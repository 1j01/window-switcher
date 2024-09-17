; This is an Inno Setup script to install Window Switcher and App Switcher.
[Setup]
AppName=Window Switcher
AppVersion=1.0
AppPublisher=Isaiah Odhner
AppPublisherURL=https://github.com/1j01
AppSupportURL=https://github.com/1j01/window-switcher/issues
AppUpdatesURL=https://github.com/1j01/window-switcher/releases
AppReadmeFile=https://github.com/1j01/window-switcher/blob/main/README.md
WizardStyle=modern
DefaultDirName={autopf}\Window Switcher
DefaultGroupName=Window Switcher
; UninstallDisplayIcon={app}\MyProg.exe
; OutputDir=userdocs:Inno Setup Examples Output

[Types]
Name: "full"; Description: "Full installation"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
Name: "window_switcher"; Description: "Window Switcher"; Types: full custom
Name: "app_switcher"; Description: "App Switcher"; Types: full custom
Name: "run_at_logon"; Description: "Run at logon"; Types: full custom
; Name: "help"; Description: "Help File"; Types: full
Name: "readme"; Description: "Readme File"; Types: full
; Name: "readme\en"; Description: "English"; Flags: exclusive
; Name: "readme\de"; Description: "German"; Flags: exclusive
Name: "license"; Description: "License File"; Types: full custom; Flags: fixed

[Files]
; Should I include AutoHotkey.exe in the repository?
; It's not version-controlled this way. But I for reference, I'm using AHK v2.0.11
; If I included it, it feels like it could bloat the repository when updating it, but maybe that would be super infrequent.
Source: "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe"; DestDir: "{app}"; Components: window_switcher app_switcher
Source: "window-switcher.ahk"; DestDir: "{app}"; Components: window_switcher
Source: "app-switcher.ahk"; DestDir: "{app}"; Components: app_switcher
Source: "GuiEnhancerKit.ahk"; DestDir: "{app}"; Components: app_switcher
Source: "resources\*"; DestDir: "{app}\resources"; Components: app_switcher
; Source: "MyProg.chm"; DestDir: "{app}"; Components: help
; Changing the extension to .txt so that the file can be opened with notepad by default.
Source: "README.md"; DestName: "README.txt"; DestDir: "{app}"; Components: readme; Flags: isreadme
; Source: "Readme.txt"; DestDir: "{app}"; Components: readme\en; Flags: isreadme
; Source: "Readme-German.txt"; DestName: "Liesmich.txt"; DestDir: "{app}"; Components: readme\de; Flags: isreadme
; (Should the license really be a component?)
Source: "LICENSE.txt"; DestDir: "{app}"; Components: license

[Icons]
; This section defines shortcuts to open programs. I'm not sure if it really makes sense here.
; I mean I do have the run-at-logon as an option, but idk why you'd want to have to run it manually.
; Could specify the icon with IconFilename and IconIndex.
; Not sure about triple quotes.
Name: "{group}\Window Switcher"; Filename: "{app}\AutoHotkey.exe"; Parameters: """{app}\window-switcher.ahk"""
Name: "{group}\App Switcher"; Filename: "{app}\AutoHotkey.exe"; Parameters: """{app}\app-switcher.ahk"""
Name: "{group}\Uninstall Window Switcher + App Switcher"; Filename: "{uninstallexe}"
