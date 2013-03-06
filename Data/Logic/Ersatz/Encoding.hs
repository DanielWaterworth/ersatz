{-# LANGUAGE TypeFamilies, Rank2Types #-}
module Data.Logic.Ersatz.Encoding
  ( Encoding(..)
  , decodeTraversable
  ) where

import Control.Applicative
import Data.Array
import qualified Data.IntMap as IntMap
import Data.Traversable (Traversable, sequenceA, traverse)

import Data.Logic.Ersatz.Internal.Problem
import Data.Logic.Ersatz.Solution

class Encoding a where
  type Decoded a :: *
  -- | Return a value based on the solution if one can be determined.
  decode :: Solution -> a -> IO (Maybe (Decoded a))

instance Encoding Literal where
  type Decoded Literal = Bool
  decode s l | i >= 0    = return $ IntMap.lookup i (solLitMap s)
             | otherwise = return $ not <$> IntMap.lookup (-i) (solLitMap s)
    where i = literalId l

instance Encoding Lit where
  type Decoded Lit = Bool
  decode _ (Bool b) = return $ Just b
  decode s (Lit l)  = decode s l

instance Encoding () where
  type Decoded () = ()
  decode _ () = return $ Just ()

instance (Encoding a, Encoding b) => Encoding (a,b) where
  type Decoded (a,b) = (Decoded a, Decoded b)
  decode s (a,b) = liftA2 (,) <$> decode s a <*> decode s b

instance (Encoding a, Encoding b, Encoding c) => Encoding (a,b,c) where
  type Decoded (a,b,c) = (Decoded a, Decoded b, Decoded c)
  decode s (a,b,c) = liftA3 (,,) <$> decode s a <*> decode s b <*> decode s c

instance (Encoding a, Encoding b, Encoding c, Encoding d) => Encoding (a,b,c,d) where
  type Decoded (a,b,c,d) = (Decoded a, Decoded b, Decoded c, Decoded d)
  decode s (a,b,c,d) = liftA4 (,,,) <$> decode s a <*> decode s b <*> decode s c <*> decode s d

liftA4 :: Applicative f => (a -> b -> c -> d -> e) -> f a -> f b -> f c -> f d -> f e
liftA4 f a b c d = f <$> a <*> b <*> c <*> d

instance (Encoding a, Encoding b) => Encoding (Either a b) where
  type Decoded (Either a b) = Either (Decoded a) (Decoded b)
  decode s (Left  a) = fmap Left  <$> decode s a
  decode s (Right b) = fmap Right <$> decode s b

decodeTraversable :: (Traversable f, Encoding a) => Solution -> f a -> IO (Maybe (f (Decoded a)))
decodeTraversable s a = sequenceA <$> traverse (decode s) a

instance Encoding a => Encoding [a] where
  type Decoded [a] = [Decoded a]
  decode = decodeTraversable

instance Encoding a => Encoding (Maybe a) where
  type Decoded (Maybe a) = Maybe (Decoded a)
  decode = decodeTraversable

instance (Ix i, Encoding e) => Encoding (Array i e) where
  type Decoded (Array i e) = Array i (Decoded e)
  decode = decodeTraversable
