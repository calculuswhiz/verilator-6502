# Assemble the program into bytecodes:
xa program.asm
# Dump the bytecode into the program list.
od a.o65 --endian=big -t x1 | perl -pe 's/^[0-9a-f]+\s//' | tr " " "\n" > program.list
