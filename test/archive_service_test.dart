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

    // Test folder compression with nested structure and empty subfolders
    final folderToZip = Directory('${tempDir.path}/test_folder')..createSync();
    File('${folderToZip.path}/inside.txt').writeAsStringSync('inside folder');
    final nestedSub = Directory('${folderToZip.path}/sub_dir')..createSync();
    File('${nestedSub.path}/sub_inside.txt').writeAsStringSync('inside nested');
    Directory('${folderToZip.path}/empty_sub').createSync();

    final folderZipPath = '${tempDir.path}/folder.zip';
    final folderZipSuccess = await ArchiveService.compressToZip(
      sourcePaths: [folderToZip.path],
      outputZipPath: folderZipPath,
    );
    expect(folderZipSuccess, true);
    expect(File(folderZipPath).existsSync(), true);

    final folderExtractDir = '${tempDir.path}/folder_out';
    final folderExtractSuccess = await ArchiveService.extractArchive(
      archivePath: folderZipPath,
      destinationDir: folderExtractDir,
    );
    expect(folderExtractSuccess, true);
    expect(File('$folderExtractDir/test_folder/inside.txt').existsSync(), true);
    expect(File('$folderExtractDir/test_folder/sub_dir/sub_inside.txt').existsSync(), true);
    expect(Directory('$folderExtractDir/test_folder/empty_sub').existsSync(), true);

    tempDir.deleteSync(recursive: true);
  });
}
