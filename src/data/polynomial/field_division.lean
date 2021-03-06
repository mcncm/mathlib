/-
Copyright (c) 2018 Chris Hughes. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Chris Hughes, Johannes Hölzl, Scott Morrison, Jens Wagemaker
-/
import data.polynomial.ring_division
import data.polynomial.derivative
import algebra.gcd_monoid

/-!
# Theory of univariate polynomials

This file starts looking like the ring theory of $ R[X] $

-/

noncomputable theory
local attribute [instance, priority 100] classical.prop_decidable

namespace polynomial
universes u v w y z
variables {R : Type u} {S : Type v} {k : Type y} {A : Type z} {a b : R} {n : ℕ}

section field
variables [field R] {p q : polynomial R}

lemma is_unit_iff_degree_eq_zero : is_unit p ↔ degree p = 0 :=
⟨degree_eq_zero_of_is_unit,
  λ h, have degree p ≤ 0, by simp [*, le_refl],
    have hc : coeff p 0 ≠ 0, from λ hc,
        by rw [eq_C_of_degree_le_zero this, hc] at h;
        simpa using h,
    is_unit_iff_dvd_one.2 ⟨C (coeff p 0)⁻¹, begin
      conv in p { rw eq_C_of_degree_le_zero this },
      rw [← C_mul, _root_.mul_inv_cancel hc, C_1]
    end⟩⟩

lemma degree_pos_of_ne_zero_of_nonunit (hp0 : p ≠ 0) (hp : ¬is_unit p) :
  0 < degree p :=
lt_of_not_ge (λ h, by rw [eq_C_of_degree_le_zero h] at hp0 hp;
  exact (hp $ is_unit.map' C $
    is_unit.mk0 (coeff p 0) (mt C_inj.2 (by simpa using hp0))))

lemma monic_mul_leading_coeff_inv (h : p ≠ 0) :
  monic (p * C (leading_coeff p)⁻¹) :=
by rw [monic, leading_coeff_mul, leading_coeff_C,
  mul_inv_cancel (show leading_coeff p ≠ 0, from mt leading_coeff_eq_zero.1 h)]

lemma degree_mul_leading_coeff_inv (p : polynomial R) (h : q ≠ 0) :
  degree (p * C (leading_coeff q)⁻¹) = degree p :=
have h₁ : (leading_coeff q)⁻¹ ≠ 0 :=
  inv_ne_zero (mt leading_coeff_eq_zero.1 h),
by rw [degree_mul, degree_C h₁, add_zero]

theorem irreducible_of_monic {p : polynomial R} (hp1 : p.monic) (hp2 : p ≠ 1) :
  irreducible p ↔ (∀ f g : polynomial R, f.monic → g.monic → f * g = p → f = 1 ∨ g = 1) :=
⟨λ hp3 f g hf hg hfg, or.cases_on (hp3.2 f g hfg.symm)
  (assume huf : is_unit f, or.inl $ eq_one_of_is_unit_of_monic hf huf)
  (assume hug : is_unit g, or.inr $ eq_one_of_is_unit_of_monic hg hug),
λ hp3, ⟨mt (eq_one_of_is_unit_of_monic hp1) hp2, λ f g hp,
have hf : f ≠ 0, from λ hf, by { rw [hp, hf, zero_mul] at hp1, exact not_monic_zero hp1 },
have hg : g ≠ 0, from λ hg, by { rw [hp, hg, mul_zero] at hp1, exact not_monic_zero hp1 },
or.imp (λ hf, is_unit_of_mul_eq_one _ _ hf) (λ hg, is_unit_of_mul_eq_one _ _ hg) $
hp3 (f * C f.leading_coeff⁻¹) (g * C g.leading_coeff⁻¹)
  (monic_mul_leading_coeff_inv hf) (monic_mul_leading_coeff_inv hg) $
by rw [mul_assoc, mul_left_comm _ g, ← mul_assoc, ← C_mul, ← mul_inv', ← leading_coeff_mul,
    ← hp, monic.def.1 hp1, inv_one, C_1, mul_one]⟩⟩

/-- Division of polynomials. See polynomial.div_by_monic for more details.-/
def div (p q : polynomial R) :=
C (leading_coeff q)⁻¹ * (p /ₘ (q * C (leading_coeff q)⁻¹))

/-- Remainder of polynomial division, see the lemma `quotient_mul_add_remainder_eq_aux`.
See polynomial.mod_by_monic for more details. -/
def mod (p q : polynomial R) :=
p %ₘ (q * C (leading_coeff q)⁻¹)

private lemma quotient_mul_add_remainder_eq_aux (p q : polynomial R) :
  q * div p q + mod p q = p :=
if h : q = 0 then by simp only [h, zero_mul, mod, mod_by_monic_zero, zero_add]
else begin
  conv {to_rhs, rw ← mod_by_monic_add_div p (monic_mul_leading_coeff_inv h)},
  rw [div, mod, add_comm, mul_assoc]
end

private lemma remainder_lt_aux (p : polynomial R) (hq : q ≠ 0) :
  degree (mod p q) < degree q :=
by rw ← degree_mul_leading_coeff_inv q hq; exact
  degree_mod_by_monic_lt p (monic_mul_leading_coeff_inv hq)
    (mul_ne_zero hq (mt leading_coeff_eq_zero.2 (by rw leading_coeff_C;
      exact inv_ne_zero (mt leading_coeff_eq_zero.1 hq))))

instance : has_div (polynomial R) := ⟨div⟩

instance : has_mod (polynomial R) := ⟨mod⟩

lemma div_def : p / q = C (leading_coeff q)⁻¹ * (p /ₘ (q * C (leading_coeff q)⁻¹)) := rfl

lemma mod_def : p % q = p %ₘ (q * C (leading_coeff q)⁻¹) := rfl

lemma mod_by_monic_eq_mod (p : polynomial R) (hq : monic q) : p %ₘ q = p % q :=
show p %ₘ q = p %ₘ (q * C (leading_coeff q)⁻¹), by simp only [monic.def.1 hq, inv_one, mul_one, C_1]

lemma div_by_monic_eq_div (p : polynomial R) (hq : monic q) : p /ₘ q = p / q :=
show p /ₘ q = C (leading_coeff q)⁻¹ * (p /ₘ (q * C (leading_coeff q)⁻¹)),
by simp only [monic.def.1 hq, inv_one, C_1, one_mul, mul_one]

lemma mod_X_sub_C_eq_C_eval (p : polynomial R) (a : R) : p % (X - C a) = C (p.eval a) :=
mod_by_monic_eq_mod p (monic_X_sub_C a) ▸ mod_by_monic_X_sub_C_eq_C_eval _ _

lemma mul_div_eq_iff_is_root : (X - C a) * (p / (X - C a)) = p ↔ is_root p a :=
div_by_monic_eq_div p (monic_X_sub_C a) ▸ mul_div_by_monic_eq_iff_is_root

instance : euclidean_domain (polynomial R) :=
{ quotient := (/),
  quotient_zero := by simp [div_def],
  remainder := (%),
  r := _,
  r_well_founded := degree_lt_wf,
  quotient_mul_add_remainder_eq := quotient_mul_add_remainder_eq_aux,
  remainder_lt := λ p q hq, remainder_lt_aux _ hq,
  mul_left_not_lt := λ p q hq, not_lt_of_ge (degree_le_mul_left _ hq),
  .. polynomial.comm_ring,
  .. polynomial.nontrivial }

lemma mod_eq_self_iff (hq0 : q ≠ 0) : p % q = p ↔ degree p < degree q :=
⟨λ h, h ▸ euclidean_domain.mod_lt _ hq0,
λ h, have ¬degree (q * C (leading_coeff q)⁻¹) ≤ degree p :=
  not_le_of_gt $ by rwa degree_mul_leading_coeff_inv q hq0,
begin
  rw [mod_def, mod_by_monic, dif_pos (monic_mul_leading_coeff_inv hq0)],
  unfold div_mod_by_monic_aux,
  simp only [this, false_and, if_false]
end⟩

lemma div_eq_zero_iff (hq0 : q ≠ 0) : p / q = 0 ↔ degree p < degree q :=
⟨λ h, by have := euclidean_domain.div_add_mod p q;
  rwa [h, mul_zero, zero_add, mod_eq_self_iff hq0] at this,
λ h, have hlt : degree p < degree (q * C (leading_coeff q)⁻¹),
    by rwa degree_mul_leading_coeff_inv q hq0,
  have hm : monic (q * C (leading_coeff q)⁻¹) := monic_mul_leading_coeff_inv hq0,
  by rw [div_def, (div_by_monic_eq_zero_iff hm (ne_zero_of_monic hm)).2 hlt, mul_zero]⟩

lemma degree_add_div (hq0 : q ≠ 0) (hpq : degree q ≤ degree p) :
  degree q + degree (p / q) = degree p :=
have degree (p % q) < degree (q * (p / q)) :=
  calc degree (p % q) < degree q : euclidean_domain.mod_lt _ hq0
  ... ≤ _ : degree_le_mul_left _ (mt (div_eq_zero_iff hq0).1 (not_lt_of_ge hpq)),
by conv {to_rhs, rw [← euclidean_domain.div_add_mod p q, add_comm,
    degree_add_eq_of_degree_lt this, degree_mul]}

lemma degree_div_le (p q : polynomial R) : degree (p / q) ≤ degree p :=
if hq : q = 0 then by simp [hq]
else by rw [div_def, mul_comm, degree_mul_leading_coeff_inv _ hq];
  exact degree_div_by_monic_le _ _

lemma degree_div_lt (hp : p ≠ 0) (hq : 0 < degree q) : degree (p / q) < degree p :=
have hq0 : q ≠ 0, from λ hq0, by simpa [hq0] using hq,
by rw [div_def, mul_comm, degree_mul_leading_coeff_inv _ hq0];
  exact degree_div_by_monic_lt _ (monic_mul_leading_coeff_inv hq0) hp
    (by rw degree_mul_leading_coeff_inv _ hq0; exact hq)

@[simp] lemma degree_map [field k] (p : polynomial R) (f : R →+* k) :
  degree (p.map f) = degree p :=
p.degree_map_eq_of_injective f.injective

@[simp] lemma nat_degree_map [field k] (f : R →+* k) :
  nat_degree (p.map f) = nat_degree p :=
nat_degree_eq_of_degree_eq (degree_map _ f)

@[simp] lemma leading_coeff_map [field k] (f : R →+* k) :
  leading_coeff (p.map f) = f (leading_coeff p) :=
by simp [leading_coeff, coeff_map f]

theorem monic_map_iff [field k] {f : R →+* k} {p : polynomial R} :
  (p.map f).monic ↔ p.monic :=
by rw [monic, leading_coeff_map, ← f.map_one, function.injective.eq_iff f.injective, monic]

theorem is_unit_map [field k] (f : R →+* k) :
  is_unit (p.map f) ↔ is_unit p :=
by simp_rw [is_unit_iff_degree_eq_zero, degree_map]

lemma map_div [field k] (f : R →+* k) :
  (p / q).map f = p.map f / q.map f :=
if hq0 : q = 0 then by simp [hq0]
else
by rw [div_def, div_def, map_mul, map_div_by_monic f (monic_mul_leading_coeff_inv hq0)];
  simp [f.map_inv, leading_coeff, coeff_map f]

lemma map_mod [field k] (f : R →+* k) :
  (p % q).map f = p.map f % q.map f :=
if hq0 : q = 0 then by simp [hq0]
else by rw [mod_def, mod_def, leading_coeff_map f, ← f.map_inv, ← map_C f,
  ← map_mul f, map_mod_by_monic f (monic_mul_leading_coeff_inv hq0)]

section
open euclidean_domain
local attribute [-instance] finsupp.finsupp.decidable_eq
theorem gcd_map [field k] (f : R →+* k) :
  gcd (p.map f) (q.map f) = (gcd p q).map f :=
gcd.induction p q (λ x, by simp_rw [map_zero, euclidean_domain.gcd_zero_left]) $ λ x y hx ih,
by rw [gcd_val, ← map_mod, ih, ← gcd_val]
end

lemma eval₂_gcd_eq_zero [comm_semiring k] {ϕ : R →+* k} {f g : polynomial R} {α : k}
  (hf : f.eval₂ ϕ α = 0) (hg : g.eval₂ ϕ α = 0) : (euclidean_domain.gcd f g).eval₂ ϕ α = 0 :=
by rw [euclidean_domain.gcd_eq_gcd_ab f g, polynomial.eval₂_add, polynomial.eval₂_mul,
       polynomial.eval₂_mul, hf, hg, zero_mul, zero_mul, zero_add]

lemma eval_gcd_eq_zero {f g : polynomial R} {α : R} (hf : f.eval α = 0) (hg : g.eval α = 0) :
  (euclidean_domain.gcd f g).eval α = 0 := eval₂_gcd_eq_zero hf hg

lemma root_left_of_root_gcd [comm_semiring k] {ϕ : R →+* k} {f g : polynomial R} {α : k}
  (hα : (euclidean_domain.gcd f g).eval₂ ϕ α = 0) : f.eval₂ ϕ α = 0 :=
by { cases euclidean_domain.gcd_dvd_left f g with p hp,
     rw [hp, polynomial.eval₂_mul, hα, zero_mul] }

lemma root_right_of_root_gcd [comm_semiring k] {ϕ : R →+* k} {f g : polynomial R} {α : k}
  (hα : (euclidean_domain.gcd f g).eval₂ ϕ α = 0) : g.eval₂ ϕ α = 0 :=
by { cases euclidean_domain.gcd_dvd_right f g with p hp,
     rw [hp, polynomial.eval₂_mul, hα, zero_mul] }

lemma root_gcd_iff_root_left_right [comm_semiring k] {ϕ : R →+* k} {f g : polynomial R} {α : k} :
  (euclidean_domain.gcd f g).eval₂ ϕ α = 0 ↔ (f.eval₂ ϕ α = 0) ∧ (g.eval₂ ϕ α = 0) :=
⟨λ h, ⟨root_left_of_root_gcd h, root_right_of_root_gcd h⟩, λ h, eval₂_gcd_eq_zero h.1 h.2⟩

lemma is_root_gcd_iff_is_root_left_right {f g : polynomial R} {α : R} :
  (euclidean_domain.gcd f g).is_root α ↔ f.is_root α ∧ g.is_root α :=
root_gcd_iff_root_left_right

theorem is_coprime_map [field k] (f : R →+* k) :
  is_coprime (p.map f) (q.map f) ↔ is_coprime p q :=
by rw [← gcd_is_unit_iff, ← gcd_is_unit_iff, gcd_map, is_unit_map]

@[simp] lemma map_eq_zero [field k] (f : R →+* k) :
  p.map f = 0 ↔ p = 0 :=
by simp [polynomial.ext_iff, f.map_eq_zero, coeff_map]

lemma map_ne_zero [field k] {f : R →+* k} (hp : p ≠ 0) : p.map f ≠ 0 :=
mt (map_eq_zero f).1 hp

lemma mem_roots_map [field k] {f : R →+* k} {x : k} (hp : p ≠ 0) :
  x ∈ (p.map f).roots ↔ p.eval₂ f x = 0 :=
begin
  rw mem_roots (show p.map f ≠ 0, by exact map_ne_zero hp),
  dsimp only [is_root],
  rw polynomial.eval_map,
end

lemma exists_root_of_degree_eq_one (h : degree p = 1) : ∃ x, is_root p x :=
⟨-(p.coeff 0 / p.coeff 1),
  have p.coeff 1 ≠ 0,
    by rw ← nat_degree_eq_of_degree_eq_some h;
    exact mt leading_coeff_eq_zero.1 (λ h0, by simpa [h0] using h),
  by conv in p { rw [eq_X_add_C_of_degree_le_one (show degree p ≤ 1, by rw h; exact le_refl _)] };
    simp [is_root, mul_div_cancel' _ this]⟩

lemma coeff_inv_units (u : units (polynomial R)) (n : ℕ) :
  ((↑u : polynomial R).coeff n)⁻¹ = ((↑u⁻¹ : polynomial R).coeff n) :=
begin
  rw [eq_C_of_degree_eq_zero (degree_coe_units u), eq_C_of_degree_eq_zero (degree_coe_units u⁻¹),
    coeff_C, coeff_C, inv_eq_one_div],
  split_ifs,
  { rw [div_eq_iff_mul_eq (coeff_coe_units_zero_ne_zero u), coeff_zero_eq_eval_zero,
      coeff_zero_eq_eval_zero, ← eval_mul, ← units.coe_mul, inv_mul_self];
    simp },
  { simp }
end

instance : normalization_monoid (polynomial R) :=
{ norm_unit := λ p, if hp0 : p = 0 then 1
    else ⟨C p.leading_coeff⁻¹, C p.leading_coeff,
      by rw [← C_mul, inv_mul_cancel, C_1];
       exact mt leading_coeff_eq_zero.1 hp0,
      by rw [← C_mul, mul_inv_cancel, C_1];
       exact mt leading_coeff_eq_zero.1 hp0,⟩,
  norm_unit_zero := dif_pos rfl,
  norm_unit_mul := λ p q hp0 hq0, begin
      rw [dif_neg hp0, dif_neg hq0, dif_neg (mul_ne_zero hp0 hq0)],
      apply units.ext,
      show C (leading_coeff (p * q))⁻¹ = C (leading_coeff p)⁻¹ * C (leading_coeff q)⁻¹,
      rw [leading_coeff_mul, mul_inv', C_mul, mul_comm]
    end,
  norm_unit_coe_units := λ u,
    have hu : degree ↑u⁻¹ = 0, from degree_eq_zero_of_is_unit ⟨u⁻¹, rfl⟩,
    begin
      apply units.ext,
      rw [dif_neg (units.ne_zero u)],
      conv_rhs {rw eq_C_of_degree_eq_zero hu},
      refine C_inj.2 _,
      rw [← nat_degree_eq_of_degree_eq_some hu, leading_coeff,
        coeff_inv_units],
      simp
    end, }

lemma monic_normalize (hp0 : p ≠ 0) : monic (normalize p) :=
show leading_coeff (p * ↑(dite _ _ _)) = 1,
by rw dif_neg hp0; exact monic_mul_leading_coeff_inv hp0

lemma coe_norm_unit (hp : p ≠ 0) : (norm_unit p : polynomial R) = C p.leading_coeff⁻¹ :=
show ↑(dite _ _ _) = C p.leading_coeff⁻¹, by rw dif_neg hp; refl

theorem map_dvd_map' [field k] (f : R →+* k) {x y : polynomial R} : x.map f ∣ y.map f ↔ x ∣ y :=
if H : x = 0 then by rw [H, map_zero, zero_dvd_iff, zero_dvd_iff, map_eq_zero]
else by rw [← normalize_dvd_iff, ← @normalize_dvd_iff (polynomial R),
    normalize_apply, normalize_apply,
    coe_norm_unit H, coe_norm_unit (mt (map_eq_zero _).1 H),
    leading_coeff_map, ← f.map_inv, ← map_C, ← map_mul,
    map_dvd_map _ f.injective (monic_mul_leading_coeff_inv H)]

lemma degree_normalize : degree (normalize p) = degree p := by simp

lemma prime_of_degree_eq_one (hp1 : degree p = 1) : prime p :=
have prime (normalize p),
  from prime_of_degree_eq_one_of_monic (hp1 ▸ degree_normalize)
    (monic_normalize (λ hp0, absurd hp1 (hp0.symm ▸ by simp; exact dec_trivial))),
prime_of_associated normalize_associated this

lemma irreducible_of_degree_eq_one (hp1 : degree p = 1) : irreducible p :=
irreducible_of_prime (prime_of_degree_eq_one hp1)

theorem not_irreducible_C (x : R) : ¬irreducible (C x) :=
if H : x = 0 then by { rw [H, C_0], exact not_irreducible_zero }
else λ hx, irreducible.not_unit hx $ is_unit_C.2 $ is_unit_iff_ne_zero.2 H

theorem degree_pos_of_irreducible (hp : irreducible p) : 0 < p.degree :=
lt_of_not_ge $ λ hp0, have _ := eq_C_of_degree_le_zero hp0,
  not_irreducible_C (p.coeff 0) $ this ▸ hp

theorem pairwise_coprime_X_sub {α : Type u} [field α] {I : Type v}
  {s : I → α} (H : function.injective s) :
  pairwise (is_coprime on (λ i : I, polynomial.X - polynomial.C (s i))) :=
λ i j hij, have h : s j - s i ≠ 0, from sub_ne_zero_of_ne $ function.injective.ne H hij.symm,
⟨polynomial.C (s j - s i)⁻¹, -polynomial.C (s j - s i)⁻¹,
by rw [neg_mul_eq_neg_mul_symm, ← sub_eq_add_neg, ← mul_sub, sub_sub_sub_cancel_left,
    ← polynomial.C_sub, ← polynomial.C_mul, inv_mul_cancel h, polynomial.C_1]⟩

/-- If `f` is a polynomial over a field, and `a : K` satisfies `f' a ≠ 0`,
then `f / (X - a)` is coprime with `X - a`.
Note that we do not assume `f a = 0`, because `f / (X - a) = (f - f a) / (X - a)`. -/
lemma is_coprime_of_is_root_of_eval_derivative_ne_zero {K : Type*} [field K]
  (f : polynomial K) (a : K) (hf' : f.derivative.eval a ≠ 0) :
  is_coprime (X - C a : polynomial K) (f /ₘ (X - C a)) :=
begin
  refine or.resolve_left (dvd_or_coprime (X - C a) (f /ₘ (X - C a))
    (irreducible_of_degree_eq_one (polynomial.degree_X_sub_C a))) _,
  contrapose! hf' with h,
  have key : (X - C a) * (f /ₘ (X - C a)) = f - (f %ₘ (X - C a)),
  { rw [eq_sub_iff_add_eq, ← eq_sub_iff_add_eq', mod_by_monic_eq_sub_mul_div],
    exact monic_X_sub_C a },
  replace key := congr_arg derivative key,
  simp only [derivative_X, derivative_mul, one_mul, sub_zero, derivative_sub,
    mod_by_monic_X_sub_C_eq_C_eval, derivative_C] at key,
  have : (X - C a) ∣ derivative f := key ▸ (dvd_add h (dvd_mul_right _ _)),
  rw [← dvd_iff_mod_by_monic_eq_zero (monic_X_sub_C _), mod_by_monic_X_sub_C_eq_C_eval] at this,
  rw [← C_inj, this, C_0],
end

end field
end polynomial
