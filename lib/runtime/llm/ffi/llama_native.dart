import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef NativeVersionFn = Pointer<Utf8> Function();
typedef DartVersionFn = Pointer<Utf8> Function();

class LlamaNative {
  static final DynamicLibrary _lib =
  Platform.isAndroid
      ? DynamicLibrary.open(
    "libsutra_native.so",
  )
      : DynamicLibrary.process();

  static final DartVersionFn _version =
  _lib.lookupFunction<
      NativeVersionFn,
      DartVersionFn>(
    "sutra_version",
  );

  static String version() {
    return _version()
        .toDartString();
  }
}