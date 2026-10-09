#include "VtopLevel.h"
// Used by verilator:
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <cassert>
#include <cstddef>
#include <cstdint>
#include <cstdio>

#include "../lib/helpAssert.cpp"
#include "../lib/testbenchMacros.cpp"
#include "./memoryMaps/testMap.cpp"

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

// Update the memory bus (should be called every cycle)
void updateMemory(VtopLevel &top) {
  if (top.mem_rW == 1)
    top.mem_rData = TestMap::read(top.mem_address);
  else
    TestMap::write(top.mem_address, top.mem_wData);
}

// Drive the reset signals for the tests
void reset(VtopLevel &top, VerilatedVcdC &vcdOut, bool printForTest) {
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

  if (printForTest) {
    std::printf("Testing reset:\n");
    std::printf("boot_1\n");
  }
  top.forceReset_n = 0;
  CycleClockWDump(top, vcdOut, 1);
  updateMemory(top);
  assert(testEqual(0xf00, top.dbg_state_out));
  assert(testEqual(0xfffc, top.dbg_PC_out));

  if (printForTest)
    std::printf("boot_2\n");

  top.forceReset_n = 1;
  updateMemory(top);
  CycleClockWDump(top, vcdOut, 3);
  assert(testEqual(0xf01, top.dbg_state_out));
  assert(testEqual(0xfffd, top.dbg_PC_out));

  updateMemory(top);
  CycleClockWDump(top, vcdOut, 5);
  assert(testEqual(0x101, top.dbg_state_out));
  assert(testEqual(0x8000, top.dbg_PC_out));
}

/** Tests the reset procedure */
void testReset(VtopLevel& top, VerilatedVcdC& vcdOut) {
  const char *vcdFile = "reset_test.vcd";
  const char *programFile = "./obj_dir/reset.test.o65";

  vcdOut.open(vcdFile);

  uint8_t *memory = NULL;
  size_t bytesRead = readBinaryFile(programFile, memory);
  if (memory == NULL) {
    std::printf("Could not read test memory\n");
    return;
  }

  uint16_t romStart = 0x8000;
  TestMap::initMap(memory, romStart);

  reset(top, vcdOut, true);

  TestMap::cleanup();
}

/** Tests the JMP instruction */
void testJmp(VtopLevel& top, VerilatedVcdC& vcdOut) {
  const char *vcdFile = "jmp_test.vcd";
  const char *programFile = "./obj_dir/jmp.test.o65";

  vcdOut.open(vcdFile);

  uint8_t *memory = NULL;
  size_t bytesRead = readBinaryFile(programFile, memory);
  if (memory == NULL) {
    std::printf("Could not read test memory\n");
    return;
  }

  uint16_t romStart = 0x8000;
  TestMap::initMap(memory, romStart);

  reset(top, vcdOut, false);

  // Test logic here

  TestMap::cleanup();
}

int main(int argc, char **argv, char **env) {
  Verilated::commandArgs(argc, argv);

  void (*tests[])(VtopLevel&, VerilatedVcdC&) = {testReset, testJmp};
  size_t numTests = sizeof(tests) / sizeof(tests[0]);

  for (int i = 0; i < numTests; i++) {
    VerilatedContext context;
    Verilated::traceEverOn(true);

    VtopLevel top;
    VerilatedVcdC vcdOut;
    top.trace(&vcdOut, 99);

    tests[i](top, vcdOut);

    vcdOut.close();
  }

  std::printf("Done with %s\n", __FILE_NAME__);
  return 0;
}
