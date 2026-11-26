package scripts

// From the top: odin run -file ./scripts/generateOpcodeCycles.odin

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:strings"

@(private = "file")
AddressMode :: enum {
	imp,
	imm,
	zp,
	zpx,
	zpy,
	izx,
	izy,
	abs,
	abx,
	aby,
	ind,
	rel,
}

@(private = "file")
Opcode :: struct {
	opcode:         int,
	mnemonic:       string,
	cycles:         int,
	mode:           AddressMode,
	is_branch:      bool,
	has_page_check: bool,
}

@(private = "file")
main :: proc() {
	dir :=
		os.get_executable_directory(context.allocator) or_else fmt.panicf(
			"Cannot get executable dir",
		)
	src_path :=
		filepath.join({dir, "scripts/6502_opcode_cycles.csv"}) or_else fmt.panicf(
			"Failed to get srcPath",
		)
	data :=
		os.read_entire_file_from_path(src_path, context.allocator) or_else fmt.panicf(
			"Failed to get data %s",
			src_path,
		)

	defer delete(data, context.allocator)

	parsed := [256]Opcode{}

	row_addr_idx := 0
	contents := string(data)
	for line in strings.split_lines_iterator(&contents) {
		defer row_addr_idx += 1

		trimmed := strings.trim(line, " \t")
		col_addr_idx := 0

		for row_data in strings.split_iterator(&trimmed, ",") {
			defer col_addr_idx += 1

			entry := strings.split(row_data, " ")
			mnemonic := entry[0]
			mode := AddressMode.imp
			if len(entry) >= 3 {
				mode =
					fmt.string_to_enum_value(AddressMode, entry[1]) or_else fmt.panicf(
						"Could not convert enum string, %s",
						entry[1],
					)
			}

			last_entry := entry[len(entry) - 1]
			has_page_check := strings.ends_with(last_entry, "*")
			cycles := -1
			if len(entry) != 1 {
				replaced, was_allocated := strings.replace_all(last_entry, "*", "")
				defer if was_allocated do delete(replaced)

				cycles = strconv.parse_int(replaced) or_else fmt.panicf("Could not parse cycles")
			}

			// Branches are the only rel instructions
			is_branch := mode == AddressMode.rel
			opcode := row_addr_idx << 4 + col_addr_idx
			parsed[opcode] = {
				opcode         = opcode,
				mnemonic       = mnemonic,
				cycles         = cycles,
				mode           = mode,
				is_branch      = is_branch,
				has_page_check = has_page_check,
			}
		}
	}

	emitted_already := make(map[string]bool)
	defer delete(emitted_already)

	out_path := filepath.join({dir, "tests/odin/Lib6502/Lib6502.odin"}) or_else os.exit(-1)
	out_file := os.open(out_path, {.Write, .Trunc}) or_else os.exit(-1)
	defer os.close(out_file)

	os.write_string(
		out_file,
		"""
    package Lib6502
    /* GENERATED - DO NOT EDIT */

    branch_taken_cycles :: 1
    page_cycles :: 1


    """,
	)

	for row in parsed {
		var_name := fmt.tprintf(
			"%s_%s_cycles",
			row.mnemonic,
			fmt.enum_value_to_string(row.mode) or_else "",
		)

		if emitted_already[var_name] {
			os.write_string(
				out_file,
				fmt.tprintfln("// Skipped duplicate: %s (%#x)", var_name, row.opcode),
			)
		} else {
			emitted_already[var_name] = true
			os.write_string(out_file, fmt.tprintfln("%s :: %d", var_name, row.cycles))
		}
	}

	fmt.printfln("Wrote to %s", out_path)
}
