package VerilatedVcdC

ptr :: distinct rawptr

foreign import MyVerilatedVcdC {"system:c++", "../../../../obj_dir/libverilated.a"}

@(default_calling_convention = "c")
foreign MyVerilatedVcdC {
	VerilatedVcd_create :: proc() -> ptr ---
	VerilatedVcd_destroy :: proc(instance: ptr) ---

	VerilatedVcd_open :: proc(instance: ptr, fileName: cstring) ---
	VerilatedVcd_dump :: proc(instance: ptr, timestamp: int) ---
}
