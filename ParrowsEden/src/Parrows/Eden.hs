{-
The MIT License (MIT)

Copyright (c) 2016 Martin Braun

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-}
{-# LANGUAGE FlexibleInstances, UndecidableInstances, ScopedTypeVariables, Rank2Types, MultiParamTypeClasses #-}
module Parrows.Eden where

import Parrows.Definition

import Control.Parallel.Strategies
import Control.Arrow

import Control.Parallel.Eden

-- ParallelSpawn Instances

instance (Trans a, Trans b) => ParallelSpawn (->) a b where
    parEvalN fs as = spawn (map process fs) as

instance (Monad m, Trans a, Trans b, Trans (m b)) => ParallelSpawn (Kleisli m) a b where
    parEvalN = (Kleisli $ \fs -> return (Kleisli $ \as -> sequence (parEvalN (map (\(Kleisli f) -> f) fs) as)))

instance (Trans a, Trans b, Trans c, Trans d) => SyntacticSugar (->) a b c d where
    f |***| g = parEval2 (f, g)