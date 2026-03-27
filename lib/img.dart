import 'dart:async';

import 'package:cbor/cbor.dart';
import 'package:mcumgr/client.dart';
import 'package:mcumgr/msg.dart';
import 'package:mcumgr/util.dart';

const _imgGroup = 1;
const _imgCmdState = 0;
const _imgCmdUpload = 1;
const _imgCmdErase = 5;
const _imgCmdSlotInfo = 6;

/// The state of the images on a device.
class ImageState {
  final List<ImageStateImage> images;
  final int splitStatus;

  ImageState(CborMap input)
      : images = (input[CborString('images')] as CborList)
            .map((value) => ImageStateImage(value as CborMap))
            .toList(),
        splitStatus =
            (input[CborString('splitStatus')] as CborInt?)?.toInt() ?? 0;

  @override
  String toString() {
    return 'ImageState{images: $images, splitStatus: $splitStatus}';
  }
}

/// An image on a device.
class ImageStateImage {
  final int slot;
  final String version;
  final List<int> hash;
  final bool bootable;
  final bool pending;
  final bool confirmed;
  final bool active;
  final bool permanent;

  ImageStateImage(CborMap input)
      : slot = (input[CborString('slot')] as CborInt).toInt(),
        version = (input[CborString('version')] as CborString).toString(),
        hash = (input[CborString('hash')] as CborBytes).bytes,
        bootable = (input[CborString('bootable')] as CborBool).value,
        pending = (input[CborString('pending')] as CborBool).value,
        confirmed = (input[CborString('confirmed')] as CborBool).value,
        active = (input[CborString('active')] as CborBool).value,
        permanent = (input[CborString('permanent')] as CborBool).value;

  @override
  String toString() {
    return 'Image{slot: $slot, version: $version, bootable: $bootable, '
        'pending: $pending, confirmed: $confirmed, active: $active, '
        'permanent: $permanent}';
  }
}

class ImageUploadResponse {
  final int nextOffset;

  ImageUploadResponse(CborMap input)
      : nextOffset = (input[CborString('off')] as CborInt).toInt();
}

class _ImageUploadChunk {
  final int offset;
  final int size;
  final int end;

  _ImageUploadChunk(this.offset, this.size) : end = offset + size;
}

class _ImageUpload {
  final Client client;
  final int image;
  final List<int> data;
  final List<int> hash;
  final Duration chunkTimeout;
  final int maxChunkSize;
  final void Function(int)? onProgress;
  final int windowSize;
  final List<_ImageUploadChunk> pending = [];
  final completer = Completer<void>();

  _ImageUpload({
    required this.client,
    required this.image,
    required this.data,
    required this.hash,
    required this.chunkTimeout,
    required this.maxChunkSize,
    required this.onProgress,
    required this.windowSize,
  });

  int sendChunk(int offset) {
    int chunkSize = data.length - offset;
    if (chunkSize > maxChunkSize) {
      chunkSize = maxChunkSize;
    }
    if (chunkSize <= 0) {
      return 0;
    }
    List<int> chunkData = data.sublist(offset, offset + chunkSize);

    final chunk = _ImageUploadChunk(offset, chunkSize);
    pending.add(chunk);

    final Future<ImageUploadResponse> future;
    if (offset == 0) {
      future = client.startImageUpload(
        image, chunkData, data.length, hash, chunkTimeout);
    } else {
      future = client.continueImageUpload(offset, chunkData, chunkTimeout);
    }

    future.then(
      (response) => _onChunkDone(chunk, response),
      onError: (error, stackTrace) => _onChunkError(chunk, error, stackTrace),
    );
    return chunkSize;
  }

  void _sendNext(int offset) {
    while (pending.length < windowSize) {
      final chunkSize = sendChunk(offset);
      if (chunkSize == 0) break;
      offset += chunkSize;
    }
  }

  void _onChunkDone(_ImageUploadChunk chunk, ImageUploadResponse response) {
    final index = pending.indexOf(chunk);
    pending.removeRange(0, index + 1);
    if (index == -1) return;

    onProgress?.call(response.nextOffset);

    while (pending.isNotEmpty && pending.first.offset != response.nextOffset) {
      pending.removeAt(0);
    }

    int nextOffset = response.nextOffset;
    if (pending.isNotEmpty) {
      nextOffset = pending.last.end;
    }
    _sendNext(nextOffset);

    if (response.nextOffset == data.length) {
      assert(pending.isEmpty);
      completer.complete();
    }
  }

  void _onChunkError(
      _ImageUploadChunk chunk, Object error, StackTrace stackTrace) {
    if (!pending.remove(chunk)) return;
    pending.clear();
    completer.completeError(error, stackTrace);
  }

  void start() {
    _sendNext(0);
  }
}

extension ClientImgExtension on Client {
  /// Reads which images are currently present on the device.
  Future<ImageState> readImageState(Duration timeout) {
    return execute(
      Message(op: Operation.read, group: _imgGroup, id: _imgCmdState,
              flags: 0, data: CborMap({})),
      timeout,
    ).unwrap().then((value) => ImageState(value.data));
  }

  /// Marks the image with the specified hash as pending.
  Future<ImageState> setPendingImage(
      List<int> hash, bool confirm, Duration timeout) {
    return execute(
      Message(op: Operation.write, group: _imgGroup, id: _imgCmdState,
              flags: 0, data: CborMap({
                CborString('hash'): CborBytes(hash),
                CborString('confirm'): CborBool(confirm),
              })),
      timeout,
    ).unwrap().then((value) => ImageState(value.data));
  }

  /// Confirms the currently running image.
  Future<ImageState> confirmImageState(Duration timeout) {
    return setPendingImage([], true, timeout);
  }

  /// Sends the first chunk of a firmware upload.
  Future<ImageUploadResponse> startImageUpload(
      int image, List<int> data, int length, List<int> sha256,
      Duration timeout) {
    return execute(
      Message(op: Operation.write, group: _imgGroup, id: _imgCmdUpload,
              flags: 0, data: CborMap({
                CborString('image'): CborSmallInt(image),
                CborString('data'): CborBytes(data),
                CborString('len'): CborSmallInt(length),
                CborString('off'): CborSmallInt(0),
                CborString('sha'): CborBytes(sha256),
              })),
      timeout,
    ).unwrap().then((value) => ImageUploadResponse(value.data));
  }

  /// Sends a continuation chunk of a firmware upload.
  Future<ImageUploadResponse> continueImageUpload(
      int offset, List<int> data, Duration timeout) {
    return execute(
      Message(op: Operation.write, group: _imgGroup, id: _imgCmdUpload,
              flags: 0, data: CborMap({
                CborString('data'): CborBytes(data),
                CborString('off'): CborSmallInt(offset),
              })),
      timeout,
    ).unwrap().then((value) => ImageUploadResponse(value.data));
  }

  /// Uploads an image to the device.
  Future<void> uploadImage(
    int image, List<int> data, List<int> hash, Duration chunkTimeout, {
    int chunkSize = 128,
    void Function(int)? onProgress,
    int windowSize = 3,
  }) async {
    final upload = _ImageUpload(
      client: this, image: image, data: data, hash: hash,
      chunkTimeout: chunkTimeout, maxChunkSize: chunkSize,
      onProgress: onProgress, windowSize: windowSize,
    );
    upload.start();
    return upload.completer.future;
  }

  /// Erases the image in the inactive slot.
  Future<void> erase(Duration timeout) {
    return execute(
      Message(op: Operation.write, group: _imgGroup, id: _imgCmdErase,
              flags: 0, data: CborMap({})),
      timeout,
    ).unwrap();
  }

  /// Gets detailed slot information (sizes, upload IDs).
  Future<SlotInfo> slotInfo(Duration timeout) {
    return execute(
      Message(op: Operation.read, group: _imgGroup, id: _imgCmdSlotInfo,
              flags: 0, data: CborMap({})),
      timeout,
    ).unwrap().then((value) => SlotInfo(value.data));
  }
}

class SlotInfoEntry {
  final int slot;
  final int? uploadImageId;
  final int? size;

  SlotInfoEntry(CborMap input)
      : slot = (input[CborString('slot')] as CborInt).toInt(),
        uploadImageId =
            (input[CborString('upload_image_id')] as CborInt?)?.toInt(),
        size = (input[CborString('size')] as CborInt?)?.toInt();

  @override
  String toString() => 'SlotEntry{slot=$slot, size=$size}';
}

class SlotInfoImage {
  final int image;
  final int? maxImageSize;
  final List<SlotInfoEntry> slots;

  SlotInfoImage(CborMap input)
      : image = (input[CborString('image')] as CborInt).toInt(),
        maxImageSize =
            (input[CborString('max_image_size')] as CborInt?)?.toInt(),
        slots = (input[CborString('slots')] as CborList)
            .map((v) => SlotInfoEntry(v as CborMap))
            .toList();

  @override
  String toString() =>
      'SlotImage{image=$image, maxSize=$maxImageSize, slots=$slots}';
}

class SlotInfo {
  final List<SlotInfoImage> images;

  SlotInfo(CborMap input)
      : images = (input[CborString('images')] as CborList)
            .map((v) => SlotInfoImage(v as CborMap))
            .toList();

  @override
  String toString() => 'SlotInfo{images=$images}';
}

const _imageHeaderMagic = 0x96f3b83d;
const _imageTLVMagic = 0x6907;

int _decodeInt(List<int> input, int offset, int length) {
  var result = 0;
  for (var i = 0; i < length; i++) {
    result |= input[offset + i] << (8 * i);
  }
  return result;
}

class ImageVersion {
  final int major;
  final int minor;
  final int revision;
  final int build;

  ImageVersion(this.major, this.minor, this.revision, this.build);

  ImageVersion.decode(List<int> input)
      : this(_decodeInt(input, 0, 1), _decodeInt(input, 1, 1),
             _decodeInt(input, 2, 2), _decodeInt(input, 4, 4));

  @override
  String toString() {
    var result = '$major.$minor.$revision';
    if (build != 0) result += '.$build';
    return result;
  }
}

class McuImageHeader {
  final int loadAddress;
  final int headerSize;
  final int imageSize;
  final int flags;
  final ImageVersion version;

  McuImageHeader(this.loadAddress, this.headerSize, this.imageSize,
      this.flags, this.version);

  factory McuImageHeader.decode(List<int> input) {
    final magic = _decodeInt(input, 0, 4);
    if (magic != _imageHeaderMagic) {
      throw const FormatException('incorrect magic');
    }
    return McuImageHeader(
      _decodeInt(input, 4, 4), _decodeInt(input, 8, 2),
      _decodeInt(input, 12, 4), _decodeInt(input, 16, 4),
      ImageVersion.decode(input.sublist(20, 28)),
    );
  }

  @override
  String toString() =>
      'McuImageHeader{version: $version, imageSize: $imageSize}';
}

class McuImageTLV {
  final List<McuImageTLVEntry> entries;

  McuImageTLV(this.entries);

  factory McuImageTLV.decode(List<int> input, int offset) {
    final magic = _decodeInt(input, offset, 2);
    if (magic != _imageTLVMagic) {
      throw const FormatException('incorrect TLV magic');
    }
    final length = _decodeInt(input, offset + 2, 2);
    final end = offset + length;
    offset += 4;
    final entries = <McuImageTLVEntry>[];
    while (offset < end) {
      final entry = McuImageTLVEntry.decode(input, offset, end);
      entries.add(entry);
      offset += entry.length + 4;
    }
    return McuImageTLV(entries);
  }
}

class McuImageTLVEntry {
  final int type;
  final int length;
  final List<int> value;

  McuImageTLVEntry(this.type, this.length, this.value);

  factory McuImageTLVEntry.decode(List<int> input, int start, int end) {
    if (start + 4 > end) throw const FormatException("tlv header doesn't fit");
    final type = _decodeInt(input, start, 1);
    final length = _decodeInt(input, start + 2, 2);
    if (start + 4 + length > end) {
      throw const FormatException("tlv value doesn't fit");
    }
    return McuImageTLVEntry(
        type, length, input.sublist(start + 4, start + 4 + length));
  }
}

class McuImage {
  final McuImageHeader header;
  final McuImageTLV tlv;
  final List<int> hash;

  static List<int> _getHash(McuImageTLV tlv) {
    for (final entry in tlv.entries) {
      if (entry.type == 0x10) return entry.value;
    }
    throw const FormatException("image doesn't contain hash");
  }

  McuImage(this.header, this.tlv) : hash = _getHash(tlv);

  factory McuImage.decode(List<int> input) {
    final header = McuImageHeader.decode(input);
    final tlv = McuImageTLV.decode(input, header.headerSize + header.imageSize);
    return McuImage(header, tlv);
  }

  @override
  String toString() => 'McuImage{header: $header, hash: $hash}';
}
