UNIT CrossRef;
(* Create cross reference list of identifiers *)

INTERFACE

  CONST
    NameLength = 24;
  TYPE
    TREES  = ^NODES;
    TABLES = TREES;
    QUEUES = ^REFS;
    NODES = RECORD
              Text : STRING[NameLength];
              LeftTree,
              RightTree : TABLES;
              DefinedBy : WORD;
              Okay      : BOOLEAN;
              RefList   : QUEUES;
            END;
    REFS = RECORD
             Number : WORD;
             Next : QUEUES;
           END;

  VAR
    Table : TABLES;

  PROCEDURE Create (VAR Table : TABLES);
  (* Initialise a new (empty) Table *)

  PROCEDURE Add (VAR Table : TABLES; Name : STRING;
                 Reference : WORD; Defined : BOOLEAN);
  (* Add Name to Table with given Reference, specifying whether this is a
     Defining (as opposed to an applied occurrence) *)

  PROCEDURE List (VAR output : TEXT; Table : TABLES);
  (* List out cross reference Table on output device *)


IMPLEMENTATION

  PROCEDURE Create (VAR Table : TABLES);
    BEGIN
      Table := NIL;
    END;

  PROCEDURE Add (VAR Table : TABLES; Name : STRING;
                 Reference : WORD; Defined : BOOLEAN);

    PROCEDURE AddToTree (VAR Root : TABLES);

      PROCEDURE NewReference (Leaf : TABLES);
        VAR
          Latest : QUEUES;
        BEGIN
          WITH Leaf^ DO BEGIN
            NEW(Latest);
            Latest^.Number := Reference;
            IF RefList = NIL
              THEN
                Latest^.Next := Latest
              ELSE
                BEGIN Latest^.Next := RefList^.Next; RefList^.Next := Latest END;
            RefList := Latest
          END
        END;

      BEGIN
        IF Root = NIL
          THEN BEGIN (*at a leaf - Name must now be inserted*)
            NEW(Root);
            WITH Root^ DO BEGIN
              Text := Name;
              LeftTree := NIL; RightTree := NIL;
              Okay := FALSE; RefList := NIL;
              CASE Defined OF
                TRUE : BEGIN
                  DefinedBy := Reference; Okay := TRUE END;
                FALSE : BEGIN
                  DefinedBy := 0; NewReference(Root); Okay := FALSE END;
              END
            END;
          END ELSE IF Name > Root^.Text
            THEN AddToTree(Root^.RightTree)
          ELSE IF  Name < Root^.Text
            THEN AddToTree(Root^.LeftTree)
          ELSE BEGIN
            WITH Root^ DO BEGIN
                CASE Defined OF
                  TRUE :
                    IF DefinedBy = 0
                      THEN BEGIN DefinedBy := Reference; Okay := TRUE; END
                      ELSE Okay := FALSE; (*redefined*)
                 FALSE :
                    IF (RefList = NIL) OR (Reference <> RefList^.Number) THEN
                      NewReference(Root);
                END
              END
        END
      END;

    BEGIN
      AddToTree(Table)
    END;

  PROCEDURE List (VAR output : TEXT; Table : TABLES);

    PROCEDURE OneEntry (ThisNode : TABLES);
      VAR
        First, Current : QUEUES;
        I, J, L : WORD;
      BEGIN
        WITH ThisNode^ DO BEGIN
          I := 0;
          Write(output, Text);
          L := Length(Text);
          WHILE L <= 16 DO BEGIN Write(output, ' '); INC(L) END;
          IF NOT Okay
            THEN Write(output, '?')
            ELSE Write(output, ' ');
          Write(output, DefinedBy:4);
          Write(output, ' - ');
          IF RefList <> NIL THEN BEGIN
            First := RefList^.Next; Current := First;
            REPEAT
              Write(output, Current^.Number:4);
              Current := Current^.Next;
              INC(I);
              IF I MOD 12 = 0 THEN BEGIN
                WriteLn(output);
                FOR J := 1 TO 20 DO Write(output, ' ');
              END;
            UNTIL Current = First; (*again*)
          END;
          WriteLn(output);
        END
      END;

    BEGIN
      IF Table <> NIL THEN
        WITH Table^ DO BEGIN
          List(output, LeftTree);
          OneEntry(Table);
          List(output, RightTree)
        END
    END;

END.
