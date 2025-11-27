(* Module de la passe de gestion des identifiants *)
(* doit être conforme à l'interface Passe *)
open Tds
open Exceptions
open Ast
open Type

type t1 = Ast.AstTds.programme
type t2 = Ast.AstType.programme

let recuperer_type info =
  match info_ast_to_info info with
  | InfoVar(_, t, _, _) -> t
  | InfoFun(_, t, _) -> t
  | _ -> failwith "Erreur interne"


(* analyse_type_expression : type -> AstTds.expression -> Asttype.expression *)
(* Paramètre e : l'expression à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme l'expression
en une expression de type Asttype.expression *)
(* Erreur si mauvaise utilisation des identifiants *)
let rec analyse_type_expression e =
  match e with
  | AstTds.AppelFonction (info, el) -> 
    begin
      let l = List.map analyse_type_expression el in
      let (lne, lte) = List.split l in
      match info_ast_to_info info with
      | InfoFun(n, tr, ltp) ->
        if Type.est_compatible_list ltp lte
        then (AstType.AppelFonction (info, lne), tr)
        else raise (Exceptions.TypesParametresInattendus (lte, ltp))
      | _ -> failwith "Erreur interne"
    end
  | AstTds.Ident info -> (AstType.Ident info, recuperer_type info)
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
  | _ ->  failwith "Erreur interne"


(* analyse_type_instruction : type -> info_ast option -> AstTds.instruction -> Asttype.instruction *)
(* Paramètre oia : None si l'instruction i est dans le bloc principal,
                   Some ia où ia est l'information associée à la fonction dans laquelle est l'instruction i sinon *)
(* Paramètre i : l'instruction à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme l'instruction
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
  | AstTds.Affectation (info, e) ->
    let (ne, te) = analyse_type_expression e in
    let t = recuperer_type info in
    if (est_compatible t te)
    then AstType.Affectation (info, ne)
    else raise (TypeInattendu (te, t))
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
(* Paramètre oia : None si le bloc li est dans le programme principal,
                   Some ia où ia est l'information associée à la fonction dans laquelle est le bloc li sinon *)
(* Paramètre li : liste d'instructions à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme le bloc en un bloc de type Asttype.bloc *)
(* Erreur si mauvaise utilisation des identifiants *)
and analyse_type_bloc li =
  List.map analyse_type_instruction li


(* analyse_type_fonction : type -> AstTds.fonction -> Asttype.fonction *)
(* Paramètre : la fonction à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme la fonction
en une fonction de type Asttype.fonction *)
(* Erreur si mauvaise utilisation des identifiants *)
let analyse_type_fonction (AstTds.Fonction(t, info, lp, li)) =
  let nli = analyse_type_bloc li in
  let (_, nlpi) = List.split lp in
  AstType.Fonction(info, nlpi, nli)
  

(* analyser : AstTds.programme -> Asttype.programme *)
(* Paramètre : le programme à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme le programme
en un programme de type Asttype.programme *)
(* Erreur si mauvaise utilisation des identifiants *)
let analyser (AstTds.Programme (fonctions,prog)) =
  let nf = List.map (analyse_type_fonction) fonctions in
  let nb = analyse_type_bloc prog in
  AstType.Programme (nf, nb)
