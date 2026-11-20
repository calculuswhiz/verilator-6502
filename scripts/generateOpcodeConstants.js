// Simple node/bun script that generates the opcode constants for different languages
import * as fs from 'fs/promises';
import path from 'path';

const opcodeLines = (await fs.readFile(
  path.join(import.meta.dirname, "./cpu_states.cfg"),
  "utf-8"
)).split("\n").map(x => x.trim());

/** @type [string, string][] */
const parsed = [];
/** @type Map<string, number> */
const seenAlready = new Map();
for (const line of opcodeLines) {
  if (line.startsWith("#") || line.length === 0)
    continue;
  const [name, value] = line.split(/\s+/);
  if (!seenAlready.has(name)) {
    parsed.push([name, value]);
    seenAlready.set(name, 0);
  } else {
    const times = seenAlready.get(name) + 1;
    parsed.push([`${name}_${times}`, value]);
    seenAlready.set(name, times);
  }
}

await fs.writeFile(
  path.join(import.meta.dirname, "../verilog/opCodeHex.sv"),
  `/* GENERATED (${import.meta.filename}) - DO NOT EDIT */
\`ifndef OP_CODE_HEX_SV
\`define OP_CODE_HEX_SV

typedef enum logic [11:0] {
  ${parsed.map(([name, value]) => `${name} = 12'h${value}`).join(",\n")}
} cpu_state;
\`endif
`, "utf-8"
);

await fs.writeFile(
  path.join(import.meta.dirname, "../tests/odin/PcState/PcState.odin"),
  `package PcState
/* GENERATED (${import.meta.filename}) - DO NOT EDIT */
${parsed.map(([name, value]) => `${name} :: 0x${value}`).join("\n")}
`, "utf-8"
);

await fs.writeFile(
  path.join(import.meta.dirname, "../filters/6502-state.toml"),
  `# Please add more if you update opCodeHex.sv
# On mac, copy to ~/Library/Application Support/org.surfer-project.surfer/mappings
${parsed.map(([name, value]) => `0x${value} ${name}`).join("\n")}`
);
