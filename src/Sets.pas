UNIT Sets;
(* General set handling primitives *)

INTERFACE

CONST
  size = 16;
  Limit = 32;
TYPE
  BITSET = SET OF 0 .. size - 1;
  BITARRAY = ARRAY [0 .. Limit] OF BITSET;

PROCEDURE Clear (VAR s: BITARRAY);                     (* s := {}       *)
PROCEDURE Fill (VAR s: BITARRAY);                      (* s := full set *)
FUNCTION IsIn (VAR s: BITARRAY; x: INTEGER): BOOLEAN;  (* x IN s ?      *)
PROCEDURE Incl (VAR s: BITARRAY; x: INTEGER);          (* INCL(s, x)    *)
PROCEDURE Excl (VAR s: BITARRAY; x: INTEGER);          (* EXCL(s, x)    *)
FUNCTION Includes (VAR s1, s2: BITARRAY): BOOLEAN;     (* s2 <= s1 ?    *)
FUNCTION Elements (VAR s: BITARRAY;                    (* | s |         *)
                    VAR lastElem: INTEGER): INTEGER;   (*               *)
FUNCTION Empty (VAR s: BITARRAY): BOOLEAN;             (* s1 = {} ?     *)
FUNCTION Equal (VAR s1, s2: BITARRAY): BOOLEAN;        (* s1 = s2 ?     *)
FUNCTION Different (VAR s1, s2: BITARRAY): BOOLEAN;    (* s1 * s2 = 0 ? *)
PROCEDURE Unite (VAR s1, s2: BITARRAY);                (* s1 := s1 + s2 *)
PROCEDURE Differ (VAR s1, s2: BITARRAY);               (* s1 := s1 - s2 *)
PROCEDURE Intersect (VAR s1, s2, s3: BITARRAY);        (* s3 := s1 * s2 *)

PROCEDURE Print (VAR f: TEXT; s: BITARRAY; w, indent: INTEGER);

IMPLEMENTATION

PROCEDURE Clear (VAR s : BITARRAY);
  VAR
    i : INTEGER;
  BEGIN
    i := 0;
    WHILE i <= Limit DO BEGIN s[i] := []; INC(i) END
  END;

(* Fill                 Set all elements in set s
---------------------------------------------------------------------------*) 

PROCEDURE Fill (VAR s : BITARRAY);
  VAR
    i : INTEGER;
  BEGIN
    i := 0;
    WHILE i <= Limit DO BEGIN s[i] := [0 .. size - 1]; INC(i) END
  END;

(* Incl                 Include element x in set s
---------------------------------------------------------------------------*) 

PROCEDURE Incl (VAR s : BITARRAY; x : INTEGER);
  BEGIN
    s[x DIV size] :=  s[x DIV size] + [x MOD size]
  END;

(* Excl
---------------------------------------------------------------------------*) 

PROCEDURE Excl (VAR s : BITARRAY; x : INTEGER);
  BEGIN
    s[x DIV size] :=  s[x DIV size] - [x MOD size]
  END;

(* IsIn                 TRUE, if element x is contained in set s
---------------------------------------------------------------------------*) 

FUNCTION IsIn (VAR s : BITARRAY; x : INTEGER) : BOOLEAN;
  BEGIN
    IsIn := x MOD size IN s[x DIV size]
  END;

(* Includes             TRUE, if s2 in s1
---------------------------------------------------------------------------*) 

FUNCTION Includes (VAR s1, s2 : BITARRAY) : BOOLEAN;
  VAR
    i : INTEGER;
  BEGIN
    i := 0;
    WHILE i <= Limit DO BEGIN
      IF NOT (s2[i] <= s1[i]) THEN BEGIN Includes := FALSE; EXIT END;
      INC(i)
    END;
    Includes := TRUE;
  END;

(* Elements             Return number of elements in set s
---------------------------------------------------------------------------*) 

FUNCTION Elements (VAR s : BITARRAY; VAR lastElem : INTEGER) : INTEGER;
  VAR
    i, n, max : INTEGER;

  BEGIN
    i := 0;
    n := 0;
    max := (Limit + 1) * size;
    WHILE i < max DO BEGIN
      IF i MOD size IN s[i DIV size] THEN BEGIN INC(n); lastElem := i END;
      INC(i)
    END;
    Elements := n
  END;

(* Empty                TRUE, if set s i sempty
---------------------------------------------------------------------------*) 

FUNCTION Empty (VAR s : BITARRAY) : BOOLEAN;
  VAR
    i : INTEGER;
  BEGIN
    i := 0;
    WHILE i <= Limit DO BEGIN
      IF s[i] <> [] THEN BEGIN Empty := FALSE; EXIT END;
      INC(i)
    END;
    Empty := TRUE
  END;

(* Equal                TRUE, if set s1 and s2 are equal
---------------------------------------------------------------------------*) 

FUNCTION Equal (VAR s1, s2 : BITARRAY) : BOOLEAN;
  VAR
    i : INTEGER;
  BEGIN
    i := 0;
    WHILE i <= Limit DO BEGIN
      IF s1[i] <> s2[i] THEN BEGIN Equal := FALSE; EXIT END;
      INC(i)
    END;
    Equal := TRUE
  END;

(* Different            TRUE, if set s1 and s2 are totally different
---------------------------------------------------------------------------*) 

FUNCTION Different (VAR s1, s2 : BITARRAY) : BOOLEAN;
  VAR
    i : INTEGER;
  BEGIN
    i := 0;
    WHILE i <= Limit DO BEGIN
      IF s1[i] * s2[i] <> [] THEN BEGIN Different := FALSE; EXIT END;
      INC(i)
    END;
    Different := TRUE
  END;

(* Unite                s1 := s1 + s2
---------------------------------------------------------------------------*) 

PROCEDURE Unite (VAR s1, s2 : BITARRAY);
  VAR
    i : INTEGER;
  BEGIN
    i := 0;
    WHILE i <= Limit DO BEGIN s1[i] := s1[i] + s2[i]; INC(i) END
  END;

(* Differ               s1 := s1 - s2
---------------------------------------------------------------------------*) 

PROCEDURE Differ (VAR s1, s2 : BITARRAY);
  VAR
    i : INTEGER;
  BEGIN
    i := 0;
    WHILE i <= Limit DO BEGIN s1[i] := s1[i] - s2[i]; INC(i) END
  END;

(* Intersect            s3 := s1 * s2
---------------------------------------------------------------------------*) 

PROCEDURE Intersect (VAR s1, s2, s3 : BITARRAY);
  VAR
    i : INTEGER;
  BEGIN
    i := 0;
    WHILE i <= Limit DO BEGIN s3[i] := s1[i] * s2[i]; INC(i) END
  END;

(* Print                Print set s
---------------------------------------------------------------------------*) 

PROCEDURE Print (VAR f : TEXT; s : BITARRAY; w, indent : INTEGER);
  VAR
    col, i, max : INTEGER;
  BEGIN
    i := 0;
    col := indent;
    max := (Limit + 1) * size;
    Write(f, '{');
    WHILE i < max DO BEGIN
      IF IsIn(s, i) THEN
        BEGIN
          IF col + 4 > w THEN
            BEGIN WriteLn(f); Write(f, ' ':indent); col := indent END;
          Write(f, i:3, ',');
          INC(col, 4)
        END;
      INC(i)
    END;
    Write(f, '}')
  END;

END.
