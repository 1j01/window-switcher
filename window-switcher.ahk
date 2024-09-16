; Requires AutoHotkey v2

;--------------------------------------------------------
; Alt+` to switch between windows of the same application
;--------------------------------------------------------

; This script piggybacks on the built-in Alt+Tab window switcher,
; filtering it to show only windows from the same process as the active window.
; It listens for Alt+` and Alt+Shift+` and converts them to Alt+Tab and Alt+Shift+Tab, respectively,
; after hiding windows from the task switcher with the ITaskbarList API,
; and then unhiding them after the switcher is closed.
; Pressing ` again while holding Alt will tab through the windows of the same application,
; and Shift+` will tab through them in reverse.
; Tab or Shift+Tab also works (automatically, since that's what the switcher normally uses.)

; Limitations:
; - Windows are hidden from the task bar as well, which can be distracting,
;   especially with taskbar button labels enabled, as it animates the taskbar buttons collapsing and expanding.
; - Some windows are not hidden from the task switcher, such as the Task Manager, due to permission errors.
;   - Running as administrator fixes this.
; - UWP windows, such as Windows's Settings app, are not filtered out either.
;   - They don't play well with any of the methods I've tried (WinHide, WinSetExStyle, ITaskbarList.DeleteTab).

; TODO: remove windows from task switcher only, and not the task bar.
; Adding WS_EX_TOOLWINDOW is much faster than WinHide/WinShow (it makes the actual interaction instantaneous!),
; but it still causes distracting animation in the taskbar, particularly when taskbar button labels are enabled.
; Is there a less obtrusive way to remove windows from the task switcher?

#MaxThreadsPerHotkey 2

TraySetIcon "shell32.dll", 99 ; overlapped windows icon - supposedly Icon ID 185 in IconsExtract, but I had to find it through trial and error in practice

A_TrayMenu.Add()  ; Creates a separator line.
A_TrayMenu.Add("Report Issue", MenuHandler)
A_TrayMenu.Add("Project Homepage", MenuHandler)

MenuHandler(ItemName, ItemPos, MyMenu) {
  if ItemName = "Report Issue" {
    Run("https://github.com/1j01/window-switcher/issues")
  } else if ItemName = "Project Homepage" {
    Run("https://github.com/1j01/window-switcher/")
  }
}


WS_EX_APPWINDOW := 0x00040000
WS_EX_TOOLWINDOW := 0x00000080
WS_CHILD := 0x40000000

IID_ITaskbarList := "{56FDF342-FD6D-11d0-958A-006097C9A090}"
CLSID_TaskbarList := "{56FDF344-FD6D-11d0-958A-006097C9A090}"

ITaskbarList_VTable := {
  HrInit: 3,
  AddTab: 4,
  DeleteTab: 5,
  ActivateTab: 6,
  SetActiveAlt: 7,
}
; Create the TaskbarList object.
TaskbarList := ComObject(CLSID_TaskbarList, IID_ITaskbarList)
TaskbarListInitialized := False

TempHiddenWindows := []
; OriginalExStyles := Map()

!+`:: {
  FilteredWindowSwitcher()
}
!`:: {
  FilteredWindowSwitcher()
}
FilteredWindowSwitcher() {
  global TaskbarListInitialized, TempHiddenWindows
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
          ; ExStyle := WinGetExStyle(Window)  ; redundantly accessed in Switchable...
          ; OriginalExStyles[Window] := ExStyle
          ; if WinGetClass(Window) = "ApplicationFrameWindow" {
          ;   ; This is a Windows UWP app. It doesn't work to add WS_EX_TOOLWINDOW (though it doesn't generate an error).
          ;   ; In fact, not even replacing all styles works:
          ;   ; WinSetExStyle(WS_EX_TOOLWINDOW, Window)
          ;   ; WinSetStyle(WS_CHILD, Window)
          ;   ; WinHide doesn't work either, for UWP apps.
          ;   ; It hides the window itself, but it doesn't hide it from the task switcher or the task bar.
          ;   ; TODO: Find a way to hide UWP apps from the task switcher. This is pretty annoying!
          ;   ; My only real idea is to move the window to a different virtual desktop,
          ;   ; which would only work well with "Show all open windows when I press Alt+Tab" set to "Only on the desktop I'm using",
          ;   ; and ideally with "On the taskbar, show all open windows" set to "On all desktops",
          ;   ; which theoretically could avoid the taskbar animation, which could be nice for other windows as well.
          ;   ; (These settings are in Multitasking in Settings.)
          ;   ; No idea if it would be performant enough. There's a library for this though: https://github.com/FuPeiJiang/VD.ahk
          ;   ; Perhaps that just speaks to the complexity of the solution though.
          ;   ; It might be better to reimplement a task switcher from scratch at that point, though it would never look quite the same.
          ;   ; WinHide(Window)
          ;   ; Um, MakeSplash is no good here, since it blocks execution. But it's useful for debugging.
          ;   ; MakeSplash("Window Switcher", "Hiding UWP app window: " WinGetTitle(Window), 1000)
          ;   ; MakeSplash("Window Switcher", "Can't hide UWP app window from task switcher: " WinGetTitle(Window), 1000)
          ; } else {
          ;   ; I have not seen any benefit to removing WS_EX_APPWINDOW, but I don't know if I've seen any windows with it.
          ;   ; It may help in some cases, if I've done it right, but I don't know.
          ;   WinSetExStyle(ExStyle | WS_EX_TOOLWINDOW & ~WS_EX_APPWINDOW, Window)
          ; }

          if (!TaskbarListInitialized) {
            ComCall(ITaskbarList_VTable.HrInit, TaskbarList)
            TaskbarListInitialized := True
          }
          ComCall(ITaskbarList_VTable.DeleteTab, TaskbarList, "ptr", Window)

          TempHiddenWindows.Push(Window)
        } catch Error as e {
          ; WinSetExStyle can get permission errors for certain windows, such as the Task Manager,
          ; unless running as administrator.
          ; But it's better to leave some extraneous windows in the list than to throw an error message up
          ; (especially while some windows are hidden, though I've made an array to delay the messages now.)
          ; UWP apps don't throw an error, but fail silently.
          ; TaskBarList.DeleteTab also fails silently without admin rights.

          ; Messages.Push("Error hiding window from the task switcher.`n`n" DescribeWindow(Window) "`n`n" e.Message)
        }
      }
    }
  }
  Send "{LAlt Down}"
  Send "{Blind}{Tab}" ; Tab or Shift+Tab to go in reverse
  KeyWait "LAlt"
  ; MakeSplash("Window Switcher", "Alt (physical key) released", 1000)
  for Window in TempHiddenWindows {
    ; If WinShow is ever used for a fallback, it should not be called for all windows, and it should be called at the end, so it doesn't slow things down for every window.
    ; WinShow(Window)

    ; Don't need to remember WS_EX_TOOLWINDOW state, since we're not matching windows with WS_EX_TOOLWINDOW.
    ; Restore WS_EX_APPWINDOW, if it was set.
    ; My first instinct was to allow other styles to change while hidden, as this may avoid problems with some apps,
    ; but styles may be forced to change as a result of WS_EX_TOOLWINDOW / removing WS_EX_APPWINDOW, I'm not sure.
    try {
      ; WinSetExStyle(WinGetExStyle(Window) & ~WS_EX_TOOLWINDOW | (OriginalExStyles[Window] & WS_EX_APPWINDOW), Window)
      ; WinSetExStyle(OriginalExStyles[Window], Window)

      ComCall(ITaskbarList_VTable.AddTab, TaskbarList, "ptr", Window)

      ; MsgBox("Would show:`n`n" DescribeWindow(Window), "Window Switcher")
    } catch Error as e {
      ; Delay error messages until after the switcher is closed and all windows are unhidden that can be.
      Messages.Push("Failed to unhide window from the task switcher.`n`n" DescribeWindow(Window) "`n`n" e.Message)
    }
  }
  TempHiddenWindows.Length := 0
  ; MakeSplash("Window Switcher", "Closing switcher (triggering logical release of Alt)", 1000)
  Send "{LAlt Up}" ; This could be earlier, couldn't it?
  ; MakeSplash("Window Switcher", "Switcher closed.", 1000)

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