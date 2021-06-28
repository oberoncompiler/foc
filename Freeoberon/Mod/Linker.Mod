MODULE FreeoberonLinker;
IMPORT TextModels, DevCommanders, Dialog, Proxy := FreeoberonLinkerProxy,
  Out := Log;

CONST postfix* = Proxy.postfix;
  debug = FALSE;

PROCEDURE Write(w: TextModels.Writer; s: ARRAY OF CHAR);
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE s[i] # 0X DO
    w.WriteChar(s[i]);
    IF debug THEN Out.Char(s[i]) END;
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
  Write(w, ' := Kernel$+ Files HostEnv Log HostFiles Math Strings Dates Unicode Meta Dialog Services Fonts Ports Utf Stores Converters Sequencers Models Printers Views Controllers Properties Printing Mechanisms Containers Documents Windows Console StdInterpreter HostConsole HostRegistry HostFonts HostWindows HostDates HostDialog StdDialog HostLang TextModels TextRulers TextSetters TextViews TextControllers TextMappers StdApi StdCmds StdLinks HostTextConv StdLog ConsLog StdCFrames Controls DevCommanders FreeoberonConfig DevLinker DevMarkers DevCPM DevCPT DevCPB DevCPS DevCPP DevCPE DevCPH DevCPL486 DevCPC486 DevCPV486 DevSelectors DevCompiler ');
  Write(w, moduleList$);
  IF debug THEN Out.Ln END;
  RETURN DoLink(m)
END Link;

END FreeoberonLinker.
