import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mcumgr/packet.dart';
import 'package:mcumgr/src/crc16.dart';
import 'package:mcumgr/src/encoding.dart';

/// SMP serial line encoding for mcumgr.
///
/// Wraps SMP packets in the serial framing protocol:
/// - Frame start:  0x06 0x09 + base64 data + \n
/// - Continuation: 0x04 0x14 + base64 data + \n
/// - Max 128 base64 chars per line
/// - Length field includes CRC (smpLen + 2)
/// - CRC16 covers SMP data only (not length field)
///
/// Use [smpSerial] as the encoding parameter when creating a [Client]
/// over a serial transport.
const smpSerial = SmpSerial();

class SmpSerial implements Encoding {
  const SmpSerial();

  static const int _frameStart1 = 0x06;
  static const int _frameStart2 = 0x09;
  static const int _frameCont1 = 0x04;
  static const int _frameCont2 = 0x14;
  static const int _maxBase64PerLine = 124; // matches AuTerm (93 raw bytes)

  @override
  List<int> encode(Packet msg) {
    final smpData = msg.header.encode() + msg.content;
    final len = smpData.length + 2; // includes CRC
    final crc = crc16(smpData);
    final payload = <int>[
      (len >> 8) & 0xFF,
      len & 0xFF,
      ...smpData,
      (crc >> 8) & 0xFF,
      crc & 0xFF,
    ];

    final b64 = base64.encode(Uint8List.fromList(payload));

    final result = <int>[];
    for (int i = 0; i < b64.length; i += _maxBase64PerLine) {
      final end = (i + _maxBase64PerLine > b64.length)
          ? b64.length
          : i + _maxBase64PerLine;
      final chunk = b64.substring(i, end);

      if (i == 0) {
        result.addAll([_frameStart1, _frameStart2]);
      } else {
        result.addAll([_frameCont1, _frameCont2]);
      }
      result.addAll(utf8.encode(chunk));
      result.add(0x0A);
    }
    return result;
  }

  @override
  Stream<Packet> decode(Stream<List<int>> input) {
    final controller = StreamController<Packet>.broadcast();
    controller.onListen = () {
      final lineBuffer = <int>[];
      bool inFrame = false;
      final base64Buffer = StringBuffer();

      void tryDecodeFrame() {
        final b64Str = base64Buffer.toString();
        if (b64Str.length % 4 != 0) return;

        List<int> decoded;
        try {
          decoded = base64.decode(b64Str);
        } catch (_) {
          return;
        }

        if (decoded.length < 4) return;

        final len = (decoded[0] << 8) | decoded[1];
        final totalLen = 2 + len;
        if (decoded.length < totalLen) return;

        final smpDataLen = len - 2;
        if (smpDataLen < 0) {
          inFrame = false;
          return;
        }

        final smpData = decoded.sublist(2, 2 + smpDataLen);
        final expectedCrc =
            (decoded[2 + smpDataLen] << 8) | decoded[2 + smpDataLen + 1];
        final actualCrc = crc16(smpData);

        if (actualCrc != expectedCrc) {
          inFrame = false;
          return;
        }

        inFrame = false;

        if (smpDataLen < Header.encodedLength) return;
        final header = Header.decode(smpData);
        final content = smpData.sublist(Header.encodedLength);
        controller.add(Packet(header: header, content: content));
      }

      void processLine(List<int> line) {
        if (line.length < 2) return;

        if (line[0] == _frameStart1 && line[1] == _frameStart2) {
          inFrame = true;
          base64Buffer.clear();
          base64Buffer.write(String.fromCharCodes(line.sublist(2)));
          tryDecodeFrame();
        } else if (line[0] == _frameCont1 && line[1] == _frameCont2) {
          if (inFrame) {
            base64Buffer.write(String.fromCharCodes(line.sublist(2)));
            tryDecodeFrame();
          }
        }
      }

      final subscription = input.listen(
        (data) {
          for (final byte in data) {
            if (byte == 0x0A) {
              while (lineBuffer.isNotEmpty && lineBuffer.last == 0x0D) {
                lineBuffer.removeLast();
              }
              processLine(List.of(lineBuffer));
              lineBuffer.clear();
            } else {
              lineBuffer.add(byte);
            }
          }
        },
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    };
    return controller.stream;
  }
}
