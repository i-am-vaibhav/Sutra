import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device/device_provider.dart';
import '../models/model_selector.dart';
import '../models/model_definition.dart';

class RuntimeRouter {

  final Ref ref;

  RuntimeRouter(this.ref);

  Future<ModelDefinition> resolveModel() async {
    final tier = await ref.read(deviceTierProvider.future);
    return ModelSelector.select(tier);
  }
}