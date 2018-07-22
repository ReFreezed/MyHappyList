--[[============================================================
--=
--=  Globals - Key Codes
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--==============================================================

From wxKeyCode:

KC_ADD
KC_ALT
KC_BACK     -- Backspace.
KC_CANCEL
KC_CAPITAL  -- Caps lock.
KC_CLEAR
KC_CONTROL
KC_DECIMAL
KC_DELETE
KC_DIVIDE
KC_DOWN
KC_ESCAPE
KC_EXECUTE
KC_F1 .. KC_F24
KC_HELP
KC_HOME, KC_END
KC_INSERT
KC_LBUTTON, KC_MBUTTON, KC_RBUTTON
KC_LEFT
KC_MENU
KC_MULTIPLY
KC_NEXT
KC_NUMLOCK
KC_NUMPAD0 .. KC_NUMPAD9
KC_NUMPAD_ADD
KC_NUMPAD_BEGIN
KC_NUMPAD_DECIMAL
KC_NUMPAD_DELETE
KC_NUMPAD_DIVIDE
KC_NUMPAD_DOWN
KC_NUMPAD_ENTER
KC_NUMPAD_EQUAL
KC_NUMPAD_F1 .. KC_NUMPAD_F4
KC_NUMPAD_HOME, KC_NUMPAD_END
KC_NUMPAD_INSERT
KC_NUMPAD_LEFT
KC_NUMPAD_MULTIPLY
KC_NUMPAD_NEXT
KC_NUMPAD_PAGEUP, KC_NUMPAD_PAGEDOWN
KC_NUMPAD_PRIOR
KC_NUMPAD_RIGHT
KC_NUMPAD_SEPARATOR
KC_NUMPAD_SPACE
KC_NUMPAD_SUBTRACT
KC_NUMPAD_TAB
KC_NUMPAD_UP
KC_PAGEUP, KC_PAGEDOWN
KC_PAUSE
KC_PRINT
KC_PRIOR
KC_RETURN
KC_RIGHT
KC_SCROLL  -- Scroll lock.
KC_SELECT
KC_SEPARATOR
KC_SHIFT
KC_SNAPSHOT
KC_SPACE
KC_START
KC_SUBTRACT
KC_TAB
KC_UP

--============================================================]]

local sbyte = string.byte

KC_0           = sbyte"0"
KC_1           = sbyte"1"
KC_2           = sbyte"2"
KC_3           = sbyte"3"
KC_4           = sbyte"4"
KC_5           = sbyte"5"
KC_6           = sbyte"6"
KC_7           = sbyte"7"
KC_8           = sbyte"8"
KC_9           = sbyte"9"
KC_A           = sbyte"A"
KC_B           = sbyte"B"
KC_C           = sbyte"C"
KC_D           = sbyte"D"
KC_E           = sbyte"E"
KC_F           = sbyte"F"
KC_G           = sbyte"G"
KC_H           = sbyte"H"
KC_I           = sbyte"I"
KC_J           = sbyte"J"
KC_K           = sbyte"K"
KC_L           = sbyte"L"
KC_M           = sbyte"M"
KC_N           = sbyte"N"
KC_O           = sbyte"O"
KC_P           = sbyte"P"
KC_Q           = sbyte"Q"
KC_R           = sbyte"R"
KC_S           = sbyte"S"
KC_T           = sbyte"T"
KC_U           = sbyte"U"
KC_V           = sbyte"V"
KC_W           = sbyte"W"
KC_X           = sbyte"X"
KC_Y           = sbyte"Y"
KC_Z           = sbyte"Z"

KC_APOSTROPHE  = sbyte"'"
KC_COMMA       = sbyte","
KC_MINUS       = sbyte"-"
KC_PERIOD      = sbyte"."
KC_PLUS        = sbyte"+"

KC_GUI         = 393 -- Command / Windows / super.
KC_APPLICATION = 395 -- Windows contextual menu / compose.
