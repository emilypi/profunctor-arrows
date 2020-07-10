{-# LANGUAGE CPP #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE ExistentialQuantification #-}
#if __GLASGOW_HASKELL__ >= 806
{-# LANGUAGE QuantifiedConstraints #-}
#endif
module Data.Profunctor.Arrow.Free where

import Control.Arrow (Arrow)
import Control.Category hiding ((.), id)
import Data.Profunctor
import Data.Profunctor.Arrow
import Data.Profunctor.Traversing
import qualified Control.Arrow as A
import qualified Control.Category as C

import Prelude

-- | Lift a profunctor into an 'Arrow' cofreely.
--
newtype PArrow p a b = PArrow { runPArrow :: forall x y. p (b , x) y -> p (a , x) y }

instance Profunctor p => Functor (PArrow p a) where
  fmap f (PArrow pp) = PArrow (pp . dimap (k f) id)
    where k g (b,x) = (g b, x)

instance Profunctor p => Profunctor (PArrow p) where
  dimap f g (PArrow pp) = PArrow $ \p -> dimap (k f) id (pp (dimap (k g) id p))
    where k h (a, b) = (h a, b)

instance Profunctor p => Category (PArrow p) where
  id = PArrow id

  PArrow pp . PArrow qq = PArrow $ \r -> qq (pp r)

instance Profunctor p => Strong (PArrow p) where
  first' (PArrow pp) = PArrow $ lmap assocr . pp . lmap assocl

toArrow :: Arrow a => PArrow a b c -> a b c
toArrow (PArrow aa) = A.arr (\x -> (x,())) >>> aa (A.arr fst)
{-# INLINE toArrow #-}

fromArrow :: Arrow a => a b c -> PArrow a b c
fromArrow x = PArrow (\z -> A.first x >>> z)
{-# INLINE fromArrow #-}

-- | Free monoid in the category of profunctors.
--
-- See <https://arxiv.org/abs/1406.4823> section 6.2.
--
--
data Free p a b where
  Parr :: (a -> b) -> Free p a b
  Free :: p x b -> Free p a x -> Free p a b

#if __GLASGOW_HASKELL__ >= 806
instance (forall t. Functor (p t)) => Functor (Free p a) where
  fmap f (Parr k) = Parr (f . k)
  fmap f (Free p q) = Free (fmap f p) q
#endif

instance Profunctor p => Profunctor (Free p) where
  dimap l r (Parr f) = Parr (dimap l r f)
  dimap l r (Free f g) = Free (rmap r f) (lmap l g)

instance Profunctor p => Category (Free p) where
  id = Parr id
  Parr g . f = rmap g f
  Free h g . f = Free h (g <<< f)

instance Strong p => Strong (Free p) where
  first' (Parr f) = Parr (first' f)
  first' (Free f g) = Free (first' f) (first' g)

instance Choice p => Choice (Free p) where
  left' (Parr f) = Parr (left' f)
  left' (Free f g) = Free (left' f) (left' g)

instance Closed p => Closed (Free p) where
  closed (Parr f) = Parr (closed f)
  closed (Free f g) = Free (closed f) (closed g)

instance Traversing p => Traversing (Free p) where
  traverse' (Parr f) = Parr (traverse' f)
  traverse' (Free f g) = Free (traverse' f) (traverse' g)

instance Mapping p => Mapping (Free p) where
  map' (Parr f) = Parr (map' f)
  map' (Free f g) = Free (map' f) (map' g)

-- | Given a natural transformation this returns a profunctor.
--
foldFree :: Category q => Profunctor q => p :-> q -> Free p a b -> q a b
foldFree _ (Parr ab) = arr ab
foldFree pq (Free p f) = pq p <<< foldFree pq f
{-# INLINE foldFree  #-}

-- | Lift a natural transformation from @f@ to @g@ into a natural transformation from @'Free' f@ to @'Free' g@.
hoistFree :: p :-> q -> Free p a b -> Free q a b
hoistFree _ (Parr ab)  = Parr ab
hoistFree pq (Free p f) = Free (pq p) (hoistFree pq f)
{-# INLINE hoistFree #-}

-- Analog of 'Const' for pliftows
newtype Append r a b = Append { getAppend :: r }

instance Functor (Append r a) where
  fmap _ (Append r) = Append r

instance Profunctor (Append r) where
  dimap _ _ (Append x) = Append x

instance Monoid r => Category (Append r) where
  id = Append mempty
  Append x . Append y = Append (x <> y)
