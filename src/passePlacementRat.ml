(* Module de la passe de placement memoire *)
(* doit être conforme à l'interface Passe *)
open Tds
open Exceptions
open Ast
open Type
open AstPlacement

type t1 = Ast.AstType.programme
type t2 = Ast.AstPlacement.programme


(**************************************************************************************)
(* analyse_placement_instruction : AstType.instruction -> int -> string ->            *)
(* AstPlacement.instruction * int                     *)
(* Parametre i : l'instruction à analyser.                                            *)
(* Parametre depl : le déplacement courant par rapport au registre.                   *)
(* Parametre reg : le registre courant (SB ou LB).                                    *)
(* Calcule l'adresse relative des variables déclarées et transforme l'instruction.    *)
(* Renvoie l'instruction placée et la taille occupée par les variables déclarées.     *)
(* Erreur si mauvaise utilisation interne des identifiants.                           *)
(**************************************************************************************)
let rec analyse_placement_instruction i depl reg =
  match i with
  | AstType.Declaration (info, e) ->
    begin
      match info_ast_to_info info with
      | InfoVar (_, t, _, _) -> 
        (* Mise à jour de l'adresse de la variable dans l'info_ast *)
        modifier_adresse_variable depl reg info;
        (AstPlacement.Declaration(info, e), getTaille t)
      | _ -> failwith "Erreur interne"
    end
  | AstType.Affectation (a, e) -> (AstPlacement.Affectation (a, e), 0)
  | AstType.AffichageInt e -> (AstPlacement.AffichageInt (e), 0)
  | AstType.AffichageRat e -> (AstPlacement.AffichageRat (e), 0)
  | AstType.AffichageBool e -> (AstPlacement.AffichageBool (e), 0)
  | AstType.Conditionnelle (c, t, e) ->
    (* Analyse des blocs sans modifier le déplacement courant pour la suite du programme *)
    let nt = analyse_placement_bloc t depl reg in
    let ne = analyse_placement_bloc e depl reg in
    (AstPlacement.Conditionnelle (c, nt, ne), 0)
  | AstType.TantQue (c, b) ->
    let nb = analyse_placement_bloc b depl reg in
    (AstPlacement.TantQue (c, nb), 0)
  | AstType.Retour (e, ia) ->
    begin
      match info_ast_to_info ia with
      | InfoFun(_, tr, tp) -> 
        (* Calcul de la taille des paramètres pour le nettoyage de la pile *)
        (AstPlacement.Retour (e, getTaille tr, (List.fold_right (fun t tq -> tq + (getTaille t)) tp 0)), 0)
      | _ -> failwith "Erreur interne"
    end
  | AstType.Empty -> (AstPlacement.Empty, 0)


(**************************************************************************************)
(* analyse_placement_bloc : AstType.bloc -> int -> string -> AstPlacement.bloc * int  *)
(* Parametre li : liste d'instructions à analyser.                                    *)
(* Parametre depl : le déplacement initial dans le bloc.                              *)
(* Parametre reg : le registre courant.                                               *)
(* Parcourt les instructions en mettant à jour le déplacement au fur et à mesure      *)
(* des déclarations. Renvoie le bloc placé et la taille totale allouée par le bloc.   *)
(* Erreur si mauvaise utilisation des identifiants.                                   *)
(**************************************************************************************)
and analyse_placement_bloc li depl reg =
  match li with
  | [] -> ([], 0)
  | t::q -> 
      (* Analyse de l'instruction courante *)
      let (nt, tt) = analyse_placement_instruction t depl reg in
      (* Analyse de la suite avec le déplacement mis à jour *)
      let (nq, tq) = analyse_placement_bloc q (depl + tt) reg in
      (nt::nq, tt + tq)


(**************************************************************************************)
(* analyse_placement_fonction : AstType.fonction -> AstPlacement.fonction             *)
(* Parametre : la fonction à analyser.                                                *)
(* Place les paramètres (déplacement négatif par rapport à LB) et les variables       *)
(* locales (déplacement positif par rapport à LB).                                    *)
(* Erreur si mauvaise utilisation des identifiants.                                   *)
(**************************************************************************************)
let analyse_placement_fonction (AstType.Fonction(info, lp, li)) =
  (* Fonction auxiliaire pour placer les paramètres en remontant depuis LB *)
  let rec placement_variables lvar depl =
    match lvar with
    | [] -> ()
    | ia::q ->
      begin
        match info_ast_to_info ia with
        | InfoVar (_, t, _, _) ->
          (* Calcul du déplacement : LB - taille totale paramètres + offset *)
          modifier_adresse_variable (depl - getTaille t) "LB" ia;
          placement_variables q (depl - getTaille t)
        | _ -> failwith "Erreur interne"
      end
    in 
  (* Placement des paramètres *)
  let _ = placement_variables (List.rev lp) 0 in
  (* Placement du corps de la fonction : les locales commencent à LB + 3 (après le chainage statique, etc) *)
  let nli = analyse_placement_bloc li 3 "LB" in
  AstPlacement.Fonction(info, lp, nli)
  

(**************************************************************************************)
(* analyser : AstType.programme -> AstPlacement.programme                             *)
(* Parametre : le programme à analyser.                                               *)
(* Lance le placement des fonctions et du bloc principal (sur SB).                    *)
(* Erreur si mauvaise utilisation des identifiants.                                   *)
(**************************************************************************************)
let analyser (AstType.Programme (fonctions, prog)) =
  let nf = List.map (analyse_placement_fonction) fonctions in
  (* Le bloc principal commence à l'adresse 0 du registre SB *)
  let nb = analyse_placement_bloc prog 0 "SB" in
  AstPlacement.Programme (nf, nb)