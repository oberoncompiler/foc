MODULE D;
IMPORT O := Log;

PROCEDURE SayHello*(name: ARRAY OF CHAR);
BEGIN
  O.String('    ~~~~========~~~~'); O.Ln;
  O.String('     Привет, '); O.String(name);
  O.String('!'); O.Ln;
  O.String('    ~~~~========~~~~'); O.Ln
END SayHello;

END D.
