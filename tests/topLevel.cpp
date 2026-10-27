#include "../obj_dir/VtopLevel.h"
// Used by verilator:
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <cassert>
#include <cstddef>
#include <cstdint>
#include <cstdio>

#include "../lib/TestMap.cpp"
#include "../lib/helpAssert.cpp"
#include "../lib/testbenchMacros.h"

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

  top.forceReset_n = 0;
  CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0xf00, top.dbg_state_out))
    return log_error(), -1;
  if (!testEqual(0xfffc, top.dbg_PC_out))
    return log_error(), -1;

  top.forceReset_n = 1;
  CycleClockWDump(top, vcdOut, counter);
  if (!testEqual(0xf01, top.dbg_state_out))
    return log_error(), -1;
  if (!testEqual(0xfffd, top.dbg_PC_out))
    return log_error(), -1;

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

/** Tests the reset procedure
  [](../6502-code/ROM/reset.test.asm)
*/
int testReset(VtopLevel &top, VerilatedVcdC &vcdOut, uint8_t *memory) {
  int resetResult = reset(top, vcdOut, true);
  if (resetResult != 0)
    return log_error(), -1;

  int counter = 9;

  // Steady state behavior
  for (int j = 0; j < 3; j++)
    RunNCycles(3, top, vcdOut, counter);

  return 0;
}

/** Tests the JMP instruction
  [](../6502-code/ROM/jmp.test.asm)
*/
int testJmp(VtopLevel &top, VerilatedVcdC &vcdOut, uint8_t *memory) {
  int resetResult = reset(top, vcdOut, true);
  RETURN_NEQ(0, resetResult);

  int counter = 9;

  const int JMP_ABS_cycles = 3;
  RunNCycles(JMP_ABS_cycles, top, vcdOut, counter);
  RETURN_NEQ(StandardProgramRomAddr + 6, top.dbg_PC_out);

  const int JMP_IND_cycles = 5;
  RunNCycles(JMP_IND_cycles, top, vcdOut, counter);
  RETURN_NEQ(StandardProgramRomAddr + 3, top.dbg_PC_out);

  // Steady state behavior
  for (int j = 0; j < 3; j++) {
    RunNCycles(3, top, vcdOut, counter);
    RETURN_NEQ(StandardProgramRomAddr + 3, top.dbg_PC_out);
  }
  return 0;
}

/** Tests JSR and RTS
  [](../6502-code/ROM/subroutines.test.asm)
*/
int testSubroutines(VtopLevel &top, VerilatedVcdC &vcdOut, uint8_t *memory) {
  int resetResult = reset(top, vcdOut, true);
  RETURN_NEQ(0, resetResult);

  int counter = 9;

  const int JSR_cycles = 6;
  RunNCycles(JSR_cycles, top, vcdOut, counter);
  RETURN_NEQ(StandardProgramRomAddr + 6, top.dbg_PC_out);

  const int RTS_cycles = 6;
  RunNCycles(RTS_cycles, top, vcdOut, counter);
  RETURN_NEQ(StandardProgramRomAddr + 3, top.dbg_PC_out);

  // Steady state behavior
  for (int j = 0; j < 3; j++) {
    RunNCycles(3, top, vcdOut, counter);
    RETURN_NEQ(StandardProgramRomAddr + 3, top.dbg_PC_out);
  }
  return 0;
}

/* Tests LDA, LDX, LDY, STA, STX, STY
  [](../6502-code/ROM/loadStore.test.asm)
*/
int testLoadStore(VtopLevel &top, VerilatedVcdC &vcdOut, uint8_t *memory) {
  int resetResult = reset(top, vcdOut, true);
  if (resetResult != 0)
    return log_error(), -1;

  int counter = 9;

#pragma region Absolute loads
  // [](../6502-code/ROM/loadStore.test.asm:9)

  const int LD_any_ABS_cycles = 4;
  // LDA (zero flag)
  RunNCycles(LD_any_ABS_cycles, top, vcdOut, counter);
  RETURN_NEQ(0, top.dbg_A_out);
  RETURN_NEQ(0b00000010, top.dbg_P_out);

  // LDA (negative flag)
  RunNCycles(LD_any_ABS_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x80, top.dbg_A_out);
  RETURN_NEQ(0b10000000, top.dbg_P_out);

  // LDX (zero flag)
  RunNCycles(LD_any_ABS_cycles, top, vcdOut, counter);
  RETURN_NEQ(0, top.dbg_X_out);
  RETURN_NEQ(0b00000010, top.dbg_P_out);

  // LDX (negative flag)
  RunNCycles(LD_any_ABS_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x80, top.dbg_X_out);
  RETURN_NEQ(0b10000000, top.dbg_P_out);

  // LDY (zero flag)
  RunNCycles(LD_any_ABS_cycles, top, vcdOut, counter);
  RETURN_NEQ(0, top.dbg_Y_out);
  RETURN_NEQ(0b00000010, top.dbg_P_out);

  // LDY (negative flag)
  RunNCycles(LD_any_ABS_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x80, top.dbg_Y_out);
  RETURN_NEQ(0b10000000, top.dbg_P_out);

#pragma endregion

#pragma region Immediate loads

  // [](../6502-code/ROM/loadStore.test.asm:21)
  const int LD_any_IMM_cycles = 2;
  // LDA (zero)
  RunNCycles(LD_any_IMM_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x00, top.dbg_A_out);
  RETURN_NEQ(0b00000010, top.dbg_P_out);

  // LDA (negative)
  RunNCycles(LD_any_IMM_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x80, top.dbg_A_out);
  RETURN_NEQ(0b10000000, top.dbg_P_out);

  // LDX (zero)
  RunNCycles(LD_any_IMM_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x00, top.dbg_X_out);
  RETURN_NEQ(0b00000010, top.dbg_P_out);

  // LDX (negative)
  RunNCycles(LD_any_IMM_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x80, top.dbg_X_out);
  RETURN_NEQ(0b10000000, top.dbg_P_out);

  // LDY (zero)
  RunNCycles(LD_any_IMM_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x00, top.dbg_Y_out);
  RETURN_NEQ(0b00000010, top.dbg_P_out);

  // LDY (negative)
  RunNCycles(LD_any_IMM_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x80, top.dbg_Y_out);
  RETURN_NEQ(0b10000000, top.dbg_P_out);

#pragma endregion

#pragma region ZP storage

  // [](../6502-code/ROM/loadStore.test.asm:30)

  // Setup
  RunNCycles(6, top, vcdOut, counter);
  const int ST_any_ZP_cycles = 3;

  // STA
  RunNCycles(ST_any_ZP_cycles, top, vcdOut, counter);
  RETURN_NEQ(1, TestMap::read(0));

  // STX
  RunNCycles(ST_any_ZP_cycles, top, vcdOut, counter);
  RETURN_NEQ(2, TestMap::read(1));

  // STY
  RunNCycles(ST_any_ZP_cycles, top, vcdOut, counter);
  RETURN_NEQ(3, TestMap::read(2));

#pragma endregion

#pragma region ZP loads

  // [](../6502-code/ROM/loadStore.test.asm:41)

  const int LD_any_ZP_cycles = 3;

  // LDA
  RunNCycles(LD_any_ZP_cycles, top, vcdOut, counter);
  RETURN_NEQ(2, top.dbg_A_out);

  // LDX
  RunNCycles(LD_any_ZP_cycles, top, vcdOut, counter);
  RETURN_NEQ(3, top.dbg_X_out);

  // LDY
  RunNCycles(LD_any_ZP_cycles, top, vcdOut, counter);
  RETURN_NEQ(1, top.dbg_Y_out);

#pragma endregion

#pragma region Absolute Storage

  // [](../6502-code/ROM/loadStore.test.asm:48)

  const int ST_any_ABS_cycles = 4;

  // STA
  RunNCycles(ST_any_ABS_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x2, TestMap::read(0x200));

  // STX
  RunNCycles(ST_any_ABS_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x3, TestMap::read(0x201));

  // STY
  RunNCycles(ST_any_ABS_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x1, TestMap::read(0x202));

#pragma endregion

#pragma region ZP idx loads

  // Setup
  RunNCycles(6, top, vcdOut, counter);

  // [](../6502-code/ROM/loadStore.test.asm:59)

  const int LD_any_ZP_IDX_cycles = 4;

  // LDA
  RunNCycles(LD_any_ZP_IDX_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x01, top.dbg_A_out);

  // LDY
  RunNCycles(LD_any_ZP_IDX_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x01, top.dbg_Y_out);

  // New index => X
  RunNCycles(LD_any_IMM_cycles, top, vcdOut, counter);

  // Again, LDA
  RunNCycles(LD_any_ZP_IDX_cycles, top, vcdOut, counter);
  RETURN_NEQ(0, top.dbg_A_out);
  RETURN_NEQ(0b00000010, top.dbg_P_out);

  // Again, LDY
  RunNCycles(LD_any_ZP_IDX_cycles, top, vcdOut, counter);
  RETURN_NEQ(0, top.dbg_Y_out);
  RETURN_NEQ(0b00000010, top.dbg_P_out);

  // LDX
  RunNCycles(LD_any_ZP_IDX_cycles, top, vcdOut, counter);
  RETURN_NEQ(1, top.dbg_X_out);
  RETURN_NEQ(0b00000000, top.dbg_P_out);

  // New index => X
  RunNCycles(LD_any_IMM_cycles, top, vcdOut, counter);
  // LDX
  RunNCycles(LD_any_ZP_IDX_cycles, top, vcdOut, counter);
  RETURN_NEQ(0, top.dbg_X_out);
  RETURN_NEQ(0b00000010, top.dbg_P_out);

#pragma endregion

#pragma region LDA Absolute Indexed

  // [](../6502-code/ROM/loadStore.test.asm:79)

  // Setup
  RunNCycles(2, top, vcdOut, counter);

  const int LDA_ABS_IDX_cycles = 4;
  RunNCycles(LDA_ABS_IDX_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x1, top.dbg_A_out);

  // Page cross
  RunNCycles(LDA_ABS_IDX_cycles + 1, top, vcdOut, counter);
  RETURN_NEQ(0x3, top.dbg_A_out);
  // Page cross should incur 1 extra cycle
  RETURN_NEQ(0x102, top.dbg_state_out);

#pragma endregion

#pragma region Indexed indirect

  // [](../6502-code/ROM/loadStore.test.asm:96)

  // Setup
  RunNCycles(12, top, vcdOut, counter);

  // LDA
  const int LDA_IDX_IND_cycles = 6;
  RunNCycles(LDA_IDX_IND_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x80, top.dbg_A_out);

#pragma endregion

#pragma region Indirect indexed

  // [](../6502-code/ROM/loadStore.test.asm:108)

  // Setup
  RunNCycles(4, top, vcdOut, counter);

  // LDA
  const int LDA_IND_IDX_cycles = 5;
  RunNCycles(LDA_IND_IDX_cycles, top, vcdOut, counter);
  RETURN_NEQ(0x80, top.dbg_A_out);

  // New index
  RunNCycles(4, top, vcdOut, counter);

  RunNCycles(LDA_IND_IDX_cycles + 1, top, vcdOut, counter);
  RETURN_NEQ(0xfd, top.dbg_A_out);
  // Page cross should incur 1 extra cycle
  RETURN_NEQ(0x102, top.dbg_state_out);

#pragma endregion

  // Steady state behavior
  for (int j = 0; j < 3; j++)
    RunNCycles(3, top, vcdOut, counter);

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
       .skip = false},
      {.testFunction = testJmp,
       .vcdFile = "./vcd_out/jmp_test.vcd",
       .programFile = "./obj_dir/jmp.test.o65",
       .romStartAddress = StandardProgramRomAddr,
       .skip = false},
      {.testFunction = testSubroutines,
       .vcdFile = "./vcd_out/subroutines_test.vcd",
       .programFile = "./obj_dir/subroutines.test.o65",
       .romStartAddress = StandardProgramRomAddr,
       .skip = false},
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

    uint8_t *memory = NULL;
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
