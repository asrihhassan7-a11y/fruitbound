# FruitBound Animation Pack

20 clips, one `KeyframeSequence` per file (`Insert > Insert from File…` in Studio, then the Animation Editor can open / publish them).
The **game already plays every clip from code** (`StarterPlayer.StarterPlayerScripts.Client.Modules.Classes.AnimationPack`), so nothing has to be uploaded for them to work in-game. These files are the same curves, sampled at 30 fps.

## Rigs
FruitBound's fruits and the Forest Deer are **rigid single meshes**: nothing is re-rigged, scaled or deformed, so each clip is one track on the whole body.

| Clips | Target | Pose path |
|---|---|---|
| `Mount_*`, `Deer_*` | `Assets.Models.Mounts["Forest Deer"]` (Motor6D `BodyJoint`, Root → Body) | `Root` › `Body` |
| `Fruit_*` | a fruit `Handle` (in-game: offset on the fruit's CFrame, pivot at its base) | `Root` › `Handle` — only for a fruit rigged with a `Root` part + Motor6D (Root → Handle); exported for a 4-stud fruit (Apple) |

No root motion: Roblox / the follow code moves the character, the clips only add the body offset.
Mount clips rotate around the saddle and the rider is welded to `Root`; each key is lifted just enough that the rigid body never pushes a hoof below the ground. The seat moves at most 0.07 studs walking and 0.20 studs galloping.

## Clips
| Clip | Loop | Length | Plays when |
|---|---|---|---|
| Fruit_Idle | ✔ | 2.4 s | following fruit stands still |
| Fruit_Walk | ✔ | 0.6 s | player walks (step speed follows player speed) |
| Fruit_Run | ✔ | 0.56 s | player faster than 20 studs/s (riding, boosts) or fruits rushing to a harvest |
| Fruit_Happy | | 1.3 s | fruit hatched / equipped, levels up or evolves |
| Fruit_Interact | | 1.2 s | "Feed / Stats" prompt on a pen fruit (it turns to you first) |
| Fruit_Sleep | ✔ | 4.0 s | player still for 45 s (eyes close) |
| Fruit_Surprised | | 0.7 s | player moves again while the fruits sleep |
| Mount_Idle / Walk / Run | ✔ | 4.0 / 1.0 / 0.8 s | generic mounts (blended by speed; walk / run synced to the stride) |
| Mount_Start / Stop | | 0.6 / 0.7 s | starts moving / stops after ≥ 0.5 s of moving |
| Mount_Jump / Land | | 0.6 / 0.5 s | rider jumps / lands after ≥ 0.25 s in the air |
| Mount_Celebrate | | 1.6 s | right after hopping on |
| Deer_Idle / Walk / Run / Jump / Land | ✔✔✔ / | 4.5 / 1.0 / 0.8 / 0.65 / 0.5 s | Forest Deer (`anim_set = "Deer"`); Start / Stop / Celebrate fall back to `Mount_*` |

Tuning lives in the clip keys in `AnimationPack` (studs / degrees); the files here can be regenerated from it.

## Using your own uploaded animations
Paste published Animation IDs in **`ReplicatedStorage.Common.Modules.Databases.AnimationIds`**, for example `DeerWalkAnimationId = "rbxassetid://1234567890"`. A plain number also works.

- **ID set and loaded:** that action plays your `AnimationTrack`.
- **Empty, or the ID fails to load:** the built-in AnimationPack clip plays. This is decided per action.
- **Ownership:** the animation must be published by the game's owner (you or your group), or Roblox won't load it.
- **Deer rig:** `Root` › `Body` (existing Motor6D `BodyJoint`). The rider stays welded to `Root`.
- **Fruit rig:** `Root` › `Handle` (Motor6D `RootJoint`). It is added automatically to every Fruit follower only when at least one Fruit ID is set. The files above (`Fruit_*.rbxmx`) already use these names, so you can open them in the Animation Editor on a rigged fruit, publish, and paste the ID.
- **Single meshes:** Fruits and the Forest Deer can only move as a whole body. There are no separate limbs.
