{-# LANGUAGE BangPatterns #-}
module Brainfuck.Data.Expr
  ( Expr (..)
  , findVar
  , filterVars
  , mapExpr
  , foldVarsR
  , foldVarsL'
  , add
  , eval
  , insertExpression
  , insertConstant
  ) where

import Brainfuck.Utility

-- |An expression is a sum of some multiples of variables and a constant
-- It is important that the sequence of variables are sorted by their value.
-- This is for assymptotically fast addition.
-- Note that this is similar to a sorted list of (Int, Int) tuples where the
-- terminator contains a value (the constant).
data Expr = Var {-# UNPACK #-} !Int {-# UNPACK #-} !Int Expr
          | Const {-# UNPACK #-} !Int
  deriving Show

-- |Find a variable and return its multiple
-- Ignores the constant
findVar :: Int -> Expr -> Maybe Int
findVar _ (Const _)                 = Nothing
findVar v (Var n v' xs) | v == v'   = Just n
                        | otherwise = findVar v xs

-- |Filter the variables of an expression
-- Leaves the constant unchanged
filterVars :: ((Int, Int) -> Bool) -> Expr -> Expr
filterVars _ e@(Const _)              = e
filterVars f (Var n v xs) | f (n, v)  = Var n v (filterVars f xs)
                          | otherwise = filterVars f xs

-- |Map the variables and the constant of an expression
mapExpr :: ((Int, Int) -> (Int, Int)) -> (Int -> Int) -> Expr -> Expr
mapExpr _ g (Const c)    = Const (g c)
mapExpr f g (Var n v xs) = uncurry Var (f (n, v)) $ mapExpr f g xs

-- |Right fold variables in an expression
-- Ignores the constant
foldVarsR :: (Int -> Int -> a -> a) -> a -> Expr -> a
foldVarsR _ acc (Const _)    = acc
foldVarsR f acc (Var n v xs) = f n v $ foldVarsR f acc xs

-- |Strict left fold variables in an expression
-- Ignores the constant
foldVarsL' :: (a -> Int -> Int -> a) -> a -> Expr -> a
foldVarsL' _ !acc (Const _)    = acc
foldVarsL' f !acc (Var n v xs) = foldVarsL' f (f acc n v) xs

-- |Addition of two expressions
-- Time complexity: O(n + m), follows the additon laws:
--
-- > forall a b c: Expr
-- > a + b       = b + a
-- > a + (b + c) = (a + b) + c
-- > a + 0       = a
-- > 0 + a       = a
add :: Expr -> Expr -> Expr
add (Const c1)       (Const c2)       = Const (c1 + c2)
add (Var n1 d1 x')   c2@(Const _)     = Var n1 d1 (add x' c2)
add c1@(Const _)     (Var n2 d2 y')   = Var n2 d2 (add c1 y')
add x@(Var n1 d1 x') y@(Var n2 d2 y') = case compare d1 d2 of
  LT -> Var n1 d1        $ add x' y
  EQ -> app (n1 + n2) d1 $ add x' y'
  GT -> Var n2 d2        $ add x y'

  where
    app 0 _ xs = xs
    app n v xs = Var n v xs

-- |Multiply an expression with a constant
-- Time complexity: O(n)
mul :: Int -> Expr -> Expr
mul n = mapExpr (mapFst (*n)) (*n)

-- |Evaluate an expression using a function for resolving variables
eval :: (Int -> Int) -> Expr -> Int
eval f = go 0
  where
    go !acc (Const c)    = acc + c
    go !acc (Var n v xs) = go (acc + n * f v) xs

-- |Insert the value of a variable into an expression
-- Time complexity: O(n + m)
insertExpression :: Int -> Expr -> Expr -> Expr
insertExpression v a b = case findVar v b of
  Nothing -> b
  Just n  -> mul n a `add` filterVars ((/= v) . snd) b

-- |Special case of insertVariable when the value is a constant
-- Time complexity: O(n)
insertConstant :: Int -> Int -> Expr -> Expr
insertConstant v c = go
  where
    go (Const c')                = Const c'
    go (Var n v' xs) | v == v'   = mapExpr id (+ (n * c)) xs
                     | otherwise = Var n v' $ go xs
