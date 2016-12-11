# Assemble the program into bytecodes:
xa program.asm
# Dump the bytecode into the program list.
if [ -e "a.o65" ]; then
    od a.o65 --endian=big -t x1 | perl -pe 's/^[0-9a-f]+\s//' | tr " " "\n" > program.list
    rm a.o65
else
    echo "No file exists."
    exit -1
fi
