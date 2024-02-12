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

WS_EX_APPWINDOW := 0x00040000
WS_EX_TOOLWINDOW := 0x00000080
WS_CHILD := 0x40000000


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

AppSwitcher := 0
AppSwitcherOpen := false ; could use AppSwitcher

#MaxThreadsPerHotkey 2 ; Needed to handle tabbing through apps while the switcher is open

ShowAppSwitcher(iconHandles, appTitles, HWNDs) {
	; TODO: Make focus visible
	MyGui := Gui()
	for index, iconHandle in iconHandles {
		; MyGui.Add("Pic", "yM w128 h128", "HICON:*" iconHandle)
		; MyGui.Add("Text", "w128", appTitles[index])
		OuterSize := 128
		InnerSize := 32
		Offset := (OuterSize - InnerSize) / 2
		Offset2 := (OuterSize + InnerSize) / 2
		MyGui.Add("Pic", "yM x+" Offset " Section Tabstop vPicForAppWithHWND" HWNDs[index], "HICON:*" iconHandle)
		MyGui.Add("Text", "w" OuterSize " x+-" Offset2 " ys+" Offset " center", appTitles[index])
	}
	; MyGui.OnEvent("Escape", (*) => ExitApp())
	; MyGui.OnEvent("Close", (*) => ExitApp())
	MyGui.OnEvent("Escape", (*) => MyGui.Destroy())
	MyGui.Show
	global AppSwitcher := MyGui
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
		return
	}
	; TODO: guess at app title by common parts from window titles?
	; Can't really guess between "untitled - Notepad" and "notepad - Untitled"
	; Maybe this is why Windows doesn't have an app switcher like this
	AllWindows := WinGetList()
	IconsByApp := Map()
	TitlesByApp := Map()
	HWNDsByApp := Map()
	for Window in AllWindows {
		if !Switchable(Window) {
			continue
		}
		iconHandle := GetAppIconHandle(Window)
		if (iconHandle) {
			App := WinGetProcessName(Window)
			IconsByApp[App] := GetAppIconHandle(Window)
			TitlesByApp[App] := WinGetTitle(Window)
			HWNDsByApp[App] := Window
		}
	}
	AppIcons := []
	AppTitles := []
	HWNDs := []
	for App, iconHandle in IconsByApp {
		AppIcons.Push(iconHandle)
		AppTitles.Push(TitlesByApp[App])
		HWNDs.Push(HWNDsByApp[App])
	}
	ShowAppSwitcher(AppIcons, AppTitles, HWNDs)
	AppSwitcherOpen := true
	if GetKeyState("LWin") {
		KeyWait "LWin"
	} else if GetKeyState("RWin") { ; just to be sure we don't wait forever in case the key was released quickly
		KeyWait "RWin"
	}
	SelectedPic := AppSwitcher.FocusedCtrl
	SelectedHWND := StrSplit(SelectedPic.Name, "PicForAppWithHWND")[2]
	MsgBox("SelectedPic: " SelectedPic.Hwnd "`nSelectedPic.Name: " SelectedPic.Name "`nSelectedHWND: " SelectedHWND "`n`n" DescribeWindow(SelectedHWND))
	AppSwitcher.Destroy()
	AppSwitcherOpen := false
	; WinActivate(HWND)
}

DescribeWindow(Window) {
	try {
		return "Window Title: " WinGetTitle(Window) "`nWindow Class: " WinGetClass(Window) "`nProcess Name: " WinGetProcessName(Window)
	} catch TargetError {
		return "Nonexistent window"
	}
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