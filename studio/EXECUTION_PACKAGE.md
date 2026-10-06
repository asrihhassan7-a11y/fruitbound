# FruitBound — Execution Package (E1–E10)

Run one prompt at a time, in order. Each prompt is standalone.
Rules for every prompt: no publishing; no new gameplay systems; a live test counts as PASS only if it was actually run in Studio (otherwise report `NOT RUN`).
Paths: `Server/Controllers/X` = `ServerScriptService.Server.Modules.Controllers.X`, `Client/Controllers/X` = `StarterPlayer.StarterPlayerScripts.Client.Modules.Controllers.X`, `Client/UI/X` = `…Client.Modules.UI.X`, `Common/…` = `ReplicatedStorage.Common.Modules.…`.

---

## E1 — Bubble Chat

```
FRUITBOUND E1 — BUBBLE CHAT FIX. Do not publish. Report NOT RUN for any test you did not actually run in Studio.

1. INSPECT
- TextChatService: ChatVersion, CreateDefaultTextChannels
- TextChatService.BubbleChatConfiguration and its children (UICorner, UIGradient, ImageLabel)
- ServerScriptService.Server.Scripts.server-main: the block that starts
  `task.spawn(function()` / `local ChatService = require(Services.ServerScriptService:WaitForChild("ChatServiceRunner"):WaitForChild("ChatService"))`
  and ends with `end)` right before `local function start_special_event()` (~lines 861–900)
- Read only: Server/Controllers/ChatTitles (legacy tags via FindFirstChild guard), Client/Controllers/ChatTitles, Client/Controllers/HatchAnnounce
- If the repo has studio/bubble_chat_fix.lua, you may run it in the Edit-mode Command Bar instead of editing by hand; it prints OK/SKIP/FAIL per step.

2. CHANGE
- TextChatService.ChatVersion = Enum.ChatVersion.TextChatService
- BubbleChatConfiguration: delete the ImageLabel child only if Image == ""; delete the UIGradient child only if Enabled == false; keep UICorner; MaxDistance = 80. Leave every other property as it is.
- server-main: delete that whole legacy ChatServiceRunner block (server ChatTitles already sets legacy speaker tags) and put a 2-line comment in its place. No WaitForChild("ChatServiceRunner") may remain anywhere.

3. DO NOT CHANGE
NPCDialogue, ChatTitles (client/server), Titles data, CharacterBillboard, chat moderation, any gameplay script.

4. BACKWARD COMPATIBILITY
Chat titles still prefix chat-window messages. Hatch announcements still post via RBXGeneral:DisplaySystemMessage.

5. SECURITY
No new remotes. No client-side chat filtering changes.

6. LIVE TEST (Studio > Test > Local Server, 2 players)
a) Server command bar: print(game:GetService("TextChatService").ChatVersion)
b) P1 chats "hello" → bubble above P1, visible to P2
c) P1 sends 5 messages quickly
d) Wait 20 s
e) P1 resets, then chats
f) P1 Travels Farm↔Village, then chats
g) Stop P2's client, start a new client, then chat
h) Both chat side by side
i) Stand ~90 studs from the speaker, then ~50 studs
j) Talk to Fisher Finn and the Seed Shop NPC
k) Hatch an egg rare enough to announce
l) Device emulator, 667x375 landscape: chat with 3 bubbles up
m) Check server and client Output

7. PASS IF
a) prints Enum.ChatVersion.TextChatService
b) bubble is readable and rounded
c) at most 3 bubbles, no duplicates
d) bubbles fade out, none stuck
e)–g) bubbles attach to the correct new character
h) each bubble is on the right character
i) hidden at 90 studs, minimized at 50
j) NPC dialogue window unchanged, no NPC bubbles
k) announcement appears in the chat window
l) bubbles don't cover the Fishing HOLD button or the Guide card
m) no red errors, no "Infinite yield ... ChatServiceRunner"

8. REPORT
Files/instances changed with before→after values, a diff of server-main, each test a–m as PASS/FAIL/NOT RUN with evidence (Output line or what you saw), remaining Output warnings.
```

---

## E2 — Quest cleanup

```
FRUITBOUND E2 — DISABLE IMPOSSIBLE RANDOM QUESTS. Do not publish. Report NOT RUN for any test you did not run.

1. INSPECT
- Common/Databases/Quests (entries id "1".."7"). "4" = "Rebirth N Times" (daily 50–100, weekly 600–1500); "7" = "Gain N Coins" (daily 10M–5T, weekly 25 quadrillion+). Both are impossible in this economy.
- Common/Utilities/DailyQuestUtility: generate(client), generateList(client) — currently ArrayUtility.random(Quests) with replacement
- Common/Utilities/WeeklyQuestUtility: generate/generateList (same pattern; confirm)
- Common/Utilities/QuestUtility.getInfo (must still find ids 4 and 7)
- Server/Controllers/Player: daily/weekly refresh (~lines 440–470), _quests_progress, _quests_claim
- Read only: Common/Databases/TutorialQuests, Common/Utilities/TutorialQuestUtility, Client/UI/Quests

2. CHANGE
- Add `pool = false` to the entries with id "4" and id "7" in Databases/Quests. Change nothing else in those entries.
- In DailyQuestUtility.generate and WeeklyQuestUtility.generate, pick randomly only from entries where `pool ~= false`. If that filtered list is empty, fall back to the full list (never error).

3. DO NOT CHANGE
- Quest texts, ranges, rewards
- TutorialQuests and the tutorial Rebirth quest (reachable)
- Progress/claim code, the quest UI, Goals / Wild Fruit goals
- No new quest system, no data migration

4. BACKWARD COMPATIBILITY
Saved daily/weekly lists that already contain id "4" or "7" must still display, progress and claim without errors. They expire naturally at the next round.

5. SECURITY
Generation stays server-side. No new remotes.

6. LIVE TEST (Studio Play; use the server-side command bar)
a) Run:
   local U=_G._L.Get{"Common","Modules","Utilities","DailyQuestUtility"}
   local c={} for i=1,1000 do local q=U.generate(nil) c[q.id]=(c[q.id] or 0)+1 end
   for k,v in pairs(c) do print("daily",k,v) end
   Repeat with WeeklyQuestUtility.
b) Old-save compatibility. Run:
   local P=game.Players:GetPlayers()[1]
   local client=_G._L.Get{"Common","Library","Network"}.Bindable.Invoke("S_Client_Get",P)
   client.data:Set({"quests","daily","v",1,"id"},"4")
   Then open the Quests UI.
c) Restore that slot afterwards: set it back to its original id, or set quests.daily.t = 0 and rejoin to regenerate.
d) Harvest crops and feed a Fruit → matching quests progress once per action; claim one completed quest → reward given once.
e) Rejoin → progress kept.

7. PASS IF
a) ids 4 and 7 have count 0; all others appear
b) the quest shows "Rebirth …" with no errors
d) correct increments, single reward
e) progress persisted; Output clean

8. REPORT
Diff of both utilities and the Quests DB lines, the printed counts, and test results a–e (PASS/FAIL/NOT RUN). Confirm that no QA data was left in the profile.
```

---

## E3 — Second Floor floor-aware crop fix

```
FRUITBOUND E3 — MAKE SEED CROPS FLOOR-AWARE (NO EXPANSION). Do not publish. Report NOT RUN for any test you did not run.

1. INSPECT (Server/Controllers/FarmingV2 unless noted)
- local soilRects(upgrades, floor2) (~123): ground rects from FarmUpgrades, then GardenFloor.beds with floor = 2
- local soilAt(list, x, z, margin) (~163): returns the FIRST rect containing x/z, ignoring floor
- local cropSurface(state, entry) (~209): soilAt(soilRects(nil), entry.x, entry.z, 0), ignores entry.floor. Used by buildCrop (~526) and _overgrow (~625).
- plantSeed (~772–850): soilAt(owned, …, EDGE_MARGIN), then |rel.Y - soil.top| > 3 → "soil"; spacing loop (~815) compares x/z only; saves `floor = if soil.floor == 2 then 2 else nil`
- syncPlayer (~644), legacySlotPosition, GROUND = 0.5, SOIL_HEIGHT = 0.4, MIN_SPACING = 4.5
- Common/Databases/GardenFloor: HEIGHT = 16; deck.at.Y, opening.at.Y and beds[i].at.Y are typed as 16 separately
- Server/Controllers/GardenFloor: buildDeck uses `surface = info.HEIGHT + 1`; ride uses the same
- Read only: Harvest.findNearest (dy < 15), Player:_auto_collect_tick, FarmingV2.waterCrop / gearTarget (3D distance to the model) — these become correct once models sit at the right height
- Common/Settings template comment on garden_floor2 (wrongly mentions an "F2:" key prefix)

2. CHANGE
a) soilAt(list, x, z, margin, floor): when floor is given, only match rects with (rect.floor or 1) == floor.
b) cropSurface: local floor = if entry.floor == 2 then 2 else 1; soil = soilAt(soilRects(nil), x, z, 0, floor).
   Fallback top when no rect matches:
   - floor 1: GROUND + SOIL_HEIGHT (as today)
   - floor 2: GardenFloor.HEIGHT + 1 + SOIL_HEIGHT
c) plantSeed: among owned rects that contain (rel.X, rel.Z) with EDGE_MARGIN, choose the one with the smallest |rel.Y - top|. It must be ≤ 3, else "soil". newFloor = rect.floor or 1. The "locked" check uses the same closest-height rule on soilRects(nil).
d) Spacing: only compare against crops where (entry.floor or 1) == newFloor.
e) Databases/GardenFloor: derive the Y of deck.at, opening.at and every beds[i].at from HEIGHT (set after the table is defined, or via a helper). Values must stay identical today (16).
f) Fix the Settings template comment: deck crops are saved with field floor = 2.

3. DO NOT CHANGE
- Deck size, HEIGHT, bed positions, price, lift, pillars (no expansion)
- Save format and keys of seed_crops
- Harvest/Auto Collect/watering logic, growth timing, tutorial crop, legacy slot migration

4. BACKWARD COMPATIBILITY
- floor == nil → ground; existing deck crops already have floor = 2
- No migration, no rewriting of saved crops
- Every existing crop must rebuild exactly where it was before

5. SECURITY
- Still server-only validation
- Client position is only used to pick a bed, never trusted for Y beyond the ±3 check
- No new remotes

6. LIVE TEST (Studio Play, test profile that owns garden_floor2; grant it with the server command bar data:Set("garden_floor2", true) and rejoin if needed)
a) Before changing code, note the positions of existing crops (ground and deck).
   After the change, rejoin and compare.
b) Plant on a ground bed and on a deck bed. Leave and rejoin.
c) Same-x/z rebuild test (server command bar):
   local P=game.Players:GetPlayers()[1]
   local client=_G._L.Get{"Common","Library","Network"}.Bindable.Invoke("S_Client_Get",P)
   local F=_G._L.Get{"Server","Modules","Controllers","FarmingV2"}
   local c=table.clone(client.data:Get("seed_crops"))
   c.qa_ground={seed_id="clover",planted_at=os.time(),x=-14.5,z=8,size=1}
   c.qa_deck={seed_id="clover",planted_at=os.time(),x=-14.5,z=8,size=1,floor=2}
   client.data:Set("seed_crops",c); F._rebuild(P,"qa_ground"); F._rebuild(P,"qa_deck")
   Read both models' pivot Y in plot space. Rejoin and read again.
d) With qa_ground present, plant a real Seed on the deck at about (-14.5, 8).
e) Plant two crops on the same floor less than 4.5 studs apart.
f) Auto Collect while standing on the deck, then on the ground.
g) Watering Can on a deck crop from the deck, then from the ground.
h) Remove qa_ground and qa_deck from seed_crops, and their models.

7. PASS IF
a) no crop moved
b) both crops on their own floor after rejoin
c) qa_ground at ground height, qa_deck at deck height, before and after rejoin
d) accepted (not "occupied")
e) refused
f) only collects that floor's mature crops
g) works from the deck, "distance" from the ground
h) no QA entries left
Output clean.

8. REPORT
Diff of FarmingV2, Databases/GardenFloor and the Settings comment. Measured Y values from (c). Test results a–h as PASS/FAIL/NOT RUN. Confirmation that the QA crops were removed.
```

---

## E4 — Staff roles + admin commands + staff titles

```
FRUITBOUND E4 — STAFF ROLES, SERVER-SIDE ADMIN COMMANDS, OVERHEAD STAFF TAG. Do not publish. Report NOT RUN for any test you did not run.

1. INSPECT
- Common/Utilities/AdminUtility
  - ADMIN_USER_IDS = {419938519} (owner)
  - isAdmin(player): list OR (game.CreatorType == User and player.UserId == game.CreatorId)
- Callers of isAdmin that must keep working:
  - Server/Controllers/Mount onChatted (~403, Chatted hook ~475): !givemount, !mount, !unmount
  - Server/Controllers/WorldEvents onChatted (~128, ~158): !event <id|stop>
  - Common/Utilities/FruitUtility give guard (~169)
  - Server/Controllers/Player admin_only fruit cleanup (~539) and equip (~2563)
  - Client UI/Fruits (~621)
- ReplicatedStorage.Assets.UI.CharacterBillboard (BillboardGui, adornee HumanoidRootPart). Its child frame `Main` (Rank/Coins/Title/HP/Shield) is saved Visible = false and must stay hidden.
- Client/Controllers/Character:_create_billboard (~137): clones it for every player's character on every client; sets Enabled = not egg-opening and no UI open
- Server/Controllers/ChatTitles (publishes the ChatTitle/ChatTitleColor attributes); Client/Controllers/ChatTitles (prefix in the chat window)
- Server/Controllers/Farm.teleport(player, where), FarmingV2.giveSeeds/givePack/_rebuild, Player controller _add_coins, Fishing data (data.fishing.bag)

2. CHANGE
A) AdminUtility (extend, don't replace):
   - ROLES = {TESTER = 1, COMMUNITY_MANAGER = 2, DEVELOPER = 3, OWNER = 4}
   - ROLE_DISPLAY = {OWNER = {text = "OWNER", color = …}, DEVELOPER = {…}, COMMUNITY_MANAGER = {text = "COMMUNITY MANAGER", …}, TESTER = {…}}
   - STAFF = {[419938519] = "OWNER"} — the one place to add staff by UserId. ADMIN_USER_IDS entries are treated as OWNER, and the creator rule also gives OWNER.
   - getRole(player) -> roleName?, level (0 if none). Config only; never data or attributes.
   - isAdmin(player) = level >= ROLES.DEVELOPER. Same people as today unless you add DEVELOPERs.
   - canTarget(actor, target) = level(actor) > level(target), strictly.
   - can(player, permission) using this table:
     - OWNER: all
     - DEVELOPER: info, tp.self, tp.bring, event, mod.kick, mod.mute, test.*, econ.*
     - COMMUNITY_MANAGER: info, tp.self, tp.bring, mod.kick, mod.mute, mod.tempban (≤ 7 days)
     - TESTER: info, tp.self, test.safe
     - mod.ban (permanent) / mod.unban: OWNER only
   - TEST_ENV(): RunService:IsStudio() or game.PrivateServerId ~= ""
B) New Server/Controllers/Staff (register like other controllers, _init/_start):
   - PlayerAdded: player:SetAttribute("StaffRole", roleName or nil). Display only; never read back for permissions.
   - Create ONE TextChatCommand on the server under TextChatService.TextChatCommands (create the folder if missing). Name "FruitBoundStaff", PrimaryAlias "/fb". On Triggered(textSource, text): resolve the player from textSource.UserId, then parse "/fb <cmd> <args>".
     FIRST verify in Studio that Triggered fires on the server. If it doesn't, implement the fallback: RemoteFunction S_Staff_Run(cmdString) with the same parser, plus a tiny client text box shown only when the StaffRole attribute is set.
   - Rate limit 0.5 s per actor. Every command logs print("[Staff]", actor.Name, role, cmd, target or "-").
     Unknown command, or one you lack permission for → private reply only (client notification); never broadcast.
   - Target resolution: unique prefix match on Name or DisplayName, otherwise "ambiguous" / "not found". Any command acting on another player requires canTarget.
   - Commands:
     | Command | Perm |
     | /fb help | info: lists only the commands this role may use |
     | /fb role, /fb whois <p> | info |
     | /fb tp <p> (self → p), /fb farm, /fb village (via Farm.teleport) | tp.self |
     | /fb bring <p> | tp.bring + canTarget |
     | /fb kick <p> [reason] | mod.kick + canTarget |
     | /fb mute <p> / unmute <p> | mod.mute + canTarget: set CanSend on the target's TextSource in every TextChannel; keep a session mute set and reapply on rejoin in the same server |
     | /fb tempban <p> <days 1-7> <reason> | mod.tempban + canTarget: Players:BanAsync, ApplyToUniverse = true |
     | /fb ban <p> <reason> | OWNER only: BanAsync with Duration = -1 |
     | /fb unban <userId> | OWNER only: UnbanAsync |
     | /fb event <id|stop> | event: call the same WorldEvents functions |
     | /fb grow | test.safe, self only, TEST_ENV only: mark own seed_crops mature by setting planted_at back by growth_time, then FarmingV2._rebuild each |
     | /fb seeds <seedId> <n ≤ 50> | test.safe, self, TEST_ENV: FarmingV2.giveSeeds; refuse available == false (Apple) |
     | /fb pack <packId> <n ≤ 10> | test.safe, self, TEST_ENV: FarmingV2.givePack |
     | /fb fish <speciesId> [kg] | test.safe, self, TEST_ENV: insert into data.fishing.bag using the same entry format as Fishing awardFish; respect bag capacity |
     | /fb quests reroll | test.safe, self, TEST_ENV: set quests.daily.t / weekly.t to 0, then regenerate through the existing Player path |
     | /fb floor | test.*, self, TEST_ENV: data garden_floor2 = true, then rebuild the deck via GardenFloor |
     | /fb coins <n ≤ 1e9> | econ.*, self, TEST_ENV: player_controller:_add_coins(n) |
     | /fb setcoins <n> | econ.*, self, TEST_ENV |
     Optional OWNER-only production grant, OFF by default:
     | /fb grant <p> coins <n ≤ 1,000,000> confirm | needs AdminUtility.PRODUCTION_GRANTS = true (default false); logged |
   - Leave the existing ! commands untouched (they keep calling isAdmin).
C) Overhead staff tag, reusing CharacterBillboard:
   - Add one TextLabel "StaffTag" as a DIRECT child of the CharacterBillboard BillboardGui (sibling of Main, NOT inside Main): TextScaled, UIStroke, top-centred, Visible = false by default.
   - In Client/Controllers/Character:_create_billboard, bind that player's "StaffRole" attribute (GetAttributeChangedSignal, cleaned up by the trove): show StaffTag with ROLE_DISPLAY text and color when set, hide otherwise.
   - Raise the tag above the R6 head by setting the billboard StudsOffset (start at 0, 2.6, 0; tune live). Do NOT touch Main.Visible or anything inside Main.
   - If staff tags overlap chat bubbles, set BubbleChatConfiguration.VerticalStudsOffset ≈ 1.5.
D) Chat prefix: in Server/Controllers/ChatTitles.publish, if AdminUtility.getRole(player) returns a role, publish the role text and color as ChatTitle/ChatTitleColor instead of the equipped title. Nothing else in ChatTitles changes.

3. DO NOT CHANGE
- Mount/WorldEvents command handlers, admin_only fruit rules, Titles database
- Main frame visibility or contents of CharacterBillboard; don't create any other overhead BillboardGui
- Save data template (no role fields), economy values, moderation of normal chat

4. BACKWARD COMPATIBILITY
- isAdmin returns true for exactly the same accounts as before (owner list + creator rule) as long as STAFF only contains the owner.
- Existing ! commands still work for the owner.
- Players without a role see no change.

5. SECURITY
- All permission checks run on the server via AdminUtility, never via attributes or client input.
- Roles are never stored in DataStore.
- A role can only act on strictly lower roles; nobody can change roles in game (config only).
- Test/econ commands only for self and only in TEST_ENV (except the optional, OFF-by-default OWNER grant).
- Validate all args (numbers finite, within caps; ids exist).
- Rate limit; log every command; commands are never broadcast in chat.

6. LIVE TEST (Studio Local Server, 3 players; temporarily map Player1 = OWNER, Player2 = COMMUNITY_MANAGER, Player3 = TESTER by putting their Studio test UserIds (negative) into STAFF; remove them afterwards)
a) Verify /fb reaches the server (or the fallback works); "/fb help" output per role
b) Overhead tags on all three, seen from each client; R6 head clearance; Explorer: exactly one CharacterBillboard per player and Main still Visible=false
c) Reset/respawn → tag returns, still a single billboard
d) P3 runs /fb kick Player2 → refused; P2 runs /fb kick Player1 → refused; P2 runs /fb kick Player3 → kicked (rejoin P3); P2 runs /fb mute Player3, P3 chats → not delivered; unmute → delivered
e) P3: /fb seeds clover 3, /fb grow, /fb fish <id> work in Studio; /fb coins 100 refused (TESTER); P1: /fb coins 100 works
f) Simulate a production server: temporarily force TEST_ENV() to return false → every test/econ command refused for every role. Restore it.
g) Owner: !event <id>, !event stop, !givemount, !mount, !unmount still work
h) Chat window shows [OWNER] etc.; bubbles don't overlap tags; normal players see nothing new
i) Rejoin → roles come back from config; inspect profile data: no role/staff fields
j) BanAsync/tempban may not work in Studio — report NOT RUN if so, and do not fake it
k) Output: no errors; [Staff] log lines present

7. PASS IF
All of a–i behave as described, k is clean, and j is reported honestly. The temporary STAFF test IDs and the forced TEST_ENV are reverted.

8. REPORT
- New/changed files with diffs
- The final STAFF config (owner only) and the permission table as implemented
- Whether TextChatCommand.Triggered fired on the server (or which fallback was used)
- Test results a–k as PASS/FAIL/NOT RUN with evidence
- Confirmation that the temporary test changes were reverted
```

---

## E5 — Hold Fish (Carry Fish)

```
FRUITBOUND E5 — CARRY ONE FISH VISUALLY (FISHING BAG STAYS AUTHORITATIVE). Do not publish. Report NOT RUN for any test you did not run.

1. INSPECT
- Server/Controllers/Items: Items.hold/unhold (~89–170), Items._held, HOLD_ANIM, remotes S_Item_Hold/S_Item_Unhold (~275), CharacterRemoving/PlayerRemoving unhold, 0.5 s watcher (~305–318) using owned(data, state.name)
- Client controller that calls Items.hold (search for S_Item_Hold; Client/Controllers/Backpack ~411 calls Items.hold(item.name))
- Server/Controllers/Fishing:
  - awardFish (~553): bag entry = {u = uid, f = speciesId, w = kg, v = coins, q = "perfect"|nil, t = time}
  - sell(player, which) (~904): removes uids once and adds coins
  - Fishing.cast (~465)
  - load/save
- Common/Utilities/FishingUtility (normalize, weightTier, bagCapacity)
- Common/Databases/Fishing (fish species list, RARITIES colors)
- Client/UI/Fishing bag rows (~250–300; the row label at ~272 shows value)
- Client/Controllers/Fishing (the "HOLD TO REEL" button; do not rename it)

2. CHANGE
a) New Common/Utilities/FishModelUtility.build(entry, speciesInfo) -> Model
   - Small procedural fish: body (ellipsoid/ball), tail (wedge), eye
   - Colour from rarity (or species colour if defined); size from FishingUtility.weightTier, clamped to 0.6–1.6 studs long
   - Sparkle only if entry.q == "perfect"
   - PrimaryPart handle; all parts Massless, Anchored = false, CanCollide/CanQuery/CanTouch = false
b) Items:
   - State gets kind = "crop" | "fish". Existing crop calls set kind = "crop".
   - Items.holdFish(player, uid):
     - uid is a string ≤ 20 chars; rate limit (existing ACTION_COOLDOWN)
     - character alive; load data.fishing.bag and find the entry with u == uid, else "missing"
     - If the same fish is already held → unhold
     - Otherwise Items.unhold(player) (one shared slot with crops), build the model, weld exactly like crops
     - Model attributes: FishUid, Species, Weight, Rarity, Value, Perfect
     - player:SetAttribute("HeldItem", "fish:" .. uid)
   - Watcher: for kind == "fish", unhold if the uid is no longer in the bag. Crop branch unchanged.
   - Items.unholdFishIf(player, soldSet): unhold when the held uid is in soldSet (or soldSet == "all").
   - New remote S_Item_HoldFish(uid) → Items.holdFish.
c) Fishing.sell: after save(client, f), call Items.unholdFishIf with the sold uids (or "all"). Use a lazy _L.Get to avoid a require cycle.
   Fishing.cast: unhold a held fish before casting.
d) Client/UI/Fishing bag rows: add a "🐟 Carry" button that becomes "Put away" when HeldItem == "fish:"..uid. It calls the remote and refreshes from the HeldItem attribute. Never label it just "HOLD".

3. DO NOT CHANGE
- Fish values, catch logic, bag capacity, sell prices, quests
- "HOLD TO REEL" button and reel inputs
- Crop hold behaviour
- Trading (fish stay non-tradeable)
- No Tool objects, no Backpack entries

4. BACKWARD COMPATIBILITY
- Existing bag entries work unchanged (no new saved fields)
- Crop hold, gifting, delete and sell keep working
- Old saves load

5. SECURITY
- Server finds the fish by uid in the saved bag; the client sends only the uid
- The visual carries no value; only the bag entry has value
- Sell removes each uid once (existing logic)
- Held state is not saved
- Rate-limited remote; invalid uid → "missing"

6. LIVE TEST (Studio, 2 players)
a) Catch 3 fish (or use /fb fish if E4 is done). Carry fish A → visible in hand, P2 sees it, HeldItem = fish:<uidA>
b) Carry fish B → A disappears, B shown
c) Carry a crop from Backpack → fish disappears; carry fish → crop disappears
d) Sell fish B at Fisher Finn while carrying it → visual gone at once, Coins increase by B's value exactly once, bag count −1
e) Carry A, Sell All → visual gone, Coins correct once
f) Carry a fish, then reset / die / Travel / leave+rejoin → put away; bag unchanged (count before = after)
g) Carry a fish, then cast the rod → put away
h) Exploit check (client command bar): fire S_Item_HoldFish("bogus"), and spam it 20×
i) Phone emulator 667x375: Carry button reachable (≥ 44 px), labels readable
j) Output

7. PASS IF
- Every step behaves as described
- No fish ever duplicated or lost
- Coins credited exactly once per fish
- h is refused without errors
- j has no errors

8. REPORT
Diffs (Items, Fishing, UI/Fishing, new FishModelUtility, client remote caller), a screenshot description of the held fish, bag counts and Coins before/after for d–f, and test results a–j as PASS/FAIL/NOT RUN.
```

---

## E6 — Fence upgrades

```
FRUITBOUND E6 — FENCE TIERS T1–T4 (ONE CONTROLLER, SERVER-AUTHORITATIVE). Do not publish. Report NOT RUN for any test you did not run.

1. INSPECT
- Workspace.__MAP.FarmIsland.Plots.<1..8>: Fence (Folder, ~67 Parts: posts + rails), Base, Sign, SignPostL, SignPostR, Spawn, Built, Pads
- Server/Controllers/Farm:
  - local assign(player) (~217): picks a free plot, plot.model/plot.cf, builds into plot.model.Built
  - local release(player) (~313): clears Built/Pads and resets the sign
  - Farm.buy (~169; spends Coins with data:Set({"stats","Strength"}, coins - cost) after a server check)
  - PLOT_HALF = 70
- Common/Settings data.template (add the new field next to garden_floor2)
- Notification pattern used by Farm/GardenFloor (notify)

2. CHANGE
a) New Common/Databases/Fences:
   {tier = 1, name = "Basic", cost = 0}
   {tier = 2, name = "Reinforced", cost = 150000}
   {tier = 3, name = "Palisade", cost = 2000000}
   {tier = 4, name = "Fortified", cost = 15000000}
   Each tier also gets visual params: color, material, heightScale, cap style.
b) Settings template: fence_tier = 1 (Reconcile fills old profiles).
c) New Server/Controllers/Fence:
   - Fence.apply(plot, tier):
     - On first touch, store each Fence part's original Size, CFrame, Color, Material and Transparency as attributes.
     - Tier 1 = restore the originals exactly.
     - Tiers 2–4 restyle the SAME parts: color/material, and height grown upward from the part's bottom (Size.Y × heightScale, CFrame shifted up by half the growth). Never change X/Z size or X/Z position, so every entrance gap stays identical.
     - Optional decorative caps go in a folder plot.model.FenceTier, rebuilt on every apply and destroyed on tier 1. Caps sit only on top of existing posts and must not block the Sign or SignPosts.
   - Fence.buy(player):
     - Rate limit 1 s; must own a plot (Farm._farms[player])
     - nextTier = clamp(saved fence_tier, 1, 4) + 1; must be ≤ 4
     - Price from the DB only; coins = stats.Strength must be ≥ price
     - Then: data:Set("fence_tier", nextTier), spend coins exactly like Farm.buy, apply, notify
   - Purchase entry: a small sign Part with a ProximityPrompt built into plot.model.Built during assign (Built is cleared on release).
     - ActionText "Upgrade Fence", ObjectText "<Next tier> – <price> Coins", HoldDuration = 1 (acts as the confirmation)
     - Hidden/disabled at T4
     - Triggered → server checks the owner (non-owner gets a notify "Not your farm"), then Fence.buy
   - Hooks:
     - In Farm.assign, after the plot is assigned: Fence.apply(plot, saved fence_tier or 1)
     - In Farm.release, before or after clearing: Fence.apply(plot, 1)
     - Use lazy _L.Get to avoid require cycles.
d) No scripts inside fence parts or plots.

3. DO NOT CHANGE
- FarmUpgrades list/ids/prices, plot size, Base, Sign/SignPosts, Spawn, decor rules
- Economy values other than these four fence prices
- No new currency, no UI framework

4. BACKWARD COMPATIBILITY
- Old profiles get fence_tier = 1 via Reconcile
- A missing or invalid value is treated as 1
- Plots that are already assigned when the controller starts get apply()

5. SECURITY
- Price and tier come only from the server DB
- Client input = the prompt trigger only
- Next-tier-only, no skipping, no downgrades via remotes
- Single charge per purchase (re-check coins and tier at the moment of purchase, no yield between check and set)
- Fence tier is visual only (no gameplay effect)

6. LIVE TEST (Studio, 2 players; /fb coins/setcoins from E4 or the command bar to set Coins)
a) Fresh profile: fence is T1 and identical to before (compare one post's Size/CFrame before/after)
b) setcoins 149,999 → prompt refused; setcoins 150,000 → buy → Coins = 0 exactly, T2 visuals
c) Spam the prompt with enough Coins → only one tier gained per hold, Coins deducted once per tier
d) Buy T3 and T4 → prompt gone at T4
e) Walk in/out through every entrance at T1 and T4 (also as P2, and on the phone emulator)
f) P1 leaves → plot back to exact T1 originals; P2 or a new join takes that plot → T1; P1 rejoins → gets a plot with T4
g) Non-owner triggers another farm's prompt → "Not your farm", nothing charged
h) Output

7. PASS IF
- Every step as described; originals restored exactly
- No entrance blocked; no double charges; tier persists across rejoin
- Output clean

8. REPORT
Diffs/new files, the tier visual params chosen, before/after Size/CFrame values for one post, Coins before/after per purchase, and results a–h as PASS/FAIL/NOT RUN.
```

---

## E7 — Coin icon consistency

```
FRUITBOUND E7 — USE THE HUD COIN ICON FOR COIN AMOUNTS. Do not publish. Report NOT RUN for any test you did not run.

1. INSPECT
- Common/Databases/Stats: Strength.image = "rbxassetid://107803545719047" (display "Coins"). This is the single source.
- HUD reference: StarterGui.Main.Top.Stats.Strength.Icon
- Every 💰 (U+1F4B0) in live scripts:
  - Client/Controllers/GearShop:189
  - Client/UI/Fishing:272, 290, 299, 325, 418
  - Client/Controllers/Decor:327, 372, 413, 467
  - Client/Controllers/Backpack:173(comment), 185, 277, 310, 334, 364, 365, 390, 407, 419
  - Client/Controllers/Guide:32
  - Server/Controllers/Leaderboard:29
  - ServerStorage.FarmBuilder:681
  - Server/Controllers/Farm:137
  - Server/Controllers/GardenFloor:302, 333
  - Common/Databases/UpgradeTree:19
- Also search for price texts that end in " Coins" with no icon (SeedShop, Confirm dialog, farm upgrade pads).

2. CHANGE
a) New Common/Utilities/CoinIconUtility:
   - ICON read from Databases/Stats
   - CoinIconUtility.attach(textLabel): inserts a square ImageLabel (the icon) to the left of the text inside a horizontal UIListLayout wrapper, keeping the label's Size/Position/AnchorPoint and TextScaled behaviour. Returns a setter for the text.
   - Works in ScreenGui, BillboardGui and SurfaceGui.
b) Replace 💰 with the icon ONLY where it shows a Coin amount or price:
   - GearShop:189 (price button)
   - UI/Fishing:272 (fish value), 325 (bait price), 418 (rod/cosmetic price)
   - Decor:372 and 413 (coin balance), 467 (price)
   - Backpack:390 ("Worth"), 407 (row worth)
   - FarmBuilder:681 and Farm:137 (upgrade price signs)
   - GardenFloor:302 and 333 (floor price)
   - Leaderboard:29 (title), only if the board layout allows
c) Keep the text emoji (unchanged):
   - Notifications: Backpack:334, UI/Fishing:290 and 299, Decor:327
   - Hints: Backpack:364, 365
   - Guide:32 step title
   - UpgradeTree:19 node icon
   - Action buttons: Backpack:185 "SELL", 310 "SELL ALL", 419 row sell button. Optional: only change them if you also change all three consistently.

3. DO NOT CHANGE
- Any value/price/number formatting
- Robux icons, Gem icons, Store artwork (StarterGui.Store…Strength_* art)
- UIBackup_BeforeTheme
- Notification/chat text

4. BACKWARD COMPATIBILITY
Pure UI. Texts that other code reads or updates (e.g. coinsLabel.Text updates in Decor) must keep updating through the setter.

5. SECURITY
None (client visuals). No remotes.

6. LIVE TEST (Studio Play, desktop and device emulator 667x375)
a) Open each changed spot: Gear Shop, Fishing bag + bait + rods, Decor panel + item cards, Backpack worth + rows, every farm upgrade sign, Second Floor sale sign, leaderboard
b) Buy one item in each shop → numbers update correctly next to the icon
c) Check the unchanged spots still show their emoji
d) Output

7. PASS IF
Icon identical to the HUD coin everywhere it was replaced, aligned with the text, readable at 667x375. No numbers changed, nothing overflowing, Output clean.

8. REPORT
List of every replaced location (file:line → widget), every location deliberately kept, diffs, per-screen PASS/FAIL/NOT RUN, and anything that clipped on mobile.
```

---

## E8 — Second Floor expansion

```
FRUITBOUND E8 — SECOND FLOOR EXPANSION. Do not publish. Report NOT RUN for any test you did not run.
PRECONDITION: E3 is merged and its tests passed. If not, STOP and say so.
TWO PHASES. Do Phase A only, then STOP and wait. Only do Phase B if my message contains "E8 APPROVED" with the numbers.

1. INSPECT
- Common/Databases/GardenFloor: HEIGHT, deck, opening, beds, lift, pillars, PILLAR_SIZE, COST; Y values derived from HEIGHT after E3
- Server/Controllers/GardenFloor: buildDeck (~180), buildSaleSign (~287), buy (~347), ride (~393)
- Server/Controllers/Farm: PLOT_HALF = 70 (plots 140x140), blockedRects (~390, uses lift/pillars)
- Common/Databases/FarmUpgrades: `at` and `soil` of every upgrade
- ServerStorage.FarmBuilder: heights of the buildings it makes (windmill, barn, greenhouse, fountain, gate, helper huts, trees, scarecrow)
- Server/Controllers/Player:_auto_collect_tick: AUTO_FARM_HALF = 70, |rel.Y| <= 40
- Server/Controllers/Harvest.findNearest: dy < 15

2. CHANGE
PHASE A (measure only, no edits):
- In a Studio Play session with a test profile that owns every FarmUpgrade and the floor, run a command-bar script that, in plot space (plot.cf:PointToObjectSpace):
  - lists the max top Y and the XZ footprint of every child of plot.model.Built (by upgrade) and of the deck parts
  - reports the plot bounds
- Propose:
  - deck rect (target ≈ 124x118) and HEIGHT (target ≈ +23) so the underside clears every building
  - opening(s)/skylights so ground crops stay visible and tappable, or the reason none are needed
  - new beds, lift position, pillar positions avoiding all soil, paths and entrance
- STOP and report.
PHASE B (after "E8 APPROVED"):
- Update only Databases/GardenFloor with the approved numbers
- Adjust GardenFloor.buildDeck only if the new opening/pillar shapes need it (keep its style)
- Pillars must not stand on ground soil or block the entrance

3. DO NOT CHANGE
- E3 floor logic, saved data, COST (unless I approve a price), FarmUpgrades, plot size
- Auto Collect/Harvest constants, unless a measurement proves the deck is out of range (then propose, don't change)

4. BACKWARD COMPATIBILITY
- Existing deck crops (floor = 2) whose x/z is no longer inside a new bed: they must still rebuild on the deck (E3 fallback) and stay harvestable. List how many exist in the test profile and where they end up.
- No migration.

5. SECURITY
Planting is still validated server-side against GardenFloor.beds.

6. LIVE TEST (Phase B, Studio, 2 players, fully upgraded test profile)
a) Deck renders at the approved height and nothing clips through it (walk around every building)
b) Lift up/down; respawn on the deck
c) Plant on every new bed; plant a ground crop exactly under a deck crop; leave/rejoin
d) Old deck crops from before the expansion: where they are, still harvestable once
e) Auto Collect on the deck and on the ground
f) Water/fertilize deck crops
g) Ground crops under the deck can still be seen/tapped (desktop and phone emulator)
h) Decor placement near pillars refused, elsewhere fine
i) Output

7. PASS IF
- a–i all as described
- Each crop stays on its own floor after rejoin
- No clipping, no blocked entrance, Output clean

8. REPORT
Phase A: the measurement table and the proposal, then STOP.
Phase B: diffs, final numbers, and test results a–i as PASS/FAIL/NOT RUN with evidence.
```

---

## E9 — Mobile + onboarding

```
FRUITBOUND E9 — MOBILE LAYOUT FIXES (ONLY WHAT FAILS) + TWO ONBOARDING TEXT TWEAKS. Do not publish. Report NOT RUN for any test you did not run.

1. INSPECT
- Client/Controllers/GearShop (window = fromScale(0.6, 0.62), no UIScale; ~400x232 px at 667x375)
- Client/UI/Fishing (main 0.92x0.82, 36 px header, 52 px close)
- Client/Controllers/Fishing HUD ("HOLD TO REEL" at Position (0.5, 0, 1, -110))
- Client/UI/Daycare (0.9x0.78, grid cells 150x172)
- Client/UI/Quests + StarterGui.Quests.Main (no UIScale)
- Garden upgrade pads / Second Floor sale sign / Fence prompt (world prompts)
- Carry Fish button (E5), staff tag + bubbles (E1/E4)
- Panels that already fit via UIScale (StarterSelect, FruitBook, Mounts, Decor, Backpack, SeedShop, NPCDialogue): verify only
- Client/Controllers/Goals GOALS list: "Buy a Watering Can", "Catch 5 fish", "Catch 25 fish", "Buy Pruning Shears"
- Client/Controllers/Guide STEPS (do not change)

2. CHANGE
A) Mobile:
   - First, test every panel in the device emulator at 667x375 landscape (plus one real phone if available) and list which ones clip, overflow, or hide close buttons.
   - Fix ONLY those:
     - On small viewports (workspace.CurrentCamera.ViewportSize.Y < 500), scale to fit (e.g. GearShop window fromScale(0.92, 0.88))
     - Add a ScrollingFrame with AutomaticCanvasSize where rows overflow
     - Make tap targets ≥ 44 px
     - Move "HOLD TO REEL" up if it collides with the jump button/bottom bar
   - Desktop layout must look the same as before.
B) Onboarding: change only these Goals texts:
   - "Buy a Watering Can" → "Buy a Watering Can at the Gear Shop"
   - "Buy Pruning Shears" → "Buy Pruning Shears at the Gear Shop"
   - "Catch 5 fish" → "Catch 5 fish at Fisher Finn's stall"
   - "Catch 25 fish" → "Catch 25 fish at Fisher Finn's stall"
   No new Guide steps, no tutorial NPC, no Guide changes.

3. DO NOT CHANGE
Gameplay, prices, the Guide tutorial steps, UI themes/colors, panels that already pass.

4. BACKWARD COMPATIBILITY
Desktop unchanged; goal ids/order/thresholds unchanged (text only).

5. SECURITY
Client-only UI. No remotes.

6. LIVE TEST
a) Device emulator 667x375, open and use each of:
   - Seed Packs, Gear Shop (buy one), Fishing (all tabs, sell, bait, rods), HOLD TO REEL during a catch
   - Hatching, Daycare, Quests (claim), Garden Upgrade pads, Second Floor sign + lift, Fence prompt
   - NPC dialogue, Carry Fish, Backpack, Fruits, Trade request, Settings, More menu
b) Same panels on desktop 1920x1080 → unchanged
c) Fresh profile, 10 minutes, no admin commands:
   - 0–3 min: harvest the starter crop, sell, buy the Starter pack, plant (ready ≤ 60 s)
   - 3–6 min: harvest, hatch, equip
   - 6–10 min: follow Goals to the Gear Shop and Fisher Finn
   Note every point of confusion.
d) Output

7. PASS IF
- Every panel usable at 667x375: close button visible, no clipped buttons, text readable
- Desktop unchanged
- The fresh player reaches the Gear Shop and Finn using only the Goals text
- Output clean

8. REPORT
Before/after list per panel (PASS/FAIL), diffs, the onboarding timeline with timestamps and confusion notes, and anything left FAIL with the reason.
```

---

## E10 — Seven crops + economy + final release QA

```
FRUITBOUND E10 — VALIDATION ONLY: SEVEN NEW CROPS, ECONOMY SESSION, FINAL RELEASE QA. Do not publish. Do NOT fix anything during this pass; list failures. Report NOT RUN for anything not actually run.

1. INSPECT (read only)
- Common/Databases/SeedPacks: Seeds (golden_corn, blossom_berry, river_melon, crystal_bean, dragon_pepper, moonberry, dragon_fruit), Packs, CROP_ASSETS, SIZE_ROLLS, VISUAL_SCALE_MAX = 3, getWeight / getSellValue
- ReplicatedStorage.Assets.Crops.<DragonFruit|Moonberry|GoldenCorn|BlossomBerry|DragonPepper|CrystalBean|RiverMelon>.Mature (Stage1–3 are procedural PlantBuilder models)
- Common/Utilities/CropModelUtility (Backpack hold model)
- Common/Settings data.mock (must be false) and data.key (must stay "Player_Data_002")
- Expected values:
  | crop | growth | base kg | base value | pack (chance) |
  |---|---|---|---|---|
  | golden_corn | 30m | 1.5 | 420 | Harvest (10%) |
  | blossom_berry | 40m | 0.5 | 500 | Woodland (10%) |
  | river_melon | 45m | 4.5 | 550 | Golden Grove (15%) |
  | crystal_bean | 50m | 0.8 | 600 | Enchanted (15%) |
  | dragon_pepper | 60m | 1.0 | 760 | Golden Grove (20%), Enchanted (30%) |
  | moonberry | 75m | 0.7 | 920 | Enchanted (25%) |
  | dragon_fruit | 90m | 1.2 | 1200 | Enchanted (5%) |
  weight = base kg × size²; sell = base value × weight / base kg (× farm bonuses).
  Every pack's odds must sum to 100. No Mythical Garden pack. Apple seed available = false.

2. CHANGE
None. Validation only.

3. DO NOT CHANGE
Anything. No pack prices, odds, crop values or models during this pass.

4. BACKWARD COMPATIBILITY
Use a returning profile (the main account) and a fresh profile.

5. SECURITY
Use E4 test commands only in Studio/private servers. Remove any QA data afterwards.

6. LIVE TEST
A) Seven crops (per crop: /fb seeds <id> 3 then /fb grow, and one crop grown naturally on fast-forward or real time):
   - Stage1 → Stage2 → Stage3 → Mature: no jarring jump in size/colour at the switch to the custom Mature model
   - Mature scale vs neighbours; upright; grounded (not floating or buried); on ground soil AND on the deck
   - Big/Huge/Giant rolls and overgrowth up to the visual cap look sane
   - Harvest → exactly 1 item; weight and value match the table
   - Backpack ✋ Hold shows the right model upright
   - Phone emulator tap-to-harvest works
   - Leave/rejoin while growing and while mature → same stage/size, harvestable once
B) Economy (fresh profile, 20–30 min real play, no commands):
   - Record Coins at 0/5/10/15/20/25/30 min
   - Record when you first: buy a pack, hatch an egg, buy a Gear, buy each Farm upgrade, catch fish, complete a quest
   - BLOCKER only if: the Starter pack is unaffordable after the first sell, or there is no affordable progress for > 5 min. Otherwise just report, don't rebalance.
C) Final release QA:
   - Fresh profile: tutorial end-to-end
   - Returning profile: crops, Fruits, fishing bag, garden_floor2, fence_tier, wild_captures, quests intact
   - Respawn in Farm, Village, Fishing spot, deck
   - Rejoin ×2 (data identical)
   - Save: leave → rejoin in a new server (Team Test or private test place)
   - Mobile pass (E9 list), quests (E2), fishing loop + Carry (E5), fence (E6), Second Floor (E3/E8), staff (E4), Bubble Chat (E1)
   - Output (server + client): no red errors, no Infinite yield
   - print(Settings.data.mock) == false
   - No temp/QA objects: search Workspace/ReplicatedStorage/StarterGui/ServerScriptService for names containing QA/Test/Debug/Temp/Copy, and leftover qa_* crops in test profiles
   - Apple seed unobtainable; Mythical Garden absent; Helper coin generation absent

7. PASS IF
Every row PASS. Any FAIL is listed with exact reproduction steps.

8. REPORT
- A table: crop × check → PASS/FAIL/NOT RUN with a screenshot description or Output line
- The economy log with timestamps and Coins
- The final QA checklist with PASS/FAIL/NOT RUN per line
- A final verdict: READY TO PUBLISH (only if everything passed) or NOT READY + the blocking lines
- Do not publish
```
