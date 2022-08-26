@echo off

REM    alternative to GUI can run quartos from command line
REM    in windows:
REM    need to add to path:
REM    C:\intelFPGA_lite\18.1\quartus\bin64
REM    see: https://forums.intel.com/s/question/0D50P00003yyPLiSAM/cannot-execute-quartussh-in-command-line?language=en_US
REM    quartus_sh --flow xxx.qpf
REM    can also run tcl scripting , API interface and more , see:
REM    https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/manual/tclscriptrefmnl.pdf

quartus_pgm -m jtag -o  "p;output_files\fpga_lab.sof"