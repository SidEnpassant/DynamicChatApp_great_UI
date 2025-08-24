import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/services/e2ee_service.dart';

class E2EESettingsScreen extends StatefulWidget {
  const E2EESettingsScreen({super.key});

  @override
  State<E2EESettingsScreen> createState() => _E2EESettingsScreenState();
}

class _E2EESettingsScreenState extends State<E2EESettingsScreen> {
  final E2EEService _e2eeService = E2EEService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isE2EEEnabled = false;
  String? _fingerprint;
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _loadE2EEData();
  }

  Future<void> _loadE2EEData() async {
    try {
      final isEnabled = await _e2eeService.isE2EEEnabled();
      final fingerprint = await _e2eeService.getCurrentUserFingerprint();
      final devices = await _e2eeService.getUserDevices(_auth.currentUser!.uid);

      setState(() {
        _isE2EEEnabled = isEnabled;
        _fingerprint = fingerprint;
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load E2EE data: $e');
    }
  }

  Future<void> _initializeE2EE() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      await _e2eeService.initializeE2EE();
      await _loadE2EEData();
      _showSuccessSnackBar('E2EE initialized successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to initialize E2EE: $e');
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _exportKeys() async {
    final backupPassword = await _showBackupPasswordDialog();
    if (backupPassword == null) return;

    try {
      final backupData = await _e2eeService.exportKeys(backupPassword);
      await Clipboard.setData(ClipboardData(text: backupData));
      _showSuccessSnackBar('Keys exported to clipboard!');
    } catch (e) {
      _showErrorSnackBar('Failed to export keys: $e');
    }
  }

  Future<void> _importKeys() async {
    final backupData = await _showImportDialog();
    if (backupData == null) return;

    final backupPassword = await _showBackupPasswordDialog();
    if (backupPassword == null) return;

    try {
      await _e2eeService.importKeys(backupData, backupPassword);
      await _loadE2EEData();
      _showSuccessSnackBar('Keys imported successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to import keys: $e');
    }
  }

  Future<void> _revokeDevice(String deviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Device'),
        content: const Text(
            'Are you sure you want to revoke this device? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _e2eeService.revokeDevice(deviceId);
        await _loadE2EEData();
        _showSuccessSnackBar('Device revoked successfully!');
      } catch (e) {
        _showErrorSnackBar('Failed to revoke device: $e');
      }
    }
  }

  Future<String?> _showBackupPasswordDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Backup Password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            hintText: 'Enter a strong password for backup',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showImportDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Keys'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Backup Data',
            hintText: 'Paste your encrypted backup data here',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E2EE Settings'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // E2EE Status Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isE2EEEnabled
                                    ? Icons.security
                                    : Icons.security_outlined,
                                color:
                                    _isE2EEEnabled ? Colors.green : Colors.grey,
                                size: 32,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'End-to-End Encryption',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    Text(
                                      _isE2EEEnabled ? 'Enabled' : 'Disabled',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: _isE2EEEnabled
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (!_isE2EEEnabled) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                    _isInitializing ? null : _initializeE2EE,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                ),
                                child: _isInitializing
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : const Text('Enable E2EE'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  if (_isE2EEEnabled) ...[
                    const SizedBox(height: 16),

                    // Security Fingerprint Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Security Fingerprint',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            if (_fingerprint != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _fingerprint!,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        Clipboard.setData(
                                            ClipboardData(text: _fingerprint!));
                                        _showSuccessSnackBar(
                                            'Fingerprint copied!');
                                      },
                                      icon: const Icon(Icons.copy),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Share this fingerprint with your contacts to verify your identity.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Key Management Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Key Management',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _exportKeys,
                                    icon: const Icon(Icons.download),
                                    label: const Text('Export Keys'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _importKeys,
                                    icon: const Icon(Icons.upload),
                                    label: const Text('Import Keys'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Group E2EE Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.group, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'Group Chat Encryption',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Group messages are encrypted with a shared group key that is securely distributed to all group members.',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            const ListTile(
                              leading:
                                  Icon(Icons.security, color: Colors.green),
                              title: Text('Group Key Management'),
                              subtitle: Text(
                                  'Automatic key distribution and rotation'),
                            ),
                            const ListTile(
                              leading:
                                  Icon(Icons.group_add, color: Colors.blue),
                              title: Text('Member Management'),
                              subtitle:
                                  Text('Keys updated when members join/leave'),
                            ),
                            const ListTile(
                              leading:
                                  Icon(Icons.refresh, color: Colors.orange),
                              title: Text('Key Rotation'),
                              subtitle:
                                  Text('Periodic key updates for security'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Devices Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connected Devices',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            if (_devices.isEmpty)
                              const Text('No devices found.')
                            else
                              ..._devices.map((device) => ListTile(
                                    leading: const Icon(Icons.devices),
                                    title: Text('Device ${device['deviceId']}'),
                                    subtitle: Text(
                                        'Fingerprint: ${device['fingerprint']}'),
                                    trailing: IconButton(
                                      onPressed: () =>
                                          _revokeDevice(device['deviceId']),
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                    ),
                                  )),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Security Info Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Security Information',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            const ListTile(
                              leading: Icon(Icons.lock, color: Colors.green),
                              title: Text('Messages are encrypted'),
                              subtitle: Text(
                                  'Only you and the recipient can read messages'),
                            ),
                            const ListTile(
                              leading: Icon(Icons.key, color: Colors.blue),
                              title: Text('Keys stored locally'),
                              subtitle: Text(
                                  'Your private keys never leave your device'),
                            ),
                            const ListTile(
                              leading:
                                  Icon(Icons.verified, color: Colors.orange),
                              title: Text('Fingerprint verification'),
                              subtitle: Text(
                                  'Verify contacts using security fingerprints'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
