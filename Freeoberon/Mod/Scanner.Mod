MODULE FreeoberonScanner;
IMPORT Files, Out := Log;

CONST
  null*    = 0;
  bad*     = 1;
  lbrak*   = 2;
  rbrak*   = 3;
  comma*   = 4;
  semicol* = 5;
  becomes* = 6;
  module*  = 7;
  import*  = 8;
  ident*   = 9;
  string*  = 10;
  eot*     = 11;

VAR
  r: Files.Reader;
  ch: CHAR;
  id-: ARRAY 50 OF CHAR;
  idlen-: INTEGER;

PROCEDURE ReadCh;
VAR b: BYTE;
BEGIN
  IF ~r.eof THEN
    r.ReadByte(b);
    ch := CHR(b)
  ELSE ch := 0X
  END
END ReadCh;

PROCEDURE Comment;
VAR end: BOOLEAN;
BEGIN
  end := FALSE;
  ReadCh; (* * *)
  REPEAT
    WHILE ~r.eof & (ch # '*') & (ch # '(') DO ReadCh END;
    IF ch = '*' THEN
      ReadCh;
      IF ch = ')' THEN
        ReadCh;
        end := TRUE
      END
    ELSIF ch = '(' THEN     (* as ((* www *) dd *)
      ReadCh;
      IF ch = '*' THEN Comment END
    END
  UNTIL r.eof OR end
END Comment;

PROCEDURE Get*(VAR sym: INTEGER);
BEGIN
  REPEAT
    WHILE ~r.eof & (ch <= ' ') DO ReadCh END;
    IF r.eof THEN sym := eot
    ELSE
      CASE ch OF
        '(': ReadCh;
        IF ch = '*' THEN Comment; sym := null
        ELSE sym := bad; ReadCh
        END
      | '[': sym := lbrak; ReadCh
      | ']': sym := rbrak; ReadCh
      (*| "'": sym := string; ... ReadCh*)
      (*| '"': sym := string; ... ReadCh*)
      | ',': sym := comma; ReadCh
      | ';': sym := semicol; ReadCh
      | ':': ReadCh;
        IF ch = '=' THEN sym := becomes; ReadCh
        ELSE sym := bad; ReadCh
        END
      | 'a'..'z', 'A'..'Z':
        idlen := 0;
        REPEAT
          IF idlen < LEN(id) - 1 THEN
            id[idlen] := ch;
            INC(idlen)
          END;
          ReadCh
        UNTIL ~(('a' <= ch) & (ch <= 'z') OR
                ('A' <= ch) & (ch <= 'Z') OR
                ('0' <= ch) & (ch <= '9') OR (ch = '_'));
        id[idlen] := 0X;
        (*Out.String('id="'); Out.String(id); Out.String('" ');*)
        IF id = 'MODULE' THEN sym := module
        ELSIF id = 'IMPORT' THEN sym := import
        ELSE sym := ident
        END
      ELSE sym := bad; ReadCh
      END
    END
  UNTIL sym # null;
  (*Out.String('Get: sym ='); Out.Int(sym); Out.Int(r.Pos()); Out.Ln*)
END Get;

PROCEDURE Init*(R: Files.Reader);
BEGIN
  r := R;
  ReadCh
END Init;

END FreeoberonScanner.
