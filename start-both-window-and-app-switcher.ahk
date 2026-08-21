; Requires AutoHotkey v2

;--------------------------------------------------------
; Start both switchers
;--------------------------------------------------------
; The app switcher (Alt+Tab) and the window switcher (Alt+`) are separate scripts, each
; with its own tray icon, and each works fine on its own. They're designed to be used
; together though, so this is a convenience launcher: it starts both and then exits, so
; that there's a single file to point a startup task or shortcut at.
;
; Running the two .ahk files directly is exactly equivalent -- nothing here is required.

#SingleInstance Off
#NoTrayIcon

if !A_AhkPath || !FileExist(A_AhkPath) {
	MsgBox("Couldn't find AutoHotkey. Install AutoHotkey v2, or run app-switcher.ahk and window-switcher.ahk directly.", "Window Switcher + App Switcher", 0x10)
	ExitApp
}

for ScriptName in ["app-switcher.ahk", "window-switcher.ahk"] {
	ScriptPath := A_ScriptDir "\" ScriptName
	if !FileExist(ScriptPath) {
		MsgBox("Couldn't find " ScriptPath, "Window Switcher + App Switcher", 0x10)
		continue
	}
	; Quoted, since the path may contain spaces. (Each script's `#Include` paths resolve
	; relative to the script's own directory, not the working directory, so the two only
	; need logical-app.ahk to sit next to them.)
	Run('"' A_AhkPath '" "' ScriptPath '"', A_ScriptDir)
}

ExitApp
