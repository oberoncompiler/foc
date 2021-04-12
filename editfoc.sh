#!/bin/bash
vim -p Freeoberon/Mod/Main.Mod \
  Freeoberon/Mod/LinkerProxy.Mod \
  Freeoberon/Mod/Linker.Mod \
  Freeoberon/Mod/Compiler.Mod \
  Freeoberon/Mod/Errors.Mod \
  Freeoberon/Mod/Scanner.Mod \
  Main.Mod \
  Makefile
