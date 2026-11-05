import 'package:path/path.dart' as p;

class ExplorerTab {
  final String id;
  String currentPath; // '' represents 'This PC' (Home)
  final List<String> history;
  int historyIndex;

  ExplorerTab({
    required this.id,
    this.currentPath = '',
    List<String>? history,
    this.historyIndex = 0,
  }) : history = history ?? (currentPath.isEmpty ? [''] : ['', currentPath]);

  String get title {
    if (currentPath.isEmpty) return 'Home';
    final name = p.basename(currentPath);
    return name.isEmpty ? 'Root' : name;
  }

  bool get canGoBack => historyIndex > 0;
  bool get canGoForward => historyIndex < history.length - 1;

  void navigateTo(String path) {
    if (currentPath == path) return;
    // Discard any forward history when navigating to a new path
    if (historyIndex < history.length - 1) {
      history.removeRange(historyIndex + 1, history.length);
    }
    history.add(path);
    historyIndex = history.length - 1;
    currentPath = path;
  }

  bool goBack() {
    if (canGoBack) {
      historyIndex--;
      currentPath = history[historyIndex];
      return true;
    }
    return false;
  }

  bool goForward() {
    if (canGoForward) {
      historyIndex++;
      currentPath = history[historyIndex];
      return true;
    }
    return false;
  }

  bool goUp() {
    if (currentPath.isEmpty) return false;
    final parent = p.dirname(currentPath);
    // If we're at storage root (e.g. /storage/emulated/0), going up takes us to Home ('')
    if (parent == currentPath || currentPath == '/storage/emulated/0' || currentPath == '/') {
      navigateTo('');
      return true;
    }
    navigateTo(parent);
    return true;
  }
}
