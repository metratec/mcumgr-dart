/// Augmented CRC16-CCITT as used by the mcumgr serial protocol.
///
/// Polynomial 0x1021, initial value 0x0000, MSB-first bit processing,
/// with 2-byte zero padding (augmented). Matches AuTerm and Zephyr
/// mcumgr serial transport implementations.
int crc16(List<int> data) {
  int crc = 0;
  final totalLen = data.length + 2; // 2 bytes zero padding
  for (int i = 0; i < totalLen; i++) {
    for (int b = 0; b < 8; b++) {
      final divide = crc & 0x8000;
      crc = (crc << 1) & 0xFFFF;
      if (i < data.length) {
        crc |= ((data[i] & (0x80 >> b)) != 0) ? 1 : 0;
      }
      if (divide != 0) {
        crc ^= 0x1021;
      }
    }
  }
  return crc;
}
