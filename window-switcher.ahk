;--------------------------------------------------------
; Alt+` to switch between windows of the same application
;--------------------------------------------------------

; This script piggybacks on the built-in Alt+Tab window switcher,
; filtering it to show only windows from the same process as the active window.
; It listens for Alt+` and Alt+Shift+` and converts them to Alt+Tab and Alt+Shift+Tab, respectively,
; after hiding windows from the task switcher by setting their WS_EX_TOOLWINDOW style,
; and then unhiding them after the switcher is closed.
; Pressing ` again while holding Alt will tab through the windows of the same application,
; and Shift+` will tab through them in reverse.
; Tab or Shift+Tab also works (automatically, since that's what the switcher normally uses.)

; Limitations:
; - Windows are hidden from the task bar as well, which can be distracting, as it animates, especially with taskbar button labels enabled.
; - Some windows are not filtered out, such as Windows's Settings app. Running as administrator doesn't help.
; - There may be side effects on the windows that get hidden, since it changes their window type, essentially, temporarily.
;   I haven't noticed any problems so far.

; TODO: remove windows from task switcher only, and not the task bar.
; Adding WS_EX_TOOLWINDOW is much faster than WinHide/WinShow (it makes the actual interaction instantaneous!),
; but it still causes distracting animation in the taskbar, particularly when taskbar button labels are enabled.
; Is there a less obtrusive way to remove windows from the task switcher?

#MaxThreadsPerHotkey 2

WS_EX_APPWINDOW := 0x00040000
WS_EX_TOOLWINDOW := 0x00000080
WS_CHILD := 0x40000000
TempHiddenWindows := []
!+`:: {
  FilteredWindowSwitcher()
}
!`:: {
  FilteredWindowSwitcher()
}
FilteredWindowSwitcher() {
  if TempHiddenWindows.Length {
    ; Needs #MaxThreadsPerHotkey 2 to handle Alt+`+`+`... to tab through windows with `, while waiting for Alt to be released
    ; Needs {Blind} to handle Alt+Shift+` to go in reverse
    Send "{Blind}{Tab}"
    return
  }
  try {
    ActiveProcessName := WinGetProcessName("A")
  } catch TargetError {
    MakeSplash("Window Switcher", "Active window not found.", 1000)
    return
  }
  WinClassCount := WinGetCount("ahk_exe " ActiveProcessName)
  if WinClassCount = 1 {
    return
  }
  WindowsOfApp := WinGetList("ahk_exe " ActiveProcessName)
  AllWindows := WinGetList()
  for Window in AllWindows {
    SameApp := false
    for WindowOfApp in WindowsOfApp {
      if Window = WindowOfApp {
        SameApp := true
        break
      }
    }
    if !SameApp {
      if Switchable(Window) {
        ; WinHide(Window)
        try {
          WinSetExStyle(WinGetExStyle(Window) | WS_EX_TOOLWINDOW, Window)
          ; MsgBox("Would hide: " DescribeWindow(Window), "Window Switcher")
        } catch Error as e {
          ; Gets permission errors for certain windows, such as Windows's Settings app.
          ; Note: WinHide/WinShow doesn't work as a fallback for permission errors.
          ; But it's better to leave some extraneous windows in the list than to throw an error message up,
          ; especially while some windows are hidden.
          ; Unfortunately, running as administrator doesn't help. It prevents errors, but fails to affect the windows.

          ; MakeSplash("Window Switcher", "Error hiding window (" WinGetTitle(Window) "):`n" e.Message)
        }
        TempHiddenWindows.Push(Window)
      }
    }
  }
  Send "{LAlt Down}"
  Send "{Blind}{Tab}" ; Tab or Shift+Tab to go in reverse
  KeyWait "LAlt"
  messages := []
  for Window in TempHiddenWindows {
    ; WinShow(Window)
    ; Don't need to remember WS_EX_TOOLWINDOW state, since we're not matching windows with WS_EX_TOOLWINDOW.
    ; Same should be true for any style that hides windows from the task switcher, if there's a better one.
    try {
      WinSetExStyle(WinGetExStyle(Window) & ~WS_EX_TOOLWINDOW, Window)
      ; MsgBox("Would show: " DescribeWindow(Window), "Window Switcher")
    } catch Error as e {
      ; Delay error messages until after the switcher is closed and all windows are unhidden that can be.
      messages.Push("Failed to unhide window from the task switcher.`n`n" DescribeWindow(Window) "`n`n" e.Message)
    }
  }
  TempHiddenWindows.Length := 0
  Send "{LAlt Up}" ; This could be earlier, couldn't it?

  for message in messages {
    MsgBox(message, "Window Switcher", 0x10)
  }
}

Switchable(Window) {
  ; Heuristics determine if a window is in the taskbar
  ; https://stackoverflow.com/a/2262791
  ExStyle := WinGetExStyle(Window)
  Style := WinGetStyle(Window)
  Taskbar := !(Style & WS_CHILD)
  if ExStyle & WS_EX_APPWINDOW {
    Taskbar := true
  }
  if ExStyle & WS_EX_TOOLWINDOW {
    Taskbar := false
  }
  ; if WinGetClass(Window) = "CabinetWClass" {
  ;   Taskbar := false
  ; }
  return Taskbar

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

DescribeWindow(Window) {
  Style := WinGetStyle(Window)
  StyleText := Style " (0x" Format("{:X}", Style) ") ("
  if Style & 0x800000 {
    StyleText .= "WS_BORDER "
  }
  if Style & 0x80000000 {
    StyleText .= "WS_POPUP "
  }
  if Style & 0xC00000 {
    StyleText .= "WS_CAPTION "
  }
  if Style & 0x4000000 {
    StyleText .= "WS_CLIPSIBLINGS "
  }
  if Style & 0x8000000 {
    StyleText .= "WS_DISABLED "
  }
  if Style & 0x400000 {
    StyleText .= "WS_DLGFRAME "
  }
  if Style & 0x20000 {
    StyleText .= "WS_GROUP "
  }
  if Style & 0x100000 {
    StyleText .= "WS_HSCROLL "
  }
  if Style & 0x1000000 {
    StyleText .= "WS_MAXIMIZE "
  }
  if Style & 0x10000 {
    StyleText .= "WS_MAXIMIZEBOX "
  }
  if Style & 0x20000000 {
    StyleText .= "WS_MINIMIZE "
  }
  if Style & 0x20000 {
    StyleText .= "WS_MINIMIZEBOX "
  }
  if Style & 0x0 {
    StyleText .= "WS_OVERLAPPED "
  }
  if Style & 0xCF0000 {
    StyleText .= "WS_OVERLAPPEDWINDOW "
  }
  if Style & 0x80880000 {
    StyleText .= "WS_POPUPWINDOW "
  }
  if Style & 0x40000 {
    StyleText .= "WS_SIZEBOX "
  }
  if Style & 0x80000 {
    StyleText .= "WS_SYSMENU "
  }
  if Style & 0x10000 {
    StyleText .= "WS_TABSTOP "
  }
  if Style & 0x40000 {
    StyleText .= "WS_THICKFRAME "
  }
  if Style & 0x200000 {
    StyleText .= "WS_VSCROLL "
  }
  if Style & 0x10000000 {
    StyleText .= "WS_VISIBLE "
  }
  if Style & 0x4000000 {
    StyleText .= "WS_CHILD "
  }
  return WinGetTitle(Window) "`nClass: " WinGetClass(Window) "`nProcess Name: " WinGetProcessName(Window) "`nMin/Max State: " WinGetMinMax(Window) "`nStyle: " StyleText
}

;--------------------------------------------------------
; Win+Tab to switch between windows (TODO: between apps)
;--------------------------------------------------------

; #Tab::
; {
;   Send "{LAlt Down}{Tab}"
;   KeyWait "LWin"  ; Wait to release left Win key
;   Send "{LAlt Up}" ; Close switcher on hotkey release
; }
; return

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
