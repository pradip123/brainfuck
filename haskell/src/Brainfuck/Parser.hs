module Brainfuck.Parser (parseBrainfuck) where

import Control.Applicative ((<$>))
import Brainfuck.Data.Brainfuck
import Text.ParserCombinators.Parsec

noSymbols :: Parser ()
noSymbols = skipMany $ noneOf "+-<>.,[]"

program :: Parser [Brainfuck]
program = between noSymbols eof bfOps

bfOps :: Parser [Brainfuck]
bfOps = many bfOp

bfOp :: Parser Brainfuck
bfOp = do
  x <- bfToken <|> bfLoop
  noSymbols
  return x

bfToken :: Parser Brainfuck
bfToken = choice $ map (uncurry f)
  [ ('+', Plus)
  , ('-', Minus)
  , ('>', ShiftRight)
  , ('<', ShiftLeft)
  , ('.', Output)
  , (',', Input)
  ] where
    f c t = char c >> return (Token t)

bfLoop :: Parser Brainfuck
bfLoop = Repeat <$> between (char '[' >> noSymbols) (char ']' >> noSymbols) bfOps

parseBrainfuck :: String -> Either ParseError [Brainfuck]
parseBrainfuck = parse program "brainfuck"
