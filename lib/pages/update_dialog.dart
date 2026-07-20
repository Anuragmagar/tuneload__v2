import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:tuneload/services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static Future<void> show(BuildContext context, UpdateInfo info) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(updateInfo: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double? _progress;
  bool _downloading = false;
  bool _error = false;

  Future<void> _downloadAndInstall() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = false;
    });

    try {
      final file = await UpdateService.downloadUpdate(
        widget.updateInfo.downloadUrl,
        (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (file == null) {
        if (mounted) setState(() => _error = true);
        return;
      }

      if (mounted) {
        setState(() => _progress = 1.0);
      }

      await UpdateService.installApk(file.path);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;

    return Dialog(
      backgroundColor: const Color(0xFF1E1F26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF832F47).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      PhosphorIconsBold.arrowDown,
                      color: Color(0xFFE06280),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Update Available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'v${info.currentVersion} → v${info.latestVersion}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Changelog',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    info.changelog,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_downloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFE06280)),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _progress != null && _progress! >= 1.0
                        ? 'Installing...'
                        : 'Downloading... ${(_progress! * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ] else ...[
                if (_error)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Download failed. Please try again.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Later',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _downloadAndInstall,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE06280),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Update',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
