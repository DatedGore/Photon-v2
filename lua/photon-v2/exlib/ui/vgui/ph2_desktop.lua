local class = "Photon2UIDesktop"
local base = "Photon2UIWindow"

---@class Photon2UIDesktop : Photon2UIWindow
---@field ActiveTabName string
local PANEL = {}

PANEL.AllowAutoRefresh = true

function PANEL:SetTab( tab )
	if ( IsValid( self.Tabs ) ) then
		self.Tabs:SwitchToName( tab )
	end
end

function PANEL:Setup()
	self:SetupMenuBar()
	if ( IsValid( self.ContentContainer ) ) then self.ContentContainer:Clear() end
	
	local container = self.ContentContainer
	local this = self

	self:SetTitle("Menu - Photon 2")
	self:SetSize( 400, 500 )
	self:Center()

	local logoContainer = vgui.Create( "DPanel", container )
	logoContainer:SetPaintBackground( false )
	logoContainer:Dock( TOP )
	logoContainer:SetContentAlignment( 5 )
	logoContainer:SetHeight( 100 )

	local logo = vgui.Create( "DImage", logoContainer )
	logo:SetWidth( 300 )
	logo:SetHeight( 100 )
	logo:SetImage( "photon/ui/ui_logo.png" )
	logo:SetKeepAspect( true )
	logo:SetContentAlignment( 5 )

	local versionLabel = vgui.Create( "DLabel", logoContainer )
	versionLabel:Dock( BOTTOM )
	versionLabel:SetText( "Photon v" .. Photon2.Version )
	versionLabel:SetContentAlignment( 5 )

	function logoContainer:PerformLayout( w, h )
		logo:Center()
	end

	local showServerSettings = CAMI.GetPrivilege( "Photon2.ServerSettings" )

	self:SetupMainPage()
	self:SetupHudOptions()
	self:SetupRenderOptions()
	if ( showServerSettings ) then self:SetupServerPage() end
	self:SetupOtherPage()

	local propertySheet = vgui.Create( "DPropertySheet", container )
	propertySheet:Dock( FILL )
	propertySheet:DockMargin( 0, 8, 0, 0 )
	self.Tabs = propertySheet
	propertySheet:AddSheet( "Photon 2", self.MainPage )
	propertySheet:AddSheet( "Effects", self.RenderPage )
	propertySheet:AddSheet( "HUD", self.HudPage )
	if ( showServerSettings ) then propertySheet:AddSheet( "Game", self.ServerPage ) end
	propertySheet:AddSheet( "Other", self.OtherPage )

	function propertySheet:OnActiveTabChanged( old, new )
		-- This stupid shit is required to get the current tab name
		local name
		for i=1, #self.Items do
			local item = self.Items[i]
			if ( item.Tab == new ) then
				name = item.Name
				break
			end
		end
		this.ActiveTabName = name
	end

	self:SetTab( self.ActiveTabName )

end

function PANEL:Init()
	self.BaseClass.Init( self )

	local container = vgui.Create( "DPanel", self )
	container:Dock( FILL )
	container:SetPaintBackground( false )
	self.ContentContainer = container
	self.ActiveTabName = "Photon 2"
	self:Setup()
end

function PANEL:SetupMenuBar()
	local this = self
	if ( IsValid( self.MenuBar ) ) then self.MenuBar:Remove() end

	-- local menubar = self:GetOrBuildMenuBar()
	
	-- local fileMenu = menubar:AddMenu("File")
end

function PANEL:SetupRenderOptions()
	local panel = vgui.Create( "DPanel", self )
	panel:Dock( FILL )
	panel:DockMargin( 4, -4, 4, 4 )
	panel:DockPadding( 3, 3, 3, 3 )
	self.RenderPage = panel
	
	local form = vgui.Create( "Photon2UIFormPanel", panel )--[[@as Photon2UIFormPanel]]
	form:Dock( FILL )
	form.LabelWidth = 120
	form:AddParagraph( "Adjust the settings on this page to customize light appearance and performance options." )
	form:CreateCheckBoxProperty( { "ph2_enable_projectedtextures_mp", "Bool" }, "Projected Textures", true, { Descriptor = "Enable in multiplayer (expensive)" } )
	form:AddDivider()
	form:AddParagraph( "You can select a Graphics Preset to improve performance or enhance appearance." )
	form:CreateComboBoxProperty( "ph2_bloom_preset", "Graphics Preset", "Select...", { 
		{ "High Performance", "HighPerformance" },
		{ "Default", "Default" },
		{ "Vivid", "Vivid" },
		{ "Cinematic", "Cinematic" },
	})
	form:AddCallback( "ph2_bloom_preset", form, function( value )
		Photon2.Render.ApplyBloomSettings( value )
	end)

	form:AddParagraph( "If desired, the specific variables can be configured below." )
	form:AddDivider()
	form:CreateCheckBoxProperty( { "ph2_enable_subtractive_sprites", "Bool" }, "Subtractive 2D", true, { Descriptor = "Draw subtractive sprites" } )
	form:CreateCheckBoxProperty( { "ph2_enable_additive_sprites", "Bool" }, "Additive 2D", true, { Descriptor = "Draw additive sprites" } )
	form:AddParagraph( "Subtractive rendering increases light color saturation, while additive rendering enhances bloom intensity. You can disable these options for slightly better performance. (Applies to 2D lights only.)" )
	form:AddDivider()
	form:AddParagraph( "Bloom intensity affects the amount of additive color saturation. Higher values are more expensive to render and may introduce minor artifacting." )
	form:CreateNumericSlider( { "ph2_bloom_add_src_passes", "Int" }, "Source Intensity", 0, 0, 32, 0, { Descriptor = "Adjust the intensity of the effect" } )
	form:CreateNumericSlider( { "ph2_bloom_add_inner_passes", "Int" }, "Inner Intensity", 0, 0, 32, 0, { Descriptor = "Adjust the intensity of the effect" } )
	form:CreateNumericSlider( { "ph2_bloom_add_outer_passes", "Int" }, "Outer Intensity", 0, 0, 32, 0, { Descriptor = "Adjust the intensity of the effect" } )
	form:AddDivider()
	form:AddParagraph( "Bloom blur settings affect the spread of light blooming. Higher pass values create a smoother effect but lose apparent intensity.\n\nHigher pass numbers can affect performance. Width and height values do not." )
	form:CreateNumericSlider( { "ph2_bloom_outer_blur_passes", "Int" }, "Outer Blur Passes", 0, 0, 16, 0, { Descriptor = "Adjust the intensity of the effect" } )
	form:CreateNumericSlider( { "ph2_bloom_outer_blur_x", "Int" }, "Outer Blur Width", 0, 0, 16, 0, { Descriptor = "Adjust the intensity of the effect" } )
	form:CreateNumericSlider( { "ph2_bloom_outer_blur_y", "Int" }, "Outer Blur Height", 0, 0, 16, 0, { Descriptor = "Adjust the intensity of the bloom effect" } )
	form:CreateNumericSlider( { "ph2_bloom_inner_blur_passes", "Int" }, "Inner Blur Passes", 0, 0, 16, 0, { Descriptor = "Adjust the intensity of the effect" } )
	form:CreateNumericSlider( { "ph2_bloom_inner_blur_x", "Int" }, "Inner Blur Width", 0, 0, 16, 0, { Descriptor = "Adjust the intensity of the effect" } )
	form:CreateNumericSlider( { "ph2_bloom_inner_blur_y", "Int" }, "Inner Blur Height", 0, 0, 16, 0, { Descriptor = "Adjust the intensity of the effect" } )
end

function PANEL:SetupHudOptions()
	local panel = vgui.Create( "DPanel", self )
	self.HudPage = panel
	panel:Dock( FILL )
	panel:DockMargin( 4, -4, 4, 4 )
	panel:DockPadding( 3, 3, 3, 3 )
	
	-- local container = vgui.Create( "DScrollPanel", panel )
	-- container:Dock( FILL )

	
	local form = vgui.Create( "Photon2UIFormPanel", panel )--[[@as Photon2UIFormPanel]]
	form.LabelWidth = 120
	form:Dock( FILL )
	form:AddParagraph( "Adjust the settings on this page change the appearance and other options of the in-vehicle status HUD." )
	form:CreateCheckBoxProperty( { "ph2_hud_enabled", "Bool" }, "Visible", Photon2.HudEnabled, { Descriptor = "Show in-vehicle HUD"} )
	form:CreateCheckBoxProperty( { "ph2_hud_draggable", "Bool" }, "Draggable", Photon2.HudDraggable, { Descriptor = "Enable HUD dragging" } )
	form:AddDivider()
	form:CreateColorProperty( { "ph2_hud_color_panel_active", "String" }, "Panel" )
	form:CreateColorProperty( { "ph2_hud_color_panel_inactive", "String" }, "Panel (Inactive)" )
	form:CreateColorProperty( { "ph2_hud_color_panel_alt_active", "String" }, "Panel Alt" )
	form:CreateColorProperty( { "ph2_hud_color_panel_alt_inactive", "String" }, "Panel Alt (Inactive)" )
	form:CreateColorProperty( { "ph2_hud_color_accent", "String" }, "Accent" )
	form:CreateColorProperty( { "ph2_hud_color_accent_inactive", "String" }, "Accent (Inactive)" )
	form:CreateColorProperty( { "ph2_hud_color_accent_alt", "String" }, "Accent (Alt)" )
	form:AddButton( "Reset to Default", function()
		RunConsoleCommand( "ph2_hud_color_panel_active", "64,64,64,200" )
		RunConsoleCommand( "ph2_hud_color_panel_inactive", "64,64,64,100" )
		RunConsoleCommand( "ph2_hud_color_panel_alt_active", "16,16,16,200" )
		RunConsoleCommand( "ph2_hud_color_panel_alt_inactive", "16,16,16,100" )
		RunConsoleCommand( "ph2_hud_color_accent", "255,255,255,255" )
		RunConsoleCommand( "ph2_hud_color_accent_inactive", "0,0,0,128" )
		RunConsoleCommand( "ph2_hud_color_accent_alt", "255,255,255,96" )
	end)
	form:AddDivider()
	form:CreateComboBoxProperty( { "ph2_hud_anchor", "String" }, "Anchor", "Bottom Left", { 
		{ "Bottom Left", "bottom_left" },
		{ "Bottom Right", "bottom_right" },
		{ "Top Left", "top_left" },
		{ "Top Right", "top_right" }
	} )
	form:CreateNumericProperty( { "ph2_hud_offset_x", "Int" }, "X Offset", 0, 0, ScrW(), 0 )
	form:CreateNumericProperty( { "ph2_hud_offset_y", "Int" }, "Y Offset", 0, 0, ScrH(), 0 )
	form:AddParagraph("Note: These settings are automatically changed when the HUD is dragged using the cursor.")
	form:AddButton( "Reset to Default", function()
		print("Resetting to default...")
		RunConsoleCommand( "ph2_hud_enabled", "1" )
		RunConsoleCommand( "ph2_hud_offset_x", "360" )
		RunConsoleCommand( "ph2_hud_offset_y", "385" )
		RunConsoleCommand( "ph2_hud_anchor", "bottom_right" )
	end)
end

local contextMenuImage = Material( "photon/ui/misc/context_menu.png" )

function PANEL:SetupMainPage()
	local panel = vgui.Create( "DPanel", self )
	-- panel:DockMargin( 4, -4, 4, 4 )
	panel:DockMargin( 4, -4, 4, 4 )
	panel:DockPadding( 3, 3, 3, 3 )
	panel:Dock( FILL )
	self.MainPage = panel

	local content = vgui.Create( "DScrollPanel", panel )
	content:Dock( FILL )
	-- content:DockPadding( 8, 8, 8, 8 )

	local mainText = vgui.Create( "DLabel", content )
	mainText:DockMargin( 8, 8, 8, 8)
	mainText:Dock( TOP )
	mainText:SetWrap( true )
	mainText:SetAutoStretchVertical( true )
	mainText:SetText([[
You are running Photon 2. This addon is a platform for emergency vehicles and related functionality.

Navigate through the tabs above to adjust and customize feature settings. Unless otherwise noted, settings apply to the client only.]])
	mainText:SetContentAlignment( 7 )
	local contextImagePanel = vgui.Create( "DPanel", content )
	contextImagePanel:Dock( TOP )
	contextImagePanel:SetHeight( 66 )
	contextImagePanel:DockMargin( 8, 8, 8, 8)
	contextImagePanel:SetPaintBackground( false )

	local contextImage = vgui.Create( "DImage", contextImagePanel )
	contextImage:SetSize( 202, 66 )
	contextImage:SetImage( "photon/ui/misc/context_menu.png" )
	contextImage:SetKeepAspect( true )
	
	local contextLabel = vgui.Create( "DLabel", content )
	contextLabel:Dock( TOP )
	contextLabel:DockMargin( 8, 8, 8, 8)
	contextLabel:SetWrap( true )
	contextLabel:SetAutoStretchVertical( true )
	contextLabel:SetText([[
	Developer utilities and additional settings can be found in the Photon 2 context menu at the top of the window.]])

	function panel:AddButton( label, icon, onClick )
		local button = vgui.Create( "EXDButton", content )
		button:Dock( TOP )
		button:SetHeight( 28 )
		button:DockMargin( 8, 4, 8, 4 )
		button:SetText( label )
		if ( icon ) then button:SetIcon( icon ) end
		function button:DoClick()
			if ( isfunction( onClick ) ) then
				onClick()
			end
		end
	end

	panel:AddButton( "Join the Photon Discord Server", "discord", function() gui.OpenURL( "https://photon.lighting/discord" ) end )
	panel:AddButton( "Open Documentation", "bookshelf", function() gui.OpenURL( "https://photon.lighting/docs") end )
	panel:AddButton( "Key Bindings & Input Configurations", "keyboard-variant", 
		function() 
			-- if ( self.ContextParent ) then
			-- 	local window = self.ContextParent:Add( "Photon2UIInputConfiguration" )
			-- 	window:MakePopup()
			-- else
				vgui.Create( "Photon2UIInputConfiguration" ) 
			-- end
		end 
	)
	local padding = vgui.Create( "DPanel", content )
	padding:Dock( TOP )
	padding:SetHeight( 4 )
	padding:SetPaintBackground( false )
end

function PANEL:SetupOtherPage()
	local panel = vgui.Create( "DPanel", self )
	panel:Dock( FILL )
	panel:DockMargin( 4, -4, 4, 4 )
	panel:DockPadding( 3, 3, 3, 3 )
	self.OtherPage = panel
	local form = vgui.Create( "Photon2UIFormPanel", panel )--[[@as Photon2UIFormPanel]]
	form.LabelWidth = 120
	form:Dock( FILL )
	form:CreateCheckBoxProperty( { "ph2_debug_perf_overlay", "Bool" }, "Performance Info", true, { Descriptor = "Display Photon 2 performance data" } )
	form:AddParagraph( "The performance overlay shows the number of active lights being rendered and the approximate percentage of frame time consumed by Photon 2.")
	form:AddDivider()
	form:CreateCheckBoxProperty( { "ph2_enable_auto_download", "Bool" }, "Automatic Download", true, { Descriptor = "Install missing content automatically" } )
	form:AddParagraph( "Photon 2's automatic download feature will attempt to install missing Photon 2 content from Workshop on the client automatically. This is a new feature that only works with some Starter Package addons." )
	form:AddDivider()
end

function PANEL:SetupServerPage()
	local panel = vgui.Create( "DPanel", self )
	panel:Dock( FILL )
	panel:DockMargin( 4, -4, 4, 4 )
	panel:DockPadding( 3, 3, 3, 3 )
	self.ServerPage = panel
	local form = vgui.Create( "Photon2UIFormPanel", panel )--[[@as Photon2UIFormPanel]]
	form.LabelWidth = 120
	form:Dock( FILL )
	form:AddParagraph( "The features and settings on this page are server-side." )
	form:AddDivider()
	form:AddParagraph( "Vehicle idling allows an emergency vehicle to idle its engine when the driver quickly exits. The engine is turned off by briefly holding 'E' (or +use) while exiting." )
	form:CreateCheckBoxProperty( { "ph2_engine_idle_enabled", "Bool" }, "Vehicle Idling", true, { Descriptor = "Enable vehicle engine idling" } )
	form:AddDivider()
	form:AddParagraph( "The Photon 2 camera SWEP removes camera roll rotation and displays a rule-of-thirds grid. It does not replace the original camera SWEP." )
	form:CreateCheckBoxProperty( { "ph2_camera_swep_enabled", "Bool" }, "Photon 2 Camera", true, { Descriptor = "Enable Photon 2 camera" } )
end

function PANEL:PostAutoRefresh()
	self:Setup()
end

derma.DefineControl( class, "", PANEL, base )
