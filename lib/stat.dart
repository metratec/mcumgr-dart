import 'package:cbor/cbor.dart';
import 'package:mcumgr/client.dart';
import 'package:mcumgr/msg.dart';
import 'package:mcumgr/util.dart';

const _statGroup = 2;
const _statCmdGroupData = 0;
const _statCmdListGroups = 1;

class StatGroup {
  final String name;
  final Map<String, int> stats;

  StatGroup(CborMap input)
      : name = (input[CborString('name')] as CborString).toString(),
        stats = _parseStats(input);

  static Map<String, int> _parseStats(CborMap input) {
    final result = <String, int>{};
    final fields = input[CborString('fields')] as CborMap?;
    if (fields != null) {
      for (final entry in fields.entries) {
        result[(entry.key as CborString).toString()] =
            (entry.value as CborInt).toInt();
      }
    }
    return result;
  }

  @override
  String toString() => 'StatGroup{$name, stats=$stats}';
}

extension ClientStatExtension on Client {
  /// Lists all available statistics group names.
  Future<List<String>> statListGroups(Duration timeout) {
    return execute(
      Message(
        op: Operation.read,
        group: _statGroup,
        id: _statCmdListGroups,
        flags: 0,
        data: CborMap({}),
      ),
      timeout,
    ).unwrap().then((msg) {
      final list = msg.data[CborString('stat_list')] as CborList;
      return list.map((v) => (v as CborString).toString()).toList();
    });
  }

  /// Gets statistics for a named group.
  Future<StatGroup> statGroupData(String name, Duration timeout) {
    return execute(
      Message(
        op: Operation.read,
        group: _statGroup,
        id: _statCmdGroupData,
        flags: 0,
        data: CborMap({CborString('name'): CborString(name)}),
      ),
      timeout,
    ).unwrap().then((msg) => StatGroup(msg.data));
  }
}
