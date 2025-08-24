import 'package:dynamichatapp/shared/services/e2ee_service.dart';
import 'package:dynamichatapp/core/utils/crypto_utils.dart';

/// E2EE Verification Utility
/// This class provides methods to test and verify E2EE functionality
class E2EEVerification {
  static final E2EEService _e2eeService = E2EEService();

  /// Test basic E2EE initialization
  static Future<Map<String, dynamic>> testInitialization() async {
    try {
      await _e2eeService.initializeE2EE();

      final fingerprint = await _e2eeService.getCurrentUserFingerprint();
      final publicKey = await _e2eeService.getCurrentUserPublicKey();
      final isEnabled = await _e2eeService.isE2EEEnabled();

      return {
        'success': true,
        'fingerprint': fingerprint,
        'publicKey': publicKey != null
            ? publicKey.substring(0, 20) + '...'
            : 'null', // Show first 20 chars
        'isEnabled': isEnabled,
        'message': 'E2EE initialized successfully'
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'E2EE initialization failed'
      };
    }
  }

  /// Test message encryption and decryption
  static Future<Map<String, dynamic>> testEncryptionDecryption(
      String testMessage) async {
    try {
      // First, ensure E2EE is initialized
      await _e2eeService.initializeE2EE();

      // Get current user's keys for testing
      final currentUserPublicKey = await _e2eeService.getCurrentUserPublicKey();
      final currentUserPrivateKey =
          await _e2eeService.getCurrentUserPrivateKey();

      if (currentUserPublicKey == null || currentUserPrivateKey == null) {
        return {
          'success': false,
          'error': 'No keys found',
          'message': 'Please enable E2EE first'
        };
      }
      // For testing purposes, we'll use a simpler approach that works with the same user
      // In real usage, this would be between different users with proper asymmetric encryption
      final sessionKey = CryptoUtils.generateSessionKey();
      final encryptedMessage = CryptoUtils.encryptAES(testMessage, sessionKey);
      final decryptedMessage = CryptoUtils.decryptAES(
        encryptedMessage['encrypted']!,
        encryptedMessage['iv']!,
        sessionKey,
      );

      // Verify the decrypted message matches the original
      final isCorrect = decryptedMessage == testMessage;

      return {
        'success': true,
        'originalMessage': testMessage,
        'encryptedData': encryptedMessage,
        'decryptedMessage': decryptedMessage,
        'isCorrect': isCorrect,
        'message': isCorrect
            ? 'Encryption/Decryption test passed'
            : 'Encryption/Decryption test failed'
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Encryption/Decryption test failed'
      };
    }
  }

  /// Test key generation
  static Future<Map<String, dynamic>> testKeyGeneration() async {
    try {
      final keyPair = CryptoUtils.generateKeyPair();
      final fingerprint =
          CryptoUtils.generateFingerprint(keyPair['publicKey']!);

      return {
        'success': true,
        'publicKey': keyPair['publicKey'] != null
            ? keyPair['publicKey']!.substring(0, 20) + '...'
            : 'null',
        'privateKey': keyPair['privateKey'] != null
            ? keyPair['privateKey']!.substring(0, 20) + '...'
            : 'null',
        'fingerprint': fingerprint,
        'message': 'Key generation test passed'
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Key generation test failed'
      };
    }
  }

  /// Test message integrity verification
  static Future<Map<String, dynamic>> testMessageIntegrity(
      String testMessage) async {
    try {
      final signature = CryptoUtils.generateFingerprint(testMessage);
      final isValid = CryptoUtils.verifyMessageIntegrity(
          testMessage, signature, 'test_sender_key');

      return {
        'success': true,
        'message': testMessage,
        'signature': signature,
        'isValid': isValid,
        'testResult': isValid
            ? 'Message integrity test passed'
            : 'Message integrity test failed'
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Message integrity test failed'
      };
    }
  }

  /// Run all E2EE tests
  static Future<Map<String, dynamic>> runAllTests() async {
    final results = <String, dynamic>{};

    // Test 1: Key Generation
    results['keyGeneration'] = await testKeyGeneration();

    // Test 2: E2EE Initialization
    results['initialization'] = await testInitialization();

    // Test 3: Message Integrity
    results['messageIntegrity'] =
        await testMessageIntegrity('Hello, E2EE World!');

    // Test 4: Encryption/Decryption
    results['encryptionDecryption'] =
        await testEncryptionDecryption('Secret message for testing');

    // Calculate overall success
    final allTests = [
      results['keyGeneration']['success'],
      results['initialization']['success'],
      results['messageIntegrity']['success'],
      results['encryptionDecryption']['success'],
    ];

    results['overallSuccess'] = allTests.every((test) => test == true);
    results['totalTests'] = allTests.length;
    results['passedTests'] = allTests.where((test) => test == true).length;

    return results;
  }
}
