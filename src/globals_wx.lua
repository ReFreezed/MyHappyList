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

			-- Other: remap to WX_*
			else
				k = "WX_"..k
				-- assert(not _G[k], k)
				_G[k] = v
			end

		end
	end
end

-- Numbers.
WX_DEFAULT_COORD                    = wx.wxDefaultCoord
WX_DRAG_ALLOW_MOVE                  = wx.wxDrag_AllowMove
WX_DRAG_COPY_ONLY                   = wx.wxDrag_CopyOnly
WX_DRAG_DEFAULT_MOVE                = wx.wxDrag_DefaultMove
WX_DRAG_RESULT_CANCEL               = wx.wxDragCancel
WX_DRAG_RESULT_COPY                 = wx.wxDragCopy
WX_DRAG_RESULT_ERROR                = wx.wxDragError
WX_DRAG_RESULT_LINK                 = wx.wxDragLink
WX_DRAG_RESULT_MOVE                 = wx.wxDragMove
WX_DRAG_RESULT_NONE                 = wx.wxDragNone
WX_INVALID_TEXT_COORD               = wx.wxInvalidTextCoord
WX_LAYOUT_DIRECTION_DEFAULT         = wx.wxLayout_Default
WX_LAYOUT_DIRECTION_LEFT_TO_RIGHT   = wx.wxLayout_LeftToRight
WX_LAYOUT_DIRECTION_RIGHT_TO_LEFT   = wx.wxLayout_RightToLeft
WX_LOG_LEVEL_DEBUG                  = wx.wxLOG_Debug
WX_LOG_LEVEL_ERROR                  = wx.wxLOG_Error
WX_LOG_LEVEL_FATAL_ERROR            = wx.wxLOG_FatalError
WX_LOG_LEVEL_INFO                   = wx.wxLOG_Info
WX_LOG_LEVEL_MAX                    = wx.wxLOG_Max
WX_LOG_LEVEL_MESSAGE                = wx.wxLOG_Message
WX_LOG_LEVEL_PROGRESS               = wx.wxLOG_Progress
WX_LOG_LEVEL_STATUS                 = wx.wxLOG_Status
WX_LOG_LEVEL_TRACE                  = wx.wxLOG_Trace
WX_LOG_LEVEL_USER                   = wx.wxLOG_User
WX_LOG_LEVEL_WARNING                = wx.wxLOG_Warning
WX_OUT_CODE_INSIDE                  = wx.wxInside
WX_OUT_CODE_OUT_BOTTOM              = wx.wxOutBottom
WX_OUT_CODE_OUT_LEFT                = wx.wxOutLeft
WX_OUT_CODE_OUT_RIGHT               = wx.wxOutRight
WX_OUT_CODE_OUT_TOP                 = wx.wxOutTop
WX_OUT_OF_RANGE_TEXT_COORD          = wx.wxOutOfRangeTextCoord
WX_REGION_CONTAIN_IN_REGION         = wx.wxInRegion
WX_REGION_CONTAIN_OUT_REGION        = wx.wxOutRegion
WX_REGION_CONTAIN_PART_REGION       = wx.wxPartRegion
WX_SEEK_MODE_FROM_CURRENT           = wx.wxFromCurrent
WX_SEEK_MODE_FROM_END               = wx.wxFromEnd
WX_SEEK_MODE_FROM_START             = wx.wxFromStart
WX_SEEK_MODE_INVALID_OFFSET         = wx.wxInvalidOffset
WX_TEXT_ENTRY_DIALOG_STYLE          = wx.wxTextEntryDialogStyle
WX_TREE_ITEM_ICON_EXPANDED          = wx.wxTreeItemIcon_Expanded
WX_TREE_ITEM_ICON_MAX               = wx.wxTreeItemIcon_Max
WX_TREE_ITEM_ICON_NORMAL            = wx.wxTreeItemIcon_Normal
WX_TREE_ITEM_ICON_SELECTED          = wx.wxTreeItemIcon_Selected
WX_TREE_ITEM_ICON_SELECTED_EXPANDED = wx.wxTreeItemIcon_SelectedExpanded

-- wxBrush
WX_BRUSH_BLACK                      = wx.wxBLACK_BRUSH
WX_BRUSH_BLUE                       = wx.wxBLUE_BRUSH
WX_BRUSH_CYAN                       = wx.wxCYAN_BRUSH
WX_BRUSH_GREEN                      = wx.wxGREEN_BRUSH
WX_BRUSH_GREY                       = wx.wxGREY_BRUSH
WX_BRUSH_LIGHT_GREY                 = wx.wxLIGHT_GREY_BRUSH
WX_BRUSH_MEDIUM_GREY                = wx.wxMEDIUM_GREY_BRUSH
WX_BRUSH_NULL                       = wx.wxNullBrush
WX_BRUSH_RED                        = wx.wxRED_BRUSH
WX_BRUSH_TRANSPARENT                = wx.wxTRANSPARENT_BRUSH
WX_BRUSH_WHITE                      = wx.wxWHITE_BRUSH

-- wxColour
WX_COLOUR_BLACK                     = wx.wxBLACK
WX_COLOUR_BLUE                      = wx.wxBLUE
WX_COLOUR_CYAN                      = wx.wxCYAN
WX_COLOUR_GREEN                     = wx.wxGREEN
WX_COLOUR_LIGHT_GREY                = wx.wxLIGHT_GREY
WX_COLOUR_Null                      = wx.wxNullColour
WX_COLOUR_RED                       = wx.wxRED
WX_COLOUR_WHITE                     = wx.wxWHITE

-- wxCursor
WX_CURSOR_CROSS                     = wx.wxCROSS_CURSOR
WX_CURSOR_HOURGLASS                 = wx.wxHOURGLASS_CURSOR
WX_CURSOR_NULL                      = wx.wxNullCursor
WX_CURSOR_STANDARD                  = wx.wxSTANDARD_CURSOR

-- wxFont
WX_FONT_ITALIC                      = wx.wxITALIC_FONT
WX_FONT_NORMAL                      = wx.wxNORMAL_FONT
WX_FONT_NULL                        = wx.wxNullFont
WX_FONT_SMALL                       = wx.wxSMALL_FONT
WX_FONT_SWISS                       = wx.wxSWISS_FONT

-- wxPen
WX_PEN_BLACK                        = wx.wxBLACK_PEN
WX_PEN_BLACK_DASHED                 = wx.wxBLACK_DASHED_PEN
WX_PEN_CYAN                         = wx.wxCYAN_PEN
WX_PEN_GREEN                        = wx.wxGREEN_PEN
WX_PEN_GREY                         = wx.wxGREY_PEN
WX_PEN_LIGHT_GREY                   = wx.wxLIGHT_GREY_PEN
WX_PEN_MEDIUM_GREY                  = wx.wxMEDIUM_GREY_PEN
WX_PEN_NULL                         = wx.wxNullPen
WX_PEN_RED                          = wx.wxRED_PEN
WX_PEN_TRANSPARENT                  = wx.wxTRANSPARENT_PEN
WX_PEN_WHITE                        = wx.wxWHITE_PEN

-- Other userdata.
WX_NULL                             = wx.NULL

WX_ACCELERATOR_TABLE_NULL           = wx.wxNullAcceleratorTable -- wxAcceleratorTable
WX_BITMAP_NULL                      = wx.wxNullBitmap           -- wxBitmap
WX_ICON_NULL                        = wx.wxNullIcon             -- wxIcon
WX_IMAGE_NULL                       = wx.wxNullImage            -- wxImage
WX_PALETTE_NULL                     = wx.wxNullPalette          -- wxPalette

WX_DEFAULT_DATE_TIME                = wx.wxDefaultDateTime      -- wxDateTime
WX_DEFAULT_POSITION                 = wx.wxDefaultPosition      -- wxPoint
WX_DEFAULT_SIZE                     = wx.wxDefaultSize          -- wxSize
WX_DEFAULT_VALIDATOR                = wx.wxDefaultValidator     -- wxValidator
WX_DEFAULT_VIDEO_MODE               = wx.wxDefaultVideoMode     -- wxVideoMode

WX_INVALID_DATA_FORMAT              = wx.wxFormatInvalid        -- wxDataFormat
WX_NO_GRID_CELL_RECT                = wx.wxGridNoCellRect       -- wxGridCellCoords (should this be wxGridNoCellCoords?)

WX_THE_BRUSH_LIST                   = wx.wxTheBrushList         -- wxBrushList
WX_THE_FONT_LIST                    = wx.wxTheFontList          -- wxFontList
WX_THE_MIME_TYPES_MANAGER           = wx.wxTheMimeTypesManager  -- wxMimeTypesManager
WX_THE_PEN_LIST                     = wx.wxThePenList           -- wxPenList

-- Common constructors.
WxPoint = wx.wxPoint
WxSize  = wx.wxSize
