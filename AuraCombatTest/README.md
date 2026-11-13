# Aura Combat Test

Prototype de combat basé sur l'aura (Roblox / Luau).

## Installation (Studio)
1. `ReplicatedStorage/AuraConfig.lua` → **ModuleScript** `AuraConfig` dans ReplicatedStorage
2. `ServerScriptService/AuraCombatServer.server.lua` → **Script** dans ServerScriptService
3. `StarterPlayerScripts/AuraCombatClient.client.lua` → **LocalScript** dans StarterPlayer > StarterPlayerScripts

(Ou synchronise le dossier avec Rojo.)

## Contrôles
| Touche | Action |
|---|---|
| Clic gauche | Coup de poing (+5 aura) |
| C (maintenir) | Charger l'aura (ralentit) |
| Q | Aura Blast vers la souris (30 aura) |
| E | Aura Burst en zone + recul (70 aura) |

## Paliers d'aura
- 0+ **Calme** (bleu) x1.0 dégâts
- 40+ **Éveillé** (or) x1.25
- 80+ **Déchaîné** (rouge) x1.6

3 mannequins réapparaissent automatiquement pour tester. Tout est réglable dans `AuraConfig`.
