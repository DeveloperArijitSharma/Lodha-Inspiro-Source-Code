import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  final int buildNumber;
  final String versionName;
  final String apkUrl;
  final String releaseUrl;

  const AppUpdateInfo({
    required this.buildNumber,
    required this.versionName,
    required this.apkUrl,
    required this.releaseUrl,
  });
}

class AppUpdateService {
  static const _nativeChannel = MethodChannel('lodha_inspiro/native');
  static const _releasesUrl =
      'https://api.github.com/repos/DeveloperArijitSharma/Lodha-Inspiro-Source-Code/releases/latest';

  Future<AppUpdateInfo?> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

    final response = await http.get(
      Uri.parse(_releasesUrl),
      headers: const {
        'Accept': 'application/vnd.github+json',
      },
    );

    if (response.statusCode != 200) return null;

    final release = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = release['tag_name'] as String? ?? '';
    final latestBuild = int.tryParse(tag.replaceFirst('build-', '')) ?? 0;
    if (latestBuild <= currentBuild) return null;

    final assets = (release['assets'] as List<dynamic>? ?? const []);
    Map<String, dynamic>? apk;
    for (final item in assets) {
      final asset = Map<String, dynamic>.from(item as Map);
      if (asset['name'] == 'lodha-inspiro.apk') {
        apk = asset;
        break;
      }
    }
    if (apk == null) return null;

    return AppUpdateInfo(
      buildNumber: latestBuild,
      versionName: release['name'] as String? ?? 'New version',
      apkUrl: apk['browser_download_url'] as String,
      releaseUrl: release['html_url'] as String? ?? '',
    );
  }

  Future<bool> downloadAndInstall(AppUpdateInfo update) async {
    final response = await http.get(Uri.parse(update.apkUrl));
    if (response.statusCode != 200) return false;

    final cacheDir = await getTemporaryDirectory();
    final apkFile = File('${cacheDir.path}/lodha-inspiro.apk');
    await apkFile.writeAsBytes(response.bodyBytes, flush: true);

    try {
      final installed = await _nativeChannel.invokeMethod<bool>('installApk', {
        'path': apkFile.path,
      });
      return installed ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> checkAndPrompt(BuildContext context) async {
    try {
      final update = await checkForUpdate();
      if (update == null || !context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('New Lodha Inspiro update'),
          content: Text(
            'Build ${update.buildNumber} is ready. The app can download the APK directly from the project release, so you do not need to download the source ZIP or rebuild it in FlutLab.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Downloading update...')),
                );
                final installed = await downloadAndInstall(update);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      installed
                          ? 'Opening Android installer...'
                          : 'Please allow Lodha Inspiro to install updates, then try again.',
                    ),
                  ),
                );
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Updates must never prevent the app from starting.
    }
  }
}
