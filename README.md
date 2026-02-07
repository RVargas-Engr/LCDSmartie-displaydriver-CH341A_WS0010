## LCDSmartie Display Driver for CH341A + WS0010/MS0010 OLED 2x16 Module

### Intended Hardware Configuration

1) #### A WCH-IC CH341A chip to provide USB-to-parallel conversion.
   Simple breakout boards that provide this functionality can be purchased from Amazon
   as well as from a few other vendors.  This driver uses the CH341A parallel "MEM"
   signaling mode, which is compatible with the "i80" signaling mode of the OLED module.
   Power, ground, the 3 control signals, and the 8 data signals are output from the
   board to the OLED module.
2) #### A 2x16 OLED character display module powered by a Midas Displays MS0010 or Winstar WS0010 controller.
   Compatible modules include, but are not limited to, the Midas Displays MCOB21605B1V-EWP and
   the Crystalfontz CFAL1602C-W modules, which both seem to be rebrands of the same EH1602C board.  The module
   must be reconfigured to use "i80" signaling mode, also referred to as "8080" mode, as opposed to "M68",
   which is the default.  This reconfiguration done on the board itself by de-soldering a 0-ohm resistor used
   as the jumper that configures "M68" mode and then re-soldering it at the jumper location that configures
   "i80" mode.  An image file has been included in this repository that shows where the jumper is located on
   the back of the module.
3) #### A 14-pin ribbon cable wired to connect the two boards as shown below.
   Note that OLED modules containing a 2x7 header, including the 2 modules documented above, are not pin-for-pin
   compatible with the CH341A breakout board found on Amazon, so connection using an unmodified 14-pin ribbon
   cable will not work.  The following hookups are needed for a general purpose connection.
   - 8 parallel data bits, D0 through D7.
   - OLED   E control pin to CH341A pin  4 (DS#/AFD#/ROV#).
   - OLED R/W control pin to CH341A pin 25 (RW#/STB#/RDY#).
   - OLED  RS control pin to CH341A pin  3 (AS#/SIN#/IN7).
   - 5V Power.
   - Ground.
   
### Software Required

#### The Driver for LCDSmartie
This display driver is available in both 32-bit and 64-bit variants.  Both files have the same filename, which is
ch341a_ws0010.dll, and you can find them in separate subfolders in the dll folder of this GitHub repository.  Copy
the one that matches your installation of LCDSmartie to LCDSmartie's "displays" folder.  The source code is also
available in the src folder and can be compiled in Lazarus to generate the DLL file as well.

#### The Driver for the CH341A Chip
In addition to the display driver for LCDSmartie described above, the appropriate DLL file provided by WCH-IC to
interface with its CH341A chip must be downloaded from the WCH website at www.wch-ic.com and copied to a directory
of your choosing.  Look on the website for a zip file called CH341PAR.ZIP.  There are many files contained in the
zip file, but the only one you will need is either CH341DLL.DLL for 32-bit mode or CH341DLLA64.DLL for 64-bit mode.
Copy that DLL to a folder of your choosing.  The directory where LCDSmartie.exe is installed is a convenient
place for it, but you can choose another folder as well (see below).

### Software Configuration in LCDSmartie
This section describes the customizations available using the "Startup Parameters" field in the LCDSmartie GUI.
#### Default Configuration
If left empty, the following default configuration will be set up:

1) The driver will look for the appropriate DLL for the CH341A chip in the same directory as LCDSmartie.exe.  If
   you are running 32-bit mode, it will look for CH341DLL.DLL, and if you are running 64-bit mode, it will look
   for CH341DLLA64.DLL.
2) Font Table 1 (Western European Font I) is selected.
3) One character is remapped:  the backslash character (ASCII code 92) will be remapped internally to
   character code 218, which allows the displayed character to also be a backslash.  Without this remapping,
   a backslash character would be displayed instead as a Yen character.
#### Custom Configuration
If you need to make changes to any or all of the defaults described above, the text entered in the "Startup
Parameters" field must follow this format

`[DLLfolder] [|<fonttable> [|<1st remap> [|<2nd remap>[...]]]]`

where
- Spaces have been shown above only for clarity.  Do not include them in the actual text except where they are
  part of the folder name or the character involved in a remap.
- [DLLfolder] is the folder containing either the CH341DLL.DLL file (for 32-bit mode) or the CH341DLLA64.DLL file
  (for 64-bit mode).  If [DLLfolder] is omitted, the DLL folder defaults to the directory containing the
  LCDSmartie executable.  Do not include the name of the DLL file itself here.
- \<fonttable\> is an integer between 0 and 3 that selects the font table used by the display module.  For both
  the MS0010 and the WS0010, the font tables are:
  - 0 = English-Japanese
  - 1 = Western European font 1
  - 2 = English-Russian
  - 3 = Western European font 2
- \<1st remap\>,\<2nd remap\>,... Each of these represents a character remapping, for example, changing every
  capital "A" in the input string to a lowercase "a" to be written out to the display.  A total of 128 remappings
  can be specified.
##### More on Character Remapping
The syntax for a remap has the following format:<br/>

`<input character> > <output character>`<br/>

Again, the spaces shown here are only for clarity.  Do not actually embed a space unless it is the actual
character involved in the remap.  For example, to specify that all "A" characters are to be replaced with "a"
characters, use:<br/>

`A>a`<br/>

Alternatively, this same remapping can be specified using the ASCII code for the input character and the
current font table's code for the output character (see below for an explanation):<br/>

`65>97`<br/>

When specified this way, prefix any single-digit codes with a 0 to prevent the parser from misinterpreting the
single digit as the character to remap.  In other words, to remap code 2 to code 27, use:<br/>

`02>27`<br/>

To specify more than one remapping, separate each remap with a vertical bar (|) character.  A total of 128
remappings can be specified this way.  Here is an example showing 3 remappings to be applied:<br/>

`A>a|62>124|92>218`<br/>

In the above example:
1) "A" letters in the input string will be displayed as "a".
2) All occurrences of the character with code 62, which is the ASCII code for the greater-than symbol ">",
   will be displayed instead as the character having code 124 in the selected font table.
   - In font tables 0, 1, and 3, it displays as the vertical bar "|".
   - In font table 2, it displays as a small single-character "12".<br/>
   - It is important to note that, as indicated here, characters in the different font pages may or may not
     always align with their ASCII symbols.  The ASCII symbol for code 124 is the vertical bar, so for this
     character at least, font tables 0, 1, and 3 align with the ASCII equivalent, while font table 2 does not.
3) All occurrences of the character with ASCII code 92, which is the backslash character "\\", will display
   as the character represented by code 218 in the current font table.  This particular mapping is useful in
   font table 1, where code 218 is the backslash character.  It allows ASCII backslash characters to correctly
   display as backslash characters when that font table is the selected one instead of having the Yen
   character display, which is what would happen without this remap.
   
#### Final Example: The Text String for the Default Configuration

Putting it all together, here is what the driver actually passes to the parsing routing if you leave the "Startup
Parameters" field empty to get the default:<br/>

`|1|92>218`<br/>

which, as documented earlier, configures:
1) The driver will look for the appropriate WCH DLL in the directory in which the LCDSmartie.exe executable
   exists, since [DLLfolder] is blank.
2) The font page will be set to 1.
3) There is a single character remapping: ASCII code 92 remaps to code 218.  This is the same backslash remap
   that was already described in the example above.
