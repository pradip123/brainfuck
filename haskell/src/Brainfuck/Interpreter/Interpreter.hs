module Brainfuck.Interpreter.Interpreter where

import Data.Sequence

import Brainfuck.Compiler.Expr
import Brainfuck.Compiler.IL
import Brainfuck.Ext
import Brainfuck.Interpreter.State

run :: (Integral a) => State a -> [IL] -> State a
run = foldl evalOp

evalOp :: (Integral a) => State a -> IL -> State a
evalOp state (Loop i ops)     = until ((== 0) . offset i . getMemory) (`run` ops) state
evalOp (State inp out mem) op = state'
  where
    state' = case op of
      PutChar e -> State inp (out |> evalExpr mem e) mem
      GetChar d -> State (tail inp) out (modify (const $ head inp) d mem)
      Set d e   -> State inp out $ modify (const $ evalExpr mem e) d mem
      Shift s   -> State inp out $ shift s mem

      Loop _ _ -> error "Should not happen"

    shift s m | s < 0     = times shiftL (abs s) m
              | s > 0     = times shiftR s m
              | otherwise = m

evalExpr :: (Integral a) => Memory a -> Expr -> a
evalExpr _ (Const v)  = fromIntegral v
evalExpr m (Get o)    = offset o m
evalExpr m (Mult exs) = foldr ((*) . evalExpr m) 1 exs
evalExpr m (Add exs)  = foldr ((+) . evalExpr m) 0 exs
