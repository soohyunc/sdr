# Microsoft Developer Studio Project File - Name="sdr" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Application" 0x0101

CFG=sdr - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "sdr.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "sdr.mak" CFG="sdr - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "sdr - Win32 Release" (based on "Win32 (x86) Application")
!MESSAGE "sdr - Win32 Debug" (based on "Win32 (x86) Application")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName ""
# PROP Scc_LocalPath ""
CPP=cl.exe
MTL=midl.exe
RSC=rc.exe

!IF  "$(CFG)" == "sdr - Win32 Release"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "Release"
# PROP Intermediate_Dir "Release"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /D "_MBCS" /YX /FD /c
# ADD CPP /nologo /W3 /GX /O2 /I "\src\sdr\src" /I "\src\tcl-8.0\generic" /I "\src\tk-8.0\generic" /I "\src\tk-8.0\xlib" /I "\src\sdr\win32" /I "\src\common" /D "WIN32" /D "NDEBUG" /D "AUTH" /D "CANT_MCAST_BIND" /D "NORANDPROTO" /D "DIFF_BYTE_ORDER" /YX /FD /c
# ADD BASE MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /machine:I386
# ADD LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib tcllib.lib tklib.lib uclmm.lib wsock32.lib Ws2_32.lib /nologo /subsystem:windows /machine:I386 /libpath:"\src\tcl-8.0\win\Release" /libpath:"\src\tk-8.0\win\Release" /libpath:"\src\common\Release"

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "Debug"
# PROP Intermediate_Dir "Debug"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /D "_MBCS" /YX /FD /GZ /c
# ADD CPP /nologo /W3 /Gm /GX /ZI /Od /I "\src\sdr\src" /I "\src\tcl-8.0\generic" /I "\src\tk-8.0\generic" /I "\src\tk-8.0\xlib" /I "\src\sdr\win32" /I "\src\common" /D "WIN32" /D "_DEBUG" /D "AUTH" /D "CANT_MCAST_BIND" /D "NORANDPROTO" /D "DIFF_BYTE_ORDER" /FR /YX /FD /GZ /c
# ADD BASE MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /debug /machine:I386 /pdbtype:sept
# ADD LINK32 msacm32.lib kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib tcllib.lib tklib.lib uclmm.lib wsock32.lib Ws2_32.lib /nologo /subsystem:windows /debug /machine:I386 /pdbtype:sept /libpath:"\src\tcl-8.0\win\Debug" /libpath:"\src\tk-8.0\win\Debug" /libpath:"\src\common\Debug"
# SUBTRACT LINK32 /verbose /nodefaultlib

!ENDIF 

# Begin Target

# Name "sdr - Win32 Release"
# Name "sdr - Win32 Debug"
# Begin Group "Source Files"

# PROP Default_Filter "cpp;c;cxx;rc;def;r;odl;idl;hpj;bat"
# Begin Source File

SOURCE=..\src\bitmaps.c
# End Source File
# Begin Source File

SOURCE=..\src\bus.c
# End Source File
# Begin Source File

SOURCE=..\src\cli.c
# End Source File
# Begin Source File

SOURCE=..\src\compat.c
# End Source File
# Begin Source File

SOURCE=..\src\crypt.c
# End Source File
# Begin Source File

SOURCE=..\src\generate_ids.c
# End Source File
# Begin Source File

SOURCE=..\src\iohandler.c
# End Source File
# Begin Source File

SOURCE=..\src\pgp_crypt.c
# End Source File
# Begin Source File

SOURCE=..\src\pkcs7_crypt.c
# End Source File
# Begin Source File

SOURCE=..\src\polluted.c
# End Source File
# Begin Source File

SOURCE=..\src\random.c
# End Source File
# Begin Source File

SOURCE=..\src\sap_crypt.c
# End Source File
# Begin Source File

SOURCE=..\src\sd_listen.c
# End Source File
# Begin Source File

SOURCE=..\src\sdr_help.c
# End Source File
# Begin Source File

SOURCE=..\src\sip.c
# End Source File
# Begin Source File

SOURCE=..\src\sip_common.c
# End Source File
# Begin Source File

SOURCE=..\src\sip_register.c
# End Source File
# Begin Source File

SOURCE=.\tcl_cache.c
# End Source File
# Begin Source File

SOURCE=.\tcl_cli.c
# End Source File
# Begin Source File

SOURCE=.\tcl_generic.c
# End Source File
# Begin Source File

SOURCE=.\tcl_new.c
# End Source File
# Begin Source File

SOURCE=.\tcl_parsed_plugins.c
# End Source File
# Begin Source File

SOURCE=.\tcl_pgp_crypt.c
# End Source File
# Begin Source File

SOURCE=.\tcl_pkcs7_crypt.c
# End Source File
# Begin Source File

SOURCE=.\tcl_plugins.c
# End Source File
# Begin Source File

SOURCE=.\tcl_sap_crypt.c
# End Source File
# Begin Source File

SOURCE=.\tcl_sdp.c
# End Source File
# Begin Source File

SOURCE=.\tcl_sdr.c
# End Source File
# Begin Source File

SOURCE=.\tcl_sip.c
# End Source File
# Begin Source File

SOURCE=.\tcl_start_tools.c
# End Source File
# Begin Source File

SOURCE=.\tcl_www.c
# End Source File
# Begin Source File

SOURCE=..\src\tkUnixInit.c
# End Source File
# Begin Source File

SOURCE=..\src\ui_fns.c
# End Source File
# Begin Source File

SOURCE=..\src\ui_init.c
# End Source File
# Begin Source File

SOURCE=..\src\win32.c
# End Source File
# Begin Source File

SOURCE=..\src\www_fns.c
# End Source File
# End Group
# Begin Group "Header Files"

# PROP Default_Filter "h;hpp;hxx;hm;inl"
# Begin Source File

SOURCE=..\src\audio_xbm.h
# End Source File
# Begin Source File

SOURCE=..\src\config.h
# End Source File
# Begin Source File

SOURCE=..\src\crypt.h
# End Source File
# Begin Source File

SOURCE=..\src\dns.h
# End Source File
# Begin Source File

SOURCE=..\src\form.h
# End Source File
# Begin Source File

SOURCE=..\src\generate_ids.h
# End Source File
# Begin Source File

SOURCE=..\src\prototypes.h
# End Source File
# Begin Source File

SOURCE=..\src\prototypes_crypt.h
# End Source File
# Begin Source File

SOURCE=..\src\sap_crypt.h
# End Source File
# Begin Source File

SOURCE=..\src\sdr.h
# End Source File
# Begin Source File

SOURCE=..\src\sip.h
# End Source File
# Begin Source File

SOURCE=..\src\store_entries.h
# End Source File
# Begin Source File

SOURCE=..\src\tcl_crypt_modules.h

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\tcl_crypt_modules.h

"\src\sdr\win32\tcl_modules.h" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	copy $(InputPath) \src\sdr\win32\tcl_modules.h

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\tcl_crypt_modules.h

"\src\sdr\win32\tcl_modules.h" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	copy $(InputPath) \src\sdr\win32\tcl_modules.h

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\ui_fns.h
# End Source File
# Begin Source File

SOURCE=..\src\www_prototypes.h
# End Source File
# End Group
# Begin Group "Resource Files"

# PROP Default_Filter "ico;cur;bmp;dlg;rc2;rct;bin;rgs;gif;jpg;jpeg;jpe"
# Begin Source File

SOURCE="..\..\tk-8.0\win\tk.res"
# End Source File
# End Group
# Begin Group "HTML files"

# PROP Default_Filter "html"
# Begin Source File

SOURCE=.\bugs.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=.\bugs.html
InputName=bugs

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=.\bugs.html
InputName=bugs

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\changes.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=.\changes.html
InputName=changes

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=.\changes.html
InputName=changes

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\intro.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\intro.html
InputName=intro

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\intro.html
InputName=intro

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\mbone_faq.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\mbone_faq.html
InputName=mbone_faq

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\mbone_faq.html
InputName=mbone_faq

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\mbone_tools.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\mbone_tools.html
InputName=mbone_tools

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\mbone_tools.html
InputName=mbone_tools

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\node1.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\node1.html
InputName=node1

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\node1.html
InputName=node1

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\node10.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\node10.html
InputName=node10

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\node10.html
InputName=node10

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\node11.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\node11.html
InputName=node11

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\node11.html
InputName=node11

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\node12.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\node12.html
InputName=node12

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\node12.html
InputName=node12

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\node13.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\node13.html
InputName=node13

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\node13.html
InputName=node13

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\node14.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\node14.html
InputName=node14

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\node14.html
InputName=node14

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\node15.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\node15.html
InputName=node15

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\node15.html
InputName=node15

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\node2.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\node2.html
InputName=node2

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\node2.html
InputName=node2

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\node3.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\node3.html
InputName=node3

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\node3.html
InputName=node3

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\node4.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\node4.html
InputName=node4

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\node4.html
InputName=node4

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\node5.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\node5.html
InputName=node5

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\node5.html
InputName=node5

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\node6.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\node6.html
InputName=node6

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\node6.html
InputName=node6

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\node7.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\node7.html
InputName=node7

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\node7.html
InputName=node7

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\node8.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\node8.html
InputName=node8

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\node8.html
InputName=node8

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\node9.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\node9.html
InputName=node9

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\node9.html
InputName=node9

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\plugins.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\plugins.html
InputName=plugins

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\plugins.html
InputName=plugins

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\html\plugtut.html

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\html\plugtut.html
InputName=plugtut

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\Release\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\html\plugtut.html
InputName=plugtut

"$(InputName).ehtml" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe $(InputName) < $(InputPath) > $(InputName).ehtml

# End Custom Build

!ENDIF 

# End Source File
# End Group
# Begin Group "Tcl Files"

# PROP Default_Filter "tcl"
# Begin Source File

SOURCE=.\cache.tcl

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=.\cache.tcl
InputName=cache

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=.\cache.tcl
InputName=cache

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\cache_crypt.tcl

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\cache_crypt.tcl

"\src\sdr\win32\cache.tcl" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	copy $(InputPath) \src\sdr\win32\cache.tcl

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\cache_crypt.tcl

"\src\sdr\win32\cache.tcl" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	copy $(InputPath) \src\sdr\win32\cache.tcl

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\cli.tcl

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\cli.tcl
InputName=cli

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\cli.tcl
InputName=cli

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\generic.tcl

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\generic.tcl
InputName=generic

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\generic.tcl
InputName=generic

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\new.tcl

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\new.tcl
InputName=new

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\new.tcl
InputName=new

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=.\parsed_plugins.tcl

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=.\parsed_plugins.tcl
InputName=parsed_plugins

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=.\parsed_plugins.tcl
InputName=parsed_plugins

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\pgp_crypt.tcl

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\pgp_crypt.tcl
InputName=pgp_crypt

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\pgp_crypt.tcl
InputName=pgp_crypt

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\pkcs7_crypt.tcl

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\pkcs7_crypt.tcl
InputName=pkcs7_crypt

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\pkcs7_crypt.tcl
InputName=pkcs7_crypt

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\plugin2tcl.tcl

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\plugin2tcl.tcl

"parsed_plugins.tcl" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\sdr\win32\tclsh\tclsh.exe $(InputPath)

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\plugin2tcl.tcl

"parsed_plugins.tcl" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\sdr\win32\tclsh\tclsh.exe $(InputPath)

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\plugins.tcl

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\plugins.tcl
InputName=plugins

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\plugins.tcl
InputName=plugins

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\sap_crypt.tcl

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\sap_crypt.tcl
InputName=sap_crypt

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\sap_crypt.tcl
InputName=sap_crypt

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\sdp.tcl

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\sdp.tcl
InputName=sdp

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\sdp.tcl
InputName=sdp

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\sdr.tcl

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\sdr.tcl
InputName=sdr

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\sdr.tcl
InputName=sdr

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\sip.tcl

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\sip.tcl
InputName=sip

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\sip.tcl
InputName=sip

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\start_tools.tcl

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\start_tools.tcl
InputName=start_tools

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\start_tools.tcl
InputName=start_tools

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\www.tcl

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\www.tcl
InputName=www

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\www.tcl
InputName=www

"tcl_$(InputName).c" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	\src\tcl-8.0\win\tcl2c\tcl2c.exe tcl_$(InputName) < $(InputPath) > tcl_$(InputName).c

# End Custom Build

!ENDIF 

# End Source File
# End Group
# Begin Source File

SOURCE=..\src\BUGS

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\BUGS

"\src\sdr\win32\bugs.html" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	copy $(InputPath) \src\sdr\win32\bugs.html

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\BUGS

"\src\sdr\win32\bugs.html" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	copy $(InputPath) \src\sdr\win32\bugs.html

# End Custom Build

!ENDIF 

# End Source File
# Begin Source File

SOURCE=..\src\CHANGES

!IF  "$(CFG)" == "sdr - Win32 Release"

# Begin Custom Build
InputPath=..\src\CHANGES

"\src\sdr\win32\changes.html" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	copy $(InputPath) \src\sdr\win32\changes.html

# End Custom Build

!ELSEIF  "$(CFG)" == "sdr - Win32 Debug"

# Begin Custom Build
InputPath=..\src\CHANGES

"\src\sdr\win32\changes.html" : $(SOURCE) "$(INTDIR)" "$(OUTDIR)"
	copy $(InputPath) \src\sdr\win32\changes.html

# End Custom Build

!ENDIF 

# End Source File
# End Target
# End Project
