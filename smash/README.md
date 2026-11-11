# Smash Arena (Roblox) — jeu de combat style « platform fighter », vue de côté fixe

## Mettre le jeu dans ta place Roblox Studio ouverte
1. Dans Studio, **Explorer** → clic droit sur **ReplicatedStorage** → *Insert from File…* → `build/SmashConfig.rbxmx`
2. Clic droit sur **ServerScriptService** → *Insert from File…* → `build/SmashServer.rbxmx`
3. Clic droit sur **StarterPlayer > StarterPlayerScripts** → *Insert from File…* → `build/SmashClient.rbxmx`
4. Clique sur **Play** (F5).

Ou bien ouvre directement `build/SmashArena.rbxlx` (File → Open from File) : c'est une place qui contient seulement le jeu.

L'arène est créée par le script à Y = 1000, loin de ta map existante.

## Contrôles
| Touche | Action |
|---|---|
| A/D, Q/D, flèches | bouger |
| Espace | saut (double saut en l'air) |
| J / clic gauche | attaque (+ W/Z ou S pour la direction) |
| K / clic droit (maintenir) | smash chargé |
| E / L | projectile |
| S en l'air | chute rapide / traverser une plateforme |
| Shift | bouclier |

Manette : A saut, X attaque, Y smash, B projectile, L2/R2 bouclier.

## Réglages
Tout est dans `SmashConfig` : nombre de vies, nombre de bots CPU, gravité, dégâts des attaques…
`CAMERA_FOLLOW = false` donne une caméra fixe de côté. Mets `true` pour une caméra qui suit les combattants et zoome.

## Modifier le code
Les sources sont dans `src/*.lua`. Après une modification, lance `python3 build.py` pour régénérer `build/`.
