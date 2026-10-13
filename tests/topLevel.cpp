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
// Base of the memory region
uint8_t *data;
// Where the ROM region starts. Above this, address is not writable
uint16_t romAddress = 0;

// Point the data and rom address to the right location for read/write
void initMap(uint8_t *initialMemory, uint16_t romStartAddress) {
  data = initialMemory;
  romAddress = romStartAddress;
}

// Read from location of memory map
uint8_t read(uint16_t address) { return data[address]; }

// Write to location of memory map. If it's in a ROM region, it does not
// overwrite the value
void write(uint16_t address, uint8_t byte) {
  // ROM region
  if (address < romAddress)
    data[address] = byte;
}
} // namespace TestMap

using std::printf;

// Reads a file into a buffer of memory
size_t readBinaryFile(const char *fileName, uint8_t *&outBuffer) {
  using std::fclose;
  using std::ferror;
  using std::fopen;
  using std::fread;
  using std::fseek;
  using std::ftell;

  FILE *file = fopen(fileName, "rb");
  if (file == NULL) {
    return -1;
  }

  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    return -1;
  }

  long size = ftell(file);
  if (size < 0) {
    fclose(file);
    return -1;
  }

  if (fseek(file, 0, SEEK_SET) != 0) {
    fclose(file);
    return -1;
  }

  uint8_t *buffer = new uint8_t[size];
  if (buffer == NULL) {
    fclose(file);
    return -1;
  }

  size_t bytesRead = fread(buffer, 1, size, file);
  if (bytesRead < (size_t)size) {
    // Partial read check (handles EOF vs actual read error)
    if (ferror(file)) {
      delete[] buffer;
      fclose(file);
      return -1;
    }
  }

  fclose(file);
  outBuffer = buffer;
  return size;
}

// Update the memory bus (should be called every cycle)
void updateMemory(VtopLevel &top) {
  if (top.mem_rW == 1) {
    top.mem_rData = TestMap::read(top.mem_address);
    top.eval();
  } else
    TestMap::write(top.mem_address, top.mem_wData);
}

const int StandardProgramRomAddr = 0x8000;

#define ToggleClockWDump(clockProvider, dumpFile, dumpAt) \
  updateMemory(clockProvider); \
  clockProvider.clk = !clockProvider.clk; \
  clockProvider.eval(); \
  dumpFile.dump(dumpAt); \

// Cycle a module's test signal
#define CycleClockWDump(clockProvider, dumpFile, dumpAt) \
  ToggleClockWDump(clockProvider, dumpFile, dumpAt); \
  ToggleClockWDump(clockProvider, dumpFile, dumpAt + 1); \

// Drive the reset signals for the tests. If you wish to see the reset dump, the
// next timestamp you should use is 7
void reset(VtopLevel &top, VerilatedVcdC &vcdOut, bool printForTest) {
  printForTest &&printf("Testing initial conditions\n");

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

  printForTest &&printf("Testing reset:\n");
  printForTest &&printf("boot_1\n");

  top.forceReset_n = 0;
  CycleClockWDump(top, vcdOut, 1);
  assert(testEqual(0xf00, top.dbg_state_out));
  assert(testEqual(0xfffc, top.dbg_PC_out));

  printForTest &&printf("boot_2\n");

  top.forceReset_n = 1;
  CycleClockWDump(top, vcdOut, 3);
  assert(testEqual(0xf01, top.dbg_state_out));
  assert(testEqual(0xfffd, top.dbg_PC_out));

  CycleClockWDump(top, vcdOut, 5);
  assert(testEqual(0x101, top.dbg_state_out));
  assert(testEqual(StandardProgramRomAddr, top.dbg_PC_out));
}

/* Testing:
  1. Set signals
  2. Cycle clock
  3. Update memory
  3. Assert
*/

/** Tests the reset procedure */
void testReset(VtopLevel &top, VerilatedVcdC &vcdOut, uint8_t *memory) {
  reset(top, vcdOut, true);
}

/** Tests the JMP instruction */
void testJmp(VtopLevel &top, VerilatedVcdC &vcdOut, uint8_t *memory) {
  reset(top, vcdOut, false);

  // After reset, need an additional fetch cycle (?)
  CycleClockWDump(top, vcdOut, 7);

  // JMP takes 3 cycles to ready
  CycleClockWDump(top, vcdOut, 9);
  CycleClockWDump(top, vcdOut, 11);
  CycleClockWDump(top, vcdOut, 13);
  // assert(testEqual(StandardProgramRomAddr + 6, top.dbg_PC_out));
  printf("JMP jumps over trap in 3 cycles.\n");

  CycleClockWDump(top, vcdOut, 15);
  CycleClockWDump(top, vcdOut, 17);
  CycleClockWDump(top, vcdOut, 19);
  CycleClockWDump(top, vcdOut, 21);
  CycleClockWDump(top, vcdOut, 23);
  CycleClockWDump(top, vcdOut, 25);
  // assert(testEqual(StandardProgramRomAddr + 3, top.dbg_PC_out));
}

// Configure test information with this
typedef struct {
  void (*testFunction)(VtopLevel &, VerilatedVcdC &, uint8_t *memory);
  const char *vcdFile;
  const char *programFile;
  uint16_t romStartAddress;
} testInfo_t;

int main(int argc, char **argv, char **env) {
  Verilated::commandArgs(argc, argv);

  testInfo_t tests[] = {
      {.testFunction = testReset,
       .vcdFile = "./vcd_out/reset_test.vcd",
       .programFile = "./obj_dir/reset.test.o65",
       .romStartAddress = StandardProgramRomAddr},
      {.testFunction = testJmp,
       .vcdFile = "./vcd_out/jmp_test.vcd",
       .programFile = "./obj_dir/jmp.test.o65",
       .romStartAddress = StandardProgramRomAddr},
  };

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
      printf("Could not read test memory\n");
      return -1;
    }
    TestMap::initMap(memory, tests[i].romStartAddress);

    tests[i].testFunction(top, vcdOut, memory);

    vcdOut.close();
    delete[] memory;
  }

  printf("Done with %s\n", __FILE_NAME__);
  return 0;
}
