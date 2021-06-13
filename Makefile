PROG=foc

all: $(PROG)

Host/Code/Files.ocf: Host/Mod/Files.Mod
	echo "ConsCompiler.Compile('Host/Mod', 'Files.Mod')" | ./runc

Dev/Code/CPM.ocf: Dev/Mod/CPM.Mod
	echo "ConsCompiler.Compile('Dev/Mod', 'CPM.Mod')" | ./runc

Host/Code/Args.ocf: Host/Mod/Args.Mod System/Mod/Args.Mod
	echo "ConsCompiler.Compile('System/Mod', 'Args.Mod')" | ./runc
	echo "ConsCompiler.Compile('Host/Mod', 'Args.Mod')" | ./runc

Freeoberon/Code/Scanner.ocf: Freeoberon/Mod/Scanner.Mod Host/Code/Files.ocf
	echo "ConsCompiler.Compile('Freeoberon/Mod', 'Scanner.Mod')" | ./runc

Freeoberon/Code/Errors.ocf: Freeoberon/Mod/Errors.Mod
	echo "ConsCompiler.Compile('Freeoberon/Mod', 'Errors.Mod')" | ./runc

Freeoberon/Code/Compiler.ocf: Freeoberon/Mod/Compiler.Mod Freeoberon/Code/Errors.ocf Host/Code/Files.ocf Dev/Code/CPM.ocf
	echo "ConsCompiler.Compile('Freeoberon/Mod', 'Compiler.Mod')" | ./runc

Dev2/Code/LnkChmod.ocf: Dev2/Mod/LnkChmod.Mod
	echo "ConsCompiler.Compile('Dev2/Mod', 'LnkChmod.Mod')" | ./runc

Freeoberon/Code/LinkerProxy.ocf: Freeoberon/Mod/LinkerProxy.Mod Dev/Code/CPM.ocf
	echo "ConsCompiler.Compile('Freeoberon/Mod', 'LinkerProxy.Mod')" | ./runc

Freeoberon/Code/Linker.ocf: Freeoberon/Mod/Linker.Mod Freeoberon/Code/LinkerProxy.ocf
	echo "ConsCompiler.Compile('Freeoberon/Mod', 'Linker.Mod')" | ./runc

Freeoberon/Code/Main.ocf: Freeoberon/Mod/Main.Mod Freeoberon/Code/Scanner.ocf Freeoberon/Code/Compiler.ocf Freeoberon/Code/Linker.ocf Host/Code/Args.ocf
	echo "ConsCompiler.Compile('Freeoberon/Mod', 'Main.Mod')" | ./runc

$(PROG): Freeoberon/Code/Main.ocf Freeoberon/Code/Scanner.ocf Freeoberon/Code/Errors.ocf Freeoberon/Code/Compiler.ocf Freeoberon/Code/Linker.ocf Host/Code/Args.ocf Host/Code/Files.ocf Dev2/Code/LnkChmod.ocf
	./link

.PHONY: clean run

clean:
	rm -rf Freeoberon/Code \
		Freeoberon/Sym \
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

run: $(PROG)
	@echo =======================================
	@./$(PROG) Main
