if (exmeta.ReloadFile()) then return end

NAME = "PhotonLightingSegment"

local print = Photon2.Debug.Print
local printf = Photon2.Debug.PrintF

---@class PhotonLightingSegment
---@field ActivePattern string Name of the current active pattern.
---@field IsActive boolean Whether the segment is active.
---@field CurrentPriorityScore integer
---@field LastFrameTime integer
---@field CurrentModes table<string, string> Key = Channel, Value = mode
---@field InputPriorities table<string, integer>
---@field Sequences table<string, PhotonSequence>
---@field Component PhotonLightingComponent
-- [string] = Pattern Name
---@field Patterns table<string, string> Key = Input Channel, Value = Associated sequence
---@field Frames table<integer, table> 
---@field InitializedFrames table<integer, table<PhotonLight, string>>
---@field Lights table Points to Component.Lights
local Segment = exmeta.New()

Segment.Patterns = {}
Segment.InputPriorities = {}
Segment.Count = 0
Segment.FrameDuration = 0.64
Segment.LastFrameTime = 0
Segment.InputPriorities = PhotonBaseEntity.DefaultInputPriorities

-- On compile
---@param segmentData any
---@param lightGroups table<string, integer[]>
---@return PhotonLightingSegment
function Segment.New( segmentData, lightGroups )

	---@type PhotonLightingSegment
	local segment = {
		Lights = {},
		Sequences = {},
		Frames = {},
		Patterns = {}
	}

	setmetatable(segment, { __index = PhotonLightingSegment })

	local function flattenFrame( frame )
		local result = {}
		for i=1, #frame do
			local key = frame[i][1]
			local value = frame[i][2]
			if isstring(key) then
				local group = lightGroups[key]
				if ( not group ) then
					error( string.format( "Undefined LightGroup [%s] in segment.", key ) )
				end
				for _i=1, #group do
					result[group[_i]] = value
				end
			else
				result[key] = value
			end
		end
		return result
	end

	local function rebuildFrame (flatFrame )
		local result = {}
		for k, v in pairs(flatFrame) do
			result[#result+1] = { k, v }
		end
		return result
	end

	local function processFrameString( frame )
		local result = {}
		local lights = string.Split( frame, " " )
		for i=1, #lights do
			local lightData = string.Split(lights[i], ":")
			
			local insert
			
			if (#lightData == 1) then
				insert = (tonumber(lightData[1]) or lightData[1])
			else
				insert = { (tonumber(lightData[1]) or lightData[1]), (tonumber(lightData[2]) or lightData[2]) }
			end

			if (insert) then
				result[#result+1] = insert
			else
				error("Frame string [" .. tostring(frame) .."] could not be parsed.")
			end
		end
		return result
	end

	local function buildZeroFrame( frames )
		local usedLights = {}
		local returnFrame = {}
		-- Get all used lights
		for frameIndex = 1, #frames do
			local frame = frames[frameIndex]
			for stateIndex = 1, #frame do
				if ( isstring(frame[stateIndex][1]) ) then
					local group = lightGroups[frame[stateIndex][1]]
					if ( not group ) then 
						error( string.format( "Light group name is not valid %s", frame[stateIndex][1] ) )
					end
					for i=1, #group do
						usedLights[group[i]] = true
					end
				else
					usedLights[frame[stateIndex][1]] = true
				end
			end
		end
		-- Build 0 frame
		for light, _ in pairs( usedLights ) do
			returnFrame[#returnFrame+1] = { light, "OFF" }
		end
		return returnFrame
	end

	-- TODO: FS white override will conflict with
	-- OFF taking priority - a "no off" option is needed

	local processedFrames = {}

	for i=1, #segmentData.Frames do
		local inputFrame = segmentData.Frames[i]
		
		if (isstring(inputFrame)) then
			inputFrame = processFrameString( inputFrame )
		end
		
		local resultFrame = {}
		
		-- Iterate over each light-state in frame
		for k, v in pairs( inputFrame ) do
			if ( isnumber(v) ) then
				resultFrame[#resultFrame+1] = { v, 1 }
			elseif ( istable(v) ) then
				resultFrame[#resultFrame+1] = v
			elseif ( isstring(v) ) then
				resultFrame[#resultFrame+1] = { v, 1 }
			else
				error("Invalid light-state in frame #" .. tostring(i))
			end
		end
		
		processedFrames[i] = resultFrame

		
	end

	-- Add zero frame (i.e. segment default state)
	if ( not segmentData.Frames[0] ) then
		processedFrames[0] = buildZeroFrame( processedFrames )
	elseif ( isstring(segmentData.Frames[0] ) ) then
		processedFrames[0] = processFrameString( segmentData.Frames[0] )
	else
		processedFrames[0] = segmentData.Frames[0]
	end

	segment:AddFrame( 0, processedFrames[0] )
	local zeroFrame = flattenFrame( processedFrames[0] )

	-- Merges the OFF/default frame to ensure lights reset in the segment
	for i=1, #processedFrames do
		local copyTo = table.Copy( zeroFrame )
		local flatFrame = flattenFrame( processedFrames[i] )
		table.Merge( copyTo, flatFrame )
		segment:AddFrame( i, rebuildFrame( copyTo ) )
	end
	
	-- Add sequences
	for sequenceName, frameSequence in pairs( segmentData.Sequences ) do
		segment:AddNewSequence( sequenceName, frameSequence )
	end

	return segment
end

-- On instance creation
---@param componentInstance PhotonLightingComponent
---@return PhotonLightingSegment
function Segment:Initialize( componentInstance )
	---@type PhotonLightingSegment
	local segment = {
		LastFrameTime = 0,
		IsActive = false,
		CurrentPriorityScore = 0,
		Component = componentInstance,
		CurrentModes = componentInstance.CurrentModes,
		Lights = componentInstance.Lights,
		ColorMap = componentInstance.ColorMap,
		Sequences = {},
		InitializedFrames = {}
	}
	
	setmetatable( segment, { __index = self } )

	-- Setup frames
	for i=0, #self.Frames do
		segment.InitializedFrames[i] = {}
		local frame = segment.InitializedFrames[i]
		for lightId, stateId in pairs(self.Frames[i]) do
			if ( isnumber( stateId ) ) then
				stateId = segment.ColorMap[lightId][stateId]
				if ( not stateId ) then
					error(string.format("ColorMap on Component[%s] Light[%s] does not have Color #%s defined.", componentInstance.Name, lightId, self.Frames[i][lightId]))
				end
			end
			-- TODO: error handling -- this breaks if the frame is 
			-- references a non-existent light
			frame[segment.Component.Lights[lightId]] = stateId
		end
	end

	-- Setup sequences
	for sequenceName, sequence in pairs( self.Sequences ) do
		segment.Sequences[sequenceName] = sequence:Initialize( segment )
	end

	segment:ApplyModeUpdate()

	return segment
end


---@param name string Unique sequence name.
---@param frameSequence integer[]
function Segment:AddNewSequence( name, frameSequence )
	self.Sequences[name] = PhotonSequence.New( name, frameSequence, self )
end


---@param index number Frame index
---@param lightStates table Table of light states (e.g. { { 1, "RED" }, { 2, "BLUE" } })
function Segment:AddFrame( index, lightStates )
	local result = {}
	local lightId, stateId
	for i=1, #lightStates do
		lightId = lightStates[i][1]
		stateId = lightStates[i][2]
		if string.StartsWith( lightId, "@" ) then

		else
			result[lightId] = stateId
		end
	end
	self.Frames[index] = result
	return result
end


---@param count number
function Segment:IncrementFrame( count )
	if not (self.IsActive) then return end
	if not (self.ActivePattern) then return end

	local sequence = self:GetCurrentSequence()
	if ( not sequence ) then return end

	sequence:SetFrame( (count % #sequence) + 1 )
end


-- Updates all lights to match the current sequence frame.
function Segment:Render()
	if (not self.IsActive) then return end

	local map = self.Patterns
	local sequence

	for i = 1, #map[self.ActivePattern] do
		---@type PhotonSequence
		sequence = map[i]
		local lights = self.Lights
		-- map[i] is a PhotonSequence class
		for lightId, state in pairs( sequence[sequence.CurrentFrame] ) do
			lights[lightId]:SetState( state, self.CurrentPriorityScore )
		end
	end
end


---@param channelMode string 
---@param sequence string
---@param conditions? table
function Segment:AddPattern( channelMode, sequence, conditions )
	printf("Adding pattern. Mode: %s. Sequence: %s.", channelMode, sequence)
	if (istable(conditions)) then
		-- TODO: conditional
	end
	-- if (isstring(sequence)) then
	-- 	sequence = self.Sequences[sequence]
	-- end
	self.Patterns[channelMode] = sequence --[[@as string]]
end

function Segment:AcceptsChannelMode( channelMode )
	-- return true
	return not ( self.Patterns[channelMode] )
end


function Segment:CalculatePriorityInput( inputState )
	-- print("Calculating priority input...")
	-- PrintTable( inputState )
	local topScore = -1000
	local result
	for channel, mode in pairs( inputState ) do
		if (mode == "OFF") then continue end
		if ( self.InputPriorities[channel] ) then
			-- printf( "\tChecking channel [%s]", channel )
			-- TODO: find alternative to string concatination
			if ( ( self.InputPriorities[channel] > topScore ) and self:AcceptsChannelMode( channel .. "." .. inputState[channel] ) ) then
				topScore = self.InputPriorities[channel]
				result = channel
			end
		end
	end
	return result
end


function Segment:OnModeChange( channel, mode )
	printf("Segment received a mode update [%s] => %s", channel, mode)
	self:ApplyModeUpdate()
end

function Segment:ApplyModeUpdate()
	local inputState = self.CurrentModes
	local newChannel = self:CalculatePriorityInput( inputState )
	if (not newChannel) then return end
	printf( "New channel calculated to be: %s", newChannel )
	local newMode = newChannel .. ":" .. inputState[newChannel]
	printf( "New mode calculated to be: %s", newMode )
	self.CurrentPriorityScore = self.InputPriorities[newChannel]
	printf( "CurrentPriorityScore: %s", self.CurrentPriorityScore )
	-- Do nothing if priority state hasn't changed
	if (self.ActivePattern == ( newMode )) then
		return
	end
	-- self:DeactivateSequences()
	-- Turn off all segment lights when the active pattern changes.
	self:DectivateCurrentSequence()
	self:ResetSegment()
	self.ActivePattern = newMode
	self.IsActive = true
	self:ActivateCurrentSequence()
	-- Turn lights back on
	-- self:ActivateSequences()
end


function Segment:ResetSegment()
	-- print("Resetting segment...")
	local lights = self.Lights
	for lightId, state in pairs(self.Frames[0]) do
		lights[lightId]:SetState( state )
	end
	-- print("Frame[0]")
	-- PrintTable(self.Frames[0])
	-- for i = 1, #default do
	-- 	printf("default[i] = %s", default[i])
	-- 	-- TODO: switch to direct reference instead of long look-up
	-- 	self.Lights[default[i][1]]:SetState( default[i][2] )
	-- end
end

function Segment:ActivateCurrentSequence()
	local sequence = self:GetCurrentSequence()
	if (sequence) then
		sequence:Activate()
		self.Component:RegisterActiveSequence( "x", sequence )
	end
end

function Segment:DectivateCurrentSequence()
	local sequence = self:GetCurrentSequence()
	if (sequence) then
		sequence:Deactivate()
		self.Component:RemoveActiveSequence( "x", sequence )
	end
end

function Segment:GetCurrentSequence()
	-- printf("Attemping to get current sequence. The .ActivePattern is [%s]", self.ActivePattern)
	-- printf("self.Patterns[self.ActivePattern] = [%s]", self.Patterns[self.ActivePattern])
	-- PrintTable(self.Sequences)
	return self.Sequences[self.Patterns[self.ActivePattern]]
end


-- function Segment:ActivateSequences()
-- 	---@type PhotonSequence[]
-- 	local sequences = self.Patterns[self.ActivePattern]
-- 	for i = 1, #sequences do
-- 		sequences[i]:Activate()
-- 	end
-- end


-- function Segment:DeactivateSequences()
-- 	---@type PhotonSequence[]
-- 	local sequences = self.Patterns[self.ActivePattern]
-- 	for i = 1, #sequences do
-- 		sequences[i]:Deactivate()
-- 	end
-- end

-- ---@param channel string Channel Name
-- ---@param ... string Channel Modes
-- ---@return PhotonLightingSegment
-- function Segment:OnInput( channel, ... )
-- 	local modes = table.pack(...)
-- 	local pattern = PhotonSequenceCollection.New( self )

-- 	if self.InputPriorities[channel] then
-- 		pattern.Priority = self.InputPriorities[channel]
-- 	else
-- 		pattern.Priority = -1
-- 		Photon2.Debug.Print("No channel input priority defined for '" .. tostring(channel) .. "'")
-- 	end

-- 	for i = 1, #modes do
-- 		self.Patterns[channel .. "." .. mode] = pattern
-- 	end

-- 	return self
-- end