(* Copyright (c) 2012-2015, Robbert Krebbers. *)
(* This file is distributed under the terms of the BSD license. *)
(** This files implements an efficient implementation of finite maps whose keys
range over Coq's data type of positive binary naturals [positive]. The
implementation is based on Xavier Leroy's implementation of radix-2 search
trees (uncompressed Patricia trees) and guarantees logarithmic-time operations.
However, we extend Leroy's implementation by packing the trees into a Sigma
type such that canonicity of representation is ensured. This is necesarry for
Leibniz equality to become extensional. *)
Require Import PArith mapset.
Require Export fin_maps.

Local Open Scope positive_scope.
Local Hint Extern 0 (@eq positive _ _) => congruence.
Local Hint Extern 0 (¬@eq positive _ _) => congruence.

(** * The tree data structure *)
(** The data type [Pmap_raw] specifies radix-2 search trees. These trees do
not ensure canonical representations of maps. For example the empty map can
be represented as a binary tree of an arbitrary size that contains [None] at
all nodes. *)
Inductive Pmap_raw (A : Type) : Type :=
  | PLeaf: Pmap_raw A
  | PNode: Pmap_raw A → option A → Pmap_raw A → Pmap_raw A.
Arguments PLeaf {_}.
Arguments PNode {_} _ _ _.

Instance Pmap_raw_eq_dec `{∀ x y : A, Decision (x = y)} (x y : Pmap_raw A) :
  Decision (x = y).
Proof. solve_decision. Defined.

(** The following decidable predicate describes non empty trees. *)
Inductive Pmap_ne {A} : Pmap_raw A → Prop :=
  | Pmap_ne_val l x r : Pmap_ne (PNode l (Some x) r)
  | Pmap_ne_l l r : Pmap_ne l → Pmap_ne (PNode l None r)
  | Pmap_ne_r l r : Pmap_ne r → Pmap_ne (PNode l None r).
Local Hint Constructors Pmap_ne.

Instance Pmap_ne_dec {A} : ∀ t : Pmap_raw A, Decision (Pmap_ne t).
Proof.
 refine (
  fix go t :=
  match t return Decision (Pmap_ne t) with
  | PLeaf => right _
  | PNode _ (Some x) _ => left _
  | PNode l Node r => cast_if_or (go l) (go r)
  end); clear go; abstract first [constructor; by auto|by inversion 1].
Defined.

(** The following predicate describes well well formed trees. A tree is well
formed if it is empty or if all nodes at the bottom contain a value. *)
Inductive Pmap_wf {A} : Pmap_raw A → Prop :=
  | Pmap_wf_leaf : Pmap_wf PLeaf
  | Pmap_wf_node l x r : Pmap_wf l → Pmap_wf r → Pmap_wf (PNode l (Some x) r)
  | Pmap_wf_empty l r :
     Pmap_wf l → Pmap_wf r → (Pmap_ne l ∨ Pmap_ne r) → Pmap_wf (PNode l None r).
Local Hint Constructors Pmap_wf.

Instance Pmap_wf_dec {A} : ∀ t : Pmap_raw A, Decision (Pmap_wf t).
Proof.
 refine (
  fix go t :=
  match t return Decision (Pmap_wf t) with
  | PLeaf => left _
  | PNode l (Some x) r => cast_if_and (go l) (go r)
  | PNode l Node r =>
     cast_if_and3 (decide (Pmap_ne l ∨ Pmap_ne r)) (go l) (go r)
  end); clear go; abstract first [constructor; by auto|by inversion 1].
Defined.

(** Now we restrict the data type of trees to those that are well formed and
thereby obtain a data type that ensures canonicity. *)
Inductive Pmap (A : Type) : Type := PMap {
  pmap_car : Pmap_raw A;
  pmap_bool_prf : bool_decide (Pmap_wf pmap_car)
}.
Arguments PMap {_} _ _.
Arguments pmap_car {_} _.
Arguments pmap_bool_prf {_} _.
Definition PMap' {A} (t : Pmap_raw A) (p : Pmap_wf t) : Pmap A :=
  PMap t (bool_decide_pack _ p).
Definition pmap_prf {A} (m : Pmap A) : Pmap_wf (pmap_car m) :=
  bool_decide_unpack _ (pmap_bool_prf m).
Lemma Pmap_eq {A} (m1 m2 : Pmap A) : m1 = m2 ↔ pmap_car m1 = pmap_car m2.
Proof.
  split; [by intros ->|intros]; destruct m1 as [t1 ?], m2 as [t2 ?].
  simplify_equality'; f_equal; apply proof_irrel.
Qed.

(** * Operations on the data structure *)
Global Instance Pmap_eq_dec `{∀ x y : A, Decision (x = y)}
    (m1 m2 : Pmap A) : Decision (m1 = m2) :=
  match Pmap_raw_eq_dec (pmap_car m1) (pmap_car m2) with
  | left H => left (proj2 (Pmap_eq m1 m2) H)
  | right H => right (H ∘ proj1 (Pmap_eq m1 m2))
  end.
Instance Pempty_raw {A} : Empty (Pmap_raw A) := PLeaf.
Global Instance Pempty {A} : Empty (Pmap A) := PMap' ∅ Pmap_wf_leaf.

Instance Plookup_raw {A} : Lookup positive A (Pmap_raw A) :=
  fix go (i : positive) (t : Pmap_raw A) {struct t} : option A :=
  match t with
  | PLeaf => None
  | PNode l o r =>
     match i with
     | 1 => o | i~0 => @lookup _ _ _ go i l | i~1 => @lookup _ _ _ go i r
     end
  end.
Instance Plookup {A} : Lookup positive A (Pmap A) := λ i m, pmap_car m !! i.

Lemma Plookup_empty {A} i : (∅ : Pmap_raw A) !! i = None.
Proof. by destruct i. Qed.

Lemma Pmap_ne_lookup {A} (t : Pmap_raw A) : Pmap_ne t → ∃ i x, t !! i = Some x.
Proof.
  induction 1 as [? x ?| l r ? IHl | l r ? IHr].
  * intros. by exists 1, x.
  * destruct IHl as [i [x ?]]. by exists (i~0), x.
  * destruct IHr as [i [x ?]]. by exists (i~1), x.
Qed.

Lemma Pmap_wf_eq_get {A} (t1 t2 : Pmap_raw A) :
  Pmap_wf t1 → Pmap_wf t2 → (∀ i, t1 !! i = t2 !! i) → t1 = t2.
Proof.
  intros t1wf. revert t2.
  induction t1wf as [| ? x ? ? IHl ? IHr | l r ? IHl ? IHr Hne1].
  * destruct 1 as [| | ???? [?|?]]; intros Hget.
    + done.
    + discriminate (Hget 1).
    + destruct (Pmap_ne_lookup l) as [i [??]]; trivial.
      specialize (Hget (i~0)). simpl in *. congruence.
    + destruct (Pmap_ne_lookup r) as [i [??]]; trivial.
      specialize (Hget (i~1)). simpl in *. congruence.
  * destruct 1; intros Hget.
    + discriminate (Hget xH).
    + f_equal.
      - apply IHl; trivial. intros i. apply (Hget (i~0)).
      - apply (Hget 1).
      - apply IHr; trivial. intros i. apply (Hget (i~1)).
    + specialize (Hget 1). simpl in *. congruence.
  * destruct 1; intros Hget.
    + destruct Hne1.
      - destruct (Pmap_ne_lookup l) as [i [??]]; trivial.
        specialize (Hget (i~0)); simpl in *. congruence.
      - destruct (Pmap_ne_lookup r) as [i [??]]; trivial.
        specialize (Hget (i~1)); simpl in *. congruence.
    + specialize (Hget 1); simpl in *. congruence.
    + f_equal.
      - apply IHl; trivial. intros i. apply (Hget (i~0)).
      - apply IHr; trivial. intros i. apply (Hget (i~1)).
Qed.

Fixpoint Psingleton_raw {A} (i : positive) (x : A) : Pmap_raw A :=
  match i with
  | 1 => PNode PLeaf (Some x) PLeaf
  | i~0 => PNode (Psingleton_raw i x) None PLeaf
  | i~1 => PNode PLeaf None (Psingleton_raw i x)
  end.
Lemma Psingleton_ne {A} i (x : A) : Pmap_ne (Psingleton_raw i x).
Proof. induction i; simpl; intuition. Qed.
Local Hint Resolve Psingleton_ne.
Lemma Psingleton_wf {A} i (x : A) : Pmap_wf (Psingleton_raw i x).
Proof. induction i; simpl; intuition. Qed.
Local Hint Resolve Psingleton_wf.
Lemma Plookup_singleton {A} i (x : A) : Psingleton_raw i x !! i = Some x.
Proof. by induction i. Qed.
Lemma Plookup_singleton_ne {A} i j (x : A) :
  i ≠ j → Psingleton_raw i x !! j = None.
Proof. revert j. induction i; intros [?|?|]; simpl; auto. congruence. Qed.

Definition PNode_canon {A} (l : Pmap_raw A) (o : option A) (r : Pmap_raw A) :=
  match l, o, r with PLeaf, None, PLeaf => PLeaf | _, _, _ => PNode l o r end.
Lemma PNode_canon_wf {A} (l : Pmap_raw A) (o : option A) (r : Pmap_raw A) :
  Pmap_wf l → Pmap_wf r → Pmap_wf (PNode_canon l o r).
Proof. intros H1 H2. destruct H1, o, H2; simpl; intuition. Qed.
Local Hint Resolve PNode_canon_wf.
Lemma PNode_canon_lookup_xH {A} (l : Pmap_raw A) o (r : Pmap_raw A) :
  PNode_canon l o r !! 1 = o.
Proof. by destruct l,o,r. Qed.
Lemma PNode_canon_lookup_xO {A} (l : Pmap_raw A) o (r : Pmap_raw A) i :
  PNode_canon l o r !! i~0 = l !! i.
Proof. by destruct l,o,r. Qed.
Lemma PNode_canon_lookup_xI {A} (l : Pmap_raw A) o (r : Pmap_raw A) i :
  PNode_canon l o r !! i~1 = r !! i.
Proof. by destruct l,o,r. Qed.
Ltac PNode_canon_rewrite := repeat first
  [ rewrite PNode_canon_lookup_xH | rewrite PNode_canon_lookup_xO
  | rewrite PNode_canon_lookup_xI].

Instance Ppartial_alter_raw {A} : PartialAlter positive A (Pmap_raw A) :=
  fix go f i t {struct t} : Pmap_raw A :=
  match t with
  | PLeaf => match f None with None => PLeaf | Some x => Psingleton_raw i x end
  | PNode l o r =>
     match i with
     | 1 => PNode_canon l (f o) r
     | i~0 => PNode_canon (@partial_alter _ _ _ go f i l) o r
     | i~1 => PNode_canon l o (@partial_alter _ _ _ go f i r)
     end
  end.
Lemma Ppartial_alter_wf {A} f i (t : Pmap_raw A) :
  Pmap_wf t → Pmap_wf (partial_alter f i t).
Proof.
  intros twf. revert i. induction twf.
  * unfold partial_alter. simpl. case (f None); intuition.
  * intros [?|?|]; simpl; intuition.
  * intros [?|?|]; simpl; intuition.
Qed.
Instance Ppartial_alter {A} : PartialAlter positive A (Pmap A) := λ f i m,
  PMap' (partial_alter f i (pmap_car m)) (Ppartial_alter_wf f i _ (pmap_prf m)).
Lemma Plookup_alter {A} f i (t : Pmap_raw A) :
  partial_alter f i t !! i = f (t !! i).
Proof.
  revert i. induction t.
  * intros i. change (match f None with Some x => Psingleton_raw i x
      | None => PLeaf end !! i = f None); destruct (f None).
    + intros. apply Plookup_singleton.
    + by destruct i.
  * intros [?|?|]; simpl; by PNode_canon_rewrite.
Qed.
Lemma Plookup_alter_ne {A} f i j (t : Pmap_raw A) :
  i ≠ j → partial_alter f i t !! j = t !! j.
Proof.
  revert i j. induction t as [|l IHl ? r IHr].
  * intros. change (match f None with Some x => Psingleton_raw i x
      | None => PLeaf end !! j = None); destruct (f None); [|done].
    intros. by apply Plookup_singleton_ne.
  * intros [?|?|] [?|?|]; simpl; PNode_canon_rewrite; auto; congruence.
Qed.

Instance Pfmap_raw : FMap Pmap_raw := λ A B f,
  fix go t :=
  match t with
  | PLeaf => PLeaf | PNode l x r => PNode (go l) (f <$> x) (go r)
  end.
Lemma Pfmap_ne `(f : A → B) (t : Pmap_raw A) : Pmap_ne t → Pmap_ne (fmap f t).
Proof. induction 1; csimpl; auto. Qed.
Local Hint Resolve Pfmap_ne.
Lemma Pfmap_wf `(f : A → B) (t : Pmap_raw A) : Pmap_wf t → Pmap_wf (fmap f t).
Proof. induction 1; csimpl; intuition. Qed.
Global Instance Pfmap : FMap Pmap := λ A B f m,
  PMap' (f <$> pmap_car m) (Pfmap_wf f _ (pmap_prf m)).
Lemma Plookup_fmap {A B} (f : A → B) (t : Pmap_raw A) i :
  (f <$> t) !! i = f <$> t !! i.
Proof. revert i. induction t. done. by intros [?|?|]; simpl. Qed.

Fixpoint Pto_list_raw {A} (j : positive) (t : Pmap_raw A)
    (acc : list (positive * A)) : list (positive * A) :=
  match t with
  | PLeaf => acc
  | PNode l o r => default [] o (λ x, [(Preverse j, x)]) ++
     Pto_list_raw (j~0) l (Pto_list_raw (j~1) r acc)
  end%list.
Lemma Pelem_of_to_list {A} (t : Pmap_raw A) j i acc x :
  (i,x) ∈ Pto_list_raw j t acc ↔
    (∃ i', i = i' ++ Preverse j ∧ t !! i' = Some x) ∨ (i,x) ∈ acc.
Proof.
  split.
  { revert j acc. induction t as [|l IHl [y|] r IHr]; intros j acc; simpl.
    * by right.
    * rewrite elem_of_cons. intros [?|?]; simplify_equality.
      { left; exists 1. by rewrite (left_id_L 1 (++))%positive. }
      destruct (IHl (j~0) (Pto_list_raw j~1 r acc)) as [(i'&->&?)|?]; auto.
      { left; exists (i' ~ 0). by rewrite Preverse_xO, (associative_L _). }
      destruct (IHr (j~1) acc) as [(i'&->&?)|?]; auto.
      left; exists (i' ~ 1). by rewrite Preverse_xI, (associative_L _).
    * intros.
      destruct (IHl (j~0) (Pto_list_raw j~1 r acc)) as [(i'&->&?)|?]; auto.
      { left; exists (i' ~ 0). by rewrite Preverse_xO, (associative_L _). }
      destruct (IHr (j~1) acc) as [(i'&->&?)|?]; auto.
      left; exists (i' ~ 1). by rewrite Preverse_xI, (associative_L _). }
  revert t j i acc. assert (∀ t j i acc,
    (i, x) ∈ acc → (i, x) ∈ Pto_list_raw j t acc) as help.
  { intros t; induction t as [|l IHl [y|] r IHr]; intros j i acc;
      simpl; rewrite ?elem_of_cons; auto. }
  intros t j ? acc [(i&->&Hi)|?]; [|by auto]. revert j i acc Hi.
  induction t as [|l IHl [y|] r IHr]; intros j i acc ?; simpl.
  * done.
  * rewrite elem_of_cons. destruct i as [i|i|]; simplify_equality'.
    + right. apply help. specialize (IHr (j~1) i).
      rewrite Preverse_xI, (associative_L _) in IHr. by apply IHr.
    + right. specialize (IHl (j~0) i).
      rewrite Preverse_xO, (associative_L _) in IHl. by apply IHl.
    + left. by rewrite (left_id_L 1 (++))%positive.
  * destruct i as [i|i|]; simplify_equality'.
    + apply help. specialize (IHr (j~1) i).
      rewrite Preverse_xI, (associative_L _) in IHr. by apply IHr.
    + specialize (IHl (j~0) i).
      rewrite Preverse_xO, (associative_L _) in IHl. by apply IHl.
Qed.
Lemma Pto_list_nodup {A} j (t : Pmap_raw A) acc :
  (∀ i x, (i ++ Preverse j, x) ∈ acc → t !! i = None) →
  NoDup acc → NoDup (Pto_list_raw j t acc).
Proof.
  revert j acc. induction t as [|l IHl [y|] r IHr]; simpl; intros j acc Hin ?.
  * done.
  * repeat constructor.
    { rewrite Pelem_of_to_list. intros [(i&Hi&?)|Hj].
      { apply (f_equal Plength) in Hi.
        rewrite Preverse_xO, !Papp_length in Hi; simpl in *; lia. }
      rewrite Pelem_of_to_list in Hj. destruct Hj as [(i&Hi&?)|Hj].
      { apply (f_equal Plength) in Hi.
        rewrite Preverse_xI, !Papp_length in Hi; simpl in *; lia. }
      specialize (Hin 1 y). rewrite (left_id_L 1 (++))%positive in Hin.
      discriminate (Hin Hj). }
   apply IHl.
   { intros i x. rewrite Pelem_of_to_list. intros [(?&Hi&?)|Hi].
     + rewrite Preverse_xO, Preverse_xI, !(associative_L _) in Hi.
       by apply (injective (++ _)) in Hi.
     + apply (Hin (i~0) x). by rewrite Preverse_xO, (associative_L _) in Hi. }
   apply IHr; auto. intros i x Hi.
   apply (Hin (i~1) x). by rewrite Preverse_xI, (associative_L _) in Hi.
 * apply IHl.
   { intros i x. rewrite Pelem_of_to_list. intros [(?&Hi&?)|Hi].
     + rewrite Preverse_xO, Preverse_xI, !(associative_L _) in Hi.
       by apply (injective (++ _)) in Hi.
     + apply (Hin (i~0) x). by rewrite Preverse_xO, (associative_L _) in Hi. }
   apply IHr; auto. intros i x Hi.
   apply (Hin (i~1) x). by rewrite Preverse_xI, (associative_L _) in Hi.
Qed.
Global Instance Pto_list {A} : FinMapToList positive A (Pmap A) := λ m,
  Pto_list_raw 1 (pmap_car m) [].

Instance Pomap_raw : OMap Pmap_raw := λ A B f,
  fix go t :=
  match t with
  | PLeaf => PLeaf | PNode l o r => PNode_canon (go l) (o ≫= f) (go r)
  end.
Lemma Pomap_wf {A B} (f : A → option B) (t : Pmap_raw A) :
  Pmap_wf t → Pmap_wf (omap f t).
Proof. induction 1; csimpl; auto. Qed.
Local Hint Resolve Pomap_wf.
Lemma Pomap_lookup {A B} (f : A → option B) (t : Pmap_raw A) i :
  omap f t !! i = t !! i ≫= f.
Proof.
  revert i. induction t as [| l IHl o r IHr ]; [done |].
  intros [?|?|]; csimpl; PNode_canon_rewrite; auto.
Qed.
Global Instance Pomap: OMap Pmap := λ A B f m,
  PMap' (omap f (pmap_car m)) (Pomap_wf f _ (pmap_prf m)).

Instance Pmerge_raw : Merge Pmap_raw :=
  fix Pmerge_raw A B C f t1 t2 : Pmap_raw C :=
  match t1, t2 with
  | PLeaf, t2 => omap (f None ∘ Some) t2
  | t1, PLeaf => omap (flip f None ∘ Some) t1
  | PNode l1 o1 r1, PNode l2 o2 r2 =>
     PNode_canon (@merge _ Pmerge_raw A B C f l1 l2)
      (f o1 o2) (@merge _ Pmerge_raw A B C f r1 r2)
  end.
Local Arguments omap _ _ _ _ _ _ : simpl never.
Lemma Pmerge_wf {A B C} (f : option A → option B → option C) t1 t2 :
  Pmap_wf t1 → Pmap_wf t2 → Pmap_wf (merge f t1 t2).
Proof. intros t1wf. revert t2. induction t1wf; destruct 1; simpl; auto. Qed.
Global Instance Pmerge: Merge Pmap := λ A B C f m1 m2,
  PMap' _ (Pmerge_wf f _ _ (pmap_prf m1) (pmap_prf m2)).
Lemma Pmerge_spec {A B C} (f : option A → option B → option C)
    (Hf : f None None = None) (t1 : Pmap_raw A) t2 i :
  merge f t1 t2 !! i = f (t1 !! i) (t2 !! i).
Proof.
  revert t2 i. induction t1 as [|l1 IHl1 o1 r1 IHr1]; intros t2 i.
  { unfold merge; simpl. rewrite Pomap_lookup. by destruct (t2 !! i). }
  destruct t2 as [|l2 o2 r2].
  * unfold merge, Pmerge_raw. rewrite Pomap_lookup.
    by destruct (PNode _ _ _ !! i).
  * destruct i; simpl; by PNode_canon_rewrite.
Qed.

(** * Instantiation of the finite map interface *)
Global Instance: FinMap positive Pmap.
Proof.
  split.
  * intros ? [t1 ?] [t2 ?] ?. apply Pmap_eq; simpl.
    apply Pmap_wf_eq_get; trivial; by apply (bool_decide_unpack _).
  * by intros ? [].
  * intros ?? [??] ?. by apply Plookup_alter.
  * intros ?? [??] ??. by apply Plookup_alter_ne.
  * intros ??? [??]. by apply Plookup_fmap.
  * intros ? [??]. apply Pto_list_nodup; [|constructor].
    intros ??. by rewrite elem_of_nil.
  * intros ? [??] i x; unfold map_to_list, Pto_list.
    rewrite Pelem_of_to_list, elem_of_nil.
    split. by intros [(?&->&?)|]. by left; exists i.
  * intros ?? ? [??] ?. by apply Pomap_lookup.
  * intros ??? ?? [??] [??] ?. by apply Pmerge_spec.
Qed.

(** * Finite sets *)
(** We construct sets of [positives]s satisfying extensional equality. *)
Notation Pset := (mapset Pmap).
Instance Pmap_dom {A} : Dom (Pmap A) Pset := mapset_dom.
Instance: FinMapDom positive Pmap Pset := mapset_dom_spec.

(** * Fresh numbers *)
Fixpoint Pdepth {A} (m : Pmap_raw A) : nat :=
  match m with
  | PLeaf | PNode _ None _ => O | PNode l _ _ => S (Pdepth l)
  end.
Fixpoint Pfresh_at_depth {A} (m : Pmap_raw A) (d : nat) : option positive :=
  match d, m with
  | O, (PLeaf | PNode _ None _) => Some 1
  | S d, PNode l _ r =>
     match Pfresh_at_depth l d with
     | Some i => Some (i~0) | None => (~1) <$> Pfresh_at_depth r d
     end
  | _, _ => None
  end.
Fixpoint Pfresh_go {A} (m : Pmap_raw A) (d : nat) : option positive :=
  match d with
  | O => None
  | S d =>
     match Pfresh_go m d with
     | Some i => Some i | None => Pfresh_at_depth m d
     end
  end.
Definition Pfresh {A} (m : Pmap A) : positive :=
  let d := Pdepth (pmap_car m) in
  match Pfresh_go (pmap_car m) d with
  | Some i => i | None => Pos.shiftl_nat 1 d
  end.

Lemma Pfresh_at_depth_fresh {A} (m : Pmap_raw A) d i :
  Pfresh_at_depth m d = Some i → m !! i = None.
Proof.
  revert i m; induction d as [|d IH].
  { intros i [|l [] r] ?; naive_solver. }
  intros i [|l o r] ?; simplify_equality'.
  destruct (Pfresh_at_depth l d) as [i'|] eqn:?,
    (Pfresh_at_depth r d) as [i''|] eqn:?; simplify_equality'; auto.
Qed.
Lemma Pfresh_go_fresh {A} (m : Pmap_raw A) d i :
  Pfresh_go m d = Some i → m !! i = None.
Proof.
  induction d as [|d IH]; intros; simplify_equality'.
  destruct (Pfresh_go m d); eauto using Pfresh_at_depth_fresh.
Qed.
Lemma Pfresh_depth {A} (m : Pmap_raw A) :
  m !! Pos.shiftl_nat 1 (Pdepth m) = None.
Proof. induction m as [|l IHl [x|] r IHr]; auto. Qed.
Lemma Pfresh_fresh {A} (m : Pmap A) : m !! Pfresh m = None.
Proof.
  destruct m as [m ?]; unfold lookup, Plookup, Pfresh; simpl.
  destruct (Pfresh_go m _) eqn:?; eauto using Pfresh_go_fresh, Pfresh_depth.
Qed.

Instance Pset_fresh : Fresh positive Pset := λ X,
  let (m) := X in Pfresh m.
Instance Pset_fresh_spec : FreshSpec positive Pset.
Proof.
  split.
  * apply _.
  * intros X Y; rewrite <-elem_of_equiv_L. by intros ->.
  * unfold elem_of, mapset_elem_of, fresh; intros [m]; simpl.
    by rewrite Pfresh_fresh.
Qed.
