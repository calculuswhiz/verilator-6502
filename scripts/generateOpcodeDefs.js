// Simple node/bun script that generates the opcode constants for different languages
import * as fs from 'fs/promises';
import path from 'path';

const opcodeLines = (await fs.readFile(
  path.join(import.meta.dirname, "../lib/opcodes.cfg"),
  "utf-8"
)).split("\n").map(x => x.trim());

/** @type [string, string][] */
const parsed = [];

for (const line of opcodeLines) {
  if (line.startsWith("#") || line.length === 0)
    continue;

  parsed.push(line.split(" "));
}

await fs.writeFile(
  path.join(import.meta.dirname, "../verilog/opCodeHex.sv"),
  `/* GENERATED - DO NOT EDIT */
\`ifndef OP_CODE_HEX_SV
\`define OP_CODE_HEX_SV

typedef enum logic [11:0] {
  ${parsed.map(([name, value]) => `${name} = 12'h${value}`).join(",\n")}
} cpu_state;
\`endif
`, "utf-8"
);

await fs.writeFile(
  path.join(import.meta.dirname, "../lib/opcodes.h"),
  `#pragma once
/* GENERATED - DO NOT EDIT */

constexpr int ${parsed.map(([name, value]) => `${name} = 0x${value}`).join(",\n\t")};
`, "utf-8"
)
