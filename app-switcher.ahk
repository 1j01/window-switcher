; Requires AutoHotkey v2

;--------------------------------------------------------
; App Switcher
;--------------------------------------------------------

WM_GETICON := 0x007F

ICON_BIG := 1
ICON_SMALL := 0
ICON_SMALL2 := 2

GCW_ATOM := -32 ; Retrieves an ATOM value that uniquely identifies the window class. This is the same atom that the RegisterClassEx function returns.
GCL_CBCLSEXTRA := -20 ; Retrieves the size, in bytes, of the extra memory associated with the class.
GCL_CBWNDEXTRA := -18 ; Retrieves the size, in bytes, of the extra window memory associated with each window in the class. For information on how to access this memory, see GetWindowLongPtr.
GCLP_HBRBACKGROUND := -10 ; Retrieves a handle to the background brush associated with the class.
GCLP_HCURSOR := -12 ; Retrieves a handle to the cursor associated with the class.
GCLP_HICON := -14 ; Retrieves a handle to the icon associated with the class.
GCLP_HICONSM := -34 ; Retrieves a handle to the small icon associated with the class.
GCLP_HMODULE := -16 ; Retrieves a handle to the module that registered the class.
GCLP_MENUNAME := -8 ; Retrieves the pointer to the menu name string. The string identifies the menu resource associated with the class.
GCL_STYLE := -26 ; Retrieves the window-class style bits.
GCLP_WNDPROC := -24 ; Retrieves the address of the window procedure, or a handle representing the address of the window procedure. You must use the CallWindowProc function to call the window procedure.

WS_CHILD := 0x40000000
WS_THICKFRAME := 0x00040000

WS_EX_APPWINDOW := 0x00040000
WS_EX_TOOLWINDOW := 0x00000080

SS_WORDELLIPSIS := 0x0000C000
SS_NOPREFIX := 0x00000080

; ; DWMWINDOWATTRIBUTE enum
; DWMWA_WINDOW_CORNER_PREFERENCE := 33

; ; DWM_WINDOW_CORNER_PREFERENCE enum
; DWMWCP_DEFAULT := 0
; DWMWCP_DONOTROUND := 1
; DWMWCP_ROUND := 2
; DWMWCP_ROUNDSMALL := 3

; DwmSetWindowAttribute(hwnd, attribute, pvAttribute, cbAttribute) {
; 	DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", pvAttribute, "int*", true, "int", cbAttribute)
; }


GetAppIconHandle(hwnd) {
	iconHandle := 0
	try {
		iconHandle := SendMessage(WM_GETICON, ICON_SMALL2, 0, , hwnd)
	} catch {
	}
	if (!iconHandle) {
		try {
			iconHandle := SendMessage(WM_GETICON, ICON_SMALL, 0, , hwnd)
		} catch {
		}
	}
	if (!iconHandle) {
		try {
			iconHandle := SendMessage(WM_GETICON, ICON_BIG, 0, , hwnd)
		} catch {
		}
	}
	if (!iconHandle) {
		try {
			iconHandle := GetClassLongPtrA(hwnd, GCLP_HICON)
		} catch {
		}
	}
	if (!iconHandle) {
		try {
			iconHandle := GetClassLongPtrA(hwnd, GCLP_HICONSM)
		} catch {
		}
	}
	if (!iconHandle) {
		try {
			return 0
		} catch {
		}
	}

	return iconHandle
}

GetClassLongPtrA(hwnd, nIndex) {
	return DllCall("GetClassLongPtrA", "Ptr", hwnd, "int", nIndex, "Ptr")
}

Switchable(Window) {
	; Heuristics determine if a window is in the taskbar
	; https://stackoverflow.com/a/2262791
	; TODO: priority of conditions (I couldn't find a definitive source, but someone gives an order in one of the answers)
	ExStyle := WinGetExStyle(Window)
	if ExStyle & WS_EX_TOOLWINDOW {
		return false
	}
	if ExStyle & WS_EX_APPWINDOW {
		return true
	}
	Style := WinGetStyle(Window)
	return !(Style & WS_CHILD)
}

global AppSwitcher := 0
global AppSwitcherOpen := false ; could use AppSwitcher
global FocusRingByHWND := Map()

#MaxThreadsPerHotkey 2 ; Needed to handle tabbing through apps while the switcher is open

ShowAppSwitcher(Apps) {
	global AppSwitcher := Gui()
	for index, app in Apps {
		FocusRing := AppSwitcher.Add("Pic", "yM w128 h128 Section", "app-border-white.png")
		FocusRingByHWND[app.HWND] := FocusRing
		OuterSize := 128
		IconSize := 32  ; TODO: get actual size of icon
		BorderSize := 8
		TextWidth := OuterSize - 2 * BorderSize
		Offset := (OuterSize - IconSize) / 2
		TextY := (OuterSize + IconSize) / 2 + BorderSize
		TextHeight := OuterSize - TextY - BorderSize
		; TODO: error handling for below line, presumably loading the icon can fail, but I don't know in what cases
		AppSwitcher.Add("Pic", "ys+" Offset " xs+" Offset " Tabstop vPicForAppWithHWND" app.HWND, "HICON:*" app.Icon)
		AppSwitcher.Add("Text", "w" TextWidth " h" TextHeight " xs+" BorderSize " ys+" TextY " center " SS_WORDELLIPSIS " " SS_NOPREFIX, app.Title)
	}
	AppSwitcher.OnEvent("Escape", (*) => AppSwitcher.Destroy())
	AppSwitcher.Opt("+AlwaysOnTop -SysMenu -Caption " WS_THICKFRAME)
	AppSwitcher.Show
	; DwmSetWindowAttribute(AppSwitcher.Hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND, 4)  ; Assuming uint size is 4 bytes
}

LastFocusHighlight := 0
UpdateFocusHighlight() {
	global LastFocusHighlight
	Pic := AppSwitcher.FocusedCtrl
	if LastFocusHighlight {
		try {
			LastFocusHighlight.Value := "app-border-white.png"
		} catch {
			; App switcher closed and destroyed the control
		}
	}
	FocusRing := FocusRingByHWND[Integer(StrSplit(Pic.Name, "PicForAppWithHWND")[2])]
	FocusRing.Value := "app-border-blue.png"
	LastFocusHighlight := FocusRing
}

#Tab::
+#Tab:: {
	global AppSwitcherOpen
	if AppSwitcherOpen {
		if GetKeyState("Shift") {
			Send "+{Tab}"
		} else {
			Send "{Tab}"
		}
		UpdateFocusHighlight()
		return
	}
	; TODO: sort list of apps by recency, considering all windows, not just one per app,
	; and focus the next one after the current active window's app
	; TODO: get app names from shortcut files like task bar seems to? or from task bar somehow?
	; Right now Chrome apps show up as Google Chrome, unseparated from browser windows, unlike on the task bar.
	; If you right click on the taskbar button, it shows the Chrome app's name, and if you right click on that and click "Properties"
	; you can see shortcut information. In the General tab, the Location will be something like
	; `C:\Users\Isaiah\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar` or
	; `C:\Users\Isaiah\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Chrome Apps`
	; depending on whether the app is pinned to the task bar or not.

	AllWindows := WinGetList()
	; WindowsByProcessPath := Map()
	ProcessPaths := []
	Apps := Map()
	for Window in AllWindows {
		if !Switchable(Window) {
			continue
		}
		ProcessPath := WinGetProcessPath(Window)
		ProcessPaths.Push(ProcessPath)
		; if !WindowsByProcessPath.Has(ProcessPath) {
		; 	WindowsByProcessPath[ProcessPath] := []
		; }
		; WindowsByProcessPath[ProcessPath].Push(Window)
	}
	; for ProcessPath, Windows in WindowsByProcessPath {
	for ProcessPath in ProcessPaths {
		try {
			Window := WinGetID("ahk_exe " ProcessPath)
		} catch TargetError {
			continue
		}
		iconHandle := GetAppIconHandle(Window)
		if (iconHandle) {
			ProcessPath := WinGetProcessPath(Window)
			try {
				Info := FileGetVersionInfo_AW(ProcessPath, ["FileDescription", "ProductName"])
				Title := Info["FileDescription"] ? Info["FileDescription"] : Info["ProductName"]
				; Title := Info["ProductName"] ? Info["ProductName"] : Info["FileDescription"]
			} catch {
				Title := WinGetTitle(Window)
			}
			Apps[ProcessPath] := {
				Icon: GetAppIconHandle(Window),
				Title: Title,
				HWND: Window,
			}
		}
	}
	ShowAppSwitcher(Apps)
	AppSwitcherOpen := true
	UpdateFocusHighlight()
	if GetKeyState("LWin") {
		KeyWait "LWin"
	} else if GetKeyState("RWin") { ; just to be sure we don't wait forever in case the key was released quickly
		KeyWait "RWin"
	}
	SelectedPic := AppSwitcher.FocusedCtrl
	SelectedHWND := Integer(StrSplit(SelectedPic.Name, "PicForAppWithHWND")[2])
	AppSwitcher.Destroy()
	AppSwitcherOpen := false
	WinActivate(SelectedHWND)
}

DescribeWindow(Window) {
	try {
		return "Window Title: " WinGetTitle(Window) "`nWindow Class: " WinGetClass(Window) "`nProcess Path: " WinGetProcessPath(Window)
	} catch TargetError {
		return "Nonexistent window"
	}
}
FileGetVersionInfo_AW(PEFile := "", Fields := ["FileDescription"]) {
	; Written by SKAN
	; https://www.autohotkey.com/forum/viewtopic.php?t=64128       CD:24-Nov-2008 / LM:28-May-2010
	; Updated for AHK v2 by 1j01                                   2024-02-12
	DLL := "Version\"
	if !FVISize := DllCall(DLL "GetFileVersionInfoSizeW", "Str", PEFile, "UInt", 0) {
		throw Error("Unable to retrieve size of file version information.")
	}
	FVI := Buffer(FVISize, 0)
	Translation := 0
	DllCall(DLL "GetFileVersionInfoW", "Str", PEFile, "Int", 0, "UInt", FVISize, "Ptr", FVI)
	if !DllCall(DLL "VerQueryValueW", "Ptr", FVI, "Str", "\VarFileInfo\Translation", "UInt*", &Translation, "UInt", 0) {
		throw Error("Unable to retrieve file version translation information.")
	}
	TranslationHex := Buffer(16)
	if !DllCall("wsprintf", "Ptr", TranslationHex, "Str", "%08X", "UInt", NumGet(Translation + 0, "UPtr"), "Cdecl") {
		throw Error("Unable to format number as hexadecimal.")
	}
	TranslationHex := StrGet(TranslationHex, , "UTF-16")
	TranslationCode := SubStr(TranslationHex, -4) SubStr(TranslationHex, 1, 4)
	PropertiesMap := Map()
	for Field in Fields {
		SubBlock := "\StringFileInfo\" TranslationCode "\" Field
		InfoPtr := 0
		if !DllCall(DLL "VerQueryValueW", "Ptr", FVI, "Str", SubBlock, "UIntP", &InfoPtr, "UInt", 0) {
			continue
		}
		Value := DllCall("MulDiv", "UInt", InfoPtr, "Int", 1, "Int", 1, "Str")
		PropertiesMap[Field] := Value
	}
	return PropertiesMap
}


;--------------------------------------------------------
; AUTO RELOAD THIS SCRIPT
;--------------------------------------------------------
~^s:: {
	if WinActive(A_ScriptName) {
		MakeSplash("AHK Auto-Reload", "`n  Reloading " A_ScriptName "  `n", 500)
		Reload
	}
}
MakeSplash(Title, Text, Duration := 0) {
	SplashGui := Gui(, Title)
	SplashGui.Opt("+AlwaysOnTop +Disabled -SysMenu +Owner")  ; +Owner avoids a taskbar button.
	SplashGui.Add("Text", , Text)
	SplashGui.Show("NoActivate")  ; NoActivate avoids deactivating the currently active window.
	if Duration {
		Sleep(Duration)
		SplashGui.Destroy()
	}
	return SplashGui
}