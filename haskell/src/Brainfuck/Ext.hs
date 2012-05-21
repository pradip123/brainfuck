module Brainfuck.Ext where

onlyOne :: [a] -> Maybe a
onlyOne [a] = Just a
onlyOne _   = Nothing

-- |Repeat a function a certain ammount of times
times :: (a -> a) -> Int -> a -> a
times f i a | i < 0     = error "Negative number"
            | i == 0    = a
            | otherwise = times f (i - 1) (f a)

-- |Repeat until a function returns the same function
whileModified :: (Eq a) => (a -> a) -> a -> a
whileModified f a | a == a'   = a'
                  | otherwise = whileModified f a'
  where a' = f a

-- |Apply a function to a specific element in a list
mapIndex :: (a -> a) -> Int -> [a] -> [a]
mapIndex f 0 (x : xs) = f x : xs
mapIndex f i (x : xs) = x : mapIndex f (i - 1) xs
mapIndex _ _ _        = error "Index out of range"

-- |Pipe a value through a list of functions
pipe :: [a -> a] -> a -> a
pipe xs x = foldl (\y f -> f y) x xs
