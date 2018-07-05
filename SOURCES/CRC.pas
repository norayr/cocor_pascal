UNIT CRC;

INTERFACE

PROCEDURE WriteDriver;
(* Emits the source code of a generated driver program using the frame file compiler.frame *)

IMPLEMENTATION

USES CRA, CRS, CRTable, FileIO;

CONST
  framefilenameext = '.frame'; framefilename =  'compiler';

VAR
  err : TEXT;  (* output: error message texts *)
  fram : TEXT; (* input:  parser frame parser.frm *)
  com : TEXT;  (* output: generated parser *)

PROCEDURE PutS (s : STRING);
  VAR
    i : INTEGER;
  BEGIN
    FOR i := 1 TO Length(s) DO
      IF s[i] = '$' THEN WriteLn(com) ELSE Write(com, s[i]);
  END;

PROCEDURE WriteDriver;
  VAR
    LeftMargin : INTEGER;
    gn : CRTable.GraphNode;
    sn : CRTable.SymbolNode;
    gramName, fGramName, fn, errName, CompilerFrame : STRING;
    ErrMsg : STRING;

  BEGIN
    CRTable.GetNode(CRTable.root, gn);
    CRTable.GetSym(gn.p1, sn);
    fn := Copy(sn.name, 1, 8);
    CompilerFrame := Concat(CRS.directory, fn, framefilenameext);
    FileIO.Open(fram, CompilerFrame, FALSE);
    IF NOT FileIO.Okay THEN
      BEGIN
        CompilerFrame := Concat(CRS.directory, framefilename, framefilenameext);
        FileIO.Open(fram, CompilerFrame, FALSE);
        IF NOT FileIO.Okay THEN BEGIN
          FileIO.SearchFile(fram, 'CRFRAMES', Concat(framefilename, framefilenameext), FALSE);
          IF NOT FileIO.Okay THEN BEGIN WriteLn('neither "', Concat(CRS.directory, fn, framefilenameext), '" nor "', Concat(framefilename, framefilenameext), '" found - aborted.'); HALT END
        END;
      END;
    LeftMargin := 0;
    gramName := Copy(sn.name, 1, 7);
    fGramName := Concat(CRS.directory, gramName);
    errName := Concat(gramName, '.err');
    FileIO.Open(err, errName, FALSE);
    IF NOT FileIO.Okay THEN
      BEGIN WriteLn('Cannot find ', errName, ' - Aborted.'); HALT END;
    fn := Concat(fGramName, '.pas');
    FileIO.Open(com, fn, TRUE);
    IF NOT FileIO.Okay THEN
      BEGIN WriteLn('Cannot open ', fn, ' - Aborted.'); HALT END;
    CRA.CopyFramePart('-->Grammar', LeftMargin, fram, com);
    PutS(gramName);
    CRA.CopyFramePart('-->Scanner', LeftMargin, fram, com);
    PutS(gramName+'S');
    CRA.CopyFramePart('-->Parser', LeftMargin, fram, com);
    PutS(gramName+'P');
    CRA.CopyFramePart('-->Errors', LeftMargin, fram, com);
    WHILE NOT EOF(err) DO BEGIN
      ReadLn(err, ErrMsg);
      WriteLn(com, ErrMsg);
      Write(com, ' ': LeftMargin);
    END;
    CRA.CopyFramePart('-->Scanner', LeftMargin, fram, com);
    PutS(gramName+'S');
    CRA.CopyFramePart('-->Grammar', LeftMargin, fram, com);
    PutS(gramName + ' *)$');
    Close(com); Close(err); Close(fram);
  END;

END.
