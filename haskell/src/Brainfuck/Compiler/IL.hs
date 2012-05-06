module Brainfuck.Compiler.IL where

import Test.QuickCheck

data Expr = From offset
          | Mult Expr Expr
          | Add Expr Expr

data IL = Loop Int [IL]
        | Add Int Expr
        | Set Int Expr
        | Shift Int
        | PutChar Int
        | GetChar Int
  deriving (Eq)

instance Show IL where
  show loop@(Loop _ _)     = showList [loop] ""
  show (AddFactor d1 d2 f) = "AddFactor " ++ show d1 ++ " " ++ show d2 ++ " " ++ show f
  show (SetFrom d1 d2)     = "SetFrom " ++ show d1 ++ " " ++ show d2
  show (Add d i)           = "Add " ++ show d ++ " " ++ show i
  show (Set d i)           = "Set " ++ show d ++ " " ++ show i
  show (Shift i)           = "Shift " ++ show i
  show (PutChar d)         = "PutChar " ++ show d
  show (GetChar d)         = "GetChar " ++ show d

  showList = helper ""
    where
      helper _ []                  = showString ""
      helper s (Loop i loop : ils) = showString s
                                   . showString "Loop "
                                   . showString (show i)
                                   . showString "\n"
                                   . helper (indent s) loop
                                   . helper s ils
      helper s (il : ils) = showString s
                          . shows il
                          . showString "\n"
                          . helper s ils

      indent s = ' ' : ' ' : s

instance Arbitrary IL where
  -- TODO: Random loops
  arbitrary = do
    i1 <- choose (-100, 100)
    i2 <- choose (-100, 100)
    oneof $ map return [Add i1 i2, Shift i1]

filterIL :: (IL -> Bool) -> [IL] -> [IL]
filterIL _ []                                    = []
filterIL f (Loop i loop : ils) | f (Loop i loop) = Loop i (filterIL f loop) : filterIL f ils
filterIL f (il : ils)          | f il            = il : filterIL f ils
filterIL f (_ : ils)                             = filterIL f ils

mapIL :: (IL -> IL) -> [IL] -> [IL]
mapIL _ []                 = []
mapIL f (Loop i loop : as) = f (Loop i (mapIL f loop)) : mapIL f as
mapIL f (a : as)           = f a : mapIL f as

modifyRelative :: (Int -> Int) -> IL -> IL
modifyRelative f il = case il of
  PutChar d              -> PutChar $ f d
  GetChar d              -> GetChar $ f d
  Add d i                -> Add (f d) i
  Set d i                -> Set (f d) i
  AddFactor d1 d2 factor -> AddFactor (f d1) (f d2) factor
  SetFrom d1 d2          -> SetFrom (f d1) (f d2)
  Loop d ils             -> Loop (f d) ils
  Shift s                -> Shift s
