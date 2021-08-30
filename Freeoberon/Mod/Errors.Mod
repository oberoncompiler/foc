MODULE FreeoberonErrors;
IMPORT Out := Log;

TYPE
  Error* = POINTER TO ErrorDesc;
  ErrorDesc* = RECORD
    fname-: ARRAY 64 OF CHAR;
    row-, col-, pos-: INTEGER;
    errno-: INTEGER;
    errmsg: ARRAY 128 OF CHAR;
    line: ARRAY 2000 OF CHAR;
    next-: Error
  END;

  List* = RECORD
    first-, last-: Error
  END;

PROCEDURE OutInt(n: INTEGER);
VAR s: ARRAY 30 OF CHAR;
  c: CHAR;
  i, L, R: INTEGER;
  minus: BOOLEAN;
BEGIN i := 0;
  IF n < 0 THEN minus := TRUE; n := -n ELSE minus := FALSE END;
  REPEAT
    s[i] := CHR(ORD('0') + n MOD 10);
    INC(i);
    n := n DIV 10
  UNTIL n = 0;
  IF minus THEN s[i] := '-'; INC(i) END;
  s[i] := 0X;

  L := 0; R := i - 1;
  WHILE L < R DO
    c := s[L]; s[L] := s[R]; s[R] := c;
    INC(L); DEC(R)
  END;
  Out.String(s)
END OutInt;

PROCEDURE NewList*(OUT list: List);
BEGIN
  list.first := NIL; list.last := NIL
END NewList;

PROCEDURE Add*(VAR list: List; IN fname: ARRAY OF CHAR;
  row, col, pos, errno: INTEGER; IN errmsg: ARRAY OF CHAR;
  IN line: ARRAY OF CHAR);
VAR p: Error;
BEGIN
  NEW(p);
  p.fname := fname$;
  p.row := row; p.col := col; p.pos := pos; p.errno := errno;
  p.errmsg := errmsg$;
  p.line := line$;

  p.next := NIL;
  IF list.last = NIL THEN list.first := p; list.last := p
  ELSE list.last.next := p; list.last := p
  END
END Add;

PROCEDURE ShowList*(IN list: List);
VAR p: Error;
BEGIN
  p := list.first;
  WHILE p # NIL DO
    Out.String(p.fname);
    Out.String(' '); OutInt(p.row);
    Out.String(':'); OutInt(p.col);
    Out.String(' ('); OutInt(p.pos);
    Out.String(') Error #'); OutInt(p.errno);
    Out.String(': '); Out.String(p.errmsg); Out.Ln;
    Out.String('> '); Out.String(p.line); Out.Ln;
    p := p.next
  END
END ShowList;

END FreeoberonErrors.
