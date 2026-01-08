(* Module de la passe de generation de code TAM *)
(* doit être conforme à l'interface Passe *)
open Tds
open Ast
open Type
open AstPlacement
open Code
open Tam

type t1 = AstPlacement.programme
type t2 = string


(**************************************************************************************)
(* analyse_code_affectable_lecture : AstPlacement.affectable -> string                *)
(* Parametre a : l'affectable à analyser en lecture.                                  *)
(* Génère le code TAM pour charger la valeur d'un affectable (variable ou pointeur)   *)
(* au sommet de la pile.                                                              *)
(* Erreur si l'affectable n'est pas une variable accessible.                          *)
(**************************************************************************************)
let rec analyse_code_affectable_lecture a =
  match a with
  | AstType.Ident info -> 
    begin
      match info_ast_to_info info with
      | InfoVar(_, t, depl, reg) -> (load (getTaille t) depl reg)
      | _ -> failwith "Erreur interne"
    end


(**************************************************************************************)
(* analyse_code_affectable_ecriture : AstPlacement.affectable -> string               *)
(* Parametre a : l'affectable à analyser en écriture.                                 *)
(* Génère le code TAM pour stocker la valeur au sommet de la pile vers l'adresse      *)
(* de l'affectable.                                                                   *)
(* Erreur si l'affectable n'est pas une variable accessible.                          *)
(**************************************************************************************)
let rec analyse_code_affectable_ecriture a =
  match a with
  | AstType.Ident info -> 
    begin
      match info_ast_to_info info with
      | InfoVar(_, t, depl, reg) -> (store (getTaille t) depl reg)
      | _ -> failwith "Erreur interne"
    end


(**************************************************************************************)
(* analyse_code_expression : AstPlacement.expression -> string                        *)
(* Parametre e : l'expression à analyser.                                             *)
(* Génère le code TAM correspondant à l'évaluation de l'expression. Le résultat       *)
(* sera placé au sommet de la pile.                                                   *)
(* Erreur si mauvaise utilisation des identifiants.                                   *)
(**************************************************************************************)
let rec analyse_code_expression e =
  match e with
  | AstType.AppelFonction (info, le) ->
    begin
      match info_ast_to_info info with
      | InfoFun(s, _, _) ->
        (* Evaluation des arguments de la gauche vers la droite puis appel *)
        (List.fold_right (fun e acc -> (analyse_code_expression e) ^ acc) le "") ^ (call "SB" (label s))
      | _ -> failwith "Erreur interne"
    end
  | AstType.Affectable a -> analyse_code_affectable_lecture a
  | AstType.Booleen b -> 
    if b then (loadl_int 1)
    else (loadl_int 0)
  | AstType.Entier i -> (loadl_int i)
  | AstType.Unaire (u, e2) -> (analyse_code_expression e2) ^ (if u = Numerateur then (pop 0 1) else (pop 1 1))
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
        | Fraction -> ""
      )
    end


(**************************************************************************************)
(* analyse_code_instruction : AstPlacement.instruction -> string                      *)
(* Parametre i : l'instruction à analyser.                                            *)
(* Génère le code TAM correspondant à l'exécution de l'instruction (gestion de pile,  *)
(* sauts, étiquettes, appels systèmes).                                               *)
(* Erreur si mauvaise utilisation des identifiants.                                   *)
(**************************************************************************************)
let rec analyse_code_instruction i =
  match i with
  | AstPlacement.Declaration (info, e) -> 
    begin
      match info_ast_to_info info with
      | InfoVar(_, t, depl, reg) -> 
        (* Allocation sur la pile, evaluation de l'expression, stockage *)
        (push (getTaille t)) ^ (analyse_code_expression e) ^ (store (getTaille t) depl reg)
      | _ ->  failwith "Erreur interne"
    end
  | AstPlacement.Affectation (a, e) -> (analyse_code_expression e) ^ (analyse_code_affectable_ecriture a)
  | AstPlacement.AffichageInt e -> (analyse_code_expression e) ^ (subr (label "IOut"))
  | AstPlacement.AffichageRat e -> (analyse_code_expression e) ^ (call "SB" (label "rout"))
  | AstPlacement.AffichageBool e -> (analyse_code_expression e) ^ (subr (label "BOut"))
  | AstPlacement.Conditionnelle (c, t, e) ->
    let sinon = getEtiquette () in 
    let finsi = getEtiquette () in
    (* Code : expression condition, saut si faux, bloc Then, saut fin, etiquette Sinon, bloc Else, etiquette Fin *)
    (analyse_code_expression c) ^ (jumpif 0 (label sinon)) ^ (analyse_code_bloc t) ^ (jump (label finsi)) ^ (label sinon) ^ (analyse_code_bloc e) ^ (label finsi)
  | AstPlacement.TantQue (c, b) ->
    let tantque = getEtiquette () in
    let fintantque = getEtiquette () in
    (label tantque) ^ (analyse_code_expression c) ^ (jumpif 0 (label fintantque)) ^ (analyse_code_bloc b) ^ (jump (label tantque)) ^ (label fintantque)
  | AstPlacement.Retour (e, tailleRet, tailleParam) -> (analyse_code_expression e) ^ (return tailleRet tailleParam)
  | AstPlacement.Empty -> ""


(**************************************************************************************)
(* analyse_code_bloc : AstPlacement.bloc -> string                                    *)
(* Parametre li : liste d'instructions à analyser avec la taille totale des locales.  *)
(* Génère le code pour toutes les instructions du bloc et nettoie la pile (pop)       *)
(* des variables locales à la fin.                                                    *)
(* Erreur si mauvaise utilisation des identifiants.                                   *)
(**************************************************************************************)
and analyse_code_bloc (li, taille) =
  (List.fold_right(fun i acc -> (analyse_code_instruction i) ^ acc) li "") ^ (pop 0 taille)


(**************************************************************************************)
(* analyse_code_fonction : AstPlacement.fonction -> string                            *)
(* Parametre : la fonction à analyser.                                                *)
(* Génère l'étiquette de la fonction, le code de son corps, et l'instruction de fin.  *)
(* Erreur si mauvaise utilisation des identifiants.                                   *)
(**************************************************************************************)
let analyse_code_fonction (AstPlacement.Fonction(info, _, bloc)) =
  match info_ast_to_info info with
  | InfoFun(n, _, _) -> (label n) ^ (analyse_code_bloc bloc) ^ halt
  | _ -> failwith "Erreur interne"


(**************************************************************************************)
(* analyser : AstPlacement.programme -> string                                        *)
(* Parametre : le programme à analyser.                                               *)
(* Génère l'entête TAM, le code des fonctions, le code du main, et termine par halt.  *)
(* Erreur si mauvaise utilisation des identifiants.                                   *)
(**************************************************************************************)
let analyser (AstPlacement.Programme (fonctions, prog)) =
  getEntete() ^ (List.fold_right(fun i acc -> (analyse_code_fonction i) ^ acc) fonctions "") ^ (label "main") ^ (analyse_code_bloc prog) ^ halt