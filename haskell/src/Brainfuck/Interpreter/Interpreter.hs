module Brainfuck.Interpreter.Interpreter where

import Data.Sequence

import Brainfuck.Ext
import Brainfuck.Interpreter.State
import Brainfuck.Compiler.IL

run :: (Integral a) => State a -> [IL] -> State a
run = foldl evalOp

evalOp :: (Integral a) => State a -> IL -> State a
evalOp state (Loop i ops)     = until ((== 0) . offset i . getMemory) (`run` ops) state
evalOp (State inp out mem) op = state'
  where
    state' = case op of
      PutChar d     -> State inp (out |> offset d mem) mem
      GetChar d     -> State (tail inp) out (modify (const $ head inp) d mem)
      AddFrom d1 d2 -> State inp out $ modify (+ offset d2 mem) d1 mem
      SetFrom d1 d2 -> State inp out $ modify (const $ offset d2 mem) d1 mem
      Add d i       -> State inp out $ modify (+ fromIntegral i) d mem
      Set d i       -> State inp out $ modify (const $ fromIntegral i) d mem
      Shift s       -> State inp out $ shift s mem

      Loop _ _ -> error "Should not happen"

    shift s m | s < 0     = times shiftL (abs s) m
              | s > 0     = times shiftR s m
              | otherwise = m
