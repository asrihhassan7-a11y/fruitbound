--> Variables
local _L = _G._L

--> Constants

---------->
-- required = real crops harvested (stats.Crops_Harvested) = ceil(legacy_required / 6).
-- legacy_required = the old threshold on stats.Kills (6 items per crop); only the one-time crop
-- progression migration reads it, to keep every player's rank (RankUtility, crop_legacy.rank).
return {
	{
		name= "Rookie",
		required = 0, legacy_required = 0,
	};

	{
		name= "Beginner",
		required = 1, legacy_required = 5,
	};

	{
		name= "Trainee",
		required = 2, legacy_required = 10,
	};

	{
		name= "Voyager",
		required = 4, legacy_required = 20,
	};

	{
		name= "Adept",
		required = 9, legacy_required = 50,
	};

	{
		name= "Champion",
		required = 13, legacy_required = 75,
	};

	{
		name= "Supreme Champion",
		required = 17, legacy_required = 100,
	};

	{
		name= "Mental Master",
		required = 21, legacy_required = 125,
	};

	{
		name= "Legendary Ruler",
		required = 25, legacy_required = 150,
	};

	{
		name= "Divine Ruler",
		required = 30, legacy_required = 175,
	};

	{
		name= "Eternal Monarch",
		required = 34, legacy_required = 200,
	};

	{
		name= "Heavenly Titan",
		required = 59, legacy_required = 350,
	};

	{
		name= "Interdimensional Emperor",
		required = 75, legacy_required = 450,
	};

	{
		name= "Master Supreme",
		required = 100, legacy_required = 600,
	};

	{
		name= "Cosmic Sovereign",
		required = 167, legacy_required = 1000,
	};

	{
		name= "Omnipotent Sovereign",
		required = 250, legacy_required = 1500,
	};

	{
		name= "Transcendent Being",
		required = 292, legacy_required = 1750,
	};

	{
		name= "Quantum Ascendant",
		required = 584, legacy_required = 3500,
	};

	{
		name= "Temporal Paragon",
		required = 834, legacy_required = 5000,
	};

	{
		name= "Infinite Nexus",
		required = 1250, legacy_required = 7500,
	};

	{
		name= "Primordial Singularity",
		required = 1667, legacy_required = 10000,
	};
	
	{
		name= "Limitless Neophyte",
		required = 2084, legacy_required = 12500,
	};
	
	{
		name= "Luminary Oracle",
		required = 2500, legacy_required = 15000,
	};
	
	{
		name= "Universal Sage",
		required = 2917, legacy_required = 17500,
	};
}