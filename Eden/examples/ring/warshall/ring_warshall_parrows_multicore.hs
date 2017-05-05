{-# LANGUAGE FlexibleInstances, FlexibleContexts, UndecidableInstances, MultiParamTypeClasses #-}
module Main where

import Parrows.Definition
import Parrows.Future
import Parrows.Util
import Parrows.Skeletons.Topology
import Parrows.Skeletons.Map as M

import Data.Traversable(sequenceA)

import GHC.Conc
import Control.DeepSeq

import Data.IORef
import System.IO.Unsafe

import Debug.Trace

import Control.Concurrent.MVar

import Control.Monad.Par
import Control.Parallel.Strategies
import Control.Arrow
import Control.DeepSeq
import Control.Monad

instance (NFData b, ArrowApply arr, ArrowChoice arr) => ArrowParallel arr a b conf where
    parEvalN _ fs = (arr $ \as -> (fs, as)) >>>
                    zipWithArr (app >>> arr spawnP) >>>
                    arr sequenceA >>>
                    arr (>>= mapM Control.Monad.Par.get) >>>
                    arr runPar

--data BasicFuture a = BF { val :: a }
--instance (NFData a) => NFData (BasicFuture a) where
--    rnf = rnf . val

{-# NOINLINE putHack #-}
putHack :: a -> MVar a
putHack a = unsafePerformIO $ do mVar <- newEmptyMVar
                                 print "pre fork"
                                 forkIO (do putMVar mVar a
                                            print "putMVar done")
                                 print "post fork"
                                 return mVar

instance (NFData a) => Future MVar a where
    put = arr putHack
    get = arr takeMVar >>> arr unsafePerformIO

--instance (NFData b, ArrowApply arr, ArrowChoice arr) => ArrowParallel arr a b conf where
--   parEvalN _ fs = listApp fs >>> arr (flip using $ parList rseq)

-- copied from Multicore for hack reasons
{-instance (NFData b, ArrowApply arr, ArrowChoice arr) => ArrowParallel arr a b conf where
    parEvalN _ fs = (arr $ \as -> (fs, as)) >>>
                    zipWithArr (app >>> arr spawnP) >>>
                    arr sequenceA >>>
                    arr (>>= mapM Control.Monad.Par.get) >>>
                    arr runPar
-}
{-
data BasicFuture a = BF {val :: IO (IORef a)}
instance NFData (BasicFuture a) where
    rnf _ = ()

instance (NFData a) => Future BasicFuture a where
    put = arr (\a -> let ref = newIORef (rnf a `pseq` a) in ref `par` BF {val = ref})
    get = arr (val >=> arr readIORef) >>> arr (\x -> let val = unsafePerformIO x in val `par` val)
    -}

-- copied from Multicore for hack reasons

ring_iterate :: Int -> Int -> Int -> ([Int], [[Int]]) -> ([Int], [[Int]])
ring_iterate size k i (rowk, (rowi:xs))
    | i > size = (rowk, []) -- Finish Iteration
    | i == k = (rowR, rowk:restoutput) -- send own row
    | otherwise = (rowR, rowi:restoutput) -- update row
    where
    (rowR, restoutput) = rnf nextrowk `pseq`
        ring_iterate size k (i+1) (nextrowk, xs)
    nextrowk
        | i == k = rowk -- no update , if own row
        | otherwise = updaterow rowk rowi (rowk !! (i-1))

updaterow rowk rowi elem = []

adjacency :: [[Int]]
adjacency = [[0, 1, 2],
             [1, 0, 2],
             [1, 2, 0]]

-- | Simple ring skeleton (tutorial version)
-- using remote data for providing direct inter-ring communication
-- without input distribution and output combination
ringSimple' :: (Show r, ArrowChoice arr, NFData o, ArrowLoop arr, ArrowApply arr, Future MVar r, (ArrowParallel arr (i, MVar r) (o, MVar r) conf)) =>
            conf
            -> arr (i, r) (o,r) -- ^ ring process function
            -> arr [i] [o]      -- ^ input output mapping
ringSimple' conf f = (loop $ second (arr rightRotate >>> arr lazy) >>>
                            (arr $ uncurry zip) >>>
                            arr (trace "premap") >>>
                            (M.parMap conf (arr (trace "preget") >>> second Parrows.Future.get >>> arr (trace "postget") >>> f >>>
                                arr (trace "postFunction") >>> arr mkLazy *** Parrows.Future.put >>> arr (trace "postput"))) >>>
                            arr (trace "preunzip") >>> arr unzip >>> first (arr (map unLazy))) >>>
                            M.parMap conf (arr $ \a -> rnf a `seq` a)

data Lazy a = Lazy a

instance (NFData a) => NFData (Lazy a) where
    rnf _ = ()

mkLazy :: a -> Lazy a
mkLazy a = Lazy a

unLazy :: Lazy a -> a
unLazy (Lazy a) = a

--main = print $ Parrows.Future.get >>> (+1) $ Parrows.Future.put (1::Int)

main = print $ ringSimple' () (\(x, y) -> trace (show (x)) (y, x+1)) ([1..3]::[Int])
--main = print $ ring () (ring_iterate 0 1 1) [[]]