{-# LANGUAGE FlexibleInstances, FlexibleContexts, UndecidableInstances,
MultiParamTypeClasses #-}

module Main where

import Parrows.Eden.Simple
import Parrows.Definition
import Parrows.Future
import Parrows.Util
import Parrows.Skeletons.Topology
import Parrows.Skeletons.Map
import Data.List

import Control.Parallel.Eden

--import GHC.Conc

import Control.Arrow
import Control.DeepSeq

import Control.DeepSeq

import Control.Applicative
import Data.Functor
import Data.List.Split

import System.Environment

import Debug.Trace

randoms1 :: [Int]
randoms1 = cycle [4,5,6]

randoms2 :: [Int]
randoms2 = cycle [7,8,9]

type Vector = [Int]
type Matrix = [Vector]

dimX :: Matrix -> Int
dimX = length

dimY :: Matrix -> Int
dimY = length . head

matAdd :: Matrix -> Matrix -> Matrix
matAdd x y
    | dimX x /= dimX y = error "dimX x not equal to dimX y"
    | dimY x /= dimY y = error "dimY x not equal to dimY y"
    | otherwise = chunksOf (dimX x) $ zipWith (+) (concat x) (concat y)

toMatrix :: Int -> [Int] -> Matrix
toMatrix cnt randoms = chunksOf n $ take (matrixIntSize n) randoms
        where n = cnt

matrixIntSize :: Int -> Int
matrixIntSize n = n * n

splitMatrix :: Int -> Matrix -> [[Matrix]]
splitMatrix size matrix = map (transpose . map (chunksOf size)) $ chunksOf size $ matrix

prMM :: Matrix -> Matrix -> Matrix
prMM m1 m2 = prMMTr m1 (transpose m2)
prMMTr m1 m2 = [[sum (zipWith (*) row col) | col <- m2 ] | row <- m1]

prMM_torus :: Int -> Int -> Matrix -> Matrix -> Matrix
prMM_torus numCores problemSizeVal m1 m2 = combine $ torus () (mult torusSize) $ zipWith (zipWith (,)) (split m1) (split m2)
    where   torusSize = (floor . sqrt) $ fromIntegral numCores
            combine = concat . (map (foldr (zipWith (++)) (repeat [])))
            split = splitMatrix (problemSizeVal `div` torusSize)

-- Function performed by each worker
mult :: Int -> ((Matrix,Matrix),[Matrix],[Matrix]) -> (Matrix,[Matrix],[Matrix])
mult size ((sm1,sm2),sm1s,sm2s) = (result,toRight,toBottom)
    where toRight = take (size-1) (sm1:sm1s)
          toBottom = take (size-1) (sm2':sm2s)
          sm2' = transpose sm2
          sms = zipWith prMMTr (sm1:sm1s) (sm2':sm2s)
          result = foldl1' matAdd sms

main = do
        args <- getArgs
        let (problemSize:rest) = args
        let problemSizeVal = read problemSize
        let numCores = noPe
        let matrixA = toMatrix problemSizeVal randoms1
        let matrixB = toMatrix problemSizeVal randoms2

        let matrixC = prMM matrixA matrixB
        print $ length $ (rnf matrixC) `seq` matrixC
