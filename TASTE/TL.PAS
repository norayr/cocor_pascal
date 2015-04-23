UNIT TL;

INTERFACE

CONST
  vars = 0;
  procs = 1;
  scopes = 2;

  undef = 0;
  int   = 1;
  bool  = 2;  (*types*)

TYPE
  TObject = ^Objectnode;
  Objectnode = RECORD
    name: STRING[16];                (*name of the Object*)
    typ: INTEGER;                    (*type of the object (undef for procs)*)
    next: TObject;                   (*to next object in same scope*)
    CASE kind: INTEGER OF
      vars, procs: (
        adr:     INTEGER;            (*address in memory or start of proc*)
        level:   INTEGER; );         (*nesting level of declaration*)
     scopes: (
        locals:  TObject;            (*to locally declared objects*)
        nextAdr: INTEGER; );         (*next free address in this scope*)
    END;

VAR
  undefObj: TObject;   (*object node for erroneous symbols*)
  curLevel: INTEGER;  (*nesting level of current scope*)

PROCEDURE EnterScope;

PROCEDURE LeaveScope;

FUNCTION DataSpace: INTEGER;

FUNCTION NewObj (name: STRING; kind: INTEGER): TObject;

FUNCTION Obj (name: STRING): TObject;

IMPLEMENTATION

USES TasteP;

VAR
  topScope: TObject;    (*topmost procedure scope*)

PROCEDURE EnterScope;
  VAR
    scope: TObject;
  BEGIN
    NEW(scope);
    WITH scope^ DO BEGIN
      name := ''; typ := undef; kind := scopes; locals := NIL; nextAdr := 3
    END;
    scope^.next := topScope; topScope := scope; INC(curLevel);
  END;

PROCEDURE LeaveScope;
  BEGIN
    topScope := topScope^.next; DEC(curLevel)
  END;

FUNCTION DataSpace: INTEGER;
  BEGIN
    DataSpace := topScope^.nextAdr - 3
  END;

FUNCTION NewObj (name: STRING; kind: INTEGER): TObject;
  VAR
    obj, p: TObject;
  BEGIN
    NEW(obj);
    obj^.name := name; obj^.typ := undef; obj^.kind := kind;
    obj^.level := curLevel;
    p := topScope^.locals;
    WHILE p <> NIL DO BEGIN
      IF p^.name = name THEN TasteP.SemError(117);
      p := p^.next
    END;
    obj^.next := topScope^.locals; topScope^.locals := obj;
    IF kind = vars THEN BEGIN
      obj^.adr := topScope^.nextAdr; INC(topScope^.nextAdr)
    END;
    NewObj := obj
  END;

FUNCTION Obj(name: STRING): TObject;
  VAR
    aobj, scope: TObject;
  BEGIN
    scope := topScope;
    WHILE scope <> NIL DO BEGIN
      aobj := scope^.locals;
      WHILE aobj <> NIL DO BEGIN
        IF aobj^.name = name THEN BEGIN Obj := aobj; exit; END;
        aobj := aobj^.next
      END;
      scope := scope^.next
    END;
    TasteP.SemError(118);
    Obj := undefObj
  END;

BEGIN
  topScope := NIL; curLevel := 0;
  NEW(undefObj);
  WITH undefObj^ DO BEGIN
    name := ''; typ := undef; kind := vars;
    adr := 0; level := 0; next := NIL
  END
END.
