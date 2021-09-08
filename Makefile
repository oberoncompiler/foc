PROG=foc

all: $(PROG) lib

Code/Args.ocf: System/Mod/Args.Mod
	echo "ConsCompiler.Compile('System/Mod', 'Args.Mod')" | ./runc

Host/Code/Args.ocf: Host/Mod/Args.Mod Code/Args.ocf
	echo "ConsCompiler.Compile('Host/Mod', 'Args.Mod')" | ./runc

Freeoberon/Code/Platform.ocf: Freeoberon/Mod/Platform.Mod Code/Args.ocf
	echo "ConsCompiler.Compile('Freeoberon/Mod', 'Platform.Mod')" | ./runc

Freeoberon/Code/Config.ocf: Freeoberon/Mod/Config.Mod
	echo "ConsCompiler.Compile('Freeoberon/Mod', 'Config.Mod')" | ./runc
	#cp _Build/FreeoberonConfig.ocf BlackBox/Freeoberon/Code/Config.ocf
	#cp _Build/FreeoberonConfig.osf BlackBox/Freeoberon/Sym/Config.osf

Dev/Code/CPM.ocf: Dev/Mod/CPM.Mod Freeoberon/Code/Config.ocf
	echo "ConsCompiler.Compile('Dev/Mod', 'CPM.Mod')" | ./runc

Dev2/Code/LnkBase.ocf: Dev2/Mod/LnkBase.Mod Freeoberon/Code/Config.ocf
	echo "ConsCompiler.Compile('Dev2/Mod', 'LnkBase.Mod')" | ./runc
	#cp _Build/Dev2LnkBase.ocf BlackBox/Dev2/Code/LnkBase.ocf
	#cp _Build/Dev2LnkBase.osf BlackBox/Dev2/Sym/LnkBase.osf

Dev2/Code/LnkChmod.ocf: Dev2/Mod/LnkChmod.Mod Dev2/Code/LnkBase.ocf
	echo "ConsCompiler.Compile('Dev2/Mod', 'LnkChmod.Mod')" | ./runc

Host/Code/Files.ocf: Host/Mod/Files.Mod
	echo "ConsCompiler.Compile('Host/Mod', 'Files.Mod')" | ./runc

Freeoberon/Code/Scanner.ocf: Freeoberon/Mod/Scanner.Mod Host/Code/Files.ocf
	echo "ConsCompiler.Compile('Freeoberon/Mod', 'Scanner.Mod')" | ./runc

Freeoberon/Code/Errors.ocf: Freeoberon/Mod/Errors.Mod
	echo "ConsCompiler.Compile('Freeoberon/Mod', 'Errors.Mod')" | ./runc

Freeoberon/Code/Compiler.ocf: Freeoberon/Mod/Compiler.Mod Freeoberon/Code/Errors.ocf Host/Code/Files.ocf Dev/Code/CPM.ocf
	echo "ConsCompiler.Compile('Freeoberon/Mod', 'Compiler.Mod')" | ./runc

Freeoberon/Code/LinkerProxy.ocf: Freeoberon/Mod/LinkerProxy.Mod Dev/Code/CPM.ocf
	echo "ConsCompiler.Compile('Freeoberon/Mod', 'LinkerProxy.Mod')" | ./runc

Freeoberon/Code/Linker.ocf: Freeoberon/Mod/Linker.Mod Freeoberon/Code/LinkerProxy.ocf Dev2/Code/LnkBase.ocf
	echo "ConsCompiler.Compile('Freeoberon/Mod', 'Linker.Mod')" | ./runc

Freeoberon/Code/Main.ocf: Freeoberon/Mod/Main.Mod Freeoberon/Code/Config.ocf Freeoberon/Code/Platform.ocf Freeoberon/Code/Scanner.ocf Freeoberon/Code/Compiler.ocf Freeoberon/Code/Linker.ocf Host/Code/Args.ocf
	echo "ConsCompiler.Compile('Freeoberon/Mod', 'Main.Mod')" | ./runc

$(PROG): Freeoberon/Code/Main.ocf Host/Code/Files.ocf Dev2/Code/LnkChmod.ocf
	./link

.PHONY: clean run

clean:
	rm -rf \
		_Build \
		System/Code \
		System/Sym \
		Host/Code \
		Host/Sym \
		Dev/Code \
		Dev/Sym \
		Dev2/Code \
		Dev2/Sym \
		Code \
		Sym \
		$(PROG)

lib:
	cd Lib && \
		../foc AllLibs && \
		rm AllLibs _Build/AllLibs.*

run: $(PROG)
	@echo =======================================
	@./$(PROG) Main
