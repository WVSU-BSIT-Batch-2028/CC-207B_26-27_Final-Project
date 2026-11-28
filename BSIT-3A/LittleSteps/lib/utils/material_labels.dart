const Set<String> _emptyMaterialTokens = <String>{
  'none',
  'none required',
  'none needed',
  'no materials',
  'no materials needed',
  'n/a',
};

/// Filters placeholder entries such as `'none'` from [materials].
List<String> normalizeActivityMaterials(List<String> materials) {
  return materials
      .map((item) => item.trim())
      .where(
        (item) =>
            item.isNotEmpty &&
            !_emptyMaterialTokens.contains(item.toLowerCase()),
      )
      .toList();
}

/// Returns caregiver-ready labels for [materials], defaulting when empty.
List<String> displayActivityMaterials(List<String> materials) {
  final normalized = normalizeActivityMaterials(materials);
  return normalized.isNotEmpty ? normalized : const ['No materials needed'];
}
