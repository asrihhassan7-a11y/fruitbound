# FruitBound — Final Release Plan (prepared, NOT implemented)

Source: `Fruitbound_Claude_06_october.rbxl`, read-only audit. Nothing below has been changed in Studio
and nothing has been live-tested. Paths are inside the place (e.g. `Server/Controllers/Farm` =
`ServerScriptService.Server.Modules.Controllers.Farm`).

---------------------------------------------------------------------------------------------------
## F. BLOCKERS vs POLISH (read first)

| Item | Class | Why |
|---|---|---|
| 3 Quest cleanup (Rebirth 50-100/day, Gain 10M-5T Coins/day) | **BLOCKER** | Mathematically impossible quests shown to every player daily/weekly |
| 2 Second Floor persistence fix | **BLOCKER for expansion** (do it anyway, it is small and harmless) | Rebuild/plant/spacing ignore `floor` |
| 9 Seven new crops live validation | **BLOCKER** | They are sold in live packs; never live-validated |
| 10 Final QA (save/rejoin, Output, mock=false, no temp objects) | **BLOCKER** | Release gate |
| Bubble Chat (`studio/bubble_chat_fix.lua` + test sheet) | BLOCKER-lite | Script ready, not applied / tested |
| 7 Mobile | BLOCKER **only** for a panel unusable at 667x375 (GearShop most at risk) | unknown until tested |
| 1 Staff titles + admin | Important polish (launch-ops) | Creator Hub ban tools exist as fallback |
| 5 Hold Fish | Polish / feature | not built yet |
| 4 Fence tiers | Polish / feature | not built yet |
| 6 Coin icons | Polish | visual consistency only |
| 2b Second Floor expansion | Polish / feature | only after the persistence fix |
| 8 Onboarding text tweaks | Polish | Goals already cover Gears + Fishing |

---------------------------------------------------------------------------------------------------
## C. WORK ORDER

1. Bubble Chat: run `studio/bubble_chat_fix.lua`, then `studio/bubble_chat_test.md` (already prepared).
2. Quest pool cleanup (data-only, smallest blocker).
3. Second Floor persistence fix (no expansion) + its tests.
4. Staff roles + admin commands (gives the test tools every later step uses: grow, seeds, coins, fish, tp).
5. Hold Fish.
6. Fence tiers.
7. Coin icons.
8. Second Floor expansion: measure → implement → test.
9. Mobile fixes (only panels that fail at 667x375).
10. Onboarding text tweaks.
11. Seven crops validation sheet (uses admin grow/seeds).
12. 20–30 min real economy session (no rebalancing unless a blocker).
13. Final QA pass → you publish manually.

---------------------------------------------------------------------------------------------------
## A. IMPLEMENTATION CHECKLIST

### 1. Staff titles + admin commands
Current state (audited):
- `Common/Modules/Utilities/AdminUtility`: `ADMIN_USER_IDS = {419938519}` (owner) + "user-owned game creator" rule. `isAdmin(player)`.
- Callers that MUST keep working: `Mount` (`!givemount`, `!mount`, `!unmount` via `player.Chatted`), `WorldEvents` (`!event <id|stop>`), `FruitUtility` admin_only fruit guard, `Player` admin_only fruit cleanup / equip.
- No staff titles exist (Titles: Seedling…Paradise Farmer + hidden PRO/YTBER/FAN).
- Overhead: `Assets/UI/CharacterBillboard` built per player on every client by `Client/Controllers/Character:_create_billboard` (adornee = HumanoidRootPart, R6 ok). Its `Main` frame is saved **Visible = false** and nothing turns it on → currently no overhead text shows.

Plan:
- [ ] **Extend AdminUtility** (do not replace):
  - `ROLES = {TESTER = 1, COMMUNITY_MANAGER = 2, DEVELOPER = 3, OWNER = 4}` + display `{text, color}` per role.
  - `STAFF = {[419938519] = "OWNER", ...}` — single centralized list (keep `ADMIN_USER_IDS` as alias → OWNER for compatibility).
  - Optional: `GROUP_ID = 9910341`, `GROUP_RANKS = {[255] = "OWNER", [n] = "DEVELOPER", ...}` resolved server-side with `GetRankInGroup` (pcall, cached per session).
  - `getRole(player) -> name?, level` (config + creator rule; never from data/attributes).
  - `isAdmin(player)` = `level >= DEVELOPER` (keeps today's behaviour: owner + creator).
  - `canTarget(actor, target)` = `actorLevel > targetLevel` (strictly higher; equal cannot act).
  - `has(player, permission)` with a permission → min-level table.
- [ ] **Server controller `Server/Controllers/Staff`**:
  - On PlayerAdded: `player:SetAttribute("StaffRole", roleName or nil)` (display only; permission checks always call `AdminUtility` on the server).
  - Commands as ONE `TextChatCommand` (`PrimaryAlias = "/fb"`) created on the server under `TextChatService.TextChatCommands` so commands are not broadcast as chat/bubbles. Parse `"/fb <cmd> <args>"` in `Triggered(textSource, text)` on the server. **Verify on first test that `Triggered` fires on the server**; fallback = `S_Staff_Run` RemoteFunction from a tiny staff panel (same permission checks).
  - Keep `!event` / `!givemount` handlers untouched (they call `isAdmin`).
  - Every command: resolve actor role → check permission → resolve target by partial name/DisplayName (unique match only) → `canTarget` for any command on another player → log `print("[Staff]", actor, cmd, target)`.
  - Rate limit 0.5 s per actor.
- [ ] **Command set** (min role):
  | Group | Commands | Min role | Notes |
  |---|---|---|---|
  | Moderation | `kick <p> [reason]`, `mute <p>` / `unmute <p>` (set `TextSource.CanSend` on RBXGeneral, server) | COMMUNITY_MANAGER | only lower roles |
  | Moderation | `ban <p> <days> <reason>` / `unban <userId>` (`Players:BanAsync` / `UnbanAsync`) | DEVELOPER | only lower roles |
  | Teleport | `tp <p>` (self → p), `farm`, `village` (existing `Farm.teleport`) | TESTER | self only |
  | Teleport | `bring <p>` | COMMUNITY_MANAGER | lower roles only |
  | Testing | `grow` (mature own crops: set `planted_at` back, call `FarmingV2._rebuild`), `seeds <id> <n>` (`FarmingV2.giveSeeds`), `pack <id> <n>` (`FarmingV2.givePack`), `fish <speciesId> [kg]`, `floor` (grant `garden_floor2`), `fence <1-4>`, `quests reroll` | TESTER | **self only, and only when `RunService:IsStudio()` or `game.PrivateServerId ~= ""`** |
  | Economy test | `coins <n>` / `setcoins <n>` (via `player_controller:_add_coins` / `stats.Strength`) | DEVELOPER | same Studio/private-server gate |
  | Info | `role`, `whois <p>`, `cmds` | TESTER | |
- [ ] **Overhead title** (no second billboard): in `CharacterBillboard`, add one `TextLabel` named `StaffTag` as a **direct child of the BillboardGui** (sibling of hidden `Main`), top-anchored. In `Client/Controllers/Character:_create_billboard` bind the target player's `StaffRole` attribute → `StaffTag.Visible/Text/TextColor3` (+ UIStroke). Set the billboard `StudsOffset = (0, 2.6, 0)` so the tag sits above the R6 head (tune live). Then set `BubbleChatConfiguration.VerticalStudsOffset ≈ 1.5` so bubbles sit above the tag.
- [ ] **Chat prefix** (optional): server `ChatTitles.publish` uses the staff role text/colour when the player has a role (so chat shows `[OWNER] Name:`); otherwise the equipped title as today.
- [ ] No permission in save data. Grep after: no `data:Set(` with role/staff/admin.

### 2. Second Floor persistence fix (no expansion)
Audited facts: crops save `{x, z, floor = 2 | nil}` in `seed_crops`; `cropSurface` (`FarmingV2:209`), `soilAt` (`:163`), plant validation (`:797-817`), spacing (`:816`) all ignore `floor`. Auto Collect (`Harvest.findNearest`: dy < 15) and Watering/Gears (`isNear` 3D on model pivot) are already height-aware once models are placed correctly.
- [ ] `soilAt(list, x, z, margin, floor)` — when `floor` given, only rects with `(rect.floor or 1) == floor`.
- [ ] `cropSurface(state, entry)` → `soilAt(soilRects(nil), entry.x, entry.z, 0, if entry.floor == 2 then 2 else 1)`.
- [ ] `plantSeed`: collect every owned rect containing (x, z) with EDGE_MARGIN; pick the one with the smallest `|rel.Y - top|` that is ≤ 3 → that is the floor. Keep the existing "locked" vs "soil" error logic, but evaluated per floor (closest-height rect from `soilRects(nil)`).
- [ ] Spacing check only against crops with the same floor (`(entry.floor or 1) == newFloor`).
- [ ] `Databases/GardenFloor`: build `deck.at`, `opening.at`, `beds[i].at` Y from `HEIGHT` (one constant). Keep `FarmingV2` bed `top = bed.at.Y + 1 + SOIL_HEIGHT` consistent with `GardenFloor.buildDeck` (`surface = HEIGHT + 1`).
- [ ] Fix stale comment in `Settings.template` (`"F2:" key prefix` → `floor = 2 field`).
- [ ] No data migration. Old crops: `floor == nil` → ground; deck crops already `floor = 2`.

### 2b. Second Floor expansion (only after 2 passes its tests)
- [ ] Measure first in Studio (command bar): plot size (140x140, `Farm.PLOT_HALF = 70`), the tallest part Y of every built upgrade (windmill, barn, greenhouse, fountain, paradise gate, helper huts, trees) on a fully-upgraded test plot, and current deck/pillars.
- [ ] Choose deck size (~124x118) and HEIGHT (~23) so deck underside clears every structure (or add openings around the windmill etc.).
- [ ] Update `GardenFloor` DB: `HEIGHT`, `deck`, `opening`(s), `beds`, `lift`, `pillars`, `PILLAR_SIZE`; `Farm.blockedRects` uses pillars automatically.
- [ ] Ground crop visibility/tapping from above: keep openings/skylights over ground soil or keep the deck translucent where needed (decide after measuring).
- [ ] Check `AUTO_FARM_HALF = 70` and `|rel.Y| <= 40` in `Player:_auto_collect_tick` still cover the deck.
- [ ] Price stays `COST = 750000` unless you decide otherwise.

### 3. Quest cleanup
Audited (`Databases/Quests`, random pick with replacement in `DailyQuestUtility.generate` / weekly equivalent):
| id | Text | Daily | Weekly | Reachable? |
|---|---|---|---|---|
| 1 | Harvest N Fruits | 17–67 | 100–250 | yes |
| 2 | Collect N Food | 15–60 | 100–250 | yes (each harvest) |
| 3 | Open N Eggs | 50–100 | 1,200–4,500 | yes but expensive (Farm Egg 750 Coins → 37K–75K/day) — economy test |
| 4 | **Rebirth N Times** | **50–100** | **600–1,500** | **NO** — rebirth is reachable (More › Progression, 1st = 25K Coins) but each costs ×2.2 more; 50/day is impossible |
| 5 | Feed Your Fruits N Times | 10–30 | 50–100 | yes (Fruits › Feed button, `Player:_fruits_feed`) |
| 6 | Level Up Fruits N Times | 3–10 | 20–50 | yes (from feeding) |
| 7 | **Gain N Coins** | **10M–5T** | **25 quadrillion+** | **NO** for normal economy (Paradise Gate, the last upgrade, is 45M) |
Tutorial quests (`TutorialQuestUtility.getList`): Open 1 Egg, Rebirth 1 (25K Coins), Gain 50 Coins → all reachable.
Crowns: real currency (Clan Shop `Player:1401`, also from Invite/Free/Daily gifts/Clan quests) → rewards are fine.
- [ ] Add `pool = false` to quests 4 and 7 in `Databases/Quests` (keep the entries so saved lists still resolve via `QuestUtility.getInfo`).
- [ ] In `DailyQuestUtility.generate` and `WeeklyQuestUtility.generate`: pick randomly only from entries with `pool ~= false`.
- [ ] Optional: avoid duplicate ids in one list (re-roll if already picked).
- [ ] Do not touch tutorial quests. Existing saved lists expire naturally (daily next day, weekly next week).

### 4. Fence tiers
Audited: each map plot `Workspace/__MAP/FarmIsland/Plots/N` has `Fence` (67 Parts), `Base`, `Sign`, `SignPostL/R`, `Spawn`, `Built`, `Pads`. `Farm.assign` (`Farm:217`) / `release` (`Farm:313`). Coins are spent with `data:Set({"stats","Strength"}, coins - cost)` (`Farm.buy:187`).
- [ ] `Databases/Fences`: T1 Basic 0 (current fence), T2 Reinforced 150,000 (~5 studs, stronger posts, 3 rails, simple cross braces), T3 Palisade 2,000,000 (~9 studs, thick posts, dense timber board panels), T4 Fortified 15,000,000 (~12 studs, low stone base, heavy timber, stone pillar accents; cozy countryside, NOT castle). Full spec in EXECUTION_PACKAGE E6.
- [ ] Template: `fence_tier = 1` (Reconcile fills old profiles).
- [ ] `Server/Controllers/Fence`:
  - `apply(plot, tier)`: tier 1 = original parts visible exactly as today, `FenceTier` folder removed; tiers 2–4 = originals hidden (never moved), tier fence generated into `plot.model.FenceTier` from the original layout (post X/Z + one run per original rail; no rail = entrance gap stays open; gap width ≥ T1 at every tier).
  - `buy(player)`: rate limit; must own a plot; next tier only (`current + 1`); server reads price from DB; coins ≥ price; set `fence_tier`, spend coins, `apply`.
  - Hooks: `Farm.assign` → `Fence.apply(plot, data.fence_tier)`; `Farm.release` → `Fence.apply(plot, 1)`.
  - Buy UI: ProximityPrompt on the plot sign (or a small sign by the entrance) built by the controller, owner-only; shows next tier + Coin icon price; reuse `Confirm` UI.
- [ ] No scripts inside fence parts.

### 5. Holdable Fish
Audited: crop hold = `Server/Controllers/Items` (`hold/unhold`, visual welded model, not a Tool, item stays in inventory, 0.5 s ownership watcher, unhold on death/CharacterRemoving/leave). Fish bag entry: `{u = uid, f = speciesId, w = kg, v = coins, q = "perfect"?, t = time}`; rarity from species DB; tier from `FishingUtility.weightTier`. No 3D fish models exist.
- [ ] `Common/Modules/Utilities/FishModelUtility.build(entry)`: small procedural fish (body + tail + eye), colour by rarity, size by weight tier (clamped), sparkle if `q == "perfect"`; PrimaryPart handle; all parts Massless, CanCollide/CanQuery/CanTouch false.
- [ ] `Items`: state gets `kind = "crop" | "fish"`. `Items.holdFish(player, uid)`: validate string ≤ 20, rate limit, alive, uid exists in `data.fishing.bag` → `Items.unhold` (one slot shared with crops) → build, weld like crops, attributes `FishUid/Species/Weight/Rarity/Value/Perfect`, `HeldItem = "fish:" .. uid`. Same uid again = put away.
- [ ] Watcher: for `kind == "fish"` unhold when uid no longer in bag.
- [ ] `Fishing.sell`: after `save`, call `Items.unholdFish(player)` if the held uid was sold (instant, the watcher is the backup).
- [ ] `Fishing.cast` / rod equip: unhold a held fish first.
- [ ] Remote `S_Item_HoldFish(uid)`.
- [ ] Client `UI/Fishing` bag row: button **"🐟 Carry"** (toggles to "Put away"); not "HOLD".
- [ ] No Tool, so nothing enters Backpack, cannot be dropped/traded/duplicated. (Deviation from the earlier "Fish Tool" idea on purpose: a Tool adds drop/dup paths.)

### 6. Coin icon consistency
Single source: `Databases/Stats` → `Strength.image = rbxassetid://107803545719047` (HUD `Main/Top/Stats/Strength/Icon`).
- [ ] `Common/Modules/Utilities/CoinIconUtility`: `ICON` read from Stats; `CoinIconUtility.label(parent, props)` → Frame with UIListLayout(horizontal): ImageLabel(icon, square) + TextLabel(amount); `setAmount(frame, text)`. For world BillboardGui/SurfaceGui signs the same helper.
- [ ] Replace 💰 where it is a Coin amount/price:
  | File:line | Use | Action |
  |---|---|---|
  | Client `GearShop:189` | buy button price | **replace** |
  | Client `UI/Fishing:272` | fish value in bag row | **replace** |
  | Client `UI/Fishing:325` | bait price button | **replace** |
  | Client `UI/Fishing:418` | rod/cosmetic price | **replace** |
  | Client `Decor:372, 413` | coins balance label | **replace** |
  | Client `Decor:467` | decor price | **replace** |
  | Client `Backpack:390` | "Worth:" total | **replace** |
  | Client `Backpack:407/419` | row worth + row sell button | replace worth; sell button = optional |
  | Client `Backpack:185, 310` | "SELL", "SELL ALL" action buttons | optional (action, not amount) |
  | `FarmBuilder:681`, `Farm:137` | upgrade price signs (world) | **replace** (icon + text) |
  | Server `GardenFloor:302, 333` | floor sale sign price | **replace** |
  | Server `Leaderboard:29` | board title "💰 Coins" | replace if layout allows (polish) |
  | `Guide:32` | step title "💰 Sell" | keep (step label) |
  | `Backpack:334`, `UI/Fishing:290, 299`, `Decor:327`, `Backpack:364-365` | notifications / hints | keep text |
  | `UpgradeTree:19` | node icon | keep |
- [ ] Also check SeedShop / Garden Upgrade pads / Confirm dialog price text for "Coins" text without icon → add icon where it is a price.
- [ ] Don't touch Robux, Gems, Store artwork (`Store/Main/Middle/Strength/*` art), values.

### 7. Mobile (target 667x375 landscape; Roblox top bar reduces usable height)
At risk from code (fixed sizes / no UIScale):
- [ ] `GearShop` window `fromScale(0.6, 0.62)` → ~400x232 px: likely cramped → if rows clip, use `fromScale(0.9, 0.85)` on small screens (`viewport.Y < 500`) and a ScrollingFrame with `AutomaticCanvasSize`.
- [ ] `UI/Fishing` main `0.92x0.82` + fixed 36 px header / 52 px close: likely OK; check tab rows and bag rows scroll.
- [ ] Fishing HUD `HOLD TO REEL` at `(0.5, 1, -110)`: check it doesn't overlap the jump button / bottom bar; raise or shrink on small screens if it does.
- [ ] `UI/Daycare` `0.9x0.78`: check grid cell 150x172 fits 2 rows; else scroll.
- [ ] `UI/Quests` (StarterGui template, no UIScale): check it fits; add UIScale fit if not.
- [ ] Garden Upgrade pads / floor sign / fence prompt: ProximityPrompt readable, not overlapping HUD.
- [ ] Hold Fish "Carry" button ≥ 44 px tall.
- [ ] Staff tag + bubbles: readable, not stacked into the HUD top bar.
Only change panels that fail the test.

### 8. Onboarding
Audited: Guide steps Harvest → Sell → Seeds → Plant (first crop ≤ 60 s) → Grow → Hatch → Equip. After that `Goals` shows one line: Harvest 5 → **Buy a Watering Can** → **Catch 5 fish** → Find a Wild Fruit → … Fishing has its own 6 tips (incl. "Sell fish… at Fisher Finn's FISHING stall"). Rod + 5 worms are free.
- [ ] Recommendation: **no new Guide steps.** Only make the two Goals lines say where:
  - `"Buy a Watering Can"` → `"Buy a Watering Can at the Gear Shop"`
  - `"Catch 5 fish"` → `"Catch 5 fish at Fisher Finn's stall"`
- [ ] Optional polish later: tapping the Goals line points the existing Guide arrow at the place.

### 9. Seven new crops — see test sheet B.9.
- [ ] No pack/price change. Mythical Garden stays removed. Apple seed stays `available = false`.

### 10. Final QA — see B.10.

---------------------------------------------------------------------------------------------------
## B. TEST CHECKLIST (live, Studio Local Server, 2 players unless noted)

### B.1 Staff
- [ ] Owner (419938519) gets OWNER tag above head (R6), tag in chat prefix (if done), `/fb role` → OWNER.
- [ ] Non-staff: `/fb kick X` does nothing, message not shown in chat, no Output error.
- [ ] Each role (temporarily add test accounts in STAFF): allowed commands work, disallowed are refused.
- [ ] CM cannot kick/mute DEVELOPER/OWNER; DEVELOPER cannot ban OWNER; equal roles cannot act on each other.
- [ ] Test/economy commands refused in a public server (simulate: gate off), work in Studio/private server.
- [ ] `!event rain`, `!givemount`, `!mount`, `!unmount` still work for owner.
- [ ] One billboard per character (Explorer › PlayerGui: one CharacterBillboard per player), respawn keeps one.
- [ ] Bubble above staff tag, no overlap. Rejoin keeps role. Role not in DataStore (inspect profile).

### B.2 Second Floor fix
- [ ] Old save with ground + deck crops loads: every crop on the right floor.
- [ ] Plant on deck, plant on ground nearby → both accepted, rejoin → same places.
- [ ] (After expansion) plant ground crop, plant deck crop exactly above → both accepted; leave/rejoin → ground stays ground, deck stays deck.
- [ ] Spacing: two crops on the same floor closer than 4.5 studs refused; same x/z on different floors allowed.
- [ ] Auto Collect on deck only collects deck crops; on ground only ground crops.
- [ ] Watering Can/Fertilizer/Shears on deck crops from the deck; refused from the ground (distance).
- [ ] Lift up/down, respawn on deck, Output clean.

### B.3 Quests
- [ ] Reroll daily/weekly 20+ times (`/fb quests reroll`): ids 4 and 7 never appear.
- [ ] Profile with old saved id 4/7 quest still displays and does not error.
- [ ] Harvest/Feed/Level/Eggs quests progress by the right amount once; claim gives Crowns once; rejoin keeps progress.
- [ ] Wild Fruit: catch one → Goals line moves on; rejoin → still done.

### B.4 Fence
- [ ] New profile: T1. Buy T2 with < 150K → refused; with enough → coins −150,000 exactly, visuals T2.
- [ ] Cannot skip tiers; T4 max; spam-buy → only one charge.
- [ ] Walk through entrance at every tier (also on a phone).
- [ ] Leave → plot visuals back to T1; another player gets that plot → T1; rejoin → own tier restored on any plot.

### B.5 Hold Fish
- [ ] Carry fish A → visual in hand, `HeldItem = fish:<uid>`; carry fish B → A disappears, B shown.
- [ ] Sell A while carried (single + Sell All) → visual gone instantly, Coins added once, bag count correct.
- [ ] Death, reset, Travel, leave → put away; no fish lost or duplicated (bag count before/after).
- [ ] Cast rod while carrying → fish put away. Carry crop then fish → only one held.
- [ ] Spam the Carry button / exploit remote with fake uid → refused.

### B.6 Coin icon
- [ ] Every replaced spot shows the HUD coin image; numbers unchanged; world signs readable.
- [ ] Robux/Gems/Store art unchanged.

### B.7 Mobile (Device emulator 667x375 + one real phone if possible)
- [ ] Open every menu: Seed Packs, Gear Shop, Fishing (all tabs), Hatching, Daycare, Quests, Garden Upgrades pads, Second Floor sign/lift, Fence prompt, NPC dialogue, Carry fish, Backpack, Fruits, Trade, Settings.
- [ ] Close buttons reachable; nothing off-screen; text ≥ readable; HOLD TO REEL usable; bubbles + staff tag fine.

### B.8 Onboarding (fresh profile, 10 minutes, no admin)
- [ ] Minute 0–3: harvest starter crop, sell, buy Starter pack, plant (≤ 60 s growth).
- [ ] Minute 3–6: harvest, hatch, equip.
- [ ] Minute 6–10: Goals → Watering Can at Gear Shop, Catch fish at Finn. Player can find both without help.
- [ ] Note every moment of confusion.

### B.9 Seven new crops (use `/fb seeds <id> 3` + `/fb grow`, and once naturally)
Expected (size roll 1.0; value scales with weight, farm bonuses on top):
| Seed id | Growth | Base kg | Base value | Pack (chance) |
|---|---|---|---|---|
| golden_corn | 30m | 1.5 | 420 | Harvest (10%) |
| blossom_berry | 40m | 0.5 | 500 | Woodland (10%) |
| river_melon | 45m | 4.5 | 550 | Golden Grove (15%) |
| crystal_bean | 50m | 0.8 | 600 | Enchanted (15%) |
| dragon_pepper | 60m | 1.0 | 760 | Golden Grove (20%), Enchanted (30%) |
| moonberry | 75m | 0.7 | 920 | Enchanted (25%) |
| dragon_fruit | 90m | 1.2 | 1,200 | Enchanted (5%) |
For each crop:
- [ ] Stage check with FORCED timestamps (not `/fb grow`): planted_at at progress 0.05 / 0.50 / 0.80 / 0.97 / 1.02 of growth time, rebuild after each, inspect (helper in EXECUTION_PACKAGE E10). Stage1 → Stage2 → Stage3 (procedural) → Mature (custom model): no jarring jump; on ground and deck.
- [ ] `/fb grow` only afterwards, for harvest/value checks.
- [ ] Mature scale vs neighbours, orientation upright, grounded (not floating/buried), on ground AND deck.
- [ ] Big/Huge/Giant + overgrowth cap (`VISUAL_SCALE_MAX = 3`) looks sane.
- [ ] Harvest gives exactly ONE item; weight/value match the table × size² (× farm bonus).
- [ ] Backpack ✋ Hold shows the right model upright in hand.
- [ ] Mobile tap-to-harvest works (tap radius on the custom model).
- [ ] Leave/rejoin while growing and while mature → same stage/size, still harvestable once.

### B.10 Final QA
- [ ] Fresh profile (new test account or wiped key in Studio): tutorial end-to-end, Output clean.
- [ ] Returning profile (your main): all crops, fruits, fishing bag, floor, fence tier, quests intact.
- [ ] Respawn (reset) in Farm, Village, Fishing spot, deck.
- [ ] Rejoin ×2: data identical (Coins, seeds, crops, bag, fence_tier, garden_floor2, wild_captures, quests).
- [ ] Save: leave → rejoin on another server (Team Test or published test place) → data persisted.
- [ ] Mobile pass (B.7). Quests (B.3). Fishing full loop. Crops (B.9). Fence (B.4). Second Floor (B.2). Staff (B.1). Bubble Chat (`bubble_chat_test.md`).
- [ ] Output: no red errors; no `Infinite yield`; prints reduced (24 `print(` in live scripts — remove or keep intentional ones).
- [ ] `Settings.data.mock == false` (it is today) and `key = "Player_Data_002"` unchanged.
- [ ] No temp/QA objects: search Workspace/ReplicatedStorage/StarterGui for `QA|Test|Debug|Temp|Copy` (today: none found); remove stray `ReplicatedStorage/Assets/Crops/Tree` if unused.
- [ ] Apple seed unobtainable, Mythical Garden absent, Helper Coin generation absent.
- [ ] Publish manually only after every line passes.

---------------------------------------------------------------------------------------------------
## D. RISKS
1. **TextChatCommand server `Triggered`** behaviour must be confirmed live; fallback = staff RemoteFunction panel.
2. **Staff test tools in live servers** = economy exploit if the gate is wrong → gate by `IsStudio()/PrivateServerId` AND role, self-only.
3. **Billboard offset** change could clip with tall hats / mounts; tune live. `CharacterBillboard` hides while the viewer has any menu open (existing behaviour).
4. **Second Floor**: changing `soilAt` signature touches plant/rebuild/overgrow paths; test old saves first. Expansion can clip barn/windmill/greenhouse and hide ground crops.
5. **Quest pool**: removing ids changes nothing for saved lists only if the DB entries remain (keep them, just `pool = false`).
6. **Fence**: restyling map parts must restore exactly on release; plots are reused between players → test reassign. Don't resize X/Z (entrance).
7. **Hold Fish**: shared hold slot with crops — make sure crop watcher logic still works for crops (branch on `kind`).
8. **Coin icon**: replacing text labels with frames can break `TextScaled` layouts; test each spot at 667x375.
9. **Mobile**: emulator ≠ real device (safe area / top bar). Test one real phone.
10. **Economy**: do not rebalance from theory; Egg quest (50–100 eggs/day) is the one to watch in the 20–30 min session.
11. **DataStore**: never change `Settings.data.key`; all new fields additive (`fence_tier`), filled by `Reconcile`.

---------------------------------------------------------------------------------------------------
## E. CODEX PROMPTS (one per task; paste with this file attached)

**E1 Staff + admin**
> FruitBound: implement staff roles per studio/RELEASE_PLAN.md §A.1. Extend Common/Modules/Utilities/AdminUtility (keep isAdmin semantics: owner 419938519 + creator rule = admin; isAdmin = role ≥ DEVELOPER). Roles OWNER 4 > DEVELOPER 3 > COMMUNITY_MANAGER 2 > TESTER 1 in one config table; no role in save data. New Server/Modules/Controllers/Staff: sets StaffRole attribute (display only), one server-created TextChatCommand "/fb" with the command table in §A.1, strict higher-role targeting, test/economy commands self-only and only in Studio or private servers. Add a StaffTag TextLabel as a direct child of Assets/UI/CharacterBillboard and bind it in Client/Controllers/Character:_create_billboard; no new BillboardGui. Do not change Mount/WorldEvents commands. Report changed files and run B.1.

**E2 Second Floor persistence**
> FruitBound: make Seed crops floor-aware per RELEASE_PLAN §A.2 in Server/Modules/Controllers/FarmingV2 (soilAt floor filter, cropSurface uses entry.floor, plantSeed picks the bed closest in height ≤ 3 studs, spacing per floor) and derive all Y values in Databases/GardenFloor from HEIGHT. No save migration; floor nil = ground. Do NOT change deck size or HEIGHT. Run B.2 (non-expansion rows).

**E3 Second Floor expansion** (only after E2 passes)
> FruitBound: first measure (command bar) plot bounds and the top Y of every built farm upgrade on a fully upgraded plot; report numbers and a proposed deck rect/HEIGHT/openings. Wait for approval before editing Databases/GardenFloor.

**E4 Quest cleanup**
> FruitBound: in Common/Modules/Databases/Quests add pool = false to ids "4" (Rebirth) and "7" (Gain Coins); in DailyQuestUtility.generate and WeeklyQuestUtility.generate choose only entries with pool ~= false (and avoid duplicate ids within one list). Keep the DB entries. Don't touch TutorialQuests. Run B.3.

**E5 Fence tiers**
> FruitBound: implement fence tiers per RELEASE_PLAN §A.4: Databases/Fences, template field fence_tier = 1, Server/Modules/Controllers/Fence (apply/buy, restyle the existing Plots/N/Fence parts, store originals as attributes, never change X/Z), hook Farm.assign → apply(saved tier) and Farm.release → apply(1), owner-only ProximityPrompt + Confirm UI, server-side price check, spend via stats.Strength like Farm.buy. Run B.4.

**E6 Hold Fish**
> FruitBound: add Carry Fish per RELEASE_PLAN §A.5 by extending Server/Modules/Controllers/Items (shared single hold slot, kind = "fish", visual welded model, not a Tool), new FishModelUtility, remote S_Item_HoldFish(uid), unhold on sell in Fishing.sell and on cast, "🐟 Carry" button in UI/Fishing bag rows. Fishing bag stays authoritative. Run B.5.

**E7 Coin icons**
> FruitBound: add CoinIconUtility (icon from Databases/Stats Strength.image) and replace 💰 only in the rows marked "replace" in RELEASE_PLAN §A.6. Keep notifications, Guide title, UpgradeTree icon, Robux/Gems/Store art. No value changes. Run B.6 at 667x375.

**E8 Mobile**
> FruitBound: at 667x375 (device emulator) open the panels in RELEASE_PLAN §A.7/B.7, report which clip, and fix only those (fit-to-screen size on small viewports + scrolling). No redesign.

**E9 Onboarding text**
> FruitBound: in Client/Controllers/Goals change only the texts "Buy a Watering Can" → "Buy a Watering Can at the Gear Shop" and "Catch 5 fish"/"Catch 25 fish" → "... at Fisher Finn's stall". Nothing else.

**E10 Crops validation / Final QA**
> FruitBound: run RELEASE_PLAN B.9 and B.10 exactly, fill each checkbox with PASS/FAIL + evidence (screenshot or Output line). Do not fix anything during the pass; list failures.
