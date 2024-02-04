;--------------------------------------------------------
; Alt+` to switch between windows of the same application
;--------------------------------------------------------
; Version from https://superuser.com/a/1783158
; !`:: {
;   OldClass := WinGetClass("A")
;   ActiveProcessName := WinGetProcessName("A")
;   WinClassCount := WinGetCount("ahk_exe " ActiveProcessName)
;   if WinClassCount = 1 {
;     return
;   }
;   loop 2 {
;     WinMoveBottom("A")
;     WinActivate("ahk_exe" ActiveProcessName)
;     NewClass := WinGetClass("A")
;     if (OldClass != "CabinetWClass" or NewClass = "CabinetWClass") {
;       break
;     }
;   }
; }

; Improved version: hide all windows except those from the same process,
; then trigger Alt+Tab to switch between them.
; TODO: just remove windows from task switcher, don't hide them

#MaxThreadsPerHotkey 2

WS_EX_APPWINDOW := 0x00040000
WS_EX_TOOLWINDOW := 0x00000080
WS_CHILD := 0x40000000
TempHiddenWindows := []
!+`:: {
  if TempHiddenWindows.Length {
    Send "{Blind}{Tab}"
  }
}
!`:: {
  if TempHiddenWindows.Length {
    ; Needs #MaxThreadsPerHotkey 2 to handle Alt+`+`+`... to tab through windows with `, while waiting for Alt to be released
    Send "{Blind}{Tab}"
    return
  }
  ActiveProcessName := WinGetProcessName("A")
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
      if Taskbar {
        WinHide(Window)
        ; MsgBox("Would hide: " DescribeWindow(Window))
        TempHiddenWindows.Push(Window)
      }
    }
  }
  Send "{LAlt Down}{Tab}"
  KeyWait "LAlt"
  for Window in TempHiddenWindows {
    WinShow(Window)
    ; MsgBox("Would show: " DescribeWindow(Window))
  }
  TempHiddenWindows.Length := 0
  Send "{LAlt Up}"
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
    SplashGui := MakeSplash("AHK Auto-Reload", "`n  Reloading " A_ScriptName "  `n")
    Sleep(500)
    SplashGui.Destroy()
    Reload
  }
}
MakeSplash(Title, Text) {
  SplashGui := Gui(, Title)
  SplashGui.Opt("+AlwaysOnTop +Disabled -SysMenu +Owner")  ; +Owner avoids a taskbar button.
  SplashGui.Add("Text", , Text)
  SplashGui.Show("NoActivate")  ; NoActivate avoids deactivating the currently active window.
  return SplashGui
}
