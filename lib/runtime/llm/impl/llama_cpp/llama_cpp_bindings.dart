import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef NativeLoadModel = Int32 Function(
    Pointer<Utf8>,
    );

typedef DartLoadModel = int Function(
    Pointer<Utf8>,
    );

class LlamaCppBindings {
  static final DynamicLibrary _lib =
  Platform.isAndroid
      ? DynamicLibrary.open(
    "libsutra_native.so",
  )
      : DynamicLibrary.process();

  static final DartLoadModel _loadModel =
  _lib.lookupFunction<
      NativeLoadModel,
      DartLoadModel
  >(
    "sutra_load_model",
  );

  static bool loadModel(String path) {
    final ptr = path.toNativeUtf8();

    final result = _loadModel(ptr);

    malloc.free(ptr);

    return result == 1;
  }
}