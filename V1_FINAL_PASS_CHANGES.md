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

## Final release pass: economy, empty farm plots, free planting
Only script `Source` changed (25 scripts). Instance count (23,716), hierarchy, names, IDs, save keys and Robux Product IDs are unchanged.

### Economy
- Harvest value no longer uses the Coins-based power tier (income was growing with income). Each harvested unit has a fixed base: the Seed's `sell_value` (Clover 8, Mint 14, Carrot 24, Sunflower 42, Glow Mushroom 75), or 1 for decor patches. It is then multiplied by farm bonuses and the player's coin boosts. Fruits speed up growth and no longer also multiply sell value.
- Each Seed crop gives 6 harvest units (one tap each, exact target).
- Seed Packs (3 Seeds each; odds unchanged): Starter 120, Garden 300, Flower 330, Woodland 560, Golden Grove 600, Enchanted 800 Coins.
- Farm upgrades: 1.5K → 45M Coins (same order and IDs). Helpers earn a fixed 1 Coin per 2 s each (× bonuses).
- Eggs: Farm 750, Desert 3,000, Jungle 10,000 Gems (both `Eggs` and `FruitEggRewards`).
- Gem sources scaled: playtime gifts, 7-day daily gifts, codes (÷40), hidden rank reward (150 × rank). Combat boosts (x2 Damage, Protection) are replaced or removed.
- Garden Spins: 5K Gems 1%, 150 Gems 25%, 1,500 Coins 20%, Starter Seed Pack 18%, Rare Seed (Glow Mushroom) 12%, x2 Coins potion 10%, Growth Potion 8%, Farm Egg 6%. Restricted accounts never roll the Egg slice. The popup shows what was really given.
- New Growth Potion (x1.25 crop growth, 30 min; starts immediately, timer shown in the Boosts HUD).
- Sprinklers now make crops grow 40% faster.
- Tutorial: the first sale always covers the Starter Pack, and the tutorial harvest grants the Farm Egg price, so neither step can softlock.
- `Settings.data.mock = false`.

### Farm plots
Land expansions build EMPTY soil (no Strawberry, Mango or other bushes) with neutral names: Starter, Meadow, Orchard, Riverside, Tropical, Blossom, Greenhouse, Mystic and Golden Plot. Internal IDs are unchanged.

### Free planting
Equip a Seed Tool, then click or tap your own soil. A green or red preview disc shows whether the spot is valid. The server validates seed ownership, owned and unlocked soil, edge margin, surface height, a 30-stud reach, 4.5-stud spacing, a 250-crop cap and a rate limit before spending exactly 1 Seed.
- **Saves:** new crops save `{seed_id, planted_at, x, z}` in plot-local coordinates under a unique key. Legacy slot crops "1"–"6" keep their keys and gain their old slot position in place.
- **UI:** the Seed Shop slot picker is removed (PLANT → EQUIP). Tutorial step 4: "Equip a Seed and tap the soil on your farm!"

### Other
- Egg stand price signs now show the real price.
- Fruit descriptions now say Fruits make crops grow faster.

### Release QA fix
| Path | Change |
|---|---|
| StarterPlayer.StarterPlayerScripts.Client.Modules.Controllers.SeedTools | The planting preview now uses the same plantable size as the server (`FarmUpgrades.soil`). The Greenhouse floor (30×20) is larger than its plantable soil (28×18), so the preview showed green in a 1-stud band the server rejects. |

## Custom Roblox animations (optional, AnimationPack fallback)
- **Instances:** new ModuleScript `ReplicatedStorage.Common.Modules.Databases.AnimationIds` (23,716 → 23,717 instances), holding the Deer / Mount / Fruit Animation IDs. Empty IDs keep the built-in animation.
- **AnimationPack:** a track layer (`trackSet`, `trackLoop`, `trackShot`, `trackBusy`, `trackStop`). It loads tracks once per model on one AnimationController + Animator and crossfades loops only when the action changes. A track is used only once it has loaded; otherwise that action falls back to the procedural clip. Everything stops and is destroyed on despawn or dismount.
- **Mounts:** the Deer uses its Root → Body rig. While an uploaded track drives the Body joint, the procedural Body layer stays off. Leg, neck and tail code is unchanged.
- **FruitGroup:** when a Fruit ID is set, each follower gets a Root → Handle Motor6D rig (invisible anchored Root as PrimaryPart at the mesh's exact CFrame; stage decorations welded to the Handle). Idle / Walk / Run / Sleep / Happy / Surprised use the tracks.
- **FruitAnimator:** finds the mesh as `Handle` first, so lids and sparkles stay on the fruit when rigged.

## Seed Pack price pass (prices only)
| Pack | Price | Expected profit (base crop values) |
|---|---|---|
| Starter | 235 | 25.6% |
| Garden | 425 | 18.1% |
| Flower | 455 | 18.3% |
| Woodland | 755 | 14.9% |
| Golden Grove | 830 | 13.9% |
| Enchanted | 1,040 | 12.7% |

Profit per Seed still rises with every tier. Break-even (expected value of 3 Seeds × 6 units) is 295 / 502 / 538 / 868 / 945 / 1,172. Farm coin bonuses (Market Stand / Golden Fountain / Paradise Gate) raise real profit above these figures for late players.

## Starter Seed Pack safety fix (price only)
- Starter Seed Pack: **235 → 180 Coins**. Nothing else changed (other packs, crops, odds, growth, tutorial untouched).
- Expected value 295.2 → expected profit **64.0%**. Worst roll (3 Clovers) returns 144 Coins (−36); every other roll returns ≥ 180, so only 6.4% of packs lose Coins (was 31.6% at 235, 20.8% at 185–200).
- Chance a farming-only new player cannot afford a 2nd pack from the 1st one: 7.7% (was 44.4%); the tutorial leftover Clover units, the 100-Coin playtime gift and free Garden Spins cover that gap.
- The tutorial top-up (`Player:_tutorial_cover_costs`) reads `SeedPacks.getPack("starter").price`, so it follows the new price automatically.
- Note: at 180 the Starter pack's profit per Seed (38.4) is above Garden / Flower / Woodland per Seed; higher packs still give far more Coins per harvest tap and per planting spot (Starter 16.4 per unit vs Garden 27.9 … Enchanted 65.1).

## Final release polish pass
**Hotbar during loading**
- New `ReplicatedFirst.BackpackVisibility`: the one place that hides/shows the Roblox Backpack hotbar, using hide reasons (`Loading`, `SeedPackReveal`). The hotbar is shown only when no reason is left; repeated hide/show calls do nothing.
- `ReplicatedFirst.LoadingScreen` hides the hotbar on its first line and shows it again when loading finishes or Skip is pressed (60 s safety net). Only CoreGui visibility changes: Tools, the Backpack and data are untouched.
- `SeedShop._setHotbarHidden` uses the same module, so a Seed Pack reveal and the loading screen can no longer re-enable each other's hidden hotbar.

**Map fixes (decoration only; no interaction point, soil, plot or NPC moved)**
- Orchard fence: all 10 rails were rotated 90°, so they cut straight through the orchard (Heart Tree, entrance path, sign, Farm and Toxic Egg stands) with collision on. They now run along their posts.
- Orchard: 4 fruit trees that grew through the Farm / Desert / Void / Toxic Egg stands moved to a row just outside the front fence. 4 trees and 2 planter crates were nudged 1–4 studs clear of the stands. The Heart Tree (with its benches) moved 1.5 studs back so a bench no longer clips the Jungle Egg stand.
- Plaza: the two lamp posts standing in the middle of the north (to the Orchard) and south paths were moved to the path edge.
- Fruit Pen: the 4 decorative Fruit statues were 9–15 studs tall (2–4× a real Fruit). They are now half size (4.4–7.3 studs), with eyes and eyelids scaled to match.
- Seed Seller / Crop Seller: their two name labels were drawn on top of each other. They are now stacked (name/role on top of the hat, shop title above it).
