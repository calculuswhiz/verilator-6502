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

using std::printf;

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

void dumpRange(uint16_t from, uint16_t to) {
  for (int i = from; i <= to; i++) {
    printf("%0x:%0x\n", i, read(i));
  }
}
} // namespace TestMap

#define log_error(fmt, ...)                                                    \
  fprintf(stderr, "[ERROR] (%s:%d) " fmt "\n", __FILE__, __LINE__)

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

#define ToggleClockWDump(clockProvider, dumpFile, countVar)                    \
  updateMemory(clockProvider);                                                 \
  clockProvider.clk = !clockProvider.clk;                                      \
  clockProvider.eval();                                                        \
  dumpFile.dump(countVar);                                                     \
  countVar++;

// Cycle a module's test signal
#define CycleClockWDump(clockProvider, dumpFile, countVar)                     \
  ToggleClockWDump(clockProvider, dumpFile, countVar);                         \
  ToggleClockWDump(clockProvider, dumpFile, countVar);

// Drive the reset signals for the tests. If you wish to see the reset dump, the
// next timestamp you should use is 7
int reset(VtopLevel &top, VerilatedVcdC &vcdOut, bool printForTest) {
  printForTest &&printf("Testing initial conditions\n");

  top.forceReset_n = 1;
  top.clk = 0;
  top.eval();
  int counter = 0;
  vcdOut.dump(counter);
  counter++;
  if (!testEqual(0x0000, top.dbg_PC_out)) {
    log_error("Failed in reset: dbg_PC_out\n");
    return -1;
  }
  if (!testEqual(0, top.dbg_A_out)) {
    log_error("Failed in reset: dbg_A_out\n");
    return -1;
  }
  if (!testEqual(0, top.dbg_X_out)) {
    log_error("Failed in reset: dbg_X_out\n");
    return -1;
  }
  if (!testEqual(0, top.dbg_Y_out)) {
    log_error("Failed in reset: dbg_Y_out\n");
    return -1;
  }
  if (!testEqual(0, top.dbg_S_out)) {
    log_error("Failed in reset: dbg_S_out\n");
    return -1;
  }
  if (!testEqual(0, top.dbg_P_out)) {
    log_error("Failed in reset: dbg_P_out\n");
    return -1;
  }
  if (!testEqual(0xf00, top.dbg_state_out)) {
    log_error("Failed in reset: dbg_state_out\n");
    return -1;
  }

  printForTest &&printf("Testing reset:\n");
  printForTest &&printf("boot_1\n");

  top.forceReset_n = 0;
  CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0xf00, top.dbg_state_out)) {
    log_error("Failed in reset: dbg_state_out\n");
    return -1;
  }
  if (!testEqual(0xfffc, top.dbg_PC_out)) {
    log_error("Failed in reset: dbg_PC_out\n");
    return -1;
  }

  printForTest &&printf("boot_2\n");

  top.forceReset_n = 1;
  CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0xf01, top.dbg_state_out)) {
    log_error("Failed in reset: dbg_state_out\n");
    return -1;
  }
  if (!testEqual(0xfffd, top.dbg_PC_out)) {
    log_error("Failed in reset: dbg_PC_out\n");
    return -1;
  }

  printForTest &&printf("boot_3\n");

  CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x101, top.dbg_state_out)) {
    log_error("Failed in reset: dbg_state_out\n");
    return -1;
  }
  if (!testEqual(StandardProgramRomAddr, top.dbg_PC_out)) {
    log_error("Failed in reset: dbg_PC_out\n");
    return -1;
  }
  
  CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x102, top.dbg_state_out)) {
    log_error("Failed in reset: dbg_state_out\n");
    return -1;
  }
  if (!testEqual(StandardProgramRomAddr, top.dbg_PC_out)) {
    log_error("Failed in reset: dbg_PC_out\n");
    return -1;
  }

  return 0;
}

/* Testing:
  1. Set signals
  2. Cycle clock
  3. Update memory
  3. Assert
*/

/** Tests the reset procedure */
int testReset(VtopLevel &top, VerilatedVcdC &vcdOut, uint8_t *memory) {
  int resetResult = reset(top, vcdOut, true);
  if (resetResult < -1) {
    log_error("Reset failed\n");
    return resetResult;
  }

  int counter = 9;

  // Steady state behavior
  for (int j = 0; j < 3; j++) {
    for (int i = 0; i < 3; i++) {
      CycleClockWDump(top, vcdOut, counter);
    }
  }
  return 0;
}

/** Tests the JMP instruction */
int testJmp(VtopLevel &top, VerilatedVcdC &vcdOut, uint8_t *memory) {
  int resetResult = reset(top, vcdOut, true);
  if (resetResult < -1) {
    log_error("Reset failed\n");
    return resetResult;
  }

  int counter = 9;

  // JMP absolute takes 3 cycles to ready
  for (int i = 0; i < 3; i++) {
    CycleClockWDump(top, vcdOut, counter);
  }
  if (!testEqual(StandardProgramRomAddr + 6, top.dbg_PC_out)) {
    log_error("Did not jump to correct address (absolute).\n");
    return -1;
  }

  // JMP indirect takes 5 cycles to ready
  for (int i = 0; i < 5; i++) {
    CycleClockWDump(top, vcdOut, counter);
  }
  if (!testEqual(StandardProgramRomAddr + 3, top.dbg_PC_out)) {
    log_error("Did not jump to correct address (absolute indirect)\n");
    return -1;
  }

  // Steady state behavior
  for (int j = 0; j < 3; j++) {
    for (int i = 0; i < 3; i++) {
      CycleClockWDump(top, vcdOut, counter);
    }
    if (!testEqual(StandardProgramRomAddr + 3, top.dbg_PC_out)) {
      log_error("Failed to JMP to trap\n");
      return -1;
    }
  }
  return 0;
}

/** Tests JSR and RTS */
int testSubroutines(VtopLevel &top, VerilatedVcdC &vcdOut, uint8_t *memory) {
  int resetResult = reset(top, vcdOut, true);
  if (resetResult < -1) {
    log_error("Reset failed\n");
    return resetResult;
  }

  int counter = 9;

  // JSR takes 6 cycles to ready
  for (int i = 0; i < 6; i++) {
    CycleClockWDump(top, vcdOut, counter);
  }
  if (!testEqual(StandardProgramRomAddr + 6, top.dbg_PC_out)) {
    log_error("Did not jump to correct address.\n");
    return -1;
  }
  
  // RTS takes 6 cycles to ready
  for (int i = 0; i < 6; i++) {
    CycleClockWDump(top, vcdOut, counter);
  }
  if (!testEqual(StandardProgramRomAddr + 3, top.dbg_PC_out)) {
    log_error("Did not return to correct address.\n");
    return -1;
  }

  // Steady state behavior
  for (int j = 0; j < 3; j++) {
    for (int i = 0; i < 3; i++) {
      CycleClockWDump(top, vcdOut, counter);
    }
    if (!testEqual(StandardProgramRomAddr + 3, top.dbg_PC_out)) {
      log_error("Failed to JMP to trap\n");
      return -1;
    }
  }
  return 0;
}

// Configure test information with this
typedef struct {
  int (*testFunction)(VtopLevel &, VerilatedVcdC &, uint8_t *memory);
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
      {.testFunction = testSubroutines,
       .vcdFile = "./vcd_out/subroutines_test.vcd",
       .programFile = "./obj_dir/subroutines.test.o65",
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
      log_error("Could not read test memory\n");
      return -1;
    }
    TestMap::initMap(memory, tests[i].romStartAddress);

    printf("BEGIN TEST: %s\n", tests[i].programFile);
    int result = tests[i].testFunction(top, vcdOut, memory);
    if (result < 0) {
      log_error("Failed tests.\n");
      return -1;
    }

    vcdOut.close();
    delete[] memory;
  }

  printf("Done with %s\n", __FILE_NAME__);
  return 0;
}
