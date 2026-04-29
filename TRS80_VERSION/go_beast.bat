as\bin\asl.exe BEAST.ASM -L
as\bin\p2bin.exe BEAST.p
rem bin2hex.exe --i BEAST.bin --o test.c --s " "
python bin2ihex.py BEAST.bin test.hex 5200
