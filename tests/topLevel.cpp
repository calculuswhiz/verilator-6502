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
#include "../lib/testbenchHelpers.h"

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
  if (file == NULL)
    return -1;

  if (fseek(file, 0, SEEK_END) != 0)
    return fclose(file), -1;

  long size = ftell(file);
  if (size < 0)
    return fclose(file), -1;

  if (fseek(file, 0, SEEK_SET) != 0)
    return fclose(file), -1;

  uint8_t *buffer = new uint8_t[size];
  if (buffer == NULL)
    return fclose(file), -1;

  size_t bytesRead = fread(buffer, 1, size, file);
  if (bytesRead < (size_t)size) {
    // Partial read check (handles EOF vs actual read error)
    if (ferror(file)) {
      delete[] buffer;
      return fclose(file), -1;
    }
  }

  fclose(file);
  outBuffer = buffer;
  return size;
}

constexpr int StandardProgramRomAddr = 0x8000;

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

  ERR_IF_NEQ(0x0000, top.dbg_PC_out);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(0, top.dbg_X_out);
  ERR_IF_NEQ(0, top.dbg_Y_out);
  ERR_IF_NEQ(0, top.dbg_S_out);
  ERR_IF_NEQ(0, top.dbg_P_out);
  ERR_IF_NEQ(0xf00, top.dbg_state_out);

  printForTest &&printf("Testing reset:\n");

  top.forceReset_n = 0;
  cycle_clock_with_dump(top, vcdOut, counter);
  ERR_IF_NEQ(0xf00, top.dbg_state_out);
  ERR_IF_NEQ(0xfffc, top.dbg_PC_out);

  top.forceReset_n = 1;
  cycle_clock_with_dump(top, vcdOut, counter);
  ERR_IF_NEQ(0xf01, top.dbg_state_out);
  ERR_IF_NEQ(0xfffd, top.dbg_PC_out);

  cycle_clock_with_dump(top, vcdOut, counter);
  ERR_IF_NEQ(0x101, top.dbg_state_out);
  ERR_IF_NEQ(StandardProgramRomAddr, top.dbg_PC_out);

  cycle_clock_with_dump(top, vcdOut, counter);
  ERR_IF_NEQ(0x102, top.dbg_state_out);
  ERR_IF_NEQ(StandardProgramRomAddr, top.dbg_PC_out);

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
  ERR_IF_NEQ(resetResult, 0);

  int counter = 9;

  // Steady state behavior
  for (int i = 0; i < 3; i++)
    run_n_cycles(3, top, vcdOut, counter);

  return 0;
}

/** Tests the JMP instruction
  [](../6502-code/ROM/jmp.test.asm)
*/
int testJmp(VtopLevel &top, VerilatedVcdC &vcdOut, uint8_t *memory) {
  int resetResult = reset(top, vcdOut, true);
  ERR_IF_NEQ(0, resetResult);

  int counter = 9;

  const int JMP_ABS_cycles = 3;
  run_n_cycles(JMP_ABS_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(StandardProgramRomAddr + 6, top.dbg_PC_out);

  const int JMP_IND_cycles = 5;
  run_n_cycles(JMP_IND_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(StandardProgramRomAddr + 3, top.dbg_PC_out);

  // Steady state behavior
  for (int i = 0; i < 3; i++) {
    run_n_cycles(3, top, vcdOut, counter);
    ERR_IF_NEQ(StandardProgramRomAddr + 3, top.dbg_PC_out);
  }
  return 0;
}

/** Tests JSR and RTS
  [](../6502-code/ROM/subroutines.test.asm)
*/
int testSubroutines(VtopLevel &top, VerilatedVcdC &vcdOut, uint8_t *memory) {
  int resetResult = reset(top, vcdOut, true);
  ERR_IF_NEQ(0, resetResult);

  int counter = 9;

  const int JSR_cycles = 6;
  run_n_cycles(JSR_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(StandardProgramRomAddr + 6, top.dbg_PC_out);

  const int RTS_cycles = 6;
  run_n_cycles(RTS_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(StandardProgramRomAddr + 3, top.dbg_PC_out);

  // Steady state behavior
  for (int i = 0; i < 3; i++) {
    run_n_cycles(3, top, vcdOut, counter);
    ERR_IF_NEQ(StandardProgramRomAddr + 3, top.dbg_PC_out);
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
  run_n_cycles(LD_any_ABS_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(0b00000010, top.dbg_P_out);

  // LDA (negative flag)
  run_n_cycles(LD_any_ABS_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x80, top.dbg_A_out);
  ERR_IF_NEQ(0b10000000, top.dbg_P_out);

  // LDX (zero flag)
  run_n_cycles(LD_any_ABS_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0, top.dbg_X_out);
  ERR_IF_NEQ(0b00000010, top.dbg_P_out);

  // LDX (negative flag)
  run_n_cycles(LD_any_ABS_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x80, top.dbg_X_out);
  ERR_IF_NEQ(0b10000000, top.dbg_P_out);

  // LDY (zero flag)
  run_n_cycles(LD_any_ABS_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0, top.dbg_Y_out);
  ERR_IF_NEQ(0b00000010, top.dbg_P_out);

  // LDY (negative flag)
  run_n_cycles(LD_any_ABS_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x80, top.dbg_Y_out);
  ERR_IF_NEQ(0b10000000, top.dbg_P_out);

#pragma endregion

#pragma region Immediate loads

  // [](../6502-code/ROM/loadStore.test.asm:21)
  const int LD_any_IMM_cycles = 2;
  // LDA (zero)
  run_n_cycles(LD_any_IMM_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x00, top.dbg_A_out);
  ERR_IF_NEQ(0b00000010, top.dbg_P_out);

  // LDA (negative)
  run_n_cycles(LD_any_IMM_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x80, top.dbg_A_out);
  ERR_IF_NEQ(0b10000000, top.dbg_P_out);

  // LDX (zero)
  run_n_cycles(LD_any_IMM_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x00, top.dbg_X_out);
  ERR_IF_NEQ(0b00000010, top.dbg_P_out);

  // LDX (negative)
  run_n_cycles(LD_any_IMM_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x80, top.dbg_X_out);
  ERR_IF_NEQ(0b10000000, top.dbg_P_out);

  // LDY (zero)
  run_n_cycles(LD_any_IMM_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x00, top.dbg_Y_out);
  ERR_IF_NEQ(0b00000010, top.dbg_P_out);

  // LDY (negative)
  run_n_cycles(LD_any_IMM_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x80, top.dbg_Y_out);
  ERR_IF_NEQ(0b10000000, top.dbg_P_out);

#pragma endregion

#pragma region ZP storage

  // [](../6502-code/ROM/loadStore.test.asm:30)

  // Setup
  run_n_cycles(6, top, vcdOut, counter);
  const int ST_any_ZP_cycles = 3;

  // STA
  run_n_cycles(ST_any_ZP_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(1, TestMap::read(0));

  // STX
  run_n_cycles(ST_any_ZP_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(2, TestMap::read(1));

  // STY
  run_n_cycles(ST_any_ZP_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(3, TestMap::read(2));

#pragma endregion

#pragma region ZP loads

  // [](../6502-code/ROM/loadStore.test.asm:41)

  const int LD_any_ZP_cycles = 3;

  // LDA
  run_n_cycles(LD_any_ZP_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(2, top.dbg_A_out);

  // LDX
  run_n_cycles(LD_any_ZP_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(3, top.dbg_X_out);

  // LDY
  run_n_cycles(LD_any_ZP_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(1, top.dbg_Y_out);

#pragma endregion

#pragma region Absolute Storage

  // [](../6502-code/ROM/loadStore.test.asm:48)

  const int ST_any_ABS_cycles = 4;

  // STA
  run_n_cycles(ST_any_ABS_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x2, TestMap::read(0x200));

  // STX
  run_n_cycles(ST_any_ABS_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x3, TestMap::read(0x201));

  // STY
  run_n_cycles(ST_any_ABS_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x1, TestMap::read(0x202));

#pragma endregion

#pragma region ZP idx loads

  // Setup
  run_n_cycles(6, top, vcdOut, counter);

  // [](../6502-code/ROM/loadStore.test.asm:59)

  const int LD_any_ZP_IDX_cycles = 4;

  // LDA
  run_n_cycles(LD_any_ZP_IDX_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x01, top.dbg_A_out);

  // LDY
  run_n_cycles(LD_any_ZP_IDX_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x01, top.dbg_Y_out);

  // New index => X
  run_n_cycles(LD_any_IMM_cycles, top, vcdOut, counter);

  // Again, LDA
  run_n_cycles(LD_any_ZP_IDX_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(0b00000010, top.dbg_P_out);

  // Again, LDY
  run_n_cycles(LD_any_ZP_IDX_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0, top.dbg_Y_out);
  ERR_IF_NEQ(0b00000010, top.dbg_P_out);

  // LDX
  run_n_cycles(LD_any_ZP_IDX_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(1, top.dbg_X_out);
  ERR_IF_NEQ(0b00000000, top.dbg_P_out);

  // New index => X
  run_n_cycles(LD_any_IMM_cycles, top, vcdOut, counter);
  // LDX
  run_n_cycles(LD_any_ZP_IDX_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0, top.dbg_X_out);
  ERR_IF_NEQ(0b00000010, top.dbg_P_out);

#pragma endregion

#pragma region LDA Absolute Indexed

  // [](../6502-code/ROM/loadStore.test.asm:79)

  // Setup
  run_n_cycles(2, top, vcdOut, counter);

  const int LDA_ABS_IDX_cycles = 4;
  run_n_cycles(LDA_ABS_IDX_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x1, top.dbg_A_out);

  // Page cross
  run_n_cycles(LDA_ABS_IDX_cycles + 1, top, vcdOut, counter);
  ERR_IF_NEQ(0x3, top.dbg_A_out);
  // Page cross should incur 1 extra cycle
  ERR_IF_NEQ(0x102, top.dbg_state_out);

#pragma endregion

#pragma region Indexed indirect

  // [](../6502-code/ROM/loadStore.test.asm:96)

  // Setup
  run_n_cycles(12, top, vcdOut, counter);

  // LDA
  const int LDA_IDX_IND_cycles = 6;
  run_n_cycles(LDA_IDX_IND_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x80, top.dbg_A_out);

#pragma endregion

#pragma region Indirect indexed

  // [](../6502-code/ROM/loadStore.test.asm:108)

  // Setup
  run_n_cycles(4, top, vcdOut, counter);

  // LDA
  const int LDA_IND_IDX_cycles = 5;
  run_n_cycles(LDA_IND_IDX_cycles, top, vcdOut, counter);
  ERR_IF_NEQ(0x80, top.dbg_A_out);

  // New index
  run_n_cycles(4, top, vcdOut, counter);

  run_n_cycles(LDA_IND_IDX_cycles + 1, top, vcdOut, counter);
  ERR_IF_NEQ(0xfd, top.dbg_A_out);
  // Page cross should incur 1 extra cycle
  ERR_IF_NEQ(0x102, top.dbg_state_out);

#pragma endregion

  // Steady state behavior
  for (int i = 0; i < 3; i++)
    run_n_cycles(3, top, vcdOut, counter);

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
    if (memory == NULL)
      return log_error("Could not read test memory\n"), -1;

    TestMap::initMap(memory, tests[i].romStartAddress);

    printf("BEGIN TEST: %s\n", tests[i].programFile);
    int result = tests[i].testFunction(top, vcdOut, memory);
    if (result != 0)
      return log_error("Failed tests.\n"), -1;

    vcdOut.close();
    delete[] memory;
  }

  printf("Done with %s\n", __FILE_NAME__);
  return 0;
}
