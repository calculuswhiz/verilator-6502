#include "VtopLevel.h"
// Used by verilator:
#include "verilated.h"
#include "verilated_vcd_c.h"
#define DumpFileName "topLevel.vcd"

#include <cassert>
#include <cstddef>
#include <cstdint>
#include <cstdio>

#include "../lib/helpAssert.cpp"
#include "../lib/testbenchMacros.cpp"
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

void updateMemory(VtopLevel& top) {
  if (top.mem_rW == 1)
    top.mem_rData = TestMap::read(top.mem_address);
  else
    TestMap::write(top.mem_address, top.mem_wData);
}

int testProgram() {
  VtopLevel top;

  VerilatedVcdC vcdOut;
  top.trace(&vcdOut, 99);
  vcdOut.open(DumpFileName);

  uint8_t *memory = NULL;
  size_t bytesRead = readBinaryFile("./obj_dir/program.o65", memory);
  if (memory == NULL) {
    std::printf("Could not read test memory\n");
    return -1;
  }

  std::printf("Read memory for test program complete. %zuk Bytes\n",
              bytesRead / 1000);

  uint16_t romStart = 0x8000;
  std::printf("ROM region set %d\n", romStart);

  TestMap::initMap(memory, romStart);

  std::printf("Testing initial conditions\n");
  top.forceReset_n = 1;
  top.clk = 0;
  top.eval();
  vcdOut.dump(0);
  assert(testEqual(0x0000, top.dbg_PC_out));
  assert(testEqual(0, top.dbg_A_out));
  assert(testEqual(0, top.dbg_X_out));
  assert(testEqual(0, top.dbg_Y_out));
  assert(testEqual(0, top.dbg_S_out));
  assert(testEqual(0, top.dbg_P_out));
  assert(testEqual(0xf00, top.dbg_state_out));

  std::printf("Testing reset:\n");
  std::printf("boot_1\n");
  top.forceReset_n = 0;
  CycleClockWDump(top, vcdOut, 1);
  updateMemory(top);
  assert(testEqual(0xf00, top.dbg_state_out));
  assert(testEqual(0xfffc, top.dbg_PC_out));
  assert(testEqual(0xfffc, top.mem_address));
  assert(testEqual(0x00, top.mem_rData));
  std::printf("boot_2\n");
  top.forceReset_n = 1;
  updateMemory(top);
  CycleClockWDump(top, vcdOut, 3);
  assert(testEqual(0xf01, top.dbg_state_out));
  assert(testEqual(0xfffd, top.dbg_PC_out));
  assert(testEqual(0xfffd, top.mem_address));
  assert(testEqual(0x0000, top.dbg_D_out));

  updateMemory(top);
  CycleClockWDump(top, vcdOut, 5);
  assert(testEqual(0x101, top.dbg_state_out));
  assert(testEqual(0x8000, top.dbg_PC_out));

  TestMap::cleanup();
  vcdOut.close();

  return 0;
}

int main(int argc, char **argv, char **env) {
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);

  testProgram();

  std::printf("Done with %s\n", __FILE_NAME__);
  return 0;
}
