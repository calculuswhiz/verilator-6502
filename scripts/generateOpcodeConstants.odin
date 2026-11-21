package main

// From the top: odin run -file ./scripts/generateOpcodeConstants.odin

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

@(private = "file")
Opcode :: struct {
	name:  string,
	value: string,
}

main :: proc() {
	script_dir :=
		os.get_executable_directory(context.allocator) or_else fmt.panicf(
			"Cannot get executable dir",
		)

	// Read cpu_states.cfg
	config_path :=
		filepath.join({script_dir, "scripts/cpu_states.cfg"}) or_else panic("Could not join")
	config_data :=
		os.read_entire_file_from_path(config_path, context.allocator) or_else fmt.panicf(
			"Failed to get data %s",
			config_path,
		)
	defer delete(config_data)

	config_str := string(config_data)
	lines := strings.split(config_str, "\n")
	defer delete(lines)

	// Parse opcodes and handle duplicates
	parsed := make([dynamic]Opcode)
	seen_already := make(map[string]int)
	defer delete(parsed)
	defer delete(seen_already)

	for line in lines {
		trimmed := strings.trim(line, " \t\r\n")

		// Skip comments and empty lines
		if len(trimmed) == 0 || strings.starts_with(trimmed, "#") {
			continue
		}

		// Split by whitespace
		parts := strings.fields(trimmed)
		if len(parts) < 2 {
			continue
		}

		name := parts[0]
		value := parts[1]

		opcode_name := name
		if name in seen_already {
			times := seen_already[name] + 1
			opcode_name = fmt.aprintf("%v_%v", name, times)
			seen_already[name] = times
		} else {
			seen_already[name] = 0
		}

		append(&parsed, Opcode{opcode_name, value})
	}

	// Generate Verilog SystemVerilog header file
	generate_sverilog(parsed, script_dir)

	// Generate Odin constants file
	generate_odin(parsed, script_dir)

	// Generate TOML filter file
	generate_toml(parsed, script_dir)

	fmt.println("Opcode constants generated successfully!")
}

generate_sverilog :: proc(parsed: [dynamic]Opcode, script_dir: string) {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	strings.write_string(&sb, "/* GENERATED (generateOpcodeConstants.odin) - DO NOT EDIT */\n")
	strings.write_string(&sb, "`ifndef OP_CODE_HEX_SV\n")
	strings.write_string(&sb, "`define OP_CODE_HEX_SV\n\n")
	strings.write_string(&sb, "typedef enum logic [11:0] {\n")

	for opcode, i in parsed {
		if i > 0 {
			strings.write_string(&sb, ",\n")
		}
		fmt.sbprintf(&sb, "  %v = 12'h%v", opcode.name, opcode.value)
	}

	strings.write_string(&sb, "\n} cpu_state;\n")
	strings.write_string(&sb, "`endif\n")

	output_path :=
		filepath.join({script_dir, "verilog/svh/opCodeHex.svh"}) or_else panic("Cannot join")
	os.write_entire_file(output_path, sb.buf[:]) or_else panic("Cannot write")
}

generate_odin :: proc(parsed: [dynamic]Opcode, script_dir: string) {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	strings.write_string(&sb, "package PcState\n")
	strings.write_string(&sb, "/* GENERATED (generateOpcodeConstants.odin) - DO NOT EDIT */\n")

	for opcode in parsed {
		fmt.sbprintf(&sb, "%v :: 0x%v\n", opcode.name, opcode.value)
	}

	output_path :=
		filepath.join({script_dir, "tests/odin/PcState/PcState.odin"}) or_else panic("Cannot join")
	os.write_entire_file(output_path, sb.buf[:]) or_else panic("Cannot write")
}

generate_toml :: proc(parsed: [dynamic]Opcode, script_dir: string) {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	strings.write_string(&sb, "# Please add more if you update opCodeHex.sv\n")
	strings.write_string(
		&sb,
		"# On mac, copy to ~/Library/Application Support/org.surfer-project.surfer/mappings\n",
	)

	for opcode in parsed {
		fmt.sbprintf(&sb, "0x%v %v\n", opcode.value, opcode.name)
	}

	output_path :=
		filepath.join({script_dir, "filters/6502-state.toml"}) or_else panic("Cannot join")
	os.write_entire_file(output_path, sb.buf[:]) or_else panic("Cannot write")

	when ODIN_OS == .Darwin {
		home_dir, home_dir_err := os.user_home_dir(context.allocator)
		if home_dir_err != nil {
			fmt.eprintln("No home directory", home_dir_err)
		}
		join, _ := filepath.join(
			{
				home_dir,
				"/Library/Application Support/org.surfer-project.surfer/mappings/6502-state.toml",
			},
		)
		writeResult := os.write_entire_file(join, sb.buf[:])
		if writeResult != nil {
			fmt.eprintln("Cannot write surfer file. Do you have surfer installed?", writeResult)
		}
		fmt.println(
			"Wrote to '~/Library/Application Support/org.surfer-project.surfer/mappings/6502-state.toml'",
		)
	}
}
