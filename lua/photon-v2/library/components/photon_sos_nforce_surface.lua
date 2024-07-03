if (Photon2.ReloadComponentFile()) then return end
local COMPONENT = Photon2.LibraryComponent()

COMPONENT.Author = "Photon"

COMPONENT.Credits = {
	Model = "SGM",
	Code = "SGM"
}

COMPONENT.Title = [[SoundOff Signal nForce Surface Mount]]
COMPONENT.Category = "Perimeter"
COMPONENT.Model = "models/sentry/props/nforce_18.mdl"

COMPONENT.Preview = {
	Position = Vector(),
	Angles = Angle( 0, 180, 0 ),
	Zoom = 3
}

COMPONENT.DefineOptions = {
	Marker = {
		Arguments = { [1] = { "enabled", "boolean" } },
		Description = "Enable or disable the marker light.",
		Action = function( self, enabled )
			if ( not enabled ) then
				self.Inputs["Emergency.Marker"]["ON"] = {}
			end
		end
	}
}

COMPONENT.States = {
	[1] = "R",
	[2] = "B",
	[3] = "W"
}

local s = 1.6

COMPONENT.Templates = {
	["2D"] = {
		Light = {
			Shape = PhotonMaterial.GenerateLightQuad("photon/lights/sos_nforce_main_shape.png").MaterialName,
			Detail = PhotonMaterial.GenerateLightQuad("photon/lights/sos_nforce_main_detail.png").MaterialName,
			Width = 11.5,
			Height = -9.5,
			Ratio = 2.4,
			Scale = 1.2,
			ForwardVisibilityOffset = -0.1,
			ForwardBloomOffset = 0.5,
			LightMatrix = { Vector(s, 0, 0), Vector(-s, 0, 0),  },
			LightMatrixScaleMultiplier = 1,
		},
	}
}

COMPONENT.StateMap = "[1/2/3] 1"

COMPONENT.Elements = {
	[1] = { "Light", Vector(0, 1.3, 0.02), Angle(0, 0, 0) },
}

local sequence = Photon2.SequenceBuilder.New

COMPONENT.Segments = {
	Light = {
		Frames = {
			[1] = "[1] 1",
			[2] = "[2] 1",
			[3] = "[3] 1",
			[4] = "[W] 1",
			[5] = "[R] 1"
			-- [1] = { { 1, 4 } },
		},
		Sequences = {
			["TEST"] = { 
				1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
				2, 2, 2, 0, 0, 0, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0,
				3, 3, 0, 3, 3, 0, 3, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0,
			},
			["MODE1"] = { 1 },
			["W"] = { 4 },
			["R"] = { 5 },
			["1"] = { 1 },
			["2"] = { 2 },
			["3"] = { 3 },
			["DUO_ALT_MED"] = sequence():Alternate( 1, 2, 8 ),
			["TRI_FLASH_SOLO"] = sequence():Add( 1, 1, 0, 1, 1, 0, 1, 1 ):AppendPhaseGap(),
			["DUO_FLASH"] = sequence():FlashHold( { 1, 0, 2, 0 }, 3, 1 )
		}
	},
	-- Using a different segment for overriding keeps the flash pattern synchronized
	-- when the override is removed.
	Override = {
		Frames = {
			[1] = "[1] 1",
			[2] = "[2] 1",
			[3] = "[3] 1",
			[4] = "[W] 1",
			[5] = "[R] 1"
		},
		Sequences = {
			["W"] = { 4 },
			["R"] = { 5 },
		}
	}
}

COMPONENT.Patterns = {
	["R"] = { { "Override", "R" } },
	["W"] = { { "Override", "W" } },
	["DUO_FLASH"] = { { "Light", "DUO_FLASH" } }
}

COMPONENT.Inputs = {
	["Emergency.Warning"] = {
		["MODE1"] = {
			Light = { 1 }
		},
		["MODE2"] = {
			Light = "TRI_FLASH_SOLO"
		},
		["MODE3"] = {
			Light = "TRI_FLASH_SOLO"
		}
	},
	["Emergency.Marker"] = {
		["ON"] = {
			Light = "1"
		}
	}
}