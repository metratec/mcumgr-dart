import 'package:cbor/cbor.dart';
import 'package:mcumgr/client.dart';
import 'package:mcumgr/msg.dart';
import 'package:mcumgr/util.dart';

const _settingsGroup = 3;
const _settingsCmdReadWrite = 0;
const _settingsCmdDelete = 1;
const _settingsCmdCommit = 2;
const _settingsCmdLoadSave = 3;

extension ClientSettingsExtension on Client {
  /// Reads a setting value by name. Returns raw bytes.
  Future<List<int>> readSetting(String name, Duration timeout,
      {int? maxSize}) {
    final data = <CborValue, CborValue>{
      CborString('name'): CborString(name),
    };
    if (maxSize != null) {
      data[CborString('max_size')] = CborSmallInt(maxSize);
    }
    return execute(
      Message(
        op: Operation.read,
        group: _settingsGroup,
        id: _settingsCmdReadWrite,
        flags: 0,
        data: CborMap(data),
      ),
      timeout,
    ).unwrap().then(
          (msg) => (msg.data[CborString('val')] as CborBytes).bytes,
        );
  }

  /// Writes a setting value by name.
  Future<void> writeSetting(String name, List<int> val, Duration timeout) {
    return execute(
      Message(
        op: Operation.write,
        group: _settingsGroup,
        id: _settingsCmdReadWrite,
        flags: 0,
        data: CborMap({
          CborString('name'): CborString(name),
          CborString('val'): CborBytes(val),
        }),
      ),
      timeout,
    ).unwrap();
  }

  /// Deletes a setting by name.
  Future<void> deleteSetting(String name, Duration timeout) {
    return execute(
      Message(
        op: Operation.write,
        group: _settingsGroup,
        id: _settingsCmdDelete,
        flags: 0,
        data: CborMap({CborString('name'): CborString(name)}),
      ),
      timeout,
    ).unwrap();
  }

  /// Commits pending setting changes to persistent storage.
  Future<void> commitSettings(Duration timeout) {
    return execute(
      Message(
        op: Operation.write,
        group: _settingsGroup,
        id: _settingsCmdCommit,
        flags: 0,
        data: CborMap({}),
      ),
      timeout,
    ).unwrap();
  }

  /// Loads settings from persistent storage.
  Future<void> loadSettings(Duration timeout) {
    return execute(
      Message(
        op: Operation.read,
        group: _settingsGroup,
        id: _settingsCmdLoadSave,
        flags: 0,
        data: CborMap({}),
      ),
      timeout,
    ).unwrap();
  }

  /// Saves current settings to persistent storage.
  Future<void> saveSettings(Duration timeout) {
    return execute(
      Message(
        op: Operation.write,
        group: _settingsGroup,
        id: _settingsCmdLoadSave,
        flags: 0,
        data: CborMap({}),
      ),
      timeout,
    ).unwrap();
  }
}
