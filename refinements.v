(* Copyright (c) 2012-2014, Robbert Krebbers. *)
(* This file is distributed under the terms of the BSD license. *)
Require Export references memory_basics.

Inductive meminj (Ti : Set) :=
  | meminj_id : meminj Ti
  | meminj_map : indexmap (index * ref Ti) → meminj Ti.
Arguments meminj_id {_}.
Arguments meminj_map {_} _.
Instance meminj_dec {Ti : Set} `{∀ τi1 τi2 : Ti, Decision (τi1 = τi2)}
  (f g : meminj Ti) : Decision (f = g).
Proof. solve_decision. Defined.
Instance meminj_lookup {Ti} : Lookup index (index * ref Ti) (meminj Ti) :=
  λ o f, match f with meminj_id => Some (o, []) | meminj_map m => m !! o end.
Definition meminj_compose {Ti} (f g : meminj Ti) : meminj Ti :=
  match f, g with
  | meminj_id, meminj_id => meminj_id
  | meminj_map m, meminj_id => meminj_map m
  | meminj_id, meminj_map m => meminj_map m
  | meminj_map m1, meminj_map m2 => meminj_map $
     merge (λ yr _ : option (index * ref Ti),
       '(y1,r1) ← yr; '(y2,r2) ← m2 !! y1; Some (y2, r1 ++ r2)) m1 ∅
  end.
Arguments meminj_compose _ !_ !_ /.
Infix "◎" := meminj_compose (at level 40, left associativity) : C_scope.
Notation "(◎)" := meminj_compose (only parsing) : C_scope.

Definition meminj_injective {Ti} (f : meminj Ti) : Prop := ∀ o1 o2 o r1 r2,
  f !! o1 = Some (o,r1) → f !! o2 = Some (o,r2) → o1 = o2 ∨ r1 ⊥ r2.
Instance meminj_subseteq {Ti} : SubsetEq (meminj Ti) := λ f1 f2,
  ∀ o o' r', f1 !! o = Some (o',r') → f2 !! o = Some (o',r').

Section meminj.
Context {Ti : Set}.
Implicit Types f g : meminj Ti.
Implicit Types o : index.
Implicit Types r : ref Ti.

Lemma meminj_eq f g : (∀ o, f !! o = g !! o) → f = g.
Proof.
  intros Hfg. destruct f as [|m1], g as [|m2].
  * done.
  * generalize (Hfg (fresh (dom _ m2))); unfold lookup; simpl.
    by rewrite (proj1 (not_elem_of_dom _ _)) by (apply is_fresh).
  * generalize (Hfg (fresh (dom _ m1))); unfold lookup; simpl.
    by rewrite (proj1 (not_elem_of_dom _ _)) by (apply is_fresh).
  * f_equal. apply map_eq, Hfg.
Qed.

Lemma lookup_meminj_id o : @meminj_id Ti !! o = Some (o, []).
Proof. done. Qed.
Lemma lookup_meminj_id_Some o1 o2 r :
  meminj_id !! o1 = Some (o2,r) ↔ o2 = o1 ∧ r = [].
Proof. rewrite lookup_meminj_id; naive_solver. Qed.
Lemma lookup_meminj_compose f g o :
  (f ◎ g) !! o = '(y1,r1) ← f !! o; '(y2,r2) ← g !! y1; Some (y2,r1 ++ r2).
Proof.
  unfold lookup; destruct f as [|m1], g as [|m2]; csimpl.
  * done.
  * by destruct (_ !! o) as [[??]|].
  * by destruct (_ !! o) as [[??]|]; csimpl; rewrite ?(right_id_L [] (++)).
  * by rewrite lookup_merge by done.
Qed.
Lemma lookup_meminj_compose_Some f g o1 o3 r :
  (f ◎ g) !! o1 = Some (o3,r) ↔
  ∃ o2 r2 r3, f !! o1 = Some (o2,r2) ∧ g !! o2 = Some (o3,r3) ∧ r = r2 ++ r3.
Proof.
  rewrite lookup_meminj_compose. split.
  * intros. destruct (f !! o1) as [[o2 r2]|] eqn:?; simplify_equality'.
    destruct (g !! o2) as [[??]|] eqn:?; naive_solver.
  * by intros (?&?&?&?&?&?); simplify_option_equality.
Qed.

Global Instance: LeftId (@eq (meminj Ti)) meminj_id (◎).
Proof. by intros []. Qed.
Global Instance: RightId (@eq (meminj Ti)) meminj_id (◎).
Proof. by intros []. Qed.
Global Instance: Associative (@eq (meminj Ti)) (◎).
Proof.
  intros f g h. apply meminj_eq. intros o1. rewrite !lookup_meminj_compose.
  destruct (f !! o1) as [[o2 r2]|]; csimpl; [|done].
  rewrite !lookup_meminj_compose.
  destruct (g !! o2) as [[o3 r3]|]; csimpl; [|done].
  by destruct (h !! o3) as [[??]|]; csimpl; rewrite ?(associative_L (++)).
Qed.
Lemma meminj_positive_l f g : f ◎ g = meminj_id → f = meminj_id.
Proof. by destruct f, g. Qed.
Lemma meminj_positive_r f g : f ◎ g = meminj_id → g = meminj_id.
Proof. by destruct f, g. Qed.

Lemma meminj_id_injective : meminj_injective (@meminj_id Ti).
Proof. intros x1 x2 y r1 r2; rewrite !lookup_meminj_id; naive_solver. Qed.
Lemma meminj_compose_injective f g :
  meminj_injective f → meminj_injective g → meminj_injective (f ◎ g).
Proof.
  intros Hf Hg o1 o2 o r1 r2; rewrite !lookup_meminj_compose_Some.
  intros (o1'&r1'&r1''&?&?&->) (o2'&r2'&r2''&?&?&->).
  destruct (decide (o1 = o2)); [by left|].
  destruct (Hg o1' o2' o r1'' r2'') as [->|?]; simplify_equality'; auto.
  { destruct (Hf o1 o2 o2' r1' r2') as [->|?]; auto.
    right. by apply ref_disjoint_here_app_1. }
  right. by apply ref_disjoint_app_l, ref_disjoint_app_r.
Qed.
Lemma meminj_injective_alt f o1 o2 o r1 r2 :
  meminj_injective f → f !! o1 = Some (o,r1) → f !! o2 = Some (o,r2) →
  o1 = o2 ∨ o1 ≠ o2 ∧ r1 ⊥ r2.
Proof.
  intros Hf ??. destruct (decide (o1 = o2)); [by left|].
  destruct (Hf o1 o2 o r1 r2); auto.
Qed.
Lemma meminj_injective_ne f o1 o2 o3 o4 r2 r4 :
  meminj_injective f → f !! o1 = Some (o2,r2) → f !! o3 = Some (o4,r4) →
  o1 ≠ o3 → o2 ≠ o4 ∨ o2 = o4 ∧ r2 ⊥ r4.
Proof.
  intros Hf ???. destruct (decide (o2 = o4)) as [->|]; auto.
  destruct (Hf o1 o3 o4 r2 r4); auto.
Qed.
Global Instance: PartialOrder ((⊆) : relation (meminj Ti)).
Proof.
  repeat split.
  * by intros f o o' r'.
  * intros f1 f2 f3. unfold subseteq, meminj_subseteq. naive_solver.
  * intros f1 f2; unfold subseteq, meminj_subseteq; intros.
    apply meminj_eq. intros o. apply option_eq. intros [o' r']; naive_solver.
Qed.
End meminj.

Class RefineM Ti E A := refineM: E → meminj Ti → relation A.
Class Refine Ti E A :=
  refine: E → meminj Ti → memenv Ti → memenv Ti → A → A → Prop.
Class RefineTM Ti E T A := refineTM: E → meminj Ti → A → A → T → Prop.
Class RefineT Ti E T A :=
  refineT: E → meminj Ti → memenv Ti → memenv Ti → A → A → T → Prop.
Class PathRefine Ti E T1 T2 A :=
  path_refine: E → meminj Ti → memenv Ti → memenv Ti → A → A → T1 → T2 → Prop.
Instance: Params (@refineM) 4.
Instance: Params (@refine) 4.
Instance: Params (@refineTM) 5.
Instance: Params (@refineT) 5.
Instance: Params (@path_refine) 6.

Notation "X ⊑{ Γ , f } Y" := (refineM Γ f X Y)
  (at level 70, format "X  ⊑{ Γ , f }  Y") : C_scope.
Notation "X ⊑{ Γ } Y" := (X ⊑{Γ,meminj_id} Y)
  (at level 70, format "X  ⊑{ Γ }  Y") : C_scope.

Notation "X ⊑{ Γ , f } Y : τ" := (refineTM Γ f X Y τ)
  (at level 70, Y at next level,
   format "X  ⊑{ Γ , f }  Y  :  τ") : C_scope.
Notation "X ⊑{ Γ } Y : τ" := (X ⊑{Γ,meminj_id} Y : τ)
  (at level 70, Y at next level, format "X  ⊑{ Γ }  Y  :  τ") : C_scope.

Notation "X ⊑{ Γ , f @ m1 ↦ m2 } Y" := (refine Γ f m1 m2 X Y)
  (at level 70, format "X  ⊑{ Γ , f  @  m1 ↦ m2 }  Y") : C_scope.
Notation "Xs ⊑{ Γ , f @ m1 ↦ m2 }* Ys" := (Forall2 (refine Γ f m1 m2) Xs Ys)
  (at level 70, format "Xs  ⊑{ Γ , f  @  m1 ↦ m2 }*  Ys") : C_scope.
Notation "Xss ⊑{ Γ , f @ m1 ↦ m2 }2** Yss" :=
  (Forall2 (λ Xs Ys, Xs.2 ⊑{Γ,f @ m1↦m2}* Ys.2) Xss Yss)
  (at level 70, format "Xss  ⊑{ Γ , f  @  m1 ↦ m2 }2**  Yss") : C_scope.
Notation "X ⊑{ Γ @ m } Y" := (X ⊑{Γ,meminj_id @ m↦m} Y)
  (at level 70, format "X  ⊑{ Γ  @  m }  Y") : C_scope.
Notation "Xs ⊑{ Γ @ m }* Ys" := (Xs ⊑{Γ,meminj_id @ m↦m}* Ys)
  (at level 70, format "Xs  ⊑{ Γ  @  m }*  Ys") : C_scope.
Notation "Xss ⊑{ Γ @ m }2** Yss" := (Xss ⊑{Γ,meminj_id @ m↦m}2** Yss)
  (at level 70, format "Xss  ⊑{ Γ  @  m }2**  Yss") : C_scope.

Notation "X ⊑{ Γ , f @ m1 ↦ m2 } Y : τ" := (refineT Γ f m1 m2 X Y τ)
  (at level 70, Y at next level,
   format "X  ⊑{ Γ , f  @  m1 ↦ m2 }  Y  :  τ") : C_scope.
Notation "Xs ⊑{ Γ , f @ m1 ↦ m2 }* Ys : τ" :=
  (Forall2 (λ X Y, X ⊑{Γ,f @ m1↦m2} Y : τ) Xs Ys)
  (at level 70, Ys at next level,
   format "Xs  ⊑{ Γ , f  @  m1 ↦ m2 }*  Ys  :  τ") : C_scope.
Notation "Xs ⊑{ Γ , f @ m1 ↦ m2 }* Ys :* τs" :=
  (Forall3 (refineT Γ f m1 m2) Xs Ys τs)
  (at level 70, Ys at next level,
   format "Xs  ⊑{ Γ , f  @  m1 ↦ m2 }*  Ys  :*  τs") : C_scope.
Notation "Xs ⊑{ Γ , f @ m1 ↦ m2 }1* Ys :* τs" :=
  (Forall3 (λ X Y τ, X.1 ⊑{Γ,f @ m1↦m2} Y.1 : τ) Xs Ys τs)
  (at level 70, Ys at next level,
   format "Xs  ⊑{ Γ , f  @  m1 ↦ m2 }1*  Ys  :*  τs") : C_scope.
Notation "X ⊑{ Γ @ m } Y : τ" := (X ⊑{Γ,meminj_id @ m↦m} Y : τ)
  (at level 70, Y at next level,
   format "X  ⊑{ Γ  @  m }  Y  :  τ") : C_scope.
Notation "Xs ⊑{ Γ @ m }* Ys : τ" := (Xs ⊑{Γ,meminj_id @ m↦m}* Ys : τ)
  (at level 70, Ys at next level,
   format "Xs  ⊑{ Γ  @  m }*  Ys  :  τ") : C_scope.
Notation "Xs ⊑{ Γ @ m }* Ys :* τs" := (Xs ⊑{Γ,meminj_id @ m↦m}* Ys :* τs)
  (at level 70, Ys at next level,
   format "Xs  ⊑{ Γ  @  m }*  Ys  :*  τs") : C_scope.
Notation "Xs ⊑{ Γ @ m }1* Ys :* τs" := (Xs ⊑{Γ,meminj_id @ m↦m}1* Ys :* τs)
  (at level 70, Ys at next level,
   format "Xs  ⊑{ Γ  @  m }1*  Ys  :*  τs") : C_scope.

Notation "X ⊑{ Γ , f @ m1 ↦ m2 } Y : τ ↣ σ" := (path_refine Γ f m1 m2 X Y τ σ)
  (at level 70, Y at next level, τ at next level, σ at next level,
   format "X  ⊑{ Γ , f  @  m1 ↦ m2 }  Y  :  τ  ↣  σ") : C_scope.
Notation "X ⊑{ Γ @ m } Y : τ ↣ σ" := (X ⊑{ Γ , meminj_id @ m ↦ m } Y : τ ↣ σ)
  (at level 70, Y at next level, τ at next level, σ at next level,
   format "X  ⊑{ Γ  @  m }  Y  :  τ  ↣  σ") : C_scope.

Ltac refine_constructor :=
  intros; match goal with
  | |- refineTM (RefineTM:=?T) ?Γ ?f _ _ _ =>
    let T' := eval hnf in (T Γ f) in
    econstructor; change T' with (refineTM (RefineTM:=T) Γ f)
  | |- refineT (RefineT:=?T) ?Γ ?f ?m1 ?m2 _ _ _ =>
    let T' := eval hnf in (T Γ f m1 m2) in
    econstructor; change T' with (refineT (RefineT:=T) Γ f m1 m2)
  | |- path_refine (PathRefine:=?T) ?Γ ?f ?m1 ?m2 _ _ _ _ =>
    let T' := eval hnf in (T Γ f m1 m2) in
    econstructor; change T' with (path_refine (PathRefine:=T) Γ f m1 m2)
  end.
Ltac refine_inversion H :=
  match type of H with
  | refineTM (RefineTM:=?T) ?Γ ?f _ _ _ =>
    let T' := eval hnf in (T Γ f) in
    inversion H; clear H; simplify_equality'; try contradiction;
    try change T' with (refineTM (RefineTM:=T) Γ f) in *
  | refineT (RefineT:=?T) ?Γ ?f ?m1 ?m2 _ _ _ =>
    let T' := eval hnf in (T Γ f m1 m2) in
    inversion H; clear H; simplify_equality'; try contradiction;
    try change T' with (refineT (RefineT:=T) Γ f m1 m2) in *
  | path_refine (PathRefine:=?T) ?Γ ?f ?m1 ?m2 _ _ _ _ =>
    let T' := eval hnf in (T Γ f m1 m2) in
    inversion H; clear H; simplify_equality'; try contradiction;
    try change T' with (path_refine (PathRefine:=T) Γ f m1 m2) in *
  end.
Ltac refine_inversion_all :=
  repeat match goal with
  | H : ?X ⊑{_,_} ?Y : _ |- _ =>
     first [is_var X; is_var Y; fail 1|refine_inversion H]
  | H : ?X ⊑{_,_@_↦_} ?Y : _ |- _ =>
     first [is_var X; is_var Y; fail 1|refine_inversion H]
  | H : ?X ⊑{_,_@_↦_} ?Y : _ ↣ _ |- _ =>
     first [is_var X; is_var Y; fail 1|refine_inversion H]
  end.

Instance memenv_refine `{Env Ti} :
    RefineM Ti (env Ti) (memenv Ti) := λ Γ f Γm1 Γm2,
  (**i 1.) *) meminj_injective f ∧
  (**i 2.) *) (∀ o1 o2 r τ1, f !! o1 = Some (o2,r) →
    Γm1 ⊢ o1 : τ1 → ∃ τ2, Γm2 ⊢ o2 : τ2 ∧ Γ ⊢ r : τ2 ↣ τ1) ∧
  (**i 3.) *) (∀ o1 o2 r τ2, f !! o1 = Some (o2,r) →
    Γm2 ⊢ o2 : τ2 → ∃ τ1, Γm1 ⊢ o1 : τ1 ∧ Γ ⊢ r : τ2 ↣ τ1) ∧
  (**i 4.) *) (∀ o1 o2 r, f !! o1 = Some (o2,r) →
    index_alive Γm1 o1 → index_alive Γm2 o2).
Record meminj_extend {Ti} (f f' : meminj Ti) (Γm1 Γm2 : memenv Ti) := {
  meminj_extend_left o τ : Γm1 ⊢ o : τ → f' !! o = f !! o;
  meminj_extend_right o o' r τ :
    Γm2 ⊢ o' : τ → f' !! o = Some (o',r) → f !! o = Some (o',r)
}.

Section memenv_refine.
Context `{EnvSpec Ti}.
Implicit Types f : meminj Ti.
Lemma memenv_refine_injective Γ f Γm1 Γm2: Γm1 ⊑{Γ,f} Γm2 → meminj_injective f.
Proof. by intros [??]. Qed.
Lemma memenv_refine_id Γ Γm : Γm ⊑{Γ} Γm.
Proof.
  repeat split; intros until 0; rewrite ?lookup_meminj_id;
    naive_solver eauto using meminj_id_injective, ref_typed_nil_2.
Qed.
Lemma memenv_refine_compose Γ f1 f2 Γm1 Γm2 Γm3 :
  ✓ Γ → Γm1 ⊑{Γ,f1} Γm2 → Γm2 ⊑{Γ,f2} Γm3 → Γm1 ⊑{Γ,f1 ◎ f2} Γm3.
Proof.
  intros ? (?&?&?&?) (?&?&?&?);
    repeat split; eauto using meminj_compose_injective.
  * intros o1 o3 r τ1; rewrite lookup_meminj_compose_Some;
      intros (o2&r2&r3&?&?&->) ?; setoid_rewrite ref_typed_app; naive_solver.
  * intros o1 o3 r τ2; rewrite lookup_meminj_compose_Some;
      intros (o2&r2&r3&?&?&->) ?; setoid_rewrite ref_typed_app; naive_solver.
  * intros o1 o3 r; rewrite lookup_meminj_compose_Some; naive_solver.
Qed.
Lemma memenv_refine_weaken Γ Γ' f Γm1 Γm2 :
  ✓ Γ → Γm1 ⊑{Γ,f} Γm2 → Γ ⊆ Γ' → Γm1 ⊑{Γ',f} Γm2.
Proof.
  intros ? (?&Htyped&Htyped'&?) ?; split;
    naive_solver eauto using ref_typed_weaken.
Qed.
Lemma meminj_extend_reflexive f Γm1 Γm2 : meminj_extend f f Γm1 Γm2.
Proof. by split. Qed.
Lemma meminj_extend_transitive f f' f'' Γm1 Γm2 Γm1' Γm2' :
  meminj_extend f f' Γm1 Γm2 → meminj_extend f' f'' Γm1' Γm2' →
  Γm1 ⊆{⇒} Γm1' → Γm2 ⊆{⇒} Γm2' → meminj_extend f f'' Γm1 Γm2.
Proof. intros [??] [??] [? _] [? _]; split; eauto using eq_trans. Qed.
Lemma meminj_extend_compose f g Γm1 Γm2 :
  meminj_extend meminj_id f Γm1 Γm1 →
  meminj_extend meminj_id g Γm2 Γm2 → Γm1 ⊆{⇒} Γm2 →
  meminj_extend meminj_id (g ◎ f) Γm1 Γm1.
Proof.
  intros [Hf Hf'] [Hg Hg'] ?; split.
  * intros o τ ?; apply lookup_meminj_compose_Some.
    eexists o, [], []; eauto 8 using memenv_extend_typed.
  * intros o o'' r τ ?; rewrite lookup_meminj_compose_Some.
    intros (o'&r'&r''&Ho&Ho'&->). eapply Hf' in Ho'; eauto.
    rewrite lookup_meminj_id in Ho'; simplify_equality.
    rewrite (right_id_L [] (++)); eauto using memenv_extend_typed.
Qed.
End memenv_refine.
