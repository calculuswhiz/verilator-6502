package Verilated

foreign import VerilatedStatic {"../../../../obj_dir/libverilated.a", "../../../../obj_dir/VerilatorStatic.binding.a"}

@(default_calling_convention = "c")
foreign VerilatedStatic {
	@(link_name = "Verilated_traceEverOn")
	traceEverOn :: proc(flag: bool) ---
}
