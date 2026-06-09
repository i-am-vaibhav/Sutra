enum ModelTier { fast, balanced, heavy }

class ModelStrategy {
  static ModelTier select(int ramGB) {
    if (ramGB <= 4) return ModelTier.fast;
    if (ramGB <= 8) return ModelTier.balanced;
    return ModelTier.heavy;
  }
}