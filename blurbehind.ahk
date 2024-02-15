; https://github.com/awbait/next-helper/blob/e1250621be5b9b049f2d26f5c47468b3971af173/launcher/lib/Neutron.ahk#L257C1-L324C1
; This doesn't work for me on Windows 11, but the DllCall does change the background from black to white.


; Undoucmented Accent API constants
; https://withinrafael.com/2018/02/02/adding-acrylic-blur-to-your-windows-10-apps-redstone-4-desktop-apps/

ACCENT_DISABLED := 0
ACCENT_ENABLE_GRADIENT := 1
ACCENT_ENABLE_TRANSPARENTGRADIENT := 2
ACCENT_ENABLE_BLURBEHIND := 3
ACCENT_ENABLE_ACRYLICBLURBEHIND := 4
ACCENT_INVALID_STATE := 5
WCA_ACCENT_POLICY := 19

; OS minor version
OS_MINOR_VER := StrSplit(A_OSVersion, ".")[3]


; Create and save the GUI
myGui := Gui("+Resize -DPIScale")

; Enable shadow
NumPut("Int", 1, margins := Buffer(16, 0))
DllCall("Dwmapi\DwmExtendFrameIntoClientArea",
	"Ptr", myGui.hWnd,	; HWND hWnd
	"Ptr", margins,	; MARGINS *pMarInset
)

; When manually resizing a window, the contents of the window often "lag
; behind" the new window boundaries. Until they catch up, Windows will
; render the border and default window color to fill that area. On most
; windows this will cause no issue, but for borderless windows this can
; cause rendering artifacts such as thin borders or unwanted colors to
; appear in that area until the rest of the window catches up.
;
; When creating a dark-themed application, these artifacts can cause
; jarringly visible bright areas. This can be mitigated some by changing
; the window settings to cause dark/black artifacts, but it's not a
; generalizable approach, so if I were to do that here it could cause
; issues with light-themed apps.
;
; Some borderless window libraries, such as rossy's C implementation
; (https://github.com/rossy/borderless-window) hide these artifacts by
; playing with the window transparency settings which make them go away
; but also makes it impossible to show certain colors (in rossy's case,
; Fuchsia/FF00FF).
;
; Luckly, there's an undocumented Windows API function in user32.dll
; called SetWindowCompositionAttribute, which allows you to change the
; window accenting policies. This tells the DWM compositor how to fill
; in areas that aren't covered by controls. By enabling the "blurbehind"
; accent policy, Windows will render a blurred version of the screen
; contents behind your window in that area, which will not be visually
; jarring regardless of the colors of your application or those behind
; it.
;
; Because this API is undocumented (and unavailable in Windows versions
; below 10) it's not a one-size-fits-all solution, and could break with
; future system updates. Hopefully a better soultion for the problem
; this hack addresses can be found for future releases of this library.
;
; https://withinrafael.com/2018/02/02/adding-acrylic-blur-to-your-windows-10-apps-redstone-4-desktop-apps/
; https://github.com/melak47/BorderlessWindow/issues/13#issuecomment-309154142
; http://undoc.airesoft.co.uk/user32.dll/SetWindowCompositionAttribute.php
; https://gist.github.com/riverar/fd6525579d6bbafc6e48
; https://vhanla.codigobit.info/2015/07/enable-windows-10-aero-glass-aka-blur.html
myGui.BackColor := 0x000000

; [StructLayout(LayoutKind.Sequential)]
; internal struct AccentPolicy
; {
; 	public AccentState AccentState;
; 	public uint AccentFlags;
; 	public uint GradientColor;
; 	public uint AnimationId;
; }

; Use ACCENT_ENABLE_GRADIENT on Windows 11 to fix window dragging issues
accent := Buffer(4 * 4, 0)
; if OS_MINOR_VER >= 22000
; 	NumPut("Int", ACCENT_ENABLE_GRADIENT, accent)
; else
; 	NumPut("Int", ACCENT_ENABLE_BLURBEHIND, accent)
NumPut(
	"Int", ACCENT_ENABLE_ACRYLICBLURBEHIND,
	"Int", 0,
	"Int", 0x55555555, ; must be non-zero ARGB color? or something like that. but I can't get it to work.
	"Int", 0,
	accent
)

; [StructLayout(LayoutKind.Sequential)]
; internal struct WindowCompositionAttributeData
; {
; 	public WindowCompositionAttribute Attribute;
; 	public IntPtr Data;
; 	public int SizeOfData;
; }

wcad := Buffer(A_PtrSize + A_PtrSize + 4, 0)
NumPut(
	"Ptr", WCA_ACCENT_POLICY,
	"Ptr", accent.Ptr,
	"Int", accent.Size,
	wcad
)

DllCall("SetWindowCompositionAttribute",
	"Ptr", myGui.hWnd,  ; HWND hwnd
	"Ptr", wcad,  ; WINCOMPATTRDATA* pAttrData
)


; ; Create the GUI window
; myGui := Gui()

; ; Enable shadow
; margins := Buffer(16, 0) ; V1toV2: if 'margins' is a UTF-16 string, use 'VarSetStrCapacity(&margins, 16)'
; NumPut("Int", 1, margins, 0)
; DllCall("Dwmapi\DwmExtendFrameIntoClientArea", "UPtr", myGui.hWnd, "UPtr", margins.Ptr)

; ; When manually resizing a window, the contents of the window often "lag
; ; behind" the new window boundaries. Until they catch up, Windows will
; ; render the border and default window color to fill that area. On most
; ; windows this will cause no issue, but for borderless windows this can
; ; cause rendering artifacts such as thin borders or unwanted colors to
; ; appear in that area until the rest of the window catches up.
; ;
; ; When creating a dark-themed application, these artifacts can cause
; ; jarringly visible bright areas. This can be mitigated some by changing
; ; the window settings to cause dark/black artifacts, but it's not a
; ; generalizable approach, so if I were to do that here it could cause
; ; issues with light-themed apps.
; ;
; ; Some borderless window libraries, such as rossy's C implementation
; ; (https://github.com/rossy/borderless-window) hide these artifacts by
; ; playing with the window transparency settings which make them go away
; ; but also makes it impossible to show certain colors (in rossy's case,
; ; Fuchsia/FF00FF).
; ;
; ; Luckly, there's an undocumented Windows API function in user32.dll
; ; called SetWindowCompositionAttribute, which allows you to change the
; ; window accenting policies. This tells the DWM compositor how to fill
; ; in areas that aren't covered by controls. By enabling the "blurbehind"
; ; accent policy, Windows will render a blurred version of the screen
; ; contents behind your window in that area, which will not be visually
; ; jarring regardless of the colors of your application or those behind
; ; it.
; ;
; ; Because this API is undocumented (and unavailable in Windows versions
; ; below 10) it's not a one-size-fits-all solution, and could break with
; ; future system updates. Hopefully a better soultion for the problem
; ; this hack addresses can be found for future releases of this library.
; ;
; ; https://withinrafael.com/2018/02/02/adding-acrylic-blur-to-your-windows-10-apps-redstone-4-desktop-apps/
; ; https://github.com/melak47/BorderlessWindow/issues/13#issuecomment-309154142
; ; http://undoc.airesoft.co.uk/user32.dll/SetWindowCompositionAttribute.php
; ; https://gist.github.com/riverar/fd6525579d6bbafc6e48
; ; https://vhanla.codigobit.info/2015/07/enable-windows-10-aero-glass-aka-blur.html

; ; Undoucmented Accent API constants
; ; https://withinrafael.com/2018/02/02/adding-acrylic-blur-to-your-windows-10-apps-redstone-4-desktop-apps/
; ACCENT_ENABLE_GRADIENT := 1
; ACCENT_ENABLE_BLURBEHIND := 3
; WCA_ACCENT_POLICY := 19

; ; OS minor version
; OS_MINOR_VER := StrSplit(A_OSVersion, ".")[3]

; myGui.BackColor := "0"
; wcad := Buffer(A_PtrSize + A_PtrSize + 4, 0)
; NumPut("Int", WCA_ACCENT_POLICY, wcad, 0)
; accent := Buffer(16, 0) ; V1toV2: if 'accent' is a UTF-16 string, use 'VarSetStrCapacity(&accent, 16)'
; ; Use ACCENT_ENABLE_GRADIENT on Windows 11 to fix window dragging issues
; if (OS_MINOR_VER >= 22000)
; 	AccentState := ACCENT_ENABLE_GRADIENT
; else
; 	AccentState := ACCENT_ENABLE_BLURBEHIND
; NumPut("Int", AccentState, accent, 0)
; NumPut("Ptr", accent, wcad, A_PtrSize)
; NumPut("Int", 16, &wcad, A_PtrSize + A_PtrSize)
; DllCall("SetWindowCompositionAttribute", "UPtr", myGui.hWnd, "UPtr", wcad)

; Show the GUI
myGui.AddText("", "Hello, World!")
myGui.Show()


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