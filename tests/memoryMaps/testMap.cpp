#include <cstdint>

/** 
  A very simple memory-mapper. Allows you to specify a ROM address start.
  Above that address until 0xffff, that memory will be treated as read only,
  i.e. writing to it will do nothing.

  Address is 16 bit, byte-addressed.
*/
namespace TestMap {
  uint8_t *data;
  
  uint16_t romAddress = 0;
  
  void initMap(uint8_t *initialMemory, uint16_t romStartAddress) {
    data = initialMemory;
    romAddress = romStartAddress;
  }
  
  void cleanup() { delete[] data; }
  
  uint8_t read(uint16_t address) { 
    return data[address]; 
  }
  
  void write(uint16_t address, uint8_t byte) {
    // ROM region
    if (address < romAddress)
      data[address] = byte;
  }
}
