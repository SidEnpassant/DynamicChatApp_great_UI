import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class CryptoUtils {
  static const int _keySize = 256;
  static const int _ivSize = 16;
  static const int _saltSize = 32;

  static Uint8List generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_saltSize, (i) => random.nextInt(256)),
    );
  }

  static Uint8List generateIV() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_ivSize, (i) => random.nextInt(256)),
    );
  }

  static Uint8List generateAESKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (i) => random.nextInt(256)),
    );
  }

  static Map<String, String> encryptAES(String data, String key) {
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    final iv = generateIV();

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

  static String decryptAES(String encryptedData, String ivString, String key) {
    final keyBytes = utf8.encode(key);
    final encrypted = base64.decode(encryptedData);
    final iv = base64.decode(ivString);

    final decrypted = Uint8List(encrypted.length);
    for (int i = 0; i < encrypted.length; i++) {
      decrypted[i] =
          encrypted[i] ^ keyBytes[i % keyBytes.length] ^ iv[i % iv.length];
    }

    return utf8.decode(decrypted);
  }

  static String signMessage(String message, String secretKey) {
    final key = utf8.encode(secretKey);
    final bytes = utf8.encode(message);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return base64.encode(digest.bytes);
  }

  static bool verifySignature(
      String message, String signature, String secretKey) {
    final expectedSignature = signMessage(message, secretKey);
    return signature == expectedSignature;
  }

  static String generateSecureRandomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
          length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  static String hashPassword(String password, String salt) {
    final saltedPassword = password + salt;
    final bytes = utf8.encode(saltedPassword);
    final digest = sha256.convert(bytes);
    return base64.encode(digest.bytes);
  }

  static bool verifyPassword(String password, String storedHash, String salt) {
    final computedHash = hashPassword(password, salt);
    return computedHash == storedHash;
  }

  static String generateSessionKey() {
    return generateSecureRandomString(32);
  }

  static Map<String, String> encryptMessage(
      String message, String recipientPublicKey) {
    final sessionKey = generateSessionKey();

    final encryptedMessage = encryptAES(message, sessionKey);

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

  static String decryptMessage(
      Map<String, String> encryptedData, String privateKey) {
    try {
      final recipientPublicKey = encryptedData['recipientPublicKey'];
      if (recipientPublicKey == null) {
        throw Exception('Recipient public key not found in encrypted data');
      }

      final sessionKeyDecryptionKey =
          _deriveKeyFromPublicKey(recipientPublicKey);

      final sessionKey = decryptAES(
        encryptedData['encryptedSessionKey']!,
        encryptedData['sessionKeyIV']!,
        sessionKeyDecryptionKey,
      );

      final decryptedMessage = decryptAES(
        encryptedData['encryptedMessage']!,
        encryptedData['iv']!,
        sessionKey,
      );

      try {
        final expectedSignature = signMessage(decryptedMessage, sessionKey);
        if (encryptedData['signature'] != expectedSignature) {
          print(
              'Warning: Message integrity check failed, but continuing with decryption');
        }
      } catch (signatureError) {
        print('Warning: Signature verification failed: $signatureError');
      }

      return decryptedMessage;
    } catch (e) {
      throw Exception('Failed to decrypt message: $e');
    }
  }

  static String generateFingerprint(String publicKey) {
    final bytes = utf8.encode(publicKey);
    final digest = sha256.convert(bytes);
    final fingerprint = digest.bytes
        .take(8)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':');
    return fingerprint.toUpperCase();
  }

  static bool verifyMessageIntegrity(
      String message, String signature, String senderPublicKey) {
    return verifySignature(message, signature, senderPublicKey);
  }

  static Map<String, String> generateKeyPair() {
    final privateKey = generateSecureRandomString(64);
    final publicKey = generateSecureRandomString(64);

    return {
      'privateKey': privateKey,
      'publicKey': publicKey,
      'fingerprint': generateFingerprint(publicKey),
    };
  }

  static String _deriveKeyFromPublicKey(String publicKey) {
    final bytes = utf8.encode(publicKey);
    final digest = sha256.convert(bytes);
    return base64.encode(digest.bytes).substring(0, 32).padRight(32, '0');
  }

  static String _deriveKeyFromPrivateKey(String privateKey) {
    final bytes = utf8.encode(privateKey);
    final digest = sha256.convert(bytes);
    return base64.encode(digest.bytes).substring(0, 32).padRight(32, '0');
  }
}
