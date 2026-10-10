#include "../obj_dir/VtopLevel.h"
// Used by verilator:
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <cassert>
#include <cstddef>
#include <cstdint>
#include <cstdio>

#include "../lib/helpAssert.cpp"
#include "../lib/testbenchMacros.cpp"

/**
  A very simple memory-mapper. Allows you to specify a ROM address start.
  Above that address until 0xffff, that memory will be treated as read only,
  i.e. writing to it will do nothing.

  Address is 16 bit, byte-addressed.
*/
namespace TestMap {
uint8_t *data;

uint16_t romAddress = 0;

void initMap(uint8_t *initialMemory, uint16_t romStartAddress) {
  data = initialMemory;
  romAddress = romStartAddress;
}

uint8_t read(uint16_t address) { return data[address]; }

void write(uint16_t address, uint8_t byte) {
  // ROM region
  if (address < romAddress)
    data[address] = byte;
}
} // namespace TestMap

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
void testReset(VtopLevel &top, VerilatedVcdC &vcdOut, uint8_t *memory) {
  TestMap::initMap(memory, 0x8000);

  reset(top, vcdOut, true);
}

/** Tests the JMP instruction */
void testJmp(VtopLevel &top, VerilatedVcdC &vcdOut, uint8_t *memory) {
  TestMap::initMap(memory, 0x8000);

  reset(top, vcdOut, false);

  // Test logic here
}

typedef struct {
  void (*testFunction)(VtopLevel &, VerilatedVcdC &, uint8_t *memory);
  const char *vcdFile;
  const char *programFile;
} testInfo_t;

int main(int argc, char **argv, char **env) {
  Verilated::commandArgs(argc, argv);

  testInfo_t tests[] = {{.testFunction = testReset,
                         .vcdFile = "reset_test.vcd",
                         .programFile = "./obj_dir/reset.test.o65"},
                        {.testFunction = testReset,
                         .vcdFile = "jmp_test.vcd",
                         .programFile = "./obj_dir/jmp.test.o65"}};

  size_t numTests = sizeof(tests) / sizeof(tests[0]);

  for (int i = 0; i < numTests; i++) {
    VerilatedContext context;
    Verilated::traceEverOn(true);

    VtopLevel top;
    VerilatedVcdC vcdOut;
    top.trace(&vcdOut, 99);
    vcdOut.open(tests[i].vcdFile);

    uint8_t *memory;
    size_t bytesRead = readBinaryFile(tests[i].programFile, memory);
    if (memory == NULL) {
      std::printf("Could not read test memory\n");
      return -1;
    }

    tests[i].testFunction(top, vcdOut, memory);

    vcdOut.close();

    delete[] memory;
  }

  std::printf("Done with %s\n", __FILE_NAME__);
  return 0;
}
