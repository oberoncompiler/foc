MODULE FreeoberonLinkerProxy; (* Windows version *)
IMPORT DevLinker;

CONST
  os* = 'dos';
  postfix* = '.exe';

VAR
  error*: BOOLEAN;

PROCEDURE Link*;
BEGIN
  DevLinker.Link;

  error := DevLinker.error
END Link;

END FreeoberonLinkerProxy.
