@SET PROG=foc
@SET runc=BlackBox\BlackBoxInterp.exe /USE .

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
