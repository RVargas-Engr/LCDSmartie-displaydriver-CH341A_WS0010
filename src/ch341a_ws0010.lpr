// ch341a_ws0010.lpr
// Display driver for LCDSmartie for a MS0010/WS0010 controller in i80
// mode driving a 2x16 character OLED and being driven by a WCH-IC CH341A
// USB-to-parallel adapter module.
//
// Copyright (C) 2026  Roy Vargas
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program; if not, write to the Free Software Foundation, Inc.,
// 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

// This project resides on GitHub at
// github.com/RVargas-Engr/LCDSmartie-displaydriver-CH341A_WS0010


library ch341a_ws0010;

{$MODE Delphi}

{.$R *.res}

uses
  Windows,SysUtils,Math,Process;

const
  DLLProjectName = 'CH341A-to-MS0010/WS0010(i80) 2x16 OLED DLL';
  Version = 'v1.0';
  // Define the name of the CH341A driver provided by WCH that we
  // will need to load to send commands to the chip.  You can get this
  // DLL by going to https://www.wch-ic.com/downloads/CH341PAR_ZIP.html.
  // Version 2.5 was used for initial development, but v2.6 also seems to
  // work.

  // In Lazarus->Project->Project Options->Compiler Options, select either
  // "Debug x32" or "Release x32" to compile a 32-bit DLL that looks for the
  // 32-bit WCH CH341DLL.DLL file, or select "Debug x64" or "Release x64" to
  // compile a 64-bit DLL that looks for the 64-bit WCH CH341DLLA64.DLL.
  {$IFDEF x32}
    ch341a_hw_driver = 'CH341DLL.DLL';
  {$ELSE}
    ch341a_hw_driver = 'CH341DLLA64.DLL';
  {$ENDIF}

type
  pboolean = ^boolean;
  TCustomArray = array[0..7] of byte;

const
  // delays required by device
  // The following delay amounts were copied directly from HD44780 driver
  // and have not been optimized for the MS0010 or WS0010 controller.
  // Therefore, it may be possible to use smaller delays.
  uiDelayShort = 40;
  uiDelayMed = 100;
  uiDelayLong = 1600;
  uiDelayInit = 4100;
  // control functions
  SetPos = 128;   // bit D7 = HIGH
  SetCGPos = 64;  // bit D6 = HIGH
  // "Function Set" instruction (D5=1).
  FuncSet = 32;
  FSInterface8Bit = 16;
  FSInterface4Bit = 0;
  FSTwoLine = 8;
  FSOneLine = 0;
  FS5x10Font = 4;
  FS5x8Font = 0;
  FSWestEur2Chars = 3;
  FSEngRusChars = 2;
  FSWestEur1Chars = 1;
  FSEngJapChars = 0;
  // "Display ON/OFF Control" instruction (D3=1).
  OnOffCtrl = 8;
  OODisplayOn = 4;
  OODisplayOff = 0;
  OOCursorOn = 2;
  OOCursorOff = 0;
  OOCursorBlink = 1;
  OOCursorNoBlink = 0;
  // "Entry Mode Set" instruction (D2=1).
  EntryMode = 4;
  EMIncrement = 2;
  EMDecrement = 0;
  EMShift = 1;
  EMNoShift = 0;
  // "Cursor Home" instruction (D1=1).
  HomeCursor = 2;
  // "Clear Screen" instruction (D0=1).
  ClearScreen = 1;


var
  FrameBuffer       : array[1..2] of array[1..20] of char;
  CH341A_DLL        : HMODULE = 0;
  result_str        : AnsiString;
  cursorx           : Word;
  width             : Byte;
  bHighResTimers    : Boolean = False;
  iHighResTimerFreq : Int64;
  num_remaps        : Integer;
  remap_table       : array[0..255] of Byte;
  // In Lazarus->Project->Project Options->Compiler Options, select either
  // "Debug x32" or "Debug x64" to compile the DLL with DEBUG defined, or
  // select "Release x32" or "Release x64" to compile the DLL with DEBUG
  // undefined.
  {$IFDEF DEBUG}
    debug_mode      : Boolean = True;
  {$ELSE}
    debug_mode      : Boolean = False;
  {$ENDIF}

type
  TCH341OpenDevice =  function(iIndex : ULONG) : Boolean; stdcall;
  TCH341CloseDevice = procedure(iIndex : ULONG); stdcall;
  TCH341GetDeviceDescr = function(iIndex : ULONG;
                                  oBuffer : PVOID;
                                  ioLength : PULONG) : Boolean; cdecl;
  TCH341InitParallel = function(iIndex : ULONG;
                                iMode : ULONG) : BOOL; stdcall;
  TCH341MemWriteAddr0 = function(iIndex : ULONG;
                                iBuffer : PVOID;
                                ioLength : PULONG) : BOOL; stdcall;
  TCH341MemWriteAddr1 = function(iIndex : ULONG;
                                iBuffer : PVOID;
                                ioLength : PULONG) : BOOL; stdcall;
  //// The following types represent functions that are available in the CH341A
  //// DLL from the manufacturer, but they are not used in this LCDSmartie driver
  //// and have been commented out to prevent compiler warnings.
  //TCH341SetParaMode = function(iIndex : ULONG;
  //                             iMode : ULONG) : BOOL; stdcall;
  //TCH341EppReadAddr = function(iIndex : ULONG;
  //                             oBuffer : PVOID;
  //                             ioLength : PULONG) : BOOL; cdecl;
  //TCH341EppReadData = function(iIndex : ULONG;
  //                             oBuffer : PVOID;
  //                             ioLength : PULONG) : BOOL; stdcall;
  //TCH341EppWriteAddr = function(iIndex : ULONG;
  //                              iBuffer : PVOID;
  //                              ioLength : PULONG) : BOOL; stdcall;
  //TCH341EppWriteData = function(iIndex : ULONG;
  //                              iBuffer : PVOID;
  //                              ioLength : PULONG) : BOOL; stdcall;
  //TCH341EppSetAddr = function(iIndex : ULONG;
  //                            iAddr : UCHAR) : BOOL; cdecl;
  //TCH341SetOutput = function(iIndex : ULONG;
  //                           iEnable : ULONG;
  //                           iSetDirOut : ULONG;
  //                           iSetDataOut : ULONG) : BOOL; stdcall;
  //TCH341GetVersion = function() : ULONG; cdecl;

var
  CH341OpenDevice  : TCH341OpenDevice = nil;
  CH341CloseDevice : TCH341CloseDevice = nil;
  CH341GetDeviceDescr : TCH341GetDeviceDescr = nil;
  CH341InitParallel   : TCH341InitParallel = nil;
  CH341MemWriteAddr0   : TCH341MemWriteAddr0 = nil;
  CH341MemWriteAddr1   : TCH341MemWriteAddr1 = nil;

  //// The following function pointers are placeholders for functions that are
  //// available in the CH341A DLL from the manufacturer but are not used in this
  //// LCDSmartie driver.  They have been commented out to prevent unnecessary
  //// compiler warnings.
  //CH341SetParaMode    : TCH341SetParaMode = nil;
  //CH341EppReadAddr    : TCH341EppReadAddr = nil;
  //CH341EppReadData    : TCH341EppReadData = nil;
  //CH341EppWriteAddr   : TCH341EppWriteAddr = nil;
  //CH341EppWriteData   : TCH341EppWriteData = nil;
  //CH341EppSetAddr     : TCH341EppSetAddr = nil;
  //CH341SetOutput       : TCH341SetOutput = nil;
  //CH341GetVersion     : TCH341GetVersion = nil;


//  Declare any forward references.
procedure writedata(const x: Byte); forward;


//  Name: log_to_file
//
//  Description:
//        This function will write the specified text to
//        a log file in the LCDSmartie program directory.
//
function log_to_file(p : PChar) : Boolean;
var
  f : TextFile;
begin
  AssignFile(f, 'lcdsmartie_ch341a_ws0010_driver.log');
  {$I+}
  try
    Append(f);
    WriteLn(f, p);
    CloseFile(f);
    result := true;
  except
    on E: EInOutError do begin
      // The file probably does not exist, so use ReWrite() to
      // create it from scratch.
      try
        ReWrite(f);
        WriteLn(f,p);
        CloseFile(f);
        result := true;
      except
        on E: EInOutError do begin
          result := false;
        end;
      end;
    end;
    on E: Exception do
      // The file probably does not exist, so use ReWrite() to create it from
      // scratch.
      try
        ReWrite(f);
        WriteLn(f,p);
        CloseFile(f);
        result := true;
      except
        on E: EInOutError do begin
          result := false;
        end;
      end;
  end;
end;


//  Name: delay_microsec
//
//  Description:
//        This function will delay program execution by the
//        specified number of microseconds.  This function has
//        been copied from the HD44780 driver and accounts for
//        the fact that we don't check the BUSY signal from the
//        display module.
//
procedure delay_microsec(uiUsecs: Cardinal);
var
 uiElapsed    : int64;
 uiUsecsScaled: int64;
 iBegin, iCurr: int64;
begin
 {$R-}

 uiUsecsScaled := int64(uiUsecs);

 if (uiUsecs <= 0) then Exit;

 if (bHighResTimers) then begin
   iBegin := 0;
   iCurr := 0;
   QueryPerformanceCounter(iBegin);

	  repeat
     QueryPerformanceCounter(iCurr);

     if (iCurr < iBegin) then iBegin := 0;
		  uiElapsed := ((iCurr - iBegin) * 1000000) div iHighResTimerFreq;

	  until (uiElapsed > uiUsecsScaled);
 end else begin
   raise exception.create('PerformanceCounter not supported on this system');
 end;

 {$R+}
end;


//  Name: writectrl
//
//  Description:
//        This function will issue a control command to the MS0010/WS0010
//        controller.
//
procedure writectrl(const x: Byte);
var
  datalen    : ULONG;
  boolresult : Boolean;
begin
  datalen := 1;
  boolresult := CH341MemWriteAddr0(0, @x, @datalen);
  if (boolresult <> True) then begin
    result_str := FormatDateTime('yyyy-mm-dd hh:mm:ss.zzz', Now()) +
                  ': call to CH341MemWriteAddr0 failed.' + #0;
    log_to_file(PChar(result_str));
  end;
end;


//  Name: writedata
//
// Description:
//        This function will write a single character to the display at
//        its current cursor position.
//
procedure writedata(const x: Byte);
var
  datalen    : ULONG;
  boolresult : Boolean;
begin
  datalen := 1;
  boolresult := CH341MemWriteAddr1(0, @x, @datalen);
  if (boolresult <> True) then begin
    result_str := FormatDateTime('yyyy-mm-dd hh:mm:ss.zzz', Now()) +
                  ': CH341MemWriteAddr1 failed.' + #0;
    log_to_file(PChar(result_str));
  end;
  delay_microsec(uiDelayMed);
end;


//  Name: DISPLAYDLL_Init
//
//  Description:
//        This is the function that LCDSmartie calls to initialize the display.
//
//  Arguments:
//        SizeX,SizeY
//            not used here; this driver assumes a 2x16 display regardless
//            what values are passed in.
//        StartupParameters
//            This is the string that the user enters in the GUI.  It can be left
//            empty for the default configuration, but otherwise it needs to follow
//            this format:
//                [<DLLfolder>][|<fontpage>[|<1st remap>[|<2nd remap[...]>]]]
//            where
//                <DLLfolder> is the folder containing either the CH341DLL.DLL file
//                  (for 32-bit mode) or the CH341DLLA64.DLL (for 64-bit mode).
//                  If omitted, the DLL folder defaults to the directory containing
//                  the LCDSmartie executable.
//
//                <fontpage> is an integer between 0 and 3 that selects the font page
//                  used by the display module.  For both the MS0010 and the WS0010,
//                  the font pages are:
//                  0 = English-Japanese
//                  1 = Western European font 1
//                  2 = English-Russian
//                  3 = Western European font 2
//
//                <1st remap>,<2nd remap>,... Each of these represents a character
//                  remapping, for example, changing every capital "A" in the input
//                  string to a lowercase "a" to be written out to the display.  A
//                  total of 128 remappings can be specified.
//                  The syntax for a remap has the following format:
//                  <input character>><output character>
//                  For example, to specify that all "A" characters are to be replaced
//                  with "a" characters, use:
//                    A>a
//                  Alternatively, this same remapping can be specified using the
//                  ASCII code for the input character and the current font page's code
//                  for the output character (see below for an explanation):
//                    65>97
//                  When specified this way, prefix any single-digit codes with a 0 to
//                  prevent the parser from confusing the single digit as the character
//                  to remap.  In other words, to remap code 2 to code 27, use
//                    02>27
//                  To specify more than one remapping, separate each remap with a
//                  vertical bar (|) character.  A total of 128 remappings can be
//                  specified this way.
//                  Here is an example showing 3 remappings to be applied:
//                    A>a|62>124|92>218
//                  In the above example:
//                    1) "A" letters in the input string will be displayed as "a".
//                    2) All occurrences of the character with code 62, which is the
//                       ASCII code for the greater-than symbol ">", will be displayed
//                       instead as the character with code 124, which, here, depends on
//                       the selected font page.  In font pages 0, 1, and 3, it displays
//                       as the vertical bar "|", but in font page 2, it displays as a
//                       small single-character "12".
//                       It is important to note that, as indicated here, characters in
//                       the different font pages may or may not always align with their
//                       ASCII symbols.  The ASCII symbol for code 124 is the vertical
//                       bar, so for this character at least, font pages 0, 1, and 3
//                       align with the ASCII equivalent, which font page 2 does not.
//                    3) All occurrences of the character with ASCII code 92, which is
//                       the backslash character "\", will display as the character
//                       represented by code 218 in the current font page.
//                       This particular mapping is useful in font page 1, where code 218
//                       is the backslash character.  It allows ASCII backslash characters
//                       to also display as backslash characters in that font page instead
//                       of the Yen character, which is code 92 in font page 1.
//
//            If StartupParameters is left empty, the default configuration is:
//              |1|92<218
//            which configures:
//            1) The location in which the DLL resides is the directory in which the
//               LCDSmartie.exe executable exists.
//            2) The font page is set to 1.
//            3) There is a single character remapped: ASCII code 92 (backslash) remaps to
//               code 218 (backslash in font page 1), thereby preserving the display of
//               the backslash character.
//
function DISPLAYDLL_Init(SizeX,SizeY : byte; StartupParameters : pchar; OK : pboolean) : pchar; stdcall;
const
  remap_max = 128;  // maximum number of character remappings
var
  Path             : string;
  time_now_str     : String;
  boolresult       : Boolean;
  i                : Integer;
  vertbarptr       : array[0..remap_max+1] of PChar;
  vb_count         : Integer;
  temp_buf         : array[0..9] of char;
  font_page        : Integer;
  gtptr            : PChar;
  remap_in         : Integer;
  remap_out        : Integer;
  default_params   : array[0..10] of Char = '|1|92>218';
begin
  if debug_mode then begin
    time_now_str := FormatDateTime('yyyy-mm-dd hh:mm:ss.zzz', Now());
    log_to_file(PChar(time_now_str + ': Begin DISPLAYDLL_Init.'));
  end;

  OK^ := true;
  result_str := DLLProjectName + ' ' + Version + #0;
  result := PChar(result_str);
  fillchar(FrameBuffer,sizeof(FrameBuffer),$00);
  cursorx := 1;
  width := 16;

  bHighResTimers := QueryPerformanceFrequency(iHighResTimerFreq);

  // See if StartupParameters is empty.
  if length(StartupParameters) = 0 then begin
    // Point StartupParameters to our 'default_params' instead.
    StartupParameters := default_params;
  end;

  try
    // Look for up to remap_max+1 vertical bar characters in the passed in string.
    vb_count := 0;
    // Find the first vertical bar, if it exists.
    vertbarptr[0] := StrScan(StartupParameters, '|');
    // Now use a loop to look for up to remap_max more vertical bars.
    if vertbarptr[0] <> nil then begin
      repeat
        vb_count := vb_count + 1;
        vertbarptr[vb_count] := StrScan(vertbarptr[vb_count-1]+1, '|');
      until ((vb_count = remap_max+1) or (vertbarptr[vb_count] = nil));
    end;

    if vb_count = remap_max+1 then begin
      // We've located all the vertical bars we can handle.  The one in index
      // 5 is actually going to be used only to tell us where to terminate the
      // substring for the remap that comes just before it.  We'll ignore any
      // text that follows it.
      vb_count := vb_count - 1;
    end else begin
      // We did not locate our full allotment of vertical bars.
      // Add one more entry to vertbarptr array to point to the string
      // terminator, as this will make the following code less complicated to
      // implement.
      vertbarptr[vb_count] := StartupParameters+strlen(StartupParameters);
    end;

    // The substring before the 1st vertical bar (if there is one) is the
    // folder name containing the DLL.
    if vb_count > 0 then begin
      // There is a vertical bar, so the path substring will end there.
      Path := copy(StartupParameters, 1, vertbarptr[0]-StartupParameters);
    end else begin
      // There is no vertical bar specified, so the path substring is the entire
      // string that was passed in.
      Path := trim(string(StartupParameters));
    end;

    // Next, we'll see if a font table has been specified.  This comes after
    // the 1st vertical bar.
    font_page := 0;
    if vb_count >= 1 then begin
      font_page := StrToInt(strlcopy(temp_buf, vertbarptr[0]+1,
                       min(vertbarptr[1]-vertbarptr[0]-1, sizeof(temp_buf)-1)));

      if debug_mode then
        log_to_file(PChar('Font page ' + IntToStr(font_page) + ' has been selected.'));

      if ((font_page < 0) or (font_page > 3)) then begin
        // This is an invalid font page.
        result_str := 'Font Page must be an integer between 0 and 3.' + #0;
        result := PChar(result_str);
        OK^ := false;
        log_to_file(PChar('Exit DISPLAY_DLL_Init: Invalid font page specified.'));
        exit(result);
      end;
    end;

    // If there were more than 1 vertical bars found, that means that the user
    // has specified one or more character code remapping pairs.
    num_remaps := 0;
    if vb_count >= 2 then begin
      // Each remapping pair is of the form (oldcode)>(newcode), i.e., two
      // integers between 0 and 255 separated by a single "greater than" symbol.
      // Begin by initializing the remap table with no remapping.
      for i := 0 to 255 do begin
        remap_table[i] := i;
      end;

      i := 1;
      repeat
        // Look for the greater than symbol in the substring.
        gtptr := StrScan(vertbarptr[i], '>');
        if gtptr <> nil then begin
          // Extract the text identifying the input character for the remap.
          strlcopy(temp_buf, vertbarptr[i]+1, min(gtptr-vertbarptr[i]-1,
                                                  sizeof(temp_buf)-1));

          // Decide whether it's a numeric representation or a single char
          // by looking at the length of the extracted string.
          if strlen(temp_buf) = 1 then begin
            // With a length of 1, we'll interpret this as a character.
            remap_in := Ord(temp_buf[0]);
          end else begin
            // With a length greater than 1, we'll interpret this as an integer
            // character code.
            remap_in := StrToInt(temp_buf);
          end;

          //  Extract the text identifying the output character for the remap.
          strlcopy(temp_buf, gtptr+1, min(vertbarptr[i+1]-gtptr-1,
                                          sizeof(temp_buf)-1));

          // Decide whether it's a numeric representation or a single char
          // by looking at the length of the extracted string.
          if strlen(temp_buf) = 1 then begin
            // With a length of 1, we'll interpret this as a character.
            remap_out := Ord(temp_buf[0]);
          end else begin
            // With a length greater than 1, we'll interpret this as an integer
            // character code.
            remap_out := StrToInt(temp_buf);
          end;

          // Update the remap table for this character's entry.
          remap_table[remap_in] := remap_out;

          if debug_mode then
            log_to_file(PChar('remap: ' + IntToStr(remap_in) + ' to ' + IntToStr(remap_out)));

          num_remaps := num_remaps + 1;
        end;
        i := i + 1;
      until i > vb_count;
    end;

    if debug_mode and (num_remaps > 0) then
      log_to_file(PChar('There are ' + IntToStr(num_remaps) + ' remapped characters.'));

    if (length(Path) > 0) then begin
      Path := includetrailingpathdelimiter(Path);
    end;
    CH341A_DLL := LoadLibrary(pchar(Path+ch341a_hw_driver + #0));
    if (CH341A_DLL = 0) then begin
      result_str := ch341a_hw_driver+' Exception: <'+Path+ch341a_hw_driver+'> not found!' + #0;
      result := PChar(result_str);
      OK^ := false;
      log_to_file(PChar('Exit DISPLAY_DLL_Init: Could not load DLL: ' + result_str));
      exit(result);
    end;

    CH341OpenDevice  := getprocaddress(CH341A_DLL, pchar('CH341OpenDevice' + #0));
    CH341CloseDevice := getprocaddress(CH341A_DLL, pchar('CH341CloseDevice' + #0));
    CH341GetDeviceDescr := getprocaddress(CH341A_DLL, pchar('CH341GetDeviceDescr' + #0));
    CH341InitParallel   := getprocaddress(CH341A_DLL, pchar('CH341InitParallel' + #0));
    CH341MemWriteAddr0   := getprocaddress(CH341A_DLL, pchar('CH341MemWriteAddr0' + #0));
    CH341MemWriteAddr1   := getprocaddress(CH341A_DLL, pchar('CH341MemWriteAddr1' + #0));

    //// The following functions are also available from the CH341A DLL from the
    //// manufacturer but are not used in this LCDSmartie driver, so they remain
    //// commented out to limit compilation warnings.
    //CH341SetParaMode    := getprocaddress(CH341A_DLL, pchar('CH341SetParaMode' + #0));
    //CH341EppReadAddr    := getprocaddress(CH341A_DLL, pchar('CH341EppReadAddr' + #0));
    //CH341EppReadData    := getprocaddress(CH341A_DLL, pchar('CH341EppReadData' + #0));
    //CH341EppWriteAddr   := getprocaddress(CH341A_DLL, pchar('CH341EppWriteAddr' + #0));
    //CH341EppWriteData   := getprocaddress(CH341A_DLL, pchar('CH341EppWriteData' + #0));
    //CH341EppSetAddr     := getprocaddress(CH341A_DLL, pchar('CH341EppSetAddr' + #0));
    //CH341SetOutput      := getprocaddress(CH341A_DLL, pchar('CH341SetOutput' + #0));
    //CH341GetVersion     := getprocaddress(CH341A_DLL, pchar('CH341GetVersion' + #0));

    if not assigned(CH341OpenDevice) then begin
      OK^ := false;
      result := PChar('CH341OpenDevice undefined.' + #0);
      log_to_file(result);
      exit(result);
    end;
    if not assigned(CH341CloseDevice) then begin
      OK^ := false;
      result := PChar('CH341CloseDevice undefined.' + #0);
      log_to_file(result);
      exit(result);
    end;
    if not assigned(CH341GetDeviceDescr) then begin
      OK^ := false;
      result := PChar('CH341GetDeviceDescr undefined.' + #0);
      log_to_file(result);
      exit(result);
    end;

  except
    on E: Exception do begin
      result_str := ch341a_hw_driver + ' Exception: ' + E.Message + #0;
      result := PChar(result_str);
      OK^ := false;
      log_to_file(result);
      exit(result);
    end;
  end;

  // Un-initialize the CH341 module to get it to a known state, even if it was
  // already un-initialized.
  CH341CloseDevice(0);
  if debug_mode then
    log_to_file('CH341 has been un-initialized.');

  // At this point, we have loaded the DLL and un-initialized the CH341 module.
  // Next, we try to open the module.
  boolresult := CH341OpenDevice(0);
  if (boolresult <> True) then begin
    result_str := 'CH341OpenDevice returned error code ' + IntToStr(QWord(boolresult)) + #0;
    result := PChar(result_str);
    OK^ := false;
    log_to_file(result);
    exit(result);
  end;
  if debug_mode then
    log_to_file('Finished calling CH341OpenDevice.');


  // Initialize the CH341A to use MEM parallel mode.
  boolresult := CH341InitParallel(0, 2);
  if (boolresult <> True) then begin
    result_str := 'CH341InitParallel returned error code ' + IntToStr(QWord(boolresult)) + #0;
    result := PChar(result_str);
    OK^ := false;
    log_to_file(result);
    exit(result);
  end;
  if debug_mode then
    log_to_file(PChar('CH341A has been set to MEM parallel mode.'));


  // The following sequence of instructions mostly parallels what is done in
  // the HD44780 driver initialization routine.  Delays that are implemented
  // here have not been tuned for the MS/WS0010 controller and may not even be
  // needed.

  // Issue the "Function Set" instruction with the following configuration:
  // 1) 8-bit addressing
  // 2) 2-line display
  // 3) small (5x8) character font size, not 5x10 size
  //
  // In the original HD44780, there was only one font table, and bits 1:0
  // were reserved and just set to zero.  For the Winstar WS0010 and Midas
  // Displays MS0010, bits 1:0 need to be set to indicate one of four font
  // tables to use for the display.
  // 4) Unless overridden by the user, the default font table is set to 1,
  //    which is for Western European Font I.

  // Here, font_page conveniently maps perfectly to the lowest 2 bits.
  writectrl(FuncSet or FSInterface8Bit or FSTwoLine or FS5x8Font or font_page);

  delay_microsec(uiDelayInit);

  if debug_mode then
    log_to_file(PChar('Sent Function Set instruction.'));

  // Issue the "Display ON/OFF Control" instruction with the following config:
  // 1) display is turned off
  // 2) cursor is off
  // 3) cursor is not blinking
  writectrl(OnOffCtrl or OODisplayOff or OOCursorOff or OOCursorNoBlink);
  delay_microsec(uiDelayShort);

  // Issue the "Clear Screen" instruction.
  writectrl(ClearScreen);
  delay_microsec(uiDelayLong);

  // Issue the "Entry Mode Set" instruction.
  writectrl(EntryMode or EMIncrement or EMNoShift);
  delay_microsec(uiDelayMed);

  // Initialize some custom characters.  This is not a necessary
  // step, but just done for convenience.
  writectrl(SetCGPos or $00);
  // Custom Character 0 or 8.
  writedata($00);
  writedata($00);
  writedata($00);
  writedata($00);
  writedata($00);
  writedata($00);
  writedata($00);
  writedata($1F); // cursor position
  // Custom Character 1 or 9.
  writedata(0);
  writedata(0);
  writedata(0);
  writedata(0);
  writedata(0);
  writedata(0);
  writedata($1F);
  writedata($1F); // cursor position
  // Custom Character 2 or 10.
  writedata(0);
  writedata(0);
  writedata(0);
  writedata(0);
  writedata(0);
  writedata($1F);
  writedata($1F);
  writedata($1F); // cursor position
  // Custom Character 3 or 11.
  writedata(0);
  writedata(0);
  writedata(0);
  writedata(0);
  writedata($1F);
  writedata($1F);
  writedata($1F);
  writedata($1F); // cursor position
  // Custom Character 4 or 12.
  writedata(0);
  writedata(0);
  writedata(0);
  writedata($1F);
  writedata($1F);
  writedata($1F);
  writedata($1F);
  writedata($1F); // cursor position
  // Custom Character 5 or 13.
  writedata(0);
  writedata(0);
  writedata($1F);
  writedata($1F);
  writedata($1F);
  writedata($1F);
  writedata($1F);
  writedata($1F); // cursor position
  // Custom Character 6 or 14.
  writedata(0);
  writedata($1F);
  writedata($1F);
  writedata($1F);
  writedata($1F);
  writedata($1F);
  writedata($1F);
  writedata($1F); // cursor position
  // Custom Character 7 or 15.
  writedata($1F);
  writedata($1F);
  writedata($1F);
  writedata($1F);
  writedata($1F);
  writedata($1F);
  writedata($1F);
  writedata($1F); // cursor position

  // Issue the "Display ON/OFF Control" instruction with the following config:
  // 1) display is turned on
  // 2) cursor is off
  // 3) cursor is not blinking
  writectrl(OnOffCtrl or  OODisplayOn or OOCursorOff or OOCursorNoBlink);
  delay_microsec(uiDelayLong);

  // Issue the "Cursor Home" instruction.
  writectrl(HomeCursor);
  delay_microsec(uiDelayLong);

  if debug_mode then begin
    log_to_file(PChar('Sent Cursor Home instruction.'));

    time_now_str := FormatDateTime('yyyy-mm-dd hh:mm:ss.zzz', Now());
    log_to_file(PChar(time_now_str +
          ': Exit DISPLAYDLL_Init function.  Successful connection made.'));
  end;
end;


//  Name: DISPLAYDLL_Done
//
//  Description:
//        This function is called by LCDSmartie when shutting down the display.
//
procedure DISPLAYDLL_Done(); stdcall;
var
  time_now_str : String;
begin
  if debug_mode then begin
    time_now_str := FormatDateTime('yyyy-mm-dd hh:mm:ss.zzz', Now());
    log_to_file(PChar(time_now_str + ': Begin DISPLAYDLL_Done().'));
  end;

  // Issue the "Clear Screen" instruction.
  writectrl(ClearScreen);
  delay_microsec(uiDelayLong);

  try
    CH341CloseDevice(0);
    if debug_mode then
      log_to_file('CH341CloseDevice() has been called.');

    if not (CH341A_DLL = 0) then begin
      FreeLibrary(CH341A_DLL);
      if debug_mode then
        log_to_file(PChar('DLL CH341DLL.dll has been freed.'));
    end;
  except
    log_to_file('Exception raised when uninitializing the CH341A module.');
  end;

  if debug_mode then begin
    time_now_str := FormatDateTime('yyyy-mm-dd hh:mm:ss.zzz', Now());
    log_to_file(PChar(time_now_str + ': Exit DISPLAYDLL_Done().'));
  end;
end;


//  Name: DISPLAYDLL_CustomChar
//
//  Description:
//        This function is called by LCDSmartie when the user's control code
//        requests to change one of the custom character bitmaps.
//
procedure DISPLAYDLL_CustomChar(Chr : byte; Data : TCustomArray); stdcall;
// define custom character
var
  i: Byte;
begin
    writectrl(SetCGPos + ((Chr-1) * 8));
    try
      for i := 0 to 7 do
        writedata(Data[i]);
    finally
    end;
end;


//  Name: DISPLAYDLL_CustomCharIndex
//
//  Description:
//        This function is called by LCDSmartie to query the character code
//        offset that must be used when accessing a custom character that was
//        previously programmed.
//
//        The Index passed in is a value between 1 and 8, while the character
//        codes for the custom characters in the WS0010 and MS0010 controller
//        are in the range 0-7 and mirrored at codes 8-15.  In order to avoid
//        potential problems with referring to a character at code 0 (since
//        0 is also the string termination character in some languages), the
//        preferred range to use is 8-15.  Therefore, the offset (index) to
//        return here is 8-1 = 7.  This means custom character #1 will be
//        accessed using code 8.
function DISPLAYDLL_CustomCharIndex(Index : byte) : byte; stdcall;
begin
  DISPLAYDLL_CustomCharIndex := Index + 7; // 8-15
end;


//  Name: DISPLAYDLL_Write
//
//  Description:
//        This function is called by LCDSmartie to write a string to the
//        display.
//
procedure DISPLAYDLL_Write(Str : pchar); stdcall;
var
  i          : Byte;
  linebuf    : array[0..99] of Char;
  boolresult : Boolean;
  num_chars  : Integer;
begin
  //// The following is commented out because, even in debug mode, these log
  //// entries get written out a lot.  Uncomment if really needed.
  //if debug_mode then
  //  log_to_file(PChar('Inside DISPLAYDLL_Write: ' + IntToStr(length(Str)) +
  //                    ' characters to be written to display.'));

  // See if we need to be on the lookout for remapped characters.
  if num_remaps = 0 then begin
    // There is no remapping taking place, so copy the input string directly
    // to the local line buffer.
    num_chars := min(length(Str), min(width-cursorx, sizeof(linebuf)));
    strlcopy(@linebuf, Str, num_chars);
  end else begin
    // One or more characters are getting remapped, so pass each character
    // through the remap table, which should be faster overall than having to
    // check whether each individual character is one of the remapped ones.

    // First set num_chars to the minimum of:
    //   1) the number of characters remaining from the cursor point to the right edge
    //   2) the length of the passed-in String containing text to display
    //   3) the allocated size of the local line buffer array
    // We use a max(0,X) to prevent a negative number just in case item 1
    // computes to a negative number.
    num_chars := min(max(width-cursorx+1,0), min(length(Str), sizeof(linebuf)));
    for i := 0 to num_chars-1 do begin
      linebuf[i] := chr(remap_table[ord(Str[i])]);
    end;
  end;

  boolresult := CH341MemWriteAddr1(0, @linebuf, @num_chars);
  if (boolresult <> True) then begin
    result_str := 'CH341MemWriteAddr1 returned error code ' + IntToStr(QWord(boolresult)) + #0;
    log_to_file(PChar(result_str));
  end;
  cursorx := cursorx + num_chars;
end;


//  Name: DISPLAYDLL_SetPosition
//
//  Description:
//        This function is called by LCDSmartie to position the cursor of
//        the display at a particular location.
procedure DISPLAYDLL_SetPosition(X, Y: byte); stdcall;
// set cursor position
var
  tempX, tempY: Byte;
  DDaddr: Byte;
begin
  //// The following is commented out because, even in debug mode, it can
  //// result in a lot of output to the log file.  Uncomment as needed.
  //if debug_mode then
  //  log_to_file('Inside DISPLAYDLL_SetPosition.');
  
  // store these values as they are used when a write occurs.
  cursorx := x;

  tempX := x - 1;
  tempY := y - 1;

  // Display memory for line 2 of the display begins at offset $40, even if
  // the display itself is only 16 characters wide.
  DDaddr := tempX + (tempY mod 2) * $40;

  // Note: The "DDRAM Address Setting" instruction is identified by having
  // D7 bit driven HIGH, while D6-D0 hold the value of the new position to be set.
  writectrl(SetPos or DDaddr);
end;


//  Name: DISPLAYDLL_DefaultParameters
//
//  Description:
//        This function is called by LCDSmartie to get the string that
//        would need to be sent to the initialization function in order
//        to configure a default setup.
//        Here, we just return an empty string.
//
function DISPLAYDLL_DefaultParameters : pchar; stdcall;
begin
  DISPLAYDLL_DefaultParameters := pchar(#0);
end;


//  Name: DISPLAYDLL_Usage
//
//  Description:
//        This function is called by LCDSmartie to query usage information
//        for the DLL.  It will display this information on the Setup
//        dialog box as an aide to the user when configuring the DLL.
//
function DISPLAYDLL_Usage : pchar; stdcall;
begin
  Result := pchar('Usage: <dllfolder>[|<fontpage>[|<remap1-128>]]'+#13#10+
                  '<dllpath> is folder containing '+ch341a_hw_driver+','+#13#10+
                  '<fontpage> is 0-3, <remapN> is CharIn>CharOut' + #0);
end;


//  Name: DISPLAYDLL_DriverName
//
//  Description:
//        This function will return a short description to indicate
//        what is the compatible hardware for this DLL and what its
//        version number is.
//
function DISPLAYDLL_DriverName : pchar; stdcall;
begin
  Result := PChar(DLLProjectName + ' ' + Version + #0);
end;


// don't forget to export the funtions, else nothing works :)
exports
  DISPLAYDLL_Write,
  DISPLAYDLL_SetPosition,
  DISPLAYDLL_DefaultParameters,
  DISPLAYDLL_CustomChar,
  DISPLAYDLL_CustomCharIndex,
  DISPLAYDLL_Usage,
  DISPLAYDLL_DriverName,
  DISPLAYDLL_Done,
  DISPLAYDLL_Init;

{$R *.res}

begin
end.

