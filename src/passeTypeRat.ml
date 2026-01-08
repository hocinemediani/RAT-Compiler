(* Module de la passe de typage, *)
(* doit etre conforme a l'interface Passe. *)
open Tds
open Exceptions
open Ast
open Type

(* Type d'entree de la passe. *)
type t1 = Ast.AstTds.programme
(* Type de sortie de la passe. *)
type t2 = Ast.AstType.programme


(**************************************************************************************)
(* recuperer_type : info_ast -> typ                                                   *)
(* Parametre info : l'info dont on souhaite le type.                                  *)
(* Verifie que l'info est celle d'une variable ou d'une fonction et retourne          *)
(* le type ou le type de retour de cette derniere.                                    *)
(**************************************************************************************)
let recuperer_type info =
  match info_ast_to_info info with
  | InfoVar(_, t, _, _) -> t
  | InfoFun(_, t, _)    -> t
  | _ -> failwith "Erreur interne"


(**************************************************************************************)
(* analyse_type_affectable : AstTds.affectable -> (AstType.affectable, typ)           *)
(* Parametre a : l'affectable a analyser.                                             *)
(* Verifie que l'affectable est bien utilise et renvoie un affectable de type         *)
(* AstType.affectable, avec son type.                                                 *)
(**************************************************************************************)
let rec analyse_type_affectable a =
  match a with
  | AstTds.Ident info -> (AstType.Ident info, recuperer_type info)
  | _                 -> failwith "Erreur interne"

(**************************************************************************************)
(* analyse_tds_expression : tds -> AstSyntax.expression -> AstTds.expression          *)
(* Parametre tds : la table des symboles courante.                                    *)
(* Parametre e : l'expression a analyser.                                             *)
(* Verifie le bon typage des expressions et tranforme l'expression en une expression  *)
(* de type AstTds.expression.                                                         *)
(**************************************************************************************)
let rec analyse_type_expression e =
  match e with
  | AstTds.AppelFonction (info, el) -> 
    begin
      let l = List.map analyse_type_expression el in
      let (lne, lte) = List.split l in
      match info_ast_to_info info with
      | InfoFun(_, tr, ltp) ->
        if Type.est_compatible_list ltp lte
        then (AstType.AppelFonction (info, lne), tr)
        else raise (Exceptions.TypesParametresInattendus (lte, ltp))
      | _ -> failwith "Erreur interne"
    end
  | AstTds.Affectable a ->
    let (na, ta) = analyse_type_affectable a in
    (AstType.Affectable na, ta)
(*
  | AstTds.Ident info -> (AstType.Ident info, recuperer_type info)
*)
  | AstTds.Booleen b -> (AstType.Booleen b, Bool)
  | AstTds.Entier i -> (AstType.Entier i, Int)
  | AstTds.Unaire (u, e2) ->
    let (n, t) = analyse_type_expression e2 in
      if (est_compatible t Rat)
      then
        begin
          match u with
          | AstSyntax.Numerateur -> (AstType.Unaire (AstType.Numerateur, n), Int)
          | AstSyntax.Denominateur -> (AstType.Unaire (AstType.Denominateur, n), Int)
        end
      else raise (TypeInattendu (t, Rat))
  | AstTds.Binaire (op, e2, e3) ->
    begin
      let (ne2, te2) = analyse_type_expression e2 in
        let (ne3, te3) = analyse_type_expression e3 in
          match (op, te2, te3) with
          | (Plus, Int, Int) -> (AstType.Binaire (PlusInt, ne2, ne3), Int)
          | (Plus, Rat, Rat) -> (AstType.Binaire (PlusRat, ne2, ne3), Rat)
          | (Mult, Int, Int) -> (AstType.Binaire (MultInt, ne2, ne3), Int)
          | (Mult, Rat, Rat) -> (AstType.Binaire (MultRat, ne2, ne3), Rat)
          | (Equ, Int, Int) -> (AstType.Binaire (EquInt, ne2, ne3), Bool)
          | (Equ, Bool, Bool) -> (AstType.Binaire (EquBool, ne2, ne3), Bool)
          | (Inf, Int, Int) -> (AstType.Binaire (Inf, ne2, ne3), Bool)
          | (Fraction, Int, Int) -> (AstType.Binaire (Fraction, ne2, ne3), Rat)
          | _ -> raise (TypeBinaireInattendu (op, te2, te3))
    end


(* analyse_type_instruction : type -> info_ast option -> AstTds.instruction -> Asttype.instruction *)
(* Parametre oia : None si l'instruction i est dans le bloc principal,
                   Some ia ou ia est l'information associee a la fonction dans laquelle est l'instruction i sinon *)
(* Parametre i : l'instruction a analyser *)
(* Verifie la bonne utilisation des identifiants et tranforme l'instruction
en une instruction de type Asttype.instruction *)
(* Erreur si mauvaise utilisation des identifiants *)
let rec analyse_type_instruction i =
  match i with
  | AstTds.Declaration (t, info, e) ->
    let (ne, te) = analyse_type_expression e in
    if (est_compatible te t)
    then
      begin
      modifier_type_variable te info; AstType.Declaration (info, ne)
      end
    else raise (TypeInattendu (te, t))
  | AstTds.Affectation (a, e) ->
    let (na, ta) = analyse_type_affectable a in
    let (ne, te) = analyse_type_expression e in
    if (est_compatible ta te)
    then AstType.Affectation (na, ne)
    else raise (TypeInattendu (te, ta))
    (*
  | AstTds.Affectation (info, e) ->
    let (ne, te) = analyse_type_expression e in
    let t = recuperer_type info in
    if (est_compatible t te)
    then AstType.Affectation (info, ne)
    else raise (TypeInattendu (te, t))
    *)
  | AstTds.Affichage e ->
    begin
      let (ne, te) = analyse_type_expression e in
      match te with
      | Int -> AffichageInt ne
      | Rat -> AffichageRat ne
      | Bool -> AffichageBool ne
      | _ -> failwith "Erreur interne"
    end
  | AstTds.Conditionnelle (c, t, e) ->
    let (nc, tc) = analyse_type_expression c in
    let nt = analyse_type_bloc t in
    let ne = analyse_type_bloc e in
    if (est_compatible tc Bool)
    then AstType.Conditionnelle (nc, nt, ne)
    else raise (TypeInattendu (tc, Bool))
  | AstTds.TantQue (c, b) ->
    let (nc, tc) = analyse_type_expression c in
    let nb = analyse_type_bloc b in
    if (est_compatible tc Bool)
    then AstType.TantQue (nc, nb)
    else raise (TypeInattendu (tc, Bool))
  | AstTds.Retour (e, ia) ->
    let (ne, te) = analyse_type_expression e in
    let t = recuperer_type ia in
    if (est_compatible t te)
    then AstType.Retour (ne, ia)
    else raise (TypeInattendu (te, t))
  | AstTds.Empty ->
    AstType.Empty


(* analyse_type_bloc : type -> info_ast option -> AstTds.bloc -> Asttype.bloc *)
(* Parametre oia : None si le bloc li est dans le programme principal,
                   Some ia ou ia est l'information associee a la fonction dans laquelle est le bloc li sinon *)
(* Parametre li : liste d'instructions a analyser *)
(* Verifie la bonne utilisation des identifiants et tranforme le bloc en un bloc de type Asttype.bloc *)
(* Erreur si mauvaise utilisation des identifiants *)
and analyse_type_bloc li =
  List.map analyse_type_instruction li


(* analyse_type_fonction : type -> AstTds.fonction -> Asttype.fonction *)
(* Parametre : la fonction a analyser *)
(* Verifie la bonne utilisation des identifiants et tranforme la fonction
en une fonction de type Asttype.fonction *)
(* Erreur si mauvaise utilisation des identifiants *)
let analyse_type_fonction (AstTds.Fonction(_, info, lp, li)) =
  let nli = analyse_type_bloc li in
  let (_, nlpi) = List.split lp in
  AstType.Fonction(info, nlpi, nli)
  

(* analyser : AstTds.programme -> AstType.programme *)
(* Parametre : le programme a analyser *)
(* Verifie la bonne utilisation des identifiants et tranforme le programme
en un programme de type Asttype.programme *)
(* Erreur si mauvaise utilisation des identifiants *)
let analyser (AstTds.Programme (fonctions,prog)) =
  let nf = List.map (analyse_type_fonction) fonctions in
  let nb = analyse_type_bloc prog in
  AstType.Programme (nf, nb)
