import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String changelog;
  final String downloadUrl;
  final String apkName;

  const UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.changelog,
    required this.downloadUrl,
    required this.apkName,
  });

  bool get hasUpdate => _compareVersions(latestVersion, currentVersion) > 0;

  static int _compareVersions(String a, String b) {
    final aParts = a.split('.').map(int.parse).toList();
    final bParts = b.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      final aVal = i < aParts.length ? aParts[i] : 0;
      final bVal = i < bParts.length ? bParts[i] : 0;
      if (aVal != bVal) return aVal.compareTo(bVal);
    }
    return 0;
  }
}

class UpdateService {
  static const _owner = 'Anuragmagar';
  static const _repo = 'tuneload__v2';
  static const _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github+json'},
      );

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = json['tag_name'] ?? '';
      final latestVersion = tagName.replaceFirst('v', '');

      String downloadUrl = '';
      String apkName = '';
      final assets = json['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = asset['name'] ?? '';
        if (name.toString().endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] ?? '';
          apkName = name;
          break;
        }
      }

      if (downloadUrl.isEmpty) return null;

      return UpdateInfo(
        latestVersion: latestVersion,
        currentVersion: currentVersion,
        changelog: json['body'] ?? 'No changelog provided.',
        downloadUrl: downloadUrl,
        apkName: apkName,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<File?> downloadUpdate(
    String downloadUrl,
    void Function(double progress)? onProgress,
  ) async {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/tuneload_update.apk';
    final file = File(filePath);

    final request = http.Request('GET', Uri.parse(downloadUrl));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) return null;

    final totalBytes = response.contentLength ?? 0;
    int receivedBytes = 0;
    final sink = file.openWrite();

    await for (final chunk in response.stream) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0) {
        onProgress?.call(receivedBytes / totalBytes);
      }
    }
    await sink.flush();
    await sink.close();

    return file;
  }

  static Future<void> installApk(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      throw Exception('Could not open APK: ${result.message}');
    }
  }
}
