/// Custom-scheme links include the first path component in the URI host.
/// Web paths pass through unchanged.
String appPath(Uri uri) {
  if (uri.scheme != 'holyhim') return uri.path.isEmpty ? '/' : uri.path;
  final host = uri.host;
  if (host.isEmpty || host == 'app') return uri.path.isEmpty ? '/' : uri.path;
  return '/$host${uri.path}';
}
