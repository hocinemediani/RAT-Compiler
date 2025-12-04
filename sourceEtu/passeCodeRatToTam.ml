(* Module de la passe de gestion des identifiants *)
(* doit être conforme à l'interface Passe *)
open Tds
open Exceptions
open Ast
open Type
open AstPlacement
open Code
open Tam

type t1 = Ast.AstPlacement.programme
type t2 = string

(* analyse_code_expression : tds -> AstSyntax.expression -> AstTds.expression *)
(* Paramètre e : l'expression à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme l'expression
en une expression de type AstTds.expression *)
(* Erreur si mauvaise utilisation des identifiants *)
let rec analyse_code_expression e =
  match e with
  | AstType.AppelFonction (info, le) -> 
    failwith "Erreur interne"
    (*
    begin
      match info_ast_to_info info with
      | InfoFun(s, t, lt) ->
      let cle = List.fold_right ( fun e acc -> (analyse_code_expression e) ^ acc) le "" in
      cle ^ (call "SB" s)
      | _ -> failwith "Erreur interne"
    end *)
  | AstType.Ident info -> 
    begin
      match info_ast_to_info info with
      | InfoVar(_, t, depl, reg) -> (load (getTaille t) depl reg)
      | _ -> failwith "Erreur interne"
    end 
  | AstType.Booleen b -> 
    if b then (loadl_int 1)
    else (loadl_int 0)
  | AstType.Entier i -> (loadl_int i)
  | AstType.Unaire (u, e2) -> (analyse_code_expression e2) ^ (if u = Numerateur then (pop 0 1) else (pop 1 1)) ^ (call "SB" (label "norm"))
  | AstType.Binaire (b, e2, e3) ->
    begin
      (analyse_code_expression e2) ^ (analyse_code_expression e3) ^ (
        match b with
        | PlusInt -> subr (label "IAdd") 
        | PlusRat -> (call "SB" (label "radd")) ^ (call "SB" (label "norm"))
        | MultInt -> subr (label "IMul")
        | MultRat -> (call "SB" (label "rmul")) ^ (call "SB" (label "norm"))
        | EquInt -> subr (label "IEq")
        | EquBool -> subr (label "IEq")
        | Inf -> subr (label "ILss")
        | Fraction -> "" (* ??? *)
      )
    end
  | _ ->  failwith "Erreur interne"

(* analyse_type_instruction : type -> info_ast option -> AstType.instruction -> Astplacement.instruction *)
(* Paramètre oia : None si l'instruction i est dans le bloc principal,
                   Some ia où ia est l'information associée à la fonction dans laquelle est l'instruction i sinon *)
(* Paramètre i : l'instruction à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme l'instruction
en une instruction de type Asttype.instruction *)
(* Erreur si mauvaise utilisation des identifiants *)
let rec analyse_code_instruction i =
  match i with
  | AstPlacement.Declaration (info, e) -> 
    begin
      match info_ast_to_info info with
      | InfoVar(s1, t, depl, reg) -> 
        (push (getTaille t)) ^ (analyse_code_expression e) ^ (store (getTaille t) depl reg)
      | _ ->  failwith "Erreur interne"
    end
  | AstPlacement.Affectation (info, e) -> 
    begin
      match info_ast_to_info info with
      | InfoVar(s1, t, depl, reg) -> 
        (analyse_code_expression e) ^ (store (getTaille t) depl reg)
      | _ ->  failwith "Erreur interne"
    end
  | AstPlacement.AffichageInt e -> (analyse_code_expression e) ^ (subr (label "IOut"))
  | AstPlacement.AffichageRat e -> (analyse_code_expression e) ^ (call "SB" (label "rout"))
  | AstPlacement.AffichageBool e -> (analyse_code_expression e) ^ (subr (label "BOut")) (* ??? *)
  | AstPlacement.Conditionnelle (c, t, e) -> (analyse_code_expression c) ^ (jumpif 0 (label "sinon")) ^ (analyse_code_bloc t) ^ (jump (label "finsi")) ^ (label "sinon") ^ (analyse_code_bloc e) ^ (label "finsi")
  | AstPlacement.TantQue (c, b) -> (label "tantque") ^ (analyse_code_expression c) ^ (jumpif 0 (label "fintantque")) ^ (analyse_code_bloc b) ^ (jump (label "tantque")) ^ (label "fintantque")
  | AstPlacement.Retour (e, tailleRet, tailleParam) -> (analyse_code_expression e) ^ (return tailleRet tailleParam)
  | AstPlacement.Empty -> ""


(* analyse_type_bloc : type -> info_ast option -> AstTds.bloc -> Asttype.bloc *)
(* Paramètre oia : None si le bloc li est dans le programme principal,
                   Some ia où ia est l'information associée à la fonction dans laquelle est le bloc li sinon *)
(* Paramètre li : liste d'instructions à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme le bloc en un bloc de type Asttype.bloc *)
(* Erreur si mauvaise utilisation des identifiants *)
and analyse_code_bloc (li, taille) =
  (List.fold_right(fun i acc -> (analyse_code_instruction i) ^ acc) li "") ^ (pop 0 taille)


(* analyse_type_fonction : type -> AstTds.fonction -> Asttype.fonction *)
(* Paramètre : la fonction à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme la fonction
en une fonction de type Asttype.fonction *)
(* Erreur si mauvaise utilisation des identifiants *)
let analyse_code_fonction (AstPlacement.Fonction(info, lp, (li, taille))) =
  ""

(* analyser : AstTds.programme -> AstType.programme *)
(* Paramètre : le programme à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme le programme
en un programme de type Asttype.programme *)
(* Erreur si mauvaise utilisation des identifiants *)
let analyser (AstPlacement.Programme (fonctions, prog)) =
  getEntete() ^ (List.fold_right(fun i acc -> (analyse_code_fonction i) ^ acc) fonctions "") ^ (label "main") ^ (analyse_code_bloc prog)
