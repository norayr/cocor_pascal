UNIT CRA;
(* CRA     Automaton and Scanner Generation
   ===     ================================

  (1) ConvertToStates translates a top-down graph into a NFA.
      MatchDFA tries to match literal strings against the DFA
  (2) MakeDeterministic converts the NFA into a DFA
  (3) WriteScanner generates the scanner source file

  ----------------------------------------------------------------*)

INTERFACE

CONST
  MaxSourceLineLength = 78;

TYPE
  PutSProc = PROCEDURE (S : STRING);

PROCEDURE CopyFramePart (stopStr: STRING; VAR leftMarg: INTEGER;
                         VAR framIn, framOut : TEXT);
(* "stopStr" must not contain "FileIO.EOL".
   "leftMarg" is in/out-parameter  --  it has to be set once by the
   calling program.    *)

PROCEDURE ImportSymConsts (leader: STRING; putS: PutSProc);
(* Generates the USES references for the eventually existing named constants. *)

PROCEDURE ConvertToStates (gp0, sp: INTEGER);
(* Converts top-down graph with root gp into a subautomaton that
   recognizes token sp *)

PROCEDURE MatchDFA (str: STRING; sp : INTEGER; VAR matchedSp: INTEGER);
(* Returns TRUE, if string str can be recognized by the current DFA.
   matchedSp is the token as that s can be recognized. *)

PROCEDURE MakeDeterministic (VAR correct: BOOLEAN);
(* Converts the NFA into a DFA. correct indicates if an error occurred. *)

PROCEDURE NewComment (start, stop: INTEGER; nested: BOOLEAN);
(* Defines a new comment for the scanner. The comment brackets are
   represented by the mini top-down graphs with the roots from and to. *)

PROCEDURE WriteScanner (VAR ok : BOOLEAN);
(* Emits the source code of the generated scanner using the frame file
   scanner.frm *)

PROCEDURE PrintStates;
(* List the automaton for tracing *)

IMPLEMENTATION

USES CRS, CRTable, FileIO, Sets;

CONST
  maxStates = 500;
  cr = #13;
TYPE
  Action = ^ ActionNode;
  Target = ^ TargetNode;
  State = 
    RECORD                     (* state of finite automaton *)
      firstAction : Action;    (* to first action of this state *)
      endOf : INTEGER;         (* nr. of recognized token if state is final *)
      ctx : BOOLEAN;           (* TRUE: state reached by contextTrans *)
    END;
  ActionNode = 
    RECORD                     (* action of finite automaton *)
      typ : INTEGER;           (* type of action symbol: char, class *)
      sym : INTEGER;           (* action symbol *)
      tc : INTEGER;            (* transition code: normTrans, contextTrans *)
      target : Target;         (* states after transition with input symbol *)
      next : Action;
    END;
  TargetNode = 
    RECORD                     (* state after transition with input symbol *)
      theState : INTEGER;      (* target state *)
      next : Target;
    END;
  Comment = ^ CommentNode;
  STRING2 = STRING[2];
  CommentNode = 
    RECORD                     (* info about a comment syntax *)
      start, stop : STRING2;
      nested : BOOLEAN;
      next : Comment;
    END;
  Melted = ^ MeltedNode;
  MeltedNode = 
    RECORD                     (* info about melted states *)
      sset : CRTable.CRTSet;   (* set of old states *)
      theState : INTEGER;      (* new state *)
      next : Melted;
    END;

VAR
  stateArray : ARRAY [0 .. maxStates] OF State;
  lastSimState : INTEGER;      (* last non melted state *)
  lastState : INTEGER;         (* last allocated state  *)
  rootState : INTEGER;         (* start state of DFA    *)
  firstMelted : Melted;        (* list of melted states *)
  firstComment : Comment;      (* list of comments      *)
  scanner,                     (* generated scanner     *)
  fram : TEXT;                 (* scanner frame         *)
  dirtyDFA,
  NewLine : BOOLEAN;

PROCEDURE SemErr (nr : INTEGER);
  BEGIN
    CRS.Error(nr + 100, CRS.line, CRS.col, CRS.pos)
  END;

PROCEDURE Put (ch : CHAR);
  BEGIN
    Write(scanner, ch)
  END;

PROCEDURE PutLn;
  BEGIN
    WriteLn(scanner)
  END;

PROCEDURE PutB (n : INTEGER);
  BEGIN
    Write(scanner, ' ':n);
  END;

PROCEDURE Indent (n : INTEGER);
  BEGIN
    IF NewLine THEN PutB(n) ELSE NewLine := TRUE
  END;

PROCEDURE PutS (s : STRING); FAR;
  VAR
    i : INTEGER;
  BEGIN
    FOR i := 1 TO Length(s) DO
      IF s[i] = '$' THEN WriteLn(scanner) ELSE Write(scanner, s[i]);
  END;

PROCEDURE PutS1 (s : STRING);
  BEGIN
    IF s[1] = '"' THEN BEGIN s[1] := ''''; s[Length(s)] := '''' END; PutS(s);
  END;

PROCEDURE PutI (i : INTEGER);
  BEGIN
    Write(scanner, i:1)
  END;

PROCEDURE PutI2 (i, n : INTEGER);
  BEGIN
    Write(scanner, i:n)
  END;

PROCEDURE PutC (ch : CHAR);
  BEGIN
    CASE ch OF
      #0 .. #31, #127 .. #255, '''' : BEGIN  PutS('CHR('); PutI(ORD(ch)); Put(')') END;
      ELSE BEGIN Put(''''); Put(ch); Put('''') END
    END
  END;

PROCEDURE PutSN (i : INTEGER);
  VAR
    sn : CRTable.SymbolNode;
  BEGIN
    CRTable.GetSym(i, sn);
    IF Length(sn.constant) > 0 THEN PutS(sn.constant) ELSE PutI(i);
  END;

PROCEDURE PutSE (i : INTEGER);
  BEGIN
    PutS('BEGIN sym := '); PutSN(i); PutS('; ');
  END;

PROCEDURE PutRange (s : CRTable.CRTSet; indent : INTEGER);
  VAR
    lo, hi : ARRAY [0 .. 31] OF CHAR;
    top, i : INTEGER;
    s1 : CRTable.CRTSet;

  BEGIN
  (*----- fill lo and hi *) 
    top :=  -1;
    i := 0;
    WHILE i < 256 (*PDT*)  DO BEGIN
      IF Sets.IsIn(s, i)
        THEN
          BEGIN
            INC(top); lo[top] := CHR(i); INC(i);
            WHILE (i < 256 (*PDT*) ) AND Sets.IsIn(s, i) DO INC(i);
            hi[top] := CHR(i - 1)
          END
        ELSE INC(i)
    END;
    (*----- print ranges *) 
    IF (top = 1) AND (lo[0] = #0) AND (hi[1] = #255
    (*PDT*) ) AND (CHR(ORD(hi[0]) + 2) = lo[1])
      THEN
        BEGIN
          Sets.Fill(s1); Sets.Differ(s1, s);
          PutS('NOT '); PutRange(s1, indent);
        END
      ELSE
        BEGIN
          PutS('(');
          i := 0;
          WHILE i <= top DO BEGIN
            IF hi[i] = lo[i]
              THEN BEGIN PutS('(ch = '); PutC(lo[i]) END
              ELSE IF lo[i] = #0 THEN
                BEGIN PutS('(ch <= '); PutC(hi[i]) END
              ELSE IF hi[i] = #255 (*PDT*)  THEN
                BEGIN PutS('(ch >= '); PutC(lo[i]) END
              ELSE
                BEGIN
                  PutS('(ch >= '); PutC(lo[i]); PutS(') AND (ch <= ');
                  PutC(hi[i])
                END;
            Put(')');
            IF i < top THEN BEGIN PutS(' OR$'); PutB(indent) END;
            INC(i)
          END;
          Put(')')
        END
  END;

PROCEDURE PutChCond (ch : CHAR);
  BEGIN
    PutS('(ch = '); PutC(ch); Put(')')
  END;

(* PrintStates          List the automaton for tracing
-------------------------------------------------------------------------*) 

PROCEDURE PrintStates;

  PROCEDURE PrintSymbol (typ, val, width : INTEGER);
    VAR
      name : CRTable.Name;
      len : INTEGER;
    BEGIN
      IF typ = CRTable.class
        THEN
          BEGIN
            CRTable.GetClassName(val, name);
            Write(CRS.lst, name); len := Length(name)
          END
        ELSE IF (val >= ORD(' ')) AND (val < 127) AND (val <> 34) THEN
          BEGIN Write(CRS.lst, '"', CHR(val), '"'); len := 3 END
        ELSE
          BEGIN Write(CRS.lst, 'CHR(', val:2, ')'); len := 7 END;
      WHILE len < width DO BEGIN Write(CRS.lst, ' '); INC(len) END
    END;

  VAR
    anAction : Action;
    first : BOOLEAN;
    s, i : INTEGER;
    targ : Target;
    sset : CRTable.CRTSet;
    name : CRTable.Name;
  BEGIN
    WriteLn(CRS.lst); WriteLn(CRS.lst, '-------- states ---------');
    s := rootState;
    WHILE s <= lastState DO BEGIN
      anAction := stateArray[s].firstAction;
      first := TRUE;
      IF stateArray[s].endOf = CRTable.noSym
        THEN Write(CRS.lst, '     ')
        ELSE Write(CRS.lst, 'E(', stateArray[s].endOf:2, ')');
      Write(CRS.lst, s:3, ':');
      IF anAction = NIL THEN WriteLn(CRS.lst);
      WHILE anAction <> NIL DO BEGIN
        IF first
          THEN BEGIN Write(CRS.lst, ' '); first := FALSE END
          ELSE BEGIN Write(CRS.lst, '          ') END;
        PrintSymbol(anAction^.typ, anAction^.sym, 0);
        Write(CRS.lst, ' ');
        targ := anAction^.target;
        WHILE targ <> NIL DO BEGIN
          Write(CRS.lst, targ^.theState:1, ' '); targ := targ^.next;
        END;
        IF anAction^.tc = CRTable.contextTrans
          THEN WriteLn(CRS.lst, ' context')
          ELSE WriteLn(CRS.lst);
        anAction := anAction^.next
      END;
      INC(s)
    END;
    WriteLn(CRS.lst); WriteLn(CRS.lst, '-------- character classes ---------');
    i := 0;
    WHILE i <= CRTable.maxC DO BEGIN
      CRTable.GetClass(i, sset); CRTable.GetClassName(i, name);
      Write(CRS.lst, name:10, ': ');
      Sets.Print(CRS.lst, sset, 80, 13);
      WriteLn(CRS.lst);
      INC(i)
    END
  END;

(* AddAction            Add a action to the action list of a state
------------------------------------------------------------------------*) 

PROCEDURE AddAction (act : Action; VAR head : Action);
  VAR
    a, lasta : Action;
  BEGIN
    a := head;
    lasta := NIL;
    WHILE TRUE DO BEGIN
      IF (a = NIL) OR (act^.typ < a^.typ) THEN
        (*collecting classes at the front improves performance*) 
        BEGIN
          act^.next := a;
          IF lasta = NIL THEN head := act ELSE lasta^.next := act;
          EXIT;
        END;
      lasta := a;
      a := a^.next;
    END;
  END;

(* DetachAction         Detach action a from list L
------------------------------------------------------------------------*) 

PROCEDURE DetachAction (a : Action; VAR L : Action);
  BEGIN
    IF L = a THEN L := a^.next ELSE IF L <> NIL THEN DetachAction(a, L^.next)
  END;

FUNCTION TheAction (theState : State; ch : CHAR) : Action;
  VAR
    a : Action;
    sset : CRTable.CRTSet;
  BEGIN
    a := theState.firstAction;
    WHILE a <> NIL DO BEGIN
      IF a^.typ = CRTable.chart
        THEN
          BEGIN
            IF ORD(ch) = a^.sym THEN BEGIN TheAction := a; EXIT END
          END
        ELSE IF a^.typ = CRTable.class THEN
          BEGIN
            CRTable.GetClass(a^.sym, sset);
            IF Sets.IsIn(sset, ORD(ch)) THEN BEGIN TheAction := a; EXIT END
          END;
      a := a^.next
    END;
    TheAction := NIL
  END;

PROCEDURE AddTargetList (VAR lista, listb : Target);
  VAR
    p, t : Target;

  PROCEDURE AddTarget (t : Target; VAR list : Target);
    LABEL
      999;
    VAR
      p, lastp : Target;
    BEGIN
      p := list;
      lastp := NIL;
      WHILE TRUE DO BEGIN
        IF (p = NIL) OR (t^.theState < p^.theState) THEN GOTO 999;
        IF p^.theState = t^.theState THEN BEGIN DISPOSE(t); EXIT END;
        lastp := p; p := p^.next
      END;
      999:
      t^.next := p;
      IF lastp = NIL THEN list := t ELSE lastp^.next := t
    END;

  BEGIN
    p := lista;
    WHILE p <> NIL DO BEGIN
      NEW(t); t^.theState := p^.theState; AddTarget(t, listb); p := p^.next
    END
  END;

(* NewMelted            Generate new info about a melted state
------------------------------------------------------------------------*) 

FUNCTION NewMelted (sset : CRTable.CRTSet; s : INTEGER) : Melted;
  VAR
    melt : Melted;
  BEGIN
    NEW(melt);
    melt^.sset := sset; melt^.theState := s; melt^.next := firstMelted;
    firstMelted := melt; NewMelted := melt
  END;

(* NewState             Return a new state node
------------------------------------------------------------------------*) 

FUNCTION NewState : INTEGER;
  BEGIN
    INC(lastState);
    IF lastState > maxStates THEN CRTable.Restriction(7, maxStates);
    stateArray[lastState].firstAction := NIL;
    stateArray[lastState].endOf := CRTable.noSym;
    stateArray[lastState].ctx := FALSE;
    NewState := lastState
  END;

(* NewTransition        Generate transition (gn.theState, gn.p1) --> toState
------------------------------------------------------------------------*) 

PROCEDURE NewTransition (from : INTEGER; gn : CRTable.GraphNode; toState : INTEGER);
  VAR
    a : Action;
    t : Target;
  BEGIN
    IF toState = rootState THEN SemErr(21);
    NEW(t); t^.theState := toState; t^.next := NIL;
    NEW(a); a^.typ := gn.typ; a^.sym := gn.p1; a^.tc := gn.p2;
    a^.target := t;
    AddAction(a, stateArray[from].firstAction)
  END;

(* NewComment           Define new comment
-------------------------------------------------------------------------*) 

PROCEDURE NewComment (start, stop : INTEGER; nested : BOOLEAN);
  VAR
    com : Comment;

  PROCEDURE MakeStr (gp : INTEGER; VAR s : STRING2);
    VAR
      i, n : INTEGER;
      gn : CRTable.GraphNode;
      sset : CRTable.CRTSet;
    BEGIN
      i := 1;
      WHILE gp <> 0 DO BEGIN
        CRTable.GetNode(gp, gn);
        IF gn.typ = CRTable.chart
          THEN
            BEGIN IF i < 3 THEN s[i] := CHR(gn.p1); INC(i) END
          ELSE IF gn.typ = CRTable.class THEN
            BEGIN
              CRTable.GetClass(gn.p1, sset);
              IF Sets.Elements(sset, n) <> 1 THEN SemErr(26);
              IF i < 3 THEN s[i] := CHR(n);
              INC(i)
            END
          ELSE SemErr(22);
        gp := gn.next
      END;
      IF (i = 1) OR (i > 3) THEN SemErr(25) ELSE s[0] := CHR(i-1)
    END;

  BEGIN
    NEW(com);
    MakeStr(start, com^.start);
    MakeStr(stop, com^.stop);
    com^.nested := nested;
    com^.next := firstComment;
    firstComment := com
  END;

(* DeleteTargetList     Delete a target list
-------------------------------------------------------------------------*) 

PROCEDURE DeleteTargetList (list : Target);
  BEGIN
    IF list <> NIL THEN BEGIN DeleteTargetList(list^.next); DISPOSE(list) END;
  END;

(* DeleteActionList     Delete an action list
-------------------------------------------------------------------------*) 

PROCEDURE DeleteActionList (anAction : Action);
  BEGIN
    IF anAction <> NIL THEN
      BEGIN
        DeleteActionList(anAction^.next);
        DeleteTargetList(anAction^.target);
        DISPOSE(anAction)
      END
  END;

(* MakeSet              Expand action symbol into symbol set
-------------------------------------------------------------------------*) 

PROCEDURE MakeSet (p : Action; VAR sset : CRTable.CRTSet);
  BEGIN
    IF p^.typ = CRTable.class
      THEN CRTable.GetClass(p^.sym, sset)
      ELSE BEGIN Sets.Clear(sset); Sets.Incl(sset, p^.sym) END
  END;

(* ChangeAction         Change the action symbol to set
-------------------------------------------------------------------------*) 

PROCEDURE ChangeAction (a : Action; sset : CRTable.CRTSet);
  VAR
    nr : INTEGER;

  BEGIN
    IF Sets.Elements(sset, nr) = 1
      THEN BEGIN a^.typ := CRTable.chart; a^.sym := nr END
      ELSE
        BEGIN
          nr := CRTable.ClassWithSet(sset);
          IF nr < 0 THEN nr := CRTable.NewClass('##', sset);
          a^.typ := CRTable.class; a^.sym := nr
        END
  END;

(* CombineShifts     Combine shifts with different symbols into same state
-------------------------------------------------------------------------*) 

PROCEDURE CombineShifts;
  VAR
    s : INTEGER;
    a, b, c : Action;
    seta, setb : CRTable.CRTSet;

  BEGIN
    s := rootState;
    WHILE s <= lastState DO BEGIN
      a := stateArray[s].firstAction;
      WHILE a <> NIL DO BEGIN
        b := a^.next;
        WHILE b <> NIL DO BEGIN
          IF (a^.target^.theState = b^.target^.theState) AND (a^.tc = b^.tc)
            THEN
              BEGIN
                MakeSet(a, seta); MakeSet(b, setb);
                Sets.Unite(seta, setb);
                ChangeAction(a, seta);
                c := b; b := b^.next;
                DetachAction(c, a)
              END
            ELSE b := b^.next
        END;
        a := a^.next
      END;
      INC(s)
    END
  END;

(* DeleteRedundantStates   Delete unused and equal states
-------------------------------------------------------------------------*) 

PROCEDURE DeleteRedundantStates;
  VAR
    anAction : Action;
    s, s2, next : INTEGER;
    used : Sets.BITARRAY;
    {ARRAY [0 .. maxStates DIV Sets.size] OF BITSET } (*KJG*)
    newStateNr : ARRAY [0 .. maxStates] OF INTEGER;

  PROCEDURE FindUsedStates (s : INTEGER);
    VAR
      anAction : Action;
    BEGIN
      IF Sets.IsIn(used, s) THEN EXIT;
      Sets.Incl(used, s);
      anAction := stateArray[s].firstAction;
      WHILE anAction <> NIL DO BEGIN
        FindUsedStates(anAction^.target^.theState);
        anAction := anAction^.next
      END
    END;

  BEGIN
    Sets.Clear(used);
    FindUsedStates(rootState);
    (*---------- combine equal final states ------------*) 
    s := rootState + 1;
    (*root state cannot be final*) 
    WHILE s <= lastState DO BEGIN
      IF Sets.IsIn(used, s) AND (stateArray[s].endOf <> CRTable.noSym) THEN
        IF (stateArray[s].firstAction = NIL) AND NOT stateArray[s].ctx THEN
          BEGIN
            s2 := s + 1;
            WHILE s2 <= lastState DO BEGIN
              IF Sets.IsIn(used, s2) AND (stateArray[s].endOf = stateArray[s2].endOf) THEN
                IF (stateArray[s2].firstAction = NIL) AND NOT stateArray[s2].ctx THEN
                  BEGIN Sets.Excl(used, s2); newStateNr[s2] := s END;
              INC(s2)
            END
          END;
      INC(s)
    END;
    s := rootState;
    (* + 1 ?  PDT - was rootState, but Oberon had .next ie +1
                    seems to work both ways?? *) 
    WHILE s <= lastState DO BEGIN
      IF Sets.IsIn(used, s) THEN
        BEGIN
          anAction := stateArray[s].firstAction;
          WHILE anAction <> NIL DO BEGIN
            IF NOT Sets.IsIn(used, anAction^.target^.theState) THEN
              anAction^.target^.theState := newStateNr[anAction^.target^.theState];
            anAction := anAction^.next
          END
        END;
      INC(s)
    END;
    (*-------- delete unused states --------*) 
    s := rootState + 1;
    next := s;
    WHILE s <= lastState DO BEGIN
      IF Sets.IsIn(used, s)
        THEN
          BEGIN
            IF next < s THEN stateArray[next] := stateArray[s];
            newStateNr[s] := next;
            INC(next)
          END
        ELSE DeleteActionList(stateArray[s].firstAction);
      INC(s)
    END;
    lastState := next - 1;
    s := rootState;
    WHILE s <= lastState DO BEGIN
      anAction := stateArray[s].firstAction;
      WHILE anAction <> NIL DO BEGIN
        anAction^.target^.theState := newStateNr[anAction^.target^.theState];
        anAction := anAction^.next
      END;
      INC(s)
    END
  END;

(* ConvertToStates    Convert the TDG in gp into a subautomaton of the DFA
------------------------------------------------------------------------*) 

PROCEDURE ConvertToStates (gp0, sp : INTEGER);
(*note: gn.line is abused as a state number!*) 

  VAR
    stepped, visited: CRTable.MarkList;

  PROCEDURE NumberNodes (gp, snr : INTEGER);
    VAR
      gn : CRTable.GraphNode;
    BEGIN
      IF gp = 0 THEN EXIT; (*end of graph*)
      CRTable.GetNode(gp, gn);
      IF gn.line >= 0 THEN EXIT; (*already visited*)
      IF snr < rootState THEN snr := NewState;
      gn.line := snr; CRTable.PutNode(gp, gn);
      IF CRTable.DelGraph(gp) THEN stateArray[snr].endOf := sp;
      (*snr is end state*) 
      CASE gn.typ OF
        CRTable.class, CRTable.chart :
          BEGIN NumberNodes(ABS(gn.next), rootState - 1) END;
        CRTable.opt :
          BEGIN NumberNodes(ABS(gn.next), rootState - 1); NumberNodes(gn.p1, snr) END;
        CRTable.iter :
          BEGIN NumberNodes(ABS(gn.next), snr); NumberNodes(gn.p1, snr) END;
        CRTable.alt :
          BEGIN NumberNodes(gn.p1, snr); NumberNodes(gn.p2, snr) END;
      END;
    END;

  FUNCTION TheState (gp : INTEGER) : INTEGER;
    VAR
      s : INTEGER;
      gn : CRTable.GraphNode;
    BEGIN
      IF gp = 0
        THEN BEGIN s := NewState; stateArray[s].endOf := sp; TheState := s END
        ELSE BEGIN CRTable.GetNode(gp, gn); TheState := gn.line END
    END;

  PROCEDURE Step (from, gp : INTEGER);
    VAR
      gn : CRTable.GraphNode;
      next : INTEGER;
    BEGIN
      IF gp = 0 THEN EXIT;
      CRTable.InclMarkList(stepped, gp);
      CRTable.GetNode(gp, gn);
      CASE gn.typ OF
        CRTable.class, CRTable.chart :
          BEGIN NewTransition(from, gn, TheState(ABS(gn.next))) END;
        CRTable.alt :
          BEGIN Step(from, gn.p1); Step(from, gn.p2) END;
        CRTable.opt, CRTable.iter :
          BEGIN
            next := ABS(gn.next);
            IF NOT CRTable.IsInMarkList(stepped, next) THEN Step(from, next);
            Step(from, gn.p1)
          END;
      END
    END;

  PROCEDURE FindTrans (gp : INTEGER; start : BOOLEAN);
    VAR
      gn : CRTable.GraphNode;
    BEGIN
      IF (gp = 0) OR CRTable.IsInMarkList(visited, gp) THEN EXIT;
      CRTable.InclMarkList(visited, gp); CRTable.GetNode(gp, gn);
      IF start THEN (* start of group of equally numbered nodes *)
        BEGIN
          CRTable.ClearMarkList(stepped);
          Step(gn.line, gp); 
        END;
      CASE gn.typ OF
        CRTable.class, CRTable.chart :
          BEGIN FindTrans(ABS(gn.next), TRUE) END;
        CRTable.opt :
          BEGIN FindTrans(ABS(gn.next), TRUE); FindTrans(gn.p1, FALSE) END;
        CRTable.iter :
          BEGIN FindTrans(ABS(gn.next), FALSE); FindTrans(gn.p1, FALSE) END;
        CRTable.alt :
          BEGIN FindTrans(gn.p1, FALSE); FindTrans(gn.p2, FALSE) END;
      END;
    END;

  VAR
    gn : CRTable.GraphNode;
    i : INTEGER;

  BEGIN
    IF CRTable.DelGraph(gp0) THEN SemErr(20);
    FOR i := 0 TO CRTable.nNodes DO BEGIN
      CRTable.GetNode(i, gn); gn.line :=  -1; CRTable.PutNode(i, gn)
    END;
    NumberNodes(gp0, rootState);
    CRTable.ClearMarkList(visited);
    FindTrans(gp0, TRUE)
  END;

(* MatchesDFA         TRUE, if the string str can be recognized by the DFA
------------------------------------------------------------------------*)
{ fossil from modula - maybe we should delete
PROCEDURE MatchesDFA (str: STRING; VAR matchedSp: INTEGER): BOOLEAN;
  VAR
    len: INTEGER;

  PROCEDURE Match (p: INTEGER; s: INTEGER): BOOLEAN;
    VAR
      ch:    CHAR;
      a:     Action;
      equal: BOOLEAN;
      sset:   CRTable.CRTSet;
    BEGIN
      IF p >= len THEN
        IF stateArray[s].endOf # CRTable.noSym
          THEN matchedSp := stateArray[s].endOf; RETURN TRUE
          ELSE RETURN FALSE
        END
      END;
      a := stateArray[s].firstAction; ch := str[p];
      WHILE a # NIL DO
        CASE a^.typ OF
          CRTable.char:
            equal := VAL(INTEGER, ORD(ch)) = a^.sym
        | CRTable.class:
            CRTable.GetClass(a^.sym, sset); equal := Sets.IsIn(sset, ORD(ch))
        END;
        IF equal THEN RETURN Match(p + 1, a^.target^.theState) END;
        a := a^.next
      END;
      RETURN FALSE
    END Match;

  BEGIN
    len := Length(str) - 1; (*strip quotes*)
    RETURN Match(1, rootState)
  END MatchesDFA;
}

PROCEDURE MatchDFA (str : STRING; sp : INTEGER; VAR matchedSp : INTEGER);
  LABEL
    999;
  VAR
    s, sto : INTEGER (*State*) ;
    a : Action;
    gn : CRTable.GraphNode;
    i, len : INTEGER;
    weakMatch : BOOLEAN;
  BEGIN (* s with quotes *)
    s := rootState;
    i := 2; len := Length(str);
    weakMatch := FALSE;
    WHILE TRUE DO BEGIN
    (* try to match str against existing DFA *) 
      IF i = len THEN GOTO 999;
      a := TheAction(stateArray[s], str[i]);
      IF a = NIL THEN GOTO 999;
      IF a^.typ = CRTable.class THEN weakMatch := TRUE;
      s := a^.target^.theState;
      INC(i)
    END;
    999:
    IF weakMatch AND ((i <> len) OR (stateArray[s].endOf = CRTable.noSym)) THEN BEGIN
      s := rootState; i := 2; dirtyDFA := TRUE
    END;
    WHILE i < len DO BEGIN
    (* make new DFA for str[i..len-1] *) 
      sto := NewState;
      gn.typ := CRTable.chart;
      gn.p1 := ORD(str[i]); gn.p2 := CRTable.normTrans;
      NewTransition(s, gn, sto);
      s := sto; INC(i)
    END;
    matchedSp := stateArray[s].endOf;
    IF stateArray[s].endOf = CRTable.noSym THEN stateArray[s].endOf := sp;
  END;

(* SplitActions     Generate unique actions from two overlapping actions
-----------------------------------------------------------------------*) 

PROCEDURE SplitActions (a, b : Action);
  VAR
    c : Action;
    seta, setb, setc : CRTable.CRTSet;

  PROCEDURE CombineTransCodes (t1, t2 : INTEGER; VAR result : INTEGER);
    BEGIN
      IF t1 = CRTable.contextTrans THEN result := t1 ELSE result := t2
    END;

  BEGIN
    MakeSet(a, seta);
    MakeSet(b, setb);
    IF Sets.Equal(seta, setb)
      THEN
        BEGIN
          AddTargetList(b^.target, a^.target);
          DeleteTargetList(b^.target);
          CombineTransCodes(a^.tc, b^.tc, a^.tc);
          DetachAction(b, a);
          DISPOSE(b);
        END
      ELSE IF Sets.Includes(seta, setb) THEN
        BEGIN
          setc := seta;
          Sets.Differ(setc, setb);
          AddTargetList(a^.target, b^.target);
          CombineTransCodes(a^.tc, b^.tc, b^.tc);
          ChangeAction(a, setc)
        END
      ELSE IF Sets.Includes(setb, seta) THEN
        BEGIN
          setc := setb;
          Sets.Differ(setc, seta);
          AddTargetList(b^.target, a^.target);
          CombineTransCodes(a^.tc, b^.tc, a^.tc);
          ChangeAction(b, setc)
        END
      ELSE
        BEGIN
          Sets.Intersect(seta, setb, setc);
          Sets.Differ(seta, setc);
          Sets.Differ(setb, setc);
          ChangeAction(a, seta);
          ChangeAction(b, setb);
          NEW(c);
          c^.target := NIL;
          CombineTransCodes(a^.tc, b^.tc, c^.tc);
          AddTargetList(a^.target, c^.target);
          AddTargetList(b^.target, c^.target);
          ChangeAction(c, setc);
          AddAction(c, a)
        END
  END;

(* MakeUnique           Make all actions in this state unique
-------------------------------------------------------------------------*) 

PROCEDURE MakeUnique (s : INTEGER; VAR changed : BOOLEAN);
  VAR
    a, b : Action;

  FUNCTION Overlap (a, b : Action) : BOOLEAN;
    VAR
      seta, setb : CRTable.CRTSet;
    BEGIN
      IF a^.typ = CRTable.chart
        THEN
          BEGIN
            IF b^.typ = CRTable.chart
              THEN BEGIN Overlap :=  a^.sym = b^.sym END
              ELSE
                BEGIN
                  CRTable.GetClass(b^.sym, setb);
                  Overlap :=  Sets.IsIn(setb, a^.sym)
                 END
          END
        ELSE
          BEGIN
            CRTable.GetClass(a^.sym, seta);
            IF b^.typ = CRTable.chart
              THEN BEGIN Overlap :=  Sets.IsIn(seta, b^.sym) END
              ELSE
                BEGIN
                  CRTable.GetClass(b^.sym, setb);
                  Overlap :=  NOT Sets.Different(seta, setb)
                END
          END
    END;

  BEGIN
    a := stateArray[s].firstAction;
    changed := FALSE;
    WHILE a <> NIL DO BEGIN
      b := a^.next;
      WHILE b <> NIL DO BEGIN
        IF Overlap(a, b)
          THEN
            BEGIN
              SplitActions(a, b);
              changed := TRUE; EXIT
              (* originally no RETURN.  FST blows up if we leave RETURN out.
                 Somewhere there is a field that is not properly set, but I
                 have not chased this down completely Fri  08-20-1993 *)
            END;
        b := b^.next;
      END;
      a := a^.next
    END;
  END;

(* MeltStates       Melt states appearing with a shift of the same symbol
-----------------------------------------------------------------------*) 

PROCEDURE MeltStates (s : INTEGER; VAR correct : BOOLEAN);
  VAR
    anAction : Action;
    ctx : BOOLEAN;
    endOf : INTEGER;
    melt : Melted;
    sset : CRTable.CRTSet;
    s1 : INTEGER;
    changed : BOOLEAN;

  PROCEDURE AddMeltedSet (nr : INTEGER; VAR sset : CRTable.CRTSet);
    VAR
      m : Melted;
    BEGIN
      m := firstMelted;
      WHILE (m <> NIL) AND (m^.theState <> nr) DO m := m^.next;
      IF m = NIL THEN CRTable.Restriction( - 1, 0);
      Sets.Unite(sset, m^.sset);
    END;

  PROCEDURE GetStateSet (t : Target; VAR sset : CRTable.CRTSet; VAR endOf : INTEGER;
                         VAR ctx : BOOLEAN);
  (* Modified back to match Oberon version Fri  08-20-1993
     This seemed to cause problems with some larger automata *)
     (* new bug fix Wed  11-24-1993  from ETHZ incorporated *)
    VAR
      lastS : INTEGER;
    BEGIN
      Sets.Clear(sset); endOf := CRTable.noSym; ctx := FALSE;
      lastS := lastState; (* Fri  08-20-1993 *)
      WHILE t <> NIL DO BEGIN
        IF t^.theState <= lastSimState
          THEN Sets.Incl(sset, t^.theState)
          ELSE AddMeltedSet(t^.theState, sset);
        IF stateArray[t^.theState].endOf <> CRTable.noSym THEN
          BEGIN
            IF (endOf = CRTable.noSym) OR (endOf = stateArray[t^.theState].endOf)
              THEN
                BEGIN
                  endOf := stateArray[t^.theState].endOf;
                  lastS := t^.theState
                END
              ELSE
                BEGIN
                  WriteLn(CRS.lst);
                  WriteLn(CRS.lst, 'Tokens ', endOf, ' and ',
                          stateArray[t^.theState].endOf, ' cannot be distinguished.');
                  correct := FALSE;
                END;
          END;
        IF stateArray[t^.theState].ctx THEN
          BEGIN
            ctx := TRUE;
(* removed this test Fri  08-30-02
            IF stateArray[t^.theState].endOf <> CRTable.noSym THEN
              BEGIN
                WriteLn(CRS.lst); WriteLn(CRS.lst, 'Ambiguous CONTEXT clause.');
                correct := FALSE
              END
*)
          END;
        t := t^.next
      END
    END;

  PROCEDURE FillWithActions (s : INTEGER; targ : Target);
    VAR
      anAction, a : Action;
    BEGIN
      WHILE targ <> NIL DO BEGIN
        anAction := stateArray[targ^.theState].firstAction;
        WHILE anAction <> NIL DO BEGIN
          NEW(a);
          a^ := anAction^;
          a^.target := NIL;
          AddTargetList(anAction^.target, a^.target);
          AddAction(a, stateArray[s].firstAction);
          anAction := anAction^.next
        END;
        targ := targ^.next
      END;
    END;

  FUNCTION KnownMelted (sset : CRTable.CRTSet; VAR melt : Melted) : BOOLEAN;
    BEGIN
      melt := firstMelted;
      WHILE melt <> NIL DO BEGIN
        IF Sets.Equal(sset, melt^.sset) THEN BEGIN KnownMelted := TRUE; EXIT END;
        melt := melt^.next
      END;
      KnownMelted := FALSE
    END;

  BEGIN
    anAction := stateArray[s].firstAction;
    WHILE anAction <> NIL DO BEGIN
      IF anAction^.target^.next <> NIL THEN
        BEGIN
          GetStateSet(anAction^.target, sset, endOf, ctx);
          IF NOT KnownMelted(sset, melt) THEN
            BEGIN
              s1 := NewState;
              stateArray[s1].endOf := endOf;
              stateArray[s1].ctx := ctx;
              FillWithActions(s1, anAction^.target);
              REPEAT
                MakeUnique(s1, changed)
              UNTIL NOT changed;
              melt := NewMelted(sset, s1);
            END;
          DeleteTargetList(anAction^.target^.next);
          anAction^.target^.next := NIL;
          anAction^.target^.theState := melt^.theState
        END;
      anAction := anAction^.next
    END
  END;

(* MakeDeterministic     Make NDFA --> DFA
------------------------------------------------------------------------*) 

PROCEDURE MakeDeterministic (VAR correct : BOOLEAN);
  VAR
    s : INTEGER;
    changed : BOOLEAN;

  PROCEDURE FindCtxStates;
  (* Find states reached by a context transition *) 
    VAR
      a : Action;
      s : INTEGER;
    BEGIN
      s := rootState;
      WHILE s <= lastState DO BEGIN
        a := stateArray[s].firstAction;
        WHILE a <> NIL DO BEGIN
          IF a^.tc = CRTable.contextTrans THEN
            stateArray[a^.target^.theState].ctx := TRUE;
          a := a^.next
        END;
        INC(s)
      END;
    END;

  BEGIN
    lastSimState := lastState;
    FindCtxStates;
    s := rootState;
    WHILE s <= lastState DO BEGIN
      REPEAT
        MakeUnique(s, changed)
      UNTIL NOT changed;
      INC(s)
    END;
    correct := TRUE;
    s := rootState;
    WHILE s <= lastState DO BEGIN
      MeltStates(s, correct);
      INC(s)
    END;
    DeleteRedundantStates;
    CombineShifts;
    (* ====    IF CRTable.ddt["A"] THEN PrintStates END ==== *)
  END;

(* GenComment            Generate a procedure to scan comments
-------------------------------------------------------------------------*) 

PROCEDURE GenComment (leftMarg : INTEGER; com : Comment);

  PROCEDURE GenBody (leftMarg : INTEGER);
    BEGIN
      PutB(leftMarg); PutS('WHILE TRUE DO BEGIN$');
      PutB(leftMarg + 2); PutS('IF ');
      PutChCond(com^.stop[1]); PutS(' THEN BEGIN$');
      IF Length(com^.stop) = 1
        THEN
          BEGIN
            PutB(leftMarg + 4);
            PutS('DEC(level); oldEols := curLine - startLine; NextCh;$');
            PutB(leftMarg + 4);
            PutS('IF level = 0 THEN BEGIN Comment := TRUE; GOTO 999; END;$');
          END
        ELSE
          BEGIN
            PutB(leftMarg + 4); PutS('NextCh;$');
            PutB(leftMarg + 4); PutS('IF ');
            PutChCond(com^.stop[2]); PutS(' THEN BEGIN$');
            PutB(leftMarg + 6); PutS('DEC(level); NextCh;$');
            PutB(leftMarg + 6);
            PutS('IF level = 0 THEN BEGIN Comment := TRUE; GOTO 999; END$');
            PutB(leftMarg + 4); PutS('END$');
          END;
      IF com^.nested
        THEN
          BEGIN
            PutB(leftMarg + 2); PutS('END ELSE IF '); PutChCond(com^.start[1]);
            PutS(' THEN BEGIN$');
            IF Length(com^.start) = 1
              THEN
                BEGIN PutB(leftMarg + 4); PutS('INC(level); NextCh;$'); END
              ELSE
                BEGIN
                  PutB(leftMarg + 4); PutS('NextCh;$');
                  PutB(leftMarg + 4); PutS('IF '); PutChCond(com^.start[2]);
                  PutS(' THEN BEGIN '); PutS('INC(level); NextCh '); PutS('END$');
                END;
          END;
      PutB(leftMarg + 2);
      PutS('END ELSE IF ch = EF THEN BEGIN Comment := FALSE; GOTO 999; END$');
      PutB(leftMarg + 2); PutS('ELSE NextCh;$');
      PutB(leftMarg); PutS('END; (* WHILE TRUE *)$');
    END;

  BEGIN
    PutS('IF '); PutChCond(com^.start[1]); PutS(' THEN BEGIN$');
    IF Length(com^.start) = 1
      THEN
        BEGIN PutB(leftMarg + 2); PutS('NextCh;$'); GenBody(leftMarg + 2) END
      ELSE
        BEGIN
          PutB(leftMarg + 2); PutS('NextCh;$');
          PutB(leftMarg + 2); PutS('IF ');
          PutChCond(com^.start[2]); PutS(' THEN BEGIN$');
          PutB(leftMarg + 4); PutS('NextCh;$');
          GenBody(leftMarg + 4);
          PutB(leftMarg + 2); PutS('END ELSE BEGIN$');
          PutB(leftMarg + 4); PutS('IF (ch = CR) OR (ch = LF) THEN BEGIN$');
          PutB(leftMarg + 6); PutS('DEC(curLine); lineStart := oldLineStart$');
          PutB(leftMarg + 4); PutS('END;$');
          PutB(leftMarg + 4);
          PutS('DEC(bp); ch := lastCh; Comment := FALSE;$');
          PutB(leftMarg + 2); PutS('END;$');
        END;
    PutB(leftMarg); PutS('END;$'); PutB(leftMarg);
  END;

(* CopyFramePart   Copy from file <fram> to file <framOut> until <stopStr>
-------------------------------------------------------------------------*) 

PROCEDURE CopyFramePart (stopStr : STRING; VAR leftMarg : INTEGER; VAR framIn, framOut : TEXT);
  CONST
    CR = #13;
    LF = #10;
  VAR
    ch, startCh : CHAR;
    slen, i, j : INTEGER;
    temp : ARRAY [1 .. 63] OF CHAR;

  BEGIN
    startCh := stopStr[1];
    Read(framIn, ch);
    slen := Length(stopStr);
    WHILE NOT EOF(framIn) DO BEGIN
      IF (ch = CR) OR (ch = LF)
        THEN leftMarg := 0
        ELSE INC(leftMarg);
      IF ch = startCh
        THEN (* check if stopString occurs *)
          BEGIN
            i := 1;
            WHILE (i < slen) AND (ch = stopStr[i]) AND NOT EOF(framIn) DO BEGIN
              temp[i] := ch; INC(i); Read(framIn, ch)
            END;
            IF ch = stopStr[i] THEN BEGIN DEC(leftMarg); EXIT END;
            (* found ==> exit , else continue *) 
            FOR j := 1 TO i-1 DO Write(framOut, temp[j]);
            Write(framOut, ch);
            INC(leftMarg, i);
          END
        ELSE Write(framOut, ch);
      Read(framIn, ch)
    END;
  END;

(* ImportSymConsts      Generates the import of the named symbol constants
-------------------------------------------------------------------------*) 

PROCEDURE ImportSymConsts (leader : STRING; putS : PutSProc);
  VAR
    oldLen, pos : INTEGER;
    cname : CRTable.Name;
    gn : CRTable.GraphNode;
    sn : CRTable.SymbolNode;
    gramName : STRING;

  PROCEDURE PutImportSym;
    BEGIN
      IF pos + oldLen > MaxSourceLineLength THEN
        BEGIN putS('$  '); pos := 2 END;
      putS(cname);
      INC(pos, oldLen + 1);
      (* This is not strictly correct, as the increase of 2 should be
         lower. I omitted it, because to separate it would be too
         complicated, and no unexpected side effects are likely, since it
         is only called again outside the loop - after which "pos" is not
         used again
      *) 
    END;

  BEGIN
  (* ----- Import list of the generated Symbol Constants Module ----- *) 
    CRTable.GetNode(CRTable.root, gn);
    CRTable.GetSym(gn.p1, sn);
    putS(leader);
    gramName := Copy(sn.name, 1, 7);
    putS(gramName);
    putS('G (* Symbol Constants *);$');
  END;

(* GenLiterals           Generate CASE for the recognition of literals
-------------------------------------------------------------------------*) 

PROCEDURE GenLiterals (leftMarg : INTEGER);
  VAR
    i, j, k : INTEGER;
    key : ARRAY [0 .. CRTable.maxLiterals] OF CRTable.Name;
    knr : ARRAY [0 .. CRTable.maxLiterals] OF INTEGER;
    ch : CHAR;
    sn : CRTable.SymbolNode;

  BEGIN
  (*-- sort literal list*) 
    i := 0;
    k := 0;
    WHILE i <= CRTable.maxT DO BEGIN
      CRTable.GetSym(i, sn);
      IF sn.struct = CRTable.litToken THEN
        BEGIN
          j := k - 1;
          WHILE (j >= 0) AND (sn.name < key[j]) DO BEGIN
            key[j + 1] := key[j]; knr[j + 1] := knr[j]; DEC(j)
          END;
          key[j + 1] := sn.name;
          knr[j + 1] := i;
          INC(k);
          IF k > CRTable.maxLiterals THEN
            CRTable.Restriction(10, CRTable.maxLiterals);
        END;
      INC(i)
    END;
    (*-- print CASE statement*) 
    IF k <> 0 THEN
      BEGIN
        PutS('CASE CurrentCh(bp0) OF$');
        PutB(leftMarg);
        i := 0;
        WHILE i < k DO BEGIN
          ch := key[i, 2]; (*key[i, 0] = quote*)
          IF i <> 0 THEN BEGIN PutLn; PutB(leftMarg) END;
          PutS('  '); PutC(ch); j := i;
          REPEAT
            IF i = j
              THEN PutS(': IF')
              ELSE BEGIN PutB(leftMarg + 6); PutS(' END ELSE IF') END;
            PutS(' Equal('); PutS1(key[i]); PutS(') THEN ');
            PutSE(knr[i]); PutLn;
            INC(i);
          UNTIL (i = k) OR (key[i, 2] <> ch);
          PutB(leftMarg + 6); PutS(' END;');
        END;
        PutLn; PutB(leftMarg); PutS('ELSE BEGIN END$');
        PutB(leftMarg); PutS('END')
      END;
  END;

(* WriteState           Write the source text of a scanner state
-------------------------------------------------------------------------*) 

PROCEDURE WriteState (leftMarg, s : INTEGER; VAR FirstState : BOOLEAN);
  VAR
    anAction : Action;
    ind : INTEGER;
    first, ctxEnd : BOOLEAN;
    sn : CRTable.SymbolNode;
    endOf : INTEGER;
    sset : CRTable.CRTSet;

  BEGIN
    endOf := stateArray[s].endOf;
    IF (endOf > CRTable.maxT) AND (endOf <> CRTable.noSym)
      THEN (*pragmas have been moved*)
        BEGIN endOf := CRTable.maxT + CRTable.maxSymbols - endOf END;
    Indent(leftMarg);
    IF FirstState THEN FirstState := FALSE;
    PutS('  '); PutI2(s, 2); PutS(': ');
    first := TRUE;
    ctxEnd := stateArray[s].ctx;
    anAction := stateArray[s].firstAction;
    WHILE anAction <> NIL DO BEGIN
      IF first
        THEN
          BEGIN PutS('IF '); first := FALSE; ind := leftMarg + 3 END
        ELSE
          BEGIN PutB(leftMarg + 6); PutS('END ELSE IF '); ind := leftMarg + 6 END;
      IF anAction^.typ = CRTable.chart
        THEN
          BEGIN PutChCond(CHR(anAction^.sym)) END
        ELSE
          BEGIN
            CRTable.GetClass(anAction^.sym, sset);
            PutRange(sset, leftMarg + ind)
          END;
      PutS(' THEN BEGIN');
      IF anAction^.target^.theState <> s THEN
        BEGIN
          PutS(' state := ');
          PutI(anAction^.target^.theState);
          Put(';')
        END;
      IF anAction^.tc = CRTable.contextTrans
        THEN BEGIN PutS(' INC(apx)'); ctxEnd := FALSE END
        ELSE IF stateArray[s].ctx THEN PutS(' apx := 0');
      PutS(' $');
      anAction := anAction^.next
    END;
    IF stateArray[s].firstAction <> NIL THEN
      BEGIN PutB(leftMarg + 6); PutS('END ELSE ') END;
    IF endOf = CRTable.noSym
      THEN
        BEGIN PutS('BEGIN sym := no_Sym; '); END
      ELSE (*final theState*)
        BEGIN
          CRTable.GetSym(endOf, sn);
          IF ctxEnd THEN (*cut appendix*)
            BEGIN
              PutS('BEGIN bp := bp - apx - 1;');
              PutS(' DEC(nextLen, apx); NextCh; ')
            END;
          PutSE(endOf);
          IF sn.struct = CRTable.classLitToken THEN
            BEGIN PutS('CheckLiteral; ') END
        END;
    IF ctxEnd
      THEN BEGIN PutS('EXIT; END; END;$') END
      ELSE BEGIN PutS('EXIT; END;$'); END;
  END;

(* WriteScanner         Write the scanner source file
-------------------------------------------------------------------------*) 

PROCEDURE WriteScanner (VAR ok : BOOLEAN);
  CONST
    ListingWidth = 78;

  VAR
    gramName, fGramName, fn : STRING;
    startTab : ARRAY [0 .. 255] OF INTEGER;
    com : Comment;
    i, j, s : INTEGER;
    gn : CRTable.GraphNode;
    sn : CRTable.SymbolNode;

  PROCEDURE FillStartTab;
    VAR
      anAction : Action;
      i, targetState, undefState : INTEGER;
      class : CRTable.CRTSet;
    BEGIN
      undefState := lastState + 2;
      startTab[0] := lastState + 1; (*eof*)
      i := 1;
      WHILE i < 256 (*PDT*)  DO BEGIN
        startTab[i] := undefState;
        INC(i)
      END;
      anAction := stateArray[rootState].firstAction;
      WHILE anAction <> NIL DO BEGIN
        targetState := anAction^.target^.theState;
        IF anAction^.typ = CRTable.chart
          THEN startTab[anAction^.sym] := targetState
          ELSE
            BEGIN
              CRTable.GetClass(anAction^.sym, class);
              i := 0;
              WHILE i < 256 (*PDT*)  DO BEGIN
                IF Sets.IsIn(class, i) THEN startTab[i] := targetState;
                INC(i)
              END
            END;
        anAction := anAction^.next
      END
    END;

  VAR
    LeftMargin : INTEGER;
    FirstState : BOOLEAN;
    ScannerFrame : STRING;

  BEGIN
    IF dirtyDFA THEN BEGIN MakeDeterministic(ok); END;
    FillStartTab;
    ScannerFrame := Concat(CRS.directory, 'scanner.frm');
    FileIO.Open(fram, ScannerFrame, FALSE);
    IF NOT FileIO.Okay THEN
      BEGIN
        FileIO.SearchFile(fram, 'CRFRAMES', 'scanner.frm', FALSE);
        IF NOT FileIO.Okay THEN
          BEGIN WriteLn; WriteLn('"scanner.frm" not found - aborted.'); HALT END
      END;
    LeftMargin := 0;
    CRTable.GetNode(CRTable.root, gn);
    CRTable.GetSym(gn.p1, sn);
    gramName := Copy(sn.name, 1, 7);
    fGramName := Concat(CRS.directory, gramName);
    (*------- *s.pas -------*)
    fn := Concat(fGramName, 's.pas');
    FileIO.Open(scanner, fn, TRUE);
    CopyFramePart('-->modulename', LeftMargin, fram, scanner);
    PutS(gramName+'S');
    CopyFramePart('-->unitname', LeftMargin, fram, scanner);
    IF CRTable.ddt['N'] OR CRTable.symNames THEN ImportSymConsts('USES ', PutS);
    CopyFramePart('-->unknownsym', LeftMargin, fram, scanner);
    IF CRTable.ddt['N'] OR CRTable.symNames
      THEN PutSN(CRTable.maxT)
      ELSE PutI(CRTable.maxT);
    CopyFramePart('-->comment', LeftMargin, fram, scanner);
    com := firstComment;
    WHILE com <> NIL DO BEGIN
      GenComment(LeftMargin, com);
      com := com^.next;
    END;
    CopyFramePart('-->literals', LeftMargin, fram, scanner);
    GenLiterals(LeftMargin);
    CopyFramePart('-->GetSy1', LeftMargin, fram, scanner);
    NewLine := FALSE;
    IF NOT Sets.IsIn(CRTable.ignored, ORD(cr)) THEN
      BEGIN
        Indent(LeftMargin);
        PutS('IF oldEols > 0 THEN BEGIN DEC(bp);');
        PutS(' DEC(oldEols); ch := CR END;$')
      END;
    Indent(LeftMargin);
    PutS('WHILE (ch = '' '')');
    IF NOT Sets.Empty(CRTable.ignored) THEN
      BEGIN
        PutS(' OR$'); Indent(LeftMargin + 6);
        PutRange(CRTable.ignored, LeftMargin + 6);
      END;
    PutS(' DO NextCh;');
    IF firstComment <> NIL THEN
      BEGIN
        PutLn; PutB(LeftMargin); PutS('IF (');
        com := firstComment;
        WHILE com <> NIL DO BEGIN
          PutChCond(com^.start[1]);
          IF com^.next <> NIL THEN PutS(' OR ');
          com := com^.next
        END;
        PutS(') AND Comment THEN BEGIN Get(sym); EXIT; END;');
      END;
    CopyFramePart('-->GetSy2', LeftMargin, fram, scanner);
    NewLine := FALSE;
    s := rootState + 1;
    FirstState := TRUE;
    WHILE s <= lastState DO BEGIN
      WriteState(LeftMargin, s, FirstState);
      INC(s)
    END;
    PutB(LeftMargin); PutS('  '); PutI2(lastState + 1, 2); PutS(': ');
    PutSE(0); PutS('ch := #0; DEC(bp); EXIT END;');
    CopyFramePart('-->initializations', LeftMargin, fram, scanner);
    IF CRTable.ignoreCase
      THEN PutS('CurrentCh := CapChAt;$')
      ELSE PutS('CurrentCh := CharAt;$');
    PutB(LeftMargin);
    i := 0;
    WHILE i < 64 (*PDT*)  DO BEGIN
      IF i <> 0 THEN BEGIN PutLn; PutB(LeftMargin); END;
      j := 0;
      WHILE j < 4 DO BEGIN
        PutS('start['); PutI2(4 * i + j, 3); PutS('] := ');
        PutI2(startTab[4 * i + j], 2); PutS('; ');
        INC(j);
      END;
      INC(i);
    END;
    CopyFramePart('-->modulename', LeftMargin, fram, scanner);
    PutS(gramName + 'S *)$');
    Close(scanner); Close(fram);
  END;

BEGIN (* CRA *)
  lastState := -1;
  rootState := NewState;
  firstMelted := NIL;
  firstComment := NIL;
  NewLine := TRUE;
  dirtyDFA := FALSE;
END.
