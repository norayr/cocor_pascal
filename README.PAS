README.PAS
==========

               (Pat Terry, last updated Mon  10-30-95)
                          p.terry@ru.ac.za

This file points out the differences between Coco/R (Modula) and Coco/R
(Pascal).

Coco/R (Modula) is obtainable from various ftp sites.  It was developed in
Modula-2, and produces Modula-2 scanners and parsers from attribute grammars.

Turbo Pascal developed from Standard Pascal by means of steady accretion of
myriads of features, many of which were clearly inspired by Modula-2.  The
Turbo Pascal UNIT, for example, closely resembles a synthesis of the
definition and implementation modules of Modula-2.  Hence the initial
conversion of Coco/R (Modula) to Coco/R (Pascal), undertaken by Volker Pohlers
in 1995, was relatively straightforward.  This was quickly followed by a full
bootstrap, in which the Modula-2 sources of Coco/R were also rewritten in
Turbo Pascal.

Note that parsers and scanners produced by Coco/R (Pascal) are a long way from
being "standard" Pascal.

Use of Coco/R (Pascal) is almost identical with use of Coco/R (Modula).
Essentially the only difference is that the compiler description language has
been extended to allow an optional USES clause to appear right at the start of
the description, giving a list of Turbo Pascal "units" which must be added to
the USES clause generated for the derived parser.  An attribute grammar might
start like

     COMPILER Example

       USES CRT, DOS, MyLib;   (* this line not in Coco/R (Modula) grammars *)

       CHARACTERS
         letter = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".
         digit = "0123456789".
         cr = CHR(13).
         ...

and so on.  Examples will be found in the various specimen grammars found in
the kits in the directories TASTE, EBNF, SPREAD and SAMPLE.

The USES clause, if required, must appear immediately after the COMPILER line.
It may be described by

      UsesClause = [ "USES" ident { "," ident } ";" ]

For a full description of Coco/R, see the various files in the DOCS directory,
and the files CR0.ATG and CR.ATG in the SOURCES directory.


Copyrights
---------

Turbo Pascal is a trademark of Borland International.

=END=
