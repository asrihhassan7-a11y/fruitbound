# FruitBound V1 final pass — change log

Source: `yess.rbxl` (original, untouched backup). Output: `FruitBound.rbxl` (binary) and `FruitBound.rbxlx` (XML, same content).
Edits are surgical: only the `Source` of the scripts below and 4 properties on 2 BillboardGuis changed.
Instance count (23,715), hierarchy, names, attributes, IDs and save keys are unchanged.
The only other difference is Roblox's binary format rounding near-zero rotation floats (for example 1e-33 → 0).

## Modified scripts
| Path | Change |
|---|---|
| StarterPlayer.StarterPlayerScripts.Client.Modules.UI.Fruits | Real fruit preview (clears the old pet image on the Icon template and any leftover ViewportFrame), bounding-box camera fit with padding, thumbnail-only effect stripping, Delete mode dims instead of hiding, last-fruit delete guards, softened Rainbow tint on 3D preview |
| ServerScriptService.Server.Modules.Controllers.Player | `_fruits_delete`: accepts single uid, de-dupes, rejects leaving 0 fruits (`"last"`). New `_paid_random_items_policy`, `_tutorial_skip`. Restricted accounts never get routed to (or stuck on) the hatch tutorial step |
| ServerScriptService.Server.Scripts.server-main | `S_Tutorial_Skip` remote |
| StarterPlayer.StarterPlayerScripts.Client.Modules.Controllers.Egg | One clear "unavailable" notice (throttled), auto-hatch stops quietly, restricted answer cached client-side (server still enforces) |
| StarterPlayer.StarterPlayerScripts.Client.Modules.Controllers.Guide | Short step texts, final message, skip support, shop-label distance fade / hide while tutorial target |
| StarterPlayer.StarterPlayerScripts.Client.Modules.UI.Settings | FruitBound-styled Settings (GENERAL / TUTORIAL), only real settings, Skip Tutorial + confirm popup, Stats tab = Coins / Gems / Rebirths / Crops Harvested / Fruits Collected |
| StarterPlayer.StarterPlayerScripts.Client.Modules.UI.Top | Coins (gold) / Gems (cyan + glow) HUD look, icon pulse + shine on gain (throttled) |
| StarterPlayer.StarterPlayerScripts.Client.Modules.Controllers.SoundFX | Music director: day/night crossfade, event MusicOverride / AmbientSound / Volume / FadeTime / MusicVolume, no duplicate loops; duplicate birds/night loops removed |
| StarterPlayer.StarterPlayerScripts.FruitBoundAmbience | Sole owner of birds/crickets; follows Ambient volume; birds hush in rain |
| ReplicatedStorage.Common.Modules.Databases.WorldEvents | Optional `audio` config; Rain / Storm use `Amb_Rain` |
| ReplicatedStorage.Common.Modules.Utilities.LuckPassUtility | Removed debug `print` |
| StarterPlayer.StarterPlayerScripts.Client.Modules.UI | Removed per-UI "initialized" debug `print` |

## Modified instance properties
`Workspace.__MAP.Village.Shops["Seed Shop"].Gardener_Seed.Torso.NPCName` and `Workspace.__MAP.Village.CropSeller.Torso.NPCName` (BillboardGui):
MaxDistance INF → 80, Size 200×50 → 150×34 px, StudsOffset Y 4.05 → 5.6, AlwaysOnTop true → false.

## Optional asset hook
Night music: add a looping Sound named `MusicNight` to SoundService (or `Music_Night` under ReplicatedStorage.Assets.Sounds). Until then, the day track plays softer at night.

## Follow-up: mobile + seed tool fixes
| Path | Change |
|---|---|
| ServerScriptService.Server.Modules.Controllers.SeedTools | Seed Tool Handle (cloned from an Anchored display mesh) is now un-anchored, massless, non-colliding, joint-free |
| ServerScriptService.MapAnchorScript | Never anchors parts inside a Tool |
| ServerScriptService.Server.Modules.Controllers.FarmingV2 | Publishes tutorial fallback positions (`GuideSell`, `GuideSeedShop`, `GuideEgg` on Workspace; `GuideFarm` on each Player) |
| StarterPlayer.StarterPlayerScripts.Client.Modules.Controllers.Guide | Points at the fallback position while the real target is not streamed in; Fruits-button pointer uses the HUD's safe-area screen space and stays on screen; marker draw distance 2000 |
| StarterPlayer.StarterPlayerScripts.Client.Modules.UI.UpgradeTree | Panel sized from the safe-area ScreenGui instead of the full viewport (fixes the clipped top-right Coins chip on phones) |

## Follow-up: Seed Pack reveal spoiler
| Path | Change |
|---|---|
| ServerScriptService.Server.Modules.Controllers.SeedTools | Seeds gained from a pack are saved immediately but their Backpack Tools are held (shown count = saved − held) until the client reports the reveal finished (`S_SeedTools_Reveal`) or 60 s pass. Holds cleared on leave; join/rejoin never hides seeds |
| StarterPlayer.StarterPlayerScripts.Client.Modules.Controllers.SeedShop | Releases the hold and refreshes the shop's seed list once all cards are revealed, or when the reveal is closed/destroyed |
