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
OutputBaseFilename=window-switcher-installer

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

[Tasks]
; Don't really want icons tbh.
; Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Components: window_switcher app_switcher
; Name: "quicklaunchicon"; Description: "Create a &Quick Launch icon"; GroupDescription: "Additional icons:"; Components: window_switcher app_switcher; Flags: unchecked
; Not using this task since it created a redundant checkbox.
; Might want to figure out how to have just one checkbox instead of the two that show up from the Run section.
; Name: "runafterinstall"; Description: "Run after installation"; GroupDescription: "Other tasks:"; Flags: checkedonce

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
; Name: "{autodesktop}\Window Switcher"; Filename: "{app}\AutoHotkey.exe"; Parameters: """{app}\window-switcher.ahk"""; Tasks: desktopicon; Components: window_switcher
; Name: "{autodesktop}\App Switcher"; Filename: "{app}\AutoHotkey.exe"; Parameters: """{app}\app-switcher.ahk"""; Tasks: desktopicon; Components: app_switcher
; Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\Window Switcher"; Filename: "{app}\AutoHotkey.exe"; Parameters: """{app}\window-switcher.ahk"""; Tasks: quicklaunchicon; Components: window_switcher
; Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\App Switcher"; Filename: "{app}\AutoHotkey.exe"; Parameters: """{app}\app-switcher.ahk"""; Tasks: quicklaunchicon; Components: app_switcher

; [Registry]
; Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Window Switcher"; ValueData: """{app}\AutoHotkey.exe"" ""{app}\window-switcher.ahk"""; Flags: uninsdeletevalue; Components: window_switcher run_at_logon
; Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "App Switcher"; ValueData: """{app}\AutoHotkey.exe"" ""{app}\app-switcher.ahk"""; Flags: uninsdeletevalue; Components: app_switcher run_at_logon

[Run]
Filename: "{app}\AutoHotkey.exe"; Parameters: """{app}\window-switcher.ahk"""; Description: "Run Window Switcher"; Flags: nowait postinstall skipifsilent runascurrentuser; Components: window_switcher
Filename: "{app}\AutoHotkey.exe"; Parameters: """{app}\app-switcher.ahk"""; Description: "Run App Switcher"; Flags: nowait postinstall skipifsilent runascurrentuser; Components: app_switcher
; Note: the task names MUST be the same in the uninstall section.
; Quote notes:
; - Inno Setup uses double double quotes ("") to denote a single double quote (") within a double-quoted string within the parameters.
;   See: https://jrsoftware.org/ishelp/index.php?topic=params
; - Single quotes around the path to the application recommended here:
;   https://stackoverflow.com/questions/12250151/how-to-add-a-scheduled-task-with-inno-setup
; - Dunno about quoting the parameters within the string within the parameters within the string within the parameters...
;   Double double quotes look wrong but I doubt single quotes will work?

Filename: "schtasks"; \
	Parameters: "/Create /F /RL highest /SC onlogon /TR ""'{app}\AutoHotkey.exe' ""{app}\window-switcher.ahk"""" /TN ""Run Window Switcher on logon"""; \
	Flags: runhidden; \
	Components: window_switcher and run_at_logon
Filename: "schtasks"; \
	Parameters: "/Create /F /RL highest /SC onlogon /TR ""'{app}\AutoHotkey.exe' ""{app}\app-switcher.ahk"""" /TN ""Run App Switcher on logon"""; \
	Flags: runhidden; \
	Components: app_switcher and run_at_logon

[UninstallRun]
Filename: "schtasks"; Parameters: "/Delete /F /TN ""Run Window Switcher on logon"""; Flags: runhidden; Components: window_switcher and run_at_logon
Filename: "schtasks"; Parameters: "/Delete /F /TN ""Run App Switcher on logon"""; Flags: runhidden; Components: app_switcher and run_at_logon

