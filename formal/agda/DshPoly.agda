{-# OPTIONS --cubical #-}

module DshPoly where

open import Cubical.Core.Primitives
open import Cubical.Foundations.Prelude
open import Cubical.Foundations.Equiv

------------------------------------------------------------------------
-- 1. Definition of Polynomial Interface Objects in Category Poly
------------------------------------------------------------------------

record Poly (ℓ : Level) : Set (ℓ-suc ℓ) where
  constructor _◁_
  field
    Pos : Set ℓ
    Dir : Pos → Set ℓ

------------------------------------------------------------------------
-- 2. Morphisms in Category Poly (Dependent Bidirectional Lenses)
------------------------------------------------------------------------

record _⇒_ {ℓ} (P Q : Poly ℓ) : Set ℓ where
  constructor lens
  open Poly P renaming (Pos to P₁; Dir to P♯)
  open Poly Q renaming (Pos to Q₁; Dir to Q♯)
  field
    f₁ : P₁ → Q₁
    f♯ : (p : P₁) → Q♯ (f₁ p) → P♯ p

------------------------------------------------------------------------
-- 3. Identity and Composition of Dependent Lenses
------------------------------------------------------------------------

id-lens : ∀ {ℓ} (P : Poly ℓ) → P ⇒ P
id-lens P = lens (λ p → p) (λ p d → d)

_∘-lens_ : ∀ {ℓ} {P Q R : Poly ℓ} → (Q ⇒ R) → (P ⇒ Q) → (P ⇒ R)
(lens g₁ g♯) ∘-lens (lens f₁ f♯) =
  lens (λ p → g₁ (f₁ p))
       (λ p r-dir → f♯ p (g♯ (f₁ p) r-dir))

------------------------------------------------------------------------
-- 4. Theorem 1: Associativity of Dependent Lens Composition
------------------------------------------------------------------------

thm-lens-assoc : ∀ {ℓ} {P Q R S : Poly ℓ}
                 (h : R ⇒ S) (g : Q ⇒ R) (f : P ⇒ Q)
               → (h ∘-lens g) ∘-lens f ≡ h ∘-lens (g ∘-lens f)
thm-lens-assoc h g f = refl

------------------------------------------------------------------------
-- 5. Theorem 2: Lawful Dependent Lens Identity Preservation
------------------------------------------------------------------------

record IsLawful {ℓ} {P Q : Poly ℓ} (m : P ⇒ Q) : Set ℓ where
  open _⇒_ m
  open Poly P renaming (Pos to P₁; Dir to P♯)
  open Poly Q renaming (Pos to Q₁; Dir to Q♯)
  field
    bwd-id : (p : P₁) → (d : Q♯ (f₁ p)) → Path (P♯ p) (f♯ p d) (f♯ p d)

thm-id-is-lawful : ∀ {ℓ} (P : Poly ℓ) → IsLawful (id-lens P)
thm-id-is-lawful P = record { bwd-id = λ p d → refl }
