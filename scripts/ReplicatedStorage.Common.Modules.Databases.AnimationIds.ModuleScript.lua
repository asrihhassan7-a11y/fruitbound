--> AnimationIds - paste your own published Roblox Animation IDs here
-- ============================================================
-- Each value is an Animation asset id: "rbxassetid://1234567890" or just "1234567890".
-- Leave it "" to keep the built-in procedural animation (Client.Modules.Classes.AnimationPack).
-- An ID that fails to load (wrong id, not owned by this game's creator / group, not published)
-- also falls back to the built-in animation automatically, so a bad ID never breaks anything.
--
-- RIGS (animate these exact part names in the Animation Editor):
--   Deer / mounts : Root -> Body          (the Forest Deer's existing Motor6D "BodyJoint")
--   Fruits        : Root -> Handle        (Motor6D "RootJoint", added automatically to every
--                                          Fruit follower as soon as any Fruit ID below is set)
-- Fruits and the Forest Deer are single meshes: they can only move as a whole body
-- (bounce, tilt, sway, lean). There are no separate legs, arms, heads or ears to animate.
--
-- Loops (Idle / Walk / Run / Sleep) are played looped; the others play once.
-- Mount one-shots without a Deer ID use the Mount ID (MountStart...), then the built-in clip.
-- ============================================================

return {
	-- Forest Deer (MountsDB anim_set = "Deer")
	DeerIdleAnimationId = "",
	DeerWalkAnimationId = "",
	DeerRunAnimationId = "",
	DeerJumpAnimationId = "",
	DeerLandAnimationId = "",
	DeerStartAnimationId = "", -- optional: starts moving
	DeerStopAnimationId = "", -- optional: stops moving
	DeerCelebrateAnimationId = "", -- optional: right after hopping on

	-- Any mount (also the fallback for a Deer action left empty above)
	MountIdleAnimationId = "",
	MountWalkAnimationId = "",
	MountRunAnimationId = "",
	MountJumpAnimationId = "",
	MountLandAnimationId = "",
	MountStartAnimationId = "",
	MountStopAnimationId = "",
	MountCelebrateAnimationId = "",

	-- Fruit followers (one set for every Fruit)
	FruitIdleAnimationId = "",
	FruitWalkAnimationId = "",
	FruitRunAnimationId = "",
	FruitHappyAnimationId = "", -- hatched / equipped, level up, evolve
	FruitSleepAnimationId = "", -- optional: player idle 45 s
	FruitSurprisedAnimationId = "", -- optional: woken up
}
