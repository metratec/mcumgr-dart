import 'package:mcumgr/packet.dart';

/// Transport encoding for SMP packets.
///
/// Implementations: [Smp] (BLE), [SmpSerial] (serial/UART).
abstract class Encoding {
  /// Encodes a single packet into bytes for transmission.
  List<int> encode(Packet msg);

  /// Decodes a stream of received byte arrays into a stream of packets.
  Stream<Packet> decode(Stream<List<int>> input);
}
