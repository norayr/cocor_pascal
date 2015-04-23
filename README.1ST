README.1st - Unpacking and installing the COCO/R kits
=====================================================

    Pat Terry (p.terry@ru.ac.za) - updated Sat  03-11-00

WinTel versions - Modula-2 
--------------------------

(The MAC p1 version can also be easily derived from these)

(a) Create a suitable directory on your hard drive, for example

                MD C:\COCO

(b) Change to this directory

                C:
                CD \COCO

(c) Copy the file COCOver.EXE to this directory (where "ver" is a number like
    143 giving the release number)

                COPY A:COCOver.EXE

(d) Extract the files

                COCOver

    This will create the appropriate further subdirectories for you.

    COCOver.EXE is a self extracting file, created with the LHA compressor.
    You can also uncompress it with the command

                LHA x COCOver.EXE

    (this should also work on many Unix systems).

(e) The executable, COCOR.EXE will be found in the base directory.  Either
    modify your PATH setting to include this directory, or copy/move
    COCOR.EXE to some suitable directory that is already on your path.

(f) Coco/R makes use of "frame" files.

    As from version 1.43, two sets of specimen frame files have been provided.
    The first, in the subdirectory C:\COCO\FRAMES is for for generating systems
    that should compile on a very large number of Modula-2 compilers (provided
    that you install the FileIO library as mentioned below) and the second, in
    the directory C:\COCO\ISOFRAME is for generating systems that are
    independent of FileIO, but which require that you have an ISO compliant
    Modula compiler with the full ISO I/O Library.

    Either move the selected frame files to your working directory, or,
    preferably, set the DOS environment variable CRFRAMES to point to the
    FRAMES or ISOFRAME directory:

                SET CRFRAMES=C:\COCO\FRAMES
    or
                SET CRFRAMES=C:\COCO\ISOFRAME

(g) Scanners, parsers, and compilers created by Coco/R using the first set of
    frames assume that you will incorporate the I/O module FileIO.  The
    sources of Coco/R itself also use this Library, and so if you want to
    recompile Coco/R, or use non-ISO compilers to compile the parsers that
    Coco/R generates, you will need to compile up the version of FileIO that
    matches your compiler.  In the C:\COCO\SOURCES subdirectory you will find
    a generic definition module FILEIO.DEF, and in one of the several
    subdirectories of C:\COCO\SOURCES you will find the implementation module
    FILEIO.MOD (and possibly a slightly compiler-specific version of
    FILEIO.DEF).  You will need to proceed somewhat as follows:

                CD your library directory
                COPY C:\COCO\SOURCES\FILEIO.DEF
                COPY C:\COCO\SOURCES\xxx

    where xxx =
            FST        (Fitted Systems Tools compilers)
            GPMBSD     (Gardens Point Free BSD compiler, GPM Library)
            GPMISO     (Gardens Point compiler, ISO library)
            GPMLIN     (Gardens Point Linux compiler, GPM Library)
            GPMPC      (Gardens Point PC compiler)
            JPI        (TopSpeed compilers)
            LOG3       (Logitech version 3 compilers)
            LOG4       (Logitech version 4 compilers)
            MOCKABSD   (Mocka Free BSD compiler, Mocka Library)
            MOCKALIN   (Mocka Linux compiler, Mocka Library)
            MPWISO     (p1 MPW (MAC) ISO compiler)
            STO        (Early StonyBrook compilers, such as QuickMod)
            STOISO     (StonyBrook ISO compilers)
            TERRA      (TerraDatentechnik port of Logitech library for
                        StonyBrook compilers)
            XDSISO     (XDS 32 bit ISO compiler)

    Follow this by compiling FILEIO.DEF and FILEIO.MOD.

(h) Study the various README files, and the documentation in the C:\COCO\DOCS
    subdirectory, especially the file "coco.use".  There are several examples
    of grammars suited to Coco/R in the other directories created by the
    installation process.

(The (non-ISO) shareware FST compiler for WinTel platforms is available from
various ftp sites - look for a file named FST-40S.LZH or similar name.)


Unix versions - Modula-2
------------------------

(a) Create a suitable directory, for example

                mkdir coco

(b) Change to this directory

                cd coco

(c) Copy the file MOCKAver.tgz to this directory (for use with the Karlsruhe
    Mocka compiler) or the file gpmver.tgz (for use with the Gardens Point
    Unix compilers).

    (where "ver" is a number like 146 implying the release number)

(d) Extract the files, for example

                gunzip MOCKAver.tgz
                tar xf MOCKAver.tar

    This will create appropriate further subdirectories for you.

(e) Next you have to make the executable of the compiler.

    Make a suitable working directory, and copy the files from the sources
    directory to this working directory.

    Also copy the files from coco/sources/BSD386 or coco/sources/Linux or
    /coco/sources/ISOGPM to the same directory, as appropriate for your
    compiler.

    If you are using Mocka, make the system by invoking the Mocka shell

                mc
                >> p CR
                >> q

    This will create the executable CR.  We recommend that you strip it,
    rename it as cocor, and move it to some suitable directory on your path.

    If you are using Gardens Point, make the system by a sequence like

                cc -c stdfiles.c
                gpmake cr

    This will create the executable cr.  We recommend that you strip it,
    rename it as cocor, and move it to some suitable directory on your path.

(f) Coco/R makes use of "frame" files.  Two sets of specimen frame files are
    provided in the subdirectories /coco/frames (for generating systems that
    should compile on a very large number of Modula-2 compilers, provided that
    you install the FileIO library as mentioned below) and /coco/isoframe (for
    generating systems that are independent of FileIO, but which require that
    you have an ISO compliant Modula compiler with the full ISO I/O Library).

    Either move these frame files to your working directory, or, preferably,
    set the environment variable CRFRAMES to point to the FRAMES directory,
    for example

                CRFRAMES=coco/frames
                export CRFRAMES

(g) Scanners, parsers, and compilers created by Coco/R assume that you will
    incorporate the I/O module FileIO.  You will need to compile up the
    version of FileIO that matches your compiler.

    Users of the Mocka compilers will need to proceed as follows

                cd your/library/directory

    followed by

                cp /coco/sources/Linux/* .
    or
                cp /coco/sources/FreeBSD/* .

    as appropriate.

    Users of the Gardens Point compilers will need to proceed as follows

                cd your/library/directory

    Versions of FileIO tuned to the Linux and FreeBsd implementations of
    Gardens Point module can be obtained by

                cp /coco/sources/Linux/* .
    or
                cp /coco/sources/FreeBSD/* .

    and a version based on the ISO libraries can be obtained by

                cp /coco/sources/ISOGPM/* .

    (These file may act as models for other implementations, but we have not
    been able to test every combination of platform and compiler.)

    Once you have the sources of FileIO, compile them, and install the various
    files into your library path.

(h) Study the various README files, and the documentation in the /coco/docs
    subdirectory, especially the file "coco.use".  There are several examples
    of grammars suited to Coco/R in the other directories created by the
    installation process.


Wintel versions - TurboPascal
-----------------------------

A version of Coco/R ported to Turbo Pascal with the help of Volker Pohlers is
available.  Installation of this is essentially as for the WinTel Modula-2
versions (without the complication of different sets of frame files, or
compiling up a special I/O library).  The file to unpack is named TURBOver.EXE
(Turbo Pascal, producing Turbo Pascal) or TURBOver.ZIP.

The sources of Coco/R and the entire system should also be compatible with
FreePascal (http://www.freepascal.org), and have been tested with Free Pascal
0.99.14 on a Linux system (Version 0.99.12 had a bug in set handling; the
system will not work on releases of Free PAscal earlier than 0.99.14).  You
will have to unpack the sources and compile them for yourself, using the
command

         ppc386 -So cr

to work in TurboPascal compatible mode.

WinTel and Unix versions - C/C++
--------------------------------

Here are the basic steps for installing and building Coco/R for C/C++.

Obtain either the "dos" based kit (cocorcXX.zip)  or the "Unix" based kit
(cocorcXX.tgz) and decompress it.  Use the -d option on the zip file
and gunzip/tar for the Unix kit.

1. Set up the CRFRAMES environment variable to the path where the
   frame files can be found:

    DOS: Give a command like
         SET CRFRAMES=C:\COCOR\FRAMES

    UNIX: Give a command like
         CRFRAMES=/usr/local/cocor/frames;export CRFRAMES
    (The exact form of this will depend on the shell you are using, and on
    the directory set up.)

2. Run the proper make file:

    DOS: Give the command
         make -f borlandc.mk

      This will compile the Coco/R sources and some examples.

    UNIX:
      First uudecode the "dos2unix.uue" file to create the file
      "dos2unix.sh".  In this way we can be sure that dos2unix.sh is
      correct; it contains a critical ASCII 13 (^M or CR) character in
      its code. Give the command

         uudecode dos2unix.uue

      Make this file executable. Give the command
         chmod +x dos2unix.sh

      Execute dos2unix.sh as a shell script to correct the file unix.mk.  
      Give the command
         ./dos2unix.sh unix.mk

      Convert all files to "unix" format.  Give the command
         make -f unix.mk dos2unix

      Finally build the distribution.  Give the command
         make -f unix.mk

      ++++ You may have to edit the makefiles to select the correct compiler
      for your system.  If "make -f unix.mk" does not work properly, study
      the make files and edit them appropriately.  You may need to invoke
      "gmake" rather than "make".


Use of the Borland C++ IDE
==========================

If you are a DOS user, you can also use the Borland C++ integrated development
environment to build the programs.  Create a .prj file, and then remember to
change the include directories to have the correct include directories for
you. (Menu: Options, Directories)


File extension conventions
==========================

The C++ source files in the kit have been supplied with ".cpp" and ".hpp"
extensions.

These work well with Borland C++, Linux g++, and several other C++ compilers.
However, some UNIX C++ compilers (like GNU C on Sun's Solaris) use a ".cpp"
extension to mean "c preprocessed files", so that the compiler will NOT
preprocess the file.  To fix this problem, you have to

  (1) Rename the files to have a valid C++ extension for your compiler, for
      example, ".C" or ".cxx".

      In all the directories that have C++ sources, the "unix.mk" makefiles
      have 2 entry points, named "fix_2_cpp" and "fix_2_cxx".  These will
      help you rename the files in the distribution.

      From the main Coco/R directory, to change all the C++ file extensions
      from ".cpp" to ".cxx", give the command:

            make -f unix.mk fix_2_cxx

  (2) Do not forget to set the "CRCEXT" environment variable to "cxx".
      Rebuild the distribution if necessary.

You can tell Coco/R to use a customized file extension for your own
applications by using the CRCEXT and CRHEXT environment variables.

For example, suppose you need to use ".cxx" extensions for C++ files
and ".hxx" for the header files

   DOS:  Give the commands
         SET CRCEXT=cxx
         SET CRHEXT=hxx
   UNIX: Give the command
         CRCEXT=cxx;CRHEXT=hxx;export CRCEXT CRHEXT

In this way, Coco/R will generate files with these extensions.  It would
probably be useful to set all the Coco/R environment variables in your
AUTOEXEC.BAT, .profile or .login file, so that each time you login these 
variables will be correctly set up.

As from version 1.08 you can also set these options using a command line
option, for example

              -DCRFRAMES=/usr/lib/coco/frames


Trademarks
----------

Any and all trademarks mentioned above are duly acknowledged.

=END=
