Paralleles Rabin-Miller

This is -*- Literate Haskell -*-

Autor: Oleg Lobachev
\begin{code}
-- module ParRM where
module Main where

import RabinMiller
import IterUntil

import Parallel.Eden (noPe)
import System.IO.Unsafe (unsafePerformIO)
import System (getArgs)
\end{code}
\begin{seqcode}
module RabinMiller where 
-- Autor: Kent Kwee
-- [...]
-- | Rabin-Miller
-- | Fuehre 20 Iterationen durch für Fehlerwahrscheinlichkeit < 0.25 ^ 20
listRabinMiller      :: Integer         -- ^ n ist der Primzahlkandidat
                    -> [Integer]       -- ^ die Liste mit den Basen fuer RabinMiller
                    ->  Maybe Integer  -- ^ Die Ausgabe (Nothing: keine Primzahl, Just n: Moegliche Primzahl) 
listRabinMiller n as
      | (n<3)            = error "N must be greater than 3."
      | (n `mod` 2 == 0) = error "N must be odd."  
      | otherwise        = listRabinMiller2 n as 20
\end{seqcode}
\begin{code}
-- | Rabin-Miller
-- | Fuehre 20 Iterationen durch für Fehlerwahrscheinlichkeit < 0.25 ^ k
listRabinMillerP :: Int             -- ^ k ist die Anzahl der Tests k
                 -> Integer         -- ^ n ist der Primzahlkandidat
                 -> [Integer]       -- ^ die Liste mit den Basen fuer RabinMiller
                 ->  Maybe Integer  -- ^ Die Ausgabe (Nothing: keine Primzahl, Just n: Moegliche Primzahl) 
listRabinMillerP k n as
      | (n<3)            = error "N must be greater than 3."
      | (n `mod` 2 == 0) = error "N must be odd."  
      | otherwise        = listRabinMillerP2 n as k
\end{code}
\begin{seqcode}
-- | RabinMiller für feste Basen a aus einer Integerliste
listRabinMiller2 :: Integer        -- ^ n ist der Primzahlkandidat
                -> [Integer]      -- ^ die Liste mit den Basen fuer RabinMiller
                -> Integer        -- ^ Restliche Durchlaeufe
                -> Maybe Integer  -- ^ Die Ausgabe (Nothing: keine Primzahl, Just n: Moegliche Primzahl) 
listRabinMiller2 n (a:as) c
     | (c==0)                          = Just n
     | (singleRabinMillerBool n t 0 b) = listRabinMiller2 n as (c-1) 
     | otherwise                       = Nothing
     where ((q,t),b) = (zerlege(n-1,0) , powermod a q n)    
\end{seqcode}
\begin{skeleton}
iterUntil :: (Trans local, Trans task, 
              Trans subResult) => 
             localM ->
             [local] ->
             dataIn ->
             (dataIn -> [task]) ->
             (local -> task -> (subResult,local)) ->
             (localM -> [subResult] -> Either result ([task],localM)) ->
             result
\end{skeleton
\begin{code}
listRabinMillerP2 :: Integer        -- ^ n ist der Primzahlkandidat
                  -> [Integer]      -- ^ die Liste mit den Basen fuer RabinMiller
                  -> Int            -- ^ Anzahl Durchlaeufe
                  -> Maybe Integer  -- ^ Die Ausgabe (Nothing: keine Primzahl, Just n: Moegliche Primzahl) 
listRabinMillerP2 n xs k = iterUntil (n, k, xs) ks (n, k, xs) createTask worker doneContinue
    where ks = reverse [0..k-1]
createTask (n, _, xs) = take nope [(n, x) | x<-xs]
worker :: Int -> (Integer, Integer) -> (Bool, Int)
worker k (n, x) = (singleRabinMillerBool n t 0 b, k)
     where ((q,t),b) = (zerlege(n-1,0) , powermod x q n)    
-- | doneContinue bekommt den Primzahlkandidaten und die Liste von Bools
-- | ist wenigstens ein Eintrag in der Liste False, dann ist es keine Primzahl
-- | sind sie alle True -- es ist eine moegliche Primzahl
doneContinue (n, k, xs) bs | not $ and bs = Left (Nothing)
                           | k<=0 = Left (Just n)
                           | otherwise = Right (createTask (n, k, xs), (n, k-nope, xs))
  
\end{code}

wir brauchen 20 iterationen und wollen alle pes auslasten
\begin{codex}
getPe = nope * ( 20`div`nope + 1)
nope = max noPe 1
\end{codex}

wir brauchen 20 iterationen und die pes sind uns egal
\begin{code}
getPe = 20
nope = max noPe 1
\end{code}

Sequentielles Code.
\begin{code}
-- | Pruefe ob n Primzahl        
rabinMillerPIO         :: Integer            -- ^ n ist der Primzahlkandidat
                   -> IO (Maybe Integer) -- ^ Die Ausgabe (Nothing: keine Primzahl, Just n: Moegliche Primzahl) 
rabinMillerPIO n = do
  ls <- randomBaseList n
  let s = listRabinMillerP getPe n ls 
  return s

-- | Pruefe ob n Primzahl
-- | HAAAACK!
rabinMillerP     :: Integer -- ^ n ist der Primzahlkandidat
		-> Maybe Integer -- ^ Die Ausgabe (Nothing: keine Primzahl, Just n: moeglicherweise Prim)
rabinMillerP n = unsafePerformIO $ rabinMillerPIO n
\end{code}

Testen.
\begin{code}
createCandidate k = 2^k-1
doIt = rabinMillerP
main = do
  args <- getArgs
  let k = read $ head args
      n = createCandidate k
      res = doIt n
  putStrLn $ "Testing " ++ show n
  putStrLn $ "Working " ++  show getPe ++ " iterations at " ++ show noPe ++ " PEs."
  print res
  putStrLn "done"
\end{code}