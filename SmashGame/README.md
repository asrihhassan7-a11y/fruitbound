# Smash Arena (Roblox Studio)

Jeu de combat de plateforme style Smash Bros, vue de côté fixe.

## Installation dans Roblox Studio (copier-coller)
1. Ouvre Studio (de préférence un **Baseplate** neuf, ou `yess.rbxl`).
2. **ReplicatedStorage** → Insérer deux **ModuleScript** : `SmashConfig` (colle `src/ReplicatedStorage/SmashConfig.lua`) `SmashMaps` (colle `src/ReplicatedStorage/SmashMaps.lua`) et `SmashFighters` (colle `src/ReplicatedStorage/SmashFighters.lua`).
3. **ServerScriptService** → Insérer un **Script** nommé `SmashServer` → colle `src/ServerScriptService/SmashServer.server.lua`.
4. **StarterPlayer > StarterPlayerScripts** → Insérer un **LocalScript** nommé `SmashClient` → colle `src/StarterPlayerScripts/SmashClient.client.lua`.
5. Appuie sur **Play**. Vote pour une map, puis affronte les bots CPU.

Avec Rojo : `rojo serve` dans ce dossier.

## Déroulement d'une manche
1. **Vote** (15 s) : chaque joueur clique sur une map (ou « Aléatoire »).
2. **Compte à rebours** puis **combat** chronométré (3 min).
3. **Résultats** : classement par vies restantes, puis % le plus bas, puis KO.

## Maps (module `SmashMaps`)
Temple du Ciel · Plateau Final · Îles Jumelles · Volcan · Glacier · Cité Néon · Forêt Enchantée · Plage Tropicale · Château Hanté · Station Spatiale (gravité faible) · Temple Sakura · Désert Antique.
Pour en ajouter une, copie un bloc `Maps[n] = {...}` et change les pièces.

## Personnages (module `SmashFighters`)
Choisis-le dans le menu : Bagarreur (équilibré), Éclair (rapide, 2 sauts), Titan (lourd, fort), Mage (projectiles).

## Attaques spéciales (E)
Bagarreur : boule d'énergie • Éclair : dash qui traverse • Titan : séisme (en l'air : plonge) • Mage : orbe magique.

## Modes
Pendant le vote : « Chacun pour soi » ou « Équipes » (Rouge contre Bleu, pas de tir ami).

## Pièges et plateformes mobiles
Temple du Ciel et Îles Jumelles : plateformes qui bougent. Volcan : geysers de lave. Glacier : stalactites.

## Statistiques et classement
Victoires, KO et matchs sauvegardés (DataStore), visibles dans la liste des joueurs et dans le menu.
Dans Studio : Accueil > Paramètres du jeu > Sécurité > activer « Enable Studio Access to API Services ».

## Objets
Un objet tombe toutes les ~12 s : Soin (-35 %), Marteau (coups x1.6), Bottes (vitesse), Bombe (explose au contact).

## Musique
Mets un ID de musique dans `SmashFighters.MenuMusic` / `FightMusic`, ou `music = "rbxassetid://..."` dans une map.

## Mobile
Des boutons tactiles apparaissent automatiquement sur téléphone/tablette.

## Entraînement
Bouton ENTRAÎNEMENT dans le menu (quand aucun match n'est en cours) : sac de frappe, vies infinies, panneau pour régler le % du sac.

## Bord de scène
En tombant près du bord, tu t'accroches : Saut / Haut = remonter, Bas = lâcher.

## Bots CPU
3 bots par défaut (Moyen, Difficile, Expert) qui bloquent, esquivent et s'accrochent au bord. Réglables dans `Config.BOTS` / `Config.BOT_COUNT`.

## Règles
- Chaque coup augmente ton **%** ; plus il est haut, plus tu es projeté loin.
- Sortir de l'écran (côtés, haut, bas) = perte d'une vie. 3 vies, le dernier debout gagne.

## Contrôles
| Touche | Action |
|---|---|
| A / D (Q / D en AZERTY) | Se déplacer |
| Espace | Sauter (double saut en l'air) |
| J / clic gauche | Attaque (+ haut / bas pour la diriger) |
| K / clic droit (maintenir) | Smash chargé |
| E / L | Projectile |
| Haut + E en l'air | Super saut de récupération |
| S en l'air | Chute rapide ; S sur une plateforme : la traverser |
| Shift | Bouclier |
Manette supportée (A saut, X attaque, Y smash, B projectile, gâchettes bouclier).

## Réglages
Tout est dans `SmashConfig` : vies, gravité, recul, dégâts, caméra (`CAMERA_FOLLOW = false` pour une caméra totalement immobile).

L'arène est générée à Y = 1000 pour ne pas toucher la map existante. Si `yess.rbxl` a d'autres scripts (téléportation, outils…), ils peuvent interférer : teste d'abord dans un Baseplate vide.
