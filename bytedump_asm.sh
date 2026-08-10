# Assemble the program into bytecodes:
xa ./6502-code/program.asm -o a.o65
# Dump the bytecode into the program list.
if [ -e "a.o65" ]; then
    # `god` instead of `od` because I'm on a Mac now.
    god -v a.o65 --endian=big -t x1 | perl -pe 's/^[0-9a-f]+\s//' | tr " " "\n" > ./obj_dir/program.list
    rm a.o65
else
    echo "No file exists."
    exit -1
fi
