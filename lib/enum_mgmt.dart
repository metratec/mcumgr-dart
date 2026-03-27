import 'package:cbor/cbor.dart';
import 'package:mcumgr/client.dart';
import 'package:mcumgr/msg.dart';
import 'package:mcumgr/util.dart';

const _enumGroup = 10;
const _enumCmdCount = 0;
const _enumCmdList = 1;
const _enumCmdSingle = 2;
const _enumCmdDetails = 3;

class EnumEntry {
  final int group;
  final bool end;

  EnumEntry(CborMap input)
      : group = (input[CborString('group')] as CborInt).toInt(),
        end = (input[CborString('end')] as CborBool?)?.value ?? false;

  @override
  String toString() => 'EnumEntry{group=$group, end=$end}';
}

class EnumGroupDetails {
  final int id;
  final String name;
  final int handlers;

  EnumGroupDetails(CborMap input)
      : id = (input[CborString('id')] as CborInt).toInt(),
        name = (input[CborString('name')] as CborString).toString(),
        handlers = (input[CborString('handlers')] as CborInt).toInt();

  @override
  String toString() => 'EnumGroup{id=$id, name=$name, handlers=$handlers}';
}

extension ClientEnumExtension on Client {
  /// Gets the number of registered management groups.
  Future<int> enumCount(Duration timeout) {
    return execute(
      Message(
        op: Operation.read,
        group: _enumGroup,
        id: _enumCmdCount,
        flags: 0,
        data: CborMap({}),
      ),
      timeout,
    ).unwrap().then(
          (msg) => (msg.data[CborString('count')] as CborInt).toInt(),
        );
  }

  /// Lists all registered management group IDs.
  Future<List<int>> enumList(Duration timeout) {
    return execute(
      Message(
        op: Operation.read,
        group: _enumGroup,
        id: _enumCmdList,
        flags: 0,
        data: CborMap({}),
      ),
      timeout,
    ).unwrap().then((msg) {
      final groups = msg.data[CborString('groups')] as CborList;
      return groups.map((v) => (v as CborInt).toInt()).toList();
    });
  }

  /// Gets a single group entry by index.
  Future<EnumEntry> enumSingle(Duration timeout, {int? index}) {
    final data = <CborValue, CborValue>{};
    if (index != null) data[CborString('index')] = CborSmallInt(index);
    return execute(
      Message(
        op: Operation.read,
        group: _enumGroup,
        id: _enumCmdSingle,
        flags: 0,
        data: CborMap(data),
      ),
      timeout,
    ).unwrap().then((msg) => EnumEntry(msg.data));
  }

  /// Gets detailed information about all management groups.
  Future<List<EnumGroupDetails>> enumDetails(Duration timeout) {
    return execute(
      Message(
        op: Operation.read,
        group: _enumGroup,
        id: _enumCmdDetails,
        flags: 0,
        data: CborMap({}),
      ),
      timeout,
    ).unwrap().then((msg) {
      final groups = msg.data[CborString('groups')] as CborList;
      return groups
          .map((v) => EnumGroupDetails(v as CborMap))
          .toList();
    });
  }
}
