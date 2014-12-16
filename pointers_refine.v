(* Copyright (c) 2012-2014, Robbert Krebbers. *)
(* This file is distributed under the terms of the BSD license. *)
Require Export pointers addresses_refine.
Local Open Scope ctype_scope.

Inductive ptr_refine' `{Env Ti} (Γ : env Ti) (α : bool) (f : meminj Ti)
     (Γm1 Γm2 : memenv Ti) : ptr Ti → ptr Ti → type Ti → Prop :=
  | NULL_refine τ :
     ptr_type_valid Γ τ → ptr_refine' Γ α f Γm1 Γm2 (NULL τ) (NULL τ) τ
  | Ptr_refine a1 a2 τ :
     a1 ⊑{Γ,α,f@Γm1↦Γm2} a2 : τ →
     ptr_refine' Γ α f Γm1 Γm2 (Ptr a1) (Ptr a2) τ.
Instance ptr_refine `{Env Ti} :
  RefineT Ti (env Ti) (type Ti) (ptr Ti) := ptr_refine'.

Section pointers.
Context `{EnvSpec Ti}.
Implicit Types Γ : env Ti.
Implicit Types Γm : memenv Ti.
Implicit Types α : bool.
Implicit Types τ : type Ti.
Implicit Types a : addr Ti.
Implicit Types p : ptr Ti.

Lemma ptr_refine_typed_l Γ α f Γm1 Γm2 p1 p2 σ :
  ✓ Γ → p1 ⊑{Γ,α,f@Γm1↦Γm2} p2 : σ → (Γ,Γm1) ⊢ p1 : σ.
Proof. destruct 2; constructor; eauto using addr_refine_typed_l. Qed.
Lemma ptr_refine_typed_r Γ α f Γm1 Γm2 p1 p2 σ :
  ✓ Γ → p1 ⊑{Γ,α,f@Γm1↦Γm2} p2 : σ → (Γ,Γm2) ⊢ p2 : σ.
Proof. destruct 2; constructor; eauto using addr_refine_typed_r. Qed.
Lemma ptr_refine_type_of_l Γ α f Γm1 Γm2 p1 p2 σ :
  p1 ⊑{Γ,α,f@Γm1↦Γm2} p2 : σ → type_of p1 = σ.
Proof. destruct 1; simpl; eauto using addr_refine_type_of_l. Qed.
Lemma ptr_refine_type_of_r Γ α f Γm1 Γm2 p1 p2 σ :
  p1 ⊑{Γ,α,f@Γm1↦Γm2} p2 : σ → type_of p2 = σ.
Proof. destruct 1; simpl; eauto using addr_refine_type_of_r. Qed.
Lemma ptr_refine_frozen Γ α f Γm1 Γm2 p1 p2 σ :
  p1 ⊑{Γ,α,f@Γm1↦Γm2} p2 : σ → frozen p2 → frozen p1.
Proof.
  unfold frozen. destruct 1; simpl; auto.
  rewrite !(injective_iff Ptr). eapply addr_refine_frozen; eauto.
Qed.
Lemma ptr_refine_id Γ α Γm p σ : (Γ,Γm) ⊢ p : σ → p ⊑{Γ,α@Γm} p : σ.
Proof. destruct 1; constructor; eauto using addr_refine_id. Qed.
Lemma ptr_refine_compose Γ α1 α2 f1 f2 Γm1 Γm2 Γm3 p1 p2 p3 σ σ' :
  ✓ Γ → p1 ⊑{Γ,α1,f1@Γm1↦Γm2} p2 : σ → p2 ⊑{Γ,α2,f2@Γm2↦Γm3} p3 : σ' →
  p1 ⊑{Γ,α1||α2,f2 ◎ f1@Γm1↦Γm3} p3 : σ.
Proof.
  destruct 2; inversion_clear 1; constructor; eauto using addr_refine_compose.
Qed.
Lemma ptr_refine_inverse Γ f Γm1 Γm2 p1 p2 σ :
  p1 ⊑{Γ,false,f@Γm1↦Γm2} p2 : σ →
  p2 ⊑{Γ,false,meminj_inverse f@Γm2↦Γm1} p1 : σ.
Proof. destruct 1; constructor; eauto using addr_refine_inverse. Qed.
Lemma ptr_refine_weaken Γ Γ' α α' f f' Γm1 Γm2 Γm1' Γm2' p1 p2 σ :
  ✓ Γ → p1 ⊑{Γ,α,f@Γm1↦Γm2} p2 : σ → Γ ⊆ Γ' → (α → α') →
  Γm1' ⊑{Γ',α',f'} Γm2' → Γm1 ⇒ₘ Γm1' →
  meminj_extend f f' Γm1 Γm2 → p1 ⊑{Γ',α',f'@Γm1'↦Γm2'} p2 : σ.
Proof.
  destruct 2; constructor;
    eauto using ptr_type_valid_weaken, addr_refine_weaken.
Qed.
Lemma ptr_refine_unique_l Γ f Γm1 Γm2 p1 p2 p3 σ2 σ3 :
  p1 ⊑{Γ,false,f@Γm1↦Γm2} p3 : σ2 → p2 ⊑{Γ,false,f@Γm1↦Γm2} p3 : σ3 → p1 = p2.
Proof.
  destruct 1; inversion_clear 1; f_equal; eauto using addr_refine_unique_l.
Qed.
Lemma ptr_refine_unique_r Γ α f Γm1 Γm2 p1 p2 p3 σ2 σ3 :
  p1 ⊑{Γ,α,f@Γm1↦Γm2} p2 : σ2 → p1 ⊑{Γ,α,f@Γm1↦Γm2} p3 : σ3 →
  frozen p2 → frozen p3 → p2 = p3.
Proof.
  unfold frozen. destruct 1; inversion_clear 1; intros; simplify_equality';
    f_equal; eauto using addr_refine_unique_r.
Qed.
Lemma ptr_freeze_refine_l Γ Γm p σ :
  (Γ,Γm) ⊢ p : σ → freeze true p ⊑{Γ,true@Γm} p : σ.
Proof. destruct 1; refine_constructor; eauto using addr_freeze_refine_l. Qed.
Lemma ptr_freeze_refine Γ α f Γm1 Γm2 p1 p2 σ :
  p1 ⊑{Γ,α,f@Γm1↦Γm2} p2 : σ →
  freeze true p1 ⊑{Γ,α,f@Γm1↦Γm2} freeze true p2 : σ.
Proof. destruct 1; simpl; constructor; eauto using addr_freeze_refine. Qed.
Lemma ptr_alive_refine Γ α f Γm1 Γm2 p1 p2 σ :
  ptr_alive Γm1 p1 → p1 ⊑{Γ,α,f@Γm1↦Γm2} p2 : σ → ptr_alive Γm2 p2.
Proof. destruct 2; simpl in *; eauto using addr_alive_refine. Qed.
End pointers.
