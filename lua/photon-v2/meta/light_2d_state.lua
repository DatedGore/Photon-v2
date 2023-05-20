if (exmeta.ReloadFile()) then return end

NAME = "PhotonLight2DState"
BASE = "PhotonLightState"

---@class PhotonLight2DState : PhotonLightState
---@field SingleSourceColor Color Source color for lights that use a *single* 2D source material.
---@field SourceFillColor Color Base color used for the fill material on Fill/Detail-configured lights.
---@field SourceDetailColor Color Detail/overlay color used for the detail material on Fill/Detail-configured lights.
---@field GlowColor Color
local State = exmeta.New()

State.SourceFillColor = nil
State.SourceDetailColor = nil

function State.New( self, name, data, collection )
	return PhotonLightState.New( PhotonLight2DState, name, data, collection )
end