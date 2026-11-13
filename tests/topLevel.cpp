#include "../obj_dir/VtopLevel.h"
// Used by verilator:
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <cassert>
#include <cstddef>
#include <cstdint>
#include <cstdio>

#include "../lib/cycles.h"
#include "../lib/helpAssert.cpp"
#include "../lib/opcodes.h"

import TestMap;

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

// Update the memory bus (should be called every cycle)
template <typename TModule> void updateMemory(TModule &module) {
  if (module.mem_rW == 1) {
    module.mem_rData = TestMap::read(module.mem_address);
    module.eval();
  } else
    TestMap::write(module.mem_address, module.mem_wData);
}

template <typename TModule>
inline void toggle_clock(TModule &module, VerilatedVcdC &dumpFile, int &count,
                         bool dump) {
  updateMemory(module);
  module.clk = !module.clk;
  module.eval();
  if (dump)
    dumpFile.dump(count++);
}

// Cycle a module's test signal. Takes 2 time units.
template <typename TModule>
inline void cycle_clock(TModule &module, VerilatedVcdC &dumpFile, int &count,
                        bool dump) {
  toggle_clock(module, dumpFile, count, dump);
  toggle_clock(module, dumpFile, count, dump);
}

template <typename TModule>
inline void run_n_cycles(int n, TModule &module, VerilatedVcdC &dumpFile,
                         int &count, bool dump) {
  for (int i = 0; i < n; i++) {
    toggle_clock(module, dumpFile, count, dump);
    toggle_clock(module, dumpFile, count, dump);
  }
}

constexpr int StandardProgramRomAddr = 0x8000;

// NV1BDIZC
namespace P_Flags {
enum Flags {
  NONE = 0 | 1 << 5,
  C = 1 << 0 | 1 << 5,
  Z = 1 << 1 | 1 << 5,
  I = 1 << 2 | 1 << 5,
  D = 1 << 3 | 1 << 5,
  B = 1 << 4 | 1 << 5,
  // Hardwire to 1
  ONE = 1 << 5,
  V = 1 << 6 | 1 << 5,
  N = 1 << 7 | 1 << 5
};
}

// Drive the reset signals for the tests. Ends on a half-cycle so we can see the
// result of the instruction.
// Returns clock time after done. -1 if error
int reset(VtopLevel &top, VerilatedVcdC &vcdOut, bool printForTest) {
  printForTest &&printf("Testing initial conditions\n");

  top.forceReset_n = 1;
  top.clk = 0;
  top.eval();
  int counter = 0;
  if (printForTest)
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
  cycle_clock(top, vcdOut, counter, printForTest);
  ERR_IF_NEQ(boot_1, top.dbg_state_out);
  ERR_IF_NEQ(0xfffc, top.dbg_PC_out);

  top.forceReset_n = 1;
  cycle_clock(top, vcdOut, counter, printForTest);
  ERR_IF_NEQ(boot_2, top.dbg_state_out);
  ERR_IF_NEQ(0xfffd, top.dbg_PC_out);

  cycle_clock(top, vcdOut, counter, printForTest);
  ERR_IF_NEQ(boot_3, top.dbg_state_out);
  ERR_IF_NEQ(StandardProgramRomAddr, top.dbg_PC_out);

  toggle_clock(top, vcdOut, counter, printForTest);
  ERR_IF_NEQ(fetch2, top.dbg_state_out);
  ERR_IF_NEQ(StandardProgramRomAddr, top.dbg_PC_out);

  return counter;
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
int testReset(VtopLevel &top, VerilatedVcdC &vcdOut) {
  int resetResult = reset(top, vcdOut, true);
  if (resetResult == -1)
    return log_error(), -1;

  int counter = resetResult;

  for (int i = 0; i < 3; i++)
    run_n_cycles(2, top, vcdOut, counter, true);

  return 0;
}

/** Tests the JMP instruction
  [](../6502-code/ROM/jmp.test.asm)
*/
int testJmp(VtopLevel &top, VerilatedVcdC &vcdOut) {
  int resetResult = reset(top, vcdOut, false);
  if (resetResult == -1)
    return log_error(), -1;

  int counter = resetResult;

  run_n_cycles(JMP_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(StandardProgramRomAddr + 6, top.dbg_PC_out);

  run_n_cycles(JMP_ind_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(StandardProgramRomAddr + 3, top.dbg_PC_out);

  // Pad output
  for (int i = 0; i < 3; i++) {
    run_n_cycles(3, top, vcdOut, counter, true);
    ERR_IF_NEQ(StandardProgramRomAddr + 3, top.dbg_PC_out);
  }
  return 0;
}

/** Tests JSR and RTS
  [](../6502-code/ROM/subroutines.test.asm)
*/
int testSubroutines(VtopLevel &top, VerilatedVcdC &vcdOut) {
  int resetResult = reset(top, vcdOut, false);
  if (resetResult == -1)
    return log_error(), -1;

  int counter = resetResult;

  run_n_cycles(JSR_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(StandardProgramRomAddr + 6, top.dbg_PC_out);

  run_n_cycles(RTS_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(StandardProgramRomAddr + 3, top.dbg_PC_out);

  // Pad output
  for (int i = 0; i < 3; i++) {
    run_n_cycles(3, top, vcdOut, counter, true);
    ERR_IF_NEQ(StandardProgramRomAddr + 3, top.dbg_PC_out);
  }
  return 0;
}

/* Tests LDA, LDX, LDY, STA, STX, STY
  [](../6502-code/ROM/loadStore.test.asm)
*/
int testLoadStore(VtopLevel &top, VerilatedVcdC &vcdOut) {
  int resetResult = reset(top, vcdOut, false);
  if (resetResult == -1)
    return log_error(), -1;

  int counter = resetResult;

#pragma region Absolute loads
  // [](../6502-code/ROM/loadStore.test.asm:9)

  run_n_cycles(LDA_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDA_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(LDX_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_X_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDX_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_X_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(LDY_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_Y_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDY_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_Y_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

#pragma endregion

#pragma region Immediate loads

  // [](../6502-code/ROM/loadStore.test.asm:21)
  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x00, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(LDX_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x00, top.dbg_X_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDX_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_X_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(LDY_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x00, top.dbg_Y_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDY_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_Y_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

#pragma endregion

#pragma region ZP storage

  // [](../6502-code/ROM/loadStore.test.asm:30)

  run_n_cycles(LDA_imm_cycles + LDX_imm_cycles + LDY_imm_cycles, top, vcdOut,
               counter, true);

  run_n_cycles(STA_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(1, TestMap::read(0));

  run_n_cycles(STX_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(2, TestMap::read(1));

  run_n_cycles(STY_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(3, TestMap::read(2));

#pragma endregion

#pragma region ZP loads

  // [](../6502-code/ROM/loadStore.test.asm:41)

  run_n_cycles(LDA_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(2, top.dbg_A_out);

  run_n_cycles(LDX_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(3, top.dbg_X_out);

  run_n_cycles(LDY_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(1, top.dbg_Y_out);

#pragma endregion

#pragma region Absolute Storage

  // [](../6502-code/ROM/loadStore.test.asm:48)
  run_n_cycles(STA_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x2, TestMap::read(0x200));

  run_n_cycles(STX_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x3, TestMap::read(0x201));

  run_n_cycles(STY_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x1, TestMap::read(0x202));

#pragma endregion

#pragma region ZP idx loads

  run_n_cycles(LDA_imm_cycles + LDX_imm_cycles + LDY_imm_cycles, top, vcdOut,
               counter, true);

  // [](../6502-code/ROM/loadStore.test.asm:59)
  run_n_cycles(LDA_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x01, top.dbg_A_out);

  run_n_cycles(LDY_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x01, top.dbg_Y_out);

  run_n_cycles(LDX_imm_cycles, top, vcdOut, counter, true);

  run_n_cycles(LDA_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDY_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_Y_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDX_zpy_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(1, top.dbg_X_out);
  ERR_IF_NEQ(P_Flags::NONE, top.dbg_P_out);

  run_n_cycles(LDY_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(LDX_zpy_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_X_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

#pragma endregion

#pragma region LDA Absolute Indexed

  // [](../6502-code/ROM/loadStore.test.asm:79)

  run_n_cycles(LDX_imm_cycles, top, vcdOut, counter, true);

  run_n_cycles(LDA_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x1, top.dbg_A_out);

  run_n_cycles(LDA_abx_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x3, top.dbg_A_out);
  ERR_IF_NEQ(fetch2, top.dbg_state_out);

#pragma endregion

#pragma region Indexed indirect

  // [](../6502-code/ROM/loadStore.test.asm:96)

  run_n_cycles(LDA_imm_cycles + STA_zp_cycles + LDA_imm_cycles + STA_zp_cycles +
                   LDX_imm_cycles,
               top, vcdOut, counter, true);

  run_n_cycles(LDA_izx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_A_out);

#pragma endregion

#pragma region Indirect indexed

  // [](../6502-code/ROM/loadStore.test.asm:108)

  run_n_cycles(LDA_imm_cycles + LDY_imm_cycles, top, vcdOut, counter, true);

  run_n_cycles(LDA_izy_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_A_out);

  run_n_cycles(LDA_imm_cycles + LDY_imm_cycles, top, vcdOut, counter, true);

  run_n_cycles(LDA_izy_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xfd, top.dbg_A_out);
  ERR_IF_NEQ(fetch2, top.dbg_state_out);

#pragma endregion

  // Pad output
  run_n_cycles(6, top, vcdOut, counter, true);

  return 0;
}

int testFlagsBranch(VtopLevel &top, VerilatedVcdC &vcdOut) {
  // [](../6502-code/ROM/flags_branch.test.asm)

  int resetResult = reset(top, vcdOut, false);
  if (resetResult == -1)
    return log_error(), -1;

  int counter = resetResult;

  int noBranchOps[] = {BCS_REL, BEQ_REL, BMI_REL, BVS_REL};
  for (int i = 0; i < 4; i++) {
    ERR_IF_NEQ(noBranchOps[i], TestMap::read(top.dbg_PC_out));
    run_n_cycles(BCS_rel_cycles, top, vcdOut, counter, true);
  }

  ERR_IF_NEQ(SEI_IMP, TestMap::read(top.dbg_PC_out));
  run_n_cycles(SEI_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::I, top.dbg_P_out);

  ERR_IF_NEQ(SEC_IMP, TestMap::read(top.dbg_PC_out));
  run_n_cycles(SEC_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::C | P_Flags::I, top.dbg_P_out);

  ERR_IF_NEQ(BIT_ABS, TestMap::read(top.dbg_PC_out));
  run_n_cycles(BIT_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::C | P_Flags::I | P_Flags::N | P_Flags::V | P_Flags::Z,
             top.dbg_P_out);

  int noBranchOps2[] = {BCC_REL, BNE_REL, BPL_REL, BVC_REL};
  for (int i = 0; i < 4; i++) {
    ERR_IF_NEQ(noBranchOps2[i], TestMap::read(top.dbg_PC_out));
    run_n_cycles(BCS_rel_cycles, top, vcdOut, counter, true);
  }

  int branchOps1[] = {BCS_REL, BEQ_REL, BMI_REL, BVS_REL};
  for (int i = 0; i < 4; i++) {
    ERR_IF_NEQ(branchOps1[i], TestMap::read(top.dbg_PC_out));
    run_n_cycles(BCS_rel_cycles + branch_taken_cycles, top, vcdOut, counter,
                 true);
  }

  ERR_IF_NEQ(CLC_IMP, TestMap::read(top.dbg_PC_out));
  run_n_cycles(CLC_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::I | P_Flags::N | P_Flags::V | P_Flags::Z, top.dbg_P_out);

  ERR_IF_NEQ(CLI_IMP, TestMap::read(top.dbg_PC_out));
  run_n_cycles(CLI_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::N | P_Flags::V | P_Flags::Z, top.dbg_P_out);

  ERR_IF_NEQ(CLV_IMP, TestMap::read(top.dbg_PC_out));
  run_n_cycles(CLV_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::N | P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::NONE, top.dbg_P_out);

  int branchOps2[] = {BCC_REL, BNE_REL, BPL_REL, BVC_REL};
  for (int i = 0; i < 4; i++) {
    ERR_IF_NEQ(branchOps2[i], TestMap::read(top.dbg_PC_out));
    run_n_cycles(BCC_rel_cycles + branch_taken_cycles, top, vcdOut, counter,
                 true);
  }

  // Jumps to close-enough spot to test page crossing branch
  run_n_cycles(JMP_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80a0, top.dbg_PC_out);

  int branchPageFixOps1[] = {BCC_REL, BNE_REL, BPL_REL, BVC_REL};
  for (int i = 0; i < 4; i++) {
    ERR_IF_NEQ(branchPageFixOps1[i], TestMap::read(top.dbg_PC_out));
    run_n_cycles(BCC_rel_cycles + branch_taken_cycles + page_cycles, top,
                 vcdOut, counter, true);
    run_n_cycles(JMP_abs_cycles, top, vcdOut, counter, true);
  }
  ERR_IF_NEQ(fetch2, top.dbg_state_out);

  // Set flags
  run_n_cycles(8, top, vcdOut, counter, true);
  ERR_IF_NEQ(fetch2, top.dbg_state_out);

  int branchPageFixOps2[] = {BCS_REL, BEQ_REL, BMI_REL, BVS_REL};
  for (int i = 0; i < 4; i++) {
    ERR_IF_NEQ(branchPageFixOps2[i], TestMap::read(top.dbg_PC_out));
    run_n_cycles(BCC_rel_cycles + branch_taken_cycles + page_cycles, top,
                 vcdOut, counter, true);
    run_n_cycles(JMP_abs_cycles, top, vcdOut, counter, true);
  }
  ERR_IF_NEQ(fetch2, top.dbg_state_out);

  // Pad output
  run_n_cycles(6, top, vcdOut, counter, true);

  return 0;
}

int testTransfer(VtopLevel &top, VerilatedVcdC &vcdOut) {
  // [](../6502-code/ROM/transfer.test.asm)

  int resetResult = reset(top, vcdOut, false);
  if (resetResult == -1)
    return log_error(), -1;

  int counter = resetResult;

  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(TAX_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  ERR_IF_NEQ(0xff, top.dbg_X_out);

  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(TAX_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  ERR_IF_NEQ(0x00, top.dbg_X_out);

  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(TAY_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  ERR_IF_NEQ(0xff, top.dbg_Y_out);

  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(TAY_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  ERR_IF_NEQ(0x00, top.dbg_Y_out);

  run_n_cycles(LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(TXA_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  ERR_IF_NEQ(0xff, top.dbg_A_out);

  run_n_cycles(LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(TXA_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  ERR_IF_NEQ(0x00, top.dbg_A_out);

  run_n_cycles(LDY_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(TYA_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  ERR_IF_NEQ(0xff, top.dbg_A_out);

  run_n_cycles(LDY_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(TYA_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  ERR_IF_NEQ(0x00, top.dbg_A_out);

  // Pad output
  run_n_cycles(6, top, vcdOut, counter, true);

  return 0;
}

int testStack(VtopLevel &top, VerilatedVcdC &vcdOut) {
  // [](../6502-code/ROM/stack.test.asm)

  int resetResult = reset(top, vcdOut, false);
  if (resetResult == -1)
    return log_error(), -1;

  int counter = resetResult;

  run_n_cycles(LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(TXS_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_S_out);

  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(PHA_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, TestMap::read(top.dbg_S_out + 0x100 + 1));
  run_n_cycles(PHP_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xa0, TestMap::read(top.dbg_S_out + 0x100 + 1));
  run_n_cycles(TSX_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xfd, top.dbg_X_out);

  run_n_cycles(PLA_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xa0, top.dbg_A_out);
  run_n_cycles(PLP_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_P_out);
  ERR_IF_NEQ(0xff, top.dbg_S_out);

  // Pad output
  run_n_cycles(6, top, vcdOut, counter, true);

  return 0;
}

int testIncDec(VtopLevel &top, VerilatedVcdC &vcdOut) {
  // [](../6502-code/ROM/inc_dec_x_y.test.asm)
  int resetResult = reset(top, vcdOut, false);
  if (resetResult == -1)
    return log_error(), -1;

  int counter = resetResult;

  run_n_cycles(INX_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(1, top.dbg_X_out);
  run_n_cycles(DEX_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_X_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(DEX_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_X_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(INX_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_X_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(INX_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_X_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(INY_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(1, top.dbg_Y_out);
  run_n_cycles(DEY_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_Y_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(DEY_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_Y_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(INY_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_Y_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDY_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(INY_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_Y_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  // Pad output
  run_n_cycles(6, top, vcdOut, counter, true);

  return 0;
}

int testArithmetic(VtopLevel &top, VerilatedVcdC &vcdOut) {
  // [](../6502-code/ROM/arithmetic.test.asm)

  int resetResult = reset(top, vcdOut, false);
  if (resetResult == -1)
    return log_error(), -1;

  int counter = resetResult;

  // Immediate
  run_n_cycles(ADC_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ADC_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ADC_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ADC_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(ADC_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::V | P_Flags::N, top.dbg_P_out);

  run_n_cycles(SBC_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z | P_Flags::V | P_Flags::C, top.dbg_P_out);
  run_n_cycles(SBC_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  // ZP
  run_n_cycles(ADC_zp_cycles, top, vcdOut, counter, true);
  run_n_cycles(CLC_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(ADC_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ADC_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ADC_zp_cycles, top, vcdOut, counter, true);
  run_n_cycles(ADC_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::V | P_Flags::N, top.dbg_P_out);

  run_n_cycles(SBC_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z | P_Flags::V | P_Flags::C, top.dbg_P_out);
  run_n_cycles(SBC_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(INC_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(1));
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(DEC_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, TestMap::read(1));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(DEC_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, TestMap::read(7));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(INC_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x0, TestMap::read(7));
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  // ZP,X
  run_n_cycles(LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);

  run_n_cycles(ADC_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z | P_Flags::C, top.dbg_P_out);
  run_n_cycles(CLC_imp_cycles, top, vcdOut, counter, true);
  run_n_cycles(INX_imp_cycles, top, vcdOut, counter, true);
  run_n_cycles(ADC_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ADC_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ADC_zpx_cycles, top, vcdOut, counter, true);
  run_n_cycles(ADC_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::V | P_Flags::N, top.dbg_P_out);

  run_n_cycles(SBC_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z | P_Flags::V | P_Flags::C, top.dbg_P_out);
  run_n_cycles(SBC_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(INC_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(1));
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(DEC_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, TestMap::read(1));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(DEC_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, TestMap::read(7));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(INC_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x0, TestMap::read(7));
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  // Absolute
  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);

  run_n_cycles(ADC_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z | P_Flags::C, top.dbg_P_out);
  run_n_cycles(CLC_imp_cycles, top, vcdOut, counter, true);
  run_n_cycles(ADC_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ADC_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ADC_abs_cycles, top, vcdOut, counter, true);
  run_n_cycles(ADC_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::V | P_Flags::N, top.dbg_P_out);

  run_n_cycles(SBC_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z | P_Flags::V | P_Flags::C, top.dbg_P_out);
  run_n_cycles(SBC_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(INC_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(0x201));
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(DEC_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, TestMap::read(0x201));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(DEC_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, TestMap::read(0x207));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(INC_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x0, TestMap::read(0x207));
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  // Absolute, X
  run_n_cycles(LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);

  run_n_cycles(ADC_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z | P_Flags::C, top.dbg_P_out);
  run_n_cycles(CLC_imp_cycles, top, vcdOut, counter, true);
  run_n_cycles(INX_imp_cycles, top, vcdOut, counter, true);
  run_n_cycles(ADC_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ADC_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ADC_abx_cycles, top, vcdOut, counter, true);
  run_n_cycles(ADC_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::V | P_Flags::N, top.dbg_P_out);

  run_n_cycles(SBC_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z | P_Flags::V | P_Flags::C, top.dbg_P_out);
  run_n_cycles(SBC_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(INC_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(0x201));
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(DEC_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, TestMap::read(0x201));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(DEC_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, TestMap::read(0x207));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(INC_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x0, TestMap::read(0x207));
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(ADC_abx_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  run_n_cycles(SBC_abx_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);

  ERR_IF_NEQ(fetch2, top.dbg_state_out);

  // Absolute, Y
  run_n_cycles(LDY_imm_cycles + LDA_imm_cycles, top, vcdOut, counter, true);

  run_n_cycles(ADC_aby_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z | P_Flags::C, top.dbg_P_out);
  run_n_cycles(CLC_imp_cycles, top, vcdOut, counter, true);
  run_n_cycles(INY_imp_cycles, top, vcdOut, counter, true);
  run_n_cycles(ADC_aby_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ADC_aby_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ADC_aby_cycles, top, vcdOut, counter, true);
  run_n_cycles(ADC_aby_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::V | P_Flags::N, top.dbg_P_out);
  ERR_IF_NEQ(fetch2, top.dbg_state_out);

  run_n_cycles(SBC_aby_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::Z | P_Flags::V | P_Flags::C, top.dbg_P_out);
  run_n_cycles(SBC_aby_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(ADC_aby_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  run_n_cycles(SBC_aby_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(fetch2, top.dbg_state_out);

  // Pad output
  run_n_cycles(6, top, vcdOut, counter, true);

  return 0;
}

int testArithmeticIndirects(VtopLevel &top, VerilatedVcdC &vcdOut) {
  // [](../6502-code/ROM/arithmetic_indirect.test.asm)

  int resetResult = reset(top, vcdOut, false);
  if (resetResult == -1)
    return log_error(), -1;

  int counter = resetResult;

  run_n_cycles(DEX_imp_cycles, top, vcdOut, counter, true);

  run_n_cycles(ADC_izx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z | P_Flags::C, top.dbg_P_out);

  run_n_cycles(CLC_imp_cycles, top, vcdOut, counter, true);
  run_n_cycles(INX_imp_cycles, top, vcdOut, counter, true);

  run_n_cycles(ADC_izx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ADC_izx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ADC_izx_cycles, top, vcdOut, counter, true);
  run_n_cycles(ADC_izx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::V | P_Flags::N, top.dbg_P_out);

  run_n_cycles(SBC_izx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z | P_Flags::V | P_Flags::C, top.dbg_P_out);
  run_n_cycles(SBC_izx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  // Indirect, Y
  run_n_cycles(ADC_izy_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z | P_Flags::C, top.dbg_P_out);

  run_n_cycles(CLC_imp_cycles + LDY_imm_cycles, top, vcdOut, counter, true);

  run_n_cycles(ADC_izy_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ADC_izy_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ADC_izy_cycles, top, vcdOut, counter, true);
  run_n_cycles(ADC_izy_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0x80, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::V | P_Flags::N, top.dbg_P_out);

  run_n_cycles(SBC_izy_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z | P_Flags::V | P_Flags::C, top.dbg_P_out);
  run_n_cycles(SBC_izy_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  // Page cross
  run_n_cycles(ADC_izy_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  run_n_cycles(SBC_izy_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(fetch2, top.dbg_state_out);

  // Pad output
  run_n_cycles(6, top, vcdOut, counter, true);

  return 0;
}

int testShifts(VtopLevel &top, VerilatedVcdC &vcdOut) {
  int resetResult = reset(top, vcdOut, false);
  if (resetResult == -1)
    return log_error(), -1;

  int counter = resetResult;

  // Acc

  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(ASL_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0b1000'0000, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ASL_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(LSR_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);

  run_n_cycles(CLC_imp_cycles + LDA_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(ROL_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0b1000'0000, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ROL_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ROL_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(1, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::NONE, top.dbg_P_out);

  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(ROR_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ROR_imp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0b1000'0000, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  // ZP
  run_n_cycles(CLC_imp_cycles, top, vcdOut, counter, true);

  run_n_cycles(ASL_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0b1000'0000, TestMap::read(0));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ASL_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(0));
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LSR_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(1));
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);

  run_n_cycles(CLC_imp_cycles, top, vcdOut, counter, true);
  run_n_cycles(ROL_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0b1000'0000, TestMap::read(2));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ROL_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(2));
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ROL_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(1, TestMap::read(2));
  ERR_IF_NEQ(P_Flags::NONE, top.dbg_P_out);

  run_n_cycles(ROR_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(3));
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ROR_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0b1000'0000, TestMap::read(3));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  // ZP,X
  run_n_cycles(CLC_imp_cycles + INX_imp_cycles, top, vcdOut, counter, true);

  run_n_cycles(ASL_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0b1000'0000, TestMap::read(5));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ASL_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(5));
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LSR_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(6));
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);

  run_n_cycles(CLC_imp_cycles, top, vcdOut, counter, true);
  run_n_cycles(ROL_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0b1000'0000, TestMap::read(7));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ROL_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(7));
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ROL_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(1, TestMap::read(7));
  ERR_IF_NEQ(P_Flags::NONE, top.dbg_P_out);

  run_n_cycles(ROR_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(8));
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ROR_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0b1000'0000, TestMap::read(8));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  // Absolute

  run_n_cycles(CLC_imp_cycles, top, vcdOut, counter, true);

  run_n_cycles(ASL_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0b1000'0000, TestMap::read(0x200));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ASL_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(0x200));
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LSR_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(0x201));
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);

  run_n_cycles(CLC_imp_cycles, top, vcdOut, counter, true);
  run_n_cycles(ROL_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0b1000'0000, TestMap::read(0x202));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ROL_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(0x202));
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ROL_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(1, TestMap::read(0x202));
  ERR_IF_NEQ(P_Flags::NONE, top.dbg_P_out);

  run_n_cycles(ROR_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(0x203));
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ROR_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0b1000'0000, TestMap::read(0x203));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  // Absolute,X
  run_n_cycles(CLC_imp_cycles, top, vcdOut, counter, true);

  run_n_cycles(ASL_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0b1000'0000, TestMap::read(0x205));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ASL_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(0x205));
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LSR_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(0x206));
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);

  run_n_cycles(CLC_imp_cycles, top, vcdOut, counter, true);
  run_n_cycles(ROL_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0b1000'0000, TestMap::read(0x207));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(ROL_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(0x207));
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ROL_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(1, TestMap::read(0x207));
  ERR_IF_NEQ(P_Flags::NONE, top.dbg_P_out);

  run_n_cycles(ROR_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, TestMap::read(0x208));
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ROR_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0b1000'0000, TestMap::read(0x208));
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  // Pad output
  run_n_cycles(6, top, vcdOut, counter, true);

  return 0;
}

int testBitwise(VtopLevel &top, VerilatedVcdC &vcdOut) {
  int resetResult = reset(top, vcdOut, false);
  if (resetResult == -1)
    return log_error(), -1;

  int counter = resetResult;

  // IMM

  run_n_cycles(LDA_imm_cycles + LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(AND_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(AND_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDA_imm_cycles + LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(ORA_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ORA_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(EOR_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(EOR_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  // ZP

  run_n_cycles(LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(AND_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(AND_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDA_imm_cycles + LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(ORA_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ORA_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(EOR_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(EOR_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  // ZP,X

  run_n_cycles(LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(AND_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(AND_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDA_imm_cycles + LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(ORA_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ORA_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(EOR_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(EOR_zpx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  // Absolute

  run_n_cycles(LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(AND_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(AND_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDA_imm_cycles + LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(ORA_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ORA_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(EOR_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(EOR_abs_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  // Absolute, X

  run_n_cycles(LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(AND_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(AND_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDA_imm_cycles + LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(ORA_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ORA_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(EOR_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(EOR_abx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(AND_abx_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  run_n_cycles(ORA_abx_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  run_n_cycles(EOR_abx_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);

  // Absolute, Y
  run_n_cycles(LDA_imm_cycles + LDY_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(AND_aby_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(AND_aby_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDA_imm_cycles + LDY_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(ORA_aby_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ORA_aby_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(EOR_aby_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(EOR_aby_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(LDY_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(AND_aby_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  run_n_cycles(ORA_aby_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  run_n_cycles(EOR_aby_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);

  // (Indirect, X)

  run_n_cycles(LDA_imm_cycles + LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(AND_izx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(AND_izx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDA_imm_cycles + LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(ORA_izx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ORA_izx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(EOR_izx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(EOR_izx_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  // (Indirect), Y

  run_n_cycles(LDA_imm_cycles + LDY_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(AND_izy_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(AND_izy_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);

  run_n_cycles(LDA_imm_cycles + LDY_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(ORA_izy_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(ORA_izy_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(EOR_izy_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::Z, top.dbg_P_out);
  run_n_cycles(EOR_izy_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);

  run_n_cycles(LDY_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(AND_izy_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);
  run_n_cycles(ORA_izy_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0xff, top.dbg_A_out);
  run_n_cycles(EOR_izy_cycles + page_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(0, top.dbg_A_out);

  // Pad output
  run_n_cycles(6, top, vcdOut, counter, true);

  return 0;
}

int testCompare(VtopLevel &top, VerilatedVcdC &vcdOut) {
  int resetResult = reset(top, vcdOut, false);
  if (resetResult == -1)
    return log_error(), -1;

  int counter = resetResult;

  // Immediate

  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(CMP_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(CMP_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(CMP_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::C, top.dbg_P_out);

  run_n_cycles(LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(CPX_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(CPX_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(CPX_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::C, top.dbg_P_out);

  run_n_cycles(LDY_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(CPY_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(CPY_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(CPY_imm_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::C, top.dbg_P_out);
  
  // ZP

  run_n_cycles(LDA_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(CMP_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(CMP_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(CMP_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::C, top.dbg_P_out);

  run_n_cycles(LDX_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(CPX_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(CPX_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(CPX_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::C, top.dbg_P_out);

  run_n_cycles(LDY_imm_cycles, top, vcdOut, counter, true);
  run_n_cycles(CPY_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::C | P_Flags::Z, top.dbg_P_out);
  run_n_cycles(CPY_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::N, top.dbg_P_out);
  run_n_cycles(CPY_zp_cycles, top, vcdOut, counter, true);
  ERR_IF_NEQ(P_Flags::C, top.dbg_P_out);

  // Pad output
  run_n_cycles(6, top, vcdOut, counter, true);

  return 0;
}

// Configure test information with this
typedef struct {
  int (*testFunction)(VtopLevel &, VerilatedVcdC &);
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
      {.testFunction = testFlagsBranch,
       .vcdFile = "./vcd_out/flags_branch_test.vcd",
       .programFile = "./obj_dir/flags_branch.test.o65",
       .romStartAddress = StandardProgramRomAddr,
       .skip = false},
      {.testFunction = testTransfer,
       .vcdFile = "./vcd_out/transfer_test.vcd",
       .programFile = "./obj_dir/transfer.test.o65",
       .romStartAddress = StandardProgramRomAddr,
       .skip = false},
      {.testFunction = testStack,
       .vcdFile = "./vcd_out/stack_test.vcd",
       .programFile = "./obj_dir/stack.test.o65",
       .romStartAddress = StandardProgramRomAddr,
       .skip = false},
      {.testFunction = testIncDec,
       .vcdFile = "./vcd_out/inc_dec_x_y_test.vcd",
       .programFile = "./obj_dir/inc_dec_x_y.test.o65",
       .romStartAddress = StandardProgramRomAddr,
       .skip = false},
      {.testFunction = testArithmetic,
       .vcdFile = "./vcd_out/arithmetic_test.vcd",
       .programFile = "./obj_dir/arithmetic.test.o65",
       .romStartAddress = StandardProgramRomAddr,
       .skip = false},
      {.testFunction = testArithmeticIndirects,
       .vcdFile = "./vcd_out/arithmetic_indirect_test.vcd",
       .programFile = "./obj_dir/arithmetic_indirect.test.o65",
       .romStartAddress = StandardProgramRomAddr,
       .skip = false},
      {.testFunction = testShifts,
       .vcdFile = "./vcd_out/shift_test.vcd",
       .programFile = "./obj_dir/shift.test.o65",
       .romStartAddress = StandardProgramRomAddr,
       .skip = false},
      {.testFunction = testBitwise,
       .vcdFile = "./vcd_out/bitwise_test.vcd",
       .programFile = "./obj_dir/bitwise.test.o65",
       .romStartAddress = StandardProgramRomAddr,
       .skip = false},
       {.testFunction = testCompare,
       .vcdFile = "./vcd_out/compare_test.vcd",
       .programFile = "./obj_dir/compare.test.o65",
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
    int result = tests[i].testFunction(top, vcdOut);
    if (result != 0)
      return log_error("Failed tests.\n"), -1;

    vcdOut.close();
    delete[] memory;
  }

  printf("Done with %s\n", __FILE_NAME__);
  return 0;
}
