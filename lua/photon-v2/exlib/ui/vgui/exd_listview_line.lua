
local PANEL = {}

function PANEL:Init()

	self:SetTextInset( 5, 0 )
	self:SetContentAlignment(4)

end

function PANEL:UpdateColours( skin )

	if ( self:GetParent().LineDisabled ) then
		self:SetTextStyleColor( skin.Colours.Label.Disabled )
		return
	end

	if ( self:GetParent():IsLineSelected() ) then return self:SetTextStyleColor( skin.Colours.Label.Bright ) end
		
	self:SetTextStyleColor( skin.Colours.Label.Dark )

end

function PANEL:GenerateExample()

	-- Do nothing!

end

function PANEL:Paint( w, h )

	-- derma.SkinHook( "Paint", "MenuOption", self, w, h )

	--
	-- Draw the button text
	--
	return false

end

derma.DefineControl( "EXDListViewLabel", "", PANEL, "EXDButton" )

--[[---------------------------------------------------------
	DListView_Line
-----------------------------------------------------------]]

local PANEL = {}

Derma_Hook( PANEL, "Paint", "Paint", "ListViewLine" )
Derma_Hook( PANEL, "ApplySchemeSettings", "Scheme", "ListViewLine" )
Derma_Hook( PANEL, "PerformLayout", "Layout", "ListViewLine" )

AccessorFunc( PANEL, "m_iID", "ID" )
AccessorFunc( PANEL, "m_pListView", "ListView" )
AccessorFunc( PANEL, "m_bAlt", "AltLine" )

function PANEL:Init()

	self:SetSelectable( true )
	self:SetMouseInputEnabled( true )

	self.Columns = {}
	self.Data = {}

end

function PANEL:OnSelect()

	-- For override

end

function PANEL:OnRightClick()

	-- For override

end

function PANEL:OnMousePressed( mcode )

	if ( mcode == MOUSE_RIGHT ) then

		-- This is probably the expected behaviour..
		if ( !self:IsLineSelected() ) then

			self:GetListView():OnClickLine( self, true )
			self:OnSelect()

		end

		self:GetListView():OnRowRightClick( self:GetID(), self )
		self:OnRightClick()

		return

	end

	self:GetListView():OnClickLine( self, true )
	self:OnSelect()

end

function PANEL:OnCursorMoved()

	if ( input.IsMouseDown( MOUSE_LEFT ) ) then
		self:GetListView():OnClickLine( self )
	end

end

function PANEL:SetSelected( b )

	self.m_bSelected = b

	-- Update colors of the lines
	for id, column in pairs( self.Columns ) do
		column:ApplySchemeSettings()
	end

end

function PANEL:IsLineSelected()

	return self.m_bSelected

end

function PANEL:EditColumnText(colIndex)
	self.Columns[colIndex]:StartEdit()
end

function PANEL:SetColumnText( i, strText, icon )

	if ( type( strText ) == "Panel" ) then

		if ( IsValid( self.Columns[ i ] ) ) then self.Columns[ i ]:Remove() end

		strText:SetParent( self )
		self.Columns[ i ] = strText
		self.Columns[ i ].Value = strText
		return

	end

	if ( !IsValid( self.Columns[ i ] ) ) then

		self.Columns[ i ] = vgui.Create( "EXDListViewLabel", self )
		self.Columns[ i ]:SetMouseInputEnabled( false )

	end

	self.Columns[ i ]:SetText( tostring( strText ) )
	self.Columns[ i ].Value = strText
	if (icon) then self.Columns[ i ]:SetIcon(icon) end
	return self.Columns[ i ]

end
PANEL.SetValue = PANEL.SetColumnText

function PANEL:GetColumnText( i )

	if ( !self.Columns[ i ] ) then return "" end

	return self.Columns[ i ].Value

end

PANEL.GetValue = PANEL.GetColumnText

--[[---------------------------------------------------------
	Allows you to store data per column

	Used in the SortByColumn function for incase you want to
	sort with something else than the text
-----------------------------------------------------------]]
function PANEL:SetSortValue( i, data )

	self.Data[ i ] = data

end

function PANEL:GetSortValue( i )

	return self.Data[ i ]

end

function PANEL:DataLayout( ListView )

	self:ApplySchemeSettings()

	local height = self:GetTall()

	local x = 0
	for k, Column in pairs( self.Columns ) do

		local w = ListView:ColumnWidth( k )
		Column:SetPos( x, 0 )
		Column:SetSize( w, height )
		x = x + w

	end

end

derma.DefineControl( "EXDListViewLine", "A line from the List View", PANEL, "Panel" )
derma.DefineControl( "EXDListView_Line", "A line from the List View", PANEL, "Panel" )