--> Variables
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Common = require(ReplicatedStorage.Common)

local _L = require(ReplicatedStorage.Loader)

--> Constants

---------->
_G._L = _L

_L.Assets = ReplicatedStorage.Assets
_L.Storage = ReplicatedStorage.Storage
_L.Map = workspace.__MAP
_L.Debris = workspace.__DEBRIS

_L.Player = Players.LocalPlayer
_L.PlayerGui = Players.LocalPlayer.PlayerGui

Common._init()

_L._start { instance = script }
