#include "VtopLevel.h"

#include <cassert>
#include <cstddef>
#include <cstdint>
#include <cstdio>

#include "../lib/helpAssert.cpp"
#include "./memoryMaps/testMap.cpp"

#define DumpFileName "topLevel.vcd"

size_t readBinaryFile(const char *fileName, uint8_t *&outBuffer) {
  FILE *file = std::fopen(fileName, "rb");
  if (file == NULL) {
    return -1;
  }

  if (std::fseek(file, 0, SEEK_END) != 0) {
    std::fclose(file);
    return -1;
  }

  long size = std::ftell(file);
  if (size < 0) {
    std::fclose(file);
    return -1;
  }

  if (std::fseek(file, 0, SEEK_SET) != 0) {
    std::fclose(file);
    return -1;
  }

  uint8_t *buffer = new uint8_t[size];
  if (buffer == NULL) {
    std::fclose(file);
    return -1;
  }

  size_t bytesRead = std::fread(buffer, 1, size, file);
  if (bytesRead < (size_t)size) {
    // Partial read check (handles EOF vs actual read error)
    if (std::ferror(file)) {
      delete[] buffer;
      std::fclose(file);
      return -1;
    }
  }

  std::fclose(file);
  outBuffer = buffer;
  return size;
}

// E.g. ./obj_dir/VtopLevel ./obj_dir/program.o65 0x700
// argv[1] - file name
// argv[2] - start rom address
int main(int argc, char **argv, char **env) {
  if (argc < 3) {
    std::printf(
        "Please specify binary file in arg 1 and rom region (hex) in arg 2");
    return -1;
  }
  std::printf("Reading %s\n", argv[1]);
  std::printf("ROM region %s\n", argv[2]);

  VtopLevel top;

  uint8_t *memory = NULL;
  size_t bytesRead = readBinaryFile(argv[1], memory);
  if (memory == NULL) {
    std::printf("Could not read binary file: %s\n", argv[1]);
    return -1;
  }

  std::printf("Read memory: %s complete. %zuk Bytes\n", argv[1],
              bytesRead / 1000);

  int romStart = 0;
  if (std::sscanf(argv[2], "%x", &romStart) != 1) {
    if (romStart > UINT16_MAX) {
      std::printf("Please specify a ROM start address <= %d\n", UINT16_MAX);
      return -1;
    }
  }

  std::printf("ROM region set %d\n", romStart);

  TestMap::initMap(memory, (uint16_t)romStart);

  // Begin test program

  int clk = 0;
  while (true) {
    top.clk = !clk;
    if (top.mem_rW == 1)
      top.mem_rData = TestMap::read(top.mem_address);
    else
      TestMap::write(top.mem_address, top.mem_wData);

    top.eval();
  }

  std::printf("Done with %s\n", __FILE_NAME__);
  TestMap::cleanup();
  return 0;
}
