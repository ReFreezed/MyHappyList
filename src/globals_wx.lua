--==============================================================
--=
--=  Globals - wxWidgets Stuff
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--==============================================================

-- wx    - wxWidgets functions, classes, defines, enums, strings, events, and objects are placed here.
-- wxlua - Special functions for introspecting into wxLua or generic functions that wxLua provides that are independent of wxWidgets.
-- wxaui - The wxWidgets Advanced User Interface library.
-- wxstc - The wxStyledTextCtrl wrapper around the Scintilla text editor.
-- bit   - The bit library from Reuben Thomas for manipulating integer bits.

require"wx" -- Adds globals: wx, wxlua, wxaui, wxstc.

wxPrint   = print
print     = print_lua

bit       = nil
print_lua = nil

wxPleaseJustStop = wx.wxLogNull() -- Ugh.

-- Things that look like constants.
for _, t in ipairs{wx, wxlua} do
	for k, v in pairs(t) do
		k = k:gsub("^wx", "")

		if k == k:upper() and (type(v) == "number" or type(v) == "string") then

			-- Key code: remap WXK_* to KC_*
			if k:find"^WXK_" then
				k = k:gsub("^WXK", "KC")
				-- assert(not _G[k], k)
				_G[k] = v

			-- Other: remap to wx*
			else
				k = "wx"..k
				-- assert(not _G[k], k)
				_G[k] = v
			end

		end
	end
end

-- Numbers.
wxDEFAULT_COORD                    = wx.wxDefaultCoord
wxDRAG_ALLOW_MOVE                  = wx.wxDrag_AllowMove
wxDRAG_COPY_ONLY                   = wx.wxDrag_CopyOnly
wxDRAG_DEFAULT_MOVE                = wx.wxDrag_DefaultMove
wxDRAG_RESULT_CANCEL               = wx.wxDragCancel
wxDRAG_RESULT_COPY                 = wx.wxDragCopy
wxDRAG_RESULT_ERROR                = wx.wxDragError
wxDRAG_RESULT_LINK                 = wx.wxDragLink
wxDRAG_RESULT_MOVE                 = wx.wxDragMove
wxDRAG_RESULT_NONE                 = wx.wxDragNone
wxINVALID_TEXT_COORD               = wx.wxInvalidTextCoord
wxLAYOUT_DIRECTION_DEFAULT         = wx.wxLayout_Default
wxLAYOUT_DIRECTION_LEFT_TO_RIGHT   = wx.wxLayout_LeftToRight
wxLAYOUT_DIRECTION_RIGHT_TO_LEFT   = wx.wxLayout_RightToLeft
wxLOG_LEVEL_DEBUG                  = wx.wxLOG_Debug
wxLOG_LEVEL_ERROR                  = wx.wxLOG_Error
wxLOG_LEVEL_FATAL_ERROR            = wx.wxLOG_FatalError
wxLOG_LEVEL_INFO                   = wx.wxLOG_Info
wxLOG_LEVEL_MAX                    = wx.wxLOG_Max
wxLOG_LEVEL_MESSAGE                = wx.wxLOG_Message
wxLOG_LEVEL_PROGRESS               = wx.wxLOG_Progress
wxLOG_LEVEL_STATUS                 = wx.wxLOG_Status
wxLOG_LEVEL_TRACE                  = wx.wxLOG_Trace
wxLOG_LEVEL_USER                   = wx.wxLOG_User
wxLOG_LEVEL_WARNING                = wx.wxLOG_Warning
wxOUT_CODE_INSIDE                  = wx.wxInside
wxOUT_CODE_OUT_BOTTOM              = wx.wxOutBottom
wxOUT_CODE_OUT_LEFT                = wx.wxOutLeft
wxOUT_CODE_OUT_RIGHT               = wx.wxOutRight
wxOUT_CODE_OUT_TOP                 = wx.wxOutTop
wxOUT_OF_RANGE_TEXT_COORD          = wx.wxOutOfRangeTextCoord
wxREGION_CONTAIN_IN_REGION         = wx.wxInRegion
wxREGION_CONTAIN_OUT_REGION        = wx.wxOutRegion
wxREGION_CONTAIN_PART_REGION       = wx.wxPartRegion
wxSEEK_MODE_FROM_CURRENT           = wx.wxFromCurrent
wxSEEK_MODE_FROM_END               = wx.wxFromEnd
wxSEEK_MODE_FROM_START             = wx.wxFromStart
wxSEEK_MODE_INVALID_OFFSET         = wx.wxInvalidOffset
wxTEXT_ENTRY_DIALOG_STYLE          = wx.wxTextEntryDialogStyle
wxTREE_ITEM_ICON_EXPANDED          = wx.wxTreeItemIcon_Expanded
wxTREE_ITEM_ICON_MAX               = wx.wxTreeItemIcon_Max
wxTREE_ITEM_ICON_NORMAL            = wx.wxTreeItemIcon_Normal
wxTREE_ITEM_ICON_SELECTED          = wx.wxTreeItemIcon_Selected
wxTREE_ITEM_ICON_SELECTED_EXPANDED = wx.wxTreeItemIcon_SelectedExpanded

-- wxBrush
wxBRUSH_BLACK                      = wx.wxBLACK_BRUSH
wxBRUSH_BLUE                       = wx.wxBLUE_BRUSH
wxBRUSH_CYAN                       = wx.wxCYAN_BRUSH
wxBRUSH_GREEN                      = wx.wxGREEN_BRUSH
wxBRUSH_GREY                       = wx.wxGREY_BRUSH
wxBRUSH_LIGHT_GREY                 = wx.wxLIGHT_GREY_BRUSH
wxBRUSH_MEDIUM_GREY                = wx.wxMEDIUM_GREY_BRUSH
wxBRUSH_NULL                       = wx.wxNullBrush
wxBRUSH_RED                        = wx.wxRED_BRUSH
wxBRUSH_TRANSPARENT                = wx.wxTRANSPARENT_BRUSH
wxBRUSH_WHITE                      = wx.wxWHITE_BRUSH

-- wxColour
wxCOLOUR_BLACK                     = wx.wxBLACK
wxCOLOUR_BLUE                      = wx.wxBLUE
wxCOLOUR_CYAN                      = wx.wxCYAN
wxCOLOUR_GREEN                     = wx.wxGREEN
wxCOLOUR_LIGHT_GREY                = wx.wxLIGHT_GREY
wxCOLOUR_NULL                      = wx.wxNullColour
wxCOLOUR_RED                       = wx.wxRED
wxCOLOUR_WHITE                     = wx.wxWHITE

-- wxCursor
wxCURSOR_CROSS                     = wx.wxCROSS_CURSOR
wxCURSOR_HOURGLASS                 = wx.wxHOURGLASS_CURSOR
wxCURSOR_NULL                      = wx.wxNullCursor
wxCURSOR_STANDARD                  = wx.wxSTANDARD_CURSOR

-- wxFont
wxFONT_ITALIC                      = wx.wxITALIC_FONT
wxFONT_NORMAL                      = wx.wxNORMAL_FONT
wxFONT_NULL                        = wx.wxNullFont
wxFONT_SMALL                       = wx.wxSMALL_FONT
wxFONT_SWISS                       = wx.wxSWISS_FONT

-- wxPen
wxPEN_BLACK                        = wx.wxBLACK_PEN
wxPEN_BLACK_DASHED                 = wx.wxBLACK_DASHED_PEN
wxPEN_CYAN                         = wx.wxCYAN_PEN
wxPEN_GREEN                        = wx.wxGREEN_PEN
wxPEN_GREY                         = wx.wxGREY_PEN
wxPEN_LIGHT_GREY                   = wx.wxLIGHT_GREY_PEN
wxPEN_MEDIUM_GREY                  = wx.wxMEDIUM_GREY_PEN
wxPEN_NULL                         = wx.wxNullPen
wxPEN_RED                          = wx.wxRED_PEN
wxPEN_TRANSPARENT                  = wx.wxTRANSPARENT_PEN
wxPEN_WHITE                        = wx.wxWHITE_PEN

-- Other userdata.
wxNULL                             = wx.NULL

wxACCELERATOR_TABLE_NULL           = wx.wxNullAcceleratorTable -- wxAcceleratorTable
wxBITMAP_NULL                      = wx.wxNullBitmap           -- wxBitmap
wxICON_NULL                        = wx.wxNullIcon             -- wxIcon
wxIMAGE_NULL                       = wx.wxNullImage            -- wxImage
wxPALETTE_NULL                     = wx.wxNullPalette          -- wxPalette

wxDEFAULT_DATE_TIME                = wx.wxDefaultDateTime      -- wxDateTime
wxDEFAULT_POSITION                 = wx.wxDefaultPosition      -- wxPoint
wxDEFAULT_SIZE                     = wx.wxDefaultSize          -- wxSize
wxDEFAULT_VALIDATOR                = wx.wxDefaultValidator     -- wxValidator
wxDEFAULT_VIDEO_MODE               = wx.wxDefaultVideoMode     -- wxVideoMode

wxINVALID_DATA_FORMAT              = wx.wxFormatInvalid        -- wxDataFormat
wxNO_GRID_CELL_RECT                = wx.wxGridNoCellRect       -- wxGridCellCoords (should this be wxGridNoCellCoords?)

wxTHE_BRUSH_LIST                   = wx.wxTheBrushList         -- wxBrushList
wxTHE_FONT_LIST                    = wx.wxTheFontList          -- wxFontList
wxTHE_MIME_TYPES_MANAGER           = wx.wxTheMimeTypesManager  -- wxMimeTypesManager
wxTHE_PEN_LIST                     = wx.wxThePenList           -- wxPenList

-- Custom helpers.
wxGROW_ALL  = wxGROW + wxALL
wxICON_NONE = 0

-- Common constructors.
WxPoint = wx.wxPoint -- @Cleanup: Export all wx.wx* into _G.wx* .
WxRect  = wx.wxRect
WxSize  = wx.wxSize
