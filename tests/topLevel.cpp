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
  do {                                                                         \
    ToggleClockWDump(clockProvider, dumpFile, countVar);                       \
    ToggleClockWDump(clockProvider, dumpFile, countVar);                       \
  } while (false)

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
  if (!testEqual(0x0000, top.dbg_PC_out))
    return log_error(), -1;
  if (!testEqual(0, top.dbg_A_out))
    return log_error(), -1;
  if (!testEqual(0, top.dbg_X_out))
    return log_error(), -1;
  if (!testEqual(0, top.dbg_Y_out))
    return log_error(), -1;
  if (!testEqual(0, top.dbg_S_out))
    return log_error(), -1;
  if (!testEqual(0, top.dbg_P_out))
    return log_error(), -1;
  if (!testEqual(0xf00, top.dbg_state_out))
    return log_error(), -1;

  printForTest &&printf("Testing reset:\n");
  printForTest &&printf("boot_1\n");

  top.forceReset_n = 0;
  CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0xf00, top.dbg_state_out))
    return log_error(), -1;
  if (!testEqual(0xfffc, top.dbg_PC_out))
    return log_error(), -1;

  printForTest &&printf("boot_2\n");

  top.forceReset_n = 1;
  CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0xf01, top.dbg_state_out))
    return log_error(), -1;
  if (!testEqual(0xfffd, top.dbg_PC_out))
    return log_error(), -1;

  printForTest &&printf("boot_3\n");

  CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x101, top.dbg_state_out))
    return log_error(), -1;
  if (!testEqual(StandardProgramRomAddr, top.dbg_PC_out))
    return log_error(), -1;

  CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x102, top.dbg_state_out))
    return log_error(), -1;
  if (!testEqual(StandardProgramRomAddr, top.dbg_PC_out))
    return log_error(), -1;

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
  if (resetResult < -1)
    return log_error(), -1;

  int counter = 9;

  // Steady state behavior
  for (int j = 0; j < 3; j++) {
    for (int i = 0; i < 3; i++)
      CycleClockWDump(top, vcdOut, counter);
  }
  return 0;
}

/** Tests the JMP instruction */
int testJmp(VtopLevel &top, VerilatedVcdC &vcdOut, uint8_t *memory) {
  int resetResult = reset(top, vcdOut, true);
  if (resetResult < -1)
    return log_error(), -1;

  int counter = 9;

  // JMP absolute takes 3 cycles to ready
  for (int i = 0; i < 3; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(StandardProgramRomAddr + 6, top.dbg_PC_out)) {
    log_error("Did not jump to correct address (absolute).\n");
    return -1;
  }

  // JMP indirect takes 5 cycles to ready
  for (int i = 0; i < 5; i++)
    CycleClockWDump(top, vcdOut, counter);
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
  if (resetResult < -1)
    return log_error(), -1;

  int counter = 9;

  // JSR takes 6 cycles to ready
  for (int i = 0; i < 6; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(StandardProgramRomAddr + 6, top.dbg_PC_out)) {
    log_error("Did not jump to correct address.\n");
    return -1;
  }

  // RTS takes 6 cycles to ready
  for (int i = 0; i < 6; i++)
    CycleClockWDump(top, vcdOut, counter);
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

/* Tests LDA, LDX, LDY, STA, STX, STY */
int testLoadStore(VtopLevel &top, VerilatedVcdC &vcdOut, uint8_t *memory) {
  int resetResult = reset(top, vcdOut, true);
  if (resetResult < -1)
    return log_error(), -1;

  int counter = 9;

#pragma region Absolute loads
  // [](../6502-code/ROM/loadStore.test.asm:9)

  // LDA (zero flag)
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0, top.dbg_A_out))
    return log_error(), -1;
  if (!testEqual(0b00000010, top.dbg_P_out))
    return log_error(), -1;

  // LDA (negative flag)
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x80, top.dbg_A_out))
    return log_error(), -1;
  if (!testEqual(0b10000000, top.dbg_P_out))
    return log_error(), -1;

  // LDX (zero flag)
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0, top.dbg_X_out))
    return log_error(), -1;
  if (!testEqual(0b00000010, top.dbg_P_out))
    return log_error(), -1;

  // LDX (negative flag)
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x80, top.dbg_X_out))
    return log_error(), -1;
  if (!testEqual(0b10000000, top.dbg_P_out))
    return log_error(), -1;

  // LDY (zero flag)
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0, top.dbg_Y_out))
    return log_error(), -1;
  if (!testEqual(0b00000010, top.dbg_P_out))
    return log_error(), -1;

  // LDY (negative flag)
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x80, top.dbg_Y_out))
    return log_error(), -1;
  if (!testEqual(0b10000000, top.dbg_P_out))
    return log_error(), -1;

#pragma endregion

#pragma region Immediate loads

  // [](../6502-code/ROM/loadStore.test.asm:21)

  // LDA (zero)
  for (int i = 0; i < 2; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x00, top.dbg_A_out))
    return log_error(), -1;
  if (!testEqual(0b00000010, top.dbg_P_out))
    return log_error(), -1;

  // LDA (negative)
  for (int i = 0; i < 2; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x80, top.dbg_A_out))
    return log_error(), -1;
  if (!testEqual(0b10000000, top.dbg_P_out))
    return log_error(), -1;

  // LDX (zero)
  for (int i = 0; i < 2; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x00, top.dbg_X_out))
    return log_error(), -1;
  if (!testEqual(0b00000010, top.dbg_P_out))
    return log_error(), -1;

  // LDX (negative)
  for (int i = 0; i < 2; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x80, top.dbg_X_out))
    return log_error(), -1;
  if (!testEqual(0b10000000, top.dbg_P_out))
    return log_error(), -1;

  // LDY (zero)
  for (int i = 0; i < 2; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x00, top.dbg_Y_out))
    return log_error(), -1;
  if (!testEqual(0b00000010, top.dbg_P_out))
    return log_error(), -1;

  // LDY (negative)
  for (int i = 0; i < 2; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x80, top.dbg_Y_out))
    return log_error(), -1;
  if (!testEqual(0b10000000, top.dbg_P_out))
    return log_error(), -1;

#pragma endregion

#pragma region ZP storage

  // [](../6502-code/ROM/loadStore.test.asm:30)

  // Setup
  for (int i = 0; i < 6; i++)
    CycleClockWDump(top, vcdOut, counter);

  // STA
  for (int i = 0; i < 3; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(1, TestMap::read(0)))
    return log_error(), -1;

  // STX
  for (int i = 0; i < 3; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(2, TestMap::read(1)))
    return log_error(), -1;

  // STY
  for (int i = 0; i < 3; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(3, TestMap::read(2)))
    return log_error(), -1;

#pragma endregion

#pragma region ZP loads

  // [](../6502-code/ROM/loadStore.test.asm:41)

  // LDA
  for (int i = 0; i < 3; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(2, top.dbg_A_out))
    return log_error(), -1;

  // LDX
  for (int i = 0; i < 3; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(3, top.dbg_X_out))
    return log_error(), -1;

  // LDY
  for (int i = 0; i < 3; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(1, top.dbg_Y_out))
    return log_error(), -1;

#pragma endregion

#pragma region Absolute Storage

  // [](../6502-code/ROM/loadStore.test.asm:48)

  // STA
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x2, TestMap::read(0x200)))
    return log_error(), -1;

  // STX
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x3, TestMap::read(0x201)))
    return log_error(), -1;

  // STY
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x1, TestMap::read(0x202)))
    return log_error(), -1;

#pragma endregion

#pragma region ZP idx loads

  // Setup
  for (int i = 0; i < 6; i++)
    CycleClockWDump(top, vcdOut, counter);

  // [](../6502-code/ROM/loadStore.test.asm:59)

  // LDA
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x01, top.dbg_A_out))
    return log_error(), -1;

  // LDY
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x01, top.dbg_Y_out))
    return log_error(), -1;

  // New index => X
  for (int i = 0; i < 2; i++)
    CycleClockWDump(top, vcdOut, counter);

  // Again, LDA
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0, top.dbg_A_out))
    return log_error(), -1;
  if (!testEqual(0b00000010, top.dbg_P_out))
    return log_error(), -1;

  // Again, LDY
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0, top.dbg_Y_out))
    return log_error(), -1;
  if (!testEqual(0b00000010, top.dbg_P_out))
    return log_error(), -1;

  // LDX
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(1, top.dbg_X_out))
    return log_error(), -1;
  if (!testEqual(0b00000000, top.dbg_P_out))
    return log_error(), -1;

  // New index => X
  for (int i = 0; i < 2; i++)
    CycleClockWDump(top, vcdOut, counter);
  // LDX
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0, top.dbg_X_out))
    return log_error(), -1;
  if (!testEqual(0b00000010, top.dbg_P_out))
    return log_error(), -1;

#pragma endregion

#pragma region Absolute Indexed

  // [](../6502-code/ROM/loadStore.test.asm:79)

  // Setup
  for (int i = 0; i < 2; i++)
    CycleClockWDump(top, vcdOut, counter);

  // LDA
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x1, top.dbg_A_out))
    return log_error(), -1;

  // LDA page cross
  for (int i = 0; i < 5; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x3, top.dbg_A_out))
    return log_error(), -1;
  // Page cross should incur 1 extra cycle
  if (!testEqual(0x102, top.dbg_state_out))
    return log_error(), -1;

#pragma endregion

#pragma region Indexed indirect

  // [](../6502-code/ROM/loadStore.test.asm:96)

  // Setup
  for (int i = 0; i < 12; i++)
    CycleClockWDump(top, vcdOut, counter);

  // LDA
  for (int i = 0; i < 6; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x80, top.dbg_A_out))
    return log_error(), -1;

#pragma endregion

#pragma region Indirect indexed

  // [](../6502-code/ROM/loadStore.test.asm:108)

  // Setup
  for (int i = 0; i < 4; i++)
    CycleClockWDump(top, vcdOut, counter);

  // LDA
  for (int i = 0; i < 5; i++)
    CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0x80, top.dbg_A_out))
    return log_error(), -1;

#pragma endregion

  // Steady state JMP trap
  for (int j = 0; j < 3; j++) {
    for (int i = 0; i < 3; i++) {
      CycleClockWDump(top, vcdOut, counter);
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
  bool skip;
} testInfo_t;

int main(int argc, char **argv, char **env) {
  Verilated::commandArgs(argc, argv);

  testInfo_t tests[] = {
      {.testFunction = testReset,
       .vcdFile = "./vcd_out/reset_test.vcd",
       .programFile = "./obj_dir/reset.test.o65",
       .romStartAddress = StandardProgramRomAddr,
       .skip = true},
      {.testFunction = testJmp,
       .vcdFile = "./vcd_out/jmp_test.vcd",
       .programFile = "./obj_dir/jmp.test.o65",
       .romStartAddress = StandardProgramRomAddr,
       .skip = true},
      {.testFunction = testSubroutines,
       .vcdFile = "./vcd_out/subroutines_test.vcd",
       .programFile = "./obj_dir/subroutines.test.o65",
       .romStartAddress = StandardProgramRomAddr,
       .skip = true},
      {.testFunction = testLoadStore,
       .vcdFile = "./vcd_out/loadStore_test.vcd",
       .programFile = "./obj_dir/loadStore.test.o65",
       .romStartAddress = StandardProgramRomAddr,
       .skip = false},
  };

  size_t numTests = sizeof(tests) / sizeof(tests[0]);

  for (int i = 0; i < numTests; i++) {
    if (tests[i].skip) {
      continue;
    }

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
