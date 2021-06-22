MODULE FreeoberonLinker;
IMPORT TextModels, DevCommanders, Dialog, Proxy := FreeoberonLinkerProxy;

CONST postfix* = Proxy.postfix;

PROCEDURE Write(w: TextModels.Writer; s: ARRAY OF CHAR);
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE s[i] # 0X DO
    w.WriteChar(s[i]);
    INC(i)
  END
END Write;

PROCEDURE DoLink(m: TextModels.Model): BOOLEAN;
VAR par: DevCommanders.Par;
  res: INTEGER;
BEGIN
  NEW(par);
  par.text := m;
  par.beg := 0;
  par.end := m.Length();
  DevCommanders.par := par;
  Proxy.Link;
  DevCommanders.par := NIL;
  RETURN ~Proxy.error
END DoLink;

PROCEDURE Link*(outFile: ARRAY OF CHAR; moduleList: ARRAY OF CHAR): BOOLEAN;
VAR m: TextModels.Model;
  w: TextModels.Writer;
  i, j: INTEGER;
BEGIN
  m := TextModels.dir.New();
  w := m.NewWriter(NIL);
  Write(w, Proxy.os); Write(w, ' ');
  Write(w, outFile$);
  Write(w, ' := Kernel$+ Files HostEnv HostFiles Math Strings Dates Unicode Meta Log Dialog Services Fonts Ports Utf Stores Converters Sequencers Models Printers Views Controllers Properties Printing Mechanisms Containers Documents Windows Console StdInterpreter HostConsole HostRegistry HostFonts HostWindows HostDates HostDialog StdDialog HostLang TextModels TextRulers TextSetters TextViews TextControllers TextMappers StdApi StdCmds StdLinks HostTextConv Args HostArgs StdLog ConsLog StdCFrames Controls DevCommanders DevLinker DevMarkers FreeoberonConfig DevCPM DevCPT DevCPB DevCPS DevCPP DevCPE DevCPH DevCPL486 DevCPC486 DevCPV486 DevSelectors DevCompiler ');
  Write(w, moduleList$);
  RETURN DoLink(m)
END Link;

END FreeoberonLinker.
