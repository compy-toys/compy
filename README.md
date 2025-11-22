# Compy

A console-based Lua-programmable computer for children based on
the [LÖVE2D][löve2d] framework.

## Principles

- Command-line based UI
- Full control over each pixel of the display
- Ability to easily reset to initial state
- Impossible to damage with non-violent interaction
- Syntactic mistakes caught early, not accepted on input
- Possibility to test/try parts of program separately
- Share software in source package form
- Minimize frustration

# Usage (IDE mode)

Rather than the default LÖVE storage locations (save directory,
cache, etc), the application uses a folder under _Documents_ to
store projects. Ideally, this is located on removable storage to
enable sharing programs the user writes.

For simplicity and security reasons, the user is only allowed to
access files inside a project. To interact with the filesystem,
a project must be selected first.

## Keys

| Command                                                           | Combination                                   |
| :---------------------------------------------------------------- | :-------------------------------------------- |
| Clear terminal                                                    | <kbd>Ctrl</kbd>+<kbd>L</kbd>                  |
| Stop project                                                      | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>S</kbd> |
| Quit project (stop and close)                                     | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Q</kbd> |
| Reset application to initial state                                | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd> |
| Reset project to initial state                                    | <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>R</kbd>   |
| Exit application                                                  | <kbd>Ctrl</kbd>+<kbd>Esc</kbd>                |
| Pause project                                                     | <kbd>Ctrl</kbd>+<kbd>Pause</kbd>              |
| Toggle edit/run                                                   | <kbd>F8</kbd>                                 |
| **Input**                                                         |                                               |
| Move cursor horizontally                                          | <kbd>⇦</kbd>/<kbd>⇨</kbd>                     |
| Move cursor vertically                                            | <kbd>⇧</kbd>/<kbd>⇩</kbd>                     |
| Go back in command history                                        | <kbd>PageUp</kbd>                             |
| Go forward in command history                                     | <kbd>PageDown</kbd>                           |
| Move in history (if in first/last line)                           | <kbd>⇧</kbd>/<kbd>⇩</kbd>                     |
| Jump to start                                                     | <kbd>Home</kbd>                               |
| Jump to end                                                       | <kbd>End</kbd>                                |
| Jump to line start                                                | <kbd>Alt</kbd>+<kbd>Home</kbd>                |
| Jump to line end                                                  | <kbd>Alt</kbd>+<kbd>End</kbd>                 |
| Insert newline                                                    | <kbd>Shift</kbd>+<kbd>Enter ⏎</kbd>           |
| Delete current line                                               | <kbd>Ctrl</kbd>+<kbd>Y</kbd>                  |
| Duplicate current line                                            | <kbd>Ctrl</kbd>+<kbd>D</kbd>                  |
| Evaluate input                                                    | <kbd>Enter ⏎</kbd>                            |
| **Editor**                                                        |                                               |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; _same as Input, except for:_ |                                               |
| Scroll up                                                         | <kbd>PageUp</kbd>                             |
| Scroll down                                                       | <kbd>PageDown</kbd>                           |
| Move selection (if in first/last line)                            | <kbd>⇧</kbd>/<kbd>⇩</kbd>                     |
| Move selection                                                    | <kbd>Ctrl</kbd>+<kbd>⇧</kbd>/<kbd>⇩</kbd>     |
| Replace selection with input                                      | <kbd>Enter ⏎</kbd>                            |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; _additionally_               |                                               |
| Delete selected block                                             | <kbd>Ctrl</kbd>+<kbd>Delete</kbd>             |
| Delete selected block (if input is empty)                         | <kbd>Ctrl</kbd>+<kbd>Y</kbd>                  |
| Wipe input                                                        | <kbd>Ctrl</kbd>+<kbd>W</kbd>                  |
| Load selected content to input (discards previous content)        | <kbd>Esc</kbd>                                |
| Insert selected content into input                                | <kbd>Shift</kbd>+<kbd>Esc</kbd>               |
| Scroll to start                                                   | <kbd>Ctrl</kbd>+<kbd>PageUp</kbd>             |
| Scroll to end                                                     | <kbd>Ctrl</kbd>+<kbd>PageDown</kbd>           |
| Scroll up by one line                                             | <kbd>Shift</kbd>+<kbd>PageUp</kbd>            |
| Scroll down by one line                                           | <kbd>Shift</kbd>+<kbd>PageDown</kbd>          |
| Move selection to start                                           | <kbd>Ctrl</kbd>+<kbd>Home</kbd>               |
| Move selecion to end                                              | <kbd>Ctrl</kbd>+<kbd>End</kbd>                |
| Stop editor                                                       | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>S</kbd> |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; _move mode_                  |                                               |
| Switch to moving ("pick up" selection)                            | <kbd>Ctrl</kbd>+<kbd>M</kbd>                  |
| Move selection                                                    | <kbd>⇧</kbd>/<kbd>⇩</kbd>                     |
| Move selection to start                                           | <kbd>Ctrl</kbd>+<kbd>Home</kbd>               |
| Move selecion to end                                              | <kbd>Ctrl</kbd>+<kbd>End</kbd>                |
| Cancel moving                                                     | <kbd>Esc</kbd>                                |
| Move line/block to selection and return to normal mode            | <kbd>Enter ⏎</kbd>                            |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; _search mode_                |                                               |
| Search definitions                                                | <kbd>Ctrl</kbd>+<kbd>F</kbd>                  |
| Exit search                                                       | <kbd>Esc</kbd>                                |
| Jump to selected definition                                       | <kbd>Enter ⏎</kbd>                            |
| Edit required file / return to previous                           | <kbd>Ctrl</kbd>+<kbd>O</kbd>                  |

## Projects

A _project_ is a folder in the application's storage which
contains at least a `main.lua` file. Projects can be loaded and
ran. At any time, pressing <kbd>Ctrl-Shift-Q</kbd> quits and
returns to the console

- `list_projects()`

  List available projects.

- `project(proj)`

  Open project _proj_ or create a new one if it doesn't exist.
  New projects are supplied with example code to demonstrate the
  structure.

- `current_project()`

  Print the currently open project's name (if any).

- `run_project(proj?)` / `run(proj?)`

  Run either _proj_ or the currently open project if no
  arguments are passed.

- `example_projects()`

  Copy the included example projects to the projects folder.

- `close_project()`

  Close currently opened project.

- `edit(file)`

  Open file in editor. If it does not exist yet, a new file will
  be created. See [Editor mode](#editor)

### Files

Once a project is open, file operations are available on it's
contents.

- `list_contents()`

  List files in the project.

- `readfile(file)`

  Open _file_ and display it's contents.

- `writefile(file, content)`

  Write to _file_ the text supplied as the _content_ parameter.
  This can be either a string, or an array of strings.

## Editor

If a project is open, the files inside can be edited or new ones
created. Run the `edit()` command to do so.

![edit](./doc/interface/open_edit.apng)

When a file is opened, the editor is scrolled to the end by
default, and entered input will be appended to the end.

![hello](./doc/interface/hello.apng)

To modify an existing line, navigate there with
<kbd>⇧</kbd>/<kbd>⇩</kbd>. Then load the text by pressing
<kbd>Esc</kbd>, make the desired changes, then send it back with
<kbd>Enter ⏎</kbd>

![capitalized](./doc/interface/hello_cap.apng)

Happy with the modifications now, we can quit by pressing
<kbd>Ctrl-Shift-S</kbd>

![quit](./doc/interface/quit_editor.apng)

#### Moving

Select the block you want to move and press <kbd>Ctrl-M</kbd>.
Move the highlight with <kbd>⇧</kbd>/<kbd>⇩</kbd> and hit
<kbd>Enter ⏎</kbd> when you found it's new home.

![move1](./doc/interface/move_line.apng)
![move2](./doc/interface/move_block.apng)

#### Searching

Definitions can be searched with <kbd>Ctrl-F</kbd>. Pressing
this combination switches to search mode, in which the
definitions are listed, and there's a highlight, which can be
moved as usual. Hitting <kbd>Enter ⏎</kbd> returns to editing,
highlighting the selected definition. To exit search mode
without moving, press <kbd>Esc</kbd>.

![search](./doc/interface/search.apng)


# Usage (playback mode)

`love compy.love play <project>`

* `<project>` is either
  * a `.compy` package (a zipped project)
  * a folder containing a valid project

Paths will be searched in the following order:
* for zips:
  * current directory (or absolute path)
  * compy storage directory
* for folders
  * current directory (or absolute path)
  * compy storage directory
  * projects directory

## Keys

| Command                        | Combination                                 |
| :----------------------------- | :------------------------------------------ |
| Reset project to initial state | <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>R</kbd> |

#

[löve2d]: https://love2d.org
