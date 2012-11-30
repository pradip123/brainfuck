{-# LANGUAGE LambdaCase #-}
module Properties where

import Brainfuck.CodeGen.C99
import Brainfuck.Compiler.Brainfuck
import Brainfuck.Compiler.Parser
import Brainfuck.Data.AST
import Brainfuck.Data.Brainfuck
import Brainfuck.Data.Expr
import Brainfuck.Interpreter
import Brainfuck.Optimization.Analysis
import Brainfuck.Optimization.Assignment
import Brainfuck.Optimization.General
import Brainfuck.Optimization.Inlining
import Brainfuck.Optimization.Pipeline
import Control.Monad
import Data.ListZipper
import Data.Maybe
import Data.Sequence (empty)
import Data.Word
import Ext
import Test.QuickCheck hiding (output)

-- {{{ ListZipper
propZipperMoveSize :: Int -> ListZipper a -> Bool
propZipperMoveSize i a = size a == size (move i a)
-- }}}
-- {{{ Misc
propMapIndexEq :: Int -> NonEmptyList Int -> Property
propMapIndexEq x (NonEmpty xs) = forAll (choose (0, length xs - 1)) $
  \i -> (mapIndex (const x) i xs !! i) == x

propMapIndexLength :: Int -> NonEmptyList Int -> Property
propMapIndexLength x (NonEmpty xs) = forAll (choose (0, length xs - 1)) $
  \i -> length (mapIndex (const x) i xs) == length xs

propPipeAdd :: Property
propPipeAdd = forAll (choose (0, 20000)) $
  \i -> pipe (replicate i (+1)) 0 == i

propWhileModified :: Property
propWhileModified = forAll (choose (-10000000, 10000000)) ((== 0) . whileModified f)
  where
    f :: Int -> Int
    f j | j < 0     = j + 1
        | j == 0    = 0
        | otherwise = j - 1
-- }}}
-- {{{ Parser
propParser :: [Brainfuck] -> Bool
propParser bf = case parseBrainfuck (show bf) of
  Left _    -> False
  Right bf' -> bf == bf'
-- }}}
-- {{{ Compiler
propCompileDecompile :: [Brainfuck] -> Bool
propCompileDecompile bf = bf == decompile (compile bf)
-- }}}
-- {{{ Optimization
compareFull :: (Integral a) => Int -> State a -> State a -> Bool
compareFull i (State _ out1 m1) (State _ out2 m2) = cut i m1 == cut i m2 && out1 == out2

compareOutput :: AST -> AST -> Bool
compareOutput xs ys = output (run state xs) == output (run state ys)
  where
    state :: State Word8
    state = State [1..] empty newMemory

testCode :: AST -> AST -> Bool
testCode xs ys = compareFull s (run state xs) (run state ys)
  where
    s = let (xsMin, xsMax) = memorySize xs
            (ysMin, ysMax) = memorySize ys
         in 1 + abs xsMin + abs xsMax + abs ysMin + abs ysMax

    state :: State Word8
    state = State [1..] empty newMemory

propOptimize :: (AST -> AST) -> AST -> Bool
propOptimize f xs = testCode xs (f xs)

-- TODO: Better testing

propInline :: Int -> Expr -> AST -> Bool
propInline d e xs = inline d e xs `testCode` Instruction (Set d e) xs

propHeuristicInlining :: Int -> Expr -> AST -> Bool
propHeuristicInlining d e xs = case heuristicInlining d e xs of
  Just xs' -> (Instruction (Set d e) xs) `testCode` xs'
  Nothing  -> True

propOptimizeInlineZeros, propOptimizeCopies, propOptimizeCleanUp,
  propOptimizeExpressions, propOptimizeMovePutGet, propOptimizeSets,
  propOptimizeMoveShifts :: AST -> Bool

propOptimizeCleanUp     = propOptimize cleanUp
propOptimizeCopies      = propOptimize reduceCopyLoops
propOptimizeExpressions = propOptimize optimizeExpressions
propOptimizeInlineZeros = propOptimize inlineZeros
propOptimizeMovePutGet  = propOptimize movePutGet
propOptimizeMoveShifts  = propOptimize moveShifts
propOptimizeSets        = propOptimize optimizeSets

propOptimizeAll :: AST -> Bool
propOptimizeAll xs = compareOutput xs (optimizeAll xs)

-- }}}
-- {{{ Loops
exCopyLoop1 :: AST
exCopyLoop1 =
  Flow (While $ Get 0)
    (Instruction (Set 0 (Get 0 `Add` Const (-1))) Nop)
  Nop

exCopyLoop2 :: AST
exCopyLoop2 =
  Flow (While (Get 5))
    (Instruction (Set 5 $ Get 5 `Add` Const (-1))
    (Instruction (Set 1 $ Get 1 `Add` Const 1)
    (Instruction (Set 2 $ Get 2 `Add` Const 5)
    (Instruction (Set 3 $ Get 3 `Add` Const 10) Nop))))
  Nop

exNotCopyLoop1 :: AST
exNotCopyLoop1 =
  Flow (While $ Get 5)
    (Instruction (Set 5 $ Get 5 `Add` Const (-1))
    (Instruction (Set 6 $ Get 5 `Add` Const 10)
    Nop))
  Nop

exShiftLoop1 :: AST
exShiftLoop1 = Instruction (Set 0 $ Get 0 `Add` Const 10)
  (Instruction (Set 1 $ Const 0)
  (Instruction (Set 2 $ Get 2 `Add` Const 4 `Add` Get 0)
  (Instruction (Set 3 $ Get 3 `Add` Const 5)
  (Flow (While $ Get 3) (Instruction (Shift (-1)) Nop)
  Nop))))

-- }}}
-- {{{ Expressions
constOnly :: Gen Expr
constOnly = frequency
  [ (3, liftM Const arbitrary)
  , (1, liftM2 Add constOnly constOnly)
  , (1, liftM2 Mul constOnly constOnly)
  ]

propExprOptimizeConst :: Property
propExprOptimizeConst = forAll constOnly (f . optimizeExpr)
  where
    f = \case
      Const _ -> True
      _       -> False

propExprOptimizeTwice :: Expr -> Bool
propExprOptimizeTwice e = let e' = optimizeExpr e in e' == optimizeExpr e'

propExprEval :: Expr -> NonEmptyList Int -> Bool
propExprEval e (NonEmpty xs) = eval f e == eval f (optimizeExpr e)
  where
    f = (!!) xs . (`mod` length xs)

propExprOptimizeSmaller :: Expr -> Bool
propExprOptimizeSmaller expr = exprComplexity expr >= exprComplexity (optimizeExpr expr)

propExprListifyDepth :: Expr -> Bool
propExprListifyDepth expr = l <= r
  where
    expr' = fromMaybe expr (listify expr)

    l = case expr' of
      Add a _ -> heigth a
      Mul a _ -> heigth a
      _       -> 0

    r = case expr' of
      Add _ b -> heigth b
      Mul _ b -> heigth b
      _       -> 0
-- }}}

-- vim: set fdm=marker :
