; Requires AutoHotkey v2

;--------------------------------------------------------
; Logical Application Identity
;--------------------------------------------------------
; Shared by app-switcher.ahk and window-switcher.ahk.
;
; A "logical application" is what a user thinks of as one app, and what the taskbar
; groups windows by. It is NOT the same thing as a process:
;
; - 10 Chrome browser windows are one logical app, even though Chrome spreads them
;   across several processes.
; - Chrome, the "Google Chat" PWA and the "Google Meet" PWA are three logical apps,
;   even though all of them run under chrome.exe.
;
; Windows already has an identity for this concept: the Application User Model ID
; (AUMID). Apps set it per-window through SHGetPropertyStoreForWindow +
; System.AppUserModel.ID, and it is exactly what the taskbar uses to decide which
; windows share a taskbar button. Chromium sets it per browser window and gives every
; installed PWA its own AUMID, so identifying apps by AUMID separates PWAs generically,
; with no browser-specific rules. (Measured on Chrome: normal windows report "Chrome",
; the Google Chat PWA reports "Chrome._crx_pommaclcbflboakcipcmmndhcj", and the Google
; Meet PWA reports "Chrome._crx_kjgfgldnnffkjfagphfepbbdan".)
;
; Windows that don't expose an AUMID fall back to their executable path, which is what
; the app switcher used for everything before.
;
; Identity hierarchy:
;   1. "aumid:<System.AppUserModel.ID of the window>"
;   2. "exe:<lowercased full path of the owning process>"
;
; See GetLogicalAppDisplayName / GetLogicalAppIconHandle for the display metadata
; hierarchies, which look past the executable (whose version info says "Google Chrome"
; for every PWA) to the app model metadata and Start Menu shortcuts.

;--------------------------------------------------------
; Windows API constants
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

; PROPERTYKEYs from the App User Model property set.
; https://learn.microsoft.com/en-us/windows/win32/properties/props-system-appusermodel-id
PKEY_AppUserModel_FMTID := "{9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}"
PID_AppUserModel_ID := 5 ; System.AppUserModel.ID
PID_AppUserModel_RelaunchIconResource := 3 ; System.AppUserModel.RelaunchIconResource
PID_AppUserModel_RelaunchDisplayNameResource := 4 ; System.AppUserModel.RelaunchDisplayNameResource

; VARENUM members that a string-valued PROPVARIANT can use.
VT_EMPTY := 0
VT_BSTR := 8
VT_LPWSTR := 31

; IPropertyStore::GetValue is the 6th vtable entry (0-based index 5), after
; QueryInterface/AddRef/Release and GetCount/GetAt.
IID_IPropertyStore := "{886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99}"
IPropertyStore_GetValue := 5

; GETPROPERTYSTOREFLAGS
GPS_DEFAULT := 0

; A PROPVARIANT is 16 bytes when built for 32-bit and 24 bytes when built for 64-bit.
; In both cases the union (where the string pointer lives) starts at offset 8, after
; `vt` and three reserved WORDs.
PROPVARIANT_SIZE := A_PtrSize = 8 ? 24 : 16
PROPVARIANT_VALUE_OFFSET := 8

; Make sure COM is available on this thread before calling into the shell.
; CoInitialize is reference counted, so this is harmless if AutoHotkey (or another
; included library) already initialized COM. We deliberately never call
; CoUninitialize, since COM should stay available for the life of the script.
DllCall("ole32\CoInitialize", "ptr", 0)

;--------------------------------------------------------
; Logical application identity
;--------------------------------------------------------

; Per-window memoization, so that enumerating every window on screen doesn't repeat the
; same shell calls. Cleared by ClearLogicalAppCache at the start of each switcher
; invocation, so a recycled HWND can never return stale data.
LogicalAppIdCache := Map()
LogicalAppNameCache := Map()

; Keyed by icon resource string rather than by window, and deliberately never cleared:
; the icons we extract ourselves are HICONs we own, and caching them means opening the
; switcher repeatedly can't leak a handle per keypress.
LogicalAppIconCache := Map()

ClearLogicalAppCache() {
	LogicalAppIdCache.Clear()
	LogicalAppNameCache.Clear()
}

; Returns a string identifying the logical application a window belongs to, or "" if
; the window couldn't be identified at all (e.g. it was destroyed while enumerating).
; IDs are only ever compared to each other, never parsed by callers.
GetLogicalAppId(Window) {
	if !Window {
		return ""
	}
	if LogicalAppIdCache.Has(Window) {
		return LogicalAppIdCache[Window]
	}
	AppId := ""
	AppUserModelId := GetWindowAppUserModelId(Window)
	if (AppUserModelId != "") {
		; Used verbatim, including any Chrome profile suffix. Chromium derives distinct
		; AUMIDs per profile, so windows from two Chrome profiles count as two logical
		; apps -- which is also how the taskbar groups them. Stripping the profile out
		; would second-guess Windows' own notion of application identity.
		AppId := "aumid:" AppUserModelId
	} else {
		try {
			ProcessPath := WinGetProcessPath(Window)
		} catch {
			; Can fail for windows we aren't allowed to query, or ones that just closed.
			ProcessPath := ""
		}
		if (ProcessPath != "") {
			; Paths are case-insensitive on Windows, so normalize them for comparison.
			AppId := "exe:" StrLower(ProcessPath)
		}
	}
	LogicalAppIdCache[Window] := AppId
	return AppId
}

; Returns the System.AppUserModel.ID of a top-level window, or "" if it has none.
GetWindowAppUserModelId(Window) {
	return GetWindowAppModelProperty(Window, PID_AppUserModel_ID)
}

; Same as GetWindowAppUserModelId, but reuses GetLogicalAppId's cache instead of making
; another shell call.
GetCachedWindowAppUserModelId(Window) {
	AppId := GetLogicalAppId(Window)
	return SubStr(AppId, 1, 6) = "aumid:" ? SubStr(AppId, 7) : ""
}

GetWindowAppModelProperty(Window, PropertyId) {
	return GetWindowShellProperty(Window, PKEY_AppUserModel_FMTID, PropertyId)
}

; Reads a single string property from a window's property store, using the same API the
; taskbar uses. Returns "" if the window has no property store, doesn't set the
; property, or sets it to something that isn't a string.
GetWindowShellProperty(Window, FormatId, PropertyId) {
	if !Window {
		return ""
	}
	InterfaceId := Buffer(16, 0)
	if (DllCall("ole32\CLSIDFromString", "wstr", IID_IPropertyStore, "ptr", InterfaceId, "int") != 0) {
		return ""
	}
	PropertyStore := 0
	try {
		HResult := DllCall("shell32\SHGetPropertyStoreForWindow", "ptr", Window, "ptr", InterfaceId, "ptr*", &PropertyStore, "int")
	} catch {
		; SHGetPropertyStoreForWindow exists on Windows 7 and later, so this shouldn't
		; happen, but a missing export must not take down the switcher.
		return ""
	}
	if (HResult != 0 || !PropertyStore) {
		; Common and expected: this fails for elevated windows when we aren't elevated,
		; and for windows that were destroyed while we were enumerating.
		return ""
	}
	return ReadStringPropertyAndRelease(PropertyStore, FormatId, PropertyId)
}

; Same, for a file (used to read the AUMID that Start Menu shortcuts advertise).
GetFileShellProperty(Path, FormatId, PropertyId) {
	if (Path = "") {
		return ""
	}
	InterfaceId := Buffer(16, 0)
	if (DllCall("ole32\CLSIDFromString", "wstr", IID_IPropertyStore, "ptr", InterfaceId, "int") != 0) {
		return ""
	}
	PropertyStore := 0
	try {
		HResult := DllCall("shell32\SHGetPropertyStoreFromParsingName", "wstr", Path, "ptr", 0, "uint", GPS_DEFAULT, "ptr", InterfaceId, "ptr*", &PropertyStore, "int")
	} catch {
		return ""
	}
	if (HResult != 0 || !PropertyStore) {
		return ""
	}
	return ReadStringPropertyAndRelease(PropertyStore, FormatId, PropertyId)
}

; Takes ownership of PropertyStore: releases it before returning, however it returns.
ReadStringPropertyAndRelease(PropertyStore, FormatId, PropertyId) {
	PropVariant := Buffer(PROPVARIANT_SIZE, 0)
	Value := ""
	try {
		PropertyKey := Buffer(20, 0) ; struct PROPERTYKEY { GUID fmtid; DWORD pid; }
		if (DllCall("ole32\CLSIDFromString", "wstr", FormatId, "ptr", PropertyKey, "int") = 0) {
			NumPut("uint", PropertyId, PropertyKey, 16)
			; Asking for an "int" return rather than the default HRESULT return type makes
			; a failure a value to check instead of an exception to unwind.
			if (ComCall(IPropertyStore_GetValue, PropertyStore, "ptr", PropertyKey, "ptr", PropVariant, "int") = 0) {
				VariantType := NumGet(PropVariant, 0, "ushort")
				if (VariantType = VT_LPWSTR || VariantType = VT_BSTR) {
					StringPointer := NumGet(PropVariant, PROPVARIANT_VALUE_OFFSET, "ptr")
					if StringPointer {
						Value := StrGet(StringPointer, "UTF-16")
					}
				}
			}
		}
	} catch {
		Value := ""
	} finally {
		; PropVariantClear is safe on a zeroed PROPVARIANT (VT_EMPTY), so it's correct to
		; call unconditionally, including when GetValue failed.
		DllCall("ole32\PropVariantClear", "ptr", PropVariant)
		ObjRelease(PropertyStore)
	}
	return Value
}

;--------------------------------------------------------
; AUMID -> shortcut index
;--------------------------------------------------------
; Installed PWAs expose a distinct AUMID per app, but (measured on Chrome) their
; windows do NOT set System.AppUserModel.RelaunchDisplayNameResource or
; RelaunchIconResource, so there's nothing on the window itself to name them by --
; every PWA would show up as "Google Chrome", with Chrome's icon.
;
; Start Menu and pinned shortcuts do carry the AUMID, though, and that's how the
; taskbar names and pins them. So we index shortcuts by AUMID and use the matching
; shortcut's name and icon. This is generic: it works for Chrome PWAs, Edge PWAs, and
; anything else that ships a shortcut with an AUMID.
;
; The scan costs on the order of a second (roughly 7 ms per shortcut, dominated by the
; shell binding each one), so it's done at most once every RescanIntervalMs, and
; app-switcher.ahk primes it on a timer shortly after startup so that the first
; Alt+Tab isn't the one that pays for it.

ShortcutIndexByAppUserModelId := 0
ShortcutIndexBuildTickCount := 0

; Builds the index up front, so an interactive switcher invocation doesn't have to.
PrimeAppShortcutIndex() {
	if !ShortcutIndexByAppUserModelId {
		BuildAppShortcutIndex()
	}
}

; Returns { Name, Path, IconHandle } for the shortcut advertising this AUMID, or 0.
FindShortcutForAppUserModelId(AppUserModelId) {
	static RescanIntervalMs := 300000 ; 5 minutes
	if (AppUserModelId = "") {
		return 0
	}
	if !ShortcutIndexByAppUserModelId {
		BuildAppShortcutIndex()
	}
	if ShortcutIndexByAppUserModelId.Has(AppUserModelId) {
		return ShortcutIndexByAppUserModelId[AppUserModelId]
	}
	; A shortcut may have appeared since the index was built, e.g. by installing a new
	; PWA. Rebuild for that case, but rate limited, since scanning isn't cheap.
	; (The A_TickCount comparison also handles its ~49 day wraparound.)
	Age := A_TickCount - ShortcutIndexBuildTickCount
	if (Age > RescanIntervalMs || Age < 0) {
		BuildAppShortcutIndex()
		if ShortcutIndexByAppUserModelId.Has(AppUserModelId) {
			return ShortcutIndexByAppUserModelId[AppUserModelId]
		}
	}
	return 0
}

BuildAppShortcutIndex() {
	global ShortcutIndexByAppUserModelId, ShortcutIndexBuildTickCount
	Index := Map()
	Index.CaseSense := false ; AUMIDs are compared case-insensitively by the shell
	for Folder in AppShortcutSearchFolders() {
		if (Folder = "" || !DirExist(Folder)) {
			continue
		}
		Loop Files Folder "\*.lnk", "FR" {
			AppUserModelId := GetFileShellProperty(A_LoopFileFullPath, PKEY_AppUserModel_FMTID, PID_AppUserModel_ID)
			if (AppUserModelId = "" || Index.Has(AppUserModelId)) {
				; First shortcut found for an AUMID wins; the search folders are ordered
				; most-specific-first so that a pinned shortcut beats a Start Menu one.
				continue
			}
			SplitPath(A_LoopFileFullPath, , , , &NameWithoutExtension)
			Index[AppUserModelId] := {
				Name: NormalizeShortcutName(NameWithoutExtension),
				Path: A_LoopFileFullPath,
				; -1 means "icon not extracted yet"; 0 would mean "tried, and there is none".
				IconHandle: -1,
			}
		}
	}
	ShortcutIndexByAppUserModelId := Index
	ShortcutIndexBuildTickCount := A_TickCount
}

AppShortcutSearchFolders() {
	QuickLaunch := A_AppData "\Microsoft\Internet Explorer\Quick Launch\User Pinned"
	return [
		; Pinned taskbar buttons, and the shortcuts Windows generates automatically for
		; windows it sees with an AUMID. These are the most likely to be named the way
		; the user sees the app named.
		QuickLaunch "\TaskBar",
		QuickLaunch "\ImplicitAppShortcuts",
		; The Start Menu, which is where installers and Chrome/Edge put app shortcuts
		; (Chrome PWAs land in "Programs\Chrome Apps").
		A_StartMenu,
		A_StartMenuCommon,
	]
}

; Windows uniquifies shortcut filenames by appending " (1)", " (2)" and so on when two
; shortcuts would otherwise collide, so a PWA's shortcut can be called
; "Google Chat (1).lnk". Drop that suffix so the switcher shows "Google Chat".
NormalizeShortcutName(Name) {
	if RegExMatch(Name, "^(.*\S)\s+\(\d+\)$", &Match) {
		return Match[1]
	}
	return Name
}

;--------------------------------------------------------
; Logical application display metadata
;--------------------------------------------------------

; Returns a human-readable name for the logical application a window belongs to.
;
; Hierarchy:
;   1. System.AppUserModel.RelaunchDisplayNameResource on the window (how app model
;      windows announce their own name, e.g. Chrome reports "Google Chrome")
;   2. The name of the Start Menu / pinned shortcut with the same AUMID (this is what
;      names installed PWAs, e.g. "Google Chat", "Google Meet")
;   3. The executable's FileDescription, then its ProductName
;   4. The window title
;   5. The executable's filename
;
; Note that the executable's version info is preferred over the window title even
; though the title is more specific: window titles name the *document* ("Inbox (3) -
; Gmail - Google Chrome"), not the app. The title is only reached when there's no
; version info to read.
GetLogicalAppDisplayName(Window) {
	if !Window {
		return ""
	}
	if LogicalAppNameCache.Has(Window) {
		return LogicalAppNameCache[Window]
	}

	Name := ResolveIndirectString(GetWindowAppModelProperty(Window, PID_AppUserModel_RelaunchDisplayNameResource))

	if (Name = "") {
		Shortcut := FindShortcutForAppUserModelId(GetCachedWindowAppUserModelId(Window))
		if Shortcut {
			Name := Shortcut.Name
		}
	}

	ProcessPath := ""
	try {
		ProcessPath := WinGetProcessPath(Window)
	} catch {
	}

	if (Name = "" && ProcessPath != "") {
		try {
			Info := FileGetVersionInfo_AW(ProcessPath, ["FileDescription", "ProductName"])
			if (Info.Has("FileDescription") && Info["FileDescription"] != "") {
				Name := Info["FileDescription"]
			} else if (Info.Has("ProductName") && Info["ProductName"] != "") {
				Name := Info["ProductName"]
			}
		} catch {
		}
	}

	if (Name = "") {
		try {
			Name := WinGetTitle(Window)
		} catch {
		}
	}

	if (Name = "" && ProcessPath != "") {
		SplitPath(ProcessPath, &FileName)
		Name := FileName
	}

	LogicalAppNameCache[Window] := Name
	return Name
}

; Returns an HICON for the logical application a window belongs to, or 0.
;
; Hierarchy:
;   1. System.AppUserModel.RelaunchIconResource on the window (Chrome points this at
;      the profile icon for browser windows)
;   2. The icon of the Start Menu / pinned shortcut with the same AUMID (this is what
;      gives each installed PWA its real icon instead of Chrome's)
;   3. The window's own icon (WM_GETICON, then the window class icon)
;   4. The executable's first icon
;
; Icons from steps 1, 2 and 4 are extracted by us and cached, so repeatedly opening the
; switcher can't leak handles. Icons from step 3 belong to the other application and
; must not be destroyed.
GetLogicalAppIconHandle(Window) {
	if !Window {
		return 0
	}

	IconHandle := LoadIconFromResourceString(ResolveIndirectString(GetWindowAppModelProperty(Window, PID_AppUserModel_RelaunchIconResource)))
	if IconHandle {
		return IconHandle
	}

	Shortcut := FindShortcutForAppUserModelId(GetCachedWindowAppUserModelId(Window))
	if Shortcut {
		if (Shortcut.IconHandle = -1) {
			Shortcut.IconHandle := LoadIconFromShortcut(Shortcut.Path)
		}
		if Shortcut.IconHandle {
			return Shortcut.IconHandle
		}
	}

	IconHandle := GetWindowIconHandle(Window)
	if IconHandle {
		return IconHandle
	}

	try {
		ProcessPath := WinGetProcessPath(Window)
	} catch {
		return 0
	}
	if (ProcessPath = "") {
		return 0
	}
	return LoadIconFromResourceString(ProcessPath ",0")
}

LoadIconFromShortcut(ShortcutPath) {
	IconFile := ""
	IconNumber := 0
	Target := ""
	try {
		FileGetShortcut(ShortcutPath, &Target, , , , &IconFile, &IconNumber)
	} catch {
		return 0
	}
	if (IconFile != "") {
		; FileGetShortcut reports a 1-based icon number, while ExtractIconEx takes a
		; 0-based index.
		IconIndex := (IsInteger(IconNumber) && IconNumber > 0) ? IconNumber - 1 : 0
		IconHandle := LoadIconFromResourceString(ExpandEnvironmentStrings(IconFile) "," IconIndex)
		if IconHandle {
			return IconHandle
		}
	}
	if (Target != "") {
		return LoadIconFromResourceString(ExpandEnvironmentStrings(Target) ",0")
	}
	return 0
}

; Resolves the "@path,-resourceId" form that app model resource properties may use.
; Plain strings are returned unchanged. Returns "" if an indirect string can't be
; resolved, so that callers fall through to the next item in their hierarchy rather
; than displaying something like "@C:\Program Files\...\chrome.dll,-12345".
ResolveIndirectString(Source) {
	static MaxCharacters := 1024
	if (Source = "") {
		return ""
	}
	if (SubStr(Source, 1, 1) != "@") {
		return Source
	}
	; One character of slack beyond what the API is allowed to write, and zero filled, so
	; that the result is null-terminated no matter what the API does.
	OutputBuffer := Buffer((MaxCharacters + 1) * 2, 0)
	try {
		if (DllCall("shlwapi\SHLoadIndirectString", "wstr", Source, "ptr", OutputBuffer, "uint", MaxCharacters, "ptr", 0, "int") = 0) {
			return StrGet(OutputBuffer, "UTF-16")
		}
	} catch {
	}
	return ""
}

; Loads an icon from a "<path>,<index>" resource string, as stored in
; System.AppUserModel.RelaunchIconResource. A negative index is a resource ID rather
; than an index, which ExtractIconEx handles natively.
LoadIconFromResourceString(Resource) {
	if (Resource = "") {
		return 0
	}
	if LogicalAppIconCache.Has(Resource) {
		return LogicalAppIconCache[Resource]
	}

	; Split on the *last* comma, since paths may (very rarely) contain one.
	CommaPosition := InStr(Resource, ",", , -1)
	if CommaPosition {
		Path := SubStr(Resource, 1, CommaPosition - 1)
		Index := Trim(SubStr(Resource, CommaPosition + 1))
	} else {
		Path := Resource
		Index := 0
	}
	Path := Trim(Trim(Path), '"')
	if !IsInteger(Index) {
		Index := 0
	}

	IconHandle := 0
	if (Path != "" && FileExist(Path)) {
		LargeIcon := 0
		try {
			; Asking only for the large icon gives us 32x32 (SM_CXICON), which is the size
			; the app switcher draws.
			DllCall("shell32\ExtractIconExW", "wstr", Path, "int", Integer(Index), "ptr*", &LargeIcon, "ptr", 0, "uint", 1, "uint")
			IconHandle := LargeIcon
		} catch {
			IconHandle := 0
		}
	}

	LogicalAppIconCache[Resource] := IconHandle
	return IconHandle
}

; Returns the icon a window advertises for itself, or 0. This handle belongs to the
; other application, so it must not be destroyed.
GetWindowIconHandle(Window) {
	IconHandle := 0
	if (!IconHandle) {
		try {
			IconHandle := SendMessage(WM_GETICON, ICON_BIG, 0, , Window)
		} catch {
		}
	}
	if (!IconHandle) {
		try {
			IconHandle := SendMessage(WM_GETICON, ICON_SMALL2, 0, , Window)
		} catch {
		}
	}
	if (!IconHandle) {
		try {
			IconHandle := SendMessage(WM_GETICON, ICON_SMALL, 0, , Window)
		} catch {
		}
	}
	if (!IconHandle) {
		try {
			IconHandle := GetClassLongPtr(Window, GCLP_HICON)
		} catch {
		}
	}
	if (!IconHandle) {
		try {
			IconHandle := GetClassLongPtr(Window, GCLP_HICONSM)
		} catch {
		}
	}
	return IconHandle
}

GetClassLongPtr(Window, Index) {
	; GetClassLongPtr is only a real export in 64-bit user32; in 32-bit builds the "Ptr"
	; names are macros for the plain GetClassLong functions.
	if (A_PtrSize = 8) {
		return DllCall("GetClassLongPtrW", "Ptr", Window, "int", Index, "Ptr")
	}
	return DllCall("GetClassLongW", "Ptr", Window, "int", Index, "uint")
}

ExpandEnvironmentStrings(Text) {
	if !InStr(Text, "%") {
		return Text
	}
	; The returned size is in characters, and includes the null terminator.
	Size := DllCall("kernel32\ExpandEnvironmentStringsW", "wstr", Text, "ptr", 0, "uint", 0, "uint")
	if !Size {
		return Text
	}
	OutputBuffer := Buffer(Size * 2, 0)
	if !DllCall("kernel32\ExpandEnvironmentStringsW", "wstr", Text, "ptr", OutputBuffer, "uint", Size, "uint") {
		return Text
	}
	return StrGet(OutputBuffer, "UTF-16")
}

;--------------------------------------------------------
; Window filtering
;--------------------------------------------------------

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

	; Not sure of the specific rules, or how much the priority of the cases matters.
	; AI-autocompleted logic is slightly different:
	; Style := WinGetStyle(Window)
	; ExStyle := WinGetExStyle(Window)
	; if Style & WS_CHILD {
	;   return false
	; }
	; if ExStyle & WS_EX_APPWINDOW {
	;   return true
	; }
	; if ExStyle & WS_EX_TOOLWINDOW {
	;   return false
	; }
	; return true
}

;--------------------------------------------------------
; Coordination between the two switchers
;--------------------------------------------------------
; window-switcher.ahk drives the *native* Windows task switcher by synthesizing
; Alt+Tab, and app-switcher.ahk owns the physical Alt+Tab hotkey. Those two facts have
; to be reconciled.
;
; The synthetic Alt+Tab is not actually a problem: AutoHotkey tags the input it
; generates with a send level (0 unless SendLevel says otherwise), and hook hotkeys
; such as `$!Tab` ignore generated input at or below their own input level. The tag is
; a value all AutoHotkey builds recognize, so this works between separate scripts too.
; window-switcher's `Send` therefore reaches Windows without re-triggering the app
; switcher. (Verified: a level-0 synthetic Alt+Tab opens the native switcher and never
; fires `$!Tab`, while a level-1 one fires `$!Tab` and is swallowed.)
;
; What that does *not* cover is the physical Tab presses a user makes to cycle through
; the native switcher once it's open. Those are indistinguishable from asking for the
; app switcher. So while window-switcher has the native switcher open it holds a named
; mutex, and app-switcher passes Tab straight through instead of opening its own UI.
;
; A named mutex is used rather than window messages because it works regardless of
; script names, works when compiled, and is released by the kernel automatically if the
; window switcher exits or crashes mid-session. Either script also works fine on its
; own: with the other one not running, the mutex simply never exists.

; "Local\" scopes the mutex to the current logon session.
NATIVE_SWITCHER_SESSION_MUTEX_NAME := "Local\1j01-window-switcher-native-task-switcher-session"
NativeSwitcherSessionMutex := 0

BeginNativeSwitcherSession() {
	global NativeSwitcherSessionMutex
	if NativeSwitcherSessionMutex {
		return
	}
	NativeSwitcherSessionMutex := DllCall("kernel32\CreateMutexW", "ptr", 0, "int", false, "wstr", NATIVE_SWITCHER_SESSION_MUTEX_NAME, "ptr")
}

EndNativeSwitcherSession() {
	global NativeSwitcherSessionMutex
	if !NativeSwitcherSessionMutex {
		return
	}
	DllCall("kernel32\CloseHandle", "ptr", NativeSwitcherSessionMutex)
	NativeSwitcherSessionMutex := 0
}

; True if *this* script is the one currently driving the native task switcher.
NativeSwitcherSessionOwnedHere() {
	return NativeSwitcherSessionMutex != 0
}

; True if any script is currently driving the native task switcher.
IsNativeSwitcherSessionActive() {
	static SYNCHRONIZE := 0x00100000
	static ERROR_ACCESS_DENIED := 5
	Handle := DllCall("kernel32\OpenMutexW", "uint", SYNCHRONIZE, "int", false, "wstr", NATIVE_SWITCHER_SESSION_MUTEX_NAME, "ptr")
	if Handle {
		DllCall("kernel32\CloseHandle", "ptr", Handle)
		return true
	}
	; If the window switcher is running as administrator and this script isn't, opening
	; the mutex can fail with access denied -- which still tells us that it exists.
	return A_LastError = ERROR_ACCESS_DENIED
}

;--------------------------------------------------------
; Misc. helpers
;--------------------------------------------------------

DescribeWindow(Window) {
	try {
		return "Window Title: " WinGetTitle(Window) "`nWindow Class: " WinGetClass(Window) "`nProcess Path: " WinGetProcessPath(Window) "`nLogical App: " GetLogicalAppId(Window)
	} catch TargetError {
		return "Nonexistent window"
	}
}

FileGetVersionInfo_AW(PEFile := "", Fields := ["FileDescription"]) {
	; Written by SKAN
	; https://www.autohotkey.com/forum/viewtopic.php?t=64128       CD:24-Nov-2008 / LM:28-May-2010
	; Updated for AHK v2 by 1j01                                   2024-02-12 / LM:2024-09-14
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
	TranslationHex := Buffer(16 + 2)  ; 8 characters + null terminator in UTF-16
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
