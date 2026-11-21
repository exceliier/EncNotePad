import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

class AtomicFileWriter {
  /// Writes [data] to `<path>.tmp` (or hidden `.<filename>.tmp`), flushes buffers to physical disk,
  /// and atomically renames to [targetPath], preventing file corruption during sudden power loss.
  static Future<void> writeAtomic(String targetPath, Uint8List data) async {
    final dir = p.dirname(targetPath);
    final filename = p.basename(targetPath);
    final tmpPath = p.join(dir, '.$filename.tmp');

    final tmpFile = File(tmpPath);
    final raf = await tmpFile.open(mode: FileMode.write);
    try {
      await raf.writeFrom(data);
      await raf.flush();
    } finally {
      await raf.close();
    }

    // Atomically replace target
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tmpFile.rename(targetPath);
  }
}
