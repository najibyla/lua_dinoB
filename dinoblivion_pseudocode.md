# Dinoblivion — Pseudocode Métier Complet
> Généré le 2026-04-11 à partir de `regleslimpides.txt` + `dino-fr.md`
> Base pour la réimplémentation TTS Lua (sessions 11+)
> **NB : La sélection clan/chef de clan existante dans le code est conservée telle quelle.**

---

## SOMMAIRE

1. [Structures de données](#1-structures-de-données)
2. [Base de données cartes](#2-base-de-données-cartes)
3. [SETUP — Mode Duel](#3-setup--mode-duel)
4. [SETUP — Mode Solo](#4-setup--mode-solo)
5. [SETUP — Mode 3-4 Joueurs](#5-setup--mode-3-4-joueurs)
6. [Boucle de jeu principale](#6-boucle-de-jeu-principale)
7. [Actions disponibles](#7-actions-disponibles)
8. [Mécanique RAGE](#8-mécanique-rage)
9. [Mécanique Totem](#9-mécanique-totem)
10. [Fin de partie et score](#10-fin-de-partie-et-score)
11. [Mode Solo — règles spécifiques](#11-mode-solo--règles-spécifiques)
12. [Pouvoirs spéciaux des cartes](#12-pouvoirs-spéciaux-des-cartes)

---

## 1. Structures de données

```
MODES = { DUEL, SOLO, MULTI }   -- mode actif

-- ─── Ressources ───────────────────────────────────────────────
RESSOURCES = {
    nourriture  : int (0–6, max banque = 6)
    pion_ami    : int (0–6)
    jeton_dino  : int (0–6)
    oeufs       : liste de OEUF  -- face cachée jusqu'en fin de partie
}

OEUF = {
    id          : string   -- "vert_1" … "bleu_4"
    valeur      : int      -- 1 (vert) | 2 (rouge) | 2 (bleu indestructible)
    indestructible : bool  -- vrai pour les 4 bleus
    face_visible   : bool  -- false jusqu'au décompte final (ou Neandertar)
}

-- ─── Carte ────────────────────────────────────────────────────
CARTE = {
    id              : string
    nom             : string
    type            : enum { clan, action, chef, dino_l1, dino_l2, ennemi, unique }
    force           : int | fn(joueur) -> int   -- peut être dynamique (Mom, Protectar…)
    cout_achat      : int                        -- en nourriture (action) ou pion_ami (clan)
    food_reward     : int                        -- nourriture gagnée si révélée lors d'une chasse (add_nourriture)
    totem_count     : int                        -- 0 | 1 | 3 (carte Totem)
    carte_unique    : bool
    ami_side        : enum { gauche, droite, both, aucun }  -- emplacement_demi_ami
    reward_action   : fn(joueur, contexte) -> void          -- effet quand activée
    reward_si_new_ami : fn(joueur, autre_carte) -> void     -- bonus quand paire ami complétée
    reward_dino     : fn(joueur) -> void                    -- récompense combat dino
}

-- ─── Zones d'un plateau joueur ────────────────────────────────
PLATEAU_JOUEUR = {
    deck            : pile de CARTE   -- côté jour, face cachée, gauche
    defausse        : pile de CARTE   -- côté nuit, face visible, droite
    main            : liste de CARTE  -- 4 cartes max en début de tour
    grotte          : CARTE | nil     -- 1 seule carte, hors défausse en fin de tour
    zone_jeu        : liste de CARTE  -- cartes jouées ce tour (vont en défausse en fin de tour)
    zone_totem      : liste de CARTE  -- totems actifs (restent entre les tours)
    zone_trophee    : liste de CARTE  -- dinos vaincus + totems en jeu
                                      -- aussi: oeufs face cachée, cartes tropées
    reserve         : RESSOURCES      -- jetons sur le plateau
    banque          : {               -- réserve au-dessus du plateau
        nourriture  : int  -- max 6
        pion_ami    : int  -- max 6
        jeton_dino  : int  -- max 6
    }
}

-- ─── Plateau principal ────────────────────────────────────────
PLATEAU_PRINCIPAL = {
    jungle          : pile de CARTE   -- pioche commune (clan + action mélangés)
    territoire_gauche : pile de CARTE -- marché gauche (cartes face visible)
    territoire_droit  : pile de CARTE -- marché droit  (cartes face visible)
    dino_gauche     : pile de CARTE   -- 3 dino_l2 + 3 dino_l1 par-dessus, dino_l1 visible
    dino_droit      : pile de CARTE   -- idem
    banque_oeufs    : liste de OEUF   -- 24 (duel/multi) | 12 (solo), face cachée
    marqueur_massue : JOUEUR | nil    -- premier joueur
}

-- ─── Solo uniquement ──────────────────────────────────────────
ETAT_SOLO = {
    ennemis_gauche  : liste de CARTE_ENNEMI  -- max 4 au total ennemis gauche+droit
    ennemis_droit   : liste de CARTE_ENNEMI
    volcan_actif    : bool
    cartes_reserve  : liste de CARTE  -- cartes jungle non utilisées au départ (pour réintroduction)
    difficulte      : enum { cueilleur=40, chasseur=36, guerrier=32, chef=28 }
}
```

---

## 2. Base de données cartes

### 2.1 Cartes de départ (identiques Soleil et Lune, ami_side = marqueur clan)

| ID           | type   | force | cout | food_reward | totem | ami_side | reward_action |
|---|---|---|---|---|---|---|---|
| ami          | action | 0     | 0    | 0           | 0     | —        | +1 pion_ami |
| dinoblivion  | action | 0     | 0    | 0           | 0     | —        | détruire N jeton_dino → +2N force (max 6 dino → 12 force) |
| fructam      | action | 0     | 0    | 0           | 0     | —        | CHOIX: +2 nourriture OU piocher +2 cartes |
| bananar      | clan   | 0     | 0    | 1           | 0     | droite   | +1 nourriture |
| explorar     | clan   | 1     | 0    | 0           | 0     | gauche   | — |

### 2.2 Cartes Chef de clan (1 par joueur, conservé dans le code actuel)

| ID     | force | ami_side | reward_action |
|---|---|---|---|
| bobor  | 1     | droite   | détruire carte en jeu → +2 pion_ami |
| cornio | 2     | droite   | détruire carte en jeu → +3 nourriture |
| magda  | 2     | gauche   | détruire carte en jeu → +2 jeton_dino |
| sillia | 3     | gauche   | détruire carte en jeu → +1 jeton_dino +1 nourriture |
| slayar | 2     | droite   | détruire carte en jeu → +4 force (ce tour) |

> La sélection chef de clan est déjà implémentée — **ne pas modifier**.

### 2.3 Cartes Action brunes (achat en nourriture)

| ID           | food | cout | totem | unique | reward_action |
|---|---|---|---|---|---|
| monki        | 1    | 3    | 1     | oui    | jouer 1 carte action brune |
| banana_boost | 1    | 2    | 0     | oui    | +4 nourriture |
| capturar     | 1    | 2    | 0     | non    | +2 jeton_dino |
| dino_farm    | 2    | 5    | 1     | non    | CHOIX: +1 nourriture OU +1 jeton_dino |
| dino_tool    | 1    | 4    | 1     | non    | détruire 1 jeton_dino → piocher +2 cartes |
| fiyar        | 2    | 5    | 1     | non    | piocher +1 carte |
| hut          | 1    | 4    | 1     | non    | +1 pion_ami |
| mammotar     | 1    | 3    | 1     | non    | détruire 2 nourriture → +4 force |
| rotam        | 2    | 4    | 0     | non    | +5 force |
| stellar      | 1    | 2    | 0     | non    | +1 nourriture +1 jeton_dino +1 pion_ami |
| tigar        | 1    | 2    | 1     | non    | +1 force |
| totem        | 2    | 6    | 3     | non    | — (totem pur, 3 symboles VP) |
| troc         | 2    | 6    | 0     | non    | +1 oeuf +2 pion_ami |
| yak          | 1    | 2    | 1     | non    | +1 nourriture |
| yolo         | 1    | 3    | 0     | non    | +1 jeton_dino + piocher +2 cartes |

### 2.4 Cartes Clan grises (achat en pion_ami)

| ID          | force              | cout | ami_side | unique | reward_action |
|---|---|---|---|---|---|
| zazza       | 3                  | 2    | gauche   | oui    | dépenser 2 pion_ami → +8 force |
| ayla        | 0                  | 2    | both     | oui    | — / reward_si_new_ami: si autre_carte.ami_side==gauche → +1 oeuf; si ==droite → +1 pion_ami |
| dino_ridar  | =nb_oeufs_joueur   | 2    | droite   | oui    | — |
| mom         | =nb_clan_en_jeu    | 3    | gauche   | non    | — (force dynamique inclut elle-même) |
| protectar   | =nb_totems_en_jeu  | 2    | droite   | non    | — (force dynamique: totems sur cartes brunes en zone_totem) |
| gogo        | 3                  | 3    | both     | non    | — / reward_si_new_ami: piocher +2 cartes (par paire) |
| amazar      | 2                  | 2    | gauche   | non    | +1 jeton_dino +1 nourriture |
| artis       | 0                  | 1    | droite   | non    | jouer carte action brune PUIS piocher +1 carte |
| dominatar   | 2                  | 2    | gauche   | non    | détruire 2 jeton_dino → +7 force |
| gilir       | 1                  | 1    | gauche   | non    | +1 jeton_dino |
| huntar      | 3                  | 2    | gauche   | non    | — |
| kraf_dinar  | 2                  | 3    | gauche   | non    | +2 jeton_dino |
| neandertar  | 4                  | 3    | droite   | non    | (DUEL seulement) adversaire perd 1 oeuf choisi au hasard parmi les siens, révélé et retiré du jeu |
| patrak      | 2                  | 1    | droite   | non    | dépenser 1 nourriture → +3 force |
| shaman      | 1                  | 1    | droite   | non    | si nb_totems_en_jeu ≥ 4 → +1 oeuf |
| workar      | 2                  | 2    | droite   | non    | jouer 2 cartes action brunes simultanément (avec 1 activation clan) |

### 2.5 Dinosaures Niveau 1 (6 uniques, 8 cartes total)

| ID               | qty | force | reward_dino |
|---|---|---|---|
| pterodactyle     | x1  | 7     | détruire 1 carte, +1 pion_ami, +1 oeuf |
| compsognathus    | x1  | 7     | détruire 1 carte, +1 oeuf, +2 jeton_dino |
| stegosaurus      | x2  | 8     | détruire 1 carte, +2 oeufs |
| dilophosaurus    | x1  | 9     | détruire 1 carte, +1 carte_chasse (sans mélange), +1 pion_ami |
| ankylosaurus     | x1  | 9     | détruire 1 carte, +1 carte_chasse (sans mélange), +2 nourriture |
| raptor           | x2  | 10    | détruire 1 carte, +1 carte_chasse (sans mélange), +1 oeuf |

> **Total pile L1** : 8 cartes (6 uniques, stegosaurus×2 et raptor×2)

### 2.6 Dinosaures Niveau 2 (6 uniques, 8 cartes total)

| ID               | qty | force | reward_dino |
|---|---|---|---|
| allosaurus       | x2  | 16    | détruire 1 carte, +1 carte_chasse (sans mélange), +1 pion_ami, +1 oeuf |
| brachiosaurus    | x1  | 17    | détruire 1 carte, +3 oeufs |
| parasaurolophus  | x1  | 17    | détruire 1 carte, +2 pion_ami, +2 oeufs |
| spinosaurus      | x1  | 18    | détruire 1 carte, +1 carte_chasse (sans mélange), +2 oeufs |
| triceratops      | x1  | 18    | détruire 2 cartes, +3 cartes_chasse (sans mélange) |
| tyrannosaurus    | x2  | 19    | détruire 1 carte, +1 carte_chasse (sans mélange), +2 oeufs |

> **Total pile L2** : 8 cartes (6 uniques, allosaurus×2 et tyrannosaurus×2)

> **Note "carte_chasse (sans mélange)"** : le joueur prend une carte au choix du territoire de chasse
> adjacent au dino vaincu. Les cartes du territoire ne sont PAS remélangées.

### 2.7 Cartes Ennemi (Solo uniquement)

| ID          | condition_victoire |
|---|---|
| cannibalar  | force ≥ 3 ET dépenser 1 pion_ami |
| cultist     | force ≥ 4 ET détruire 1 carte en jeu |
| piranar     | force ≥ 1 ET dépenser 1 jeton_dino |
| coconar     | force ≥ 2 ET dépenser 2 nourriture |

---

## 3. SETUP — Mode Duel

```
PROCEDURE setup_duel():

    -- A. Table physique --
    placer plateau_principal au centre
    placer plateau_joueur_p1 côté joueur 1
    placer plateau_joueur_p2 côté joueur 2

    -- B. Banque oeufs --
    constituer banque_oeufs = 24 oeufs (12 verts×1pt, 8 rouges×2pt, 4 bleus×2pt indestructibles)
    mélanger banque_oeufs face_cachée
    placer banque_oeufs au centre de la table

    -- C. Banques de réserves joueurs --
    POUR chaque joueur p:
        p.banque = { nourriture=6, pion_ami=6, jeton_dino=6 }
        -- Ressources de départ sur le plateau joueur --
        p.reserve = { nourriture=2, pion_ami=2, jeton_dino=0, oeufs=[] }
        -- (1 jeton nourriture valeur=2 face visible = équivaut à 2 nourriture)

    -- D. Jungle --
    jungle = mélanger(toutes_cartes_clan + toutes_cartes_action)
    -- Retirer les 4 cartes ennemi (mode solo uniquement) --
    placer jungle sur plateau_principal.jungle

    -- E. Dinosaures --
    POUR chaque côté (gauche, droit) du plateau_principal:
        pile_l2 = mélanger(3 dino_l2 aléatoires parmi les 8)
        pile_l1 = mélanger(3 dino_l1 aléatoires parmi les 8)
        placer pile_l2 face_cachée
        placer pile_l1 face_cachée PAR-DESSUS pile_l2
        révéler carte du dessus (premier dino à combattre)

    -- F. Sélection premier joueur (implémentation existante conservée) --
    -- Chaque joueur lance ses 6 pions ami ; celui qui en a le plus debout = premier joueur --
    premier_joueur = determine_premier_joueur()
    attribuer marqueur_massue à premier_joueur

    -- G. Sélection chef de clan (implémentation existante conservée) --
    -- setup_manager.chief_selection déjà implémenté --

    -- H. Deck de départ --
    POUR chaque joueur p:
        p.deck = 9 cartes clan (soleil ou lune selon choix)
        ajouter p.chef_de_clan à p.deck
        mélanger p.deck
        placer p.deck sur plateau_joueur.deck (côté jour, gauche)

    -- I. Territoires de chasse --
    territoire_gauche = []
    territoire_droit  = []
    -- (vides au départ, se rempliront lors des premières chasses et RAGE)

    -- J. Pioche initiale --
    POUR chaque joueur p:
        p.main = piocher(p.deck, 4)

    -- K. Ordre de jeu --
    tour_actuel = premier_joueur
    fin_declenchee = false
    dernier_tour_second = false
```

---

## 4. SETUP — Mode Solo

```
PROCEDURE setup_solo(difficulte):

    -- A. Table --
    placer plateau_joueur (côté SOLO) devant le joueur
    placer plateau_principal (côté SOLO)

    -- B. Banque oeufs solo --
    tous_oeufs = 24 oeufs (12 verts, 8 rouges, 4 bleus)
    mélanger tous_oeufs face_cachée
    banque_oeufs = prendre(tous_oeufs, 12)
    -- Les 12 oeufs restants sont mis de côté --

    -- C. Banque réserve --
    banque = { nourriture=3, pion_ami=6, jeton_dino=6 }
    reserve_joueur = { nourriture=2, pion_ami=2, jeton_dino=0, oeufs=[] }
    -- (1 nourriture valeur=2 face visible = 2 nourriture)

    -- D. Sélection clan + chef (existant) --
    -- (même logique que duel, sans confrontation premier joueur)

    -- E. Jungle selon difficulté --
    toutes_jungle = mélanger(toutes_cartes_clan + toutes_cartes_action)
    nb_cartes = difficulte  -- 40 | 36 | 32 | 28
    jungle = prendre(toutes_jungle, nb_cartes)
    cartes_reserve_solo = cartes_jungle_restantes  -- garder pour réintroduire via oeufs

    -- F. Ajouter les 4 cartes ennemi à la jungle --
    ajouter(jungle, [cannibalar, cultist, piranar, coconar])
    mélanger(jungle, 3 fois)

    -- G. Dinosaures solo --
    dino_l1_pile = mélanger(8 dino_l1)
    zone_gauche_dinos = prendre(dino_l1_pile, 4)
    révéler carte du dessus de zone_gauche_dinos
    détruire le reste

    dino_l2_pile = mélanger(8 dino_l2)
    zone_droite_dinos = prendre(dino_l2_pile, 3)
    révéler carte du dessus de zone_droite_dinos
    détruire le reste

    -- H. État volcan --
    etat_solo.volcan_actif = false
    etat_solo.ennemis_gauche = []
    etat_solo.ennemis_droit  = []

    -- I. Pioche initiale --
    main = piocher(deck, 4)
```

---

## 5. SETUP — Mode 3-4 Joueurs

```
PROCEDURE setup_multi(nb_joueurs):

    -- Requiert 2 boîtes du jeu --
    -- A. Jungle doublée --
    jungle = mélanger(
        toutes_cartes_clan_boite1 + toutes_cartes_action_boite1 +
        toutes_cartes_clan_boite2 + toutes_cartes_action_boite2
        -- inclure toutes les cartes uniques des deux boîtes --
    )
    -- Retirer les cartes ennemi (mode solo) des deux boîtes --

    -- B. Oeufs doublés --
    banque_oeufs = 48 oeufs (24 par boîte) mélangés face_cachée

    -- C. Dinosaures doublés --
    POUR chaque emplacement dino (gauche, droit) du plateau_principal:
        pile_l2 = mélanger(8 dino_l2 boite1 + 8 dino_l2 boite2)  -- 16 total
        pile_l1 = mélanger(8 dino_l1 boite1 + 8 dino_l1 boite2)  -- 16 total
        choisir 6 dino_l2 + 6 dino_l1 par emplacement
        placer comme en duel (11 dessous, l1 dessus, révéler le dessus)

    -- D. Un plateau joueur par joueur (côté Duel) --
    POUR chaque joueur p (1 à nb_joueurs):
        même setup que Duel: deck de départ, chef de clan, réserves

    -- E. Premier joueur --
    même règle qu'en Duel (lancer pions ami)

    -- F. Ordre de jeu --
    Sens horaire depuis le premier joueur
    fin_declenchee = false
    -- Quand fin déclenchée par le 1er joueur → tous les autres jouent encore 1 tour --
    -- Quand fin déclenchée par un autre joueur → les joueurs entre lui et le 1er joueur
    --   (dans le sens du tour) jouent encore 1 tour --
```

---

## 6. Boucle de jeu principale

```
PROCEDURE game_loop():

    TANT QUE NOT fin_de_partie():

        joueur = joueur_actif()

        -- ─── DÉBUT DE TOUR ───────────────────────────────
        verifier_rage(joueur)     -- vérifier AVANT de piocher (voir §8)
        piocher(joueur, jusqu_a=4)

        -- ─── PHASE D'ACTION ──────────────────────────────
        actions_restantes = true
        TANT QUE actions_restantes:
            action = choisir_action(joueur)
            SELON action:
                CASE CHASSER      : action_chasser(joueur)
                CASE ATTAQUER     : action_attaquer_dino(joueur)
                CASE JOUER_ACTION : action_jouer_carte_action(joueur)
                CASE GAGNER_AMI   : action_gagner_pion_ami(joueur)
                CASE POUVOIR      : action_pouvoir_carte(joueur)
                CASE GROTTE       : action_grotte(joueur)
                CASE ACHETER      : action_acheter_carte(joueur)  -- pas une action formelle
                CASE FIN_TOUR     : actions_restantes = false

        -- ─── FIN DE TOUR ─────────────────────────────────
        fin_de_tour(joueur)

        -- ─── VÉRIFICATION FIN DE PARTIE ──────────────────
        SI condition_fin_partie(plateau_principal):
            fin_declenchee = true
            SI joueur == premier_joueur:
                -- L'autre joueur (duel) ou les suivants (multi) jouent 1 dernier tour --
                jouer_derniers_tours()
            SINON:
                -- En multi: joueurs suivants jusqu'au premier joueur jouent leur dernier tour --
                jouer_derniers_tours_jusqua_premier()
            BREAK

        passer_au_joueur_suivant()

    decompte_final()


PROCEDURE fin_de_tour(joueur):
    -- 1. Défausser toutes les cartes de zone_jeu → defausse
    POUR carte IN joueur.zone_jeu:
        ajouter(joueur.defausse, carte)
    joueur.zone_jeu = []

    -- 2. Défausser la main restante → defausse
    POUR carte IN joueur.main:
        ajouter(joueur.defausse, carte)
    joueur.main = []

    -- 3. Réactiver tous les totems (remettre à 0° / inactive)
    POUR totem IN joueur.zone_totem:
        totem.est_actif = false  -- prêt à être activé au prochain tour

    -- 4. La grotte reste (ne va PAS en défausse)
    -- 5. Les cartes totem en zone_totem restent (ne vont PAS en défausse)


PROCEDURE piocher(joueur, jusqu_a=4):
    manque = jusqu_a - #joueur.main
    TANT QUE manque > 0 ET (#joueur.deck > 0 OU #joueur.defausse > 0):
        SI #joueur.deck == 0:
            -- Recycler la défausse --
            joueur.deck = mélanger(joueur.defausse)
            joueur.defausse = []
        carte = retirer_dessus(joueur.deck)
        ajouter(joueur.main, carte)
        manque = manque - 1
```

---

## 7. Actions disponibles

### 7.1 Activer une carte Clan (prérequis pour plusieurs actions)

```
-- Activer = faire pivoter la carte à 90° dans zone_jeu
-- Une carte clan déjà activée ne peut pas l'être à nouveau ce tour

PROCEDURE activer_carte_clan(joueur, carte_clan):
    PRECOND: carte_clan IN joueur.main OR carte_clan IN joueur.zone_jeu (non encore activée)
    PRECOND: NOT carte_clan.est_activee
    déplacer carte_clan vers joueur.zone_jeu  -- si elle était en main
    carte_clan.est_activee = true
    -- (rotation 90° dans TTS)
```

### 7.2 Action CHASSER

```
PROCEDURE action_chasser(joueur, carte_clan, territoire):
    -- territoire: "gauche" | "droit"
    PRECOND: carte_clan.type == "clan" AND NOT carte_clan.est_activee
    activer_carte_clan(joueur, carte_clan)  -- sans récolter son reward_action

    force = calculer_force(joueur, carte_clan)
    food_gagne = 0
    cartes_revelees = []

    POUR i = 1 À force:
        SI #jungle == 0: BREAK
        carte = retirer_dessus(jungle)
        SI MODE == SOLO ET carte.type == "ennemi":
            -- Lors d'une chasse, les ennemis sont renvoyés sous la jungle --
            remettre_sous(jungle, carte)
            CONTINUE
        ajouter(territoire[territoire], carte)  -- face visible
        ajouter(cartes_revelees, carte)
        SI carte.type == "action":  -- carte brune = food_reward
            food_gagne += carte.food_reward

    -- Ajouter la nourriture gagnée à la réserve joueur --
    ajouter_ressource(joueur, "nourriture", food_gagne)

    RETOURNER cartes_revelees


-- Note: les cartes sur le dessus des deux territoires forment le marché disponible à l'achat.
-- On ne peut pas chasser sur les deux territoires en même temps avec une seule carte.
```

### 7.3 Action ACHETER une carte (pas une action formelle, peut être faite à tout moment)

```
PROCEDURE action_acheter_carte(joueur, carte, territoire):
    -- La carte doit être au SOMMET du territoire (marché)
    PRECOND: carte == territoire.pile[1]  -- sommet de pile

    SI carte.type == "clan" OR carte.type == "unique_clan":
        PRECOND: joueur.reserve.pion_ami >= carte.cout_achat
        joueur.reserve.pion_ami -= carte.cout_achat

    SI carte.type == "action":
        PRECOND: joueur.reserve.nourriture >= carte.cout_achat
        joueur.reserve.nourriture -= carte.cout_achat

    retirer(territoire.pile, carte)
    ajouter(joueur.defausse, carte)  -- va dans la défausse (côté nuit)
```

### 7.4 Action JOUER UNE CARTE ACTION brune

```
PROCEDURE action_jouer_carte_action(joueur, carte_clan, carte_action):
    -- L'activation d'une carte clan sert de "support" à la carte action
    PRECOND: carte_clan.type == "clan" AND NOT carte_clan.est_activee
    PRECOND: carte_action.type == "action" AND carte_action IN joueur.main

    activer_carte_clan(joueur, carte_clan)  -- sans son propre reward_action

    SI carte_action.totem_count > 0:
        -- Carte Totem: va dans zone_totem (gauche du plateau), reste entre les tours
        retirer(joueur.main, carte_action)
        ajouter(joueur.zone_totem, carte_action)
        carte_action.est_active = false  -- inactive jusqu'à activation ce tour
        -- Le joueur peut l'activer immédiatement ce tour (action Totem §9)
    SINON:
        -- Carte action normale: va dans zone_jeu, part en défausse en fin de tour
        retirer(joueur.main, carte_action)
        ajouter(joueur.zone_jeu, carte_action)
        appliquer(carte_action.reward_action, joueur)
```

### 7.5 Action GAGNER UN PION AMI (combiner les moitiés)

```
PROCEDURE action_gagner_pion_ami(joueur, carte_a, carte_b):
    -- Combiner deux moitiés de symbole ami pour former un cercle complet
    -- Combinaisons valides: (gauche + droite), (both + droite), (both + gauche), (both + both)
    PRECOND: cartes_forment_paire_ami(carte_a, carte_b)
    PRECOND: carte_a IN joueur.zone_jeu AND carte_b IN joueur.zone_jeu (activées)

    ajouter_ressource(joueur, "pion_ami", 1)

    -- Bonus spéciaux si "both" impliqué --
    SI carte_a.ami_side == "both":
        appliquer(carte_a.reward_si_new_ami, joueur, carte_b)
    SI carte_b.ami_side == "both":
        appliquer(carte_b.reward_si_new_ami, joueur, carte_a)

    -- Cas Ayla: dépend du côté de l'autre carte
    SI carte_a.id == "ayla" OR carte_b.id == "ayla":
        autre = SI carte_a.id == "ayla" ALORS carte_b SINON carte_a
        SI autre.ami_side == "gauche": ajouter_ressource(joueur, "oeuf", 1)
        SI autre.ami_side == "droite": ajouter_ressource(joueur, "pion_ami", 1)

    -- Cas double Gogo: (both + both) avec 2 Gogo = 1 pion ami + piocher 4 cartes
    SI carte_a.id == "gogo" AND carte_b.id == "gogo":
        piocher(joueur, 2)  -- +2 cartes par gogo = 4 cartes au total
        -- (déjà compté 1 pion ami ci-dessus)


FONCTION cartes_forment_paire_ami(a, b):
    RETOURNER (a.ami_side == "gauche" AND b.ami_side == "droite") OR
              (a.ami_side == "droite" AND b.ami_side == "gauche") OR
              (a.ami_side == "both"   AND b.ami_side IN {"gauche","droite","both"}) OR
              (b.ami_side == "both"   AND a.ami_side IN {"gauche","droite","both"})
```

### 7.6 Action UTILISER LE POUVOIR d'une carte Clan

```
PROCEDURE action_pouvoir_carte(joueur, carte_clan):
    PRECOND: carte_clan.type == "clan" AND NOT carte_clan.est_activee
    activer_carte_clan(joueur, carte_clan)  -- avec son reward_action
    appliquer(carte_clan.reward_action, joueur)
```

### 7.7 Action ATTAQUER un Dinosaure

```
PROCEDURE action_attaquer_dino(joueur, dino, cartes_utilisees, carte_a_detruire):
    -- Le joueur cumule la force de plusieurs cartes
    force_totale = somme(calculer_force(joueur, c) for c in cartes_utilisees)
    PRECOND: force_totale >= dino.force
    PRECOND: #carte_a_detruire >= 1  -- toujours au moins 1 (parfois 2 pour Triceratops)
    PRECOND: une seule pile de dino attaquée par tour

    -- Activer toutes les cartes utilisées --
    POUR carte IN cartes_utilisees:
        activer_carte_clan(joueur, carte)  -- sans reward_action

    -- Destruction obligatoire de cartes --
    nb_destroy = dino.reward_dino.nb_destroy  -- 1 pour la plupart, 2 pour Triceratops
    POUR i = 1 À nb_destroy:
        -- Le joueur choisit une carte parmi: main + zone_jeu + grotte
        retirer_du_jeu(joueur, carte_a_detruire[i])

    -- Récompenses dino --
    appliquer_reward_dino(joueur, dino, dino.reward_dino)

    -- Placer le dino vaincu comme trophée --
    retirer(pile_dino_correspondante, dino)
    ajouter(joueur.zone_trophee, dino)

    -- Révéler le prochain dino dans la pile --
    SI #pile_dino_correspondante > 0:
        révéler(pile_dino_correspondante[1])
    SINON:
        -- Pile vide: déclencher fin de partie (vérification §10) ou volcan solo
        verifier_condition_fin()

    -- Limite: 1 seul dino par pile par tour --
    joueur.dino_attaque_ce_tour[côté] = true


PROCEDURE appliquer_reward_dino(joueur, dino, reward):
    SI reward.pion_ami > 0:    ajouter_ressource(joueur, "pion_ami", reward.pion_ami)
    SI reward.nourriture > 0:  ajouter_ressource(joueur, "nourriture", reward.nourriture)
    SI reward.jeton_dino > 0:  ajouter_ressource(joueur, "jeton_dino", reward.jeton_dino)

    SI reward.oeufs > 0:
        POUR i = 1 À reward.oeufs:
            oeuf = prendre_oeuf_banque(banque_oeufs)
            SI oeuf != nil:
                ajouter(joueur.reserve.oeufs, oeuf)  -- face cachée, zone_trophee gauche
                SI MODE == SOLO:
                    -- Révéler la valeur de l'oeuf pour ajouter des cartes dans la jungle --
                    oeuf.face_visible = true
                    nb_cartes_a_ajouter = oeuf.valeur
                    POUR i = 1 À nb_cartes_a_ajouter:
                        carte = prendre(cartes_reserve_solo)
                        SI carte != nil:
                            remettre_sous(jungle, carte)

    SI reward.carte_chasse > 0:
        -- Le joueur prend la carte au sommet du territoire adjacent (sans mélanger) --
        territoire = territoire_adjacent_dino(dino)
        carte = prendre_sommet(territoire)
        SI carte != nil:
            ajouter(joueur.defausse, carte)
```

### 7.8 Action GROTTE

```
PROCEDURE action_grotte(joueur, carte_main, carte_grotte_optionnelle):
    -- Placer une carte de la main dans la grotte (ou échanger avec celle en grotte)
    -- La grotte ne peut contenir qu'une seule carte à la fois

    SI joueur.grotte != nil:
        -- Échange: reprendre la carte de la grotte dans la main
        ajouter(joueur.main, joueur.grotte)
    joueur.grotte = carte_main
    retirer(joueur.main, carte_main)
    -- La carte en grotte ne part pas en défausse en fin de tour
```

---

## 8. Mécanique RAGE

```
PROCEDURE verifier_rage(joueur):
    -- La RAGE se déclenche quand le deck (côté jour) est vide au moment de piocher
    SI #joueur.deck == 0:
        declencher_rage(joueur)


PROCEDURE declencher_rage(joueur):
    SI MODE == DUEL OR MODE == MULTI:
        rage_duel(joueur)
    SI MODE == SOLO:
        rage_solo(joueur)


PROCEDURE rage_duel(joueur):
    -- Pour chaque côté du plateau principal, révéler N cartes de la jungle
    -- N = niveau du dino face visible au-dessus de l'emplacement

    POUR côté IN ["gauche", "droit"]:
        dino_visible = pile_dino[côté][1]  -- dino du dessus (face visible)
        SI dino_visible != nil:
            n = dino_visible.niveau  -- 1 ou 2
            POUR i = 1 À n:
                SI #jungle == 0: BREAK
                carte = retirer_dessus(jungle)
                ajouter(territoire[côté], carte)
                -- (pas de food_reward pour les cartes révélées par RAGE)
        SINON:
            -- Pile dino vide → révéler 3 cartes (volcan) --
            POUR i = 1 À 3:
                SI #jungle == 0: BREAK
                carte = retirer_dessus(jungle)
                ajouter(territoire[côté], carte)

    verifier_condition_fin()


PROCEDURE rage_solo(joueur):
    -- Même logique que duel + gestion des ennemis présents

    POUR côté IN ["gauche", "droit"]:
        dino_visible = pile_dino_solo[côté][1]

        SI dino_visible != nil:
            n = dino_visible.niveau
        SINON:
            -- Volcan activé pour ce côté --
            n = 3

        -- Cartes de base selon le niveau --
        nb_a_révéler = n
        -- Plus 1 carte par ennemi présent de CE côté --
        nb_a_révéler += #ennemis[côté]

        -- Révéler les cartes --
        POUR i = 1 À nb_a_révéler:
            SI #jungle == 0:
                -- Condition de DÉFAITE solo --
                declarer_defaite_solo()
                RETURN
            carte = retirer_dessus(jungle)
            SI carte.type == "ennemi":
                -- Ennemi révélé par RAGE: s'ajoute au côté --
                ajouter(ennemis[côté], carte)
                -- Effet immédiat: révéler 1 carte supplémentaire du MÊME côté --
                SI #jungle > 0:
                    carte_supp = retirer_dessus(jungle)
                    ajouter(territoire[côté], carte_supp)
            SINON:
                ajouter(territoire[côté], carte)

    -- Vérifier si la jungle est épuisée → défaite solo --
    SI #jungle == 0:
        declarer_defaite_solo()
```

---

## 9. Mécanique Totem

```
-- Les totems sont des cartes action brunes avec totem_count > 0.
-- Une fois posées dans zone_totem (gauche du plateau), elles persistent entre les tours.

PROCEDURE activer_totem(joueur, totem):
    -- Un totem en zone_totem peut être activé SANS utiliser de carte clan
    PRECOND: totem IN joueur.zone_totem
    PRECOND: NOT totem.est_active  -- pas encore utilisé ce tour
    totem.est_active = true
    appliquer(totem.reward_action, joueur)
    -- (rotation 90° dans TTS)


PROCEDURE reactiver_totems_fin_de_tour(joueur):
    POUR totem IN joueur.zone_totem:
        totem.est_active = false  -- remis droit, prêt pour le prochain tour


-- Calcul des totems pour Protectar et Shaman --
FONCTION nb_totems_en_jeu(joueur):
    total = 0
    POUR totem IN joueur.zone_totem:
        total += totem.totem_count  -- Carte "Totem" = 3, les autres = 1
    RETOURNER total
```

---

## 10. Fin de partie et score

### 10.1 Condition de fin

```
FONCTION condition_fin_partie():
    -- En Duel/Multi: fin si l'un de ces 3 espaces du plateau principal est VIDE:
    RETOURNER (
        #jungle == 0 OR
        #pile_dino_gauche == 0 OR
        #pile_dino_droit  == 0
    )

-- Comportement quand déclenché:
-- - Si c'est le PREMIER JOUEUR (porteur de la massue) qui déclenche la fin:
--   → Il termine son tour, puis le second joueur joue UN DERNIER TOUR.
-- - En mode multi: les joueurs entre le déclencheur et le premier joueur jouent encore 1 tour.
```

### 10.2 Décompte final

```
PROCEDURE decompte_final():

    POUR chaque joueur p:
        score[p] = 0
        toutes_cartes_joueur = union(
            p.deck, p.defausse, p.main, p.grotte, p.zone_totem, p.zone_jeu
        )
        -- NB: les cartes dino vaincues sont dans p.zone_trophee --

        -- ─── Familles (paires ami) = 2 points par paire ───
        familles = calculer_familles(toutes_cartes_joueur)
        -- Algorithme de pairing:
        --   - Associer chaque carte "gauche" avec une carte "droite"
        --   - Les cartes "both" peuvent compléter une gauche OU une droite
        --   - Gogo et Ayla comptent comme 2 (peuvent former 2 familles chacune)
        --   - Les célibataires (sans paire) = 0 point
        score[p] += familles * 2

        -- ─── Totems = 1 point par symbole totem ACTIVÉ ────
        -- Seuls les totems dans zone_totem (en jeu) comptent.
        -- Les totems dans la défausse non utilisés NE comptent PAS.
        score[p] += nb_totems_en_jeu(p)

        -- ─── Dinosaures vaincus = 1 point chacun ──────────
        score[p] += #p.zone_trophee_dinos  -- cartes dino dans la zone trophée

        -- ─── Oeufs = surprise ──────────────────────────────
        POUR oeuf IN p.reserve.oeufs:
            oeuf.face_visible = true
            score[p] += oeuf.valeur  -- 1 ou 2

    -- Afficher les scores --
    gagnant = joueur avec le score le plus élevé
    SI égalité:
        -- Tiebreak: total des niveaux des dinos vaincus --
        tiebreak = somme(dino.niveau for dino in p.zone_trophee_dinos)
        SI encore égalité: tout le monde gagne


-- Algorithme détaillé des familles --
FONCTION calculer_familles(cartes):
    -- Répartir les cartes par ami_side --
    gauche_pool = [c for c in cartes where c.ami_side IN {"gauche", "both"}]
    droite_pool = [c for c in cartes where c.ami_side IN {"droite", "both"}]
    -- Les "both" sont comptés une fois dans chaque pool
    -- Gogo: compte comme 2 (1 dans gauche + 1 dans droite = 2 familles possibles)
    -- Ayla: compte comme 2 (idem)
    -- Pour les "both" non-spéciaux: compte comme 1

    paires = 0
    TANT QUE gauche_pool non vide ET droite_pool non vide:
        g = retirer_un(gauche_pool)
        d = retirer_un(droite_pool)
        -- Si g == d (même carte "both"): impossible (ne peut pas se coupler avec elle-même)
        SI g != d:
            paires += 1
        -- (en pratique Gogo/Ayla sont représentés 2 fois dans les pools)
    RETOURNER paires
```

---

## 11. Mode Solo — règles spécifiques

### 11.1 Combat des Ennemis

```
PROCEDURE action_combattre_ennemi(joueur, ennemi, ressources_depensees):
    -- Chaque ennemi a une condition de victoire différente --
    condition = ennemi.condition_victoire
    PRECOND: force_cumul_joueur >= condition.force
    PRECOND: joueur peut payer le coût (pion_ami / jeton_dino / nourriture / détruire carte)

    -- Payer le coût --
    SI condition.cout == "pion_ami":    joueur.reserve.pion_ami -= condition.nb
    SI condition.cout == "jeton_dino":  joueur.reserve.jeton_dino -= condition.nb
    SI condition.cout == "nourriture":  joueur.reserve.nourriture -= condition.nb
    SI condition.cout == "detruire":    retirer_du_jeu(joueur, carte_choisie)

    -- Ennemi vaincu: remettre dans la jungle et mélanger --
    retirer(ennemis_presents, ennemi)
    ajouter(jungle, ennemi)
    mélanger(jungle)
```

### 11.2 Volcan Solo

```
-- Le volcan s'active quand une pile de dinos est VIDE --
PROCEDURE verifier_volcan():
    SI #pile_dino_gauche == 0 OR #pile_dino_droit == 0:
        SI NOT etat_solo.volcan_actif:
            etat_solo.volcan_actif = true
            printToAll("Le VOLCAN se réveille !")

-- Lors des prochaines RAGE avec volcan actif:
-- Le côté vide de dinos révèle 3 cartes supplémentaires (géré dans rage_solo)
```

### 11.3 Condition de victoire / défaite Solo

```
-- VICTOIRE: toutes les piles de dinos sont vidées
FONCTION condition_victoire_solo():
    RETOURNER #pile_dino_gauche == 0 AND #pile_dino_droit == 0

-- DÉFAITE: le deck jungle est épuisé (éruption volcanique)
FONCTION condition_defaite_solo():
    RETOURNER #jungle == 0
```

---

## 12. Pouvoirs spéciaux des cartes

Ces pouvoirs sont déjà partiellement implémentés. Pseudocode de référence:

```
-- ARTIS: jouer une carte action brune + piocher 1 carte
reward_action["artis"](joueur):
    joueur.peut_jouer_action_brune_gratuitement = true  -- sans activer de clan
    piocher(joueur, 1)

-- GOGO: chaque paire ami = piocher 2 cartes (par carte gogo impliquée)
reward_si_new_ami["gogo"](joueur, autre_carte):
    piocher(joueur, 2)

-- MOM: force = nombre de cartes clan en zone_jeu (inclut elle-même)
calculer_force["mom"](joueur):
    RETOURNER compte(c for c in joueur.zone_jeu where c.type == "clan")

-- PROTECTAR: force = nombre de symboles totem sur cartes brunes en zone_totem
calculer_force["protectar"](joueur):
    RETOURNER nb_totems_en_jeu(joueur)

-- NEANDERTAR: détruire 1 oeuf de l'adversaire (DUEL uniquement)
reward_action["neandertar"](joueur):
    SI MODE != DUEL: RETURN
    adversaire = autre_joueur(joueur)
    SI #adversaire.reserve.oeufs == 0: RETURN
    -- Le joueur choisit un oeuf FACE CACHÉE parmi ceux de l'adversaire
    oeuf = choisir_oeuf_aleatoire(adversaire.reserve.oeufs)
    oeuf.face_visible = true
    retirer(adversaire.reserve.oeufs, oeuf)
    -- L'oeuf est révélé et retiré du jeu (ne retourne pas dans la banque)
    -- NB: les oeufs bleus sont INDESTRUCTIBLES (ne peuvent pas être cible de Neandertar)
    -- (si tous les oeufs de l'adversaire sont bleus, aucun effet)

-- SHAMAN: si ≥ 4 symboles totem en jeu → +1 oeuf
reward_action["shaman"](joueur):
    SI nb_totems_en_jeu(joueur) >= 4:
        oeuf = prendre_oeuf_banque(banque_oeufs)
        SI oeuf != nil:
            ajouter(joueur.reserve.oeufs, oeuf)

-- WORKAR: jouer 2 cartes action avec 1 seule activation clan
reward_action["workar"](joueur):
    joueur.actions_brunes_disponibles += 2  -- au lieu de 1

-- DINOBLIVION: détruire N jetons dino → +2N force (max 6 dino = 12 force)
reward_action["dinoblivion"](joueur, nb_dino_detruits):
    PRECOND: 1 <= nb_dino_detruits <= min(6, joueur.reserve.jeton_dino)
    joueur.reserve.jeton_dino -= nb_dino_detruits
    joueur.force_bonus_ce_tour += nb_dino_detruits * 2

-- DINO RIDAR: force = nombre d'oeufs du joueur
calculer_force["dino_ridar"](joueur):
    RETOURNER #joueur.reserve.oeufs

-- ZAZZA: dépenser 2 pion_ami → +8 force
reward_action["zazza"](joueur):
    PRECOND: joueur.reserve.pion_ami >= 2
    joueur.reserve.pion_ami -= 2
    joueur.force_bonus_ce_tour += 8

-- PATRAK: dépenser 1 nourriture → +3 force
reward_action["patrak"](joueur):
    PRECOND: joueur.reserve.nourriture >= 1
    joueur.reserve.nourriture -= 1
    joueur.force_bonus_ce_tour += 3

-- DOMINATAR: détruire 2 jetons dino → +7 force
reward_action["dominatar"](joueur):
    PRECOND: joueur.reserve.jeton_dino >= 2
    joueur.reserve.jeton_dino -= 2
    joueur.force_bonus_ce_tour += 7

-- MAMMOTAR: détruire 2 nourriture → +4 force
reward_action["mammotar"](joueur):
    PRECOND: joueur.reserve.nourriture >= 2
    joueur.reserve.nourriture -= 2
    joueur.force_bonus_ce_tour += 4

-- DINO TOOL: détruire 1 jeton dino → piocher +2 cartes
reward_action["dino_tool"](joueur):
    PRECOND: joueur.reserve.jeton_dino >= 1
    joueur.reserve.jeton_dino -= 1
    piocher(joueur, 2)

-- FRUCTAM: CHOIX +2 nourriture OU piocher +2 cartes
reward_action["fructam"](joueur, choix):
    SI choix == "nourriture": ajouter_ressource(joueur, "nourriture", 2)
    SI choix == "piocher":    piocher(joueur, 2)

-- DINO FARM: CHOIX +1 nourriture OU +1 jeton dino
reward_action["dino_farm"](joueur, choix):
    SI choix == "nourriture":   ajouter_ressource(joueur, "nourriture", 1)
    SI choix == "jeton_dino":   ajouter_ressource(joueur, "jeton_dino", 1)
```

---

## ANNEXE — Règles diverses

### Cartes Uniques
- Monki, Banana Boost, Zazza, Ayla, Dino Ridar sont uniques (une seule exemplaire).
- On ne peut **pas** choisir une carte unique comme récompense de combat dino.
- Elle doivent être **achetées** sur le territoire de chasse.

### Limite des ressources
- Maximum 6 de chaque ressource dans la banque (au-dessus du plateau).
- Il n'y a pas de limite explicite dans la réserve du joueur (sur le plateau).
- Quand la banque_oeufs est épuisée, plus aucun oeuf ne peut être obtenu.

### La Grotte
- 1 seule carte à la fois.
- Peut être échangée ou récupérée à tout moment pendant le tour.
- La carte en grotte ne va pas en défausse en fin de tour.
- Elle peut être détruite (compte comme "carte en main" pour les pouvoirs chefs).

### Achat de cartes
- L'achat n'est pas une action formelle (ne compte pas dans les 5 types d'actions).
- On peut acheter à tout moment pendant son tour, autant de fois qu'on peut payer.
- On achète uniquement la carte au **sommet** du territoire de chasse.

### Indestructibilité des oeufs bleus
- Les 4 oeufs bleus sont indestructibles.
- Neandertar ne peut pas les cibler.
- Une fois révélés, ils restent en jeu.

### Séquence de destruction (Chefs de clan)
- "Détruire une carte en main" signifie: carte en main + cartes en zone_jeu + grotte.
- La carte détruite est retirée définitivement du jeu (ne va pas en défausse).

---

*Fin du pseudocode — version 1.0 (2026-04-11)*

---

## MAPPING TTS — Concepts métier → Représentation physique TTS

> Comment chaque concept du pseudocode se traduit en objets, zones et API TTS.
> À lire avant d'implémenter n'importe quel module.

---

### Ordre d'implémentation des modules (dépendances)

```
1. card_db.lua        → données pures, aucun TTS           ← existant ✓
2. zone_manager.lua   → ScriptingTrigger zones              ← existant ✓ (corrigé s10)
3. game_objects.lua   → spawn visuel (tokens, eggs, decks)  ← existant ✓ (corrigé s10)
4. setup_manager.lua  → init plateau, clan/chief selection  ← existant ✓ (garder tel quel)
5. duel_rules.lua     → logique métier Duel                 ← À RÉÉCRIRE
6. card_powers.lua    → effets des cartes (use duel_rules)  ← À RÉÉCRIRE
7. ui_manager.lua     → HUD XML                             ← existant ✓ (corrigé s10)
8. main.lua           → glue: callbacks XML → duel_rules    ← À RÉÉCRIRE
9. solo_rules.lua     → mode Solo (après duel stable)       ← À ÉCRIRE
```

---

### Table de mapping concept → TTS

| Concept pseudocode | Représentation TTS | API utilisée |
|---|---|---|
| `joueur.deck` | Objet Deck TTS dans zone `DECK_P1` / `DECK_P2` | `zone_manager.find_zone("DECK_P1"):getObjects()[1]` |
| `joueur.defausse` | Objet Deck TTS dans zone `DISCARD_P1` | idem |
| `joueur.main` | Zone main TTS du joueur (hand zone) | `Player["Red"]:getHandObjects(1)` |
| `joueur.grotte` | Zone `CAVE_P1` (ScriptingTrigger, 1 objet max) | `zone_manager.get_objects("CAVE_P1")[1]` |
| `joueur.zone_jeu` | Zone `PLAY_P1` côté droit du plateau | `zone_manager.get_objects("PLAY_P1")` |
| `joueur.zone_totem` | Zone `TOTEM_P1` côté gauche du plateau | `zone_manager.get_objects("TOTEM_P1")` |
| `joueur.zone_trophee` | Zone `TROPHY_P1` côté gauche (dinos + oeufs) | `zone_manager.get_objects("TROPHY_P1")` |
| `joueur.reserve.nourriture` | Tokens physiques dans zone `P1_FOOD_BANK` | `zone_manager.count_tokens("P1_FOOD_BANK", "Nourriture")` |
| `joueur.reserve.pion_ami` | Tokens physiques dans zone `P1_BUDDY_BANK` | `zone_manager.count_tokens("P1_BUDDY_BANK", "Ami")` |
| `joueur.reserve.jeton_dino` | Tokens physiques dans zone `P1_DINO_BANK` | `zone_manager.count_tokens("P1_DINO_BANK", "Dino")` |
| `joueur.reserve.oeufs` | Tokens Custom_Tile face cachée dans `TROPHY_P1` | filtre `EGG_DESC[obj:getDescription()]` |
| `plateau_principal.jungle` | Objet Deck TTS dans zone `JUNGLE` | `zone_manager.find_zone("JUNGLE"):getObjects()[1]` |
| `territoire_gauche` | Pile visible dans zone `HUNT_LEFT` | `zone_manager.get_objects("HUNT_LEFT")` |
| `territoire_droit` | Pile visible dans zone `HUNT_RIGHT` | `zone_manager.get_objects("HUNT_RIGHT")` |
| `pile_dino_gauche` | Objet Deck TTS dans zone `DINO_LEFT` | `zone_manager.find_zone("DINO_LEFT"):getObjects()[1]` |
| `pile_dino_droit` | Objet Deck TTS dans zone `DINO_RIGHT` | idem |
| `banque_oeufs` | Sac TTS (Bag) dans zone `EGG_BANK` | `zone_manager.find_zone("EGG_BANK"):getObjects()[1]` |
| `ennemis_gauche` (Solo) | Cartes posées dans zone `ENEMY_LEFT` | `zone_manager.get_objects("ENEMY_LEFT")` |
| `ennemis_droit` (Solo) | Cartes posées dans zone `ENEMY_RIGHT` | `zone_manager.get_objects("ENEMY_RIGHT")` |
| ID de carte | `obj:getDescription()` | `card_db.by_id[obj:getDescription()]` |
| Carte activée (90°) | `obj:setRotation({0, 90, 0})` | rotation sur axe Y |
| Carte inactive (0°) | `obj:setRotation({0, 0, 0})` | |
| Totem activé (90°) | `obj:setRotation({0, 90, 0})` | même convention que clan |
| Carte face visible | `obj.is_face_down == false` | |
| Carte face cachée | `obj:flip()` ou rotZ=180 dans spawn JSON | |
| `detruire une carte` | `destroyObject(obj)` | définitif, pas de défausse |
| `piocher(N)` | `deck:takeObject({top=true, position=..., callback=...})` répété N fois | Wait.frames entre chaque |
| `ajouter à défausse` | `obj:setPosition(discard_pos)` puis physique TTS | ou `putObject` dans deck discard |
| `mélanger` | `deck:shuffle()` | sur objet Deck TTS |
| `retirer_dessus(jungle)` | `jungle_deck:takeObject({top=true, ...})` | async, callback obligatoire |
| `ajouter_ressource(food, N)` | `token_manager.take_food({amount=N, player_key="p1"})` | spawne des tokens dans la banque |
| `printToAll(msg)` | `printToAll(msg, {r,g,b})` | guard Player -1 avant tout printToColor |

---

### Noms des zones TTS (identifiants string dans zone_manager)

```lua
-- Zones communes (Duel + Solo)
"JUNGLE"         -- pioche commune
"HUNT_LEFT"      -- territoire de chasse gauche
"HUNT_RIGHT"     -- territoire de chasse droit
"DINO_LEFT"      -- pile dinos gauche (l1 par-dessus l2)
"DINO_RIGHT"     -- pile dinos droit
"EGG_BANK"       -- sac oeufs central

-- Zones joueur 1
"DECK_P1"        -- deck (côté jour)
"DISCARD_P1"     -- défausse (côté nuit)
"PLAY_P1"        -- zone jeu cartes jouées ce tour (droit plateau)
"TOTEM_P1"       -- totems actifs (gauche plateau)
"TROPHY_P1"      -- trophées: dinos vaincus + oeufs (gauche plateau)
"CAVE_P1"        -- grotte (1 carte max)
"P1_FOOD_BANK"   -- banque nourriture
"P1_BUDDY_BANK"  -- banque pions ami
"P1_DINO_BANK"   -- banque jetons dino

-- Zones joueur 2 (mêmes noms avec _P2)
"DECK_P2" / "DISCARD_P2" / "PLAY_P2" / "TOTEM_P2" /
"TROPHY_P2" / "CAVE_P2" / "P2_FOOD_BANK" / "P2_BUDDY_BANK" / "P2_DINO_BANK"

-- Solo uniquement
"ENEMY_LEFT"     -- cartes ennemis accumulées côté gauche
"ENEMY_RIGHT"    -- cartes ennemis accumulées côté droit
```

---

### Gestion de l'asynchronisme TTS

Le pseudocode est synchrone. En TTS, toute manipulation d'objet physique est async.

**Règle d'or :** Ne jamais supposer qu'un objet spawné est disponible immédiatement.
Toujours utiliser `callback_function` ou `Wait.condition`.

```lua
-- Pattern standard pour une action séquentielle
local function etape_2(carte) ... end
local function etape_1()
    jungle_deck:takeObject({
        top = true,
        position = HUNT_LEFT_POS,
        callback_function = function(carte)
            -- carte est maintenant disponible
            etape_2(carte)
        end
    })
end

-- Pattern "N cartes une par une" (Wait récursif)
local function reveal_next(deck, zone_pos, n, total, cb)
    if n > total then if cb then cb() end; return end
    deck:takeObject({
        top = true, position = zone_pos, smooth = true,
        callback_function = function(card)
            -- traiter card (food_reward, ennemi solo, etc.)
            Wait.frames(function()
                reveal_next(deck, zone_pos, n+1, total, cb)
            end, 2)
        end
    })
end

-- Pattern pending counter (attendre N spawns)
local pending = 0
local function on_done() ... end
for _, cfg in pairs(zones) do
    pending = pending + 1
    zone_manager.spawn_zone({ ..., callback = function(_)
        pending = pending - 1
        if pending == 0 then on_done() end
    end})
end
```

---

### État du jeu — où le stocker

Pas de table globale monolithique. Répartir dans les modules :

```lua
-- duel_rules.lua
local _state = {
    current_player = "p1",   -- "p1" | "p2"
    turn_number    = 1,
    rage_active    = false,
    fin_declenchee = false,
    dernier_tour   = false,   -- true = dernier tour en cours
    dino_attaque   = { p1 = {left=false, right=false},
                       p2 = {left=false, right=false} },
}

-- Persistance onSave / onLoad via JSON.encode / JSON.decode
function onSave()
    return JSON.encode({ duel = duel_rules.get_state() })
end
function onLoad(state_str)
    if state_str and state_str ~= "" then
        local s = JSON.decode(state_str)
        if s.duel then duel_rules.restore_state(s.duel) end
    end
end
```

---

*Fin du Mapping TTS — version 1.0 (2026-04-12)*

---

## ANNEXE TTS — Référence API Tabletop Simulator
> Extraite de `/api_repo/types/tts.lua` — à consulter pendant tout le développement

---

### A. Assets locaux (images embarquées)

```
-- Cartes Ennemi (mode Solo) — fichiers locaux dans Mods/Images/
ENEMY_IMAGES = {
    cannibalar = "Mods/Images/cannibalar.jpg",
    cultist    = "Mods/Images/cultist.jpg",
    piranar    = "Mods/Images/piranar.jpg",
    coconar    = "Mods/Images/coconar.jpg",
}
-- Usage dans spawnObjectJSON: ImageURL = ASSETS.cannibalar  (chemin relatif TTS)
```

---

### B. Spawn d'objets

```lua
-- ── Spawner un objet par type (primitif TTS) ──────────────────
spawnObject({
    type              = "Custom_Tile",     -- ou "Bag", "ScriptingTrigger", etc.
    position          = { x, y, z },
    rotation          = { x, y, z },
    scale             = { x, y, z },       -- optionnel
    sound             = false,             -- optionnel
    snap_to_grid      = false,             -- optionnel
    callback_function = function(obj) end  -- appelé quand spawning=false
})

-- ── Spawner depuis un tableau Lua ──────────────────────────────
spawnObjectData({
    data              = { ... },           -- table getData() d'un objet existant
    position          = { x, y, z },
    callback_function = function(obj) end
})

-- ── Spawner depuis du JSON (recommandé pour ContainedObjects) ──
spawnObjectJSON({
    json              = JSON.encode({ Name="Bag", ContainedObjects={...}, ... }),
    position          = { x, y, z },
    callback_function = function(obj) end
})

-- NOTES:
-- • L'objet n'est pas utilisable avant que callback_function soit appelée (spawning=false)
-- • Pour un sac avec 24 oeufs: utiliser spawnObjectJSON + ContainedObjects (1 seul callback)
-- • ScriptingTrigger = zone invisible pour compter les tokens
```

---

### C. Manipulation d'objets (TTSObject)

```lua
-- ── Position / Rotation / Scale ───────────────────────────────
obj:getPosition()                       -- → {x,y,z}
obj:setPosition({x, y, z})             -- téléportation instantanée
obj:setPositionSmooth({x,y,z}, false, false)  -- mouvement animé
obj:getRotation()                       -- → {x,y,z} angles Euler
obj:setRotation({x, y, z})
obj:setScale({x, y, z})
obj:getScale()

-- ── Identité ──────────────────────────────────────────────────
obj:getName()                           -- → string (Nickname affiché)
obj:setName("Nom")
obj:getDescription()                    -- → string (stocke l'ID de carte dans ce projet)
obj:setDescription("card_id")
obj:getGUID()                           -- → "a1b2c3" (6 chars, unique)
obj.type                                -- → "Custom_Tile" | "Bag" | "ScriptingTrigger" | ...
obj.guid                                -- même chose, champ direct
obj.is_face_down                        -- → bool (lecture seule)

-- ── Flip ──────────────────────────────────────────────────────
obj:flip()                              -- retourne l'objet (face/dos)

-- ── Destruction ───────────────────────────────────────────────
obj:destruct()                          -- détruire self (depuis le script de l'objet)
destroyObject(obj)                      -- détruire depuis un script Global

-- ── Containers (Bag, Deck) ────────────────────────────────────
obj:getObjects()      -- → [{name, description, guid, index, ...}] contenu du container
obj:getQuantity()     -- → number (-1 si pas un container)
obj:shuffle()         -- mélanger un deck/sac
obj:putObject(other)  -- mettre un autre objet dans ce container
obj:takeObject({      -- extraire un objet du container
    position          = {x,y,z},
    rotation          = {x,y,z},
    flip              = false,
    guid              = "...",         -- ou index = N
    top               = true,          -- prendre du dessus
    smooth            = true,
    callback_function = function(obj) end
})
obj.Container:search(player)  -- ouvrir l'interface de fouille pour un joueur

-- ── Deck ──────────────────────────────────────────────────────
obj:deal(N, player_color)   -- distribuer N cartes dans la main d'un joueur
obj:dealToColorWithOffset(offset, flip, player_color)  -- distribuer vers une position relative à la main
obj:cut(N)                  -- couper le deck à N cartes → {dessus, dessous}

-- ── Tags (filtrage d'objets) ──────────────────────────────────
obj:addTag("token_food")
obj:hasTag("token_food")  -- → bool
obj:getTags()             -- → {"tag1", "tag2"}
getObjectsWithTag("token_food")       -- → [TTSObject]
getObjectsWithAnyTags({"food","dino"})

-- ── Visibilité ────────────────────────────────────────────────
obj:setHiddenFrom({"Red", "Blue"})    -- cache l'objet (comme dans une zone main)
obj:setInvisibleTo({"Red"})           -- invisible complet (Fog of War)
obj.hide_when_face_down = true        -- automatiquement caché quand face verso

-- ── Highlight ─────────────────────────────────────────────────
obj:highlightOn({r,g,b,a}, duration)  -- surligner en couleur (duration=nil = permanent)
obj:highlightOff()

-- ── Tint / Couleur ────────────────────────────────────────────
obj:setColorTint({r, g, b, a})        -- teinter l'objet
obj:getColorTint()

-- ── CustomObject (Custom_Tile, Custom_Model) ──────────────────
obj:getCustomObject()    -- → table des propriétés custom
obj:setCustomObject({
    -- Custom_Tile:
    image         = "url_recto",
    image_bottom  = "url_verso",
    type          = 2,            -- 0=rectangle, 1=hexagonal, 2=cercle
    thickness     = 0.2,
    stackable     = true,
    stretch       = true,
})
obj:reload()             -- respawner l'objet (pour appliquer setCustomObject)

-- ── Zones ─────────────────────────────────────────────────────
obj:getZones()           -- → [TTSObject] zones dans lesquelles l'objet se trouve

-- ── Divers ────────────────────────────────────────────────────
obj.locked       = true   -- immobiliser l'objet
obj.interactable = false  -- empêcher toute interaction joueur
obj.sticky       = false  -- ne pas soulever les objets posés dessus
obj:addContextMenuItem("label", function(color, pos) end)
obj:clearContextMenu()

-- ── Boutons scriptés (sur objets) ─────────────────────────────
obj:createButton({
    click_function = "nom_fonction_globale",
    label          = "Texte",
    position       = {x, y, z},   -- local à l'objet
    rotation       = {x, y, z},
    scale          = {x, y, z},
    width          = 300,
    height         = 42,
    font_size      = 14,
    color          = {r,g,b,a},
    font_color     = {r,g,b,a},
    tooltip        = "Aide",
})
obj:clearButtons()
```

---

### D. Fonctions globales

```lua
-- ── Chercher des objets ───────────────────────────────────────
getObjects()                        -- → tous les objets sur la table (remplace getAllObjects)
getObjectFromGUID("a1b2c3")         -- → TTSObject | nil
getObjectsWithTag("tag")            -- → [TTSObject]
getSeatedPlayers()                  -- → ["Red", "Blue", ...]

-- ── Destruction ───────────────────────────────────────────────
destroyObject(obj)

-- ── Spawn ─────────────────────────────────────────────────────
spawnObject(...)       -- voir §B
spawnObjectData(...)
spawnObjectJSON(...)

-- ── Coroutine (animations séquentielles) ──────────────────────
startLuaCoroutine(Global, "nom_coroutine")
-- La fonction coroutine doit retourner 1 quand terminée
-- Utiliser coroutine.yield(0) pour attendre 1 frame
```

---

### E. Messages

```lua
print("debug")                              -- console host uniquement
printToAll("message", {r,g,b})              -- chat tous les joueurs
printToColor("message", "Red", {r,g,b})     -- chat d'un joueur spécifique
broadcastToAll("message", {r,g,b})          -- popup + chat tous
broadcastToColor("message", "Red", {r,g,b}) -- popup + chat d'un joueur

-- GUARD OBLIGATOIRE avant printToColor:
-- if not color or color == -1 then return end
-- TTS appelle les handlers de boutons avec color=-1 (serveur) pendant les callbacks spawnObject
```

---

### F. UI (XML) — UIClass

```lua
-- ── Lecture ───────────────────────────────────────────────────
UI:getAttribute("element_id", "attribute")   -- → valeur
UI:getAttributes("element_id")               -- → {attr=val, ...}
UI:getValue("element_id")                    -- → contenu text entre balises
UI:getXml()                                  -- → string XML complet

-- ── Écriture ──────────────────────────────────────────────────
UI:setAttribute("element_id", "attribute", value)   -- modifier 1 attribut
UI:setAttributes("element_id", {attr=val, ...})     -- modifier plusieurs attributs
UI:setValue("element_id", "nouveau_texte")          -- modifier le contenu text
UI:setXml(xml_string)                               -- remplacer tout le XML
UI:setXmlTable(data_table)                          -- remplacer via table Lua

-- ── Visibilité ────────────────────────────────────────────────
UI:show("element_id")   -- afficher avec animation
UI:hide("element_id")   -- cacher avec animation
-- ou: UI:setAttribute("id", "active", "true"/"false")

-- ── Attributs XML courants ────────────────────────────────────
-- id, active, color, fontSize, width, height, offsetXY, text
-- rectAlignment: "MiddleRight"|"UpperLeft"|"LowerCenter" etc.
-- visibility: "Red|Blue" = visible seulement pour ces couleurs

-- SIZES MINIMALES pour lisibilité dans TTS:
-- Panel width   ≥ 300px (on utilise 310)
-- Button height ≥ 40px  (on utilise 42)
-- Font bouton   ≥ 14
-- Font label    ≥ 13
-- Pas d'emojis dans les boutons TTS (rendu cassé)

-- CHAMPS INVISIBLES pour compatibilité API:
-- <Text id="p1_played_food" fontSize="1" color="rgba(0,0,0,0)" text="0"/>
-- → UI:setAttribute fonctionne sans planter même si l'élément n'est pas visible
```

---

### G. Player

```lua
-- ── Accès ─────────────────────────────────────────────────────
Player.getPlayers()              -- → [Player]
Player.getAvailableColors()      -- → ["Red", "Blue", ...]
Player["Red"]                    -- → Player instance
player.color                     -- → "Red"
player.steam_name                -- → "NomJoueur"
player.seated                    -- → bool

-- ── Main du joueur ────────────────────────────────────────────
player:getHandObjects(1)         -- → [TTSObject] cartes en main
player:getHandTransform(1)       -- → {position, rotation, scale, forward, right, up}
player:getHandCount()            -- → nombre de zones main

-- ── Dialogues ─────────────────────────────────────────────────
player:showInfoDialog("Message info")
player:showConfirmDialog("Confirmer?", function(color) end)
player:showInputDialog("Titre", "défaut", function(text, color) end)
player:showOptionsDialog("Choisir:", {"Option1","Option2"}, 0, function(opt, idx, color) end)
-- → Utile pour: choisir un territoire de chasse, choisir une carte à détruire

-- ── Envoi d'objet ─────────────────────────────────────────────
obj:sendToHand("Red")            -- envoyer un objet dans la main d'un joueur
```

---

### H. Wait (asynchrone)

```lua
-- ── Attendre N secondes ───────────────────────────────────────
Wait.time(function() ... end, 1.0)            -- après 1 seconde
Wait.time(function() ... end, 0.5, 3)         -- 3 fois, toutes les 0.5s

-- ── Attendre N frames ─────────────────────────────────────────
Wait.frames(function() ... end, 2)            -- après 2 frames physiques

-- ── Attendre une condition ────────────────────────────────────
Wait.condition(
    function() ... end,          -- à exécuter quand condition vraie
    function() return obj ~= nil and not obj.spawning end,  -- condition
    10,                          -- timeout en secondes (optionnel)
    function() print("timeout") end
)

-- ── Annuler ───────────────────────────────────────────────────
local id = Wait.time(func, 5)
Wait.stop(id)   -- annuler ce Wait spécifique
Wait.stopAll()  -- annuler tous les Waits

-- PATTERN "deal 1 par 1" (session 7):
local function deal_next(deck, positions, i, cb)
    if i > #positions then if cb then cb() end; return end
    deck:takeObject({
        position = positions[i], top = true, smooth = true,
        callback_function = function(card)
            Wait.frames(function() deal_next(deck, positions, i+1, cb) end, 2)
        end
    })
end
```

---

### I. Turns (système de tours natif TTS)

```lua
-- ── Configuration ─────────────────────────────────────────────
Turns.enable    = true           -- activer le système de tours
Turns.type      = 2              -- 1=auto, 2=custom (on gère l'ordre manuellement)
Turns.order     = {"Red","Blue"} -- ordre personnalisé
Turns.turn_color                 -- couleur du joueur actif (lecture)

-- ── Contrôle ──────────────────────────────────────────────────
Turns.endTurn()                  -- passer au joueur suivant
Turns.getNextTurnColor()         -- → couleur du prochain joueur

-- ── Event ─────────────────────────────────────────────────────
function onPlayerTurn(player, previous_player)
    -- appelé au début du tour de chaque joueur
end

-- NOTE: Dans ce projet on gère les tours manuellement via duel_rules.lua
-- Turns.enable peut rester false si on préfère le HUD XML + boutons
```

---

### J. Events principaux

```lua
function onLoad(script_state)
    -- Appelé quand le save est chargé (ou au démarrage)
    -- script_state = string retourné par onSave() précédent
end

function onSave()
    -- Appelé avant chaque sauvegarde
    -- Retourner un string JSON avec l'état du jeu
    return JSON.encode({ duel_state = ..., players = ... })
end

function onObjectSpawn(object)
    -- Appelé quand un objet est spawné
end

function onObjectEnterZone(zone, object)
    -- Appelé quand un objet entre dans une ScriptingTrigger
    -- Utile pour: détecter token entrant dans une zone banque
end

function onObjectLeaveZone(zone, object)
    -- Appelé quand un objet quitte une ScriptingTrigger
end

function onObjectDestroy(object)
    -- Appelé avant destruction
end

function onPlayerChangeColor(player_color)
    -- Joueur s'est assis ou changé de couleur
end
```

---

### K. JSON

```lua
JSON.encode(data)           -- table/string/number → string JSON
JSON.decode(json_string)    -- string JSON → table/string/number
JSON.encode_pretty(data)    -- avec indentation (debug)
```

---

### L. Zones (ScriptingTrigger) — patterns Dinoblivion

```lua
-- ── Spawner une zone ──────────────────────────────────────────
spawnObject({
    type     = "ScriptingTrigger",
    position = { x=0, y=2.0, z=0 },   -- centre y=2.0 pour tokens empilés
    callback_function = function(obj)
        obj:setName("P1_FOOD_BANK")
        obj:setScale({ 2.2, 4, 2.2 })  -- height=4 pour capturer tokens à y élevé
    end
})

-- ── Compter les tokens dans une zone ──────────────────────────
local zone = zone_manager.find_zone("P1_FOOD_BANK")
if zone then
    for _, obj in ipairs(zone:getObjects()) do
        if obj:getName() == "Nourriture" then count = count + 1 end
    end
end

-- LEÇONS APPRISES (sessions 8-10):
-- • Stackable=true dans CustomTile JSON → tokens restent dans la zone
-- • Zone height ≥ 4, centre y=2.0 → capture les tokens empilés en hauteur
-- • pcall() obligatoire sur spawnObject("ScriptingTrigger")
--   → si échec, appeler args.callback(nil) pour ne pas bloquer le pending counter
```

---

### M. Custom_Tile JSON (tokens, oeufs)

```lua
-- Structure JSON d'un Custom_Tile (token):
{
    Name        = "Custom_Tile",
    Nickname    = "Nourriture",
    Description = "",           -- utiliser pour stocker l'ID de carte (card_db)
    Transform   = {
        posX=x, posY=y, posZ=z,
        rotX=0, rotY=0, rotZ=0,    -- rotZ=180 = face verso visible
        scaleX=s, scaleY=s, scaleZ=s
    },
    CustomImage = {
        ImageURL          = "url_recto",
        ImageSecondaryURL = "url_verso",
        ImageScalar       = 1.0,
        WidthScale        = 0.0,
        CustomTile        = {
            Type      = 2,     -- 0=rectangle, 1=hexagonal, 2=cercle, 3=custom
            Thickness = 0.2,
            Stackable = true,  -- IMPORTANT: évite que les tokens se dispersent
            Stretch   = true,
        }
    }
}

-- Structure JSON d'un Bag avec ContainedObjects (spawn atomique):
{
    Name        = "Bag",
    Nickname    = "Banque Oeufs (24)",
    Description = "12 verts | 8 rouges | 4 bleus indestructibles",
    Transform   = { posX=x, posY=y, posZ=z, rotX=0,rotY=0,rotZ=0, scaleX=1,scaleY=1,scaleZ=1 },
    ContainedObjects = {
        -- tableau de Custom_Tile (posX/Y/Z=0 pour les objets à l'intérieur)
        { Name="Custom_Tile", Nickname="Oeuf Vert", Description="1", Transform={...}, CustomImage={...} },
        ...
    }
}
```

---

### N. Card / Deck operations

```lua
-- Un Deck TTS est un TTSObject de type "Deck"
-- getObjects() retourne une liste de descriptions de cartes (pas des TTSObject):
-- { name, description, guid, index, lua_script, ... }

deck:shuffle()    -- mélanger
deck:deal(N, "Red")  -- distribuer N cartes dans la main du joueur Rouge
deck:takeObject({
    guid     = "...",    -- prendre une carte spécifique par GUID
    top      = true,     -- ou prendre du dessus
    position = {x,y,z},
    smooth   = true,
    callback_function = function(card) ... end
})

-- Pour créer un deck TTS depuis un code Lua:
-- Utiliser spawnObjectJSON avec Name="Deck" et ContainedObjects = [{Name="Card",...}, ...]
-- Ou: group() plusieurs cartes individuelles pour former un deck
group(objects)  -- → [TTSObject] (groupe formé)
```

---

### O. Patterns récurrents Dinoblivion

```lua
-- ── Guard Player -1 (OBLIGATOIRE dans tous les handlers XML) ──
local function check_turn(player_key, color)
    if not color or color == -1 then return false end  -- callback serveur TTS
    ...
end

-- ── tts_alive() — vérifier qu'un objet TTS est encore valide ──
local function tts_alive(obj)
    return obj ~= nil and not obj:isDestroyed() and obj.spawning == false
end

-- ── Stocker l'ID carte dans Description ───────────────────────
-- card_db.by_id["bananar"].food_reward  ← lookup depuis getDescription()
-- obj:setDescription("bananar")         ← lors du spawn de la carte

-- ── Zones comme source de vérité des tokens ───────────────────
-- Ne jamais faire confiance aux compteurs Lua.
-- Toujours zone:getObjects() pour connaître l'état réel.
-- zone_manager.count_tokens("P1_FOOD_BANK", "Nourriture")  ← pattern standard

-- ── Rotation des cartes (activé/désactivé) ────────────────────
-- Carte inactive  : rotY=0   (portrait)
-- Carte activée   : rotY=90  (paysage = 90° sur Y dans TTS)
-- Totem inactif   : rotZ=0
-- Totem activé    : rotZ=90

-- ── JSON.encode pour spawnObjectJSON ──────────────────────────
-- JSON.encode({...}) retourne une string
-- spawnObjectJSON({ json = JSON.encode({...}), position = pos, callback_function = cb })
```

---

*Fin de l'annexe TTS API — version 1.0 (2026-04-12)*
