import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:neofile/services/archive_service.dart';

void main() {
  test('ArchiveService compression and extraction with cancellation and progress', () async {
    final tempDir = Directory.systemTemp.createTempSync('archive_unit_test');
    final file1 = File('${tempDir.path}/a.txt');
    file1.writeAsStringSync('NeoFile test data 1');
    final file2 = File('${tempDir.path}/b.txt');
    file2.writeAsStringSync('NeoFile test data 2');

    final zipPath = '${tempDir.path}/bundle.zip';
    double lastProgress = 0.0;

    final success = await ArchiveService.compressToZip(
      sourcePaths: [file1.path, file2.path],
      outputZipPath: zipPath,
      onProgress: (p, item) {
        lastProgress = p;
      },
    );

    expect(success, true);
    expect(File(zipPath).existsSync(), true);
    expect(lastProgress, 1.0);

    final extractDir = '${tempDir.path}/out';
    final extractSuccess = await ArchiveService.extractArchive(
      archivePath: zipPath,
      destinationDir: extractDir,
    );

    expect(extractSuccess, true);
    expect(File('$extractDir/a.txt').existsSync(), true);
    expect(File('$extractDir/b.txt').existsSync(), true);

    tempDir.deleteSync(recursive: true);
  });
}
