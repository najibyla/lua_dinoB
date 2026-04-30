# Spécifications Techniques : Dinoblivion

## 1. Architecture du Plateau et Zones

Chaque joueur dispose d'un plateau individuel divisé en zones logiques distinctes pour la gestion des objets et des états.

### Zones Joueur

- **Deck (Côté Jour)** : Situé à gauche, face cachée. Contient les cartes disponibles pour la pioche.
    
- **Défausse (Côté Nuit)** : Située à droite, face visible. Reçoit les cartes achetées et les cartes jouées en fin de tour.
    
- **Grotte** : Emplacement central au-dessus du plateau pour **une seule carte** maximum. Elle n'est pas défaussée en fin de tour.
    
- **Zone Permanente (Gauche)** : Reçoit les **Totems** activés , les **Dinosaures vaincus** et les **Œufs** (face cachée).
    
- **Zone d'Action (Droite)** : Reçoit les cartes Clan et Action jouées durant le tour.
    

### Zones Communes (Plateau Principal)

- **Jungle** : Pioche centrale commune.
    
- **Territoires de Chasse** : Deux espaces (gauche et droite) où les cartes de la Jungle sont révélées.
    
- **Emplacements Dinosaures** : Deux piles de 6 dinosaures (3 de Niveau 2 recouverts par 3 de Niveau 1).
    

---

## 2. Définition des Objets (Cartes et Jetons)

### Cartes Clan (Grises)

- **Coût** : Pions Ami.
    
- **Force** : Utilisée pour chasser ou combattre.
    
- **Connecteurs (Demi-Ami)** : Symboles Gauche, Droite ou "Both" (Gogo, Ayla).
    
- **Action** : Nécessite une rotation à **90°** pour être activée.
    

### Cartes Action (Brunes)

- **Coût** : Jetons Nourriture.
    
- **Prérequis** : Nécessite l'activation d'une carte Clan pour être jouée depuis la main.
    
- **Attribut Totem** : Si présent, la carte reste en jeu (Zone Gauche) et se réactive chaque tour.
    

### Jetons et Ressources

- **Nourriture** : Max 6 dans la réserve commune. Utilisée pour les achats et pouvoirs.
    
- **Jetons Dino** : Max 12. Utilisés pour le combat (Pouvoir Dinoblivion : 1 jeton détruit = +2 force, max 12 force totale).
    
- **Pions Ami** : Max 12. Utilisés pour l'achat de clans.
    
- **Œufs** : Valeur de 1 PV (Vert) ou 2 PV (Rouge/Bleu). Le bleu est indestructible (Neandertar).
    

---

## 3. Logique des Phases de Jeu

### Le Tour du Joueur

1. **Phase de Pioche** : Tirer 4 cartes. Si le deck est vide, déclencher la **Rage**.
    
2. **Phase d'Action** : Le joueur peut, dans l'ordre de son choix :
    
    - **Chasser** : Utiliser la force d'un clan pour révéler $X$ cartes Jungle vers un territoire.
        
    - **Combattre** : Cumuler la force pour égaler/dépasser un Dino.
        
    - **Jouer une Action** : Poser une carte brune sur un clan activé.
        
    - **Gagner Ami** : Unir deux connecteurs compatibles (un seul ami par connexion en jeu).
        
    - **Acheter** : Payer le coût d'une carte visible sur un territoire.
        
3. **Phase de Nettoyage** :
    
    - Les cartes en main et en zone droite vont à la défausse.
        
    - Les Totems et la carte en Grotte restent en place.
        
    - Les Totems utilisés sont redressés (0°).
        

### La Rage des Dinosaures

- **Condition** : Deck vide lors d'une tentative de pioche.
    
- **Effet** : Révéler $X$ cartes Jungle par territoire ($X$ = niveau du Dino visible au-dessus).
    
- **Résolution** : Une fois la rage traitée, mélanger la défausse pour reformer le deck et compléter la pioche à 4 cartes.
    

---

## 4. Conditions de Fin et Scoring

La fin est déclenchée si une pile de **Dinosaures** est vide ou si la **Jungle** est épuisée.

### Calcul du Score (PV)

- **Familles** : +2 PV par couple `Demi-Ami` formé en fin de partie (calculer sur la totalité des cartes possédées).
    
- **Totems** : +1 PV par totem présent dans la zone gauche.
    
- **Dinosaures** : +1 PV par carte dinosaure vaincue.
    
- **Œufs** : Somme des valeurs (1 ou 2) au verso des jetons récoltés.
    

---

## 5. Spécificités du Mode Solo

- **Objectif** : Éliminer tous les dinosaures.
    
- **Défaite** : Jungle épuisée (Éruption du volcan).
    
- **Ennemis (Cartes Rouges)** :
    
    - Apparaissent uniquement lors de la **Rage**.
        
    - Ajoutent un tirage Jungle immédiat lors de leur apparition.
        
    - S'ils apparaissent lors d'une **Chasse**, ils sont remis sous la Jungle sans effet.
        
- **Volcan** : Si une pile de dinos est vide, la Rage sur cet emplacement tire désormais 3 cartes Jungle.
    

---

## 6. Précisions pour l'IA (Logique de Destruction)

Lorsqu'un combat contre un dinosaure impose de détruire une carte:

1. Le système doit présenter une interface de sélection.
    
2. Le joueur peut choisir une carte en **main**, en **jeu** (zone droite) ou dans la **Grotte**.
    
3. **Exception** : Les Totems (zone gauche) ne sont pas destructibles par ce biais.

Voici les données exhaustives extraites des documents pour les **122 cartes** constituant le jeu Dinoblivion, structurées pour une intégration technique.


---


### 1. Cartes de Départ (18 cartes)

Ces cartes sont divisées en deux clans identiques (**Soleil** et **Lune**). Elles n'ont pas de coût d'achat.

|**Nom**|**Qty/Clan**|**Force**|**Type**|**Effet (Reward)**|**Connecteur**|
|---|---|---|---|---|---|
|**Ami**|1|0|Action|+1 pion Ami|Aucun|
|**Dinoblivion**|1|0|Action|Détruire 1 jeton Dino (max 6) = +2 Force par jeton|Aucun|
|**Fructam**|1|0|Action|+2 nourriture **OU** piocher +2 cartes|Aucun|
|**Bananar**|3|0|Clan|+1 nourriture|Droite|
|**Explorar**|3|1|Clan|Aucun|Gauche|

---

### 2. Chefs de Clan (5 cartes)

Une carte choisie par joueur au début de la partie. Coût d'achat : 0.

|**Nom**|**Force**|**Effet (Détruire 1 carte en main pour...)**|**Connecteur**|
|---|---|---|---|
|**Bobor**|1|+2 pions Ami|Droite|
|**Cornio**|2|+3 nourriture|Droite|
|**Magda**|2|+2 jetons Dino|Gauche|
|**Sillia**|3|+1 jeton Dino et +1 nourriture|Gauche|
|**Slayar**|2|+4 force|Droite|

---

### 3. Cartes de la Jungle : Actions (41 cartes)

Coût payé en **Nourriture**.

|**Nom**|**Qty**|**Coût**|**Totem**|**Effet (Reward)**|**Spécial**|
|---|---|---|---|---|---|
|**Banana Boost**|1|2|0|+4 nourriture|Unique|
|**Capturar**|3|2|0|+2 jetons Dino|-|
|**Dino Farm**|3|5|1|+1 nourriture **OU** +1 jeton Dino|-|
|**Dino Tool**|3|4|1|Détruire 1 jeton Dino = piocher +2 cartes|-|
|**Fiyar**|3|5|1|Piocher +1 carte|-|
|**Hut**|3|4|1|+1 pion Ami|-|
|**Mammotar**|3|3|1|Détruire 2 nourritures = +4 force|-|
|**Monki**|1|3|1|Jouer une carte Action brune additionnelle|Unique|
|**Rotam**|3|4|0|+5 force|-|
|**Stellar**|3|2|0|+1 nourriture, +1 jeton Dino, +1 pion Ami|-|
|**Tigar**|3|2|1|+1 force|-|
|**Totem**|3|6|3|Aucun reward (Vaut 3 PV fin de partie)|-|
|**Troc**|3|6|0|+1 œuf, +2 pions Ami|-|
|**Yak**|3|2|1|+1 nourriture|-|
|**Yolo**|3|3|0|+1 jeton Dino, piocher +2 cartes|-|

---

### 4. Cartes de la Jungle : Clans (42 cartes)

Coût payé en **Pions Ami**.

|**Nom**|**Qty**|**Coût**|**Force**|**Connecteur**|**Effet / Pouvoir**|
|---|---|---|---|---|---|
|**Zazza**|1|2|3|Gauche|-2 pions Ami = +8 Force|
|**Ayla**|1|2|0|Both|Si Gauche combiné: +1 œuf. Si Droite: +1 pion Ami|
|**Dino Ridar**|1|2|*|Droite|Force = nombre d'œufs possédés|
|**Gogo**|3|3|3|Both|Piocher 2 cartes par pion Ami généré par elle|
|**Mom**|3|3|*|Gauche|Force = nombre de clans en jeu|
|**Protectar**|3|2|*|Droite|Force = nombre de symboles Totem en jeu|
|**Amazar**|3|2|2|Gauche|+1 jeton Dino, +1 nourriture|
|**Artis**|3|1|0|Droite|Jouer 1 action brune + pioche 1 carte|
|**Dominatar**|3|2|2|Gauche|Détruire 2 jetons Dino = +7 force|
|**Gilir**|3|1|1|Gauche|+1 jeton Dino|
|**Huntar**|3|2|3|Gauche|Aucun|
|**Kraf Dinar**|3|3|2|Gauche|+2 jetons Dino|
|**Neandertar**|3|3|4|Droite|Détruire 1 œuf adverse (Duel uniquement)|
|**Patrak**|3|1|2|Droite|-1 nourriture = +3 force|
|**Shaman**|3|1|1|Droite|Si 4+ totems en jeu = +1 œuf|
|**Workar**|3|2|2|Droite|Jouer 2 cartes Action à la fois|

---

### 5. Dinosaures (16 cartes)

Elles sont réparties en deux niveaux et servent de trophées. Chaque combat impose de **détruire une carte** en jeu/main.

|**Nom**|**Niveau**|**Qty**|**Force**|**Reward (Ressources / Effets)**|
|---|---|---|---|---|
|**Tyrannosaurus**|2|2|19|+1 carte territoire, +2 œufs|
|**Spinosaurus**|2|1|18|+1 carte territoire, +2 œufs|
|**Triceratops**|2|1|18|Détruire 2 cartes en jeu = +3 cartes territoire|
|**Brachiosaurus**|2|1|17|+3 œufs|
|**Parasaurolophus**|2|1|17|+2 pions Ami, +2 œufs|
|**Allosaurus**|2|2|16|+1 carte territoire, +1 pion Ami, +1 œuf|
|**Raptor**|1|2|10|+1 carte territoire, +1 œuf|
|**Ankylosaurus**|1|1|9|+1 carte territoire, +2 nourritures|
|**Dilophosaurus**|1|1|9|+1 carte territoire, +1 pion Ami|
|**Stegosgurus**|1|2|8|+2 œufs|
|**Compsognathus**|1|1|7|+1 œuf, +2 jetons Dino|
|**Pterodactyle**|1|1|7|+1 pion Ami, +1 œuf|

---

### 6. Ennemis (4 cartes - Mode Solo uniquement)

Mélangées dans la jungle en solo, s'activent lors de la Rage.

|**Nom**|**Force Requise**|**Ressource à payer**|**Effet si non vaincu**|
|---|---|---|---|
|**Cannibalar**|3|-1 pion Ami|Tirage Jungle supp.|
|**Cultist**|4|Détruire 1 carte en jeu|Tirage Jungle supp.|
|**Piranar**|1|-1 jeton Dino|Tirage Jungle supp.|
|**Coconar**|2|-2 nourriture|Tirage Jungle supp.|

**Total des cartes :** 18 (départ) + 5 (chefs) + 41 (actions) + 42 (clans) + 16 (dinos) + 4 (ennemis) - 4 (doublons/uniques ajustées) = **126 cartes théoriques** (incluant les aides de jeu). Les documents mentionnent **110 cartes Dinoblivion** de base + 16 Dinosaures.