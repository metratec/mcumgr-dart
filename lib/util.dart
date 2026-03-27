import 'package:cbor/cbor.dart';
import 'package:mcumgr/msg.dart';

// ── Generic MCUMgr return codes (SMP v1 "rc" field) ──

/// Generic mcumgr error codes from mgmt.h.
class McuMgrReturnCode {
  static const ok = 0;
  static const unknown = 1;
  static const noMemory = 2;
  static const invalidValue = 3;
  static const timeout = 4;
  static const noEntry = 5;
  static const badState = 6;
  static const msgSize = 7;
  static const notSupported = 8;
  static const corrupt = 9;
  static const busy = 10;
  static const accessDenied = 11;
  static const unsupportedTooOld = 12;
  static const unsupportedTooNew = 13;

  static String name(int rc) => switch (rc) {
        ok => 'OK',
        unknown => 'UNKNOWN',
        noMemory => 'NO_MEMORY',
        invalidValue => 'INVALID_VALUE',
        timeout => 'TIMEOUT',
        noEntry => 'NO_ENTRY',
        badState => 'BAD_STATE',
        msgSize => 'MSG_SIZE',
        notSupported => 'NOT_SUPPORTED',
        corrupt => 'CORRUPT',
        busy => 'BUSY',
        accessDenied => 'ACCESS_DENIED',
        unsupportedTooOld => 'UNSUPPORTED_TOO_OLD',
        unsupportedTooNew => 'UNSUPPORTED_TOO_NEW',
        _ => 'RC_$rc',
      };
}

// ── SMP v2 group-specific return codes ("err" -> {"rc", "group"}) ──

/// Group-specific error codes for OS management (group 0).
class OsMgmtReturnCode {
  static const invalidFormat = 2;
  static const queryYieldsNoAnswer = 3;

  static String name(int rc) => switch (rc) {
        invalidFormat => 'INVALID_FORMAT',
        queryYieldsNoAnswer => 'QUERY_YIELDS_NO_ANSWER',
        _ => 'OS_RC_$rc',
      };
}

/// Group-specific error codes for Image management (group 1).
class ImgMgmtReturnCode {
  static const flashConfigQueryFail = 2;
  static const noImage = 3;
  static const noTlvs = 4;
  static const invalidTlv = 5;
  static const tlvMultipleHashesFound = 6;
  static const tlvInvalidSize = 7;
  static const hashNotFound = 8;
  static const noFreeSlot = 9;
  static const flashOpenFailed = 10;
  static const flashReadFailed = 11;
  static const flashWriteFailed = 12;
  static const flashEraseFailed = 13;
  static const invalidSlot = 14;
  static const noFreeMemory = 15;
  static const flashContextAlreadySet = 16;
  static const flashContextNotSet = 17;
  static const flashAreaDeviceNull = 18;
  static const invalidPageOffset = 19;
  static const invalidOffset = 20;
  static const invalidLength = 21;
  static const invalidImageHeader = 22;
  static const invalidImageHeaderMagic = 23;
  static const invalidHash = 24;
  static const invalidFlashAddress = 25;
  static const versionGetFailed = 26;
  static const currentVersionIsNewer = 27;
  static const imageAlreadyPending = 28;
  static const invalidImageVectorTable = 29;
  static const invalidImageTooLarge = 30;
  static const invalidImageDataOverrun = 31;
  static const imageConfirmationDenied = 32;
  static const imageSettingTestToActiveDenied = 33;

  static String name(int rc) => switch (rc) {
        flashConfigQueryFail => 'FLASH_CONFIG_QUERY_FAIL',
        noImage => 'NO_IMAGE',
        noTlvs => 'NO_TLVS',
        invalidTlv => 'INVALID_TLV',
        tlvMultipleHashesFound => 'TLV_MULTIPLE_HASHES_FOUND',
        tlvInvalidSize => 'TLV_INVALID_SIZE',
        hashNotFound => 'HASH_NOT_FOUND',
        noFreeSlot => 'NO_FREE_SLOT',
        flashOpenFailed => 'FLASH_OPEN_FAILED',
        flashReadFailed => 'FLASH_READ_FAILED',
        flashWriteFailed => 'FLASH_WRITE_FAILED',
        flashEraseFailed => 'FLASH_ERASE_FAILED',
        invalidSlot => 'INVALID_SLOT',
        noFreeMemory => 'NO_FREE_MEMORY',
        flashContextAlreadySet => 'FLASH_CONTEXT_ALREADY_SET',
        flashContextNotSet => 'FLASH_CONTEXT_NOT_SET',
        flashAreaDeviceNull => 'FLASH_AREA_DEVICE_NULL',
        invalidPageOffset => 'INVALID_PAGE_OFFSET',
        invalidOffset => 'INVALID_OFFSET',
        invalidLength => 'INVALID_LENGTH',
        invalidImageHeader => 'INVALID_IMAGE_HEADER',
        invalidImageHeaderMagic => 'INVALID_IMAGE_HEADER_MAGIC',
        invalidHash => 'INVALID_HASH',
        invalidFlashAddress => 'INVALID_FLASH_ADDRESS',
        versionGetFailed => 'VERSION_GET_FAILED',
        currentVersionIsNewer => 'CURRENT_VERSION_IS_NEWER',
        imageAlreadyPending => 'IMAGE_ALREADY_PENDING',
        invalidImageVectorTable => 'INVALID_IMAGE_VECTOR_TABLE',
        invalidImageTooLarge => 'INVALID_IMAGE_TOO_LARGE',
        invalidImageDataOverrun => 'INVALID_IMAGE_DATA_OVERRUN',
        imageConfirmationDenied => 'IMAGE_CONFIRMATION_DENIED',
        imageSettingTestToActiveDenied => 'IMAGE_SETTING_TEST_TO_ACTIVE_DENIED',
        _ => 'IMG_RC_$rc',
      };
}

/// Group-specific error codes for Statistics management (group 2).
class StatMgmtReturnCode {
  static const invalidGroup = 2;
  static const invalidStatName = 3;
  static const invalidStatSize = 4;
  static const walkAborted = 5;

  static String name(int rc) => switch (rc) {
        invalidGroup => 'INVALID_GROUP',
        invalidStatName => 'INVALID_STAT_NAME',
        invalidStatSize => 'INVALID_STAT_SIZE',
        walkAborted => 'WALK_ABORTED',
        _ => 'STAT_RC_$rc',
      };
}

/// Group-specific error codes for Settings management (group 3).
class SettingsMgmtReturnCode {
  static const keyTooLong = 2;
  static const keyNotFound = 3;
  static const readNotSupported = 4;
  static const rootKeyNotFound = 5;
  static const writeNotSupported = 6;
  static const deleteNotSupported = 7;

  static String name(int rc) => switch (rc) {
        keyTooLong => 'KEY_TOO_LONG',
        keyNotFound => 'KEY_NOT_FOUND',
        readNotSupported => 'READ_NOT_SUPPORTED',
        rootKeyNotFound => 'ROOT_KEY_NOT_FOUND',
        writeNotSupported => 'WRITE_NOT_SUPPORTED',
        deleteNotSupported => 'DELETE_NOT_SUPPORTED',
        _ => 'SETTINGS_RC_$rc',
      };
}

/// Group-specific error codes for File System management (group 8).
class FsMgmtReturnCode {
  static const fileInvalidName = 2;
  static const fileNotFound = 3;
  static const fileIsDirectory = 4;
  static const fileOpenFailed = 5;
  static const fileSeekFailed = 6;
  static const fileReadFailed = 7;
  static const fileTruncateFailed = 8;
  static const fileDeleteFailed = 9;
  static const fileWriteFailed = 10;
  static const fileOffsetNotValid = 11;
  static const fileOffsetLargerThanFile = 12;
  static const checksumHashNotFound = 13;
  static const mountPointNotFound = 14;
  static const readOnlyFilesystem = 15;
  static const fileEmpty = 16;

  static String name(int rc) => switch (rc) {
        fileInvalidName => 'FILE_INVALID_NAME',
        fileNotFound => 'FILE_NOT_FOUND',
        fileIsDirectory => 'FILE_IS_DIRECTORY',
        fileOpenFailed => 'FILE_OPEN_FAILED',
        fileSeekFailed => 'FILE_SEEK_FAILED',
        fileReadFailed => 'FILE_READ_FAILED',
        fileTruncateFailed => 'FILE_TRUNCATE_FAILED',
        fileDeleteFailed => 'FILE_DELETE_FAILED',
        fileWriteFailed => 'FILE_WRITE_FAILED',
        fileOffsetNotValid => 'FILE_OFFSET_NOT_VALID',
        fileOffsetLargerThanFile => 'FILE_OFFSET_LARGER_THAN_FILE',
        checksumHashNotFound => 'CHECKSUM_HASH_NOT_FOUND',
        mountPointNotFound => 'MOUNT_POINT_NOT_FOUND',
        readOnlyFilesystem => 'READ_ONLY_FILESYSTEM',
        fileEmpty => 'FILE_EMPTY',
        _ => 'FS_RC_$rc',
      };
}

/// Group-specific error codes for Shell management (group 9).
class ShellMgmtReturnCode {
  static const commandTooLong = 2;
  static const emptyCommand = 3;

  static String name(int rc) => switch (rc) {
        commandTooLong => 'COMMAND_TOO_LONG',
        emptyCommand => 'EMPTY_COMMAND',
        _ => 'SHELL_RC_$rc',
      };
}

/// Group-specific error codes for Enumeration management (group 10).
class EnumMgmtReturnCode {
  static const tooManyGroupEntries = 2;
  static const insufficientHeap = 3;

  static String name(int rc) => switch (rc) {
        tooManyGroupEntries => 'TOO_MANY_GROUP_ENTRIES',
        insufficientHeap => 'INSUFFICIENT_HEAP',
        _ => 'ENUM_RC_$rc',
      };
}

/// Group-specific error codes for Zephyr management (group 63).
class ZephyrMgmtReturnCode {
  static const flashOpenFailed = 2;
  static const flashConfigQueryFail = 3;
  static const flashEraseFailed = 4;

  static String name(int rc) => switch (rc) {
        flashOpenFailed => 'FLASH_OPEN_FAILED',
        flashConfigQueryFail => 'FLASH_CONFIG_QUERY_FAIL',
        flashEraseFailed => 'FLASH_ERASE_FAILED',
        _ => 'ZEPHYR_RC_$rc',
      };
}

// ── Group ID to name lookup ──

final _groupNameLookup = <int, String Function(int)>{
  0: OsMgmtReturnCode.name,
  1: ImgMgmtReturnCode.name,
  2: StatMgmtReturnCode.name,
  3: SettingsMgmtReturnCode.name,
  8: FsMgmtReturnCode.name,
  9: ShellMgmtReturnCode.name,
  10: EnumMgmtReturnCode.name,
  63: ZephyrMgmtReturnCode.name,
};

// ── Exception classes ──

/// Thrown on a generic SMP v1 error (top-level "rc" field != 0).
class McuException implements Exception {
  final int rc;

  McuException(this.rc);

  @override
  String toString() => 'mcumgr error: ${McuMgrReturnCode.name(rc)} ($rc)';
}

/// Thrown on a group-specific SMP v2 error ("err" -> {"rc", "group"}).
class McuGroupException implements Exception {
  final int group;
  final int rc;

  McuGroupException(this.group, this.rc);

  String get groupRcName {
    final lookup = _groupNameLookup[group];
    return lookup != null ? lookup(rc) : 'GROUP_${group}_RC_$rc';
  }

  @override
  String toString() => 'mcumgr group $group error: $groupRcName ($rc)';
}

// ── Response unwrap ──

extension FutureMessageExtension on Future<Message> {
  /// Checks the response for errors and throws on failure.
  ///
  /// Handles both SMP v1 (top-level "rc") and SMP v2 ("err" map with
  /// "rc" and "group" fields).
  Future<Message> unwrap() {
    return then(
      (value) {
        // SMP v2: check for "err" map with group-specific error
        final errValue = value.data[CborString('err')];
        if (errValue is CborMap) {
          final errRc = (errValue[CborString('rc')] as CborInt?)?.toInt();
          final errGroup =
              (errValue[CborString('group')] as CborInt?)?.toInt();
          if (errRc != null && errRc != 0 && errGroup != null) {
            throw McuGroupException(errGroup, errRc);
          }
        }

        // SMP v1: check top-level "rc"
        final rcValue = value.data[CborString('rc')];
        if (rcValue is CborInt) {
          final rc = rcValue.toInt();
          if (rc != 0) {
            throw McuException(rc);
          }
        }

        return value;
      },
    );
  }
}
