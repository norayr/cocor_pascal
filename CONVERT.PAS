PROGRAM Convert;
(* Convert textfiles from one operating system form to another
   P.D. Terry, Rhodes University, 1995 *)

CONST
  CR = #13;
  LF = #10;
TYPE
  MODES = (dos2unix, dos2mac, mac2dos, mac2unix, unix2dos, unix2mac) ;
VAR
  Old, New, ChStr : STRING;
  input, output : TEXT;
  ch : CHAR;
  Mode : MODES;
BEGIN
  IF ParamCount < 2 THEN
    BEGIN
      WriteLn('Usage : CONVERT OldFile NewFile [n]');
      WriteLn('n = 1) dos2unix 2) dos2mac 3) mac2dos 4) mac2unix 5) unix2dos 6) unix2mac ');
      HALT
    END;
  Old := ParamStr(1);
  New := ParamStr(2);
  Assign(input, Old); {$I-} Reset(input); {$I+}
  IF IOResult <> 0 THEN BEGIN WriteLn('File <', Old, '> not found'); HALT END;
  Assign(output, New); {$I-} Rewrite(output); {$I+}
  IF IOResult <> 0 THEN BEGIN WriteLn('File <', New, '> not opened'); HALT END;
  ChStr := ParamStr(3);
  IF Length(ChStr) > 0 THEN ch := ChStr[1] ELSE ch := '0';
  IF (ch < '1') OR (ch > '6') THEN
    BEGIN
      WriteLn('1) dos2unix 2) dos2mac 3) mac2dos 4) mac2unix 5) unix2dos 6) unix2mac ? ');
      REPEAT
        Read(ch)
      UNTIL (ch >= '1') AND (ch <= '6');
    END;
  Mode := MODES(ORD(ch) - 49);
  REPEAT
    Read(input, ch);
    IF NOT EOF(input)
      THEN
        CASE ch OF
          CR, LF :
            BEGIN
              IF (Mode < mac2dos) AND (ch = CR) THEN Read(input, ch);
              CASE Mode OF
                dos2unix, mac2unix : Write(output, LF);
                dos2mac, unix2mac :  Write(output, CR);
                ELSE Write(output, CR, LF);
              END;
            END;
          ELSE Write(output, ch)
        END
      ELSE
        CASE Mode OF
          mac2unix : Write(output, LF);
          unix2mac : Write(output, CR);
          mac2dos, unix2dos : Write(output, CR, LF);
          ELSE
        END;
  UNTIL EOF(input);
  Close(input);
  Close(output)
END.
