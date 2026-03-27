# CLAUDE.md

## Project

Dart implementation of the MCU Manager (mcumgr) SMP protocol. Forked from jkdhn/mcumgr-dart, maintained by metraTec.

## Architecture

- `lib/client.dart` -- Core `Client` class. Takes input stream + output callback + encoding. Handles sequence numbering and request/response correlation.
- `lib/src/encoding.dart` -- Abstract `Encoding` interface (encode Packet to bytes, decode stream to Packets).
- `lib/src/smp.dart` -- `Smp` encoding for BLE transport (raw SMP header + CBOR content).
- `lib/src/smp_serial.dart` -- `SmpSerial` encoding for serial/UART transport. Handles base64 line framing (0x06 0x09 / 0x04 0x14), augmented CRC16-CCITT, multi-line splitting.
- `lib/src/crc16.dart` -- CRC16 matching AuTerm/Zephyr (poly 0x1021, init 0, 2-byte zero padding, MSB-first). CRC covers SMP data only, not the length field.
- `lib/packet.dart` -- `Header` (8 bytes, SMP v2 by default) and `Packet` (header + CBOR content).
- `lib/msg.dart` -- `Message` (high-level: op, group, id, flags, CBOR data).
- `lib/util.dart` -- `McuException`, response unwrap extension.

Management groups (each is an `extension on Client`):
- `lib/os.dart` -- OS group (0): echo, reset, task stats, memory pools, date/time, mcumgr params, app info, bootloader info
- `lib/img.dart` -- Image group (1): state, upload, erase, confirm, slot info. Also contains `McuImage` decoder for .bin firmware files.
- `lib/stat.dart` -- Statistics group (2): list groups, group data
- `lib/settings.dart` -- Settings group (3): read, write, delete, commit, load, save
- `lib/fs.dart` -- File System group (8): upload, download, status, hash/checksum, supported hashes, close
- `lib/shell.dart` -- Shell group (9): execute
- `lib/enum_mgmt.dart` -- Enumeration group (10): count, list, single, details
- `lib/zephyr.dart` -- Zephyr group (63): storage erase

## Serial Frame Format

```
TX: 0x06 0x09 <base64(len_BE16 + smp_data + crc16_BE16)> \n
    0x04 0x14 <base64 continuation> \n  (if > 124 base64 chars)

len = smpData.length + 2 (includes CRC in count)
CRC = augmented CRC16-CCITT over smpData only (not len field)
Max 124 base64 chars per line (matching AuTerm's 93 raw bytes)
```

## Key Protocol Details

- SMP v2: Header byte 0 = `(op & 0x07) | ((version & 0x03) << 3)`. Version=1 for SMP v2.
- Serial chunk size: 64 bytes recommended (fits in Zephyr's default 256-byte MTU)
- CRC verified against AuTerm (https://github.com/thedjnK/AuTerm)

## Commands

```bash
dart pub get
dart analyze lib/
dart test
```
