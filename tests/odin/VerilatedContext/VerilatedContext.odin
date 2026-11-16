package VerilatedContext

foreign import MyVerilatedContext "../../../obj_dir/VerilatedContext.binding.a"

VerilatedContextPtr :: distinct rawptr

@(default_calling_convention = "c")
foreign MyVerilatedContext {
  @(link_name="VerilatedContext_create")
  create :: proc() -> VerilatedContextPtr ---
  @(link_name="VerilatedContext_destroy")
	destroy :: proc(instance: VerilatedContextPtr) ---
}
