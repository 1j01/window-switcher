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
OriginalExStyles := Map()
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
  Messages := []
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
        try {
          ; MsgBox("Would hide:`n`n" DescribeWindow(Window), "Window Switcher")
          ExStyle := WinGetExStyle(Window)  ; redundantly accessed in Switchable...
          OriginalExStyles[Window] := ExStyle
          if WinGetClass(Window) = "ApplicationFrameWindow" {
            ; This is a Windows UWP app. It doesn't work to add WS_EX_TOOLWINDOW (though it doesn't generate an error).
            ; TODO: investigate why WinHide isn't working either, even though in a separate script, it does work
            ; with UWP apps. Maybe it only works on the active window? Maybe it has to do with the alt+tab switcher?
            WinHide(Window)
            MakeSplash("Window Switcher", "Hiding UWP app window: " WinGetTitle(Window), 1000)
          } else {
            ; I have not seen any benefit to removing WS_EX_APPWINDOW, but I don't know if I've seen any windows with it.
            ; It may help in some cases, if I've done it right, but I don't know.
            WinSetExStyle(ExStyle | WS_EX_TOOLWINDOW & ~WS_EX_APPWINDOW, Window)
          }
          TempHiddenWindows.Push(Window)
        } catch Error as e {
          ; It gets permission errors for certain windows, such as the Task Manager.
          ; Note: WinHide/WinShow doesn't work as a fallback for permission errors.
          ; But it's better to leave some extraneous windows in the list than to throw an error message up,
          ; especially while some windows are hidden.
          ; Unfortunately, running as administrator doesn't help. It prevents errors, but fails to affect the windows.

          ; Messages.Push("Error hiding window from the task switcher.`n`n" DescribeWindow(Window) "`n`n" e.Message)
        }
      }
    }
  }
  Send "{LAlt Down}"
  Send "{Blind}{Tab}" ; Tab or Shift+Tab to go in reverse
  KeyWait "LAlt"
  for Window in TempHiddenWindows {
    ; In case of UWP apps
    WinShow(Window)
    ; Don't need to remember WS_EX_TOOLWINDOW state, since we're not matching windows with WS_EX_TOOLWINDOW.
    ; Restore WS_EX_APPWINDOW, if it was set. Don't change other styles; allow them to change while hidden.
    try {
      WinSetExStyle(WinGetExStyle(Window) & ~WS_EX_TOOLWINDOW | (OriginalExStyles[Window] & WS_EX_APPWINDOW), Window)
      ; MsgBox("Would show:`n`n" DescribeWindow(Window), "Window Switcher")
    } catch Error as e {
      ; Delay error messages until after the switcher is closed and all windows are unhidden that can be.
      Messages.Push("Failed to unhide window from the task switcher.`n`n" DescribeWindow(Window) "`n`n" e.Message)
    }
  }
  TempHiddenWindows.Length := 0
  Send "{LAlt Up}" ; This could be earlier, couldn't it?

  for message in Messages {
    MsgBox(message, "Window Switcher", 0x10)
  }
}

Switchable(Window) {
  ; Heuristics determine if a window is in the taskbar
  ; https://stackoverflow.com/a/2262791
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

DescribeWindow(Window) {
  return "Window Title: " WinGetTitle(Window) "`nWindow Class: " WinGetClass(Window) "`nProcess Name: " WinGetProcessName(Window)
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