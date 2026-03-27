import 'package:cbor/cbor.dart';
import 'package:mcumgr/client.dart';
import 'package:mcumgr/msg.dart';
import 'package:mcumgr/util.dart';

const _zephyrGroup = 63;
const _zephyrCmdStorageErase = 0;

extension ClientZephyrExtension on Client {
  /// Erases Zephyr persistent storage (settings/NVS).
  Future<void> storageErase(Duration timeout) {
    return execute(
      Message(
        op: Operation.write,
        group: _zephyrGroup,
        id: _zephyrCmdStorageErase,
        flags: 0,
        data: CborMap({}),
      ),
      timeout,
    ).unwrap();
  }
}
