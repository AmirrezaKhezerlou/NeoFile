class ClipboardItem {
  final List<String> paths;
  final bool isCut; // true = Cut (move), false = Copy

  const ClipboardItem({
    required this.paths,
    required this.isCut,
  });

  bool get isEmpty => paths.isEmpty;
  bool get isNotEmpty => paths.isNotEmpty;
  int get count => paths.length;
}
