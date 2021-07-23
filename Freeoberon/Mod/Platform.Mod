MODULE FreeoberonPlatform;

IMPORT Args;

PROCEDURE GetAppDir*(OUT dir: ARRAY OF CHAR);
BEGIN
  dir := './'
END GetAppDir;

END FreeoberonPlatform.
