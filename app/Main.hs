module Main where

import PGN

import Control.Monad (unless)
import Data.List (intersperse)
import System.Environment (getArgs)
import System.Exit (ExitCode(..), exitSuccess, exitWith)

main :: IO ()
main = getArgs >>= dispatch

dispatch :: [String] -> IO ()
dispatch ("check" : files) = mapM checkFile files >>= exit
dispatch ("show"  : files) = sequence_ $ intersperse delimiter $ map showFile files
dispatch ("help"  : _    ) = help
dispatch ("-h"    : _    ) = help
dispatch ("--help": _    ) = help
dispatch (unknown : _    ) = putStrLn $ "Unknown action " ++ unknown
dispatch []                 = help

delimiter :: IO ()
delimiter = putStrLn ""

exit :: [Bool] -> IO ()
exit checks =
  if failures == 0
  then exitSuccess
  else exitWith (ExitFailure failures)
    where failures = length $ filter not checks

help :: IO ()
help = do
  putStrLn "Commands:"
  putStrLn " show files*  : browse PGN files"
  putStrLn ""
  putStrLn " check files* : attempt to parse PGN files"
  putStrLn ""
  putStrLn " help         : this message"

checkFile :: String -> IO Bool
checkFile file = do
  r <- parseFile file
  case r of
    Right _ -> True  <$ putStrLn (file ++ " OK")
    Left  e -> False <$ putStrLn (file ++ " KO") <* putStr (asMessage e)
    where asMessage = indent . show
          indent = unlines . map ("  "++) . lines

showFile :: String -> IO ()
showFile f = do
  r <- parseFile f
  case r of
    Left  e -> print e
    Right m -> printMatch m

printMatch :: Match -> IO ()
printMatch m = do
  putStrLn "Headers:"
  mapM_ (indented 1) $ matchHeaders m
  putStrLn ""
  putStr "Moves:"
  printMove $ matchMoves m

printMove :: Move -> IO ()
printMove VariantEnd = return ()
printMove (End result) = do
  putStrLn ""
  putStr "      "
  printResult result
printMove (HalfMove n c pm ch as nx vs) = do
  case c of
    White -> do
      putStrLn ""
      putStr "  "
      printMoveNumber n
    Black -> return ()
  printPieceMove pm
  printCheck ch
  printAnnotations as
  unless (null vs) $ do
    printVariants vs
  case c of
    White -> if null as
             then putStr " "
             else do
               putStrLn ""
               putStr $ lpad (2 + 4 + 10 + 1 + 1) ""
    Black -> return ()
  printMove nx

printVariants :: [Move] -> IO ()
printVariants []  = return ()
printVariants [_] = putStr " 1 variant"
printVariants vs  = putStr $ " " ++ (show $ length vs) ++ " variants"

printResult :: ResultValue -> IO ()
printResult WhiteWins = putStrLn "white wins"
printResult BlackWins = putStrLn "black wins"
printResult Draw      = putStrLn "draw"
printResult _         = putStrLn "uncertain"

printMoveNumber :: Int -> IO ()
printMoveNumber n = putStr $ lpad 4 (show n ++ ". ")

printPieceMove :: PieceMove -> IO ()
printPieceMove (PieceMove pm) = putStr (lpad 10 pm)

printCheck :: Check -> IO ()
printCheck None  = putStr " "
printCheck Check = putStr "+"
printCheck Mate  = putStr "#"

printAnnotations :: [Annotation] -> IO ()
printAnnotations [] = return ()
printAnnotations as = do
  putStr " "
  sequence_ $ intersperse (putStr " ") $ map printAnnotation as

printAnnotation :: Annotation -> IO ()
printAnnotation (GlyphAnnotation g)   = printGlyph g
printAnnotation (CommentAnnotation c) = printComment c

printGlyph :: Glyph -> IO ()
printGlyph (Glyph v) = putStr ("$" ++ show v)

printComment :: Comment -> IO ()
printComment c = putStr $ "« " ++ c ++ " »"

indented :: Show a => Int -> a -> IO ()
indented width o = do
  putStr $ take (width*2) $ repeat ' '
  print o

lpad :: Int -> String -> String
lpad l s | l < 0     = error "padding size must be >= 0"
         | otherwise = pad ++ s'
  where l' = l - length s'
        s' = take l s
        pad = replicate l' ' '
