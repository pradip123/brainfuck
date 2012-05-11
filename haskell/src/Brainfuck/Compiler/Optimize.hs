module Brainfuck.Compiler.Optimize where

import Data.Set hiding (map)

import Brainfuck.Compiler.Analyzer
import Brainfuck.Compiler.Expr
import Brainfuck.Compiler.IL

-- Inline and apply instructions
applyIL :: [IL] -> [IL]
applyIL []                  = []
applyIL (Loop i loop : ils) = Loop i (applyIL loop) : applyIL ils
applyIL (il1 : il2 : ils)   = case (il1, il2) of
  -- Inline sets
  (Set d1 e1, Set d2 e2) | d2 == d1                  -> applyIL $ Set d2 (inline d1 e1 e2) : ils
                         | not (d2 `exprDepends` e1) -> Set d2 (inline d1 e1 e2) : applyIL (il1 : ils)

  (Set d1 e1, PutChar e2) -> PutChar (inline d1 e1 e2) : applyIL (il1 : ils)

  -- Apply shifts
  (Shift s1, Shift s2)   -> applyIL $ Shift (s1 + s2) : ils
  (Shift s, Set d e)     -> Set (d + s) (modifyPtr (+s) e) : applyIL (il1 : ils)
  (Shift s, Loop d loop) -> Loop (d + s) (mapIL (modifyOffset (+s)) loop) : applyIL (il1 : ils)
  (Shift s, PutChar e)   -> PutChar (modifyPtr (+s) e) : applyIL (il1 : ils)

  _ -> il1 : applyIL (il2 : ils)

applyIL (il : ils) = il : applyIL ils

-- |Inline instructions
-- Inline initial zeros
inlineZeros :: [IL] -> [IL]
inlineZeros = go empty
  where
    go :: Set Int -> [IL] -> [IL]
    go _ []         = []
    go s (il : ils) = case il of
      Loop i loop | hasShifts loop -> il : ils
                  | otherwise      -> Loop i (go s loop) : go s ils
      Set i e                      -> Set i (inl s e) : go (insert i s) ils
      PutChar e                    -> PutChar (inl s e) : go s ils
      GetChar _                    -> il : go s ils
      Shift _                      -> il : ils

    inl :: Set Int -> Expr -> Expr
    inl _ (Const c)            = Const c
    inl s (Get i) | member i s = Get i
                  | otherwise  = Const 0
    inl s (Add e1 e2)          = inl s e1 `Add` inl s e2
    inl s (Mul e1 e2)          = inl s e1 `Mul` inl s e2

-- Reduce multiplications and clear loops
reduceLoops :: [IL] -> [IL]
reduceLoops []                       = []
reduceLoops (il@(Loop d loop) : ils) = case copyLoop il of
  Nothing -> Loop d (reduceLoops loop) : reduceLoops ils
  Just xs -> map f xs ++ [Set d $ Const 0] ++ reduceLoops ils
    where f (ds, v) = Set ds $ Get ds `Add` (Const v `Mul` Get d)
reduceLoops (il : ils) = il : reduceLoops ils

-- Remove side effect free instructions from the end
removeFromEnd :: [IL] -> [IL]
removeFromEnd = reverse . helper . reverse
  where
    sideEffect (PutChar _) = True
    sideEffect (Loop _ _)  = True
    sideEffect _           = False

    helper []                         = []
    helper (il : ils) | sideEffect il = il : ils
                      | otherwise     = helper ils

-- Optimize expressions
optimizeExpressions :: IL -> IL
optimizeExpressions il = case il of
  Set d e   -> Set d $ optimizeExpr e
  PutChar e -> PutChar $ optimizeExpr e
  _         -> il

-- Remove instructions that does not do anything
clean :: IL -> Bool
clean il = case il of
  Shift s         -> s /= 0
  Set o1 (Get o2) -> o1 /= o2
  _               -> True

