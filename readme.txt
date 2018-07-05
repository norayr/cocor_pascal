Compiler-Generator Coco/R
=========================

               (Pat Terry,  updated Sat  03-11-00)
                       p.terry@ru.ac.za

Coco/R generates recursive descent parsers and their associated scanners from
attributed grammars.  The distribution kit contains source files for the
compiler generator Coco/R (Moessenboeck, 1990), as well as the executables,
frame files, and some sample applications.

Coco/R was originally written in Oberon by Hanspeter Moessenboeck.  It was
then ported into Modula-2; the first such port being done by Hanspeter
Moessenboeck for the Apple MacMeth system.  A port was done to JPI TopSpeed
Modula-2 at ETH Zurich by Marc Brandis and Christof Brass.  This was made
available to Pat Terry, who corrected several errors, enhanced the
portability, and provided the versions which you find on this distribution.
Responsibility for remaining bugs in these versions now rests largely with
Pat Terry.

The Modula-2 versions for WinTel platforms are known to be immediately
usable with any of the PIM based TopSpeed (JPI) compilers; the Fitted
Software Tools (FST) compilers, versions 2.x through 3.5; the StonyBrook
QuickMod 2.2 compiler; and the Logitech compiler, version 3.03.  As from
release 1.43, the system should also be fully compatible with ISO compilers
such as StonyBrook V4, and XDS from XTech Ltd.

Full source code for Coco/R compatible with these compilers is supplied.  It
is hoped that this will be trivially portable to other Modula-2 compilers
presently available, save for the I/O module used by Coco/R (and, in one
mode of use, its generated parsers); code for the I/O module for the
compilers listed above is, naturally, supplied.

So far as other operating systems are concerned, the Modula-2 versions of
Coco/R have also been ported to Mocka Modula-2 by Pat Terry and Toshinori
Maeno, for both Linux and BSD386, and to the Apple MAC p1 compiler by Woody
Yeung (yeung@reed.edu).  The source code is identical save for the I/O
modules for these compilers (which code is also provided in the DOS kit),
and in addition, distributions are available for these systems in their
native format.

Coco/R was first ported to Gardens Point Modula-2 by John Gough. (Gardens
Point Modula-2 is available for a wide variety of platforms, including Intel,
Sparc and MIPS machines).  The source code for the I/O modules for use with
the freeware Gardens Point Modula-2 for the PC (gpm-pc) is supplied with the
DOS distribution kit, and a complete port of Coco/R for the Unix hosted
versions of Gardens Point Modula-2 is also available.

Coco/R was also ported to TDI Modula-2 for the Atari by Rolf Schrader.
The sources (at level 1.39) are also supplied in a complete kit.  These
have numerous minor differences from the MS-DOS versions, although they
were derived from them, and not having access to an Atari, they have not
been kept up to date.  A contact address for this version is

    Rolf Schrader, Dipl.-Math. & Dipl.-Phys.,
    Kronenstr. 24,
    D-76133 Karlsruhe,
    Germany.

As from release 1.39, versions of Coco/R that produce Turbo Pascal units have
been made available through a port largely done by Volker Pohlers
(pohlers@escher.hrz.fh-stralsund.de), and now also maintained by Pat Terry.

There is also a C/C++ version of Coco/R, ported by Frankie Arzu
(frankie_arzu@yahoo.com or farzu@uvg.edu.gt).  As from version 1.06 a user has
had the option of generating either C or C++ code. The C++ version generates
scanner and parser classes based on a simple but effective class hierarchy.

All of these versions of Coco/R can bootstrap themselves to generate a
driver, parser, scanner, and semantic evaluator from an attributed grammar
CR.ATG.  This grammar thus serves as an an example of how to write compiler
descriptions for Coco/R.  There are also other simpler examples showing its
use.

Oberon versions of Coco/R are still available, and a new Java version has
recently been released.  These original versions are maintained by Hanspeter
Moessenboeck in Linz (see address below); an extended Java one has been
derived by Pat Terry.

It is important to realise that Coco/R is intended for use with grammars that
meet the LL(1) conditions.  Many grammars require some massaging before these
conditions are met.  Some of the examples in the kit are (deliberately)
non-LL(1), and are intended as examples for study and experiment.

While every attempt has been made to ensure that Coco/R performs
satisfactorily, the developers can accept no liability for any damage or
loss, including special, incidental, or consequential, caused by the use of
the software, directly or indirectly.


Where to get the latest versions
================================

Up to date information about Coco/r is available on the WWW at

        http://cs.ru.ac.za/homes/cspt/cocor.htm

The latest versions of Coco/R should be available for anonymous ftp from any
of the servers listed below (not all servers carry all versions):

In Europe

         ftp.ssw.uni-linz.ac.at:/pub/Coco

In Australia

         ftp.fit.qut.edu.au:/pub/coco

The freeware gpm-pc Modula-2 compiler is available on the same server.

In South Africa

         cs.ru.ac.za:/pub/coco

The latest shareware version of the FST Modula-2 compiler for the PC is
available on the same server in the directory /pub/languages.

In Central America

         uvg.edu.gt:/pub/coco

In the USA

         ftp.psg.com:/pub/modula-2/coco

where it also will be available by mail server

         To: server@ftp.psg.com
         From: <address to which it is to be sent>
         Subject: send pub/modula-2/coco/...

The latest shareware version of FST Modula-2 for the PC is available on the
same server in the directory /pub/modula-2 (fst-40s.lzh, compressed with
LHA).

The distributions come in various files (in each case "xxx" denotes the
release number, for example 143 for version 1.43)

    (a)    COCOxxx.EXE   - the kit for MS-DOS platforms
    (b)    gpmxxx.tgz    - the equivalent kit for Gardens Point
    (c)    ATARIxxx.EXE  - the kit for the Atari platform
    (d)    MOCKAxxx.tgz  - the kit for Mocka (Linux and 386BSD)
    (e)    COCOPxxx.EXE  - the kit for producing Turbo Pascal hosted in Modula
    (f)    TURBOxxx.EXE  - the kit for producing Turbo Pascal hosted in Pascal
    (g)    COCORCxx.ZIP  - the kit for producing C/C++
    (g)    README        - this file
    (h)    README.1st    - unpacking and installation notes

The kits contain sources, objects, examples and vanilla-ASCII documentation
files.  The MS-DOS versions are self-extracting files for MS-DOS, compressed
with the public domain utility LHA (which is also available on many Unix
systems).  All that is needed to install the system on a WinTel platform
is to copy the .EXE file to a suitable directory and to execute it.  About
1.6 MB of space is needed for the entire distribution, but several files
are compiler/platform specific, and need not be retained.

The Atari version is also supplied as a self-extracting file for MS-DOS.  It
is hoped that users will be able to find an easy way to transfer the files to
their Atari systems.  The Atari port is presently sufficiently different from
the others that the distribution kit is self contained, rather than being
merged with the MS-DOS versions.

For the latest on the Oberon versions, point your browser at

         ftp://ftp.ssw-linz.ac.at/pub/Oberon/LinzTools/Coco.cod

or look for the ile on the other mirrors.  Like the Modula-2 version, this
release comes with full source code.

For the Java versions, point your browser at

         http://www.ssw-linz.ac.at/Projects/Coco/Coco.html

or

         http://cs.ru.ac.za/homes/cspt/javacoco.htm

for the extended version.

FileList
========

The following gives an indication of the files provided in various kits of
Coco/R (Modula).  Essentially the same distribution is to be found in the
other kits (including the Pascal versions) - allowing for differences in
file and directory naming conventions.  There may also be extra files,
depending on the release date and version.  The Pascal kits have "units"
with extensions PAS, rather than separate DEF and MOD files.

  READ.ME              This file
  README.GPM           Notes on the Gardens Point implementation
  README.ISO           Notes on using the ISO compliant system
  README.1ST           Unpacking and installation information
  HELP.LHA             Notes on packing the kit with LHA
  PACK.BAT             Pack up system into a self-extracting file
  COCOR.EXE            Compiler-compiler executable
  HISTORY              Summary of bug fixes and modifications
  CONVERT.MOD          Program to convert text files between systems -
                       translating line marks appropriate to the O/S in use

Subdirectory "Docs"    Documentation

  COCO.USE             Notes on the use of Coco
  COCOL                The compiler description language
  CHANGES              Differences between Oberon and Modula-2 versions

Subdirectories "Frames"  and "IsoFrame"  Specimen frame files.  One set is
for generating parsers to be used with the supplied FileIO library, the
other set is for generating parsers to be used with an ISO I/O library.

  SCANNER.FRM          Frame from which the standard scanner is generated
  SCANNERC.FRM         Frame from which a scanner can be generated
                       allowing the retrieval of comment text
  SCANNER2.FRM         Frame from which a more efficient scanner can be
                       generated for short source files
  PARSER.FRM           Frame from which the parser is generated
  COMPILER.FRM         Frame from which a driver compiler may be generated
                       (tabs in the listing files are retained)
  COMPILE2.FRM         Frame from which a driver compiler may be generated
                       (tabs in the listing files are expanded)

Subdirectory "Sources" and its subdirectories - Sources for Coco/R

  CR.MOD               Main program
  CR.ATG               Fully attributed grammar of Coco/R
  CR0.ATG              Simplifed grammar of Coco/R (no attributes)
  CRE.TXT              Error numbers and corresponding error message texts
  CRS.DEF + MOD        Scanner (generated by Coco/R from CR.ATG)
  CRP.DEF + MOD        Parser (generated by Coco/R from CR.ATG)
                       (The JPI specific version of CRP.MOD is in the
                       Sources\JPI directory)
  CRT.DEF + MOD        Symbol table, top-down graph, grammar tests.
  CRA.DEF + MOD        Generation of the scanner.
  CRX.DEF + MOD        Generation of the parser.
  CRC.DEF + MOD        Generation of the compiler driver.
  CRG.DEF + MOD        Module giving symbolic names for scanner/parser
                       to use (Generated with $N pragma)
  FileIO.DEF           General input output library definition
  FileIO.MOD           Source for FileIO.MOD appears in compiler specific
                       subdirectories - Sources\JPI Sources\FST Sources\STO
                       Sources\LOG or Sources\GPM etc
  Sets.DEF + MOD       Various set operations
  CR.FRM               Frame from which CR.MOD may be regenerated ($C pragma)

Subdirectory "Taste"   A tiny compiler and utilities as examples of Coco/R

  Taste.ATG            Compiler description
  Taste.FRM            Frame from which TASTE.MOD may be generated ($C pragma)
  TC.DEF + MOD         Code generator/interpreter
  TL.DEF + MOD         Symbol table handler

  Pretty.ATG           Pretty printer description
  Pretty.FRM           Frame from which PRETTY.MOD may be generated ($C pragma)
  Prettier.DEF and MOD Auxiliary pretty printing routines

  XRef.ATG             Cross referencer description
  Xref.FRM             Frame from which XREF.MOD may be generated ($C pragma)
  CrossRef.DEF + MOD   Auxiliary table handlers

  *.TAS                Example input files

Subdirectory "EBNF"    An EBNF cross referencer as an example of Coco/R

  EBNF.ATG             Compiler description
  EBNF.FRM             Frame from which EBNF.MOD may be generated ($C pragma)

  CrossRef.DEF + MOD   Auxiliary table handlers

  BNF.*                Example input files

Subdirectory "Pretty" and "ISOPretty"  A Modula-2 pretty printer

  ISOMOD2.ATG          Pretty printer description (ISO M-2)
  PIMMOD2.ATG          Pretty printer description (PIM M-2)
  MOD2.FRM             Frame from which MOD2.MOD may be generated ($C pragma)
  Prettier.DEF and MOD Auxiliary pretty printing routines
  Scanner.FRM          Special Scanner frame file to handle comments

Subdirectory "Sample"  Further sample grammars for Coco/R

--- These are not necesarily suitable for immediate use.  They may need
    massaging and adaptation before sensible parsers can be constructed

  ADACS.ATG            Subset Ada grammar based on Fischer and LeBlanc
  CALC.ATG             Simple calculator grammar based on Dobler
  CDECL.ATG            Decipher complicated C declarations
  CLANG1.ATG           Clang level 1 grammar based on Terry
  CLANG2.ATG           Clang prettyprinter based on Terry
  EXPR.ATG             Simple expression grammar
  ADACS.ATG            Subset Ada grammar based on Fisher and LeBlanc
  MICROADA.ATG         Subset Ada grammar based on Dobler
  MOD2.ATG             Modula-2 grammar based on Dobler's
  PIMMOD2.ATG          Modula-2 grammar based on PIM
  PASCAL.ATG           Jensen and Wirth Pascal
  C.ATG                Grammar for a subset of C
  CMINUS.ATG           Simple C like language
  HTML.ATG             Subset of early versions of HTML for Web pages
  OBERON.ATG           Grammar for Oberon
  UMBRIEL1.ATG         Grammar for Umbriel
  UMBRIEL2.ATG         Grammar for Umbriel
  TOPSY0.ATG           Another simple C like language


References
==========

For further information on the use and implementation of Coco refer to

  Moessenboeck, H. : A Generator for Fast Compiler Front-Ends.
  Report 127, Dept. Informatik, ETH Zurich (1990)

  Moessenboeck, H. : A generator for production quality compilers.
  Proc 3rd Int'l Workshop on Compiler-Compilers, Schwerin FRG, 1990

Related insight may be gained from

  Rechenberg, P and Moessenboeck, H. : A compiler generator for
  microcomputers (Prentice-Hall, 1989)

whichs describes Alex and Coco, predecessors of Coco/R, and from

  Dobler, H. and Pirklbauer, P.  : Coco-2, a new Compiler Compiler
  (ACM SIGPLAN Notices, 25(5), 82-90, May 1990)

  Dobler, H. : Top-down Parsing in Coco-2
  (ACM SIGPLAN Notices, 26(3), 79-87, March 1991)

which describe Coco-2, another derivative of the original Coco.

A textbook making extensive use of Coco/R is

  Terry, P.D. : Compilers and Compiler Generators - an introduction with C++
  (ITCP, London, 1997)

This book contains numerous case studies; in spite of the title, the case
studies are supplied in machine readable form for users of any one of
Modula-2, Pascal and C/C++.  These sources are also available by anonymous
ftp from

      cs.ru.ac.za:/pub/languages

Th original book has a home page at

      http://cs.ru.ac.za/homes/cspt/compbook.htm

but is now out of print.  It has been made available on the WWW in various
formats; point your browser at

      http://www.scifac.ru.ac.za/compilers

for full details.

Licensing
=========

The Modula-2 version of Coco/R is not a public domain program.  It is being
distributed as Shareware.  This means that you are encouraged to make
unmodified copies of the software and documentation for your own evaluation,
and for others to try, but you may not sell it, or distribute it in
connection with any other product or service.

Should you find Coco/R to be useful, you are invited to become a registered
user, by sending your name and address to one of the developers:

      Prof. Hanspeter Moessenboeck
      University of Linz
      Institute of Computer Science
      Altenbergerstr 69
      A-4040 Linz
      Austria
      Tel: +43-732-2468-9700
      e-mail: moessenboeck@ssw.uni-linz.ac.at

or

      Prof. Pat Terry
      Computer Science Department,
      Rhodes University
      GRAHAMSTOWN 6140,  South Africa
      Tel: +27-46-6038292
      e-mail: p.terry@ru.ac.za

If you make use of the Modula-2 version of Coco/R for commercial projects
(that is, to develop software that you sell to others) you are obliged to
pay for it by making a donation of $50; usage for academic purposes is free.

The C/C++ version is being distributed under the same terms as GNU software.
For full details contact Frankie Arzu (frankie_arzu@yahoo.com or
farzu@uvg.edu.gt).

Users who implement Coco/R under other compilers are encouraged to share
their experience and to make their I/O module implementations available in
later releases of the system.

Trademarks
==========

Any and all trademarks mentioned above are duly acknowledged.

=END=
