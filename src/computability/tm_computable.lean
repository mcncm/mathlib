/-
Copyright (c) 2020 Pim Spelier, Daan van Gent. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Pim Spelier, Daan van Gent.
-/

import computability.encoding
import computability.turing_machine
import data.polynomial.basic
import data.polynomial.eval

/-!
# Computable functions

This file contains the definition of a Turing machine with some finiteness conditions
(bundling the definition of TM2 in turing_machine.lean), a definition of when a TM gives a certain
output (in a certain time), and the definition of computability (in polytime or any time function)
of a function between two types that have an encoding (as in encoding.lean).

## Main theorems

- `id_computable_in_poly_time` : a TM + a proof it computes the identity on a type in polytime.
- `id_computable`              : a TM + a proof it computes the identity on a type.

## Implementation notes

To count the execution time of a Turing machine, we have decided to count the number of times the
`step` function is used. Each step executes a statement (of type stmt); this is a function, and
generally contains multiple "fundamental" steps (pushing, popping, so on). However, as functions
only contain a finite number of executions and each one is executed at most once, this execution
time is up to multiplication by a constant the amount of fundamental steps.
-/

open computability

namespace tm2
section

parameters {K : Type} [decidable_eq K] -- index type of stacks
parameters (k₀ k₁ : K) -- input and output stack
parameters (Γ : K → Type) -- type of stack elements
parameters (Λ : Type) (main : Λ) -- type of function labels
parameters (σ : Type) (initial_state : σ) -- type of states of the machine

/-- The type of statements (functions) corresponding to the alphabet Γ, the function labels Λ,
 and the variable states σ. -/
def stmt' := turing.TM2.stmt Γ Λ σ

/-- The type of configurations (which function we're executing, which state we're in, what is on
the stack) corresponding to the alphabet Γ, the function labels Λ, and the variable states σ. -/
def cfg' := turing.TM2.cfg Γ Λ σ

/-- The type of a program, i.e. a function for every function label, corresponding to the
alphabet Γ, the function labels Λ, and the variable states σ. -/
def machine := Λ → stmt'
end
end tm2

/-- A bundled Turing Machine of type 2 (as defined in turing_machine.lean), with an input and
output stack, a main function, an initial state and some finiteness guarantees. -/
structure fin_tm2 :=
 {K : Type}
 [K_decidable_eq : decidable_eq K] -- index type of stacks
 (k₀ k₁ : K) -- input and output stack
 (Γ : K → Type) -- type of stack elements
 (Λ : Type) (main : Λ)  -- type of function labels
 (σ : Type) (initial_state : σ) -- type of states of the machine
 [σ_fin : fintype σ]
 [Γk₀_fin : fintype (Γ k₀)]
 (M : tm2.machine Γ Λ σ) -- the program itself, i.e. one function for every function label

namespace fin_tm2
/-- The type of statements (functions) corresponding to this TM. -/
def stmt (tm : fin_tm2 ) : Type := @tm2.stmt' tm.K tm.K_decidable_eq tm.Γ tm.Λ tm.σ

/-- The type of configurations (functions) corresponding to this TM. -/
def cfg (tm : fin_tm2 ) : Type := @tm2.cfg' tm.K tm.K_decidable_eq tm.Γ tm.Λ tm.σ

/-- The step function corresponding to this TM. -/
@[simp] def step (tm : fin_tm2 ) : tm.cfg → option tm.cfg :=
@turing.TM2.step tm.K tm.K_decidable_eq tm.Γ tm.Λ tm.σ tm.M
end fin_tm2

/-- The initial configuration corresponding to a list in the input alphabet. -/
def init_list (tm : fin_tm2) (s : list (tm.Γ tm.k₀)) : tm.cfg :=
{ l := option.some tm.main,
  var := tm.initial_state,
  stk := λ k, @dite (k = tm.k₀) (tm.K_decidable_eq k tm.k₀) (list (tm.Γ k))
                (λ h, begin rw h, exact s, end)
                (λ _,[]) }

/-- The final configuration corresponding to a list in the output alphabet. -/
def halt_list (tm : fin_tm2) (s : list (tm.Γ tm.k₁)) : tm.cfg :=
{ l := option.none,
  var := tm.initial_state,
  stk := λ k, @dite (k = tm.k₁) (tm.K_decidable_eq k tm.k₁) (list (tm.Γ k))
                (λ h, begin rw h, exact s, end)
                (λ _,[]) }

/-- A "proof" of the fact that f eventually reaches b when repeatedly evaluated on a,
remembering the number of steps it takes. -/
structure evals_to {σ : Type*} (f : σ → option σ) (a : σ) (b : option σ) :=
(steps : ℕ)
(evals_in_steps : ((flip bind f)^[steps] a) = b)

/-- A "proof" of the fact that f eventually reaches b in at most m steps when repeatedly evaluated on a,
remembering the number of steps it takes. -/
structure evals_to_in_time {σ : Type*} (f : σ → option σ) (a : σ) (b : option σ) (m : ℕ) extends evals_to f a b :=
(steps_le_m : steps ≤ m)

/-- Reflexitivy of evals_to in 0 steps. -/
@[refl] def evals_to.refl {σ : Type*} (f : σ → option σ) (a : σ) : evals_to f a a := ⟨0,rfl⟩

/-- Transitivity of evals_to in the sum of the numbers of steps. -/
@[trans] def evals_to.trans {σ : Type*} (f : σ → option σ) (a : σ) (b : σ) (c : option σ)
  (h₁ : evals_to f a b) (h₂ : evals_to f b c) : evals_to f a c :=
⟨h₂.steps + h₁.steps,
 by rw [function.iterate_add_apply,h₁.evals_in_steps,h₂.evals_in_steps]⟩

/-- Reflexitivy of evals_to_in_time in 0 steps. -/
@[refl] def evals_to_in_time.refl {σ : Type*} (f : σ → option σ) (a : σ) : evals_to_in_time f a a 0 :=
⟨evals_to.refl f a, le_refl 0⟩

/-- Transitivity of evals_to_in_time in the sum of the numbers of steps. -/
@[trans]  def evals_to_in_time.trans {σ : Type*} (f : σ → option σ) (a : σ) (b : σ) (c : option σ)
  (m₁ : ℕ) (m₂ : ℕ) (h₁ : evals_to_in_time f a b m₁) (h₂ : evals_to_in_time f b c m₂) :
  evals_to_in_time f a c (m₂ + m₁) :=
⟨evals_to.trans f a b c h₁.to_evals_to h₂.to_evals_to, add_le_add h₂.steps_le_m h₁.steps_le_m⟩

/-- A proof of tm outputting l' when given l. -/
def tm2_outputs (tm : fin_tm2) (l : list (tm.Γ tm.k₀)) (l' : option (list (tm.Γ tm.k₁))) :=
evals_to tm.step (init_list tm l) ((option.map (halt_list tm)) l')

/-- A proof of tm outputting l' when given l in at most m steps. -/
def tm2_outputs_in_time (tm : fin_tm2) (l : list (tm.Γ tm.k₀)) (l' : option (list (tm.Γ tm.k₁))) (m : ℕ) :=
evals_to_in_time tm.step (init_list tm l) ((option.map (halt_list tm)) l') m

/-- The forgetful map, forgetting the upper bound on the number of steps. -/
def tm2_outputs_in_time.to_tm2_outputs {tm : fin_tm2} {l : list (tm.Γ tm.k₀)}
{l' : option (list (tm.Γ tm.k₁))} {m : ℕ} (h : tm2_outputs_in_time tm l l' m) : tm2_outputs tm l l' :=
h.to_evals_to

/-- A Turing machine with input alphabet equivalent to Γ₀ and output alphabat equivalent to Γ₁. -/
private structure computable_by_tm2_aux (Γ₀ Γ₁ : Type) :=
( tm : fin_tm2 )
( input_alphabet : tm.Γ tm.k₀ ≃ Γ₀ )
( output_alphabet : tm.Γ tm.k₁ ≃ Γ₁ )

/-- A Turing machine + a proof it outputs f. -/
structure computable_by_tm2 {α β : Type} (ea : fin_encoding α) (eb : fin_encoding β) (f : α → β)
  extends computable_by_tm2_aux ea.Γ eb.Γ :=
(outputs_f : ∀ a, tm2_outputs tm (list.map input_alphabet.inv_fun (ea.encode a))
  (option.some ((list.map output_alphabet.inv_fun) (eb.encode (f a)))) )

/-- A Turing machine + a time function + a proof it outputs f in at most time(len(input)) steps. -/
structure computable_by_tm2_in_time {α β : Type} (ea : fin_encoding α) (eb : fin_encoding β) (f : α → β)
  extends computable_by_tm2_aux ea.Γ eb.Γ :=
( time: ℕ → ℕ )
( outputs_f : ∀ a, tm2_outputs_in_time tm (list.map input_alphabet.inv_fun (ea.encode a))
  (option.some ((list.map output_alphabet.inv_fun) (eb.encode (f a))))
  (time (ea.encode a).length) )

/-- A Turing machine + a polynomial time function + a proof it outputs f in at most time(len(input)) steps. -/
structure computable_by_tm2_in_poly_time {α β : Type} (ea : fin_encoding α) (eb : fin_encoding β) (f : α → β)
  extends computable_by_tm2_aux ea.Γ eb.Γ :=
( time: polynomial ℕ )
( outputs_f : ∀ a, tm2_outputs_in_time tm (list.map input_alphabet.inv_fun (ea.encode a))
  (option.some ((list.map output_alphabet.inv_fun) (eb.encode (f a))))
  (time.eval (ea.encode a).length) )

/-- A forgetful map, forgetting the time bound on the number of steps. -/
def computable_by_tm2_in_time.to_computable_by_tm2 {α β : Type} {ea : fin_encoding α} {eb : fin_encoding β}
{f : α → β} (h : computable_by_tm2_in_time ea eb f) : computable_by_tm2 ea eb f :=
⟨h.to_computable_by_tm2_aux, λ a, tm2_outputs_in_time.to_tm2_outputs (h.outputs_f a)⟩

/-- A forgetful map, forgetting that the time function is polynomial. -/
def computable_by_tm2_in_poly_time.to_computable_by_tm2_in_time {α β : Type} {ea : fin_encoding α}
{eb : fin_encoding β} {f : α → β} (h : computable_by_tm2_in_poly_time ea eb f) : computable_by_tm2_in_time ea eb f :=
⟨h.to_computable_by_tm2_aux, λ n, h.time.eval n, h.outputs_f⟩

open turing.TM2.stmt

/-- A Turing machine computing the identity on α. -/
def id_computer (α : Type) (ea : fin_encoding α) : fin_tm2 :=
{ K := fin 1,
  k₀ := 0,
  k₁ := 0,
  Γ := λ _, ea.Γ,
  Λ := fin 1,
  main := 0,
  σ := fin 1,
  initial_state := 0,
  Γk₀_fin := ea.Γ_fin,
  M := λ _, halt }

open tm2

noncomputable theory
/-- A proof that the identity map on α is computable in polytime. -/
def id_computable_in_poly_time {α : Type} (ea : fin_encoding α) : @computable_by_tm2_in_poly_time α α ea ea id :=
{ tm := id_computer α ea,
  input_alphabet := equiv.cast rfl,
  output_alphabet := equiv.cast rfl,
  time := 1,
  outputs_f := λ _, { steps := 1,
    evals_in_steps := rfl,
    steps_le_m := by tidy,
}}

/-- A proof that the identity map on α is computable. -/
def id_computable (α : Type) (ea : fin_encoding α) : @computable_by_tm2 α α ea ea id :=
computable_by_tm2_in_time.to_computable_by_tm2 $ computable_by_tm2_in_poly_time.to_computable_by_tm2_in_time $ id_computable_in_poly_time ea