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

ShowAppSwitcher(iconHandles, appTitles) {
	MyGui := Gui()
	for index, iconHandle in iconHandles {
		MyGui.Add("Pic", "yM", "HICON:*" iconHandle)
		MyGui.Add("Text", "w128", appTitles[index])
	}
	; MyGui.OnEvent("Escape", (*) => ExitApp())
	; MyGui.OnEvent("Close", (*) => ExitApp())
	MyGui.OnEvent("Escape", (*) => MyGui.Destroy())
	MyGui.Show
}

#Tab:: {
	; TODO: why are multiple VS Code icons showing up? does process name include args? or...
	; one shows "CodeSetup-stable-...-.tmp", maybe it updated since opening one of the windows
	; so it's a different exe? or the Setup window is hidden and should be ignored by checking for WS_EX_TOOLWINDOW / visibility
	; TODO: guess at app title by common parts from window titles?
	; Can't really guess between "untitled - Notepad" and "notepad - Untitled"
	; Maybe this is why Windows doesn't have an app switcher like this
	AllWindows := WinGetList()
	IconsByApp := Map()
	TitlesByApp := Map()
	for Window in AllWindows {
		iconHandle := GetAppIconHandle(Window)
		if (iconHandle) {
			App := WinGetProcessName(Window)
			IconsByApp[App] := GetAppIconHandle(Window)
			TitlesByApp[App] := WinGetTitle(Window)
		}
	}
	AppIcons := []
	AppTitles := []
	for App, iconHandle in IconsByApp {
		AppIcons.Push(iconHandle)
		AppTitles.Push(TitlesByApp[App])
	}
	ShowAppSwitcher(AppIcons, AppTitles)
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