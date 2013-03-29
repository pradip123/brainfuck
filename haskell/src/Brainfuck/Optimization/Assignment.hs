{-# LANGUAGE LambdaCase #-}
module Brainfuck.Optimization.Assignment where

import Brainfuck.Data.Expr
import Brainfuck.Data.Tarpit
import Brainfuck.Utility
import Data.Monoid
import qualified Data.Graph as G
import qualified Data.IntMap as M

-- TODO: IntMap

-- |Merge sequences of Assign ILs using full program analysis
optimizeAssign :: Tarpit -> Tarpit
optimizeAssign = \case
  Nop -> Nop

  x@(Instruction (Assign _ _) _) -> uncurry mappend $ modify $ splitAssign x

  Instruction fun next -> Instruction fun (optimizeAssign next)

  Flow ctrl inner next -> Flow ctrl (optimizeAssign inner) (optimizeAssign next)

  where
    modify (x, y) = (makeTarpit $ findOptimal x, optimizeAssign y)

    splitAssign = \case
      Instruction (Assign d e) next -> mapFst ((d, e) :) $ splitAssign next
      y                             -> ([], y)

    makeTarpit = foldr (Instruction . uncurry Assign) Nop

-- Initial Code:
-- Assign 2 (Var 1)
-- Assign 1 (Var 0)
-- Assign 0 (Var 2)
--
-- 0: Var 1
-- 1: Var 0
-- 2: Var 1
--
-- After Optimal Assign:
-- Assign 2 (Var 1)
-- Assign 1 (Var 0)
-- Assign 0 (Var 1)
--
-- 0: Var 0
-- 1: Var 0
-- 2: Var 1
--
-- After Topologic Sort:
-- Assign 2 (Var 1)
-- Assign 0 (Var 1)
-- Assign 1 (Var 2)
--
-- 0; Var 1
-- 1: Var 1
-- 2: Var 1

type AssignOp = (Int, Expr)

-- |Calculate the optimal representation of some Assign ILs
-- TODO: Handle cyclical dependencies
findOptimal :: [AssignOp] -> [AssignOp]
findOptimal = topSort . go M.empty
  where
    go :: M.IntMap Expr -> [AssignOp] -> [AssignOp]
    go m []          = M.assocs m
    go m ((x, e):xs) = go (M.alter (const $ Just $ f m e) x m) xs

    f :: M.IntMap Expr -> Expr -> Expr
    f = flip (M.foldrWithKey' inlineExpr)

topSort :: [AssignOp] -> [AssignOp]
topSort xs = map ((\(x, k, _) -> (k, x)) . f) $ G.topSort $ graph
  where
    (graph, f, _) = G.graphFromEdges $ map (\(d, e) -> (e, d, get e)) xs

    get = M.keys . snd
