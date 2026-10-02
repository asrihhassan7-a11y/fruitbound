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

## Follow-up: reveal hold rework + rare harvest Seed drop
| Path | Change |
|---|---|
| ServerScriptService.Server.Modules.Controllers.SeedTools | Hold is now explicit per pack purchase (token), not inferred from inventory increases. One idempotent `releaseHold(player, token)` clears and rebuilds immediately; used by the client release (`S_SeedTools_Reveal`, now an acknowledged Invoke) and the 60 s timeout. Rebuilds are serialized per player; an equipped Seed Tool (in the Character) is no longer treated as missing |
| ServerScriptService.Server.Modules.Controllers.FarmingV2 | `buyPack` registers the hold right before saving and returns the token as a 3rd value. New `rollHarvestSeedDrop` with `HARVEST_SEED_DROP_CHANCE = 0.005` |
| ServerScriptService.Server.Modules.Controllers.Harvest | `tryHarvest` returns the harvested crop's saved `seed_id` (mature, owned, completed seed crop only) |
| ServerScriptService.Server.Modules.Controllers.Player | After a manual harvest pays its normal reward, rolls the bonus Seed and shows "🌱 Lucky Harvest! You found a <Seed>!" |
| StarterPlayer.StarterPlayerScripts.Client.Modules.Controllers.SeedShop | Passes the pack's token to the reveal; single release path (last card / closed / destroyed) with confirmation + retry, then refreshes the shop list |

## Follow-up: Seed hold removed, reveal hides the hotbar instead
| Path | Change |
|---|---|
| ServerScriptService.Server.Modules.Controllers.SeedTools | Restored to the pre-hold version (pass 2: un-anchored handle) — no hold tables, tokens, timeouts or hidden counts. Added only `S_SeedTools_Refresh` (one normal rebuild, max 1/s per player) |
| ServerScriptService.Server.Modules.Controllers.FarmingV2 | `buyPack` back to `return true, results` (no hold call / token). Harvest Seed drop (0.5%) kept |
| StarterPlayer.StarterPlayerScripts.Client.Modules.Controllers.SeedShop | Hides the Roblox Backpack hotbar (CoreGui) only while the reveal is on screen; one `finishReveal()` re-shows it and requests a refresh on last card / early close / shop close / overlay destroyed; respawn always re-shows it |

## Seed crop harvest fix
| Path | Change |
|---|---|
| ServerScriptService.Server.Modules.Controllers.Harvest | Seed crops are harvested only by a tap on that crop (clicked point within 4.5 studs); never by Auto Collect / auto punch |
| ServerScriptService.Server.Modules.Controllers.Player | `_power_click` forwards the clicked position to `Harvest.tryHarvest` |
| ServerScriptService.Server.Modules.Controllers.FarmingV2 | NaN guard in `placeCrop`; `pcall` around `mature()` in the growth heartbeat |

## Animation Pack (Fruits + Mounts)
New `StarterPlayer.StarterPlayerScripts.Client.Modules.Classes.AnimationPack` (20 keyframe clips + sampler / one-shot blending). Instance count 23,715 → 23,716; nothing else added or removed.
| Path | Change |
|---|---|
| …Client.Modules.Classes.FruitGroup | Followers play Fruit_Idle / Walk / Run / Sleep (blended), Fruit_Surprised on waking, Fruit_Happy on new / levelled / evolved fruit |
| …Client.Modules.Classes.FruitAnimator | `setSleeping` (eyes stay closed while asleep) |
| …Client.Modules.Controllers.FruitPen | Pen fruit turns to you and plays Fruit_Interact when its "Feed / Stats" prompt is used |
| …Client.Modules.Controllers.Mounts | Mount body plays <set>_Idle / Walk / Run + Start / Stop / Jump / Land / Celebrate (leg / neck / tail joint code unchanged) |
| ReplicatedStorage.Common.Modules.Databases.Mounts | Forest Deer: `anim_set = "Deer"`, gallop from 20 studs/s (riding speed is 22) |
Exports: `Animations/*.rbxmx` (one KeyframeSequence per clip) — see `Animations/README.md`.

### Animation QA pass (AnimationPack keys only)
Headless run of the real Mounts / FruitGroup animation code found: deer hooves sinking up to 0.33 studs into the ground (rigid body pitching / negative keys), Fruit_Happy and Fruit_Sleep dipping 0.12 / 0.09 studs into the ground, Fruit_Run hopping ~7x/s at mount speed. Fixed by retuning clip keys only (lifts, smaller pitch, Fruit_Run 0.4 s → 0.56 s and 0.8 → 0.6 studs, Mount_Celebrate 9° → 5.5°). No logic changes.
