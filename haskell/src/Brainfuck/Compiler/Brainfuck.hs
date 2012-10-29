{-# LANGUAGE LambdaCase #-}
module Brainfuck.Compiler.Brainfuck (compile) where

import Brainfuck.Data.Brainfuck
import Brainfuck.Data.Expr
import Brainfuck.Data.IL

compile :: [Brainfuck] -> [IL]
compile = \case
  []             -> []
  Repeat ys : xs -> While (Get 0) (compile ys) : compile xs
  Token t : xs   -> token t : compile xs
  where
    token = \case
      Plus       -> Set 0 $ Add (Get 0) (Const 1)
      Minus      -> Set 0 $ Add (Get 0) (Const (-1))
      ShiftRight -> Shift 1
      ShiftLeft  -> Shift (-1)
      Output     -> PutChar $ Get 0
      Input      -> GetChar 0
