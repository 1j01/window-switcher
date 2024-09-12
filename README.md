# Window Switcher

This small utility augments the native window switching capabilities of Windows.

It provides shortcuts found on many other operating systems, that are sorely missing from Windows.

## Features

- <kbd>Alt+`</kbd> to switch between windows of the same application
- <kbd>Win+Tab</kbd> to switch between applications
- <kbd>Shift</kbd> to cycle in reverse
- ✨ Uses the native Windows window switching UI ✨
  - This means it looks and behaves exactly like the native window switcher
  - It will continue to match the Windows theme even if Microsoft overhauls their UI style

## Installation

### Window Switcher
1. Install [AutoHotkey v2](https://www.autohotkey.com/)
2. Download [`window-switcher.ahk`](window-switcher.ahk)
3. Set `window-switcher.ahk` to run on startup (see below)

### Application Switcher

Note: unlike the Window Switcher, the Application Switcher is a totally custom UI.
However, it's designed to match the Windows 11 theme, and will use Mica blur-behind effect.

1. Install [AutoHotkey v2](https://www.autohotkey.com/)
2. Download `app-switcher.ahk` and `GuiEnhancerKit.ahk` and the `resources` folder.
   The easiest way is to [download the entire repository as a zip file](https://github.com/1j01/window-switcher/archive/refs/heads/main.zip).
3. Set `app-switcher.ahk` to run on startup (see below)

### Running on Startup

- To run at startup with administrator privileges:
  - Place the script somewhere permanent, since moving or renaming it will break the startup action.
    - In the case of the app switcher, the `resources` folder must be in the same directory as the script.
  - Open Task Scheduler
  - Action > Create Task...
  - Check "Run with highest privileges" in "Security options" in General tab
  - In Triggers tab, click "New..." and set the type to "At log on"
  - For the Action, you can browse for the script.

## Known Issues

- Windows are hidden from the task bar as well, which can be distracting,
  especially with taskbar button labels enabled, as it animates the taskbar buttons collapsing and expanding.
  - ❌ I don't know of any way to hide windows from the task switcher without hiding them from the taskbar.
- Some windows are not hidden from the task switcher, such as the Task Manager, due to permission errors.
  - 🛡️✅ Running as administrator fixes this.
- UWP windows, such as Windows's Settings app, are not filtered out either.
  - ❌ They don't play well with any of the methods I've tried (`WinHide`, `WinSetExStyle`, `ITaskbarList.DeleteTab`).
- When running on startup, an error may be thrown due to initializing `ITaskbarList` too early.
  - ✅ Clicking "Reload Script" will fix this. I have a permanent fix planned.
- In the app switcher:
  - ❌ There's no way to close the app switcher without selecting an app.
	- Pressing <kbd>Esc</kbd> causes `Error: Gui has no window.`
  - ✂️ Apps are not distinguished by their shortcut, so for instance, PWAs installed with Chrome will be lumped in with "Google Chrome".
  - Can sometimes get an error `Error: Gui has no window.` at `Pic := AppSwitcher.FocusedCtrl`

## License

This project is licensed under the MIT License - see the [LICENSE.txt](LICENSE.txt) file for details.

## TODO

- Fix error on startup about `ITaskbarList`
  - Switch back to initializing `ITaskbarList` as-needed instead of up-front, but still only once
- Compile the scripts into executables
  - Figure out how to handle the resources needed for the app switcher (embed but allow them to be overridden with external files?)
  - Create GitHub release
  - Simplify installation instructions
- Add screenshots/gifs

## Development

- The script will automatically reload if you press Ctrl+S on a window with the script's name in the title
- The [VS Code extension for AutoHotkey v2](https://marketplace.visualstudio.com/items?itemName=thqby.vscode-autohotkey2-lsp) provides auto-formatting among many other features