UNIT CRTable;
{ renamed from Modula version CRT to avoid name space problems with CRT unit }
(* CRTable   Table Handler
   =======   =============

  (1) handles a symbol table for terminals, pragmas and nonterminals
  (2) handles a table for character classes (for scanner generation)
  (3) handles a top-down graph for productions
  (4) computes various sets (start symbols, followers, any sets)
  (5) contains procedures for grammar tests

  --------------------------------------------------------------------*) 

INTERFACE

USES Sets;

CONST
(* The following are chosen to ensure that data segments remain within the
   64K limit imposed by Dos 16 bit systems.  Manipulate them at your peril
   if you need to handle large grammars! *)

  maxSymbols   =   400; (* max number of symbols
                           (terminals+nonterminals+pragmas) *)
  maxTerminals =   256; (* max number of terminals *)
  maxNt        =   130; (* max number of nonterminals *)
  maxNodes     =  1500; (* max number of top-down graph nodes *)
  maxClasses   =   250; (* max number of character classes *)
  maxSemLen    = 64000; (* max length of a semantic text *)
  normTrans    =     0; (* DFA transition during normal scanning *)
  contextTrans =     1; (* DFA transition during scanning of right context *)
  maxList      =   150; (* max array size in FindCircularProductions *)
  maxLiterals  =   127; (* max number of literal terminals *)

  (* node types *)
  unknown =  0;
  t     =  1; (* terminal symbol *)
  pr    =  2; (* pragma *)
  nt    =  3; (* nonterminal symbol *)
  class =  4; (* character class *)
  chart =  5; (* single character *)
  wt    =  6; (* weak terminal symbol *)
  any   =  7; (* symbol ANY *)
  eps   =  8; (* empty alternative *)
  sync  =  9; (* symbol SYNC *)
  sem   = 10; (* semantic action *)
  alt   = 11; (* alternative *)
  iter  = 12; (* iteration *)
  opt   = 13; (* option *)

  noSym = -1;
  eofSy =  0;

  (* token kinds *)
  classToken    = 0;  (* token class *)
  litToken      = 1;  (* literal (e.g. keyword) not recognized by DFA *)
  classLitToken = 2;  (* token class that can also match a literal *)
  MaxNameLength = 39; (* max length of token name *)

TYPE
  Name       = STRING [MaxNameLength];
  Position   = RECORD    (* position of stretch of source text *)
    beg:       LONGINT;  (* start relative to beginning of file *)
    len:       LONGINT;  (* length *)
    col:       INTEGER;  (* column number of start position *)
  END;

  SymbolNode = RECORD    (* node of symbol table *)
    typ:       INTEGER;  (* nt, t, pr, unknown *)
    name,                (* symbol name *)
    constant:  Name;     (* named constant of symbol *)
    struct:    INTEGER;  (* typ = nt: index of first node of syntax graph *)
                         (* typ = t: token kind: literal, class, ... *)
    deletable: BOOLEAN;  (* typ = nt: TRUE, if nonterminal is deletable *)
    attrPos:   Position; (* position of attributes in source text *)
    semPos:    Position; (* typ = pr: pos of sem action in source text *)
                         (* typ = nt: pos of local decls in source text *)
    line:      INTEGER;  (* source text line number of symbol in this node *)
  END;

  GraphNode = RECORD     (* node of top-down graph *)
    typ : INTEGER;       (* nt,sts,wts,chart,class,any,eps,sem,sync,alt,
                            iter,opt*)
    next: INTEGER;       (* to successor node *)
                         (* next < 0: to successor of enclosing structure *)
    p1: INTEGER;         (* typ IN {nt, t, wt}: index to symbol table *)
                         (* typ = any: index to anyset *)
                         (* typ = sync: index to syncset *)
                         (* typ = alt:
                                  index of first node of first alternative *)
                         (* typ IN {iter, opt}: first node in subexpression *)
                         (* typ = chart: ordinal character value *)
                         (* typ = class: index of character class *)
    p2: INTEGER;         (* typ = alt:
                                  index of first node of second alternative *)
                         (* typ IN {chart, class}: transition code *)
    pos: Position;       (* typ IN {nt, t, wt}:
                                  source pos of actual attributes *)
                         (* typ = sem: source pos of sem action *)
    line: INTEGER;       (* source text line number of item in this node *)
  END;

{ The next is nasty - we really want different sizes of sets
  CRTSet   = ARRAY [0 .. maxTerminals DIV 16 (*Sets.size*) ] OF BITSET;
}
  CRTSet = Sets.BITARRAY;

{ This means some hacking later on from the original Modula stuff }

  MarkList = ARRAY [0 .. maxNodes DIV Sets.size] OF BITSET;

VAR
  maxT:        INTEGER;  (* terminals stored from 0 .. maxT in symbol table *)
  maxP:        INTEGER;  (* pragmas stored from maxT+1..maxP in symbol table *)
  firstNt:     INTEGER;  (* index of first nt: available after CompSymbolSets *)
  lastNt:      INTEGER;  (* index of last nt: available after CompSymbolSets *)
  maxC:        INTEGER;  (* index of last character class *)
  nNodes:      INTEGER;  (* index of last top-down graph node *)
  root:        INTEGER;  (* index of root node, filled by ATG *)

  useDeclPos,
  semDeclPos:  Position; (* position of global semantic declarations *)
  genScanner:  BOOLEAN;  (* TRUE: a scanner shall be generated *)
  hasUses:     BOOLEAN;  (* TRUE: attribute grammar had USES clause *)
  ignoreCase:  BOOLEAN;  (* TRUE: scanner treats lower case as upper case *)
  symNames:    BOOLEAN;  (* TRUE: symbol names have to be assigned *)
  ignored:     CRTSet;      (* characters ignored by the scanner *)
  ddt:         ARRAY ['A' .. 'Z'] OF BOOLEAN;
                         (* parameter, debug and test switches *)


PROCEDURE NewName (n: Name; s: STRING);
(* Inserts the pair (n, s) in the token symbol name table *)

FUNCTION NewSym (typ: INTEGER; n: Name; line: INTEGER): INTEGER;
(* Generates a new symbol with type t and name n and returns its index *)

PROCEDURE GetSym (sp: INTEGER; VAR sn: SymbolNode);
(* Gets symbol node with index sp in sn. *)

PROCEDURE PutSym (sp: INTEGER; sn: SymbolNode);
(* Replaces symbol node with index sp by sn. *)

FUNCTION FindSym (n: Name): INTEGER;
(* Gets symbol index for identifier with name n. *)

FUNCTION NewSet (s: CRTSet): INTEGER;
(* Stores s as a new set and returns its index. *)

PROCEDURE CompFirstSet (gp: INTEGER; VAR fs: CRTSet);
(* Computes start symbols of graph gp. *)

PROCEDURE CompExpected (gp, sp: INTEGER; VAR exp: CRTSet);
(* Computes all symbols expected at location gp in graph of symbol sp. *)

PROCEDURE CompDeletableSymbols;
(* Marks deletable nonterminals and prints them. *)

PROCEDURE CompSymbolSets;
(* Collects first-sets, follow-sets, any-sets, and sync-sets. *)

PROCEDURE PrintSymbolTable;
(* Prints the symbol table (for tracing). *)

PROCEDURE XRef;
(* Produces a cross reference listing of all symbols. *)

FUNCTION NewClass (n: Name; cset: CRTSet): INTEGER;
(* Defines a new character class and returns its index *)

FUNCTION ClassWithName (n: Name): INTEGER;
(* Searches for a class with the given name.  Returns its index or -1 *)

FUNCTION ClassWithSet (s: CRTSet): INTEGER;
(* Searches for a class with the given set. Returns its index or -1 *)

PROCEDURE GetClass (n: INTEGER; VAR s: CRTSet);
(* Returns character class n *)

PROCEDURE GetClassName (n: INTEGER; VAR name: Name);
(* Returns the name of class n *)

PROCEDURE GetSet (nr: INTEGER; VAR s: CRTSet);
(* Gives access to precomputed symbol sets *)

FUNCTION NewNode (typ, p1, line: INTEGER): INTEGER;
(* Generates a new graph node with typ, p1, and source line number
   line and returns its index. *)

PROCEDURE ClearMarkList (VAR m: MarkList);
(* Clears all elements of m *)

FUNCTION IsInMarkList (VAR s: MarkList; x: INTEGER): BOOLEAN;
(* Returns x IN s *)

PROCEDURE InclMarkList (VAR s : MarkList; x : INTEGER);
(* s.INCL(x) *)

PROCEDURE GetNode (gp: INTEGER; VAR n: GraphNode);
(* Gets graph node with index gp in n. *)

PROCEDURE PutNode (gp: INTEGER; n: GraphNode);
(* Replaces graph node with index gp by n. *)

PROCEDURE ConcatAlt (VAR gL1, gR1: INTEGER; gL2, gR2: INTEGER);
(* Makes (gL2, gR2) an alternative of the graph (gL1, gR1).
   The resulting graph is identified by (gL1, gR1). *)

PROCEDURE ConcatSeq (VAR gL1, gR1: INTEGER; gL2, gR2: INTEGER);
(* Concatenates graph (gL1, gR1) with graph (gL2, gR2) via next-chain.
   The resulting graph is identified by (gL1, gR1). *)

PROCEDURE MakeFirstAlt (VAR gL, gR: INTEGER);
(* Generates an alt-node with (gL, gR) as its first and only alternative *)

PROCEDURE MakeIteration (VAR gL, gR: INTEGER);
(* Encloses the graph (gL, gR) into an iteration construct.
   The resulting graph is identified by (gL, gR). *)

PROCEDURE MakeOption (VAR gL, gR: INTEGER);
(* Encloses the graph (gL, gR) into an option construct.
   The resulting graph is identified by (gL, gR). *)

PROCEDURE CompleteGraph (gp: INTEGER);
(* Lets right ends of graph gp be 0 *)

PROCEDURE StrToGraph (s: STRING; VAR gL, gR: INTEGER);
(* Generates linear graph from characters in s *)

FUNCTION DelGraph (gp: INTEGER): BOOLEAN;
(* TRUE, if (sub) graph with root gp is deletable. *)

FUNCTION DelNode (gn: GraphNode): BOOLEAN;
(* TRUE, if graph node gn is deletable, i.e. can be derived into the
   empty string. *)

PROCEDURE PrintGraph;
(* Prints the graph (for tracing). *)

PROCEDURE FindCircularProductions (VAR ok: BOOLEAN);
(* Finds and prints the circular part of the grammar.
   ok = TRUE means no circular part. *)

PROCEDURE LL1Test (VAR ll1: BOOLEAN);
(* Checks if the grammar satisfies the LL(1) conditions.
   ll1 = TRUE means no LL(1)-conflicts. *)

PROCEDURE TestCompleteness (VAR ok: BOOLEAN);
(* ok = TRUE, if all nonterminals have productions. *)

PROCEDURE TestIfAllNtReached (VAR ok: BOOLEAN);
(* ok = TRUE, if all nonterminals can be reached from the start symbol. *)

PROCEDURE TestIfNtToTerm (VAR ok: BOOLEAN);
(* ok = TRUE, if all nonterminals can be reduced to terminals. *)

PROCEDURE AssignSymNames (default: BOOLEAN; VAR thereExists: BOOLEAN);

PROCEDURE Restriction (n, limit: INTEGER);
(* Signal compiler restriction and abort program *)

IMPLEMENTATION

USES CRS;

CONST
  maxSetNr = 50;      (* max. number of symbol sets *)
  maxNames = 100;     (* max. number of declared token names *)

TYPE
  FirstSets = ARRAY [0 .. maxNt] OF 
    RECORD
      ts : CRTSet;     (* terminal symbols *)
      ready : BOOLEAN; (* TRUE = ts is complete *)
    END;
  FollowSets = ARRAY [0 .. maxNt] OF 
    RECORD
      ts : CRTSet;     (* terminal symbols *)
      nts : CRTSet;    (* nts whose start set is to be included in ts *)
    END;
  CharClass = 
    RECORD
      name : Name;     (* class name *)
      cset : INTEGER   (* ptr to set representing the class *)
    END;
  SymbolTable = ARRAY [0 .. maxSymbols] OF SymbolNode;
  ClassTable = ARRAY [0 .. maxClasses] OF CharClass;
  GraphList = ARRAY [0 .. maxNodes] OF GraphNode;
  SymbolSet = ARRAY [0 .. maxSetNr] OF CRTSet;
  NameTable = ARRAY [1 .. maxNames] OF 
    RECORD
      name, definition : Name
    END;

VAR
  (* moved symbol table to the heap Fri  08-20-1993 to allow larger one *)
  st : ^ SymbolTable;                (* symbol table for terminals,
                                         pragmas, and nonterminals *) 
  gn : ^ GraphList;                  (* top-down graph *)
  tt : NameTable;                    (* table of token name declarations *)
  first : FirstSets;                 (* first[i]  = first symbols of st[i+firstNt] *)
  follow : FollowSets;               (* follow[i] = followers of st[i+firstNt] *)
  chClass : ClassTable;              (* character classes *)
  cset : SymbolSet;                  (* cset[0] = all SYNC symbols *)
  maxSet : INTEGER;                  (* index of last symbol set *)
  lastName, dummyName : INTEGER;     (* for unnamed character classes *)
  ch : CHAR;

PROCEDURE WriteText (VAR f : TEXT; s : STRING; w : INTEGER);
  VAR
    slen, i : INTEGER;
  BEGIN
    slen := Length(s);
    FOR i := 1 TO w DO
      IF i <= slen THEN Write(f, s[i]) ELSE Write(f, ' ');
  END;

(* Restriction          Implementation restriction
----------------------------------------------------------------------*) 

PROCEDURE Restriction (n, limit : INTEGER);
  BEGIN
    WriteLn;
    WriteLn('Restriction ', n:1);
    CASE n OF
      1 : Write(' Too many graph nodes');
      2 : Write(' Too many symbols');
      3 : Write(' Too many sets');
      4 : Write( 'Too many character classes');
      5 : Write( 'Too many symbol sets');
      6 : Write( 'Too many token names');
      7 : Write( 'Too many states');
      8 : Write( 'Semantic text buffer overflow');
      9 : Write( 'Circular check buffer overflow');
     10 : Write( 'Too many literal terminals');
     11 : Write( 'Too many non-terminals');
     -1 : Write( 'Compiler error');
    END;
    IF n > 0 THEN WriteLn(' (limited to ', limit:1, ')');
    (* maybe we want CRX.WriteStatistics; *) 
    HALT
  END;

(* MovePragmas          Move pragmas after terminals
----------------------------------------------------------------------*) 

PROCEDURE MovePragmas;
  VAR
    i : INTEGER;
  BEGIN
    IF maxP > firstNt THEN
      BEGIN
        i := maxSymbols - 1; maxP := maxT;
        WHILE i > lastNt DO BEGIN
          INC(maxP);
          IF maxP >= firstNt THEN Restriction(2, maxSymbols);
          st^[maxP] := st^[i]; DEC(i)
        END;
      END
  END;

(* ClearMarkList        Clear mark list m
----------------------------------------------------------------------*) 

PROCEDURE ClearMarkList (VAR m : MarkList);
  VAR
    i : INTEGER;
  BEGIN
    i := 0;
    WHILE i < maxNodes DIV Sets.size DO BEGIN m[i] := []; INC(i) END;
  END;

FUNCTION IsInMarkList (VAR s : MarkList; x : INTEGER) : BOOLEAN;
  BEGIN
    IsInMarkList := x MOD size IN s[x DIV size]
  END;

PROCEDURE InclMarkList (VAR s : MarkList; x : INTEGER);
  BEGIN
    s[x DIV size] :=  s[x DIV size] + [x MOD size]
  END;

(* GetNode              Get node with index gp in n
----------------------------------------------------------------------*) 

PROCEDURE GetNode (gp : INTEGER; VAR n : GraphNode);
  BEGIN
    n := gn^[gp]
  END;

(* PutNode              Replace node with index gp by n
----------------------------------------------------------------------*) 

PROCEDURE PutNode (gp : INTEGER; n : GraphNode);
  BEGIN
    gn^[gp] := n
  END;

(* NewName              Collects a user defined token name
----------------------------------------------------------------------*) 

PROCEDURE NewName (n : Name; s : STRING);
  BEGIN
    IF lastName = maxNames
      THEN Restriction(6, maxNames)
      ELSE
        BEGIN
          INC(lastName); symNames := TRUE;
          tt[lastName].name := n; tt[lastName].definition := s;
        END;
  END;

(* NewSym               Generate a new symbol and return its index
----------------------------------------------------------------------*) 

FUNCTION NewSym (typ : INTEGER; n : Name; line : INTEGER) : INTEGER;
  VAR
    i : INTEGER;
  BEGIN
    IF maxT + 1 = firstNt
      THEN Restriction(2, maxSymbols)
      ELSE
        BEGIN
          CASE typ OF
            t : BEGIN INC(maxT); i := maxT; END;
            pr : BEGIN DEC(maxP); DEC(firstNt); DEC(lastNt); i := maxP; END;
            nt, unknown : BEGIN DEC(firstNt); i := firstNt; END;
          END;
          IF maxT + 1 >= firstNt THEN Restriction(2, maxSymbols);
          st^[i].typ := typ;      st^[i].name := n;
          st^[i].constant := '';  (* Bug fix - PDT *)
          st^[i].struct := 0;     st^[i].deletable := FALSE;
          st^[i].attrPos.beg := -1; st^[i].semPos.beg := -1;
          st^[i].line := line;
        END;
    NewSym := i;
  END;

(* GetSym               Get symbol sp in sn
----------------------------------------------------------------------*) 

PROCEDURE GetSym (sp : INTEGER; VAR sn : SymbolNode);
  BEGIN
    sn := st^[sp]
  END;

(* PutSym               Replace symbol with index snix by sn
----------------------------------------------------------------------*) 

PROCEDURE PutSym (sp : INTEGER; sn : SymbolNode);
  BEGIN
    st^[sp] := sn
  END;

(* FindSym              Find index of symbol with name n
----------------------------------------------------------------------*) 

FUNCTION FindSym (n : Name) : INTEGER;
  VAR
    i : INTEGER;

  BEGIN
    i := 0;
    (*search in terminal list*) 
    WHILE (i <= maxT) AND (st^[i].name <> n) DO INC(i);
    IF i <= maxT THEN BEGIN FindSym := i; EXIT END;
    i := firstNt;
    (*search in nonterminal/pragma list*) 
    WHILE (i < maxSymbols) AND (st^[i].name <> n) DO INC(i);
    IF i < maxSymbols THEN FindSym := i ELSE FindSym := noSym
  END;

(* PrintSet             Print set s
----------------------------------------------------------------------*) 

PROCEDURE PrintSet (VAR f : TEXT; s : BITARRAY; indent : INTEGER);
  CONST
    maxLineLen = 80;
  VAR
    col, i, len : INTEGER;
    empty : BOOLEAN;
    sn : SymbolNode;
  BEGIN
    i := 0;
    col := indent;
    empty := TRUE;
    WHILE i <= maxT DO BEGIN
      IF Sets.IsIn(s, i) THEN
        BEGIN
          empty := FALSE;
          GetSym(i, sn);
          len := Length(sn.name);
          IF col + len + 2 > maxLineLen THEN
            BEGIN
              WriteLn(f); col := 1;
              WHILE col < indent DO BEGIN Write(f, ' '); INC(col) END
            END;
          Write(f, sn.name, '  ');
          INC(col, len + 2)
        END;
      INC(i)
    END;
    IF empty THEN Write(f, '-- empty set --');
    WriteLn(f)
  END;

(* NewSet               Stores s as a new set and return its index
----------------------------------------------------------------------*) 

FUNCTION NewSet (s : CRTSet) : INTEGER;
(*any-set computation requires not to search if s is already in set*) 
  BEGIN
    INC(maxSet);
    IF maxSet > maxSetNr THEN Restriction(3, maxSetNr);
    cset[maxSet] := s;
    NewSet := maxSet
  END;

(* CompFirstSet         Compute first symbols of (sub) graph at gp
----------------------------------------------------------------------*) 

PROCEDURE CompFirstSet (gp : INTEGER; VAR fs : CRTSet);
  VAR
    visited : MarkList;

  PROCEDURE CompFirst (gp : INTEGER; VAR fs : CRTSet);
    VAR
      s : CRTSet;
      gn : GraphNode;
      sn : SymbolNode;
    BEGIN
      Sets.Clear(fs);
      WHILE (gp <> 0) AND NOT IsInMarkList(visited, gp) DO BEGIN
        GetNode(gp, gn);
        InclMarkList(visited, gp);
        CASE gn.typ OF
          nt : 
            BEGIN
              IF first[gn.p1 - firstNt].ready
                THEN Sets.Unite(fs, first[gn.p1 - firstNt].ts)
                ELSE
                  BEGIN
                    GetSym(gn.p1, sn); CompFirst(sn.struct, s);
                    Sets.Unite(fs, s);
                  END;
            END;
          t, wt : 
            BEGIN Sets.Incl(fs, gn.p1) END;
          any :
            BEGIN Sets.Unite(fs, cset[gn.p1]) END;
          alt, iter, opt : 
            BEGIN
              CompFirst(gn.p1, s);
              Sets.Unite(fs, s);
              IF gn.typ = alt THEN
                BEGIN CompFirst(gn.p2, s); Sets.Unite(fs, s) END
            END;
          ELSE
          (* eps, sem, sync, ind: nothing *) 
        END;
        IF NOT DelNode(gn) THEN EXIT;
        gp := ABS(gn.next)
      END
    END;

  BEGIN (* ComputeFirstSet *)
    ClearMarkList(visited);
    CompFirst(gp, fs);
    IF ddt['I'] THEN
      BEGIN
        WriteLn; WriteLn('ComputeFirstSet: gp = ', gp:1);
        PrintSet(output, fs, 0);
      END;
  END;

(* CompFirstSets        Compute first symbols of nonterminals
----------------------------------------------------------------------*) 

PROCEDURE CompFirstSets;
  VAR
    i : INTEGER;
    sn : SymbolNode;
  BEGIN
    i := firstNt;
    IF lastNt-firstNt > maxNt THEN Restriction(11, maxNt);
    WHILE i <= lastNt DO BEGIN
      first[i - firstNt].ready := FALSE;
      INC(i)
    END;
    i := firstNt;
    WHILE i <= lastNt DO BEGIN (* for all nonterminals *)
      GetSym(i, sn);
      CompFirstSet(sn.struct, first[i - firstNt].ts);
      first[i - firstNt].ready := TRUE;
      INC(i)
    END;
  END;

(* CompExpected     Compute symbols expected at location gp in Symbol sp
----------------------------------------------------------------------*) 

PROCEDURE CompExpected (gp, sp : INTEGER; VAR exp : CRTSet);
  BEGIN
    CompFirstSet(gp, exp);
    IF DelGraph(gp) THEN Sets.Unite(exp, follow[sp - firstNt].ts)
  END;

(* CompFollowSets       Get follow symbols of nonterminals
----------------------------------------------------------------------*) 

PROCEDURE CompFollowSets;
  VAR
    sn : SymbolNode;
    curSy, i, size : INTEGER;
    visited : MarkList;

  PROCEDURE CompFol (gp : INTEGER);
    VAR
      s : CRTSet;
      gn : GraphNode;
    BEGIN
      WHILE (gp > 0) AND NOT IsInMarkList(visited, gp) DO BEGIN
        GetNode(gp, gn); InclMarkList(visited, gp);
        IF gn.typ = nt
          THEN
            BEGIN
              CompFirstSet(ABS(gn.next), s);
              Sets.Unite(follow[gn.p1 - firstNt].ts, s);
              IF DelGraph(ABS(gn.next)) THEN
                Sets.Incl(follow[gn.p1 - firstNt].nts, curSy - firstNt)
            END
          ELSE IF (gn.typ = opt) OR (gn.typ = iter) THEN CompFol(gn.p1)
          ELSE IF gn.typ = alt THEN BEGIN CompFol(gn.p1); CompFol(gn.p2) END;
        gp := gn.next
      END
    END;

  PROCEDURE Complete (i : INTEGER);
    VAR
      j : INTEGER;
    BEGIN
      IF IsInMarkList(visited, i) THEN EXIT;
      InclMarkList(visited, i);
      j := 0;
      WHILE j <= lastNt - firstNt DO BEGIN (* for all nonterminals *)
        IF Sets.IsIn(follow[i].nts, j) THEN
          BEGIN
            Complete(j);
            Sets.Unite(follow[i].ts, follow[j].ts);
            (* fix 1.42 *) IF i = curSy THEN Sets.Excl(follow[i].nts, j)
          END;
        INC(j)
      END;
    END;

  BEGIN (* GetFollowSets *)
    size := (lastNt - firstNt + 2) DIV Sets.size;
    curSy := firstNt;
    WHILE curSy <= lastNt DO BEGIN
      Sets.Clear(follow[curSy - firstNt].ts);
      i := 0;
      WHILE i <= size DO BEGIN
        follow[curSy - firstNt].nts[i] := []; INC(i)
      END;
      INC(curSy)
    END;

    ClearMarkList(visited);
    curSy := firstNt;         (*get direct successors of nonterminals*)
    WHILE curSy <= lastNt DO BEGIN
      GetSym(curSy, sn); CompFol(sn.struct);
      INC(curSy)
    END;

    curSy := 0;               (*add indirect successors to follow.ts*)
    WHILE curSy <= lastNt - firstNt DO BEGIN
      ClearMarkList(visited); Complete(curSy);
      INC(curSy);
    END;
  END;

(* CompAnySets          Compute all any-sets
----------------------------------------------------------------------*) 

PROCEDURE CompAnySets;
  VAR
    curSy : INTEGER;
    sn : SymbolNode;

  FUNCTION LeadingAny (gp : INTEGER; VAR a : GraphNode) : BOOLEAN;
    VAR
      gn : GraphNode;
    BEGIN
      IF gp <= 0 THEN BEGIN LeadingAny := FALSE; EXIT END;
      GetNode(gp, gn);
      IF (gn.typ = any)
        THEN BEGIN a := gn; LeadingAny := TRUE END
        ELSE
          LeadingAny := (gn.typ = alt) AND (LeadingAny(gn.p1, a)
          OR LeadingAny(gn.p2, a)) OR ((gn.typ = opt)
          OR (gn.typ = iter)) AND LeadingAny(gn.p1, a)
          OR DelNode(gn) AND LeadingAny(gn.next, a)
    END;

  PROCEDURE FindAS (gp : INTEGER);
    VAR
      gn, gn2, a : GraphNode;
      s1, s2 : CRTSet;
      p : INTEGER;
    BEGIN
      WHILE gp > 0 DO BEGIN
        GetNode(gp, gn);
        IF (gn.typ = opt) OR (gn.typ = iter)
          THEN
            BEGIN
              FindAS(gn.p1);
              IF LeadingAny(gn.p1, a) THEN
                BEGIN
                  CompExpected(ABS(gn.next), curSy, s1);
                  Sets.Differ(cset[a.p1], s1)
                END
            END
          ELSE IF gn.typ = alt THEN
            BEGIN
              p := gp;
              Sets.Clear(s1);
              WHILE p <> 0 DO BEGIN
                GetNode(p, gn2);
                FindAS(gn2.p1);
                IF LeadingAny(gn2.p1, a)
                  THEN
                    BEGIN
                      CompExpected(gn2.p2, curSy, s2);
                      Sets.Unite(s2, s1);
                      Sets.Differ(cset[a.p1], s2)
                    END
                  ELSE
                    BEGIN
                      CompFirstSet(gn2.p1, s2);
                      Sets.Unite(s1, s2)
                    END;
                p := gn2.p2
              END
            END;
        gp := gn.next
      END
    END;

  BEGIN
    curSy := firstNt;
    WHILE curSy <= lastNt DO BEGIN
    (* for all nonterminals *) 
      GetSym(curSy, sn);
      FindAS(sn.struct);
      INC(curSy)
    END
  END;

(* CompSyncSets         Compute follow symbols of sync-nodes
----------------------------------------------------------------------*) 

PROCEDURE CompSyncSets;
  VAR
    curSy : INTEGER;
    sn : SymbolNode;
    visited : MarkList;

  PROCEDURE CompSync (gp : INTEGER);
    VAR
      s : CRTSet;
      gn : GraphNode;
    BEGIN
      WHILE (gp > 0) AND NOT IsInMarkList(visited, gp) DO BEGIN
        GetNode(gp, gn); InclMarkList(visited, gp);
        IF gn.typ = sync
          THEN
            BEGIN
              CompExpected(ABS(gn.next), curSy, s);
              Sets.Incl(s, eofSy);
              Sets.Unite(cset[0], s);
              gn.p1 := NewSet(s);
              PutNode(gp, gn)
            END
          ELSE IF gn.typ = alt THEN
            BEGIN
              CompSync(gn.p1);
              CompSync(gn.p2)
            END
          ELSE IF (gn.typ = opt) OR (gn.typ = iter) THEN
            BEGIN
              CompSync(gn.p1)
            END;
        gp := gn.next
      END
    END;

  BEGIN
    curSy := firstNt;
    ClearMarkList(visited);
    WHILE curSy <= lastNt DO BEGIN
      GetSym(curSy, sn);
      CompSync(sn.struct);
      INC(curSy);
    END
  END;

(* CompDeletableSymbols Compute all deletable symbols and print them
----------------------------------------------------------------------*) 

PROCEDURE CompDeletableSymbols;
  VAR
    changed, none : BOOLEAN;
    i : INTEGER;
    sn : SymbolNode;
  BEGIN
    REPEAT
      changed := FALSE;
      i := firstNt;
      WHILE i <= lastNt DO BEGIN (*for all nonterminals*)
        GetSym(i, sn);
        IF NOT sn.deletable AND (sn.struct <> 0) AND DelGraph(sn.struct) THEN
          BEGIN
            sn.deletable := TRUE;
            PutSym(i, sn);
            changed := TRUE
          END;
        INC(i)
      END;
    UNTIL NOT changed;
    Write(CRS.lst, 'Deletable symbols:');
    i := firstNt;
    none := TRUE;
    WHILE i <= lastNt DO BEGIN
      GetSym(i, sn);
      IF sn.deletable THEN
        BEGIN
          none := FALSE;
          WriteLn(CRS.lst);
          Write(CRS.lst, '     ', sn.name)
        END;
      INC(i);
    END;
    IF none THEN Write(CRS.lst, '        -- none --');
    WriteLn(CRS.lst);
  END;

(* CompSymbolSets       Get first-sets, follow-sets, and sync-set
----------------------------------------------------------------------*) 

PROCEDURE CompSymbolSets;
  VAR
    i : INTEGER;
    sn : SymbolNode;
  BEGIN
    MovePragmas;
    CompDeletableSymbols;
    CompFirstSets;
    CompFollowSets;
    CompAnySets;
    CompSyncSets;
    IF ddt['F'] THEN
      BEGIN
        i := firstNt;
        WriteLn(CRS.lst, 'List of first & follow symbols:');
        WriteLn(CRS.lst);
        WHILE i <= lastNt DO BEGIN (* for all nonterminals *)
          GetSym(i, sn);
          WriteLn(CRS.lst, sn.name);
          Write(CRS.lst, 'first:   ');
          PrintSet(CRS.lst, first[i - firstNt].ts, 10);
          Write(CRS.lst, 'follow:  ');
          PrintSet(CRS.lst, follow[i - firstNt].ts, 10);
          WriteLn(CRS.lst);
          INC(i);
        END;
        i := 0;
        WriteLn(CRS.lst);
        WriteLn(CRS.lst);
        Write(CRS.lst, 'List of sets (ANY, SYNC): ');
        IF maxSet < 0
          THEN Write(CRS.lst, '        -- none --')
          ELSE WriteLn(CRS.lst);
        WHILE i <= maxSet DO BEGIN
          Write(CRS.lst, '     set[', i:2, '] = ');
          PrintSet(CRS.lst, cset[i], 16);
          INC(i)
        END;
        WriteLn(CRS.lst);
      END;
  END;

(* GetFirstSet          Get precomputed first-set for nonterminal sp
----------------------------------------------------------------------*) 

PROCEDURE GetFirstSet (sp : INTEGER; VAR s : CRTSet);
  BEGIN
    s := first[sp - firstNt].ts
  END;

(* GetFollowSet         Get precomputed follow-set for nonterminal snix
----------------------------------------------------------------------*) 

PROCEDURE GetFollowSet (sp : INTEGER; VAR s : CRTSet);
  BEGIN
    s := follow[sp - firstNt].ts
  END;

(* GetSet               Get set with index nr
----------------------------------------------------------------------*) 

PROCEDURE GetSet (nr : INTEGER; VAR s : CRTSet);
  BEGIN
    s := cset[nr]
  END;

(* PrintSymbolTable     Print symbol table
----------------------------------------------------------------------*) 

PROCEDURE PrintSymbolTable;
  VAR
    i : INTEGER;

  PROCEDURE WriteBool (b : BOOLEAN);
    BEGIN
      IF b
        THEN Write(CRS.lst, '  TRUE ')
        ELSE Write(CRS.lst, '  FALSE');
    END;

  PROCEDURE WriteTyp1 (typ : INTEGER);
    BEGIN
      CASE typ OF
        unknown : Write(CRS.lst, ' unknown');
        t :       Write(CRS.lst, ' t      ');
        pr :      Write(CRS.lst, ' pr     ');
        nt :      Write(CRS.lst, ' nt     ');
      END;
    END;

  BEGIN (* PrintSymbolTable *)
    WriteLn(CRS.lst, 'SymbolTable:');
    WriteLn(CRS.lst);
    Write(CRS.lst, 'nr    definition                ');
    IF (*CRTable.*) ddt['N'] OR (*CRTable.*) symNames THEN
      Write(CRS.lst, 'constant        ');
    WriteLn(CRS.lst, 'typ    hasAttrs struct del  line');
    WriteLn(CRS.lst);
    i := 0;
    WHILE i < maxSymbols DO BEGIN
      Write(CRS.lst, i:3);
      Write(CRS.lst, ' ':3);
      WriteText(CRS.lst, st^[i].name, 26);
      IF (*CRTable.*) ddt['N'] OR (*CRTable.*) symNames THEN
        IF i <= maxT
          THEN WriteText(CRS.lst, st^[i].constant, 16)
          ELSE Write(CRS.lst, ' ':16);
      WriteTyp1(st^[i].typ);
      WriteBool(st^[i].attrPos.beg >= 0);
      Write(CRS.lst, st^[i].struct:5);
      WriteBool(st^[i].deletable);
      WriteLn(CRS.lst, st^[i].line:5);
      IF i = maxT THEN i := firstNt ELSE INC(i);
    END;
    WriteLn(CRS.lst);
    WriteLn(CRS.lst);
  END;

(* NewClass             Define a new character class
----------------------------------------------------------------------*) 

FUNCTION NewClass (n : Name; cset : CRTSet) : INTEGER;
  BEGIN
    INC(maxC);
    IF maxC > maxClasses THEN Restriction(4, maxClasses);
    IF n[1] = '#' THEN
      BEGIN
        n[2] := CHR(ORD('A') + dummyName);
        INC(dummyName)
      END;
    chClass[maxC].name := n; chClass[maxC].cset := NewSet(cset);
    NewClass := maxC
  END;

(* ClassWithName        Return index of class with name n
----------------------------------------------------------------------*) 

FUNCTION ClassWithName (n : Name) : INTEGER;
  VAR
    i : INTEGER;
  BEGIN
    i := maxC;
    WHILE (i >= 0) AND (chClass[i].name <> n) DO DEC(i);
    ClassWithName := i
  END;

(* ClassWithSet        Return index of class with the specified set
----------------------------------------------------------------------*) 

FUNCTION ClassWithSet (s : CRTSet) : INTEGER;
  VAR
    i : INTEGER;
  BEGIN
    i := maxC;
    WHILE (i >= 0) AND NOT Sets.Equal(cset[chClass[i].cset], s) DO DEC(i);
    ClassWithSet := i
  END;

(* GetClass             Return character class n
----------------------------------------------------------------------*) 

PROCEDURE GetClass (n : INTEGER; VAR s : CRTSet);
  BEGIN
    GetSet(chClass[n].cset, s);
  END;

(* GetClassName         Get the name of class n
----------------------------------------------------------------------*) 

PROCEDURE GetClassName (n : INTEGER; VAR name : Name);
  BEGIN
    name := chClass[n].name
  END;

(* XRef                 Produce a cross reference listing of all symbols
----------------------------------------------------------------------*) 

PROCEDURE XRef;
  CONST
    maxLineLen = 80;
  TYPE
    ListPtr = ^ ListNode;
    ListNode = 
      RECORD
        next : ListPtr;
        line : INTEGER;
      END;
    ListHdr = 
      RECORD
        name : Name;
        lptr : ListPtr;
      END;
  VAR
    gn : GraphNode;
    col, i : INTEGER;
    l, p, q : ListPtr;
    sn : SymbolNode;
    xList : ARRAY [0 .. maxSymbols] OF ListHdr;
  BEGIN (* XRef *)
    IF maxT <= 0 THEN EXIT;
    MovePragmas;
    (* initialize cross reference list *);
    i := 0;
    WHILE i <= lastNt DO BEGIN (* for all symbols *)
      GetSym(i, sn);
      xList[i].name := sn.name; xList[i].lptr := NIL;
      IF i = maxP THEN i := firstNt ELSE INC(i)
    END;
    (* search lines where symbol has been referenced *) 
    i := 1;
    WHILE i <= nNodes DO BEGIN (* for all graph nodes *)
      GetNode(i, gn);
      IF (gn.typ = t) OR (gn.typ = wt) OR (gn.typ = nt) THEN
        BEGIN
          NEW(l);
          l^.next := xList[gn.p1].lptr; l^.line := gn.line;
          xList[gn.p1].lptr := l
        END;
      INC(i);
    END;
    (* search lines where symbol has been defined and insert in order *) 
    i := 1;
    WHILE i <= lastNt DO BEGIN (*for all symbols*)
      GetSym(i, sn);
      p := xList[i].lptr;
      q := NIL;
      WHILE (p <> NIL) AND (p^.line > sn.line) DO BEGIN
        q := p; p := p^.next
      END;
      NEW(l);
      l^.next := p; l^.line :=  -sn.line;
      IF q <> NIL THEN q^.next := l ELSE xList[i].lptr := l;
      IF i = maxP THEN i := firstNt ELSE INC(i)
    END;
    (* print cross reference listing *) 
    Write(CRS.lst, 'Cross reference list:');
    WriteLn(CRS.lst);
    WriteLn(CRS.lst);
    Write(CRS.lst, 'Terminals:');
    WriteLn(CRS.lst);
    Write(CRS.lst, '  0  EOF');
    WriteLn(CRS.lst);
    i := 1;
    WHILE i <= lastNt DO BEGIN (* for all symbols *)
      IF i = maxT
        THEN
          BEGIN WriteLn(CRS.lst); WriteLn(CRS.lst, 'Pragmas:'); END
        ELSE
          BEGIN
            Write(CRS.lst, i:3, '  ');
            WriteText(CRS.lst, xList[i].name, 25);
            l := xList[i].lptr;
            col := 35;
            WHILE l <> NIL DO BEGIN
              IF col + 5 > maxLineLen THEN
                BEGIN WriteLn(CRS.lst); Write(CRS.lst, ' ':30); col := 35 END;
              IF l^.line = 0
                THEN Write(CRS.lst, 'undef')
                ELSE Write(CRS.lst, l^.line: 5);
              INC(col, 5);
              l := l^.next
            END;
            WriteLn(CRS.lst);
          END;
      IF i = maxP
        THEN
          BEGIN
            WriteLn(CRS.lst); WriteLn(CRS.lst, 'Nonterminals:'); i := firstNt
          END
        ELSE INC(i)
    END;
    WriteLn(CRS.lst);
    WriteLn(CRS.lst);
  END;

(* NewNode              Generate a new graph node and return its index gp
----------------------------------------------------------------------*) 

FUNCTION NewNode (typ, p1, line : INTEGER) : INTEGER;
  BEGIN
    INC(nNodes);
    IF nNodes > maxNodes THEN Restriction(1, maxNodes);
    gn^[nNodes].typ := typ; gn^[nNodes].next := 0;
    gn^[nNodes].p1 := p1;   gn^[nNodes].p2 := 0;
    gn^[nNodes].pos.beg :=  -1;
    gn^[nNodes].pos.len := 0; gn^[nNodes].pos.col := 0;
    gn^[nNodes].line := line;
    NewNode := nNodes;
  END;

(* CompleteGraph        Set right ends of graph gp to 0
----------------------------------------------------------------------*) 

PROCEDURE CompleteGraph (gp : INTEGER);
  VAR
    p : INTEGER;
  BEGIN
    WHILE gp <> 0 DO BEGIN
      p := gn^[gp].next; gn^[gp].next := 0; gp := p
    END
  END;

(* ConcatAlt            Make (gL2, gR2) an alternative of (gL1, gR1)
----------------------------------------------------------------------*) 

PROCEDURE ConcatAlt (VAR gL1, gR1 : INTEGER; gL2, gR2 : INTEGER);
  VAR
    p : INTEGER;
  BEGIN
    gL2 := NewNode(alt, gL2, 0);
    p := gL1; WHILE gn^[p].p2 <> 0 DO p := gn^[p].p2; gn^[p].p2 := gL2;
    p := gR1; WHILE gn^[p].next <> 0 DO p := gn^[p].next; gn^[p].next := gR2
  END;

(* ConcatSeq            Make (gL2, gR2) a successor of (gL1, gR1)
----------------------------------------------------------------------*) 

PROCEDURE ConcatSeq (VAR gL1, gR1 : INTEGER; gL2, gR2 : INTEGER);
  VAR
    p, q : INTEGER;
  BEGIN
    p := gn^[gR1].next; gn^[gR1].next := gL2; (*head node*)
    WHILE p <> 0 DO BEGIN (*substructure*)
      q := gn^[p].next; gn^[p].next :=  - gL2; p := q
    END;
    gR1 := gR2
  END;

(* MakeFirstAlt         Generate alt-node with (gL,gR) as only alternative
----------------------------------------------------------------------*) 

PROCEDURE MakeFirstAlt (VAR gL, gR : INTEGER);
  BEGIN
    gL := NewNode(alt, gL, 0); gn^[gL].next := gR; gR := gL
  END;

(* MakeIteration        Enclose (gL, gR) into iteration node
----------------------------------------------------------------------*) 

PROCEDURE MakeIteration (VAR gL, gR : INTEGER);
  VAR
    p, q : INTEGER;
  BEGIN
    gL := NewNode(iter, gL, 0); p := gR; gR := gL;
    WHILE p <> 0 DO BEGIN
      q := gn^[p].next; gn^[p].next :=  - gL; p := q
    END
  END;

(* MakeOption           Enclose (gL, gR) into option node
----------------------------------------------------------------------*) 

PROCEDURE MakeOption (VAR gL, gR : INTEGER);
  BEGIN
    gL := NewNode(opt, gL, 0); gn^[gL].next := gR; gR := gL
  END;

(* StrToGraph           Generate node chain from characters in s
----------------------------------------------------------------------*) 

PROCEDURE StrToGraph (s : STRING; VAR gL, gR : INTEGER);
  VAR
    i, len : INTEGER;
  BEGIN
    gR := 0; i := 2; len := Length(s); (*strip quotes*)
    WHILE i < len DO BEGIN
      gn^[gR].next := NewNode(chart, ORD(s[i]), 0); gR := gn^[gR].next;
      INC(i)
    END;
    gL := gn^[0].next; gn^[0].next := 0
  END;

(* DelGraph             Check if graph starting with index gp is deletable
----------------------------------------------------------------------*) 

FUNCTION DelGraph (gp : INTEGER) : BOOLEAN;
  VAR
    gn : GraphNode;
  BEGIN
    IF gp = 0 THEN BEGIN DelGraph := TRUE; EXIT END; (*end of graph found*)
    GetNode(gp, gn);
    DelGraph := DelNode(gn) AND DelGraph(ABS(gn.next));
  END;

(* DelNode              Check if graph node gn is deletable
----------------------------------------------------------------------*) 

FUNCTION DelNode (gn : GraphNode) : BOOLEAN;
  VAR
    sn : SymbolNode;

  FUNCTION DelAlt (gp : INTEGER) : BOOLEAN;
    VAR
      gn : GraphNode;
    BEGIN
      IF gp <= 0 THEN BEGIN DelAlt := TRUE; EXIT END; (*end of graph found*)
      GetNode(gp, gn);
      DelAlt := DelNode(gn) AND DelAlt(gn.next);
    END;

  BEGIN
    IF gn.typ = nt
      THEN
        BEGIN GetSym(gn.p1, sn); DelNode := sn.deletable END
      ELSE IF gn.typ = alt THEN
        DelNode := DelAlt(gn.p1) OR (gn.p2 <> 0) AND DelAlt(gn.p2)
      ELSE
        DelNode := (gn.typ = eps) OR (gn.typ = iter) OR (gn.typ = opt) OR (gn.typ = sem) OR (gn.typ = sync)
  END;

(* PrintGraph           Print the graph
----------------------------------------------------------------------*) 

PROCEDURE PrintGraph;
  VAR
    i : INTEGER;

  PROCEDURE WriteTyp2 (typ : INTEGER);
    BEGIN
      CASE typ OF
        nt   : Write(CRS.lst, 'nt  ');
        t    : Write(CRS.lst, 't   ');
        wt   : Write(CRS.lst, 'wt  ');
        any  : Write(CRS.lst, 'any ');
        eps  : Write(CRS.lst, 'eps ');
        sem  : Write(CRS.lst, 'sem ');
        sync : Write(CRS.lst, 'sync');
        alt  : Write(CRS.lst, 'alt ');
        iter : Write(CRS.lst, 'iter');
        opt  : Write(CRS.lst, 'opt ');
        ELSE Write(CRS.lst, '--- ')
      END;
    END;

  BEGIN (* PrintGraph *)
    WriteLn(CRS.lst, 'GraphList:');
    WriteLn(CRS.lst);
    Write(CRS.lst, ' nr   typ    next     p1     p2   line');
    (* useful for debugging - PDT *) 
    Write(CRS.lst, ' posbeg poslen poscol');
    (* *) 
    WriteLn(CRS.lst);
    WriteLn(CRS.lst);
    i := 0;
    WHILE i <= nNodes DO BEGIN
      Write(CRS.lst, i:3);
      Write(CRS.lst, '   ');
      WriteTyp2(gn^[i].typ);
      Write(CRS.lst, gn^[i].next:7);
      Write(CRS.lst, gn^[i].p1:7);
      Write(CRS.lst, gn^[i].p2:7);
      Write(CRS.lst, gn^[i].line:7);
      (* useful for debugging - PDT *) 
      Write(CRS.lst, gn^[i].pos.beg:7);
      Write(CRS.lst, gn^[i].pos.len:7);
      Write(CRS.lst, gn^[i].pos.col:7);
      (*  *) 
      WriteLn(CRS.lst);
      INC(i);
    END;
    WriteLn(CRS.lst);
    WriteLn(CRS.lst);
  END;

(* FindCircularProductions      Test grammar for circular derivations
----------------------------------------------------------------------*) 

PROCEDURE FindCircularProductions (VAR ok : BOOLEAN);
  TYPE
    ListEntry = 
      RECORD
        left : INTEGER;
        right : INTEGER;
        deleted : BOOLEAN;
      END;
  VAR
    changed, onLeftSide, onRightSide : BOOLEAN;
    i, j, listLength : INTEGER;
    list : ARRAY [0 .. maxList] OF ListEntry;
    singles : MarkList;
    sn : SymbolNode;

  PROCEDURE GetSingles (gp : INTEGER; VAR singles : MarkList);
    VAR
      gn : GraphNode;
    BEGIN
      IF gp <= 0 THEN EXIT;
      (* end of graph found *) 
      GetNode(gp, gn);
      IF gn.typ = nt
        THEN
          IF DelGraph(ABS(gn.next)) THEN InclMarkList(singles, gn.p1)
        ELSE IF (gn.typ = alt) OR (gn.typ = iter) OR (gn.typ = opt) THEN
          IF DelGraph(ABS(gn.next)) THEN
            BEGIN
              GetSingles(gn.p1, singles);
              IF gn.typ = alt THEN GetSingles(gn.p2, singles)
            END;
      IF DelNode(gn) THEN GetSingles(gn.next, singles)
    END;

  BEGIN (* FindCircularProductions *)
    i := firstNt;
    listLength := 0;
    WHILE i <= lastNt DO BEGIN (* for all nonterminals i *)
      ClearMarkList(singles);
      GetSym(i, sn);
      GetSingles(sn.struct, singles);
      (* get nt's j such that i-->j *) 
      j := firstNt;
      WHILE j <= lastNt DO BEGIN (* for all nonterminals j *)
        IF IsInMarkList(singles, j) THEN
          BEGIN
            list[listLength].left := i;
            list[listLength].right := j;
            list[listLength].deleted := FALSE;
            INC(listLength);
            IF listLength > maxList THEN Restriction(9, listLength)
          END;
        INC(j)
      END;
      INC(i)
    END;
    REPEAT
      i := 0;
      changed := FALSE;
      WHILE i < listLength DO BEGIN
        IF NOT list[i].deleted THEN
          BEGIN
            j := 0;
            onLeftSide := FALSE;
            onRightSide := FALSE;
            WHILE j < listLength DO BEGIN
              IF NOT list[j].deleted THEN
                BEGIN
                  IF list[i].left = list[j].right THEN onRightSide := TRUE;
                  IF list[j].left = list[i].right THEN onLeftSide := TRUE
                END;
              INC(j)
            END;
            IF NOT onRightSide OR NOT onLeftSide THEN
              BEGIN list[i].deleted := TRUE; changed := TRUE END
          END;
        INC(i)
      END
    UNTIL NOT changed;
    Write(CRS.lst, 'Circular derivations:    ');
    i := 0;
    ok := TRUE;
    WHILE i < listLength DO BEGIN
      IF NOT list[i].deleted THEN
        BEGIN
          ok := FALSE;
          WriteLn(CRS.lst);
          Write(CRS.lst, '     ');
          GetSym(list[i].left, sn);
          Write(CRS.lst, sn.name:20, ' --> ');
          GetSym(list[i].right, sn);
          Write(CRS.lst, sn.name:20);
        END;
      INC(i)
    END;
    IF ok THEN Write(CRS.lst, ' -- none --');
    WriteLn(CRS.lst);
  END;

(* LL1Test              Collect terminal sets and checks LL(1) conditions
----------------------------------------------------------------------*) 

PROCEDURE LL1Test (VAR ll1 : BOOLEAN);
  VAR
    sn : SymbolNode;
    curSy : INTEGER;

  PROCEDURE LL1Error (cond, ts : INTEGER);
    VAR
      sn : SymbolNode;
    BEGIN
      ll1 := FALSE;
      WriteLn(CRS.lst);
      Write(CRS.lst, ' LL(1) error in ');
      GetSym(curSy, sn);
      Write(CRS.lst, sn.name, ': ');
      IF ts > 0 THEN
        BEGIN
          GetSym(ts, sn);
          Write(CRS.lst, sn.name, ' is ');
        END;
      CASE cond OF
        1 : Write(CRS.lst, 'the start of several alternatives.');
        2 : Write(CRS.lst, 'the start & successor of a deletable structure');
        3 : Write(CRS.lst, 'an ANY node that matches no symbol');
      END;
    END;

  PROCEDURE Check (cond : INTEGER; VAR s1, s2 : CRTSet);
    VAR
      i : INTEGER;
    BEGIN
      i := 0;
      WHILE i <= maxT DO BEGIN
        IF Sets.IsIn(s1, i) AND Sets.IsIn(s2, i) THEN LL1Error(cond, i);
        INC(i)
      END
    END;

  PROCEDURE CheckAlternatives (gp : INTEGER);
    VAR
      gn, gn1 : GraphNode;
      s1, s2 : CRTSet;
      p : INTEGER;
    BEGIN
      WHILE gp > 0 DO BEGIN
        GetNode(gp, gn);
        IF gn.typ = alt
          THEN
            BEGIN
              p := gp;
              Sets.Clear(s1);
              WHILE p <> 0 DO BEGIN (*for all alternatives*)
                GetNode(p, gn1);
                CompExpected(gn1.p1, curSy, s2);
                Check(1, s1, s2);
                Sets.Unite(s1, s2);
                CheckAlternatives(gn1.p1);
                p := gn1.p2
              END
            END
          ELSE IF (gn.typ = opt) OR (gn.typ = iter) THEN
            BEGIN
              CompExpected(gn.p1, curSy, s1);
              CompExpected(ABS(gn.next), curSy, s2);
              Check(2, s1, s2);
              CheckAlternatives(gn.p1)
            END
          ELSE IF gn.typ = any THEN
            BEGIN
              GetSet(gn.p1, s1);
              IF Sets.Empty(s1) THEN LL1Error(3, 0)
            END
            (*e.g. {ANY} ANY or [ANY] ANY*) ;
        gp := gn.next
      END
    END;

  BEGIN (* LL1Test *)
    Write(CRS.lst, 'LL(1) conditions:');
    curSy := firstNt;
    ll1 := TRUE;
    WHILE curSy <= lastNt DO BEGIN (*for all nonterminals*)
      GetSym(curSy, sn);
      CheckAlternatives(sn.struct);
      INC(curSy)
    END;
    IF ll1 THEN Write(CRS.lst, '         --  ok  --');
    WriteLn(CRS.lst);
  END;

(* TestCompleteness     Test if all nonterminals have productions
----------------------------------------------------------------------*) 

PROCEDURE TestCompleteness (VAR ok : BOOLEAN);
  VAR
    sp : INTEGER;
    sn : SymbolNode;
  BEGIN
    Write(CRS.lst, 'Undefined nonterminals:  ');
    sp := firstNt; ok := TRUE;
    WHILE sp <= lastNt DO BEGIN (*for all nonterminals*)
      GetSym(sp, sn);
      IF sn.struct = 0 THEN
        BEGIN
          ok := FALSE;
          WriteLn(CRS.lst); Write(CRS.lst, '     ', sn.name);
        END;
      INC(sp)
    END;
    IF ok THEN Write(CRS.lst, ' -- none --');
    WriteLn(CRS.lst);
  END;

(* TestIfAllNtReached   Test if all nonterminals can be reached
----------------------------------------------------------------------*) 

PROCEDURE TestIfAllNtReached (VAR ok : BOOLEAN);
  VAR
    gn : GraphNode;
    sp : INTEGER;
    reached : MarkList;
    sn : SymbolNode;

  PROCEDURE MarkReachedNts (gp : INTEGER);
    VAR
      gn : GraphNode;
      sn : SymbolNode;
    BEGIN
      WHILE gp > 0 DO BEGIN
        GetNode(gp, gn);
        IF gn.typ = nt
          THEN
            BEGIN
              IF NOT IsInMarkList(reached, gn.p1) THEN (*new nt reached*)
                BEGIN
                  InclMarkList(reached, gn.p1);
                  GetSym(gn.p1, sn);
                  MarkReachedNts(sn.struct)
                END
            END
          ELSE IF (gn.typ = alt) OR (gn.typ = iter) OR (gn.typ = opt) THEN
            BEGIN
              MarkReachedNts(gn.p1);
              IF gn.typ = alt THEN MarkReachedNts(gn.p2)
            END;
        gp := gn.next
      END
    END;

  BEGIN (* TestIfAllNtReached *)
    ClearMarkList(reached);
    GetNode(root, gn); InclMarkList(reached, gn.p1);
    GetSym(gn.p1, sn); MarkReachedNts(sn.struct);
    Write(CRS.lst, 'Unreachable nonterminals:');
    sp := firstNt; ok := TRUE;
    WHILE sp <= lastNt DO BEGIN (*for all nonterminals*)
      IF NOT IsInMarkList(reached, sp) THEN
        BEGIN
          ok := FALSE; GetSym(sp, sn);
          WriteLn(CRS.lst); Write(CRS.lst, '     ', sn.name)
        END;
      INC(sp)
    END;
    IF ok THEN Write(CRS.lst, ' -- none --');
    WriteLn(CRS.lst);
  END;

(* TestIfNtToTerm   Test if all nonterminals can be derived to terminals
----------------------------------------------------------------------*) 

PROCEDURE TestIfNtToTerm (VAR ok : BOOLEAN);
  VAR
    changed : BOOLEAN;
    sp : INTEGER;
    sn : SymbolNode;
    termList : MarkList;

  FUNCTION IsTerm (gp : INTEGER) : BOOLEAN;
    VAR
      gn : GraphNode;
    BEGIN
      WHILE gp > 0 DO BEGIN
        GetNode(gp, gn);
        IF (gn.typ = nt) AND NOT IsInMarkList(termList, gn.p1)
          OR (gn.typ = alt) AND NOT IsTerm(gn.p1)
             AND ((gn.p2 = 0) OR NOT IsTerm(gn.p2))
          THEN BEGIN IsTerm := FALSE; EXIT END;
        gp := gn.next
      END;
      IsTerm := TRUE
    END;

  BEGIN (* TestIfNtToTerm *)
    ClearMarkList(termList);
    REPEAT
      sp := firstNt;
      changed := FALSE;
      WHILE sp <= lastNt DO BEGIN
        IF NOT IsInMarkList(termList, sp) THEN
          BEGIN
            GetSym(sp, sn);
            IF IsTerm(sn.struct) THEN
              BEGIN InclMarkList(termList, sp); changed := TRUE END
          END;
        INC(sp)
      END
    UNTIL NOT changed;
    Write(CRS.lst, 'Underivable nonterminals:');
    sp := firstNt; ok := TRUE;
    WHILE sp <= lastNt DO BEGIN
      IF NOT IsInMarkList(termList, sp) THEN
        BEGIN
          ok := FALSE; GetSym(sp, sn);
          WriteLn(CRS.lst); Write(CRS.lst, '     ', sn.name);
        END;
      INC(sp)
    END;
    IF ok THEN Write(CRS.lst, ' -- none --');
    WriteLn(CRS.lst);
  END;

(* ASCIIName            Assigns the wellknown ASCII-Name in lowercase
----------------------------------------------------------------------*) 

PROCEDURE ASCIIName (ascii : CHAR; VAR asciiname : Name);
  VAR
    N : INTEGER;
  BEGIN
    CASE ascii OF
      #00 : asciiname := '_nul';
      #01 : asciiname := '_soh';
      #02 : asciiname := '_stx';
      #03 : asciiname := '_etx';
      #04 : asciiname := '_eot';
      #05 : asciiname := '_enq';
      #06 : asciiname := '_ack';
      #07 : asciiname := '_bel';
      #08 : asciiname := '_bs';
      #09 : asciiname := '_ht';
      #10 : asciiname := '_lf';
      #11 : asciiname := '_vt';
      #12 : asciiname := '_ff';
      #13 : asciiname := '_cr';
      #14 : asciiname := '_so';
      #15 : asciiname := '_si';
      #16 : asciiname := '_dle';
      #17 : asciiname := '_dc1';
      #18 : asciiname := '_dc2';
      #19 : asciiname := '_dc3';
      #20 : asciiname := '_dc4';
      #21 : asciiname := '_nak';
      #22 : asciiname := '_syn';
      #23 : asciiname := '_etb';
      #24 : asciiname := '_can';
      #25 : asciiname := '_em';
      #26 : asciiname := '_sub';
      #27 : asciiname := '_esc';
      #28 : asciiname := '_fs';
      #29 : asciiname := '_gs';
      #30 : asciiname := '_rs';
      #31 : asciiname := '_us';
      ' ' : asciiname := '_sp';
      '!' : asciiname := '_bang';
      '"' : asciiname := '_dquote';
      '#' : asciiname := '_hash';
      '$' : asciiname := '_dollar';
      '%' : asciiname := '_percent';
      '&' : asciiname := '_and';
      '''' : asciiname := '_squote';
      '(' : asciiname := '_lparen';
      ')' : asciiname := '_rparen';
      '*' : asciiname := '_star';
      '+' : asciiname := '_plus';
      ',' : asciiname := '_comma';
      '-' : asciiname := '_minus';
      '.' : asciiname := '_point';
      '/' : asciiname := '_slash';
      '0' : asciiname := '_zero';
      '1' : asciiname := '_one';
      '2' : asciiname := '_two';
      '3' : asciiname := '_three';
      '4' : asciiname := '_four';
      '5' : asciiname := '_five';
      '6' : asciiname := '_six';
      '7' : asciiname := '_seven';
      '8' : asciiname := '_eight';
      '9' : asciiname := '_nine';
      ':' : asciiname := '_colon';
      ';' : asciiname := '_semicolon';
      '<' : asciiname := '_less';
      '=' : asciiname := '_equal';
      '>' : asciiname := '_greater';
      '?' : asciiname := '_query';
      '@' : asciiname := '_at';
      'A' .. 'Z', 'a' .. 'z' : BEGIN asciiname := '_ '; asciiname[2] := ascii END;
      '[' : asciiname := '_lbrack';
      '\' : asciiname := '_backslash';
      ']' : asciiname := '_rbrack';
      '^' : asciiname := '_uparrow';
      '_' : asciiname := '_underscore';
      '`' : asciiname := '_accent';
      '{' : asciiname := '_lbrace';
      '|' : asciiname := '_bar';
      '}' : asciiname := '_rbrace';
      '~' : asciiname := '_tilde';
      #127 : asciiname := '_delete';
      ELSE BEGIN
             N := ORD(ascii);
             asciiname := 'ascii  ';
             asciiname[7] := CHR(N MOD 10 + ORD('0'));
             N := N DIV 10;
             asciiname[6] := CHR(N MOD 10 + ORD('0'));
             asciiname[5] := CHR(N DIV 10 + ORD('0'));
           END
    END;
  END;

(* BuildName            Build new Name to represent old string
----------------------------------------------------------------------*) 

PROCEDURE BuildName (VAR oldName, newName : Name);
  VAR
    ForLoop, I : INTEGER;
    TargetIndex : INTEGER;
    ascName : Name;
  BEGIN
    TargetIndex := 1;
    FOR ForLoop := 2 TO Length(oldName) -1 DO BEGIN
      CASE oldName[ForLoop] OF
        'A' .. 'Z', 'a' .. 'z' :
          BEGIN
            IF TargetIndex <= 255 THEN
              BEGIN newName[TargetIndex] := oldName[ForLoop]; INC(TargetIndex); END;
          END;
        ELSE
          BEGIN
            ASCIIName(oldName[ForLoop], ascName);
            FOR I := 1 TO Length(ascName) DO
              IF TargetIndex <= MaxNameLength - 3 THEN
                BEGIN newName[TargetIndex] := ascName[I]; INC(TargetIndex) END;
          END;
      END;
    END;
    newName[0] := CHR(TargetIndex-1);
  END;

(* SymName              Generates a new name for a symbol constant
----------------------------------------------------------------------*) 

PROCEDURE SymName (symn : Name; VAR conn : Name);
  BEGIN
    IF (symn[1] = '''') OR (symn[1] = '"')
      THEN IF Length(symn) = 3 THEN ASCIIName(symn[2], conn) ELSE BuildName(symn, conn)
      ELSE conn := symn;
    conn := Concat(conn, 'Sym');
  END;

(* AssignSymNames     Assigns the user defined or generated token names
----------------------------------------------------------------------*) 

PROCEDURE AssignSymNames (default : BOOLEAN; VAR thereExists : BOOLEAN);

  PROCEDURE AssignDef (VAR n (*is not modified*), constant : Name);
    VAR
      ForLoop : INTEGER;
    BEGIN
      FOR ForLoop := 1 TO lastName DO
        IF n = tt[ForLoop].definition THEN
          BEGIN
            constant := tt[ForLoop].name; thereExists := TRUE; EXIT;
          END;
      IF default THEN SymName(n, constant) ELSE constant := ''
    END;

  VAR
    ForLoop : INTEGER;
  BEGIN
    thereExists := default;
    st^[0].constant := 'EOFSYMB';
    FOR ForLoop := 1 TO maxP DO
      AssignDef(st^[ForLoop].name, st^[ForLoop].constant);
    st^[maxT].constant := 'NO_SYMB';
  END;

BEGIN (* CRTable *)
  ch := 'A'; WHILE ch <= 'Z' DO BEGIN ddt[ch] := FALSE; INC(ch) END;
  maxSet := 0; Sets.Clear(cset[0]); Sets.Incl(cset[0], eofSy);
  firstNt := maxSymbols; maxP := maxSymbols; maxT :=  -1; maxC :=  -1;
  lastNt := maxP - 1;
  dummyName := 0; lastName := 0; symNames := FALSE; hasUses := FALSE;
  (* The dummy node gn^[0] ensures that none of the procedures
     above have to check for 0 indices. *) 
  NEW(gn);
  NEW(st);
  nNodes := 0;
  gn^[0].typ := -1; gn^[0].p1 := 0;    gn^[0].p2 := 0;
  gn^[0].next := 0; gn^[0].line := 0;
  gn^[0].pos.beg := -1; gn^[0].pos.len := 0; gn^[0].pos.col := 0;
END.
