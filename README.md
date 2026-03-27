# mcumgr

Dart client library for the [mcumgr](https://docs.zephyrproject.org/latest/services/device_mgmt/mcumgr.html) device management protocol (SMP).

Forked from [jkdhn/mcumgr-dart](https://github.com/jkdhn/mcumgr-dart), updated for Dart 3 and extended with serial transport and all standard management groups.

## Features

- SMP v1 and v2 protocol support
- BLE and Serial (UART) transport
- All 8 standard management groups:

| Group | ID | Operations |
|-------|---:|------------|
| **OS** | 0 | echo, reset, task stats, memory pools, date/time, mcumgr params, app info, bootloader info |
| **Image** | 1 | list state, upload firmware (DFU), erase, confirm, set pending, slot info |
| **Statistics** | 2 | list groups, get group data |
| **Settings** | 3 | read, write, delete, commit, load, save |
| **File System** | 8 | upload, download, status, hash/checksum, supported hashes, close |
| **Shell** | 9 | execute commands |
| **Enumeration** | 10 | count, list, single, details |
| **Zephyr** | 63 | storage erase |

## Usage

```dart
import 'package:mcumgr/mcumgr.dart';
```

### Serial (UART)

```dart
import 'package:flutter_libserialport/flutter_libserialport.dart';

final port = SerialPort('/dev/ttyUSB0')..openReadWrite();
port.config = SerialPortConfig()
  ..baudRate = 115200
  ..bits = 8
  ..parity = SerialPortParity.none
  ..stopBits = 1
  ..setFlowControl(SerialPortFlowControl.none);

final reader = SerialPortReader(port);

final client = Client(
  input: reader.stream,
  output: (bytes) => port.write(Uint8List.fromList(bytes)),
  encoding: smpSerial,  // serial line framing with CRC16
);
```

### Bluetooth LE

```dart
// Using flutter_blue or similar BLE package
await device.requestMtu(252);

final client = Client(
  input: characteristic.onValueChangedStream,
  output: (value) => characteristic.write(value, withoutResponse: true),
  // encoding defaults to smp (raw SMP, suitable for BLE)
);
```

### OS Management

```dart
// Echo test
final response = await client.echo('hello', Duration(seconds: 5));

// Device info
final info = await client.appInfo(Duration(seconds: 5));
final params = await client.mcumgrParameters(Duration(seconds: 5));
print('Buffer: ${params.bufSize} x ${params.bufCount}');

// Task statistics
final tasks = await client.taskStats(Duration(seconds: 5));
for (final t in tasks) {
  print('${t.name}: prio=${t.priority} stack=${t.stackUsed}/${t.stackSize}');
}

// Reset
await client.reset(Duration(seconds: 5));
```

### Firmware Update (DFU)

```dart
final firmware = await File('app_update.bin').readAsBytes();
final image = McuImage.decode(firmware);

// Upload
await client.uploadImage(
  0,                           // image slot
  firmware,
  image.hash,
  Duration(seconds: 10),
  chunkSize: 64,               // use 64 for serial, 128+ for BLE
  windowSize: 1,               // use 1 for serial, 3+ for BLE
  onProgress: (bytes) => print('${bytes}/${firmware.length}'),
);

// Set pending and reboot
await client.setPendingImage(image.hash, false, Duration(seconds: 5));
await client.reset(Duration(seconds: 5));

// After reconnecting: confirm
await client.confirmImageState(Duration(seconds: 5));
```

### Shell

```dart
final result = await client.shellExecute(['kernel', 'version'], Duration(seconds: 5));
print('${result.output} (rc=${result.returnCode})');
```

### File System

```dart
// Upload a file
final data = await File('config.txt').readAsBytes();
await client.fsUpload('/lfs/config.txt', data, Duration(seconds: 10),
    chunkSize: 64);

// Download a file
final downloaded = await client.fsDownload('/lfs/config.txt', Duration(seconds: 10));

// Get file info
final status = await client.fsStatus('/lfs/config.txt', Duration(seconds: 5));
print('Size: ${status.length}');
```

### Settings

```dart
final value = await client.readSetting('my/setting', Duration(seconds: 5));
await client.writeSetting('my/setting', [0x01, 0x02], Duration(seconds: 5));
await client.commitSettings(Duration(seconds: 5));
```

### Statistics

```dart
final groups = await client.statListGroups(Duration(seconds: 5));
for (final name in groups) {
  final data = await client.statGroupData(name, Duration(seconds: 5));
  print('$name: ${data.stats}');
}
```

### Enumeration

```dart
final details = await client.enumDetails(Duration(seconds: 5));
for (final g in details) {
  print('Group ${g.id}: ${g.name} (${g.handlers} commands)');
}
```

## License

BSD-3-Clause (see [LICENSE](LICENSE))
