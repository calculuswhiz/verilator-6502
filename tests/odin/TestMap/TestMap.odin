package TestMap

import "core:fmt"
import "core:testing"

TestMap :: struct {
	data:       ^[0x1_0000]u8,
	romAddress: u16,
}

// Allocate the memory elsewhere. This just initializes a struct
TestMap_init :: proc(initialMemory: ^[0x1_0000]u8, romStartAddress: u16) -> TestMap {
	return TestMap{initialMemory, romStartAddress}
}

TestMap_read :: proc(testMap: TestMap, address: u16) -> u8 {
	return testMap.data[address]
}

// Write to location of memory map. If it's in a ROM region, it does not
// overwrite the value
TestMap_write :: proc(testMap: TestMap, address: u16, data: u8) {
	if address < testMap.romAddress {
		testMap.data[address] = data
	}
}

TestMap_dumpRange :: proc(testMap: TestMap, from: u16, toInclusive: u16) {
	for i in from ..= toInclusive {
		fmt.printf("%0x:%0x\n", i, TestMap_read(testMap, i))
	}
}

@(test)
test_init_read :: proc(t: ^testing.T) {
	arr: [0x1_0000]u8
	arr[0x10] = 0x10

	testMap := TestMap_init(&arr, 0x8000)
	val := TestMap_read(testMap, 0x10)
	testing.expect_value(t, val, 0x10)
}

@(test)
test_ram_write :: proc(t: ^testing.T) {
	arr: [0x1_0000]u8

	testMap := TestMap_init(&arr, 0x8000)
	TestMap_write(testMap, 0x10, 0x10)
	val := TestMap_read(testMap, 0x10)
	testing.expect_value(t, val, 0x10)
}

@(test)
test_rom_write :: proc(t: ^testing.T) {
	arr: [0x1_0000]u8

	testMap := TestMap_init(&arr, 0x8000)
	TestMap_write(testMap, 0x8000, 0x10)
	val := TestMap_read(testMap, 0)
	testing.expect_value(t, val, 0)
}
