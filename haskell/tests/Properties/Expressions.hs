{-# LANGUAGE LambdaCase #-}
module Properties.Expressions where

import Brainfuck.Data.Expr
import Brainfuck.Optimization.Expr
import Brainfuck.Optimization.Inlining
import Control.Applicative ((<$>),(<*>))
import Test.QuickCheck

constOnly :: Gen Expr
constOnly = sized $ \n -> expr n n
  where
    expr 0 _ = leaf
    expr n s = oneof [leaf, branch n s]

    branch n s = frequency
      [ (1, OperateUnary <$> arbitrary <*> (expr (n - 1) s))
      , (4, OperateBinary <$> arbitrary <*> (expr (n - 1) s) <*> (expr (n - 1) s))
      ]

    leaf = mkInt <$> arbitrary

propExprOptimizeConst :: Property
propExprOptimizeConst = forAll constOnly (isConst . simplify)

propExprOptimizeTwice :: Expr -> Bool
propExprOptimizeTwice expr = let expr' = simplify expr in expr' == simplify expr'

propExprEval :: Expr -> NonEmptyList Int -> Bool
propExprEval expr (NonEmpty xs) = eval f expr == eval f (simplify expr)
  where
    f = (!!) xs . (`mod` length xs)

propExprOptimizeSmaller :: Expr -> Bool
propExprOptimizeSmaller expr = exprComplexity expr >= exprComplexity (simplify expr)
