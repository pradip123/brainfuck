{-# LANGUAGE LambdaCase #-}
module Brainfuck.Interpret (run, run1) where

import Brainfuck.Data.AST
import Brainfuck.Data.Expr
import Control.Monad.State.Strict
import Control.Monad.Writer.Strict
import Data.Char
import Data.ListZipper
import Data.Word
import Ext

type Input  = [Word8]
type Output = [Word8]
type Memory = ListZipper Word8

type Machine = StateT Memory (StateT Input (Writer Output))

input :: Machine Word8
input = do
  (x:xs) <- lift get
  lift (put xs)
  return x

output :: Word8 -> Machine ()
output = tell . (:[])

newMemory :: Memory
newMemory = ListZipper zeros 0 zeros
  where zeros = repeat 0

run1 :: String -> AST -> String
run1 inp = map (chr . fromIntegral) . run (map (fromIntegral . ord) inp)

run :: Input -> AST -> Output
run inp ast = execWriter (execStateT (execStateT (go ast) newMemory) inp)
  where
    go = \case
      Nop                  -> return ()
      Instruction fun next -> function fun >> go next
      Flow ctrl inner next -> flow inner ctrl >> go next

    function = \case
      Shift s    -> modify (move s)
      Assign d e -> eval' e >>= modify . (`set` d)
      PutChar e  -> eval' e >>= output
      GetChar d  -> input >>= modify . (`set` d)

    flow inner = \case
      Forever -> forever (go inner)
      Never   -> return ()
      Once    -> go inner
      While e -> while (continue e) (go inner)
      If e    -> when' (continue e) (go inner)

    continue e = do
      x <- eval' e
      return $ x /= (0 :: Word8)

    eval' :: Expr -> Machine Word8
    eval' e = do
      mem <- get
      return $ fromIntegral $ eval (fromIntegral . (`peek` mem)) e

    set = applyAt . const
