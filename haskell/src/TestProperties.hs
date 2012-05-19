module TestProperties where

import Data.Word

import Test.QuickCheck
import Test.QuickCheck.Modifiers

import Brainfuck.Compiler.Expr
import Brainfuck.Compiler.IL
import Brainfuck.Compiler.Optimize
import Brainfuck.Ext
import Brainfuck.Interpreter.Interpreter
import Brainfuck.Interpreter.State
import Brainfuck.Parser.Brainfuck
import Brainfuck.Parser.Parser

-- {{{ Memory operations
propShiftLength :: ([Int], [Int]) -> Property
propShiftLength x = forAll gen $ \l -> forAll gen $ \r -> f (g l) == f (g r)
  where
    gen      = choose (0, 1000)
    f (a, b) = length a + length b
    g i      = times shiftL i x

propShiftToEmpty :: ([Int], [Int]) -> Property
propShiftToEmpty x@(a, b) =
  (null ae && null be) ==> (length af == lx && length bf == lx)
  where
    la = length a
    lb = length b
    lx = la + lb

    (ae, bf) = times shiftR la x
    (af, be) = times shiftL lb x
-- }}}
-- {{{ Parser
propParser :: [Brainfuck] -> Bool
propParser bf = bf == parse (show bf)
-- }}}
-- {{{ Optimization
comp :: (Integral a) => Int -> State a -> State a -> Bool
comp i (State _ out1 (ml1, mr1)) (State _ out2 (ml2, mr2)) =
  take i ml1 == take i ml2 && take i mr1 == take i mr2 && out1 == out2

propOptimize :: ([IL] -> [IL]) -> [IL] -> Bool
propOptimize f il = comp (length il) (run state il) (run state opt)
  where
    state :: State Word8
    state = newState ""
    opt   = f il

propOptimizeInlineZeros = propOptimize inlineZeros
propOptimizeCopies      = propOptimize reduceCopyLoops
propOptimizeShifts      = propOptimize reduceShiftLoops
propOptimizeApply       = propOptimize applyIL
propOptimizeClean       = propOptimize $ filterIL clean
propOptimizeExpressions = propOptimize $ mapIL optimizeExpressions
-- }}}
-- {{{ Loops
exCopyLoop1 :: IL
exCopyLoop1 =
  While 0
    [ Set 0 $ Get 0 `Add` Const (-1) ]

exCopyLoop2 :: IL
exCopyLoop2 =
  While 5
    [ Set 5 $ Get 5 `Add` Const (-1)
    , Set 1 $ Get 1 `Add` Const 1
    , Set 2 $ Get 2 `Add` Const 5
    , Set 3 $ Get 3 `Add` Const 10 ]

exNotCopyLoop1 :: IL
exNotCopyLoop1 =
  While 5
    [ Set 5 $ Get 5 `Add` Const (-1)
    , Set 6 $ Get 5 `Add` Const 10 ]

exShiftLoop1 :: [IL]
exShiftLoop1 =
  [ Set 0 $ Get 0 `Add` Const 10
  , Set 1 $ Const 0
  , Set 2 $ Get 2 `Add` Const 4 `Add` Get 0
  , Set 3 $ Get 3 `Add` Const 5
  , While 3 [ Shift (-1) ] ]

-- }}}
-- {{{ Expressions
propExprOptimizeTwice :: Expr -> Bool
propExprOptimizeTwice e = let e' = optimizeExpr e in e' == optimizeExpr e'

propExprEval :: Expr -> NonEmptyList Int -> Bool
propExprEval e (NonEmpty xs) = eval f e == eval f e'
  where
    e' = optimizeExpr e
    l  = length xs

    f :: Int -> Int
    f i = xs !! (i `mod` l)

propExprOptimizeSmaller :: Expr -> Bool
propExprOptimizeSmaller expr = complexity expr >= complexity (optimizeExpr expr)
-- }}}

-- vim: set fdm=marker :