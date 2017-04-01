# Make file for Drivewire over Ethernet client for CoCo

all: dwoe.dsk

dwoe.dsk: test.bin
	rm -f dwoe.dsk
	decb dskini dwoe.dsk
	decb copy -2br ./test.bin dwoe.dsk,TEST.BIN

test.bin: test.asm
	lwasm -f obj -o test.o test.asm
	lwasm -f obj -o coconic.o coconic.asm
	lwlink -b -m test.map -o test.bin test.o coconic.o

clean: 
	rm -f test.bin dwoe.dsk test.o coconic.o