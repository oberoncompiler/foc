MODULE Dev2LnkChmod;
(* Ivan Denisov, 2016.11 *)
IMPORT Kernel, LinLibc, Files, Log, Dev2LnkBase;

PROCEDURE Chmod*;
VAR name0: Files.Name; name: ARRAY LEN(Files.Name) OF SHORTCHAR; res: INTEGER;
BEGIN
  name0 := Dev2LnkBase.outputName;
  IF Dev2LnkBase.outputType # '' THEN
    Kernel.MakeFileName(name0, Dev2LnkBase.outputType)
  END;
  name := SHORT(name0);
  res := LinLibc.chmod(name, {0, 2, 3, 4, 5, 6, 7, 8}) (* rwxrwxr-x *)
END Chmod;

END  Dev2LnkChmod.
