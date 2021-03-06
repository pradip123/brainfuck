{-# LANGUAGE LambdaCase, BangPatterns #-}
module Brainfuck.Optimization.Analysis where

import Brainfuck.Data.Expr
import Brainfuck.Data.Tarpit
import Control.Applicative hiding (Const)
import Data.Maybe

-- |Check if an expression reads a certain memory position
exprDepends :: Int -> Expr -> Bool
exprDepends = ((.) isJust) . findVar

-- |Heuristically decide how much memory a program uses.
memorySize :: Tarpit -> (Int, Int)
memorySize = \case
  Nop                  -> (0, 0)
  Instruction fun next -> function fun <+> memorySize next
  Flow ctrl inner next -> control ctrl <+> memorySize inner <+> memorySize next

  where
    function = \case
      Assign d e -> g d <+> expr e
      Shift d    -> g d
      PutChar e  -> expr e
      GetChar d  -> g d

    control = \case
      If e    -> expr e
      While e -> expr e

    expr :: Expr -> (Int, Int)
    expr = foldVarsL' (\x _ y -> x <+> (g y)) (0, 0)

    g :: Int -> (Int, Int)
    g d = case compare d 0 of
      LT -> (d, 0)
      EQ -> (0, 0)
      GT -> (0, d)

    (a, b) <+> (c, d) = (a + c, b + d)

-- |Check if some tarpit consists soley of PutChar (Const _) instructions
putConstOnly :: Tarpit -> Bool
putConstOnly = \case
  Nop                                  -> True
  Instruction (PutChar (Const _)) next -> putConstOnly next
  _                                    -> False

-- |Analyze a loop for a copy/multiply structure
-- A copy loop is a loop that follow these criteria:
--   * Contains no shifts, puts or gets.
--   * The loop memory position is decremented by 1. If it's decremented by some
--     other value we can not determine if it reaches zero or overflows.
--   * Increment or decrement any other memory cell by any integer.
-- If the supplied instruction isn't a Loop, we will return Nothing.
copyLoop :: Int -> Tarpit -> Maybe Tarpit
copyLoop d1 = go
  where
    go = \case
      Nop -> Just $ Instruction (Assign d1 $ Const 0) Nop

      Instruction (Assign d2 (Var 1 d3 (Const c))) next
        | d1 == d2 && d2 == d3 && c == (-1) -> go next
        | d1 /= d2 && d2 == d3              -> Instruction (Assign d2 $ mult d2 c) <$> go next
        | otherwise                         -> Nothing

      _ -> Nothing

    mult d2 c = Var c d1 (Const 0) `add` Var 1 d2 (Const 0)

-- |Check if a while loop could be an if statement
-- This happens when the loop condition is simple (ptr[x]), for all integer x,
-- and when there is an instruction ptr[x] = 0 in the loop body.
whileOnce :: Int -> Tarpit -> Maybe Tarpit
whileOnce d = go False
  where
    go !b = \case
      Nop -> if b then Just Nop else Nothing

      Instruction fun next -> case fun of

        Assign d' (Const c) | d == d' && c == 0 -> go True next
        Assign d' _         | d == d'           -> Instruction fun `fmap` (go False next)
        GetChar d'          | d == d'           -> Instruction fun `fmap` (go False next)

        Shift _ -> Nothing

        _ -> Instruction fun `fmap` (go b next)

      Flow ctrl inner next -> Flow ctrl inner `fmap` go False next
