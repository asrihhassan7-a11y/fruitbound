# Crop system: size, weight & overgrowth

The changes are 8 scripts, packaged in `CropUpdate.rbxmx`. The source of each script is also in `scripts/`.
`here.rbxl` is your original place, unchanged.

## Install into your place
1. Open your place in Studio and close any open script tabs.
2. Right-click **Workspace** → **Insert from File...** → pick `CropUpdate.rbxmx`.
3. Open **View → Command Bar**, paste this line and press Enter:

```lua
local f=game:FindFirstChild("CropUpdate",true) for _,s in f:GetChildren() do local t=game for n in s.Name:gmatch("[^/]+") do t=t and t:FindFirstChild(n) end if t and t:IsA("ModuleScript") then t.Source=s.Source print("updated "..t:GetFullName()) else warn("not found: "..s.Name) end end f:Destroy()
```

4. The Output window should show 8 `updated` lines. Then save (Ctrl+S).

## How it works
- **One plant per crop.** Every Seed you plant is its own single plant (one carrot, one sunflower,
  one mushroom...) with its own model at every growth stage: sprout → young plant → small crop → mature.
  Built in `ServerStorage.PlantBuilder` (`PlantBuilder.buildCrop`).
- **Size roll.** When planted, each crop rolls its own size: Normal 70% (x0.85–1.1), Big 22% (x1.1–1.3),
  Huge 6% (x1.3–1.6), Giant 2% (x1.6–2).
- **Overgrowth.** Once a crop is ready it keeps growing until you harvest it, with no timer and also
  while you're offline. It grows fast at first, then slower (15m x1.21, 1h x1.48, 1 day x2.37,
  1 week x2.95, and it never stops). Models stop getting visibly bigger at x3, but the weight keeps going up.
- **Weight.** `weight = base_weight × size²` (kg). Base weights: Clover 0.25, Mint 0.35, Carrot 0.6,
  Sunflower 1.8, Glow Mushroom 3.2.
- **Value.** Each crop item sells for `sell_value × weight / base_weight`, so a crop twice as heavy is
  worth twice the Coins.
- **Leaderboard.** New "⚖️ Heaviest Crop" category on the Village board: the heaviest crop each player
  ever grew (saved in `heaviest_crop`). Harvesting shows the weight and says when it's your heaviest ever.
- **Labels.** Your mature crops show their weight. Other players' mature crops show theirs too, so you
  can compare.

## Tuning (ReplicatedStorage.Common.Modules.Databases.SeedPacks)
`SIZE_ROLLS`, `OVERGROW_RATE`, `OVERGROW_PERIOD`, `VISUAL_SCALE_MAX`, and `base_weight` per Seed.

Crops planted before this update start at normal size and begin overgrowing from the moment they
mature, or from when you rejoin if they're already mature. Old saves don't get instant giants.
