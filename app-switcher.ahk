; Requires AutoHotkey v2
#Include "./GuiEnhancerKit.ahk"
#Include "./logical-app.ahk"

;--------------------------------------------------------
; App Switcher
;--------------------------------------------------------
; Press Alt+Tab to cycle through open applications.
; Press Shift+Alt+Tab to cycle backwards.
; Release Alt to switch to the selected application.
; Press Escape to close the app switcher.
;
; This replaces Windows' own Alt+Tab. Use Alt+` (window-switcher.ahk) to switch
; between the windows of whichever application is currently active.
;
; One entry is shown per *logical application* -- not per window, and not per process.
; Ten Chrome windows are one entry, while installed PWAs such as Google Chat and
; Google Meet get their own entries even though they all run under chrome.exe.
; See logical-app.ahk for how that identity, and each app's name and icon, are found.

;--------------------------------------------------------
; Handle resources for compiling to EXE
;--------------------------------------------------------
; `FileInstall` when compiled, copies the files from the EXE to the destination directory.
; `FileInstall` when not compiled, copies the files from the source directory to the destination directory.
; Thus in both cases the resources can be referenced by the same path.
; When Ahk2Exe processes the script, it parses `FileInstall` commands
; in a basic way, so variables and expressions are not supported for the Source parameter,
; and thus loops can't be used to install multiple files in a succinct way.

ResourcesDir := A_Temp "/AppSwitcherResources/"
if !FileExist(ResourcesDir) {
	DirCreate(ResourcesDir)
}
FileInstall("resources/app-border-inactive.png", ResourcesDir "app-border-inactive.png", true)
FileInstall("resources/app-border-active.png", ResourcesDir "app-border-active.png", true)

;--------------------------------------------------------
; Windows API constants
;--------------------------------------------------------
; Note: window style, icon and app model constants live in logical-app.ahk,
; alongside the functions that use them.

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

;--------------------------------------------------------
; Tray Menu
;--------------------------------------------------------

A_TrayMenu.Add()  ; Creates a separator line.
A_TrayMenu.Add("Report Issue", MenuHandler)
A_TrayMenu.Add("Project Homepage", MenuHandler)

MenuHandler(ItemName, ItemPos, MyMenu) {
	if ItemName = "Report Issue" {
		Run("https://github.com/1j01/window-switcher/issues")
	} else if ItemName = "Project Homepage" {
		Run("https://github.com/1j01/window-switcher/?tab=readme-ov-file#window-switcher")
	}
}

;--------------------------------------------------------

global AppSwitcher := 0
; Set by the Escape hotkey (and the Gui's Escape event) so that releasing Alt afterwards
; commits nothing. Reset for each new switcher session in `ShowAppSwitcher`.
global AppSwitcherCancelled := false
global FocusRingByHWND := Map()

; Build the AUMID-to-shortcut index that names and illustrates PWAs ahead of time, so
; that the first Alt+Tab isn't the one that waits for it. (A negative period means
; "run once", and the delay keeps it out of the way of startup.)
SetTimer(PrimeAppShortcutIndex, -3000)

#MaxThreadsPerHotkey 2 ; Needed to handle tabbing through apps while the switcher is open

ShowAppSwitcher(Apps) {
	CloseAppSwitcher()  ; just in case - don't want to leave behind an old app switcher window

	global AppSwitcherCancelled := false  ; a fresh session starts out uncancelled
	global AppSwitcher := GuiExt()

	AppSwitcher.SetFont("cWhite s10", "Segoe UI")
	AppSwitcher.SetDarkTitle()  ; needed for dark window background apparently, even though there's no title bar
	AppSwitcher.SetDarkMenu()  ; should be unnecessary

	; AppSwitcher.BackColor := 0x202020
	AppSwitcher.BackColor := 0x000000

	AppSwitcher.MarginX := 30
	AppSwitcher.MarginY := 30
	for index, app in Apps {
		FocusRing := AppSwitcher.Add("Pic", "yM w128 h128 Section", ResourcesDir "app-border-inactive.png")
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
			AppSwitcher.Add("Pic", "ys+" Offset " xs+" Offset " w32 h32 Tabstop vPicForAppWithHWND" app.HWND, ResourcesDir "app-border-inactive.png")
		}
		AppSwitcher.Add("Text", "w" TextWidth " h" TextHeight " xs+" BorderSize " ys+" TextY " center " SS_WORDELLIPSIS " " SS_NOPREFIX, app.Title)
	}
	; Belt and braces: this only fires if Escape actually reaches the Gui, which it doesn't
	; while Alt is held (see the Escape hotkey below), i.e. essentially never in practice.
	AppSwitcher.OnEvent("Escape", CancelAppSwitcher)
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

CloseAppSwitcher(*) {
	global AppSwitcher
	if !AppSwitcher {
		return
	}
	; AppSwitcher.Destroy()
	; AppSwitcher := 0

	; Trying to avoid "Error: Gui has no window." in the compiled script...
	; This might be safer with threading? This way the variable always
	; references an existing window or is 0, right?
	OldAppSwitcher := AppSwitcher
	AppSwitcher := 0
	OldAppSwitcher.Destroy()
}

; Cancel: dismiss the switcher without acting on the highlighted app.
; `CloseAppSwitcher` is only the teardown; this is what makes it a *cancellation*, marking the
; session so that the pending Alt release in the hotkey thread commits nothing.
CancelAppSwitcher(*) {
	global AppSwitcherCancelled := true
	CloseAppSwitcher()
}

; Confirm: activate whatever is highlighted, then dismiss the switcher.
; This is the only path that activates an application.
ConfirmAppSwitcher() {
	global AppSwitcher, AppSwitcherCancelled
	; Don't commit a cancelled session. Also don't commit a switcher that's already gone, which
	; happens when a newer Alt+Tab session has opened and closed one in the meantime; between
	; them, a stale hotkey thread can never activate anything.
	if (!AppSwitcher || AppSwitcherCancelled) {
		return
	}
	; Normally `AppSwitcher.FocusedCtrl` exists at this point,
	; but it may not exist if focus changes while the switcher is open
	; such as by pressing Win+D to show the desktop, then releasing Win.
	SelectedPic := AppSwitcher.FocusedCtrl
	SelectedHWND := 0
	if SelectedPic {
		SelectedHWND := Integer(StrSplit(SelectedPic.Name, "PicForAppWithHWND")[2])
	}
	CloseAppSwitcher()
	if SelectedHWND {
		WinActivate(SelectedHWND)
	}
}

; Workaround for blur-behind accent effect not working the first time the app switcher is shown.
; FIXME: the effect is still not reliably applied. This helps, but it doesn't get at the root cause.
; Hm, resizing a test window seems to make the effect work. Maybe I can trigger something like a resize event to make it work reliably.
; Or many such events? Since it updates gradually? (Is it an animation, or is it updating only slightly at a given event?)
ShowAppSwitcher([])
CloseAppSwitcher()


LastFocusHighlight := 0
UpdateFocusHighlight() {
	global LastFocusHighlight
	Pic := AppSwitcher.FocusedCtrl
	if LastFocusHighlight {
		try {
			LastFocusHighlight.Value := ResourcesDir "app-border-inactive.png"
		} catch {
			; App switcher closed and destroyed the control
		}
	}
	if !Pic {
		; Probably shouldn't happen, GENERALLY, with logic outside this function focusing the app switcher if it's not focused
		; but maybe it could lose focus immediately after being focused with `WinActivate`,
		; or immedaitely after showing the app switcher.
		return
	}
	FocusRing := FocusRingByHWND[Integer(StrSplit(Pic.Name, "PicForAppWithHWND")[2])]
	FocusRing.Value := ResourcesDir "app-border-active.png"
	LastFocusHighlight := FocusRing
}

; The `$` prefix forces these to be implemented with the keyboard hook, which is what
; makes it possible to take Alt+Tab away from Windows at all -- and it's also what makes
; them ignore the synthetic Alt+Tab that window-switcher.ahk sends to open the *native*
; task switcher. See the coordination notes in logical-app.ahk.
$!Tab::
$!+Tab:: {
	global AppSwitcher
	if IsNativeSwitcherSessionActive() {
		; The same-app window switcher currently has the native task switcher open.
		; Pass Tab through so that it cycles through that, instead of opening this
		; switcher on top of it. Sent at the default send level, so this doesn't come
		; straight back to this hotkey.
		Send "{Blind}{Tab}"
		return
	}
	if AppSwitcher {
		; Cycle through apps in the app switcher
		; This uses normal control tabbing behavior, so it requires the app switcher to be focused.

		; Normally `AppSwitcher.FocusedCtrl` exists at this point,
		; but it may not exist if focus changes while the switcher is open
		; such as by pressing Win+D to show the desktop,
		; then pressing Tab while Win is still held down.
		if !AppSwitcher.FocusedCtrl {
			; Focus the app switcher so that it will have a focused control again.
			; Do this before sending Tab so that it still cycles even in this case.
			WinActivate(AppSwitcher.HWND)
		}
		if GetKeyState("Shift") {
			Send "+{Tab}"
		} else {
			Send "{Tab}"
		}
		UpdateFocusHighlight()
		return
	}
	; Group windows by logical application rather than by process path, so that Chrome
	; and each of its installed PWAs are separate entries, while all of Chrome's own
	; windows collapse into one. GetLogicalAppId prefers the window's AUMID (which is
	; what the taskbar groups by) and falls back to the process path.
	ClearLogicalAppCache()

	AllWindows := WinGetList()
	WindowsByAppId := Map()
	for Window in AllWindows {
		AppId := ""
		try {
			if Switchable(Window) {
				AppId := GetLogicalAppId(Window)
			}
		} catch {
			; The window may have been destroyed while we were enumerating.
		}
		if (AppId = "") {
			continue
		}
		if !WindowsByAppId.Has(AppId) {
			WindowsByAppId[AppId] := []
		}
		WindowsByAppId[AppId].Push(Window)
	}
	TopWindows := []
	for AppId, WindowsOfApp in WindowsByAppId {
		; Represent each application with its topmost window.
		; (Using the specific window IDs found above, rather than `WinGetID("ahk_exe ...")`,
		; which fails to find a window for File Explorer.)
		try {
			TopWindows.Push(Topmost(WindowsOfApp))
		} catch {
			continue
		}
	}
	SortByRecency(TopWindows)

	Apps := []
	for Window in TopWindows {
		IconHandle := GetLogicalAppIconHandle(Window)
		if (IconHandle) {
			Apps.Push({
				Icon: IconHandle,
				Title: GetLogicalAppDisplayName(Window),
				HWND: Window,
			})
		}
	}
	ShowAppSwitcher(Apps)
	; Initially select the next app after the currently focused app when opening the switcher.
	; (Otherwise you always have to press Tab twice to get to the next app.)
	if GetKeyState("Shift") {
		Send "+{Tab}"
	} else {
		Send "{Tab}"
	}
	UpdateFocusHighlight()
	; Wait for Alt to be released, which is what commits the selection.
	; "P" (the physical state) is what KeyWait uses by default anyway, but it's stated
	; explicitly here because it matters: `Send` above temporarily lifts whichever
	; modifier the user is holding so that it can send a bare Tab, so the *logical* Alt
	; state briefly looks released while tabbing through the switcher.
	if GetKeyState("LAlt", "P") {
		KeyWait "LAlt", "P"
	} else if GetKeyState("RAlt", "P") { ; just to be sure we don't wait forever in case the key was released quickly
		KeyWait "RAlt", "P"
	}
	; Releasing Alt is what confirms the selection. The switcher is normally still open at this
	; point, but it may have been cancelled with Escape, in which case this does nothing.
	ConfirmAppSwitcher()
}

; Escape cancels the app switcher, and nothing else.
; The `$` prefix forces this to be implemented with the keyboard hook, which is what lets it
; take the keystroke away from Windows. Without it, Alt+Esc -- and Escape is only ever pressed
; with Alt held here, since holding Alt is what keeps the switcher open -- is swallowed by the
; OS as its own "activate the next window in the z-order" shortcut, which switches apps behind
; our back and stops the Gui's Escape event from ever firing.
; `*` matches whatever modifiers are held (Alt, plus Shift when cycling backwards).
; The Alt release is deliberately not consumed: the `KeyWait` above still returns as usual,
; it just finds the session cancelled and commits nothing.
#HotIf AppSwitcher
$*Escape:: {
	CancelAppSwitcher()
}
#HotIf

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
		TopmostOfTwo(A, B) == A ? -1 : 1)
}
TopmostOfTwo(A, B) {
	; `Topmost` throws if neither window exists any more, e.g. if one was closed
	; while the switcher was being built.
	try {
		return Topmost([A, B])
	} catch {
		return A
	}
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