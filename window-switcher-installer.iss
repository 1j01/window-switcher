; This is an Inno Setup script to install Window Switcher and App Switcher.
[Setup]
AppName=Window Switcher
AppVersion=1.0
VersionInfoVersion=1.0
AppPublisher=Isaiah Odhner
AppPublisherURL=https://github.com/1j01
AppSupportURL=https://github.com/1j01/window-switcher/issues
AppUpdatesURL=https://github.com/1j01/window-switcher/releases
AppReadmeFile=https://github.com/1j01/window-switcher/blob/main/README.md
AppCopyright=2024 Isaiah Odhner
AppContact=isaiahodhner@gmail.com
WizardStyle=modern
WizardImageFile=resources\window-switcher-installer-side-image.bmp
WizardSmallImageFile=resources\window-switcher-icon-128x128.bmp
WizardImageAlphaFormat=premultiplied

DefaultDirName={autopf}\Window Switcher
DefaultGroupName=Window Switcher
; UninstallDisplayIcon={app}\MyProg.exe
; OutputDir=userdocs:Inno Setup Examples Output
OutputBaseFilename=window-switcher-setup
; Requiring users to accept to the MIT license feels a bit overkill
; considering how permissive the license is... two extra clicks...
; but I don't know. Personally I kind of like seeing permissive licenses in installers.
; It's a nice change of pace to be able to say "hell yeah I agree to that shit"
; but really it would be nicer to have a no-interaction install experience like with Squirrel.Windows,
; and then a settings window to enable/disable the app switcher or window switcher.
; For now we're going old school.
; By the way, does the license need to be specified in the [Files] + [Components] sections?
; I should at least be able to remove it from the [Components] section:
; "An entry without a Components parameter is always processed, unless other parameters say it shouldn't be."
LicenseFile=LICENSE.txt

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
; It's not version-controlled this way. But for reference, I'm using AHK v2.0.11
; If I included it, it feels like it could bloat the repository when updating it, but maybe that would be super infrequent.
; Actually, "v2" is in the path, so it won't copy the wrong major version, which is nice. This is probably good enough.
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
; Quoting notes:
; - Inno Setup uses double double quotes ("") to denote a single double quote (") within a double-quoted string within the parameters.
;   See: https://jrsoftware.org/ishelp/index.php?topic=params
; - Single quotes around the path to the application are recommended here:
;   https://stackoverflow.com/questions/12250151/how-to-add-a-scheduled-task-with-inno-setup
;   but they give an example only of unquoted parameters,
;   and I feel like single quotes won't work there?
; - I managed to get it working with double quotes escaped with backslahes,
;   by building the command to run in cmd.exe and then doubling the quotes,
;   and wrapping it in quotes, and substituting concrete paths with substitutions.
; For testing, this command can be run in admin command prompt (cmd.exe, not PowerShell or Git Bash):
;   schtasks /Create /F /RL Highest /SC OnLogon /TR "\"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe\" \"C:\Users\Isaiah\Projects\window-switcher\window-switcher.ahk\"" /TN "Run Window Switcher on logon"
; Quoted:
;   "/Create /F /RL Highest /SC OnLogon /TR ""\""C:\Program Files\AutoHotkey\v2\AutoHotkey.exe\"" \""C:\Users\Isaiah\Projects\window-switcher\window-switcher.ahk\"""" /TN ""Run Window Switcher on logon"""
; It's kind of insane. But at least it only has to run on one operating system.
; (In at least one project, I've ended up with octuple backslashes, for real. And it only worked on some operating systems due to redundant backslashes being ignored, since it was interpreted differently across OSes.)
Filename: "schtasks"; \
	Parameters: "/Create /F /RL Highest /SC OnLogon /TR ""\""{app}\AutoHotkey.exe\"" \""{app}\window-switcher.ahk\"""" /TN ""Run Window Switcher on logon"""; \
	Flags: runhidden; \
	Components: window_switcher and run_at_logon
Filename: "schtasks"; \
	Parameters: "/Create /F /RL Highest /SC OnLogon /TR ""\""{app}\AutoHotkey.exe\"" \""{app}\app-switcher.ahk\"""" /TN ""Run App Switcher on logon"""; \
	Flags: runhidden; \
	Components: app_switcher and run_at_logon

[UninstallRun]
Filename: "schtasks"; Parameters: "/Delete /F /TN ""Run Window Switcher on logon"""; Flags: runhidden; Components: window_switcher and run_at_logon; RunOnceId: "delete_window_switcher_logon_task"
Filename: "schtasks"; Parameters: "/Delete /F /TN ""Run App Switcher on logon"""; Flags: runhidden; Components: app_switcher and run_at_logon; RunOnceId: "delete_app_switcher_logon_task"

