module Main where

import MyLib (double)

main :: IO ()
main = do
  putStrLn $ show (double 21)
