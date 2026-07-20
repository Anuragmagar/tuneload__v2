import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:tuneload/pages/update_dialog.dart';
import 'package:tuneload/services/update_service.dart';

class Aboutpage extends StatefulWidget {
  const Aboutpage({super.key});

  @override
  State<Aboutpage> createState() => _AboutpageState();
}

class _AboutpageState extends State<Aboutpage> {
  String _version = '...';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  Future<void> _checkForUpdate() async {
    setState(() => _checkingUpdate = true);
    final update = await UpdateService.checkForUpdate();
    setState(() => _checkingUpdate = false);

    if (!mounted) return;

    if (update != null && update.hasUpdate) {
      UpdateDialog.show(context, update);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are on the latest version!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              "Settings",
              style: TextStyle(
                color: Color.fromARGB(255, 226, 226, 226),
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            "Download Path",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: const Text(
            "/storage/emulated/0/Download/TuneLoad",
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(color: Colors.white60),
          ),
          leading: const Icon(
            PhosphorIconsBold.downloadSimple,
            color: Colors.white,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            "Version",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            _version,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(color: Colors.white60),
          ),
          leading: const Icon(
            PhosphorIconsBold.gitBranch,
            color: Colors.white,
          ),
          trailing: IconButton(
            onPressed: _checkingUpdate ? null : _checkForUpdate,
            icon: _checkingUpdate
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  )
                : const Icon(
                    PhosphorIconsBold.arrowClockwise,
                    color: Colors.white54,
                    size: 20,
                  ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            "Share App",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: const Text(
            "Let your friends know about us",
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(color: Colors.white60),
          ),
          leading: const Icon(
            PhosphorIconsBold.shareFat,
            color: Colors.white,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            "Feedback",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: const Text(
            "Help us sharing the error and improvements to make",
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(color: Colors.white60),
          ),
          leading: const Icon(
            PhosphorIconsBold.warningCircle,
            color: Colors.white,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            "About Developer",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: const Text(
            "For detail, visit anuragmagar.com.np",
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(color: Colors.white60),
          ),
          leading: const Icon(
            PhosphorIconsBold.userFocus,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
