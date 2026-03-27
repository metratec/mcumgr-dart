import 'package:cbor/cbor.dart';
import 'package:mcumgr/client.dart';
import 'package:mcumgr/msg.dart';
import 'package:mcumgr/util.dart';

const _shellGroup = 9;
const _shellCmdExecute = 0;

class ShellResult {
  final int returnCode;
  final String output;

  ShellResult(CborMap input)
      : returnCode = (input[CborString('ret')] as CborInt).toInt(),
        output = (input[CborString('o')] as CborString).toString();

  @override
  String toString() => 'ShellResult{rc=$returnCode, output=$output}';
}

extension ClientShellExtension on Client {
  /// Executes a shell command on the device.
  ///
  /// [argv] is the command and its arguments, e.g. `['ls', '/lfs']`.
  Future<ShellResult> shellExecute(List<String> argv, Duration timeout) {
    return execute(
      Message(
        op: Operation.write,
        group: _shellGroup,
        id: _shellCmdExecute,
        flags: 0,
        data: CborMap({
          CborString('argv'):
              CborList(argv.map((s) => CborString(s)).toList()),
        }),
      ),
      timeout,
    ).unwrap().then((msg) => ShellResult(msg.data));
  }
}
