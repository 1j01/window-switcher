; FileGetVersionInfo_AW(peFile := "", StringFileInfo := "", Delimiter := "|") {    ; Written by SKAN
;   ; www.autohotkey.com/forum/viewtopic.php?t=64128          CD:24-Nov-2008 / LM:28-May-2010
;   Wide := true
;   CS := Wide ? "W" : "A"
;   Spaces := "                        "
;   DLL := "Version\"
;   HexVal := "msvcrt\s" (Wide ? "w" : "") "printf"
;   If !FVISize := DllCall(DLL "GetFileVersionInfoSize" CS, "Str", peFile, "UInt", 0) {
;     DllCall("SetLastError", "UInt", 1)
;     Return ""
;   }
;   FVI := Buffer(FVISize, 0)
;   Trans := "" ;?
;   VarSetStrCapacity(&Trans, 8 * (1 ? 2 : 1)) ; V1toV2: if 'Trans' is NOT a UTF-16 string, use 'Trans := Buffer(8 * ( A_IsUnicode ? 2 : 1 ))'
;   DllCall(DLL "GetFileVersionInfo" CS, "Str", peFile, "Int", 0, "UInt", FVISize, "UInt*", &FVI)
;   If !DllCall(DLL "VerQueryValue" CS, "UInt", FVI, "Str", "\VarFileInfo\Translation", "UIntP", &Translation, "UInt", 0) {
;     DllCall("SetLastError", "UInt", 2)
;     Return ""
;   }
;   If !DllCall(HexVal, "Str", Trans, "Str", "%08X", "UInt", NumGet(Translation + 0, "UPtr")) {
;     DllCall("SetLastError", "UInt", 3)
;     Return ""
;   }
;   Loop Parse, StringFileInfo, Delimiter
;   { subBlock := "\StringFileInfo\" SubStr(Trans, -4) SubStr(Trans, 1, 4) "\" A_LoopField
;     If !DllCall(DLL "VerQueryValue" CS, "UInt", FVI, "Str", SubBlock, "UIntP", &InfoPtr, "UInt", 0)
;       Continue
;     Value := DllCall("MulDiv", "UInt", InfoPtr, "Int", 1, "Int", 1, "Str")
;     Info .= Value ? ((InStr(StringFileInfo, Delimiter) ? SubStr(A_LoopField Spaces, 1, 24) . A_Tab : "") . Value . Delimiter) : ""
;   }
;   Info := RTrim(Info, 1)
;   Return Info
; }

FileGetVersionInfo_AW_IO(peFile := "", Fields := ["FileDescription"]) {
  ; Written by SKAN
  ; https://www.autohotkey.com/forum/viewtopic.php?t=64128       CD:24-Nov-2008 / LM:28-May-2010
  ; Updated for AHK v2 by 1j01                                   2024-02-12
  DLL := "Version\"
  if !FVISize := DllCall(DLL "GetFileVersionInfoSizeW", "Str", peFile, "UInt", 0) {
    throw Error("Error: Unable to retrieve file version information size.")
  }
  FVI := Buffer(FVISize, 0)
  Translation := 0
  DllCall(DLL "GetFileVersionInfoW", "Str", peFile, "Int", 0, "UInt", FVISize, "Ptr", FVI)
  if !DllCall(DLL "VerQueryValueW", "Ptr", FVI, "Str", "\VarFileInfo\Translation", "UIntP", &Translation, "UInt", 0) {
    throw Error("Error: Unable to retrieve file version translation information.")
  }
  TranslationHex := Buffer(16)
  ; if !DllCall("wsprintf", "Ptr", TranslationHex, "Str", "%08X", "UInt", NumGet(Translation + 0, "UPtr"), "Cdecl") {
  if !DllCall("wsprintf", "Ptr", TranslationHex, "Str", "%08X", "UInt", Translation, "Cdecl") {
    throw Error("Error: Unable to format number as hexadecimal.")
  }
  TranslationHex := StrGet(TranslationHex, , "UTF-16")
  TranslationCode := SubStr(TranslationHex, -4) SubStr(TranslationHex, 1, 4)
  MsgBox((
    "peFile: " peFile
    "FVISize: " FVISize "`n"
    "FVI: " StrGet(FVI, ,) "`n"
    "Translation: " Translation "`n"
    "TranslationHex: " TranslationHex "`n"
    "TranslationCode: " TranslationCode "`n"
  ))
  PropertiesMap := Map()
  for Field in Fields {
    subBlock := "\StringFileInfo\" TranslationCode "\" Field
    InfoPtr := 0
    if !DllCall(DLL "VerQueryValueW", "Ptr", FVI, "Str", SubBlock, "UIntP", &InfoPtr, "UInt", 0) {
      PropertiesMap[Field] := "?" ; TODO: remove this line
      continue
    }
    Value := DllCall("MulDiv", "UInt", InfoPtr, "Int", 1, "Int", 1, "Str")
    PropertiesMap[Field] := Value
  }
  return PropertiesMap
}


#SingleInstance Force

; Loop Files, A_WinDir "\System32\*.??l"
;   Files .= "`n" A_LoopFileFullPath
; Files := A_AhkPath . Files

; StringFileInfo := "
; ( LTrim
; [color=#800000]  FileDescription
;   FileVersion
;   InternalName
;   LegalCopyright
;   OriginalFilename
;   ProductName
;   ProductVersion
;   CompanyName
;   PrivateBuild
;   SpecialBuild
;   LegalTrademarks
; [/color]
; )"

; Loop Parse, Files, "`n"
;   If VI := FileGetVersionInfo_AW(A_LoopField, StringFileInfo, "`n")
;     MsgBox(A_LoopField "`n" VI)

TargetFile := A_AhkPath
; TargetFile := A_WinDir "\System32\calc.exe"
Info := FileGetVersionInfo_AW_IO(TargetFile, ["FileDescription", "FileVersion", "InternalName", "LegalCopyright", "OriginalFilename", "ProductName", "ProductVersion", "CompanyName", "PrivateBuild", "SpecialBuild", "LegalTrademarks"])
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