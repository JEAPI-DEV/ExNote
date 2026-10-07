/// IDs are filenames in the legacy storage layout; reject path components.
String safeStorageId(String id) {
  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
    throw const FormatException('Invalid stored note ID');
  }
  return id;
}
