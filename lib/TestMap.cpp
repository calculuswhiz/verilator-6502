#pragma once

#include <cstdint>
#include <cstdio>
using std::printf;

/**
  A very simple memory-mapper. Allows you to specify a ROM address start.
  Above that address until 0xffff, that memory will be treated as read only,
  i.e. writing to it will do nothing.

  Address is 16 bit, byte-addressed.
*/
namespace TestMap {
// Base of the memory region
uint8_t *data;
// Where the ROM region starts. Above this, address is not writable
uint16_t romAddress = 0;

// Point the data and rom address to the right location for read/write
void initMap(uint8_t *initialMemory, uint16_t romStartAddress) {
  data = initialMemory;
  romAddress = romStartAddress;
}

// Read from location of memory map
uint8_t read(uint16_t address) { return data[address]; }

// Write to location of memory map. If it's in a ROM region, it does not
// overwrite the value
void write(uint16_t address, uint8_t byte) {
  // ROM region
  if (address < romAddress)
    data[address] = byte;
}

void dumpRange(uint16_t from, uint16_t to) {
  for (int i = from; i <= to; i++) {
    printf("%0x:%0x\n", i, read(i));
  }
}
} // namespace TestMap
