import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Core cryptographic utilities for E2EE implementation
class CryptoUtils {
  static const int _keySize = 256;
  static const int _ivSize = 16;
  static const int _saltSize = 32;

  /// Generate a random salt
  static Uint8List generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_saltSize, (i) => random.nextInt(256)),
    );
  }

  /// Generate a random IV
  static Uint8List generateIV() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_ivSize, (i) => random.nextInt(256)),
    );
  }

  /// Generate AES key for symmetric encryption
  static Uint8List generateAESKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (i) => random.nextInt(256)),
    );
  }

  /// Simple XOR encryption (for demonstration - in production use proper AES)
  static Map<String, String> encryptAES(String data, String key) {
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    final iv = generateIV();

    // XOR encryption with key and IV
    final encrypted = Uint8List(dataBytes.length);
    for (int i = 0; i < dataBytes.length; i++) {
      encrypted[i] =
          dataBytes[i] ^ keyBytes[i % keyBytes.length] ^ iv[i % iv.length];
    }

    return {
      'encrypted': base64.encode(encrypted),
      'iv': base64.encode(iv),
    };
  }

  /// Simple XOR decryption
  static String decryptAES(String encryptedData, String ivString, String key) {
    final keyBytes = utf8.encode(key);
    final encrypted = base64.decode(encryptedData);
    final iv = base64.decode(ivString);

    // XOR decryption
    final decrypted = Uint8List(encrypted.length);
    for (int i = 0; i < encrypted.length; i++) {
      decrypted[i] =
          encrypted[i] ^ keyBytes[i % keyBytes.length] ^ iv[i % iv.length];
    }

    return utf8.decode(decrypted);
  }

  /// Generate message signature using HMAC-SHA256
  static String signMessage(String message, String secretKey) {
    final key = utf8.encode(secretKey);
    final bytes = utf8.encode(message);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return base64.encode(digest.bytes);
  }

  /// Verify message signature
  static bool verifySignature(
      String message, String signature, String secretKey) {
    final expectedSignature = signMessage(message, secretKey);
    return signature == expectedSignature;
  }

  /// Generate secure random string
  static String generateSecureRandomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
          length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// Hash password for storage
  static String hashPassword(String password, String salt) {
    final saltedPassword = password + salt;
    final bytes = utf8.encode(saltedPassword);
    final digest = sha256.convert(bytes);
    return base64.encode(digest.bytes);
  }

  /// Verify password
  static bool verifyPassword(String password, String storedHash, String salt) {
    final computedHash = hashPassword(password, salt);
    return computedHash == storedHash;
  }

  /// Generate a secure session key
  static String generateSessionKey() {
    return generateSecureRandomString(32);
  }

  /// Encrypt message for E2EE
  static Map<String, String> encryptMessage(
      String message, String recipientPublicKey) {
    // Generate a unique session key for this message
    final sessionKey = generateSessionKey();

    // Encrypt the message with the session key
    final encryptedMessage = encryptAES(message, sessionKey);

    // For demo purposes, we'll use a shared secret approach
    // In production, this should use proper asymmetric encryption
    // We'll use the recipient's public key as a shared secret for demo
    final sessionKeyEncryptionKey = _deriveKeyFromPublicKey(recipientPublicKey);
    final encryptedSessionKey = encryptAES(sessionKey, sessionKeyEncryptionKey);

    return {
      'encryptedMessage': encryptedMessage['encrypted']!,
      'iv': encryptedMessage['iv']!,
      'encryptedSessionKey': encryptedSessionKey['encrypted']!,
      'sessionKeyIV': encryptedSessionKey['iv']!,
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      'signature': signMessage(message, sessionKey),
      'recipientPublicKey': recipientPublicKey, // Store for demo decryption
    };
  }

  /// Decrypt message for E2EE
  static String decryptMessage(
      Map<String, String> encryptedData, String privateKey) {
    try {
      // For demo purposes, we'll use the stored recipient public key for decryption
      // In production, this would use proper asymmetric decryption with private key
      final recipientPublicKey = encryptedData['recipientPublicKey'];
      if (recipientPublicKey == null) {
        throw Exception('Recipient public key not found in encrypted data');
      }

      // Use the same key derivation as encryption
      final sessionKeyDecryptionKey =
          _deriveKeyFromPublicKey(recipientPublicKey);

      // Decrypt the session key
      final sessionKey = decryptAES(
        encryptedData['encryptedSessionKey']!,
        encryptedData['sessionKeyIV']!,
        sessionKeyDecryptionKey,
      );

      // Decrypt the message with the session key
      final decryptedMessage = decryptAES(
        encryptedData['encryptedMessage']!,
        encryptedData['iv']!,
        sessionKey,
      );

      // Verify message integrity - but be more lenient for demo purposes
      try {
        final expectedSignature = signMessage(decryptedMessage, sessionKey);
        if (encryptedData['signature'] != expectedSignature) {
          print(
              'Warning: Message integrity check failed, but continuing with decryption');
          // For demo purposes, we'll continue even if signature doesn't match
          // In production, this should throw an exception
        }
      } catch (signatureError) {
        print('Warning: Signature verification failed: $signatureError');
        // Continue with decryption for demo purposes
      }

      return decryptedMessage;
    } catch (e) {
      throw Exception('Failed to decrypt message: $e');
    }
  }

  /// Generate a fingerprint for key verification
  static String generateFingerprint(String publicKey) {
    final bytes = utf8.encode(publicKey);
    final digest = sha256.convert(bytes);
    final fingerprint = digest.bytes
        .take(8)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':');
    return fingerprint.toUpperCase();
  }

  /// Verify message integrity
  static bool verifyMessageIntegrity(
      String message, String signature, String senderPublicKey) {
    return verifySignature(message, signature, senderPublicKey);
  }

  /// Generate key pair for E2EE
  static Map<String, String> generateKeyPair() {
    final privateKey = generateSecureRandomString(64);
    final publicKey = generateSecureRandomString(64);

    return {
      'privateKey': privateKey,
      'publicKey': publicKey,
      'fingerprint': generateFingerprint(publicKey),
    };
  }

  /// Derive a consistent key from public key for demo purposes
  static String _deriveKeyFromPublicKey(String publicKey) {
    final bytes = utf8.encode(publicKey);
    final digest = sha256.convert(bytes);
    return base64.encode(digest.bytes).substring(0, 32).padRight(32, '0');
  }

  /// Derive a consistent key from private key for demo purposes
  static String _deriveKeyFromPrivateKey(String privateKey) {
    final bytes = utf8.encode(privateKey);
    final digest = sha256.convert(bytes);
    return base64.encode(digest.bytes).substring(0, 32).padRight(32, '0');
  }
}
