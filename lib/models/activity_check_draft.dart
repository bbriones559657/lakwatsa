class ActivityCheckDraft {
  final DateTime startedAt;
  final Map<String, String> foundMethods;

  ActivityCheckDraft({
    required this.startedAt,
    required Map<String, String> foundMethods,
  }) : foundMethods = Map.unmodifiable(foundMethods);
}
