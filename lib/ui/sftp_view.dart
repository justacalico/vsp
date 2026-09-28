import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../protocols/ssh/ssh_session.dart';
import 'widgets.dart';

/// Minimal SFTP file browser attached to a live [SshSession]: navigate
/// directories, download to the app's documents folder, upload from
/// disk.
class SftpView extends StatefulWidget {
  const SftpView({super.key, required this.session});

  final SshSession session;

  @override
  State<SftpView> createState() => _SftpViewState();
}

class _SftpViewState extends State<SftpView> {
  SftpClient? _sftp;
  String _path = '.';
  List<SftpName> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      _sftp = await widget.session.sftp();
      await _cd(_path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _cd(String path) async {
    setState(() => _loading = true);
    try {
      final abs = await _sftp!.absolute(path);
      final entries = await _sftp!.listdir(abs);
      entries.sort((a, b) {
        final dir = (b.attr.isDirectory ? 1 : 0) - (a.attr.isDirectory ? 1 : 0);
        return dir != 0 ? dir : a.filename.compareTo(b.filename);
      });
      if (mounted) {
        setState(() {
          _path = abs;
          _entries = entries.where((e) => e.filename != '.').toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _download(SftpName entry) async {
    try {
      final remote = '$_path/${entry.filename}';
      final file = await _sftp!.open(remote);
      final chunks = await file.read().fold<List<int>>(
          <int>[], (acc, chunk) => acc..addAll(chunk));
      await file.close();
      final uri = await FilePicker.saveFile(
        fileName: entry.filename,
        bytes: Uint8List.fromList(chunks),
        dialogTitle: 'Save ${entry.filename}',
      );
      if (mounted && uri != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  Future<void> _upload() async {
    final files = await FilePicker.pickFiles();
    final file = files.firstOrNull;
    if (file == null) return;
    final bytes = await file.readAsBytes();
    try {
      final remote = await _sftp!.open('$_path/${file.name}',
          mode: SftpFileOpenMode.write |
              SftpFileOpenMode.create |
              SftpFileOpenMode.truncate);
      await remote.writeBytes(bytes);
      await remote.close();
      await _cd(_path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _copyPath() async {
    await Clipboard.setData(ClipboardData(text: _path));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Path copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _copyPath,
          child: Text(_path,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 14)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_upward_rounded),
            tooltip: 'Up',
            onPressed: _loading ? null : () => _cd('$_path/..'),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Upload here',
            onPressed: _upload,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.error_outline, title: 'SFTP failed', hint: _error)
              : _entries.isEmpty
                  ? const EmptyState(
                      icon: Icons.folder_open,
                      title: 'Empty directory',
                    )
                  : ListView.separated(
                      itemCount: _entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 0.5),
                      itemBuilder: (context, i) {
                        final e = _entries[i];
                        final dir = e.attr.isDirectory;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            dir ? Icons.folder_rounded : Icons.insert_drive_file_outlined,
                            color: dir
                                ? Theme.of(context).colorScheme.primary
                                : null,
                            size: 20,
                          ),
                          title: Text(
                            e.filename,
                            style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
                          ),
                          subtitle: Text(
                            dir ? 'directory' : _fmtSize(e.attr.size ?? 0),
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: dir
                              ? () => _cd('$_path/${e.filename}')
                              : () => _download(e),
                          trailing: dir
                              ? null
                              : const Icon(Icons.download_rounded, size: 16),
                        );
                      },
                    ),
    );
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1 << 20) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1 << 30) return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
    return '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
  }
}
