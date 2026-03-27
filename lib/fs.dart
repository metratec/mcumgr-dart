import 'dart:async';
import 'dart:math';

import 'package:cbor/cbor.dart';
import 'package:mcumgr/client.dart';
import 'package:mcumgr/msg.dart';
import 'package:mcumgr/util.dart';

const _fsGroup = 8;
const _fsCmdUploadDownload = 0;
const _fsCmdStatus = 1;
const _fsCmdHashChecksum = 2;
const _fsCmdSupportedHashes = 3;
const _fsCmdFileClose = 4;

class FileStatus {
  final int length;

  FileStatus(CborMap input)
      : length = (input[CborString('len')] as CborInt).toInt();

  @override
  String toString() => 'FileStatus{length=$length}';
}

class HashChecksumResult {
  final String type;
  final List<int> output;
  final int length;

  HashChecksumResult(CborMap input)
      : type = (input[CborString('type')] as CborString).toString(),
        output = (input[CborString('output')] as CborBytes).bytes,
        length = (input[CborString('len')] as CborInt).toInt();

  @override
  String toString() => 'HashChecksum{type=$type, len=$length}';
}

class HashType {
  final String name;
  final int format;
  final int size;

  HashType(CborMap input)
      : name = input.keys
            .whereType<CborString>()
            .firstWhere((k) => k.toString() != 'format' && k.toString() != 'size')
            .toString(),
        format = (input[CborString('format')] as CborInt).toInt(),
        size = (input[CborString('size')] as CborInt).toInt();

  @override
  String toString() => 'HashType{$name, format=$format, size=$size}';
}

extension ClientFsExtension on Client {
  /// Calculates optimal FS upload chunk size from client's maxPacketSize.
  int _fsAutoChunkSize(String name, List<int> data, int offset) {
    final mps = maxPacketSize;
    if (mps == null) return 64; // fallback

    const headerSize = 8;
    const mapSize = 2;
    final nameSize = cbor.encode(CborString('name')).length +
        cbor.encode(CborString(name)).length;
    final offSize = cbor.encode(CborString('off')).length +
        cbor.encode(CborSmallInt(offset)).length;
    final lenSize = offset == 0
        ? cbor.encode(CborString('len')).length +
            cbor.encode(CborSmallInt(data.length)).length
        : 0;
    final dataKeySize = cbor.encode(CborString('data')).length;

    final overhead = headerSize + mapSize + nameSize + offSize + lenSize + dataKeySize;
    final maxDataLen = mps - overhead;
    final dataLenHeaderSize = cbor.encode(CborSmallInt(maxDataLen)).length;
    return min(max(mps - overhead - dataLenHeaderSize, 1), data.length - offset);
  }

  /// Uploads a file to the device.
  ///
  /// [name] is the remote file path (e.g. `/lfs/myfile.txt`).
  /// [data] is the file contents.
  /// If [chunkSize] is null, the optimal size is calculated from
  /// [Client.maxPacketSize].
  Future<void> fsUpload(
    String name,
    List<int> data,
    Duration chunkTimeout, {
    int? chunkSize,
    void Function(int)? onProgress,
  }) async {
    int offset = 0;
    while (offset < data.length) {
      final cs = chunkSize ?? _fsAutoChunkSize(name, data, offset);
      final end = (offset + cs > data.length) ? data.length : offset + cs;
      final chunk = data.sublist(offset, end);

      final reqData = <CborValue, CborValue>{
        CborString('name'): CborString(name),
        CborString('off'): CborSmallInt(offset),
        CborString('data'): CborBytes(chunk),
      };
      if (offset == 0) {
        reqData[CborString('len')] = CborSmallInt(data.length);
      }

      final msg = await execute(
        Message(
          op: Operation.write,
          group: _fsGroup,
          id: _fsCmdUploadDownload,
          flags: 0,
          data: CborMap(reqData),
        ),
        chunkTimeout,
      ).unwrap();

      offset = (msg.data[CborString('off')] as CborInt).toInt();
      onProgress?.call(offset);
    }
  }

  /// Downloads a file from the device.
  ///
  /// [name] is the remote file path.
  /// [onProgress] is called with the number of bytes downloaded so far.
  Future<List<int>> fsDownload(
    String name,
    Duration chunkTimeout, {
    void Function(int)? onProgress,
  }) async {
    final result = <int>[];
    int offset = 0;
    int? totalLen;

    while (true) {
      final msg = await execute(
        Message(
          op: Operation.read,
          group: _fsGroup,
          id: _fsCmdUploadDownload,
          flags: 0,
          data: CborMap({
            CborString('name'): CborString(name),
            CborString('off'): CborSmallInt(offset),
          }),
        ),
        chunkTimeout,
      ).unwrap();

      totalLen ??= (msg.data[CborString('len')] as CborInt?)?.toInt();
      final chunk = (msg.data[CborString('data')] as CborBytes).bytes;
      result.addAll(chunk);
      offset = result.length;
      onProgress?.call(offset);

      if (totalLen != null && offset >= totalLen) break;
      if (chunk.isEmpty) break;
    }
    return result;
  }

  /// Gets the size of a file on the device.
  Future<FileStatus> fsStatus(String name, Duration timeout) {
    return execute(
      Message(
        op: Operation.read,
        group: _fsGroup,
        id: _fsCmdStatus,
        flags: 0,
        data: CborMap({CborString('name'): CborString(name)}),
      ),
      timeout,
    ).unwrap().then((msg) => FileStatus(msg.data));
  }

  /// Computes a hash/checksum of a file on the device.
  Future<HashChecksumResult> fsHashChecksum(
      String name, String type, Duration timeout) {
    return execute(
      Message(
        op: Operation.read,
        group: _fsGroup,
        id: _fsCmdHashChecksum,
        flags: 0,
        data: CborMap({
          CborString('name'): CborString(name),
          CborString('type'): CborString(type),
        }),
      ),
      timeout,
    ).unwrap().then((msg) => HashChecksumResult(msg.data));
  }

  /// Lists supported hash/checksum algorithms.
  Future<List<HashType>> fsSupportedHashes(Duration timeout) {
    return execute(
      Message(
        op: Operation.read,
        group: _fsGroup,
        id: _fsCmdSupportedHashes,
        flags: 0,
        data: CborMap({}),
      ),
      timeout,
    ).unwrap().then((msg) {
      final types = msg.data[CborString('types')] as CborList;
      return types.map((v) => HashType(v as CborMap)).toList();
    });
  }

  /// Closes any open file handles on the device.
  Future<void> fsClose(Duration timeout) {
    return execute(
      Message(
        op: Operation.write,
        group: _fsGroup,
        id: _fsCmdFileClose,
        flags: 0,
        data: CborMap({}),
      ),
      timeout,
    ).unwrap();
  }
}
