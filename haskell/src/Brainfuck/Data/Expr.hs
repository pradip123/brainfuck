{-# LANGUAGE LambdaCase, GeneralizedNewtypeDeriving #-}
module Brainfuck.Data.Expr where

import Brainfuck.Utility
import Control.Applicative
import Test.QuickCheck
import qualified Data.List as List

-- Use a newtype for keeping my sanity
newtype Mult = Mult { mkMult :: Int }
  deriving (Eq, Ord, Num, Arbitrary, Show)

newtype Var = Var { mkVar :: Int }
  deriving (Eq, Ord, Num, Arbitrary, Show)

type Variable = (Mult, Var)

-- |An expression is a constant and a sum of multiples of variables
data Expr = Expr { econst :: {-# UNPACK #-} !Int, evars :: [(Mult, Var)] }
  deriving Show

instance Arbitrary Expr where
  arbitrary = Expr <$> arbitrary <*> sized (go (-100))
    where
      go _ 0 = return []

      go m s = do
        n <- arbitrary
        d <- choose (m, 100)
        ((Mult n, Var d) :) <$> go d (s `div` 2)

  shrink (Expr c v) = concatMap (\c' -> map (Expr c') $ shrink v) $ shrink c

constant :: Int -> Expr
constant = (`Expr` [])

variable :: Int -> Expr
variable d = Expr 0 [(Mult 1, Var d)]

variable' :: Int -> Int -> Expr
variable' n d = Expr 0 [(Mult n, Var d)]

foldExpr :: (Int -> Variable -> Int) -> Expr -> Int
foldExpr f (Expr c v) = foldl f c v

findExpr :: Int -> Expr -> Maybe Variable
findExpr d = List.find ((==d) . mkVar . snd) . evars

filterExpr :: (Variable -> Bool) -> Expr -> Expr
filterExpr f (Expr c v) = Expr c (List.filter f v)

add :: Expr -> Expr -> Expr
add (Expr c1 v1) (Expr c2 v2) = Expr (c1 + c2) (merge v1 v2)
  where
    merge []              ys              = ys
    merge xs              []              = xs
    merge (x@(m1, d1):xs) (y@(m2, d2):ys) = case compare d1 d2 of
      LT -> x             : merge xs (y:ys)
      EQ -> (m1 + m2, d1) : merge xs ys
      GT -> y             : merge (x:xs) ys

eval :: (Int -> Int) -> Expr -> Int
eval f = foldExpr (\acc (Mult n, Var d) -> acc + n * f d)

inlineExpr :: Var -> Expr -> Expr -> Expr
inlineExpr (Var d) (Expr c v) b = case findExpr d b of
  Nothing              -> b
  Just (m@(Mult n), _) ->
    add
      (Expr (c * n) (map (mapFst (*m)) v))
      (filterExpr ((/= d) . mkVar . snd) b)
