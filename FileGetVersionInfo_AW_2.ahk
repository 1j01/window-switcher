FileGetVersionInfo_AW(PEFile := "", Fields := ["FileDescription"]) {
  ; Written by SKAN
  ; https://www.autohotkey.com/forum/viewtopic.php?t=64128       CD:24-Nov-2008 / LM:28-May-2010
  ; Updated for AHK v2 by 1j01                                   2024-02-12
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
  TranslationHex := Buffer(16)
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


#SingleInstance Force

TargetFile := A_AhkPath
; TargetFile := A_WinDir "\System32\calc.exe"
Info := FileGetVersionInfo_AW(TargetFile, ["FileDescription", "FileVersion", "InternalName", "LegalCopyright", "OriginalFilename", "ProductName", "ProductVersion", "CompanyName", "PrivateBuild", "SpecialBuild", "LegalTrademarks"])
InfoString := ""
for Key, Value in Info
  InfoString .= Key ": " Value "`n"
MsgBox("Retrieved info for " TargetFile "`n`n" InfoString)


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