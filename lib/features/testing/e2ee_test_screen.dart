import 'package:flutter/material.dart';
import '../../shared/services/e2ee_service.dart';
import 'e2ee_verification.dart';

class E2EETestScreen extends StatefulWidget {
  const E2EETestScreen({super.key});

  @override
  State<E2EETestScreen> createState() => _E2EETestScreenState();
}

class _E2EETestScreenState extends State<E2EETestScreen> {
  final E2EEService _e2eeService = E2EEService();
  bool _isLoading = false;
  Map<String, dynamic>? _testResults;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E2EE Test Screen'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // E2EE Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'E2EE Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<bool>(
                      future: _e2eeService.isE2EEEnabled(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        final isEnabled = snapshot.data ?? false;
                        return Row(
                          children: [
                            Icon(
                              isEnabled ? Icons.security : Icons.security_outlined,
                              color: isEnabled ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEnabled ? 'E2EE Enabled' : 'E2EE Disabled',
                              style: TextStyle(
                                color: isEnabled ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test Buttons
            ElevatedButton(
              onPressed: _isLoading ? null : _runAllTests,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Run All E2EE Tests'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testInitialization,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Test E2EE Initialization'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testEncryption,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Test Encryption/Decryption'),
            ),
            const SizedBox(height: 16),

            // Test Results
            if (_testResults != null) ...[
              const Text(
                'Test Results',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildTestResults(_testResults!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTestResults(Map<String, dynamic> results) {
    if (results.containsKey('overallSuccess')) {
      // All tests results
      return Column(
        children: [
          Card(
            color: results['overallSuccess'] ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        results['overallSuccess'] ? Icons.check_circle : Icons.error,
                        color: results['overallSuccess'] ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Overall Test Result: ${results['passedTests']}/${results['totalTests']} Tests Passed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: results['overallSuccess'] ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...results.entries
              .where((entry) => entry.key != 'overallSuccess' && entry.key != 'totalTests' && entry.key != 'passedTests')
              .map((entry) => _buildTestResultCard(entry.key, entry.value)),
        ],
      );
    } else {
      // Single test result
      return _buildTestResultCard('Test', results);
    }
  }

  Widget _buildTestResultCard(String testName, Map<String, dynamic> result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result['success'] ? Icons.check_circle : Icons.error,
                  color: result['success'] ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  testName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(result['message'] ?? 'No message'),
            if (result['error'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Error: ${result['error']}',
                style: const TextStyle(color: Colors.red),
              ),
            ],
            if (result['fingerprint'] != null) ...[
              const SizedBox(height: 4),
              Text('Fingerprint: ${result['fingerprint']}'),
            ],
            if (result['publicKey'] != null) ...[
              const SizedBox(height: 4),
              Text('Public Key: ${result['publicKey']}'),
            ],
            if (result['isCorrect'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Decryption Correct: ${result['isCorrect']}',
                style: TextStyle(
                  color: result['isCorrect'] ? Colors.green : Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isLoading = true;
      _testResults = null;
    });

    try {
      final results = await E2EEVerification.runAllTests();
      setState(() {
        _testResults = results;
      });
    } catch (e) {
      setState(() {
        _testResults = {
          'success': false,
          'error': e.toString(),
          'message': 'Failed to run tests',
        };
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testInitialization() async {
    setState(() {
      _isLoading = true;
      _testResults = null;
    });

    try {
      final result = await E2EEVerification.testInitialization();
      setState(() {
        _testResults = result;
      });
    } catch (e) {
      setState(() {
        _testResults = {
          'success': false,
          'error': e.toString(),
          'message': 'Failed to test initialization',
        };
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testEncryption() async {
    setState(() {
      _isLoading = true;
      _testResults = null;
    });

    try {
      final result = await E2EEVerification.testEncryptionDecryption('Hello, E2EE World!');
      setState(() {
        _testResults = result;
      });
    } catch (e) {
      setState(() {
        _testResults = {
          'success': false,
          'error': e.toString(),
          'message': 'Failed to test encryption',
        };
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
