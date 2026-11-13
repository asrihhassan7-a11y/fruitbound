# Aura Battles (test)

Jeu d'arène où tu frappes les autres avec ton **aura** pour les éjecter dans le vide (genre "slap", mais avec des auras).

## Installation (Studio)
1. `ReplicatedStorage/AuraConfig.lua` → **ModuleScript** `AuraConfig` dans ReplicatedStorage
2. `ServerScriptService/AuraCombatServer.server.lua` → **Script** dans ServerScriptService
3. `StarterPlayerScripts/AuraCombatClient.client.lua` → **LocalScript** dans StarterPlayer > StarterPlayerScripts

L'arène, le lobby, le spawn et le portail sont créés automatiquement au lancement.

## Déroulement
1. Tu apparais dans le lobby → choisis ton aura à gauche.
2. Traverse le portail violet → tu tombes dans l'arène.
3. Clic = frapper (gros recul + ragdoll), E = capacité de l'aura.
4. Tombe dans le vide = mort. Celui qui t'a frappé en dernier gagne une **Éjection** (classement).

## Auras
| Aura | Recul | Cooldown | Capacité (E) |
|---|---|---|---|
| Normale | 60 | 0.8s | — |
| Feu | 75 | 1.0s | Ruée vers l'avant |
| Glace | 55 | 0.9s | Gèle les ennemis proches 2s |
| Foudre | 50 | 0.5s | Vitesse x2 pendant 4s |
| Vent | 65 | 1.0s | Bourrasque autour de soi |
| Ombre | 70 | 1.1s | Téléportation derrière l'ennemi |
| Titan | 140 | 3.0s | — |

Ajoute une aura en ajoutant une ligne dans `AuraConfig.Auras`.
