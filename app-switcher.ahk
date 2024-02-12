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
	iconHandle := SendMessage(WM_GETICON, ICON_SMALL2, 0, , hwnd)
	if (!iconHandle)
		iconHandle := SendMessage(WM_GETICON, ICON_SMALL, 0, , hwnd)
	if (!iconHandle)
		iconHandle := SendMessage(WM_GETICON, ICON_BIG, 0, , hwnd)
	if (!iconHandle)
		iconHandle := GetClassLongPtrA(hwnd, GCLP_HICON)
	if (!iconHandle)
		iconHandle := GetClassLongPtrA(hwnd, GCLP_HICONSM)

	if (!iconHandle)
		return 0

	return iconHandle
}

GetClassLongPtrA(hwnd, nIndex) {
	return DllCall("GetClassLongPtrA", "Ptr", hwnd, "int", nIndex, "Ptr")
}

ShowIcon(iconHandle) {
	MyGui := Gui()
	Pic := MyGui.Add("Pic", "", "HICON:*" iconHandle)
	; MyGui.OnEvent("Escape", (*) => ExitApp())
	; MyGui.OnEvent("Close", (*) => ExitApp())
	MyGui.OnEvent("Escape", (*) => MyGui.Destroy())
	MyGui.Show
}

#i:: {
	hwnd := WinExist("A")
	iconHandle := GetAppIconHandle(hwnd)
	; MsgBox("Icon handle: " iconHandle)
	ShowIcon(iconHandle)
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