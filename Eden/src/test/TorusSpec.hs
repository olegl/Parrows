module TorusSpec (spec) where

import Test.Hspec
import Test.Hspec.QuickCheck


import Parrows.Definition
import Parrows.Future
import Control.Parallel.Eden.Topology as E
import Parrows.Skeletons.Topology as P
import Parrows.Eden
import Parrows.Eden.Simple
import Data.List

import Control.Applicative
import Data.Functor
import Data.List.Split

import Control.DeepSeq

spec :: Spec
spec = do
    torusSpec

torusSpec :: Spec
torusSpec = describe "torus Test" $ do
    prop "Basic Torus Test" $ torusTest
        where
            torusTest :: Int -> Bool
            torusTest len = (P.torus () (nodefunction 8) [[(matrix, matrix)]]) == (E.torus (\ x y z -> nodefunction 8 (x, y, z)) $ [[(matrix, matrix)]])
                where
                    matrix = replicate len [1..len]


type Vector = [Int]
type Matrix = [Vector]

dimX :: Matrix -> Int
dimX = length

dimY :: Matrix -> Int
dimY = length . head

--from: https://rosettacode.org/wiki/Matrix_multiplication#Haskell
foldlZipWith::(a -> b -> c) -> (d -> c -> d) -> d -> [a] -> [b]  -> d
foldlZipWith _ _ u [] _          = u
foldlZipWith _ _ u _ []          = u
foldlZipWith f g u (x:xs) (y:ys) = foldlZipWith f g (g u (f x y)) xs ys

foldl1ZipWith::(a -> b -> c) -> (c -> c -> c) -> [a] -> [b] -> c
foldl1ZipWith _ _ [] _          = error "First list is empty"
foldl1ZipWith _ _ _ []          = error "Second list is empty"
foldl1ZipWith f g (x:xs) (y:ys) = foldlZipWith f g (f x y) xs ys

multAdd::(a -> b -> c) -> (c -> c -> c) -> [[a]] -> [[b]] -> [[c]]
multAdd f g xs ys = map (\us -> foldl1ZipWith (\u vs -> map (f u) vs) (zipWith g) us ys) xs

matMult:: Num a => [[a]] -> [[a]] -> [[a]]
matMult xs ys = multAdd (*) (+) xs ys

matAdd :: Matrix -> Matrix -> Matrix
matAdd x y
    | dimX x /= dimX y = error "dimX x not equal to dimX y"
    | dimY x /= dimY y = error "dimY x not equal to dimY y"
    | otherwise = chunksOf (dimX x) $ zipWith (+) (concat x) (concat y)

-- from: http://www.mathematik.uni-marburg.de/~eden/paper/edenCEFP.pdf (page 38)
nodefunction :: Int                         -- torus dimension
    -> ((Matrix, Matrix), [Matrix], [Matrix]) -- process input
    -> ([Matrix], [Matrix], [Matrix])       -- process output
nodefunction n ((bA, bB), rows, cols)
    = ([bSum], bA:nextAs , bB:nextBs)
    where bSum = foldl' matAdd (matMult bA bB) (zipWith matMult nextAs nextBs)
          nextAs = take (n-1) rows
          nextBs = take (n-1) cols

testMatrix :: Matrix
testMatrix = replicate 10 [1..10]
