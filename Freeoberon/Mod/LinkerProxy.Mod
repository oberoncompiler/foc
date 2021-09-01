MODULE FreeoberonLinkerProxy; (* Linux version *)
IMPORT Dev2Linker1, Dev2LnkBase; (*Windows: DevLinker*)

CONST
  os* = 'Linux'; (*Windows: dos*)
  postfix* = ''; (*Windows: exe*)

VAR
  error*: BOOLEAN;

PROCEDURE Link*;
BEGIN
  Dev2Linker1.LinkElfExe; (*Windows: DevLinker.Link*)

  error := Dev2LnkBase.error
END Link;

END FreeoberonLinkerProxy.
