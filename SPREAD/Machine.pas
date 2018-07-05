UNIT Machine;
(* Simple stack based interpreter for a spreadsheet - Version 2
   P.D. Terry, Rhodes University, 1995 *)

INTERFACE

  CONST
  (* The following are Opcode mnemonics *)
    Push     = 0;
    Load     = 1;
    Negate   = 2;
    Add      = 3;
    Subtract = 4;
    Multiply = 5;
    Divide   = 6;
    Modulus  = 7;
    Stop     = 8;

  PROCEDURE InitActive;
  (* Clear all code associated with active cell *)

  PROCEDURE EvalActive;
  (* Re-evaluate the active cell *)

  PROCEDURE Refresh;
  (* Recalculate and refresh entire spreadsheet *)

  PROCEDURE Terminate;
  (* Clean up at end of session *)

  PROCEDURE Up;
  (* Move active cell up - stick at top edge *)

  PROCEDURE Down;
  (* Move active cell up - stick at bottom edge *)

  PROCEDURE Left;
  (* Move active cell up - stick at left edge *)

  PROCEDURE Right;
  (* Move active cell up - stick at right edge *)

  PROCEDURE Home;
  (* Move active cell to top left *)

  PROCEDURE MoveTo (Row, Col : INTEGER);
  (* Move active cel to specified Row, Col *)

  PROCEDURE Gen (Op : INTEGER);
  (* Add Op to code associated with active cell *)

  PROCEDURE GenPush (I : INTEGER);
  (* Add (Push I) to code associated with active cell *)

  PROCEDURE GenLoad (I, J : INTEGER);
  (* Add (Load I J) to code associated with active cell *)

IMPLEMENTATION

  USES CRT;

  CONST
  (* The hidden spreadsheet is MaxRows by MaxCols in extent *)
    MaxRows  = 20;
    MaxCols  = 9;

  TYPE
    ROWS    = 1 .. MaxRows;
    COLUMNS = 1 .. MaxCols;

  (* The memory for each cell is an array of integer values, containing
     interpretive code for a reverse polish representation of the
     corresponding formula.  For example,

     The formula    -2 * (4 + 5) / A2
     is coded as    2 Negate 4 5 Plus Multiply Load 1 2 Divide Stop   *)

  CONST
    MaxMem   = 50;
  TYPE
    ADDRESS = 0 .. MaxMem;
    CELLS   = RECORD
                Defined  : BOOLEAN;
                Value    : INTEGER;
                LastCode : INTEGER;
                Code     : ARRAY [ADDRESS] OF INTEGER;
              END;
  VAR
    SpreadSheet : ARRAY [ROWS, COLUMNS] OF CELLS;
    ActiveRow : ROWS;
    ActiveCol : COLUMNS; (* Active cell coordinates *)

  PROCEDURE Evaluate (Row : ROWS; Col : COLUMNS; VAR Okay : BOOLEAN);
  (* This has no error checking for going out of the bounds of code.
     Of course, it should have done *)

    VAR
      Stack : ARRAY [ADDRESS] OF INTEGER;
      PC, Top : ADDRESS;
      I : INTEGER;
    BEGIN

(* +++++++++++++++++++++ start of debugging code +++++++++
   Okay, I'll 'fess up.  For debugging during development I added this so that
   I could make sure the code generated was okay

      GotoXY(1, 16);
      Write(Row:6);
      Write(Col:6);
      GotoXY(1, 17);
      FOR I := 0 TO 10 DO
        Write(SpreadSheet[Row, Col].Code[I]:6);

 +++++++++++++++++++++++ end of debugging code +++++++++++ *)

      Top := 0; Stack[Top] := 0;
      PC := 0; Okay := TRUE;
      WITH SpreadSheet[Row, Col] DO BEGIN
        WHILE (Code[PC] <> Stop) AND Okay DO BEGIN
          CASE Code[PC] OF
              Push :
                BEGIN
                  INC(Top);
                  Stack[Top] := Code[PC+1]; INC(PC);
                END;
              Load :
                BEGIN
                  INC(Top);
                  Stack[Top] := SpreadSheet[Code[PC+1], Code[PC+2]].Value;
                  INC(PC, 2)
                END;
              Negate :
                Stack[Top] := - Stack[Top];
              Add :
                BEGIN
                  DEC(Top); Stack[Top] := Stack[Top] + Stack[Top+1]
                END;
              Subtract :
                BEGIN
                  DEC(Top); Stack[Top] := Stack[Top] - Stack[Top+1]
                END;
              Multiply :
                BEGIN
                  DEC(Top); Stack[Top] := Stack[Top] * Stack[Top+1]
                END;
              Divide :
                BEGIN
                  Okay := Stack[Top] <> 0; DEC(Top);
                  IF Okay
                    THEN Stack[Top] := Stack[Top] DIV Stack[Top+1]
                    ELSE Stack[Top] := MaxInt
                END;
              Modulus :
                BEGIN
                  Okay := Stack[Top] <> 0; DEC(Top);
                  IF Okay
                    THEN Stack[Top] := Stack[Top] MOD Stack[Top+1]
                    ELSE Stack[Top] := 0
                END;
            ELSE Okay := FALSE (* unexpected opcode *)
          END;
          INC(PC)
        END;
        IF Top <> 1 THEN Okay := FALSE (* this should never happen! *);
        Value := Stack[Top]
      END
    END;

  PROCEDURE InitActive;
    VAR
      I : ADDRESS;
    BEGIN
      WITH SpreadSheet[ActiveRow, ActiveCol] DO BEGIN
        LastCode := 0;
        Defined := TRUE;
        (* safety belt feature - make sure there is a halt there *)
        FOR I := 0 TO MaxMem DO Code[I] := Stop
      END
    END;

  PROCEDURE EvalActive;
    VAR
      Done : BOOLEAN;
    BEGIN
      Evaluate(ActiveRow, ActiveCol, Done)
    END;

  PROCEDURE Refresh;
    VAR
      Row  : ROWS;
      Col  : COLUMNS;
      Okay : BOOLEAN;
    BEGIN
      FOR Row := 1 TO MaxRows DO
        FOR Col := 1 TO MaxCols DO
          IF SpreadSheet[Row, Col].Defined THEN BEGIN
            Evaluate(Row, Col, Okay);
            (* we should really react to NOT Okay of course! *)
            GotoXY(10 * (Col - 1) + 1, Row);
            Write(SpreadSheet[Row, Col].Value:10);
          END;
      ReadLn (* just to slow things up *)
    END;

  PROCEDURE Terminate;
    BEGIN
      GotoXY(1, 24)
    END;

  PROCEDURE Up;
    BEGIN
      IF ActiveRow > 1 THEN DEC(ActiveRow)
    END;

  PROCEDURE Down;
    BEGIN
      IF ActiveRow < MaxRows THEN INC(ActiveRow)
    END;

  PROCEDURE Left;
    BEGIN
      IF ActiveCol > 1 THEN DEC(ActiveCol)
    END;

  PROCEDURE Right;
    BEGIN
      IF ActiveCol < MaxCols THEN INC(ActiveCol)
    END;

  PROCEDURE Home;
    BEGIN
      ActiveRow := 1; ActiveCol := 1
    END;

  PROCEDURE MoveTo (Row, Col : INTEGER);
    BEGIN
      ActiveRow := Row; ActiveCol := Col
    END;

  PROCEDURE Gen (Op : INTEGER);
    BEGIN
      WITH SpreadSheet[ActiveRow, ActiveCol] DO
        BEGIN Code[LastCode] := Op; INC(LastCode) END
    END;

  PROCEDURE GenPush (I : INTEGER);
    BEGIN
      Gen(Push); Gen(I)
    END;

  PROCEDURE GenLoad (I, J : INTEGER);
    BEGIN
      Gen(Load); Gen(I); Gen(J)
    END;

  VAR
    I : ROWS;
    J : COLUMNS;

  BEGIN (* overall initialization *)
    ClrScr;
    FOR I := 1 TO MaxRows DO
      FOR J := 1 TO MaxCols DO
        BEGIN
          SpreadSheet[I, J].Defined := FALSE;
          SpreadSheet[I, J].Value := 0;
          SpreadSheet[I, J].LastCode := 0;
        END;
    ActiveRow := 1; ActiveCol := 1;
  END.
