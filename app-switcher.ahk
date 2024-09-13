; Requires AutoHotkey v2
#Include "./GuiEnhancerKit.ahk"

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
; WS_THICKFRAME := 0x00040000
; WS_POPUP := 0x80000000
; WS_CLIPCHILDREN := 0x02000000

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


; https://learn.microsoft.com/en-us/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
DWMWA_USE_HOSTBACKDROPBRUSH := 16
DWMWA_SYSTEMBACKDROP_TYPE := 38
; https://learn.microsoft.com/en-us/windows/win32/api/dwmapi/ne-dwmapi-dwm_systembackdrop_type
DWMSBT_AUTO := 0
DWMSBT_NONE := 1
DWMSBT_MAINWINDOW := 2
DWMSBT_TRANSIENTWINDOW := 3
DWMSBT_TABBEDWINDOW := 4


GetAppIconHandle(hwnd) {
	iconHandle := 0
	if (!iconHandle) {
		try {
			iconHandle := SendMessage(WM_GETICON, ICON_BIG, 0, , hwnd)
		} catch {
		}
	}
	if (!iconHandle) {
		try {
			iconHandle := SendMessage(WM_GETICON, ICON_SMALL2, 0, , hwnd)
		} catch {
		}
	}
	if (!iconHandle) {
		try {
			iconHandle := SendMessage(WM_GETICON, ICON_SMALL, 0, , hwnd)
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
	global AppSwitcher := GuiExt()

	AppSwitcher.SetFont("cWhite s10", "Segoe UI")
	AppSwitcher.SetDarkTitle()  ; needed for dark window background apparently, even though there's no title bar
	AppSwitcher.SetDarkMenu()  ; should be unnecessary

	; AppSwitcher.BackColor := 0x202020
	AppSwitcher.BackColor := 0x000000

	AppSwitcher.MarginX := 30
	AppSwitcher.MarginY := 30
	for index, app in Apps {
		FocusRing := AppSwitcher.Add("Pic", "yM w128 h128 Section", "resources/app-border-inactive.png")
		FocusRingByHWND[app.HWND] := FocusRing
		OuterSize := 128
		; TODO: get actual size of icon, and allow smaller icons, but not larger than 32 since many programs have 32 as the largest icon size
		; (at least available through WM_GETICON, where you can only request 16x16 or 32x32, so if they provide 32x32, that's what is returned)
		; Or get icon from shortcut file, which could get bigger icons.
		IconSize := 32
		BorderSize := 15
		TextWidth := OuterSize - 2 * BorderSize
		Offset := (OuterSize - IconSize) / 2
		TextY := (OuterSize + IconSize) / 2 + BorderSize
		TextHeight := OuterSize - TextY - BorderSize
		try {
			AppSwitcher.Add("Pic", "ys+" Offset " xs+" Offset " w32 h32 Tabstop vPicForAppWithHWND" app.HWND, "HICON:*" app.Icon)
		} catch {
			; Loading the icon can fail, but I don't know in what cases. It just says "Failed to add control"
			AppSwitcher.Add("Pic", "ys+" Offset " xs+" Offset " w32 h32 Tabstop vPicForAppWithHWND" app.HWND, "resources/app-border-inactive.png")
		}
		AppSwitcher.Add("Text", "w" TextWidth " h" TextHeight " xs+" BorderSize " ys+" TextY " center " SS_WORDELLIPSIS " " SS_NOPREFIX, app.Title)
	}
	AppSwitcher.OnEvent("Escape", (*) => AppSwitcher.Destroy())
	AppSwitcher.Opt("+AlwaysOnTop -SysMenu -Caption -Border +Owner")
	AppSwitcher.Show

	; Enables rounded corners.
	; Doesn't seem to hide the border if the window is already shown, but `-Border` takes care of that.
	AppSwitcher.SetBorderless(6)
	; Set blur-behind accent effect. (Supported starting with Windows 11 Build 22000.)
	; Doesn't seem to work the first time. See workaround below.
	if (VerCompare(A_OSVersion, "10.0.22600") >= 0) {
		AppSwitcher.SetWindowAttribute(DWMWA_USE_HOSTBACKDROPBRUSH, true)  ; required for DWMSBT_TRANSIENTWINDOW
		AppSwitcher.SetWindowAttribute(DWMWA_SYSTEMBACKDROP_TYPE, DWMSBT_TRANSIENTWINDOW)
		; AppSwitcher.SetWindowAttribute(DWMWA_SYSTEMBACKDROP_TYPE, DWMSBT_TABBEDWINDOW)
		; AppSwitcher.SetWindowAttribute(DWMWA_SYSTEMBACKDROP_TYPE, DWMSBT_MAINWINDOW)
	}
}

; Workaround for blur-behind accent effect not working the first time the app switcher is shown.
; FIXME: the effect is still not reliably applied. This helps, but it doesn't get at the root cause.
; Hm, resizing a test window seems to make the effect work. Maybe I can trigger something like a resize event to make it work reliably.
; Or many such events? Since it updates gradually? (Is it an animation, or is it updating only slightly at a given event?)
ShowAppSwitcher([])
AppSwitcher.Destroy()


LastFocusHighlight := 0
UpdateFocusHighlight() {
	global LastFocusHighlight
	Pic := AppSwitcher.FocusedCtrl
	if LastFocusHighlight {
		try {
			LastFocusHighlight.Value := "resources/app-border-inactive.png"
		} catch {
			; App switcher closed and destroyed the control
		}
	}
	FocusRing := FocusRingByHWND[Integer(StrSplit(Pic.Name, "PicForAppWithHWND")[2])]
	FocusRing.Value := "resources/app-border-active.png"
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
	; TODO: get app names from shortcut files like task bar seems to? or from task bar somehow?
	; Right now Chrome apps show up as Google Chrome, unseparated from browser windows, unlike on the task bar.
	; If you right click on the taskbar button, it shows the Chrome app's name, and if you right click on that and click "Properties"
	; you can see shortcut information. In the General tab, the Location will be something like
	; `C:\Users\Isaiah\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar` or
	; `C:\Users\Isaiah\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Chrome Apps`
	; depending on whether the app is pinned to the task bar or not.

	AllWindows := WinGetList()
	WindowsByProcessPath := Map()
	TopWindowsByProcessPath := Map()
	; ProcessPathByWindow := Map()  ; optimization
	ProcessPaths := []
	Apps := []
	for Window in AllWindows {
		if !Switchable(Window) {
			continue
		}
		ProcessPath := WinGetProcessPath(Window)
		; Note: this can have duplicates.
		; There's no Set type or easy way to check for existence in an array, or uniquify an array,
		; so it's a bit of a pain, but it shouldn't cause problems for now.
		; Easiest fix would be to use the existing Map and extract keys.
		ProcessPaths.Push(ProcessPath)

		if !WindowsByProcessPath.Has(ProcessPath) {
			WindowsByProcessPath[ProcessPath] := []
		}
		WindowsByProcessPath[ProcessPath].Push(Window)
	}
	for ProcessPath in ProcessPaths {
		; First approach fails to find a window for File Explorer.
		; try {
		; 	Window := WinGetID("ahk_exe " ProcessPath)
		; } catch TargetError {
		; 	continue
		; }
		; This approach is more reliable, as it uses the specific window IDs we found earlier.
		Window := Topmost(WindowsByProcessPath[ProcessPath])
		TopWindowsByProcessPath[ProcessPath] := Window
	}
	TopWindows := []
	for _, Window in TopWindowsByProcessPath {
		TopWindows.Push(Window)
	}
	SortByRecency(TopWindows)

	; for ProcessPath, Window in TopWindowsByProcessPath {
	for Window in TopWindows {
		iconHandle := GetAppIconHandle(Window)
		if (iconHandle) {
			ProcessPath := WinGetProcessPath(Window)  ; TODO: maybe optimize by storing this in the loop above
			try {
				Info := FileGetVersionInfo_AW(ProcessPath, ["FileDescription", "ProductName"])
				Title := Info["FileDescription"] ? Info["FileDescription"] : Info["ProductName"]
				; Title := Info["ProductName"] ? Info["ProductName"] : Info["FileDescription"]
			} catch {
				Title := WinGetTitle(Window)
			}
			Apps.Push({
				Icon: GetAppIconHandle(Window),
				Title: Title,
				HWND: Window,
			})
		}
	}
	ShowAppSwitcher(Apps)
	AppSwitcherOpen := true
	; Initially select the next app after the currently focused app when opening the switcher.
	; (Otherwise you always have to press Tab twice to get to the next app.)
	if GetKeyState("Shift") {
		Send "+{Tab}"
	} else {
		Send "{Tab}"
	}
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

GroupIDCounter := 0
Topmost(Windows) {
	; Returns the highest z-index window in the list
	; Note: memory leak: there's no way to remove a group or remove an item from a group.
	global GroupIDCounter
	GroupID := "TestGroup" GroupIDCounter++
	for Window in Windows {
		GroupAdd(GroupID, "ahk_id " Window)
	}
	return WinGetID("ahk_group " GroupID)
}
SortByRecency(Windows) {
	; Sort the windows by z-index, which essentially maps to recency.
	; By comparing subsets of the list, we can order the whole list.
	SortArray(Windows, (A, B) =>
		Topmost([A, B]) == A ? -1 : 1)
}

SortArray(Array, ComparisonFunction) {
	; Insertion sort
	; Note one-based array indexing
	i := 1
	while (i < Array.Length) {
		j := i
		while (j > 0 && ComparisonFunction(Array[j], Array[j + 1]) > 0) {
			Tmp := Array[j]
			Array[j] := Array[j + 1]
			Array[j + 1] := Tmp
			j--
		}
		i++
	}
	return Array
}

; MsgBox((
; 	"SortArray([3, 2, 1], (A, B) => A - B) = " FormatArray(SortArray([3, 2, 1], (A, B) => A - B)) "`n" ; [1, 2, 3]
; 	"SortArray([3, 2, 1], (A, B) => B - A) = " FormatArray(SortArray([3, 2, 1], (A, B) => B - A)) "`n" ; [3, 2, 1]
; 	"SortArray([], (A, B) => B - A) = " FormatArray(SortArray([], (A, B) => B - A)) "`n" ; []
; ))

; FormatArray(Array) {
; 	Str := "["
; 	for index, item in Array {
; 		Str .= item
; 		if (index < Array.Length) {
; 			Str .= ", "
; 		}
; 	}
; 	Str .= "]"
; 	return Str
; }

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