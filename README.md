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
2. Download `window-switcher.ahk`
3. Set `window-switcher.ahk` to run on startup

### Application Switcher

Note: unlike the Window Switcher, the Application Switcher is a totally custom UI.
It won't perfectly match the Windows theme.

1. Install [AutoHotkey v2](https://www.autohotkey.com/)
2. Download `app-switcher.ahk` and the `resources` folder
3. Set `app-switcher.ahk` to run on startup

## Known Issues

- Windows are hidden from the task bar as well, which can be distracting,
  especially with taskbar button labels enabled, as it animates the taskbar buttons collapsing and expanding.
  - ❌ I don't know of any way to hide windows from the task switcher without hiding them from the taskbar.
- Some windows are not hidden from the task switcher, such as the Task Manager, due to permission errors.
  - 🛡️✅ Running as administrator fixes this.
- UWP windows, such as Windows's Settings app, are not filtered out either.
  - ❌ They don't play well with any of the methods I've tried (`WinHide`, `WinSetExStyle`, `ITaskbarList.DeleteTab`).
- When running on startup, an error may be thrown due to initializing `ITaskbarList` too early.
  - ✅ Clicking "Reload Script" will fix this.
- In the app switcher:
  - Some apps provide only a very high resolution icon, which is not scaled down. The correct size is used if available.
  - Vertical alignment is a bit off.
  - There's no acrylic blur effect. I tried to implement it (see `blurbehind.ahk` in git history), but couldn't get it to work.
  - There's no way to close the app switcher without selecting an app.
	- Pressing <kbd>Esc</kbd> causes `Error: Gui has no window.`

## License

This project is licensed under the MIT License - see the [LICENSE.txt](LICENSE.txt) file for details.

## TODO

- Fix error on startup about `ITaskbarList`
  - Switch back to initializing `ITaskbarList` as-needed instead of up-front, but still only once
- Compile the scripts into executables
  - Figure out how to handle the `resources` folder
  - Create GitHub release
- Clarify the installation instructions, especially setting up the scripts to run on startup
- Copy over a few VS Code settings, recommended extension, and spelling dictionary
- Add screenshots/gifs