import 'package:cbor/cbor.dart';
import 'package:mcumgr/client.dart';
import 'package:mcumgr/msg.dart';
import 'package:mcumgr/util.dart';

const _osGroup = 0;
const _osCmdEcho = 0;
const _osCmdTaskStats = 2;
const _osCmdMemoryPool = 3;
const _osCmdDateTime = 4;
const _osCmdReset = 5;
const _osCmdMcumgrParams = 6;
const _osCmdAppInfo = 7;
const _osCmdBootloaderInfo = 8;

class TaskInfo {
  final String name;
  final int priority;
  final int taskId;
  final int state;
  final int stackUsed;
  final int stackSize;
  final int contextSwitches;
  final int runtime;

  TaskInfo(CborMap input)
      : name = (input[CborString('tname')] as CborString).toString(),
        priority = (input[CborString('prio')] as CborInt).toInt(),
        taskId = (input[CborString('tid')] as CborInt).toInt(),
        state = (input[CborString('state')] as CborInt).toInt(),
        stackUsed = (input[CborString('stkuse')] as CborInt).toInt(),
        stackSize = (input[CborString('stksiz')] as CborInt).toInt(),
        contextSwitches = (input[CborString('cswcnt')] as CborInt).toInt(),
        runtime = (input[CborString('runtime')] as CborInt).toInt();

  @override
  String toString() => 'Task{$name, prio=$priority, state=$state, '
      'stack=$stackUsed/$stackSize}';
}

class MemoryPool {
  final int blockSize;
  final int numBlocks;
  final int numFree;
  final int minFree;

  MemoryPool(CborMap input)
      : blockSize = (input[CborString('blksiz')] as CborInt).toInt(),
        numBlocks = (input[CborString('nblks')] as CborInt).toInt(),
        numFree = (input[CborString('nfree')] as CborInt).toInt(),
        minFree = (input[CborString('min')] as CborInt).toInt();

  @override
  String toString() =>
      'Pool{blk=$blockSize, total=$numBlocks, free=$numFree, min=$minFree}';
}

class McumgrParams {
  final int bufSize;
  final int bufCount;

  McumgrParams(CborMap input)
      : bufSize = (input[CborString('buf_size')] as CborInt).toInt(),
        bufCount = (input[CborString('buf_count')] as CborInt).toInt();

  @override
  String toString() => 'McumgrParams{bufSize=$bufSize, bufCount=$bufCount}';
}

extension ClientOsExtension on Client {
  /// Sends an echo message to the device.
  Future<String> echo(String msg, Duration timeout) {
    return execute(
      Message(
        op: Operation.write,
        group: _osGroup,
        id: _osCmdEcho,
        flags: 0,
        data: CborMap({CborString('d'): CborString(msg)}),
      ),
      timeout,
    ).unwrap().then(
          (msg) => (msg.data[CborString('r')] as CborString).toString(),
        );
  }

  /// Retrieves task statistics from the device.
  Future<List<TaskInfo>> taskStats(Duration timeout) {
    return execute(
      Message(
        op: Operation.read,
        group: _osGroup,
        id: _osCmdTaskStats,
        flags: 0,
        data: CborMap({}),
      ),
      timeout,
    ).unwrap().then((msg) {
      final tasks = msg.data[CborString('tasks')] as CborMap;
      return tasks.values
          .map((v) => TaskInfo(v as CborMap))
          .toList();
    });
  }

  /// Retrieves memory pool statistics from the device.
  Future<List<MemoryPool>> memoryPool(Duration timeout) {
    return execute(
      Message(
        op: Operation.read,
        group: _osGroup,
        id: _osCmdMemoryPool,
        flags: 0,
        data: CborMap({}),
      ),
      timeout,
    ).unwrap().then((msg) {
      final pools = msg.data[CborString('pools')] as CborMap;
      return pools.values
          .map((v) => MemoryPool(v as CborMap))
          .toList();
    });
  }

  /// Gets the device date/time as an ISO 8601 string.
  Future<String> getDateTime(Duration timeout) {
    return execute(
      Message(
        op: Operation.read,
        group: _osGroup,
        id: _osCmdDateTime,
        flags: 0,
        data: CborMap({}),
      ),
      timeout,
    ).unwrap().then(
          (msg) =>
              (msg.data[CborString('datetime')] as CborString).toString(),
        );
  }

  /// Sets the device date/time. [datetime] should be ISO 8601 format.
  Future<void> setDateTime(String datetime, Duration timeout) {
    return execute(
      Message(
        op: Operation.write,
        group: _osGroup,
        id: _osCmdDateTime,
        flags: 0,
        data: CborMap({CborString('datetime'): CborString(datetime)}),
      ),
      timeout,
    ).unwrap();
  }

  /// Resets (reboots) the device.
  Future<void> reset(Duration timeout,
      {bool? force, int? bootMode}) {
    final data = <CborValue, CborValue>{};
    if (force != null) data[CborString('force')] = CborBool(force);
    if (bootMode != null) {
      data[CborString('boot_mode')] = CborSmallInt(bootMode);
    }
    return execute(
      Message(
        op: Operation.write,
        group: _osGroup,
        id: _osCmdReset,
        flags: 0,
        data: CborMap(data),
      ),
      timeout,
    ).unwrap();
  }

  /// Gets MCUMgr buffer parameters (size and count).
  Future<McumgrParams> mcumgrParameters(Duration timeout) {
    return execute(
      Message(
        op: Operation.read,
        group: _osGroup,
        id: _osCmdMcumgrParams,
        flags: 0,
        data: CborMap({}),
      ),
      timeout,
    ).unwrap().then((msg) => McumgrParams(msg.data));
  }

  /// Gets application info string (e.g. uname-like output).
  Future<String> appInfo(Duration timeout, {String? format}) {
    final data = <CborValue, CborValue>{};
    if (format != null) data[CborString('format')] = CborString(format);
    return execute(
      Message(
        op: Operation.read,
        group: _osGroup,
        id: _osCmdAppInfo,
        flags: 0,
        data: CborMap(data),
      ),
      timeout,
    ).unwrap().then(
          (msg) => (msg.data[CborString('output')] as CborString).toString(),
        );
  }

  /// Gets bootloader information.
  Future<Map<String, dynamic>> bootloaderInfo(Duration timeout,
      {String? query}) {
    final data = <CborValue, CborValue>{};
    if (query != null) data[CborString('query')] = CborString(query);
    return execute(
      Message(
        op: Operation.read,
        group: _osGroup,
        id: _osCmdBootloaderInfo,
        flags: 0,
        data: CborMap(data),
      ),
      timeout,
    ).unwrap().then((msg) {
      final result = <String, dynamic>{};
      for (final entry in msg.data.entries) {
        final key = (entry.key as CborString).toString();
        if (key == 'rc') continue;
        final val = entry.value;
        if (val is CborString) {
          result[key] = val.toString();
        } else if (val is CborInt) {
          result[key] = val.toInt();
        } else if (val is CborBool) {
          result[key] = val.value;
        } else {
          result[key] = val.toString();
        }
      }
      return result;
    });
  }
}
