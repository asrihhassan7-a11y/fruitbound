# Smash Arena (Roblox Studio)

Jeu de combat de plateforme style Smash Bros, vue de côté fixe.

## Installation dans Roblox Studio (copier-coller)
1. Ouvre Studio (de préférence un **Baseplate** neuf, ou `yess.rbxl`).
2. **ReplicatedStorage** → Insérer un **ModuleScript** nommé `SmashConfig` → colle `src/ReplicatedStorage/SmashConfig.lua`.
3. **ServerScriptService** → Insérer un **Script** nommé `SmashServer` → colle `src/ServerScriptService/SmashServer.server.lua`.
4. **StarterPlayer > StarterPlayerScripts** → Insérer un **LocalScript** nommé `SmashClient` → colle `src/StarterPlayerScripts/SmashClient.client.lua`.
5. Appuie sur **Play**. Tu affrontes un bot CPU (réglable avec `CPU_BOTS`).

Avec Rojo : `rojo serve` dans ce dossier.

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
| S en l'air | Chute rapide ; S sur une plateforme : la traverser |
| Shift | Bouclier |
Manette supportée (A saut, X attaque, Y smash, B projectile, gâchettes bouclier).

## Réglages
Tout est dans `SmashConfig` : vies, gravité, recul, dégâts, caméra (`CAMERA_FOLLOW = false` pour une caméra totalement immobile).

L'arène est générée à Y = 1000 pour ne pas toucher la map existante. Si `yess.rbxl` a d'autres scripts (téléportation, outils…), ils peuvent interférer : teste d'abord dans un Baseplate vide.
