/// Serializes draft writes, so an older selection cannot overwrite a newer one.
class CheckDraftWriter {
  final Future<void> Function(Map<String, String> snapshot) write;
  final void Function(Object error)? onError;
  final void Function()? onSaved;

  Future<void> _pending = Future<void>.value();
  int _revision = 0;

  CheckDraftWriter({
    required this.write,
    this.onError,
    this.onSaved,
  });

  void save(Map<String, String> selections) {
    final snapshot = Map<String, String>.from(selections);
    final revision = ++_revision;

    _pending = _pending
        .then((_) => write(snapshot))
        .then((_) {
          if (revision == _revision) onSaved?.call();
        })
        .catchError((Object error) {
          if (revision == _revision) onError?.call(error);
        });
  }

  /// Call before completing a check, so an outstanding draft write cannot
  /// recreate a draft after the completed check deletes it.
  Future<void> flush() => _pending;
}
