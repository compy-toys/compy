# Introduction to Compy

Compy is a 7'' portable educational computer with an interactive development 
environment for the [love2d](https://love2d.org) framework. It runs on top of 
Android operating system and uses the Lua programming language for the command 
line, scripting, configuration and programming. The primary interface is the 
command console, with the standard input displayed at the bottom of the screen, 
with real-time syntax highlingting (when appropriate). The standard output is 
displayed on a terminal occupying the rest of the screen, which also doubles as 
a graphical canvas. Thus, commands with both text-based or graphical output can 
be entered. Below are some invariant principles of operations:

* Pointing devices (such as mice, touch pad or touch screen) might be used, but 
  are not necessary for the successful operation of Compy.
* Apart from syntax highlighting, anything entered in the console 
  input will only take effect upon pressing the **Enter** key.
* If the input is syntactically invalid at the time of pressing **Enter**, the
  user can continue editing, correcting the mistake.
* Users cannot render compy unusable from the command line. Compy can always 
  be restored to its initial state by inserting a clean _SD card_ or formatting
  the currently inserted one. Example projects are written onto the SD card by
  entering `example_projects()` on the command line.

## Persistence

All data persisted by the user is saved on the included _SD card_. It is 
organized into named _projects_, with no file system hieararchy. Technically, 
each project is a directory under `Documents/compy/projects/` on the SD card. 
Inside these directories, there is no further directory structure.

Projects can be selected or, in the absence of one, created by entering 
`project("...")` in the console, with the project's name between the double 
quotes. Running the project means executing a file called "`main.lua`" in its 
directory. It can be done by entering `run()` in the console for the currently 
selected project or `run("...")` for a different project, with the name of the 
project between the double quotes.

Text files, including Lua sources can be edited using the built-in text editor 
that can be started by entering `edit("...")` in the console, with the name of 
the file between the quotes. In its absence, `main.lua` will be edited.

No changes to the edited file will occur unless the user presses **Enter** _and_ 
the text in the edit area at the bottom of the screen is syntactically correct. 
Pressing **Enter** takes immediate effect on the SD card, there is no need to 
"save" the edited file separately.

If there is no highlighted section in the edited file, the text inputed in the 
console will be appended to the end of the file. If there is a bright white 
highlight, the entered text is inserted before it. If there is a bright yellow 
highlight, the entered text replaces it.

For more information, please see the documentation of the [editor](EDITOR.md) 
and the [console](../README.md).
