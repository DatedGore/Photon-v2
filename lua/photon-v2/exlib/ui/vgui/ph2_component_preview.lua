--[[

	Component Preview Panel

--]]

local info, warn, warnonce = Photon2.Debug.Declare( "Library" )

local PANEL = {
	AllowAutoRefresh = true
}

local displayElementDebugConVar = CreateClientConVar( "ph2_preview_debug_overlay", "0", true, false, "Display debug elements in the component preview." )

local SortedPairs = Photon2.Util.SortedPairsToString

function PANEL:Init()
	self.BaseClass.Init( self )
	local this = self
	self:Setup()
end

function PANEL:PostAutoRefresh()
	self:Setup()
end

local function IsKeyBindDown( cmd )
	for keyCode = 1, BUTTON_CODE_LAST do
		if ( input.LookupKeyBinding( keyCode ) == cmd and input.IsKeyDown( keyCode ) ) then
			return true
		end
	end

	return false
end

function PANEL:DoComponentReload()
	self.CurrentEntry = Photon2.Library.Components:GetInherited( self.CurrentEntryName )
	if ( IsValid( self.ModelPanel ) ) then
		self.ModelPanel:SetComponent( self.CurrentEntryName, true )
		local selected = self.Tree:GetSelectedItem()
		if ( IsValid( selected ) ) then
			selected:OnNodeSelected()
		end
	end
end

---@param entryName string
---@param isComponentReload? boolean If this was triggered by a component reload.
function PANEL:SetEntry( entryName, isComponentReload )
	-- Ignore loading reload because it's handled internally.

	-- if ( isComponentReload ) then return end
	
	self:Clear()

	local this = self

	local scrollPanel = vgui.Create( "DPanel", self )
	scrollPanel:SetPaintBackground( false )
	scrollPanel:Dock( FILL )

	self.CurrentEntryName = entryName
	self.CurrentEntry = Photon2.Library.Components:GetInherited( entryName )

	local entry = self.CurrentEntry

	local titleLabel = vgui.Create( "DLabel", scrollPanel )
	titleLabel:Dock( TOP )
	-- titleLabel:SetHeight( 30 )
	titleLabel:SetFont( "PhotonUI.Header")
	titleLabel:SetText( entry.Title or "(Untitled)" )
	
	local overviewTab = vgui.Create( "DPanel", scrollPanel )
	overviewTab:SetPaintBackground( false )

	local viewTab = vgui.Create( "DScrollPanel", scrollPanel )
	local showLightNumbersOption = vgui.Create( "DCheckBoxLabel", viewTab )
	showLightNumbersOption:SetText( "Display Element Overlay" )
	showLightNumbersOption:Dock( TOP )
	showLightNumbersOption:SetConVar( "ph2_preview_debug_overlay" )

	local modelTab = vgui.Create( "DPanel", scrollPanel )
	modelTab:DockMargin( -4, -4, 0, 0 )

	local propertySheet = vgui.Create ("DPropertySheet", scrollPanel )
	propertySheet:DockMargin( 0, 8, 0, 0 )
	propertySheet:Dock( FILL )
	propertySheet:AddSheet( "Component", overviewTab )
	
	local actualModelTab = propertySheet:AddSheet( "Model", modelTab )
	propertySheet:AddSheet( "View", viewTab )
	propertySheet:DockPadding( 0, 0, 0, 0 )

	function propertySheet:OnActiveTabChanged( oldPanel, newPanel )
		if ( newPanel:GetPanel() == modelTab ) then
			if ( this.ActiveComponent ) then
				this.ActiveComponent:SuspendAllModes()
			end
		else
			if ( this.ActiveComponent ) then
				this.ActiveComponent:ResumeAllModes()
			end
		end
	end

	modelTab:SetPaintBackground( false )
	
	modelTab.Title = vgui.Create( "Photon2UICopyInfoTitle", modelTab )
	modelTab.Title:Dock( TOP )
	modelTab.Title:DockMargin( 0, 0, 0, 4)

	modelTab.Tree = vgui.Create( "Photon2UIModelPreviewTree", modelTab )
	modelTab.Tree:Dock( FILL )


	local activeComponent
	local modelPanel

	if ( entry.Model ) then
		modelPanel = vgui.Create( "DAdjustableModelPanel", scrollPanel )
		modelPanel:Dock( TOP )
		modelPanel:SetTall( 100 )
		modelPanel:SetCamPos( Vector( -60, 0, 20 ) )
		modelPanel:SetLookAng( Angle( 20, 0, 0 ) )
		modelPanel:SetFOV( 60 )
		modelPanel:SetAnimated( false )
		local nativeMouseWheel = modelPanel.OnMouseWheeled
		function modelPanel:OnMouseWheeled( delta )
			nativeMouseWheel( self, delta )
			this.PreviewCameraFOV = self.fFOV
		end

		modelTab.Title:SetEntry( entry.Model, (entry.Credits or {}).Model or "Unknown", "model name", true )

		local scrW = ScrW()
		local scrH = ScrH()

		-- modelPanel:SetFOV( this.FOV or 45 )
		-- modelPanel.Angles = angle_zero
		-- modelPanel:SetSize( 200, 200 )
		-- modelPanel:SetModel( entry.Model )
		function modelPanel:Paint( w, h )

			if ( !IsValid( self.Entity ) ) then return end
		
			local x, y = self:LocalToScreen( 0, 0 )
		
			self:LayoutEntity( self.Entity )
		
			local ang = self.aLookAngle
			if ( !ang ) then
				ang = ( self.vLookatPos - self.vCamPos ):Angle()
			end
		
			cam.Start3D( self.vCamPos, ang, self.fFOV, x, y, w, h, 5, self.FarZ )
		
			render.SuppressEngineLighting( true )
			render.SetLightingOrigin( self.Entity:GetPos() )
			render.ResetModelLighting( self.colAmbientLight.r / 255, self.colAmbientLight.g / 255, self.colAmbientLight.b / 255 )
			render.SetColorModulation( self.colColor.r / 255, self.colColor.g / 255, self.colColor.b / 255 )
			render.SetBlend( ( self:GetAlpha() / 255 ) * ( self.colColor.a / 255 ) ) -- * surface.GetAlphaMultiplier()
			for i = 0, 6 do
				local col = self.DirectionalLight[ i ]
				if ( col ) then
					render.SetModelLighting( i, col.r / 255, col.g / 255, col.b / 255 )
				end
			end
			
			self.Entity:SetupBones()
			self:DrawModel()

			Photon2.RenderLightMesh.OnPreRender()
			Photon2.RenderLightMesh.DrawUI()
			Photon2.RenderLight2D.OnPreRender()
			Photon2.RenderLight2D.DrawUI()
			-- cam.Start3D()
			-- cam.End3D()
			-- cam.Start2D()
			for i=1, #self.Entity.Elements do
				if ( self.Entity.Elements[i].DrawDebug and self.Entity.Elements[i].DoPreRender ) then
					self.Entity.Elements[i]:DoPreRender( true )
					if ( not self.Entity.Elements[i].Position ) then continue end
					self.Entity.Elements[i].ScreenPosition = self.Entity.Elements[i].Position:ToScreen()
					local scrPos = self.Entity.Elements[i].ScreenPosition

					-- :ToScreen() does not account for viewport size so it needs to be scaled manually
					scrPos.x = scrPos.x * ( w / scrW )
					scrPos.y = scrPos.y * ( h / scrH )
					-- self.Entity.Elements[i]:DrawDebug()
				end
			end
			-- cam.End2D()
			render.SuppressEngineLighting( false )
			cam.End3D()
			cam.Start3D()
			cam.End3D()
			
			self.LastPaint = RealTime()

			if ( displayElementDebugConVar:GetBool() ) then
				for i, element in pairs( self.Entity.Elements ) do
					if ( element.DrawDebug ) then
						element:DrawDebug()
					end
				end
			end
		end

		function modelPanel:SetComponent( componentId, static )
			if ( IsValid( PHOTON2_PREVIEW_COMPONENT ) ) then
				PHOTON2_PREVIEW_COMPONENT:Remove()
			end

			local component = Photon2.GetComponent( componentId )
			local ent = component:CreateForUI()
			ent.UseStrictFrameTiming = false
			ent:SetScale( ent.Preview.Zoom )
			if ( this.PlayerControls ) then
				ent.ManualFrameDuration = this.PlayerControls.CurrentFrameDuration
			end
			self.Entity = ent
			
			PHOTON2_PREVIEW_COMPONENT = ent
			
			ent:SetChannelMode( "Emergency.Warning", "MODE3" )
			if ( not static ) then
				local newZ = ent.Preview.Position.Z + 20
				self:SetLookAng( Angle( newZ, 0, 0 ) )
				self:SetCamPos( Vector( -60, 0, newZ ) )
			end
			
			if ( CurTime() < 32000 ) then
				hook.Add( "Think", ent, function() 
					local index = ent:ManualThink()
					if ( not ent.IsPaused ) then
						this.PlayerControls:SetFrameIndex( index )
					end
					-- ent:SetupBones()
					-- ent:SetPropertiesFromEquipment( component )
				end)
			else
				warn( "Component preview disabled to prevent game crash. Please reload the map or restart the game.")
			end
			
			hook.Add( "Photon2:ComponentReloaded", this, function( hookName, id )
				if ( id == entryName or component.Ancestors[id] ) then
					-- this:SetEntry( entryName )
					this:DoComponentReload()
				end
			end )
			this.ActiveComponent = ent
			
			modelTab.Tree:SetModel( this.ActiveComponent )

		end
			

		function modelPanel:FirstPersonControls()

			local x, y = self:CaptureMouse()
			
			local scale = self:GetFOV() / 180
			x = x * -0.5 * scale
			y = y * 0.5 * scale
		
			if ( self.MouseKey == MOUSE_LEFT ) then
		
				if ( input.IsShiftDown() ) then y = 0 end
		
				self.aLookAngle = self.aLookAngle + Angle( y * 1, x * 1, 0 )
		
				self.vCamPos = self.OrbitPoint - self.aLookAngle:Forward() * self.OrbitDistance
		
				this.PreviewCameraPosition = self.vCamPos
				this.PreviewCameraAngle = self.aLookAngle
				return
			end
			-- Look around
			self.aLookAngle = self.aLookAngle + Angle( y, x, 0 )
			self.aLookAngle.p = math.Clamp( self.aLookAngle.p, -90, 90 )
		
			local Movement = vector_origin
		
			if ( IsKeyBindDown( "+forward" ) or input.IsKeyDown( KEY_UP ) ) then
				Movement = Movement + self.aLookAngle:Forward()
			end
		
			if ( IsKeyBindDown( "+back" ) or input.IsKeyDown( KEY_DOWN ) ) then
				Movement = Movement - self.aLookAngle:Forward()
			end
		
			if ( IsKeyBindDown( "+moveleft" ) or input.IsKeyDown( KEY_LEFT ) ) then
				Movement = Movement - self.aLookAngle:Right()
			end
		
			if ( IsKeyBindDown( "+moveright" ) or input.IsKeyDown( KEY_RIGHT ) ) then
				Movement = Movement + self.aLookAngle:Right()
			end
		
			if ( IsKeyBindDown( "+jump" ) or input.IsKeyDown( KEY_SPACE ) ) then
				Movement = Movement + vector_up
			end
		
			if ( IsKeyBindDown( "+duck" ) or input.IsKeyDown( KEY_LCONTROL ) ) then
				Movement = Movement - vector_up
			end
		
			local speed = 0.5
			if ( input.IsShiftDown() ) then speed = 4.0 end
		
			self.vCamPos = self.vCamPos + Movement * speed
			
			this.PreviewCameraPosition = self.vCamPos
			this.PreviewCameraAngle = self.aLookAngle
		end

		modelPanel:SetComponent( entryName )

		function modelPanel:LayoutEntity()
			self.Entity:SetPos( self.Entity.Preview.Position )
			self.Entity:SetAngles( self.Entity.Preview.Angles )
		end

		self.ModelPanel = modelPanel

		function modelTab.Tree:OnHighlightMaterial( index )
			this.ActiveComponent:SoftHighlightSubMaterial( index )
		end

		function modelTab.Tree:OnHighlightMaterialClear()
			this.ActiveComponent:ClearMaterialHighlight()
		end

		function modelTab.Tree:OnIsolateMaterial( index )
			this.ActiveComponent:IsolateSubMaterial( index )
		end

	end



	local sequencePlayer = vgui.Create( "Photon2UISequencePlayerControls", overviewTab )
	sequencePlayer:Dock( BOTTOM )
	sequencePlayer:DockMargin( 0, 4, 0, 0 )
	sequencePlayer:DockPadding( 4, 0, 4, 0 )

	function sequencePlayer:OnPause() this.ActiveComponent:SetPaused( true ) end
	function sequencePlayer:OnPlay() this.ActiveComponent:SetPaused( false ) end

	function sequencePlayer:OnForwardOne() this.ActiveComponent:IndependentFrameTick( true ) end
	function sequencePlayer:OnBackOne() this.ActiveComponent:IndependentFrameTick( true, -1 ) end

	function sequencePlayer:OnFrameSliderChange( value )
		this.ActiveComponent:SetFrameIndex( value - 1 )
	end

	function sequencePlayer:OnFrameDurationChange( value )
		this.ActiveComponent.ManualFrameDuration = value
	end

	self.PlayerControls = sequencePlayer

	local tree = vgui.Create( "Photon2UIComponentPreviewTree", overviewTab )
	self.Tree = tree
	-- tree:SetLineHeight( 22 )
	tree:Dock( FILL )

	function tree:OnNodeSelected( node )
		this.CurrentPath = self:GetPath( node )
	end


	local componentInfoPanel = vgui.Create( "DPanel", overviewTab )
	componentInfoPanel:Dock( TOP )
	componentInfoPanel:SetHeight( 48 )
	componentInfoPanel:DockMargin( 0, 0, 0, 4 )
	componentInfoPanel:DockPadding( 8, 4, 8, 4 )
	componentInfoPanel:SetCursor( "hand" )

	local nameLabel = vgui.Create( "DLabel", componentInfoPanel )
	nameLabel:Dock( TOP )
	-- nameLabel:SetHeight( 60 )
	nameLabel:SetFont( "PhotonUI.Mono" )
	nameLabel:SetText( entryName )

	local authorLabel = vgui.Create( "DLabel", componentInfoPanel )
	authorLabel:Dock( TOP )
	local function setAuthorLabelText()
		local authorText = "Author: " .. ( entry.Author or "Unknown" )
		if ( entry.Credits ) then
			for credit, name in pairs( entry.Credits ) do
				authorText = authorText .. " | " .. tostring( credit ) .. ": " .. tostring( name )
			end
		end
		authorLabel:SetText( authorText )
	end
	setAuthorLabelText()

	function componentInfoPanel:OnCursorEntered()
		authorLabel:SetText( "Click to copy component name..." )
	end
	
	function componentInfoPanel:OnCursorExited()
		setAuthorLabelText()
	end
	
	function componentInfoPanel:OnMousePressed( keyCode )
		if ( keyCode == MOUSE_LEFT ) then
			authorLabel:SetText( "" )
			SetClipboardText( entryName )
		end
	end

	function componentInfoPanel:OnMouseReleased( keyCode )
		if ( keyCode == MOUSE_LEFT ) then
			authorLabel:SetText( "Copied." )
		end
	end

	function tree:OnSequenceSelected( segment, sequence )
		local sequenceData = this.CurrentEntry.Segments[segment].Sequences[sequence]
		this.PlayerControls:SetSequence( sequenceData )
		this.PlayerControls:DoPlay()
		if( modelPanel ) then
			Photon2.ComponentBuilder.ApplyDebugSequences( entryName, { [segment] = sequence } )
			modelPanel:SetComponent( entryName, true )
			modelPanel.Entity:SetChannelMode( "#DEBUG", "ON", true )
		end
	end

	function tree:OnPatternSelected( segment )
		this.PlayerControls:SetSliderVisible( false )
		this.PlayerControls:DoPlay()
		if ( modelPanel ) then
			Photon2.ComponentBuilder.ApplyDebugSequences( entryName, segment )
			modelPanel:SetComponent( entryName, true )
			modelPanel.Entity:SetChannelMode( "#DEBUG", "ON", true )
		end
	end

	function tree:OnModeSelected( channel, mode )
		this.PlayerControls:SetSliderVisible( false )
		if ( modelPanel ) then
			modelPanel.Entity:SetChannelMode( channel, mode, true )
			this.PlayerControls:Show()
		end
	end

	function tree:OnElementGroupSelected( group )
		this.PlayerControls:SetSliderVisible( false )
		if ( modelPanel ) then
			Photon2.ComponentBuilder.ApplyDebugElementGroup( entryName, group )
			modelPanel:SetComponent( entryName, true )
			modelPanel.Entity:SetChannelMode( "#DEBUG", "ON", true )
		end
	end
	
	local function modeOff()
		if ( modelPanel ) then
			modelPanel.Entity:ClearAllModes()
			self.PlayerControls:Hide()
		end
	end


	tree:SetComponent( entry )

	if ( isComponentReload ) then
		if ( self.CurrentPath ) then
			self.Tree:NavigateToPath( self.CurrentPath )
		end
		if IsValid( self.ModelPanel ) then
			if ( self.PreviewCameraPosition ) then
				self.ModelPanel:SetCamPos( self.PreviewCameraPosition )
				self.ModelPanel:SetLookAng( self.PreviewCameraAngle )
			end
			if ( self.PreviewCameraFOV ) then
				self.ModelPanel:SetFOV( self.PreviewCameraFOV )
			end
		end
	end
end

function PANEL:Setup()
	self:DockPadding( 8, 8, 8, 8 )
	if ( self.CurrentEntryName ) then
		self:Clear()
		self:SetEntry( self.CurrentEntryName )
		if ( self.CurrentPath ) then
			self.Tree:NavigateToPath( self.CurrentPath )
		end
	end
end


--[[

	Sequence Player Controls

--]]

local PLAYER = {
	AllowAutoRefresh = true
}

local timingOptions = {
	{ Label = "1/60s",	Value = 1/60 },
	{ Label = "1/48s",	Value = 1/48 },
	{ Label = "1/40s",	Value = 1/40 },
	{ Label = "1/32s",	Value = 1/32 },
	{ Label = "1/24s",	Value = 1/24 },
	{ Label = "1/10s",	Value = 1/10 },
	{ Label = "1/2s",	Value = 1/2  },
	{ Label = "1s",  	Value = 1    },
}

function PLAYER:OnFrameDurationChange( new ) end

function PLAYER:SetSequence( sequence )
	self.CurrentSequence = sequence
	self:SetSequenceLength( #sequence )
	self:SetSliderVisible( true )
end

function PLAYER:Show()
	self:SetVisible( true )
	self:InvalidateParent()
end

function PLAYER:Hide()
	self:SetVisible( false )
	self:InvalidateParent()
end

function PLAYER:SetFrameIndex( index )
	self.Slider.Suppress = true
	self.Slider:SetValue( ( index % self.Slider:GetMax() ) + 1 )
	self.Slider.Suppress = false
end

function PLAYER:OnPause() end

function PLAYER:OnPlay() end

function PLAYER:OnFrameSliderChange( value ) end

function PLAYER:OnForwardOne() end
function PLAYER:OnBackOne() end

function PLAYER:DoPause()
	self.IsPaused = true
	self.PlayButton:SetIcon( "play" )
	self:OnPause()
end

function PLAYER:DoPlay()
	self.IsPaused = false
	self.PlayButton:SetIcon( "pause" )
	self:OnPlay()
end

function PLAYER:DoForwardOne()
	self:DoPause()
	self:SetFrameIndex( self.Slider:GetValue() )
	self:OnForwardOne()
end

function PLAYER:DoBackOne()
	self:DoPause()
	-- This needs to be -2 to work properly because
	-- it's not worth figuring out what's actually happening
	self:SetFrameIndex( self.Slider:GetValue() - 2 )
	self:OnBackOne()
end

-- Sets label of the current *actual* frame.
function PLAYER:SetRealFrame( frame )
	self.RealFrameLabel:SetText( "=[" .. tostring( frame ) .. "]" )
end

-- Sets the current frame index of the sequence.
function PLAYER:SetSequenceFrame( frame )
	self.Slider.Suppress = true
	self.Slider:SetValue( frame )
	self.Slider.Suppress = false
end

function PLAYER:SetSequenceLength( length )
	self.Slider:SetMax( length )
	self.Slider:SetValue( 1 )
end

function PLAYER:SetSliderVisible( visible )
	if ( visible ) then
		self.Slider:SetVisible( true )
		self.RealFrameLabel:SetVisible( true )
		self:SetHeight( 64 )
	else
		self.RealFrameLabel:SetVisible( false )
		self.Slider:SetVisible( false )
		self:SetHeight( 40 )
	end
end



function PLAYER:Init()
	self:Clear()
	
	self:SetHeight( 40 )
	
	local this = self
	self.IsPaused = false

	local sequencePlayer = self

	local slider = vgui.Create( "DNumSlider", sequencePlayer )
	slider:Dock( TOP )
	slider:SetHeight( 24 )
	slider:SetDecimals( 0 )
	slider:SetMax( 1 )
	slider:SetMin( 1 )
	slider:SetDefaultValue( 1 )
	slider.Label:SetVisible( false )
	slider:DockPadding( 0, 0, 0, 0 )
	slider.TextArea:SetWide( 26 )
	slider:SetVisible( false )
	self.Slider = slider

	function slider:OnValueChanged( value )
		value = math.floor( value ) 
		if ( this.LastValue == value ) then return end
		if ( this.CurrentSequence ) then this:SetRealFrame( this.CurrentSequence[value] ) end
		if ( slider.Suppress ) then return end
		this:OnFrameSliderChange( value )
		this.LastValue = value
	end

	local playerControls = vgui.Create( "DPanel", sequencePlayer )
	playerControls:Dock( FILL )
	playerControls:SetPaintBackground( false ) 

	local playButton = vgui.Create( "EXDButton", playerControls )
	playButton:SetIcon( "pause", true )
	playButton:SetSize( 48, 28 )
	playButton:AlignLeft( 2 )
	playButton:AlignTop( 6 )

	self.PlayButton = playButton

	function playButton:OnReleased()
		if ( self.Wait ) then 
			self.Wait = false
			self:SetIcon( "play" )
			return
		end
		if ( not this.IsPaused ) then return end
		this:DoPlay()
		self.Wait = false
	end

	function playButton:OnDepressed()
		if ( this.IsPaused ) then return end
		this.IsPaused = true
		this:OnPause()
		self.Wait = true
	end

	local stepBackButton = vgui.Create( "EXDButton", playerControls )
	stepBackButton:SetIcon( "skip-previous", true )
	stepBackButton:SetSize( 32, 28 )
	stepBackButton:MoveRightOf( playButton, 4 )
	stepBackButton:AlignTop( 6 )

	function stepBackButton:OnDepressed() this:DoBackOne() end

	local stepForwardButton = vgui.Create( "EXDButton", playerControls )
	stepForwardButton:SetIcon( "skip-next", true )
	stepForwardButton:SetSize( 32, 28 )
	stepForwardButton:MoveRightOf( stepBackButton, 4 )
	stepForwardButton:AlignTop( 6 )
	
	function stepForwardButton:OnDepressed() this:DoForwardOne() end

	local frameRateOption = vgui.Create( "DComboBox", playerControls )
	frameRateOption:SetSize( 56, 28 )
	frameRateOption:MoveRightOf( stepForwardButton, 4 )
	frameRateOption:AlignTop( 6 )
	frameRateOption:SetSortItems( false )
	frameRateOption:SetValue( "1/24s" )
	self.CurrentFrameDuration = 1/24
	for i, value in ipairs( timingOptions ) do
		frameRateOption:AddChoice( value.Label, value )
	end

	function frameRateOption:OnSelect( index, value, data )
		this.CurrentFrameDuration = data.Value
		this:OnFrameDurationChange( data.Value )
	end

	local currentFrame = vgui.Create( "DLabel", playerControls )
	currentFrame:Dock( RIGHT )
	currentFrame:SetWide( 48 )
	currentFrame:SetText( "= [99]" )
	currentFrame:SetContentAlignment( 5 )
	currentFrame:SetFont( "PhotonUI.Mono" )
	currentFrame:SetVisible( false )
	self.RealFrameLabel = currentFrame
end

function PLAYER:PostAutoRefresh()
	-- print("post auto")
	-- self:Init()
end


--[[

	Component Preview Tree

--]]

local TREE = {}

function TREE:OnPatternSelected( patternName ) end

function TREE:OnSequenceSelected( segmentName, sequenceName ) end

function TREE:OnModeSegmentSelected( segmentName ) end

function TREE:OnModeSelected( channelName, modeName ) end

function TREE:OnModeDeselected() end

function TREE:OnElementGroupSelected( groupName ) end

function TREE:BuildStateSlotsSignature( states )
	local signature = "[STATES]"
	for i, state in ipairs( states ) do
		signature = signature .. "(" .. tostring( i ) .. "=" .. tostring( state ) .. ")"
	end
	signature = signature .. "[/STATES]"
end

function TREE:UpdateStateSlots( states )
	local slotsNode = self.SlotsNode or self:AddNode( "State Slots", "numeric", true )
	for i, state in ipairs( states ) do
		local stateNode = slotsNode:AddNode( state, "numeric-" .. tostring( i ) .. "-circle-outline" )
	end
	self.SlotsNode = slotsNode
end

function TREE:UpdateInputs( inputs )
	local this = self
	local signature = ""
	local inputsNode = self.InputsNode or self:AddNode( "Inputs", "power-plug", true )
	for channelName, modes in pairs( inputs ) do
		if ( channelName == "#DEBUG" ) then continue end
		signature = signature .. "[" .. tostring( signature ) .. "]"
		local channelNode = inputsNode:AddNode( channelName, "ray-vertex", true )
		for modeName, sequences in SortedPairs( modes ) do
			signature = signature .. "(" .. tostring( modeName ) .. ")"
			local modeNode = channelNode:AddNode( modeName, "chevron-right-circle-outline" )
			function modeNode:OnNodeSelected()
				this:OnNodeSelected( self )
				this:OnModeSelected( channelName, modeName )
			end

			if ( istable( sequences ) ) then
				for segmentName, sequenceName in pairs( sequences ) do
					local sequenceNode = modeNode:AddNode( string.format("%s/%s", segmentName, sequenceName), "filmstrip" )
					function sequenceNode:OnNodeSelected()
						this:OnNodeSelected( self )
						this:OnSequenceSelected( segmentName, sequenceName)
					end
				end
			elseif( isstring( sequences ) ) then
				local patternNode = modeNode:AddNode( sequences, "play-box" )
				function patternNode:OnNodeSelected()
					this:OnNodeSelected( self )
					this:OnPatternSelected( sequences )
				end
			end
		end
	end
	this.InputsNode = inputsNode
end

function TREE:UpdateElementGroups( elementGroups )
	local this = self
	local groupsNode = self.GroupsNode or self:AddNode( "Element Groups", "folder", true )
	for groupName, elements in SortedPairs( elementGroups ) do
		local groupNode = groupsNode:AddNode( groupName, "folder" )
		function groupNode:OnNodeSelected()
			this:OnNodeSelected( self )
			this:OnElementGroupSelected( groupName )
		end
		for i, element in ipairs( elements ) do
			local elementNode = groupNode:AddNode( element, "cube-outline" )
		end
	end
	self.GroupsNode = groupsNode
end

function TREE:UpdatePatterns( patterns )
	local this = self
	local patternsNode = self.PatternsNode or self:AddNode( "Patterns", "animation-play", true )
	for patternName, sequences in SortedPairs( patterns ) do
		local patternNode = patternsNode:AddNode( patternName, "play-box" )
		for i, sequence in ipairs( sequences or {} ) do
			local sequenceNode = patternNode:AddNode( string.format("%s/%s", sequence[1], sequence[2] ), "filmstrip" )
			function sequenceNode:OnNodeSelected()
				this:OnNodeSelected( self )
				this:OnSequenceSelected( sequence[1], sequence[2] )
			end
		end
		function patternNode:OnNodeSelected()
			this:OnNodeSelected( self )
			this:OnPatternSelected( patternName )
		end
	end
	self.PatternsNode = patternsNode
end

function TREE:UpdateSegments( segments )
	local this = self
	local segmentsNode = self.SegmentsNode or self:AddNode( "Sequences", "movie-roll", true )
	for segmentName, segment in SortedPairs( segments ) do
		local segmentNode = segmentsNode:AddNode( segmentName, "film", true )
		for sequenceName, sequence in SortedPairs( segment.Sequences or {} ) do
			local sequenceNode = segmentNode:AddNode( sequenceName, "filmstrip")
			function sequenceNode:OnNodeSelected()
				this:OnNodeSelected( self )
				this:OnSequenceSelected( segmentName, sequenceName )
			end
		end
	end
	self.SegmentsNode = segmentsNode
end

function TREE:UpdateDefinedOptions( options )
	local this = self
	local optionsNode = self.OptionsNode or self:AddNode( "Options", "xml", true )
	for optionName, option in SortedPairs( options ) do
		if ( not istable( option ) ) then option = { option } end
		local optionNode = optionsNode:AddNode( optionName, "wrench" )
		function optionNode:OnNodeSelected()
			this:OnNodeSelected( self )
		end
		for argIndex, argData in ipairs( option.Arguments or {} ) do
			local argNode = optionNode:AddNode( string.format( "%s (%s)", argData[1], argData[2] ), string.format("numeric-%i-circle", argIndex ) )
			function argNode:OnNodeSelected()
				this:OnNodeSelected( self )
			end
		end
	end
	self.OptionsNode = optionsNode
end

function TREE:SetComponent( component )
	self:Clear()
	if ( component.States ) then self:UpdateStateSlots( component.States ) end
	if ( component.Inputs ) then self:UpdateInputs( component.Inputs ) end
	if ( component.Patterns ) then self:UpdatePatterns( component.Patterns ) end
	if ( component.Segments ) then self:UpdateSegments( component.Segments ) end
	if ( component.ElementGroups ) then self:UpdateElementGroups( component.ElementGroups ) end
	-- use .DefineOptions (not DEFINED) because the component is not compiled at this stage
	if ( component.DefineOptions ) then self:UpdateDefinedOptions( component.DefineOptions ) end
end

function TREE:Init()
	self:SetLineHeight( 22 )
end

function TREE:GetPath( node )
	local path = {}
	local current = node
	while ( IsValid( current ) ) do
		if ( current:IsRootNode() ) then break end
		path[#path+1] = current:GetText()
		current = current:GetParentNode()
	end
	return path
end

function TREE:OnNodeSelected( node )
	self.CurrentPath = self:GetPath( node )
end

local function findChildNodeByName( node, name )
	for i, child in ipairs( node:GetChildNodes() ) do
		if ( child:GetText() == name ) then
			return child
		end
	end
end

function TREE:NavigateToPath( path )
	local current = self:Root()
	for i = #path, 1, -1 do
		local next = findChildNodeByName( current, path[i] )
		if ( not IsValid( next ) ) then break end
		current = next
	end
	current:ExpandTo( true )
	current:DoClick()
	current:OnNodeSelected()
	self:SetSelectedItem( current )
	self:ScrollToChild( current )
	return current
end

---@class Photon2UIComponentPreviewer : Panel
local TITLE = {}

function TITLE:SetEntry( title, subTitle, descriptor, enabled )
	self.TitleText = title
	self.SubTitleText = subTitle
	self.SubTitleLabel:SetText( subTitle )
	self.Enabled = enabled
	self.Descriptor = descriptor
	self.TitleLabel:SetText( title )
	if ( enabled ) then
		self:SetCursor( "hand" )
	else
		self:SetCursor( "no" )
	end
end

function TITLE:Init()
	self:SetCursor( "hand" )
	self:SetHeight( 48 )
	self:DockPadding( 8, 4, 8, 4 )

	local titleLabel = vgui.Create( "DLabel", self )
	titleLabel:Dock( TOP )
	titleLabel:SetFont( "PhotonUI.Mono" )

	local subTitle = vgui.Create( "DLabel", self )
	subTitle:Dock( TOP )

	self.TitleLabel = titleLabel
	self.SubTitleLabel = subTitle
end

function TITLE:OnCursorEntered()
	if ( self.Enabled ) then
		self.SubTitleLabel:SetText( "Click to copy " .. self.Descriptor .. "..." )
	end
end

function TITLE:OnCursorExited()
	self.SubTitleLabel:SetText( self.SubTitleText )
end

function TITLE:OnMousePressed( keyCode )
	if ( keyCode == MOUSE_LEFT ) then
		self.SubTitleLabel:SetText( "" )
		SetClipboardText( self.TitleText )
	end
end

function TITLE:OnMouseReleased( keyCode )
	if ( keyCode == MOUSE_LEFT ) then
		self.SubTitleLabel:SetText( "Copied." )
	end
end

---@class Photon2UIModelPreviewTree : Panel
local MODELTREE = {}

function MODELTREE:Init()
	self:SetLineHeight( 22 )
end

function MODELTREE:OnHighlightMaterial( index ) end

function MODELTREE:OnHighlightMaterialClear() end

function MODELTREE:OnIsolateMaterial( index ) end

function MODELTREE:SetModel( ent )
	self:Clear()
	
	local this = self

	local bgData = ent:GetBodyGroups()
	local bodyGroupsNode = self:AddNode( "Body Groups", "group", true )

	for i, bodyGroup in ipairs( bgData or {} ) do
		local bodyGroupNode = bodyGroupsNode:AddNode( bodyGroup.name, "numeric-" .. tostring( bodyGroup.id ) .. "-circle-outline", true )
		for index=0, bodyGroup.num - 1 do
			local modelName = bodyGroup.submodels[index]
			if ( modelName == "" ) then modelName = "(Blank)" end
			local subModelNode = bodyGroupNode:AddNode( modelName, "numeric-" .. tostring( index ) .. "-circle" )
		end
	end

	ent:SetupBones()
	
	-- model's bone hierarchy needs to be constructed manually
	local hierarchy = {}
	for i=0, ent:GetBoneCount() - 1 do
		local thisHierarchy = {}
		local currentStep = i
		local building = true
		while ( building ) do
			thisHierarchy[#thisHierarchy+1] = currentStep

			if ( ent:GetBoneParent( currentStep ) > -1 ) then
				currentStep = ent:GetBoneParent( currentStep )
			else
				building = false
			end
			
			-- prevent game crash
			if ( #thisHierarchy > 1000 ) then
				Error( "Bone child depth has exceeded 1000 levels! This should NEVER happen. Model: " .. tostring( ent:GetModel() ) )
			end
		end
		
		local currentTableStep = hierarchy
		
		for _i = #thisHierarchy, 1, -1 do
			if ( i > 0 ) then
				currentTableStep[thisHierarchy[_i]] = currentTableStep[thisHierarchy[_i]] or {}
				currentTableStep = currentTableStep[thisHierarchy[_i]]
			end
		end

	end

	-- PrintTable( hierarchy )

	local function addBones( tbl, node )
		for boneId, children in pairs( tbl ) do
			local boneNode = node:AddNode( ent:GetBoneName( boneId ), boneId )
			addBones( children, boneNode )
		end
	end

	local bonesNode = self:AddNode( "Bones", "bone", true )
	addBones( hierarchy, bonesNode )

	local materialsNode = self:AddNode( "Materials", "texture", true )
	for i, material in pairs( ent:GetMaterials() ) do
		local node = materialsNode:AddNode( material, i - 1 )
		local p = node:GetChildren()[1]
		function p:OnCursorEntered()
			this:OnHighlightMaterial( i - 1 )
		end
		function p:OnCursorExited()
			this:OnHighlightMaterialClear()
		end
		function node:OnNodeSelected()
			
			this:OnIsolateMaterial( i - 1 )
		end
	end

	local numPoseParameters = ent:GetNumPoseParameters()

	if ( numPoseParameters and ( numPoseParameters >= 1 ) ) then
		local poseParametersNode = self:AddNode( "Pose Parameters", "ruler-square", true )
		for i = 0, numPoseParameters - 1 do
			local poseParamName = ent:GetPoseParameterName( i )
			poseParametersNode:AddNode( poseParamName, "ruler" )
		end
	end

	local sequences = ent:GetSequenceList()

	if ( sequences and #sequences > 0 ) then
		local sequencesNode = self:AddNode( "Sequences", "run", true )
		for i = 0, #sequences do
			sequencesNode:AddNode( sequences[i], "play" )
		end
	end
end


derma.DefineControl( "Photon2UIModelPreviewTree", "Photon 2 Model Preview Tree", MODELTREE, "EXDTree" )
derma.DefineControl( "Photon2UIComponentPreviewTree", "Photon 2 Component Preview Tree", TREE, "EXDTree" )
derma.DefineControl( "Photon2UISequencePlayerControls", "Photon 2 component previewer", PLAYER, "DPanel" )
derma.DefineControl( "Photon2UICopyInfoTitle", "Photon 2 Copyable Info Title", TITLE, "DPanel" )
derma.DefineControl( "Photon2UIComponentPreviewer", "Photon 2 component previewer", PANEL, "DPanel" )