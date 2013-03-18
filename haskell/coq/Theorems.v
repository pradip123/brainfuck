Require Import Expr OptExpr AST.
Require Import ssreflect ssrnat ssrint ssralg ssrfun.
Import intZmod intRing.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Section Theorems.
  Theorem evals: forall (f: int -> int) (e: Expr),
    eval f e = eval' f e.
  Proof.
    move=> f.
    elim=> //=.
      by move=> op e IH; rewrite IH.
      by move=> op a IHa b IHb; rewrite IHa IHb.
  Qed.

  Theorem unfoldId: forall (e: Expr),
    unfold OperateUnary OperateBinary Return e = e.
  Proof.
    elim=> //=.
      by move=> op e IH; rewrite IH.
      by move=> op a IHa b IHb; rewrite IHa IHb.
  Qed.

  Theorem addC: forall (f: int -> int) (a b: Expr),
    eval f (OperateBinary Add a b) = eval f (OperateBinary Add b a).
  Proof. by move=> ? ? ?; rewrite /eval addzC. Qed.

  Theorem addA: forall (f: int -> int) (a b c: Expr),
    eval f (OperateBinary Add a (OperateBinary Add b c)) =
      eval f (OperateBinary Add (OperateBinary Add a b) c).
  Proof. by move=> ? ? ? ?; rewrite /eval addzA. Qed.

  Theorem add0e: forall (f: int -> int) (e: Expr),
    eval f (OperateBinary Add (Return (Const 0)) e) = eval f e.
  Proof. by move=> ? ?; rewrite /eval add0z. Qed.

  Theorem adde0: forall (f: int -> int) (e: Expr),
    eval f (OperateBinary Add e (Return (Const 0))) = eval f e.
  Proof. by move=> ? ?; rewrite /eval addzC add0z. Qed.

  Theorem addnn: forall (f: int -> int) (a b: int),
    eval f (OperateBinary Add (Return (Const a)) (Return (Const b))) =
      eval f (Return (Const (addz a b))).
  Proof. by []. Qed.

  Theorem mulC: forall (f: int -> int) (a b: Expr),
    eval f (OperateBinary Mul a b) = eval f (OperateBinary Mul b a).
  Proof. by move=> ? ? ?; rewrite /eval mulzC. Qed.

  Theorem mulA: forall (f: int -> int) (a b c: Expr),
    eval f (OperateBinary Mul a (OperateBinary Mul b c)) =
      eval f (OperateBinary Mul (OperateBinary Mul a b) c).
  Proof. by move=> ? ? ? ?; rewrite /eval mulzA. Qed.

  Theorem mul0e: forall (f: int -> int) (e: Expr),
    eval f (OperateBinary Mul (Return (Const 0)) e) = 0.
  Proof. by move=> ? ?; rewrite /eval mul0z. Qed.

  Theorem mule0: forall (f: int -> int) (e: Expr),
    eval f (OperateBinary Mul e (Return (Const 0))) = 0.
  Proof. by move=> ? ?; rewrite /eval mulz0. Qed.

  Theorem mul1e: forall (f: int -> int) (e: Expr),
    eval f (OperateBinary Mul (Return (Const 1)) e) = eval f e.
  Proof. by move=> ? ?; rewrite /eval mul1z. Qed.

  Theorem mule1: forall (f: int -> int) (e: Expr),
    eval f (OperateBinary Mul e (Return (Const 1))) = eval f e.
  Proof. by move=> ? ?; rewrite /eval mulzC mul1z. Qed.

  Theorem optAddConsts: forall (f: int -> int) (e: Expr),
    eval f (addConsts e) = eval f e.
  Proof. by move=> ?; do 4?case=> //=; move=> ?; do ?case=> //=. Qed.

  Theorem optAddZeroL: forall (f: int -> int) (e: Expr),
    eval f (addZeroL e) = eval f e.
  Proof.
    move=> f.
    do 5?case=> //=.
    case=> e //=.
    case: eval => n //=.
    by rewrite subn0.
  Qed.

  Theorem optAddZeroR: forall (f: int -> int) (e: Expr),
    eval f (addZeroR e) = eval f e.
  Proof.
    move=> f.
    case=> //=.
    case=> e //=.
    do 4?case=> //=.
    by rewrite addzC add0z.
  Qed.

  Theorem optMulConsts: forall (f: int -> int) (e: Expr),
    eval f (mulConsts e) = eval f e.
  Proof.
    move=> f.
    do 4?case=> //=.
    move=> z.
    by do 2?case=> //=.
  Qed.

  Theorem optMulOneL: forall (f: int -> int) (e: Expr),
    eval f (mulOneL e) = eval f e.
  Proof.
    move=> f.
    do 7?case=> //=.
    move=> e.
    case: eval => n //=.
    by rewrite mul1n.
    by rewrite mul1n.
  Qed.

  Theorem optMulOneR: forall (f: int -> int) (e: Expr),
    eval f (mulOneR e) = eval f e.
  Proof.
    move=> f.
    do 2?case=> //=.
    move=> e.
    do 5?case=> //=.
    by rewrite mulzC mul1z.
  Qed.

  Theorem optMulNegOneL: forall (f: int -> int) (e: Expr),
    eval f (mulNegOneL e) = eval f e.
  Proof.
    move=> f.
    do 6?case=> //=.
    move=> e.
    case: eval => n //=.
    by rewrite muln1.
    by rewrite mul1n.
  Qed.

  Theorem optMulNegOneR: forall (f: int -> int) (e: Expr),
    eval f (mulNegOneR e) = eval f e.
  Proof.
    move=> f.
    do 2?case=> //=.
    move=> e.
    do 4?case=> //=.
    case: eval => n //=.
    by rewrite muln1.
    by rewrite muln1.
  Qed.

  Theorem optNegConstant: forall (f: int -> int) (e: Expr),
    eval f (negConstant e) = eval f e.
  Proof. move=> f. by do 4?case=> //=. Qed.

  Theorem optNegCollaps: forall (f: int -> int) (e: Expr),
    eval f (negCollaps e) = eval f e.
  Proof. move=> f. do 4?case=> //=. move=> e. by rewrite oppzK. Qed.

  Theorem optIdAny: forall (f: int -> int) (e: Expr),
    eval f (idAny e) = eval f e.
  Proof. move=> f. by do 4?case=> //=. Qed.

  Theorem optSwapConstGet: forall (f: int -> int) (e: Expr),
    eval f (swapConstGet e) = eval f e.
  Proof.
    move=> f.
    do 3?case=> //=.
    case=> i //=.
    case=> //=.
    case=> i' //=.
    by rewrite addzC.
    case=> //=.
    case=> i //=.
    case=> //=.
    case=> i' //=.
    by rewrite mulzC.
    case=> //=.
    case=> i' //=.
    case f => n //=.
    by rewrite mulnC.
  Qed.

  Theorem optSwapConstDown: forall (f: int -> int) (e: Expr),
    eval f (swapConstDown e) = eval f e.
  Proof.
    move=> f.
    case=> //=.
    case=> //=.
    case=> //=.
    case=> i //=.
    case=> //=.
    case=> //=.
    case=> //=.
    case=> //=.
    move=> i' e.
    by rewrite addzA [X in addz X _]addzC addzA.
    case=> //=.
    case=> i //=.
    case=> //=.
    case=> //=.
    case=> //=.
    case=> //=.
    move=> i' e.
    by rewrite mulzA [X in mulz X _]mulzC mulzA.
  Qed.

  Theorem optRotateBinary: forall (f: int -> int) (e: Expr),
    eval f (rotateBinary e) = eval f e.
  Proof.
    move=> f.
    case=> //=.
    case=> //=.
    case=> //=.
    case=> a b c //=.
    by rewrite addzA.
    case=> //=.
    case=> a b c //=.
    by rewrite mulzA.
  Qed.

  Theorem optSortGets: forall (f: int -> int) (e: Expr),
    eval f (sortGets e) = eval f e.
  Proof.
    move=> f.
    do 4?case=> //=.
    move=> a.
      case=> //=. case=> b //=.
      case: Aux.gtz => //=.
      by rewrite addzC.

      do 3?case=> //=.
      move=> b c.
      case: Aux.gtz => //=.
      by rewrite addzA [X in addz X _]addzC addzA.

    move=> a.
      case=> //=. case=> b //=.
      case Aux.gtz => //=.
      by rewrite mulzC.

      do 3?case=> //=.
      move=> b c.
      case Aux.gtz => //=.
      by rewrite mulzA [X in mulz X _]mulzC mulzA.
  Qed.
End Theorems.