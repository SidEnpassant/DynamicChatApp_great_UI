import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/crypto_utils.dart';

/// E2EE Service for managing end-to-end encryption
class E2EEService {
  static final E2EEService _instance = E2EEService._internal();
  factory E2EEService() => _instance;
  E2EEService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Key storage constants
  static const String _privateKeyKey = 'e2ee_private_key';
  static const String _publicKeyKey = 'e2ee_public_key';
  static const String _fingerprintKey = 'e2ee_fingerprint';
  static const String _deviceIdKey = 'e2ee_device_id';

  /// Initialize E2EE for the current user
  Future<void> initializeE2EE() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final prefs = await SharedPreferences.getInstance();

      // Check if keys already exist
      final existingPrivateKey = prefs.getString(_privateKeyKey);
      if (existingPrivateKey != null) {
        // Keys already exist, verify they're stored in Firestore
        await _ensureKeysInFirestore();
        return;
      }

      // Generate new key pair
      final keyPair = CryptoUtils.generateKeyPair();

      // Store keys in SharedPreferences (in production, use secure storage)
      await prefs.setString(_privateKeyKey, keyPair['privateKey']!);
      await prefs.setString(_publicKeyKey, keyPair['publicKey']!);
      await prefs.setString(_fingerprintKey, keyPair['fingerprint']!);

      // Generate device ID
      final deviceId = CryptoUtils.generateSecureRandomString(16);
      await prefs.setString(_deviceIdKey, deviceId);

      // Store public key in Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('e2ee_keys')
          .doc(deviceId)
          .set({
        'publicKey': keyPair['publicKey'],
        'fingerprint': keyPair['fingerprint'],
        'deviceId': deviceId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUsed': FieldValue.serverTimestamp(),
      });

      // Update user document with E2EE status
      await _firestore.collection('users').doc(user.uid).update({
        'e2eeEnabled': true,
        'e2eeFingerprint': keyPair['fingerprint'],
        'lastE2EEUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to initialize E2EE: $e');
    }
  }

  /// Ensure keys are stored in Firestore
  Future<void> _ensureKeysInFirestore() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(_deviceIdKey);
    final publicKey = prefs.getString(_publicKeyKey);
    final fingerprint = prefs.getString(_fingerprintKey);

    if (deviceId == null || publicKey == null || fingerprint == null) {
      throw Exception('E2EE keys not found on device');
    }

    // Check if keys exist in Firestore
    final keyDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('e2ee_keys')
        .doc(deviceId)
        .get();

    if (!keyDoc.exists) {
      // Store keys in Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('e2ee_keys')
          .doc(deviceId)
          .set({
        'publicKey': publicKey,
        'fingerprint': fingerprint,
        'deviceId': deviceId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUsed': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Get current user's public key
  Future<String?> getCurrentUserPublicKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_publicKeyKey);
  }

  /// Get current user's private key
  Future<String?> getCurrentUserPrivateKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_privateKeyKey);
  }

  /// Get current user's fingerprint
  Future<String?> getCurrentUserFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fingerprintKey);
  }

  /// Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Get recipient's public key from Firestore
  Future<String?> getRecipientPublicKey(String recipientUid) async {
    try {
      final keysSnapshot = await _firestore
          .collection('users')
          .doc(recipientUid)
          .collection('e2ee_keys')
          .orderBy('lastUsed', descending: true)
          .limit(1)
          .get();

      if (keysSnapshot.docs.isEmpty) {
        return null;
      }

      return keysSnapshot.docs.first.data()['publicKey'] as String;
    } catch (e) {
      throw Exception('Failed to get recipient public key: $e');
    }
  }

  /// Encrypt message for a specific recipient
  Future<Map<String, dynamic>> encryptMessage(
      String message, String recipientUid) async {
    try {
      // Get recipient's public key
      final recipientPublicKey = await getRecipientPublicKey(recipientUid);
      if (recipientPublicKey == null) {
        throw Exception(
            'Recipient public key not found - recipient may not have E2EE enabled');
      }

      // Encrypt the message
      final encryptedData =
          CryptoUtils.encryptMessage(message, recipientPublicKey);

      // Get current user's fingerprint for verification
      final senderFingerprint = await getCurrentUserFingerprint();

      return {
        ...encryptedData,
        'senderFingerprint': senderFingerprint,
        'recipientUid': recipientUid,
        'encrypted': true,
      };
    } catch (e) {
      throw Exception('Failed to encrypt message: $e');
    }
  }

  /// Decrypt message using current user's private key
  Future<String> decryptMessage(Map<String, dynamic> encryptedData) async {
    try {
      final privateKey = await getCurrentUserPrivateKey();
      if (privateKey == null) {
        throw Exception('Private key not found');
      }

      // Convert the encrypted data to the format expected by CryptoUtils
      final cryptoData = <String, String>{
        'encryptedMessage': encryptedData['encryptedMessage'] as String,
        'iv': encryptedData['iv'] as String,
        'encryptedSessionKey': encryptedData['encryptedSessionKey'] as String,
        'sessionKeyIV': encryptedData['sessionKeyIV'] as String,
        'signature': encryptedData['signature'] as String,
        'recipientPublicKey':
            encryptedData['recipientPublicKey'] as String, // Add this field
      };

      return CryptoUtils.decryptMessage(cryptoData, privateKey);
    } catch (e) {
      throw Exception('Failed to decrypt message: $e');
    }
  }

  /// Verify message sender's fingerprint
  Future<bool> verifyMessageSender(
      String senderFingerprint, String senderUid) async {
    try {
      final keysSnapshot = await _firestore
          .collection('users')
          .doc(senderUid)
          .collection('e2ee_keys')
          .where('fingerprint', isEqualTo: senderFingerprint)
          .get();

      return keysSnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get all devices for a user
  Future<List<Map<String, dynamic>>> getUserDevices(String userUid) async {
    try {
      final devicesSnapshot = await _firestore
          .collection('users')
          .doc(userUid)
          .collection('e2ee_keys')
          .get();

      return devicesSnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Failed to get user devices: $e');
    }
  }

  /// Revoke a device's keys
  Future<void> revokeDevice(String deviceId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final prefs = await SharedPreferences.getInstance();

      // Remove from Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('e2ee_keys')
          .doc(deviceId)
          .delete();

      // If this is the current device, clear local keys
      final currentDeviceId = prefs.getString(_deviceIdKey);
      if (deviceId == currentDeviceId) {
        await prefs.remove(_privateKeyKey);
        await prefs.remove(_publicKeyKey);
        await prefs.remove(_fingerprintKey);
        await prefs.remove(_deviceIdKey);
      }
    } catch (e) {
      throw Exception('Failed to revoke device: $e');
    }
  }

  /// Check if E2EE is enabled for current user
  Future<bool> isE2EEEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final privateKey = prefs.getString(_privateKeyKey);
      return privateKey != null;
    } catch (e) {
      return false;
    }
  }

  /// Get E2EE status for a user
  Future<bool> getUserE2EEStatus(String userUid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userUid).get();
      return userDoc.data()?['e2eeEnabled'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Update last used timestamp for current device
  Future<void> updateLastUsed() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString(_deviceIdKey);
      if (deviceId == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('e2ee_keys')
          .doc(deviceId)
          .update({
        'lastUsed': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently fail for last used updates
    }
  }

  /// Export keys for backup (encrypted)
  Future<String> exportKeys(String backupPassword) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final privateKey = prefs.getString(_privateKeyKey);
      final publicKey = prefs.getString(_publicKeyKey);
      final fingerprint = prefs.getString(_fingerprintKey);
      final deviceId = prefs.getString(_deviceIdKey);

      if (privateKey == null ||
          publicKey == null ||
          fingerprint == null ||
          deviceId == null) {
        throw Exception('Keys not found');
      }

      final keysData = {
        'privateKey': privateKey,
        'publicKey': publicKey,
        'fingerprint': fingerprint,
        'deviceId': deviceId,
        'exportedAt': DateTime.now().toIso8601String(),
      };

      final keysJson = json.encode(keysData);
      final salt = CryptoUtils.generateSalt();
      final encryptedKeys = CryptoUtils.encryptAES(
          keysJson, backupPassword + base64.encode(salt));

      return json.encode({
        'encryptedKeys': encryptedKeys['encrypted'],
        'iv': encryptedKeys['iv'],
        'salt': base64.encode(salt),
      });
    } catch (e) {
      throw Exception('Failed to export keys: $e');
    }
  }

  /// Import keys from backup
  Future<void> importKeys(String backupData, String backupPassword) async {
    try {
      final backup = json.decode(backupData);
      final salt = base64.decode(backup['salt']);
      final decryptedKeys = CryptoUtils.decryptAES(
        backup['encryptedKeys'],
        backup['iv'],
        backupPassword + base64.encode(salt),
      );

      final keysData = json.decode(decryptedKeys);
      final prefs = await SharedPreferences.getInstance();

      // Store imported keys
      await prefs.setString(_privateKeyKey, keysData['privateKey']);
      await prefs.setString(_publicKeyKey, keysData['publicKey']);
      await prefs.setString(_fingerprintKey, keysData['fingerprint']);
      await prefs.setString(_deviceIdKey, keysData['deviceId']);

      // Ensure keys are in Firestore
      await _ensureKeysInFirestore();
    } catch (e) {
      throw Exception('Failed to import keys: $e');
    }
  }

  // ============================================================
  // =============== GROUP CHAT E2EE FEATURES ===================
  // ============================================================

  /// Initialize E2EE for a group chat
  Future<void> initializeGroupE2EE(
      String groupId, List<String> memberIds) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if user is a member of the group
      if (!memberIds.contains(user.uid)) {
        throw Exception('User is not a member of this group');
      }

      // Generate a group encryption key
      final groupKey = CryptoUtils.generateSecureRandomString(32);

      // Encrypt the group key for each member using their public keys
      final encryptedGroupKeys = <String, Map<String, dynamic>>{};

      for (final memberId in memberIds) {
        try {
          final memberPublicKey = await getRecipientPublicKey(memberId);
          if (memberPublicKey != null) {
            // Encrypt group key with member's public key
            final encryptedGroupKey =
                CryptoUtils.encryptAES(groupKey, memberPublicKey);
            encryptedGroupKeys[memberId] = {
              'encryptedGroupKey': encryptedGroupKey['encrypted']!,
              'iv': encryptedGroupKey['iv']!,
            };
          }
        } catch (e) {
          print(
              'Warning: Could not encrypt group key for member $memberId: $e');
        }
      }

      // Store group E2EE data in Firestore
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('e2ee_keys')
          .doc('group_key')
          .set({
        'groupKey': groupKey,
        'encryptedGroupKeys': encryptedGroupKeys,
        'memberIds': memberIds,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
      });

      // Update group document with E2EE status
      await _firestore.collection('groups').doc(groupId).update({
        'e2eeEnabled': true,
        'e2eeGroupKeyId': 'group_key',
        'lastE2EEUpdate': FieldValue.serverTimestamp(),
      });

      print('Group E2EE initialized successfully for group: $groupId');
    } catch (e) {
      throw Exception('Failed to initialize group E2EE: $e');
    }
  }

  /// Check if E2EE is enabled for a group
  Future<bool> isGroupE2EEEnabled(String groupId) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      return groupDoc.data()?['e2eeEnabled'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get group encryption key for current user
  Future<String?> getGroupEncryptionKey(String groupId) async {
    try {
      print('DEBUG: getGroupEncryptionKey called for group: $groupId');

      final user = _auth.currentUser;
      if (user == null) {
        print('DEBUG: User is null');
        return null;
      }
      print('DEBUG: Current user ID: ${user.uid}');

      // Get group E2EE data
      print('DEBUG: Fetching group E2EE data from Firestore...');
      final e2eeDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('e2ee_keys')
          .doc('group_key')
          .get();

      if (!e2eeDoc.exists) {
        print('DEBUG: Group E2EE document does not exist');
        return null;
      }
      print('DEBUG: Group E2EE document exists');

      final e2eeData = e2eeDoc.data()!;
      print('DEBUG: e2eeData keys: ${e2eeData.keys.toList()}');

      final encryptedGroupKeys =
          e2eeData['encryptedGroupKeys'] as Map<String, dynamic>;
      print(
          'DEBUG: encryptedGroupKeys keys: ${encryptedGroupKeys.keys.toList()}');

      // Get current user's encrypted group key
      final userEncryptedKey = encryptedGroupKeys[user.uid];
      if (userEncryptedKey == null) {
        print('DEBUG: User encrypted key not found for user: ${user.uid}');
        return null;
      }
      print('DEBUG: User encrypted key found');

      // Get current user's public key (since group key was encrypted with it)
      print('DEBUG: Getting current user public key...');
      final publicKey = await getCurrentUserPublicKey();
      if (publicKey == null) {
        print('DEBUG: Current user public key is null');
        return null;
      }
      print('DEBUG: Current user public key retrieved');

      // Decrypt the group key using user's public key (same key used for encryption)
      print('DEBUG: Decrypting group key with public key...');
      final decryptedGroupKey = CryptoUtils.decryptAES(
        userEncryptedKey['encryptedGroupKey'],
        userEncryptedKey['iv'],
        publicKey,
      );
      print('DEBUG: Group key decrypted successfully');

      return decryptedGroupKey;
    } catch (e) {
      print('DEBUG: Failed to get group encryption key: $e');
      return null;
    }
  }

  /// Encrypt message for group chat
  Future<Map<String, dynamic>> encryptGroupMessage(
      String message, String groupId) async {
    try {
      // Check if group E2EE is enabled
      final isEnabled = await isGroupE2EEEnabled(groupId);
      if (!isEnabled) {
        throw Exception('Group E2EE is not enabled');
      }

      // Get group encryption key
      final groupKey = await getGroupEncryptionKey(groupId);
      if (groupKey == null) {
        throw Exception('Group encryption key not found');
      }

      // Encrypt the message with group key
      final encryptedData = CryptoUtils.encryptAES(message, groupKey);

      // Get current user's fingerprint for verification
      final senderFingerprint = await getCurrentUserFingerprint();

      return {
        'encryptedMessage':
            encryptedData['encrypted']!, // Add the encrypted message content
        'iv': encryptedData['iv']!, // Add the IV
        'senderFingerprint': senderFingerprint,
        'groupId': groupId,
        'encrypted': true,
        'isGroupMessage': true,
      };
    } catch (e) {
      throw Exception('Failed to encrypt group message: $e');
    }
  }

  /// Decrypt group message
  Future<String> decryptGroupMessage(Map<String, dynamic> encryptedData) async {
    try {
      print('DEBUG: Starting group message decryption');
      print('DEBUG: encryptedData keys: ${encryptedData.keys.toList()}');

      final groupId = encryptedData['groupId'] as String;
      print('DEBUG: Group ID: $groupId');

      // Get group encryption key
      print('DEBUG: Attempting to get group encryption key...');
      final groupKey = await getGroupEncryptionKey(groupId);
      if (groupKey == null) {
        print('DEBUG: Group encryption key is null');
        throw Exception('Group encryption key not found');
      }
      print('DEBUG: Group encryption key retrieved successfully');

      // Decrypt the message with group key
      print('DEBUG: Attempting to decrypt message with group key...');
      final decryptedMessage = CryptoUtils.decryptAES(
        encryptedData['encryptedMessage'] as String,
        encryptedData['iv'] as String,
        groupKey,
      );
      print('DEBUG: Message decrypted successfully: $decryptedMessage');

      return decryptedMessage;
    } catch (e) {
      print('DEBUG: Group message decryption failed with error: $e');
      throw Exception('Failed to decrypt group message: $e');
    }
  }

  /// Add new member to group E2EE
  Future<void> addMemberToGroupE2EE(String groupId, String newMemberId) async {
    try {
      // Get group E2EE data
      final e2eeDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('e2ee_keys')
          .doc('group_key')
          .get();

      if (!e2eeDoc.exists) {
        throw Exception('Group E2EE not initialized');
      }

      final e2eeData = e2eeDoc.data()!;
      final groupKey = e2eeData['groupKey'] as String;
      final encryptedGroupKeys =
          Map<String, dynamic>.from(e2eeData['encryptedGroupKeys']);

      // Get new member's public key
      final newMemberPublicKey = await getRecipientPublicKey(newMemberId);
      if (newMemberPublicKey == null) {
        throw Exception('New member does not have E2EE enabled');
      }

      // Encrypt group key for new member
      final encryptedGroupKey =
          CryptoUtils.encryptAES(groupKey, newMemberPublicKey);
      encryptedGroupKeys[newMemberId] = {
        'encryptedGroupKey': encryptedGroupKey['encrypted']!,
        'iv': encryptedGroupKey['iv']!,
      };

      // Update group E2EE data
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('e2ee_keys')
          .doc('group_key')
          .update({
        'encryptedGroupKeys': encryptedGroupKeys,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('Member $newMemberId added to group E2EE successfully');
    } catch (e) {
      throw Exception('Failed to add member to group E2EE: $e');
    }
  }

  /// Remove member from group E2EE
  Future<void> removeMemberFromGroupE2EE(
      String groupId, String memberId) async {
    try {
      // Get group E2EE data
      final e2eeDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('e2ee_keys')
          .doc('group_key')
          .get();

      if (!e2eeDoc.exists) return;

      final e2eeData = e2eeDoc.data()!;
      final encryptedGroupKeys =
          Map<String, dynamic>.from(e2eeData['encryptedGroupKeys']);

      // Remove member's encrypted group key
      encryptedGroupKeys.remove(memberId);

      // Update group E2EE data
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('e2ee_keys')
          .doc('group_key')
          .update({
        'encryptedGroupKeys': encryptedGroupKeys,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('Member $memberId removed from group E2EE successfully');
    } catch (e) {
      throw Exception('Failed to remove member from group E2EE: $e');
    }
  }

  /// Rotate group encryption key (for security)
  Future<void> rotateGroupEncryptionKey(String groupId) async {
    try {
      // Get current group E2EE data
      final e2eeDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('e2ee_keys')
          .doc('group_key')
          .get();

      if (!e2eeDoc.exists) {
        throw Exception('Group E2EE not initialized');
      }

      final e2eeData = e2eeDoc.data()!;
      final currentMemberIds = List<String>.from(e2eeData['memberIds']);

      // Generate new group key
      final newGroupKey = CryptoUtils.generateSecureRandomString(32);

      // Re-encrypt for all current members
      final newEncryptedGroupKeys = <String, Map<String, dynamic>>{};

      for (final memberId in currentMemberIds) {
        try {
          final memberPublicKey = await getRecipientPublicKey(memberId);
          if (memberPublicKey != null) {
            final encryptedGroupKey = CryptoUtils.encryptAES(
              newGroupKey,
              memberPublicKey,
            );
            newEncryptedGroupKeys[memberId] = {
              'encryptedGroupKey': encryptedGroupKey['encrypted']!,
              'iv': encryptedGroupKey['iv']!,
            };
          }
        } catch (e) {
          print(
              'Warning: Could not encrypt new group key for member $memberId: $e');
        }
      }

      // Update group E2EE data with new key
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('e2ee_keys')
          .doc('group_key')
          .update({
        'groupKey': newGroupKey,
        'encryptedGroupKeys': newEncryptedGroupKeys,
        'lastUpdated': FieldValue.serverTimestamp(),
        'keyRotatedAt': FieldValue.serverTimestamp(),
      });

      print('Group encryption key rotated successfully for group: $groupId');
    } catch (e) {
      throw Exception('Failed to rotate group encryption key: $e');
    }
  }
}
