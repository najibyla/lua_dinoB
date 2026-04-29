-- card_db.lua
-- Source de vérité : regleslimpides.txt (2026-04-29)
--
-- Corrections vs version précédente :
--   - Cartes Clan grises : coût corrigé en cost_ami (pas cost_food)
--   - Cartes Clan grises : food_reward = 0 (seules les brunes donnent add_nourriture)
--   - Cartes Clan grises : force (strength) corrigée selon regleslimpides.txt
--   - Cartes Action brunes : cost_food et food_reward (add_nourriture) corrigés
--   - Cartes Action brunes : has_totem ajouté sur Monki, Dino Tool, Fiyar, Mammotar, Yak
--   - Deck de départ : strength corrigé (Ami=0, Fructam=0, Bananar=0, Explorar=1)
--   - Deck de départ : Ami/Dinoblivion/Fructam passés card_type="action" (Bananar/Explorar restent "clan")
--   - Chefs : Bobor force 2→1, Sillia force 2→3
--   - Ayla : cost_ami=0→2
--   - Monki : unique=false→true
--
-- Champs cartes :
--   id               : clé unique
--   type             : "jungle"|"clan_sun"|"clan_moon"|"dino_l1"|"dino_l2"|"chief"|"enemy"
--   card_type        : "clan"|"action"  (cartes jungle uniquement)
--   name             : nom affiché
--   qty              : exemplaires dans le deck
--   unique           : true → carte unique (1 seule dans la jungle)
--   strength         : Force pour chasser/attaquer  (enemy = Force requise pour les vaincre)
--   cost_food        : Jetons Nourriture pour acheter (cartes Action brunes)
--   cost_ami         : Pions Ami pour acheter (cartes Clan grises)
--   food_reward      : add_nourriture gagné quand la carte est révélée lors d'une chasse
--                      (brunes uniquement — clans = 0)
--   family           : "sun"|"moon"|"mixed"|nil  → paires = 2 VP chacune en fin de partie
--   has_totem        : true → carte Totem (reste en jeu, se réactive chaque tour)
--   totem_count      : nombre de symboles Totem (défaut 1 ; carte Totem = 3)
--   card_power       : clé de dispatch dans card_powers.lua
--   ami_side         : "right"|"left"|"both"|nil
--
-- Récompenses dinos :
--   reward_food          : jetons Nourriture gagnés après victoire
--   reward_dino_tokens   : jetons Dino gagnés
--   reward_ami           : pions Ami gagnés
--   reward_hunt_cards    : nb de cartes choisies dans le territoire adjacent au dino vaincu
--   reward_destroy_cards : nb de cartes que le joueur DOIT détruire lors du combat
--   reward_eggs          : nb d'œufs révélés depuis la banque (Solo : valeur = cartes sous Jungle)

local card_db = {}

local BASE        = "http://cloud-3.steamusercontent.com/ugc/"
local BACK_JUNGLE = BASE.."1866179082042233297/D176DBC19F1F84700C6DF7372FC9243B1B437246/"
local BACK_L1     = BASE.."1866179082042438668/00EFCAE19788CEE5C89276FF34E5C9CAC9501FCD/"
local BACK_L2     = BASE.."1866179082042500825/7135595FF9CE8DD8BC5F98E700E497F66C4A2D51/"

-- ─────────────────────────────────────────────────────────────────────────────
-- JUNGLE — 83 cartes  (42 Clan grises + 41 Action brunes)
-- ─────────────────────────────────────────────────────────────────────────────

card_db.cards = {

    -- ── CARTES CLAN GRISES (cost = pions ami) ───────────────────────────────

    { id="amazar",     card_type="clan", type="jungle", name="Amazar",     qty=3, unique=false,
      strength=2, cost_ami=2, food_reward=0, family="sun", ami_side="left",
      card_power="amazar_dino_food",
      face_url=BASE.."1866179082042261823/C9B0A0CC7B154F329FFC40E74AB2BAA0285133B6/", back_url=BACK_JUNGLE },

    -- Artis : force=0, permet de jouer une carte action brune + piocher 1
    { id="artis",      card_type="clan", type="jungle", name="Artis",      qty=3, unique=false,
      strength=0, cost_ami=1, food_reward=0, family="sun", ami_side="right",
      card_power="play_action_draw",
      face_url=BASE.."1866179082042278832/8D29CF7E4672CAE91659ECEF9B9025DDC466A9AE/", back_url=BACK_JUNGLE },

    { id="ayla",       card_type="clan", type="jungle", name="Ayla",       qty=1, unique=true,
      strength=0, cost_ami=2, food_reward=0, family="mixed", ami_side="both",
      card_power="ayla_ami_and_egg",
      face_url=BASE.."1866179082042347306/B4A7A28361D1926A9DA705B03F556D752F597FA3/", back_url=BACK_JUNGLE },

    -- Dino Ridar : force = nb d'œufs du joueur (géré par card_power)
    { id="dino_ridar", card_type="clan", type="jungle", name="Dino Ridar", qty=1, unique=true,
      strength=0, cost_ami=2, food_reward=0, family="mixed", ami_side="right",
      card_power="dino_ridar_force_eggs",
      face_url=BASE.."1866179082042345426/F22895B9A3754CEDCB541873278E13AE02B87CF4/", back_url=BACK_JUNGLE },

    { id="dominatar",  card_type="clan", type="jungle", name="Dominatar",  qty=3, unique=false,
      strength=2, cost_ami=2, food_reward=0, family="sun", ami_side="left",
      card_power="dominatar_dino_force",
      face_url=BASE.."1866179082042335606/BAB05BCC05A8D82E2E1F1B12A55D2D40D7EFF7BC/", back_url=BACK_JUNGLE },

    { id="gilir",      card_type="clan", type="jungle", name="Gilir",      qty=3, unique=false,
      strength=1, cost_ami=1, food_reward=0, family="sun", ami_side="left",
      card_power="gilir_gain_dino",
      face_url=BASE.."1866179082042357798/5E8959B91F4EA103A03402BD5E437563B7A98BAF/", back_url=BACK_JUNGLE },

    -- Gogo : force=3 ; reward_si_new_ami = piocher 2 cartes
    { id="gogo",       card_type="clan", type="jungle", name="Gogo",       qty=3, unique=false,
      strength=3, cost_ami=3, food_reward=0, family="sun", ami_side="both",
      card_power="gogo_ami_draw",
      face_url=BASE.."1866179082042233641/2ED8E9295451FEF6D65C649412B8FE08BA234B4E/", back_url=BACK_JUNGLE },

    { id="huntar",     card_type="clan", type="jungle", name="Huntar",     qty=3, unique=false,
      strength=3, cost_ami=2, food_reward=0, family="sun", ami_side="left",
      face_url=BASE.."1866179082042248498/DDF31AFBA863EB687DD29974C5DB61FE2C95B0A0/", back_url=BACK_JUNGLE },

    { id="krafdinar",  card_type="clan", type="jungle", name="Kraf Dinar", qty=3, unique=false,
      strength=2, cost_ami=3, food_reward=0, family="sun", ami_side="left",
      card_power="krafdinar_gain_dino",
      face_url=BASE.."1866179082042251637/B33D9B844D3103A45F161CC5E6CC812C300773BF/", back_url=BACK_JUNGLE },

    -- Mom : force = nb de cartes Clan en jeu (elle-même incluse) — géré par card_power
    { id="mom",        card_type="clan", type="jungle", name="Mom",        qty=3, unique=false,
      strength=0, cost_ami=3, food_reward=0, family="moon", ami_side="left",
      card_power="mom_strength_equals_clans",
      face_url=BASE.."1866179082042527741/8B92D9710936E5E00EFC3B2C1B677E47ACB2901E/", back_url=BACK_JUNGLE },

    -- Neandertar : détruit un œuf adverse — sans effet en mode Solo
    { id="neandertar", card_type="clan", type="jungle", name="Neandertar", qty=3, unique=false,
      strength=4, cost_ami=3, food_reward=0, family="sun", ami_side="right",
      card_power="destroy_opponent_egg",
      face_url=BASE.."1866179082042349941/7FD159FCFD95BB6AD2988FFD328C05C1ED0D5BA3/", back_url=BACK_JUNGLE },

    { id="patrak",     card_type="clan", type="jungle", name="Patrak",     qty=3, unique=false,
      strength=2, cost_ami=1, food_reward=0, family="sun", ami_side="right",
      card_power="patrak_food_force",
      face_url=BASE.."1866179082042271361/E7DFEBE8A02348B168E00A48B1AEA87B8419FDA5/", back_url=BACK_JUNGLE },

    -- Protectar : force = nb de symboles Totem en jeu — géré par card_power
    { id="protectar",  card_type="clan", type="jungle", name="Protectar",  qty=3, unique=false,
      strength=0, cost_ami=2, food_reward=0, family="mixed", ami_side="right",
      card_power="protectar_strength_totems",
      face_url=BASE.."1866179082042242931/A3B1BE4DB932686BB08CCB784997187DAFF0054C/", back_url=BACK_JUNGLE },

    -- Shaman : gagne 1 œuf si ≥ 4 symboles Totem en jeu
    { id="shaman",     card_type="clan", type="jungle", name="Shaman",     qty=3, unique=false,
      strength=1, cost_ami=1, food_reward=0, family="sun", ami_side="right",
      card_power="shaman_egg_if_4_totems",
      face_url=BASE.."1866179082042253369/D329A81383619C9F2FC2FD123C70CC3E6CADA510/", back_url=BACK_JUNGLE },

    -- Workar : permet de jouer 2 cartes Action brunes ce tour
    { id="workar",     card_type="clan", type="jungle", name="Workar",     qty=3, unique=false,
      strength=2, cost_ami=2, food_reward=0, family="sun", ami_side="right",
      card_power="workar_play_2_actions",
      face_url=BASE.."1866179082042279865/9286A2E8A9E29859C4F6CCDA08FD314206EA6712/", back_url=BACK_JUNGLE },

    -- Zazza : unique — détruit 2 pions Ami → gagne 8 Force
    { id="zazza",      card_type="clan", type="jungle", name="Zazza",      qty=1, unique=true,
      strength=3, cost_ami=2, food_reward=0, family="mixed", ami_side="left",
      card_power="zazza_destroy_ami_for_force",
      face_url=BASE.."1866179082042280839/786F079E5F54F39C5E784428E2849B0A14A6AEC6/", back_url=BACK_JUNGLE },

    -- ── CARTES ACTION BRUNES (cost = nourriture, food_reward = add_nourriture) ─

    -- Banana Boost : unique, reward = +4 nourriture
    { id="banana_boost", card_type="action", type="jungle", name="Banana Boost", qty=1, unique=true,
      strength=0, cost_food=2, food_reward=1,
      card_power="banana_boost_gain_food",
      face_url=BASE.."1866179082042352533/B1D5E2081B426F69C993A8383A2F653F2781CD19/", back_url=BACK_JUNGLE },

    -- Capturar : reward = +2 jetons dino
    { id="capturar",   card_type="action", type="jungle", name="Capturar",   qty=3, unique=false,
      strength=0, cost_food=2, food_reward=1,
      card_power="capturar_gain_dino",
      face_url=BASE.."1866179082042268661/3CE60BE1F1F37DCBF5DDFC344244CFB21FF8F8F7/", back_url=BACK_JUNGLE },

    -- Dino Farm : totem, reward = +1 nourriture OU +1 jeton dino
    { id="dino_farm",  card_type="action", type="jungle", name="Dino Farm",  qty=3, unique=false,
      strength=0, cost_food=5, food_reward=2, has_totem=true,
      card_power="dino_farm_choice",
      face_url=BASE.."1866179082042323425/21A75FBFA45F15764BAAA94731282ABAF57B9A9B/", back_url=BACK_JUNGLE },

    -- Dino Tool : totem, reward = détruire 1 jeton dino = piocher +2 cartes
    { id="dino_tool",  card_type="action", type="jungle", name="Dino Tool",  qty=3, unique=false,
      strength=0, cost_food=4, food_reward=1, has_totem=true,
      card_power="dino_tool_destroy_dino_draw",
      face_url=BASE.."1866179082042315966/F9CBCFECD8374C027CE614CA7C09EBB0E989216D/", back_url=BACK_JUNGLE },

    -- Fiyar : totem, reward = piocher +1 carte
    { id="fiyar",      card_type="action", type="jungle", name="Fiyar",      qty=3, unique=false,
      strength=0, cost_food=5, food_reward=2, has_totem=true,
      card_power="fiyar_draw",
      face_url=BASE.."1866179082042312608/6D85DAE4F748EFB388C0752E9407F822F8051370/", back_url=BACK_JUNGLE },

    -- Hut : totem, reward = +1 pion ami
    { id="hut",        card_type="action", type="jungle", name="Hut",        qty=3, unique=false,
      strength=0, cost_food=4, food_reward=1, has_totem=true,
      card_power="hut_gain_ami",
      face_url=BASE.."1866179082042338627/49A5D70E4561C99F9DDB87AEDDEF41DFEBDA3923/", back_url=BACK_JUNGLE },

    -- Mammotar : totem, reward = détruire x2 nourriture = +4 force
    { id="mammotar",   card_type="action", type="jungle", name="Mammotar",   qty=3, unique=false,
      strength=0, cost_food=3, food_reward=1, has_totem=true,
      card_power="mammotar_food_force",
      face_url=BASE.."1866179082042329981/DBA1E9245CA7D7BE202DC73E0D993FC723CF22FA/", back_url=BACK_JUNGLE },

    -- Monki : unique, totem, reward = jouer une carte action brune
    { id="monki",      card_type="action", type="jungle", name="Monki",      qty=1, unique=true,
      strength=0, cost_food=3, food_reward=1, has_totem=true,
      card_power="monki_play_action",
      face_url=BASE.."1866179082042332304/6FBFBCE71D20FB9D5A571DFC3FFBC76BF28924F9/", back_url=BACK_JUNGLE },

    -- Rotam : reward = +5 force
    { id="rotam",      card_type="action", type="jungle", name="Rotam",      qty=3, unique=false,
      strength=0, cost_food=4, food_reward=2,
      card_power="rotam_force_5",
      face_url=BASE.."1866179082042341485/48EA7AD988BD7C555DCA7AE0520A80CCBE065B71/", back_url=BACK_JUNGLE },

    -- Stellar : reward = +1 nourriture, +1 jeton dino, +1 pion ami
    { id="stellar",    card_type="action", type="jungle", name="Stellar",    qty=3, unique=false,
      strength=0, cost_food=2, food_reward=1,
      card_power="stellar_resources",
      face_url=BASE.."1866179082045503487/4C686D39C681B4B9E6C7F8B4414B5E7B4C39A522/", back_url=BACK_JUNGLE },

    -- Tigar : totem, reward = +1 force
    { id="tigar",      card_type="action", type="jungle", name="Tigar",      qty=3, unique=false,
      strength=0, cost_food=2, food_reward=1, has_totem=true,
      card_power="tigar_attack_bonus",
      face_url=BASE.."1866179082042530981/3672867AC736CCEEC1776B8737D4F270CF9D2C69/", back_url=BACK_JUNGLE },

    -- Totem spécial : 3 symboles Totem, vaut 3 VP, pas de reward_action
    { id="totem_card", card_type="action", type="jungle", name="Totem",      qty=3, unique=false,
      strength=0, cost_food=6, food_reward=2, has_totem=true, totem_count=3,
      card_power="totem_no_action",
      face_url=BASE.."1866179082045502524/1A1BF9AEFB4404A466FEF52643CE9E37B9B35387/", back_url=BACK_JUNGLE },

    -- Troc : reward = +1 oeuf, +2 pions ami
    { id="troc",       card_type="action", type="jungle", name="Troc",       qty=3, unique=false,
      strength=0, cost_food=6, food_reward=2,
      card_power="troc_exchange",
      face_url=BASE.."1866179082042264583/CD05544A52C8AEEDDB27470B32A53955D066981D/", back_url=BACK_JUNGLE },

    -- Yak : totem, reward = +1 nourriture
    { id="yak",        card_type="action", type="jungle", name="Yak",        qty=3, unique=false,
      strength=0, cost_food=2, food_reward=1, has_totem=true,
      card_power="yak_gain_food",
      face_url=BASE.."1866179082042306892/0775692D656E3F077D4F885286D2F95D37B597E1/", back_url=BACK_JUNGLE },

    -- Yolo : reward = +1 jeton dino, piocher +2 cartes
    { id="yolo",       card_type="action", type="jungle", name="Yolo",       qty=3, unique=false,
      strength=0, cost_food=3, food_reward=1,
      card_power="yolo_dino_draw",
      face_url=BASE.."1866179082042266836/C41CF2585438F29BD7A6BD64EE5299F559BEAD76/", back_url=BACK_JUNGLE },

    -- ─────────────────────────────────────────────────────────────────────────
    -- DECKS DE DÉPART — Clan Soleil (9 cartes + 1 chef = 10)
    -- Ami=0, Dinoblivion=0, Fructam=0, Bananar=0, Explorar=1
    -- ─────────────────────────────────────────────────────────────────────────

    -- Ami : reward = +1 pion ami
    { id="ami_sun",         card_type="action", type="clan_sun",  name="Ami",         qty=1,
      strength=0, family="sun", ami_half_symbols=1,
      card_power="ami_gain_ami",
      face_url=BASE.."1866179082042417253/3599E18DF9429F92121944EC7F09C4726A471A29/", back_url=BACK_JUNGLE },

    -- Dinoblivion : chaque jeton dino = +2 force (max 6 jetons)
    { id="dinoblivion_sun", card_type="action", type="clan_sun",  name="Dinoblivion", qty=1,
      strength=0, family="sun",
      card_power="dinoblivion_dino_tokens",
      face_url=BASE.."1866179082042416483/E710903EA34734042874ADD2ED5ACC3219D1FE8C/", back_url=BACK_JUNGLE },

    -- Fructam : reward = +2 nourriture OU piocher +2 cartes
    { id="fructam_sun",     card_type="action", type="clan_sun",  name="Fructam",     qty=1,
      strength=0, family="sun",
      card_power="fructam_choice",
      face_url=BASE.."1866179082042415484/01A4ACAA0A5066B1F1AA1DC4615294DC3DFDD738/", back_url=BACK_JUNGLE },

    -- Bananar : reward = +1 nourriture
    { id="bananar_sun",     card_type="clan", type="clan_sun",  name="Bananar",     qty=3,
      strength=0, family="sun", ami_side="right",
      card_power="bananar_gain_food",
      face_url=BASE.."1866179082042413346/49468F3977F55CE57FD292761914E58DAA945623/", back_url=BACK_JUNGLE },

    -- Explorar : force=1, pas de reward
    { id="explorar_sun",    card_type="clan", type="clan_sun",  name="Explorar",    qty=3,
      strength=1, family="sun", ami_side="left",
      face_url=BASE.."1866179082042413955/6D2803F25265C43C4D54A27C0C729A3DA7179329/", back_url=BACK_JUNGLE },

    -- ─────────────────────────────────────────────────────────────────────────
    -- DECKS DE DÉPART — Clan Lune (9 cartes + 1 chef = 10)
    -- ─────────────────────────────────────────────────────────────────────────

    { id="ami_moon",        card_type="action", type="clan_moon", name="Ami",         qty=1,
      strength=0, family="moon", ami_half_symbols=1,
      card_power="ami_gain_ami",
      face_url=BASE.."1866179082042390354/7CC9B61C6B73302092F252211AD3C1EB484C74EA/", back_url=BACK_JUNGLE },

    { id="dinoblivion_moon",card_type="action", type="clan_moon", name="Dinoblivion", qty=1,
      strength=0, family="moon",
      card_power="dinoblivion_dino_tokens",
      face_url=BASE.."1866179082042390961/E4D659D406E6791684CEB0A6D4E25C0DA73AC745/", back_url=BACK_JUNGLE },

    { id="fructam_moon",    card_type="action", type="clan_moon", name="Fructam",     qty=1,
      strength=0, family="moon",
      card_power="fructam_choice",
      face_url=BASE.."1866179082042389599/2554F64A27A8359510D08AA26CE9A3D4AAE60589/", back_url=BACK_JUNGLE },

    { id="bananar_moon",    card_type="clan", type="clan_moon", name="Bananar",     qty=3,
      strength=0, family="moon", ami_side="right",
      card_power="bananar_gain_food",
      face_url=BASE.."1866179082042384689/DF90690A242DCD9EB88243669336E3E02012F321/", back_url=BACK_JUNGLE },

    { id="explorar_moon",   card_type="clan", type="clan_moon", name="Explorar",    qty=3,
      strength=1, family="moon", ami_side="left",
      face_url=BASE.."1866179082042385698/1D2716C3C39789BB5857576860EBDDE32FAB376C/", back_url=BACK_JUNGLE },

    -- ─────────────────────────────────────────────────────────────────────────
    -- DINOSAURES NIVEAU 1 — 8 cartes  (Solo : 4 à gauche)
    -- ─────────────────────────────────────────────────────────────────────────

    { id="ankylosaurs",     type="dino_l1", name="Ankylosaurus",    qty=1,
      strength=9,
      reward_destroy_cards=1, reward_hunt_cards=1, reward_food=2,
      reward_dino_tokens=0, reward_ami=0, reward_eggs=0,
      face_url=BASE.."1866179082042439255/A0F8E13BBA59C424ADC6B44D9D68D41F97B3817E/", back_url=BACK_L1 },

    { id="compsognathus",   type="dino_l1", name="Compsognathus",   qty=1,
      strength=7,
      reward_destroy_cards=1, reward_hunt_cards=0, reward_food=0,
      reward_dino_tokens=2, reward_ami=0, reward_eggs=1,
      face_url=BASE.."1866179082042446735/71D828CD66D33C3960F55D453CDECBDEEB8F85E7/", back_url=BACK_L1 },

    { id="dilophosaurus",   type="dino_l1", name="Dilophosaurus",   qty=1,
      strength=9,
      reward_destroy_cards=1, reward_hunt_cards=1, reward_food=0,
      reward_dino_tokens=0, reward_ami=1, reward_eggs=0,
      face_url=BASE.."1866179082042449172/C58467EEB4589878F53A7C82614EE84C0EC83D27/", back_url=BACK_L1 },

    { id="pterodactyle",    type="dino_l1", name="Pterodactyle",    qty=1,
      strength=7,
      reward_destroy_cards=1, reward_hunt_cards=0, reward_food=0,
      reward_dino_tokens=0, reward_ami=1, reward_eggs=1,
      face_url=BASE.."1866179082042457450/8E7267869EB1E5F275C413E730B51792E728E971/", back_url=BACK_L1 },

    { id="raptor",          type="dino_l1", name="Raptor",          qty=2,
      strength=10,
      reward_destroy_cards=1, reward_hunt_cards=1, reward_food=0,
      reward_dino_tokens=0, reward_ami=0, reward_eggs=1,
      face_url=BASE.."1866179082042442216/4DED7B2B473A9867D08D9D8C8CE03EFD4137B015/", back_url=BACK_L1 },

    { id="stegosaurus",     type="dino_l1", name="Stegosaurus",     qty=2,
      strength=8,
      reward_destroy_cards=1, reward_hunt_cards=0, reward_food=0,
      reward_dino_tokens=0, reward_ami=0, reward_eggs=2,
      face_url=BASE.."1866179082042443426/F4D6247C4E3ACA6183077DB50655D176ADCE7D59/", back_url=BACK_L1 },

    -- ─────────────────────────────────────────────────────────────────────────
    -- DINOSAURES NIVEAU 2 — 8 cartes  (Solo : 3 à droite)
    -- ─────────────────────────────────────────────────────────────────────────

    { id="allosaurus",      type="dino_l2", name="Allosaurus",      qty=2,
      strength=16,
      reward_destroy_cards=1, reward_hunt_cards=1, reward_food=0,
      reward_dino_tokens=0, reward_ami=1, reward_eggs=1,
      face_url=BASE.."1866179082042506202/E865E5A61F809DCFD366059EEA2D763417BD2ED0/", back_url=BACK_L2 },

    { id="brachiosaurus",   type="dino_l2", name="Brachiosaurus",   qty=1,
      strength=17,
      reward_destroy_cards=1, reward_hunt_cards=0, reward_food=0,
      reward_dino_tokens=0, reward_ami=0, reward_eggs=3,
      face_url=BASE.."1866179082042501211/7B6889B6E3D0B7D8A25D31F1599C1B8FBFD00805/", back_url=BACK_L2 },

    { id="parasaurolophus", type="dino_l2", name="Parasaurolophus", qty=1,
      strength=17,
      reward_destroy_cards=1, reward_hunt_cards=0, reward_food=0,
      reward_dino_tokens=0, reward_ami=2, reward_eggs=2,
      face_url=BASE.."1866179082042504081/E0D40BD20B2B6AC6420BE0CCC0A9DF59F6CF9799/", back_url=BACK_L2 },

    -- Spinosaurus : les cartes territoire prises ne sont pas mélangées
    { id="spinosaurus",     type="dino_l2", name="Spinosaurus",     qty=1,
      strength=18,
      reward_destroy_cards=1, reward_hunt_cards=1, reward_food=0,
      reward_dino_tokens=0, reward_ami=0, reward_eggs=2,
      face_url=BASE.."1866179082042505195/CC26308E742C2608BD97EF72721171C3F8A78E87/", back_url=BACK_L2 },

    -- Triceratops : récompense exceptionnelle (3 cartes territoire, détruire 2)
    { id="triceratops",     type="dino_l2", name="Triceratops",     qty=1,
      strength=18,
      reward_destroy_cards=2, reward_hunt_cards=3, reward_food=0,
      reward_dino_tokens=0, reward_ami=0, reward_eggs=0,
      face_url=BASE.."1866179082042501891/15769F1C18F1DD554BD26A3E958FBFDE46530462/", back_url=BACK_L2 },

    -- Tyrannosaurus : les cartes territoire prises ne sont pas mélangées
    { id="tyrannosaurus",   type="dino_l2", name="Tyrannosaurus",   qty=2,
      strength=19,
      reward_destroy_cards=1, reward_hunt_cards=1, reward_food=0,
      reward_dino_tokens=0, reward_ami=0, reward_eggs=2,
      face_url=BASE.."1866179082045598604/B192A55D41A116B1D85D936617B2D423CE621315/", back_url=BACK_L2 },

    -- ─────────────────────────────────────────────────────────────────────────
    -- CHEFS DE CLAN — 5 cartes (1 choisi au setup, sans coût d'achat)
    -- reward = détruire une carte en main pour obtenir le bonus
    -- ─────────────────────────────────────────────────────────────────────────

    -- Bobor : force=1, détruire carte = +2 pions ami
    { id="chief_bobor",  card_type="clan", type="chief", name="Bobor",  qty=1, unique=true,
      strength=1, ami_side="right",
      card_power="bobor_destroy_for_ami",
      face_url=BASE.."1866179082042371250/629495BC9BC58793CAB2EB0E464A7101D2EA544B/", back_url=BACK_JUNGLE },

    -- Cornio : force=2, détruire carte = +3 nourriture
    { id="chief_cornio", card_type="clan", type="chief", name="Cornio", qty=1, unique=true,
      strength=2, ami_side="right",
      card_power="cornio_destroy_for_food",
      face_url=BASE.."1866179082042377460/3E75C92589C9269EED25530AC09FD2A58CA15B06/", back_url=BACK_JUNGLE },

    -- Magda : force=2, détruire carte = +2 jetons dino
    { id="chief_magda",  card_type="clan", type="chief", name="Magda",  qty=1, unique=true,
      strength=2, ami_side="left",
      card_power="magda_destroy_for_dino",
      face_url=BASE.."1866179082042371603/F1192ECA720E9F44A641990A5A8428C326F3050E/", back_url=BACK_JUNGLE },

    -- Sillia : force=3, détruire carte = +1 jeton dino + 1 nourriture
    { id="chief_sillia", card_type="clan", type="chief", name="Sillia", qty=1, unique=true,
      strength=3, ami_side="left",
      card_power="sillia_destroy_for_dino_food",
      face_url=BASE.."1866179082042372927/5B75FDBEA4F7DA1F5E0A7796FB20CC7439F95935/", back_url=BACK_JUNGLE },

    -- Slayar : force=2, détruire carte = +4 force
    { id="chief_slayer", card_type="clan", type="chief", name="Slayar", qty=1, unique=true,
      strength=2, ami_side="right",
      card_power="slayar_destroy_for_force",
      face_url=BASE.."1866179082042376719/20CB56359D6CBFE4644B3CF0D43464AB43826FAE/", back_url=BACK_JUNGLE },

    -- ─────────────────────────────────────────────────────────────────────────
    -- CARTES ENNEMI — 4 cartes (Solo uniquement, mélangées dans la Jungle)
    -- strength = Force requise pour vaincre l'ennemi (+ ressource spécifique)
    -- Chasse : ennemis révélés → remis sous la Jungle, sans effet
    -- Rage   : ennemis révélés → placés sur plateau, déclenchent +1 carte Jungle
    -- ─────────────────────────────────────────────────────────────────────────

    { id="cannibalar", type="enemy", name="Cannibalar", qty=1,
      strength=3, card_power="enemy_cannibalar",  -- coût : −1 pion ami
      face_url="https://i.imgur.com/bookuih.jpeg", back_url=BACK_JUNGLE },

    { id="coconar",    type="enemy", name="Coconar",    qty=1,
      strength=2, card_power="enemy_coconar",     -- coût : −2 nourriture
      face_url="https://i.imgur.com/7GBxpdp.jpeg", back_url=BACK_JUNGLE },

    { id="cultist",    type="enemy", name="Cultist",    qty=1,
      strength=4, card_power="enemy_cultist",     -- coût : détruire 1 carte en jeu
      face_url="https://i.imgur.com/VqjtNNX.jpeg", back_url=BACK_JUNGLE },

    { id="piranar",    type="enemy", name="Piranar",    qty=1,
      strength=1, card_power="enemy_piranar",     -- coût : −1 jeton dino
      face_url="https://i.imgur.com/TfgxB0r.jpeg", back_url=BACK_JUNGLE },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Tables de lookup
-- ─────────────────────────────────────────────────────────────────────────────

card_db.by_id     = {}
card_db.by_type   = {}
card_db.by_family = {}

for _, card in ipairs(card_db.cards) do
    card_db.by_id[card.id] = card
    card_db.by_type[card.type] = card_db.by_type[card.type] or {}
    table.insert(card_db.by_type[card.type], card)
    if card.family then
        card_db.by_family[card.family] = card_db.by_family[card.family] or {}
        table.insert(card_db.by_family[card.family], card)
    end
end

-- Liste expansée d'ids pour un type donné (respecte qty)
function card_db.expanded_list(args)
    local result = {}
    for _, card in ipairs(card_db.by_type[args.type] or {}) do
        for _ = 1, (card.qty or 1) do table.insert(result, card.id) end
    end
    return result
end

-- Nb total de symboles Totem sur une liste d'ids
function card_db.count_totem_symbols(ids)
    local total = 0
    for _, id in ipairs(ids) do
        local def = card_db.by_id[id]
        if def and def.has_totem then total = total + (def.totem_count or 1) end
    end
    return total
end

-- Nb de cartes Clan dans une liste d'ids
function card_db.count_clan_cards(ids)
    local total = 0
    for _, id in ipairs(ids) do
        local def = card_db.by_id[id]
        if def and def.card_type == "clan" then total = total + 1 end
    end
    return total
end

return card_db
