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

-- Quick'n'dirty export.
for _, t in ipairs{wx, wxlua} do
	for k0, v in pairs(t) do
		local k = k0:gsub("^wx", "")

		-- Constants.
		if k == k:upper() and (type(v) == "number" or type(v) == "string" or type(v) == "userdata") then

			-- Key code: remap WXK_* to KC_*
			if k:find"^WXK_" then
				k = k:gsub("^WXK", "KC")
				-- assert(not _G[k], k)
				_G[k] = v

			-- Other: remap to wx*
			else
				k = "wx"..k
				if _G[k] ~= v then
					-- assert(not _G[k], k)
					_G[k] = v
				end
			end

		-- Classes and functions.
		elseif k0:find"^wx" and (
			type(v) == "table" or
			type(v) == "function" and not k:find("_", 1, true)
		) then
			-- assert(not _G[k0], k0)
			_G[k0] = v
		end
	end
end

local function add(k, t, tk)
	-- assert(t[tk], tk)
	-- assert(not _G[k], k)
	_G[k] = t[tk]
end

local function rename(kNew, kOld)
	-- assert(_G[kOld], kOld)
	-- assert(not _G[kNew], kNew)
	_G[kNew] = _G[kOld]
	_G[kOld] = nil
end

-- Numbers.
add   ("wxDEFAULT_COORD",                    wx, "wxDefaultCoord")
add   ("wxDRAG_ALLOW_MOVE",                  wx, "wxDrag_AllowMove")
add   ("wxDRAG_COPY_ONLY",                   wx, "wxDrag_CopyOnly")
add   ("wxDRAG_DEFAULT_MOVE",                wx, "wxDrag_DefaultMove")
add   ("wxDRAG_RESULT_CANCEL",               wx, "wxDragCancel")
add   ("wxDRAG_RESULT_COPY",                 wx, "wxDragCopy")
add   ("wxDRAG_RESULT_ERROR",                wx, "wxDragError")
add   ("wxDRAG_RESULT_LINK",                 wx, "wxDragLink")
add   ("wxDRAG_RESULT_MOVE",                 wx, "wxDragMove")
add   ("wxDRAG_RESULT_NONE",                 wx, "wxDragNone")
add   ("wxINVALID_TEXT_COORD",               wx, "wxInvalidTextCoord")
add   ("wxLAYOUT_DIRECTION_DEFAULT",         wx, "wxLayout_Default")
add   ("wxLAYOUT_DIRECTION_LEFT_TO_RIGHT",   wx, "wxLayout_LeftToRight")
add   ("wxLAYOUT_DIRECTION_RIGHT_TO_LEFT",   wx, "wxLayout_RightToLeft")
add   ("wxLOG_LEVEL_DEBUG",                  wx, "wxLOG_Debug")
add   ("wxLOG_LEVEL_ERROR",                  wx, "wxLOG_Error")
add   ("wxLOG_LEVEL_FATAL_ERROR",            wx, "wxLOG_FatalError")
add   ("wxLOG_LEVEL_INFO",                   wx, "wxLOG_Info")
add   ("wxLOG_LEVEL_MAX",                    wx, "wxLOG_Max")
add   ("wxLOG_LEVEL_MESSAGE",                wx, "wxLOG_Message")
add   ("wxLOG_LEVEL_PROGRESS",               wx, "wxLOG_Progress")
add   ("wxLOG_LEVEL_STATUS",                 wx, "wxLOG_Status")
add   ("wxLOG_LEVEL_TRACE",                  wx, "wxLOG_Trace")
add   ("wxLOG_LEVEL_USER",                   wx, "wxLOG_User")
add   ("wxLOG_LEVEL_WARNING",                wx, "wxLOG_Warning")
add   ("wxOUT_CODE_INSIDE",                  wx, "wxInside")
add   ("wxOUT_CODE_OUT_BOTTOM",              wx, "wxOutBottom")
add   ("wxOUT_CODE_OUT_LEFT",                wx, "wxOutLeft")
add   ("wxOUT_CODE_OUT_RIGHT",               wx, "wxOutRight")
add   ("wxOUT_CODE_OUT_TOP",                 wx, "wxOutTop")
add   ("wxOUT_OF_RANGE_TEXT_COORD",          wx, "wxOutOfRangeTextCoord")
add   ("wxREGION_CONTAIN_IN_REGION",         wx, "wxInRegion")
add   ("wxREGION_CONTAIN_OUT_REGION",        wx, "wxOutRegion")
add   ("wxREGION_CONTAIN_PART_REGION",       wx, "wxPartRegion")
add   ("wxSEEK_MODE_FROM_CURRENT",           wx, "wxFromCurrent")
add   ("wxSEEK_MODE_FROM_END",               wx, "wxFromEnd")
add   ("wxSEEK_MODE_FROM_START",             wx, "wxFromStart")
add   ("wxSEEK_MODE_INVALID_OFFSET",         wx, "wxInvalidOffset")
add   ("wxTEXT_ENTRY_DIALOG_STYLE",          wx, "wxTextEntryDialogStyle")
add   ("wxTREE_ITEM_ICON_EXPANDED",          wx, "wxTreeItemIcon_Expanded")
add   ("wxTREE_ITEM_ICON_MAX",               wx, "wxTreeItemIcon_Max")
add   ("wxTREE_ITEM_ICON_NORMAL",            wx, "wxTreeItemIcon_Normal")
add   ("wxTREE_ITEM_ICON_SELECTED",          wx, "wxTreeItemIcon_Selected")
add   ("wxTREE_ITEM_ICON_SELECTED_EXPANDED", wx, "wxTreeItemIcon_SelectedExpanded")

-- Strings.
add   ("wxDIR_DIALOG_DEFAULT_FOLDER_STR",    wx, "wxDirDialogDefaultFolderStr")
add   ("wxDIR_SELECTOR_PROMPT_STR",          wx, "wxDirSelectorPromptStr")
add   ("wxFILE_SELECTOR_PROMPT_STR",         wx, "wxFileSelectorPromptStr")
add   ("wxFILE_SELECTOR_DEFAULT_WILDCARD_STR",wx,"wxFileSelectorDefaultWildcardStr")
add   ("wxGET_PASSWORD_FROM_USER_PROMPT_STR",wx, "wxGetPasswordFromUserPromptStr")

-- wxBrush
add   ("wxBRUSH_NULL",                       wx, "wxNullBrush")
rename("wxBRUSH_BLACK",                      "wxBLACK_BRUSH")
rename("wxBRUSH_BLUE",                       "wxBLUE_BRUSH")
rename("wxBRUSH_CYAN",                       "wxCYAN_BRUSH")
rename("wxBRUSH_GREEN",                      "wxGREEN_BRUSH")
rename("wxBRUSH_GREY",                       "wxGREY_BRUSH")
rename("wxBRUSH_LIGHT_GREY",                 "wxLIGHT_GREY_BRUSH")
rename("wxBRUSH_MEDIUM_GREY",                "wxMEDIUM_GREY_BRUSH")
rename("wxBRUSH_RED",                        "wxRED_BRUSH")
rename("wxBRUSH_TRANSPARENT",                "wxTRANSPARENT_BRUSH")
rename("wxBRUSH_WHITE",                      "wxWHITE_BRUSH")

-- wxColour
add   ("wxCOLOUR_NULL",                      wx, "wxNullColour")
rename("wxCOLOUR_BLACK",                     "wxBLACK")
rename("wxCOLOUR_BLUE",                      "wxBLUE")
rename("wxCOLOUR_CYAN",                      "wxCYAN")
rename("wxCOLOUR_GREEN",                     "wxGREEN")
rename("wxCOLOUR_LIGHT_GREY",                "wxLIGHT_GREY")
rename("wxCOLOUR_RED",                       "wxRED")
rename("wxCOLOUR_WHITE",                     "wxWHITE")

-- wxCursor
add   ("wxCURSOR_NULL",                       wx, "wxNullCursor")
rename("wxCURSOR_CROSS_XXX",                  "wxCROSS_CURSOR") -- Hack for wxWidgets >2.7
rename("wxCURSOR_HOURGLASS",                  "wxHOURGLASS_CURSOR")
rename("wxCURSOR_STANDARD",                   "wxSTANDARD_CURSOR")

-- wxFont
add   ("wxFONT_NULL",                        wx, "wxNullFont")
rename("wxFONT_ITALIC",                      "wxITALIC_FONT")
rename("wxFONT_NORMAL",                      "wxNORMAL_FONT")
rename("wxFONT_SMALL",                       "wxSMALL_FONT")
rename("wxFONT_SWISS",                       "wxSWISS_FONT")

-- wxPen
add   ("wxPEN_NULL",                         wx, "wxNullPen")
rename("wxPEN_BLACK",                        "wxBLACK_PEN")
rename("wxPEN_BLACK_DASHED",                 "wxBLACK_DASHED_PEN")
rename("wxPEN_CYAN",                         "wxCYAN_PEN")
rename("wxPEN_GREEN",                        "wxGREEN_PEN")
rename("wxPEN_GREY",                         "wxGREY_PEN")
rename("wxPEN_LIGHT_GREY",                   "wxLIGHT_GREY_PEN")
rename("wxPEN_MEDIUM_GREY",                  "wxMEDIUM_GREY_PEN")
rename("wxPEN_RED",                          "wxRED_PEN")
rename("wxPEN_TRANSPARENT",                  "wxTRANSPARENT_PEN")
rename("wxPEN_WHITE",                        "wxWHITE_PEN")

-- Other userdata.

add   ("wxACCELERATOR_TABLE_NULL",           wx, "wxNullAcceleratorTable") -- wxAcceleratorTable
add   ("wxBITMAP_NULL",                      wx, "wxNullBitmap")           -- wxBitmap
add   ("wxICON_NULL",                        wx, "wxNullIcon")             -- wxIcon
add   ("wxIMAGE_NULL",                       wx, "wxNullImage")            -- wxImage
add   ("wxPALETTE_NULL",                     wx, "wxNullPalette")          -- wxPalette

add   ("wxDEFAULT_DATE_TIME",                wx, "wxDefaultDateTime")      -- wxDateTime
add   ("wxDEFAULT_POSITION",                 wx, "wxDefaultPosition")      -- wxPoint
add   ("wxDEFAULT_SIZE",                     wx, "wxDefaultSize")          -- wxSize
add   ("wxDEFAULT_VALIDATOR",                wx, "wxDefaultValidator")     -- wxValidator
add   ("wxDEFAULT_VIDEO_MODE",               wx, "wxDefaultVideoMode")     -- wxVideoMode

add   ("wxINVALID_DATA_FORMAT",              wx, "wxFormatInvalid")        -- wxDataFormat
add   ("wxNO_GRID_CELL_COORDS",              wx, "wxGridNoCellCoords")       -- wxGridCellCoords (should this be wxGridNoCellCoords?)

add   ("wxTHE_BRUSH_LIST",                   wx, "wxTheBrushList")         -- wxBrushList
add   ("wxTHE_FONT_LIST",                    wx, "wxTheFontList")          -- wxFontList
add   ("wxTHE_MIME_TYPES_MANAGER",           wx, "wxTheMimeTypesManager")  -- wxMimeTypesManager
add   ("wxTHE_PEN_LIST",                     wx, "wxThePenList")           -- wxPenList

-- Custom helpers.
wxGROW_ALL  = wxGROW + wxALL -- Note: wxGROW and wxALL has nothing to do with each other.
wxICON_NONE = 0
wxMOD_NONE  = 0
