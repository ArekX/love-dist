Compiles everything in a LÖVE game folder and creates a .love file, or embeds it directly into application. It uses Lua Compiler to compile code in order to make it more safer and a bit faster.

You can use following options:
  * -e, -embed - embeds .love file directly in LÖVE game engine.
  * -c, -compile - compiles all .lua files to bytecode using luac compiler.
  * -d, -dist - creates a folder and copies all necessary files needed for distribution.

If you already have created a .love file then you can embed it by typing:
`lovedist.exe file.love -e`

### Usage ###
lovedist.exe input\_folder output\_name [-e][-d][-c]

Extract zipped files in the same folder as LÖVE game engine in order to use it.

## Current Version ##
Version: 1.1.3