@SET PROG=foc
@SET runc=BlackBox\BlackBoxInterp.exe /USE .

@IF NOT EXIST __WIN_BlackBox GOTO ENDIF1
	@MOVE BlackBox __LIN_BlackBox
	@MOVE __WIN_BlackBox BlackBox
:ENDIF1

@IF NOT EXIST Host\Mod\__WIN_Args.Mod GOTO ENDIF2
	@MOVE Host\Mod\Args.Mod Host\Mod\__LIN_Args.Mod
	@MOVE Host\Mod\__WIN_Args.Mod Host\Mod\Args.Mod
:ENDIF2

@IF NOT EXIST Host\Mod\__WIN_Files.Mod GOTO ENDIF3
	@MOVE Host\Mod\Files.Mod Host\Mod\__LIN_Files.Mod
	@MOVE Host\Mod\__WIN_Files.Mod Host\Mod\Files.Mod
:ENDIF3

@IF NOT EXIST Freeoberon\Mod\__WIN_LinkerProxy.Mod GOTO ENDIF4
	@MOVE Freeoberon\Mod\LinkerProxy.Mod Freeoberon\Mod\__LIN_LinkerProxy.Mod
	@MOVE Freeoberon\Mod\__WIN_LinkerProxy.Mod Freeoberon\Mod\LinkerProxy.Mod
:ENDIF4

@echo ConsCompiler.Compile('Host\Mod', 'Files.Mod') | %runc%
@echo ConsCompiler.Compile('System\Mod', 'Args.Mod') | %runc%
@echo ConsCompiler.Compile('Host\Mod', 'Args.Mod') | %runc%
@echo ConsCompiler.Compile('Freeoberon\Mod', 'Scanner.Mod') | %runc%
@echo ConsCompiler.Compile('Freeoberon\Mod', 'Errors.Mod') | %runc%
@echo ConsCompiler.Compile('Freeoberon\Mod', 'Compiler.Mod') | %runc%
@echo ConsCompiler.Compile('Freeoberon\Mod', 'LinkerProxy.Mod') | %runc%
@echo ConsCompiler.Compile('Freeoberon\Mod', 'Linker.Mod') | %runc%
@echo ConsCompiler.Compile('Freeoberon\Mod', 'Main.Mod') | %runc%
@echo DevLinker.Link dos foc.exe := Kernel$+ Files HostEnv HostFiles Math Strings Dates Unicode Meta Log Dialog Services Fonts Ports Utf Stores Converters Sequencers Models Printers Views Controllers Properties Printing Mechanisms Containers Documents Windows Console StdInterpreter HostConsole HostRegistry HostFonts HostWindows HostDates HostDialog StdDialog HostLang TextModels TextRulers TextSetters TextViews TextControllers TextMappers StdApi StdCmds StdLinks HostTextConv Args HostArgs StdLog ConsLog StdCFrames Controls DevCommanders DevLinker DevMarkers DevCPM DevCPT DevCPB DevCPS DevCPP DevCPE DevCPH DevCPL486 DevCPC486 DevCPV486 DevSelectors DevCompiler FreeoberonScanner FreeoberonLinkerProxy FreeoberonLinker FreeoberonErrors FreeoberonCompiler FreeoberonMain | %runc%
