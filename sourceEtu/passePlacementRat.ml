(* Module de la passe de gestion des identifiants *)
(* doit être conforme à l'interface Passe *)
open Tds
open Exceptions
open Ast
open Type
open AstPlacement

type t1 = Ast.AstType.programme
type t2 = Ast.AstPlacement.programme


(* analyse_type_instruction : type -> info_ast option -> AstType.instruction -> Astplacement.instruction *)
(* Paramètre oia : None si l'instruction i est dans le bloc principal,
                   Some ia où ia est l'information associée à la fonction dans laquelle est l'instruction i sinon *)
(* Paramètre i : l'instruction à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme l'instruction
en une instruction de type Asttype.instruction *)
(* Erreur si mauvaise utilisation des identifiants *)
let rec analyse_placement_instruction i depl reg =
  match i with
  | AstType.Declaration (info, e) ->
    begin
      match info_ast_to_info info with
      | InfoVar (_, t, _, _) -> modifier_adresse_variable depl reg info;
                                (AstPlacement.Declaration(info, e), getTaille t)
      | _ -> failwith "Erreur interne"
    end
  | AstType.Affectation (info, e) -> (AstPlacement.Affectation (info, e), 0)
  | AstType.AffichageInt e -> (AstPlacement.AffichageInt (e), 0)
  | AstType.AffichageRat e -> (AstPlacement.AffichageRat (e), 0)
  | AstType.AffichageBool e -> (AstPlacement.AffichageBool (e), 0)
  | AstType.Conditionnelle (c, t, e) ->
    let (nt, tt) = analyse_placement_bloc t depl reg in
    let (ne, te) = analyse_placement_bloc e depl reg in
    (AstPlacement.Conditionnelle (c, nt, ne), 0)
  | AstType.TantQue (c, b) ->
    let (nb, tb) = analyse_placement_bloc b depl reg in
    (AstPlacement.TantQue (c, nb), 0)
  | AstType.Retour (e, ia) ->
    begin
      match info_ast_to_info ia with
      | InfoFun(_, tr, tp) -> (AstPlacement.Retour (e, getTaille tr, (List.fold_right (fun t tq -> tq + (getTaille t)) tp 0)), 0)
      | _ -> failwith "Erreur interne"
    end
  | AstType.Empty -> (AstPlacement.Empty, 0)


(* analyse_type_bloc : type -> info_ast option -> AstTds.bloc -> Asttype.bloc *)
(* Paramètre oia : None si le bloc li est dans le programme principal,
                   Some ia où ia est l'information associée à la fonction dans laquelle est le bloc li sinon *)
(* Paramètre li : liste d'instructions à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme le bloc en un bloc de type Asttype.bloc *)
(* Erreur si mauvaise utilisation des identifiants *)
and analyse_placement_bloc li depl reg =
  match li with
  | [] -> ([], 0)
  | t::q -> let (nt, tt) = analyse_placement_instruction t depl reg in
            let (nq, tq) = analyse_placement_bloc q (depl + tt) reg in
            (nt::nq, tt + tq)


(* analyse_type_fonction : type -> AstTds.fonction -> Asttype.fonction *)
(* Paramètre : la fonction à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme la fonction
en une fonction de type Asttype.fonction *)
(* Erreur si mauvaise utilisation des identifiants *)
let analyse_placement_fonction (AstPlacement.Fonction(t, info, lp, li)) =
  let nli = analyse_placement_bloc li 0 "LB" in
  let (_, nlpi) = List.split lp in
  AstType.Fonction(info, nlpi, nli)
  

(* analyser : AstTds.programme -> AstType.programme *)
(* Paramètre : le programme à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme le programme
en un programme de type Asttype.programme *)
(* Erreur si mauvaise utilisation des identifiants *)
let analyser (AstType.Programme (fonctions, prog)) =
  let nf = List.map (analyse_placement_fonction) fonctions in
  let nb = analyse_placement_bloc prog 0 "SB" in
  AstPlacement.Programme (nf, nb)
