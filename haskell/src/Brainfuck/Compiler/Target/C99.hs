{-# LANGUAGE LambdaCase #-}
module Brainfuck.Compiler.Target.C99 (showC) where

import Brainfuck.Compiler.Analysis
import Brainfuck.Data.Expr
import Brainfuck.Data.IL
import Control.Monad
import Data.Char
import Text.CodeWriter

showExpr :: Expr -> ShowS
showExpr = \case
  Const c         -> shows c
  Get d           -> showString "ptr[" . shows d . showString "]"
  Add a b         -> showExpr a . showString " + " . showExpr b
  Mul (Add a b) c -> showString "(" . showExpr a . showString " + " . showExpr b . showString ") * " . showExpr c
  Mul a (Add b c) -> showExpr a . showString " * (" . showExpr b . showString " + " . showExpr c . showString ")"
  Mul a b         -> showExpr a . showString " * " . showExpr b

showC :: [IL] -> String
showC ils = writeCode $ do
  line "#include <stdio.h>"
  line ""
  line "int main() {"
  incIndent
  when (usesMemory ils) $ do
    line "unsigned char mem[30001];"
    line "unsigned char* ptr = mem;"

  code ils

  line "return 0;"
  decIndent
  line "}"
  where
    code :: [IL] -> CodeWriter
    code []       = return ()
    code (x : xs) = case x of
      While e ys -> block "while" e ys >> code xs
      If e ys    -> block "if" e ys >> code xs
      _          -> lineM (statement x >> string ";") >> code xs

    block :: String -> Expr -> [IL] -> CodeWriter
    block word e ys = do
      lineM $ do
        string word
        string " ("
        string $ showExpr e ") {"
      indentedM $ code ys
      line "}"

    statement x = case x of
      Set d1 (Get d2 `Add` Const c) | d1 == d2 -> ptr d1 "+=" (show c)
      Set d1 (Const c `Add` Get d2) | d1 == d2 -> ptr d1 "+=" (show c)

      PutChar (Const c) -> string "putchar(" >> string (show $ chr c) >> string ")"

      Set d e   -> ptr d "=" (showExpr e "")
      Shift s   -> string "ptr += " >> string (show s)
      PutChar e -> string "putchar(" >> string (showExpr e ")")
      GetChar p -> ptr p "=" "getchar()"

      While _ _ -> error "While can not be composed into a single line"
      If _ _    -> error "If can not be composed into a single line"

    ptr :: Int -> String -> String -> CodeWriter
    ptr d op b = do
      string "ptr["
      string $ show d
      string "] "
      string op
      string " "
      string b
