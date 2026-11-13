// Data taken and saved as csv from https://www.oxyron.de/html/opcodes02.html
// Includes unofficial opcodes/cycles

// Simple node/bun script that generates the opcode constants for different languages
import * as fs from 'fs/promises';
import path from 'path';

const opcodeLines = (await fs.readFile(
  path.join(import.meta.dirname, "./6502_opcode_matrix.csv"),
  "utf-8"
)).split("\n")
  .map(x => x.trim())
  .slice(1);

const modes = /** @type {const} */([
  "imp", "imm", "zp", "zpx", "zpy", "izx", "izy",
  "abs", "abx", "aby", "ind", "rel"
]);

/** @typedef {Object} Opcode
 * @property {number} opcode
 * @property {string} mnemonic
 * @property {number} cycles
 * @property {modes[number]} mode
 * @property {boolean} isBranch
 * @property {boolean} hasPageCheck
 */

/** @type Opcode[] */
const parsed = [];

for (let rowIdx = 0; rowIdx <= 0xf; rowIdx++) {
  const row = opcodeLines[rowIdx].split(",").slice(1);
  for (let colIdx = 0; colIdx <= 0xf; colIdx++) {
    const entry = row[colIdx].split(" ");
    const mnemonic = entry[0];
    const mode = (entry.length < 3)
      ? "imp"
      : entry[1];
    const hasPageCheck = entry.at(-1).endsWith("*");
    const cycles = entry.length === 1 ? -1 : +entry.at(-1).replace("*", "");
    // Branches are the only rel instructions
    const isBranch = mode === "rel";
    parsed.push({ opcode: (rowIdx << 4 | colIdx), mnemonic, cycles, mode, isBranch, hasPageCheck });
  }
}

const emittedAlready = new Set();

await fs.writeFile(
  path.join(import.meta.dirname, "../lib/cycles.h"),
  `/* GENERATED - DO NOT EDIT */
  
constexpr int branch_taken_cycles = 1;
constexpr int page_cycles = 1;

${parsed
    .map(row => {
      const varName = `${row.mnemonic}_${row.mode}_cycles`;
      if (emittedAlready.has(varName))
        return `// Skipped duplicate: ${varName} (0x${row.opcode.toString(16)})`;
      emittedAlready.add(varName);
      return `constexpr int ${`${row.mnemonic}_${row.mode}_cycles = ${row.cycles};`}`;
    }
    ).join("\n")
  }
`, "utf-8"
);
