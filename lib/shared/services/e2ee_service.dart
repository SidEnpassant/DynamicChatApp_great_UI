import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/crypto_utils.dart';

class E2EEService {
  static final E2EEService _instance = E2EEService._internal();
  factory E2EEService() => _instance;
  E2EEService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _privateKeyKey = 'e2ee_private_key';
  static const String _publicKeyKey = 'e2ee_public_key';
  static const String _fingerprintKey = 'e2ee_fingerprint';
  static const String _deviceIdKey = 'e2ee_device_id';

  Future<void> initializeE2EE() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final prefs = await SharedPreferences.getInstance();

      final existingPrivateKey = prefs.getString(_privateKeyKey);
      if (existingPrivateKey != null) {
        await _ensureKeysInFirestore();
        return;
      }

      final keyPair = CryptoUtils.generateKeyPair();

      await prefs.setString(_privateKeyKey, keyPair['privateKey']!);
      await prefs.setString(_publicKeyKey, keyPair['publicKey']!);
      await prefs.setString(_fingerprintKey, keyPair['fingerprint']!);

      final deviceId = CryptoUtils.generateSecureRandomString(16);
      await prefs.setString(_deviceIdKey, deviceId);

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

      await _firestore.collection('users').doc(user.uid).update({
        'e2eeEnabled': true,
        'e2eeFingerprint': keyPair['fingerprint'],
        'lastE2EEUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to initialize E2EE: $e');
    }
  }

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

    final keyDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('e2ee_keys')
        .doc(deviceId)
        .get();

    if (!keyDoc.exists) {
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

  Future<String?> getCurrentUserPublicKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_publicKeyKey);
  }

  Future<String?> getCurrentUserPrivateKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_privateKeyKey);
  }

  Future<String?> getCurrentUserFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fingerprintKey);
  }

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

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

  Future<Map<String, dynamic>> encryptMessage(
      String message, String recipientUid) async {
    try {
      final recipientPublicKey = await getRecipientPublicKey(recipientUid);
      if (recipientPublicKey == null) {
        throw Exception(
            'Recipient public key not found - recipient may not have E2EE enabled');
      }
      final encryptedData =
          CryptoUtils.encryptMessage(message, recipientPublicKey);

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

  Future<String> decryptMessage(Map<String, dynamic> encryptedData) async {
    try {
      final privateKey = await getCurrentUserPrivateKey();
      if (privateKey == null) {
        throw Exception('Private key not found');
      }

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

  Future<void> revokeDevice(String deviceId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final prefs = await SharedPreferences.getInstance();

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('e2ee_keys')
          .doc(deviceId)
          .delete();

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

  Future<bool> isE2EEEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final privateKey = prefs.getString(_privateKeyKey);
      return privateKey != null;
    } catch (e) {
      return false;
    }
  }

  Future<bool> getUserE2EEStatus(String userUid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userUid).get();
      return userDoc.data()?['e2eeEnabled'] ?? false;
    } catch (e) {
      return false;
    }
  }

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
    } catch (e) {}
  }

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

      await prefs.setString(_privateKeyKey, keysData['privateKey']);
      await prefs.setString(_publicKeyKey, keysData['publicKey']);
      await prefs.setString(_fingerprintKey, keysData['fingerprint']);
      await prefs.setString(_deviceIdKey, keysData['deviceId']);

      await _ensureKeysInFirestore();
    } catch (e) {
      throw Exception('Failed to import keys: $e');
    }
  }

  Future<void> initializeGroupE2EE(
      String groupId, List<String> memberIds) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      if (!memberIds.contains(user.uid)) {
        throw Exception('User is not a member of this group');
      }

      final groupKey = CryptoUtils.generateSecureRandomString(32);

      final encryptedGroupKeys = <String, Map<String, dynamic>>{};

      for (final memberId in memberIds) {
        try {
          final memberPublicKey = await getRecipientPublicKey(memberId);
          if (memberPublicKey != null) {
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

  Future<bool> isGroupE2EEEnabled(String groupId) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      return groupDoc.data()?['e2eeEnabled'] ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getGroupEncryptionKey(String groupId) async {
    try {
      print('DEBUG: getGroupEncryptionKey called for group: $groupId');

      final user = _auth.currentUser;
      if (user == null) {
        print('DEBUG: User is null');
        return null;
      }
      print('DEBUG: Current user ID: ${user.uid}');

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

      final userEncryptedKey = encryptedGroupKeys[user.uid];
      if (userEncryptedKey == null) {
        print('DEBUG: User encrypted key not found for user: ${user.uid}');
        return null;
      }
      print('DEBUG: User encrypted key found');

      print('DEBUG: Getting current user public key...');
      final publicKey = await getCurrentUserPublicKey();
      if (publicKey == null) {
        print('DEBUG: Current user public key is null');
        return null;
      }
      print('DEBUG: Current user public key retrieved');

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

  Future<Map<String, dynamic>> encryptGroupMessage(
      String message, String groupId) async {
    try {
      final isEnabled = await isGroupE2EEEnabled(groupId);
      if (!isEnabled) {
        throw Exception('Group E2EE is not enabled');
      }

      final groupKey = await getGroupEncryptionKey(groupId);
      if (groupKey == null) {
        throw Exception('Group encryption key not found');
      }

      final encryptedData = CryptoUtils.encryptAES(message, groupKey);

      final senderFingerprint = await getCurrentUserFingerprint();

      return {
        'encryptedMessage': encryptedData['encrypted']!,
        'iv': encryptedData['iv']!,
        'senderFingerprint': senderFingerprint,
        'groupId': groupId,
        'encrypted': true,
        'isGroupMessage': true,
      };
    } catch (e) {
      throw Exception('Failed to encrypt group message: $e');
    }
  }

  Future<String> decryptGroupMessage(Map<String, dynamic> encryptedData) async {
    try {
      print('DEBUG: Starting group message decryption');
      print('DEBUG: encryptedData keys: ${encryptedData.keys.toList()}');

      final groupId = encryptedData['groupId'] as String;
      print('DEBUG: Group ID: $groupId');

      print('DEBUG: Attempting to get group encryption key...');
      final groupKey = await getGroupEncryptionKey(groupId);
      if (groupKey == null) {
        print('DEBUG: Group encryption key is null');
        throw Exception('Group encryption key not found');
      }
      print('DEBUG: Group encryption key retrieved successfully');

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

  Future<void> addMemberToGroupE2EE(String groupId, String newMemberId) async {
    try {
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

      final newMemberPublicKey = await getRecipientPublicKey(newMemberId);
      if (newMemberPublicKey == null) {
        throw Exception('New member does not have E2EE enabled');
      }

      final encryptedGroupKey =
          CryptoUtils.encryptAES(groupKey, newMemberPublicKey);
      encryptedGroupKeys[newMemberId] = {
        'encryptedGroupKey': encryptedGroupKey['encrypted']!,
        'iv': encryptedGroupKey['iv']!,
      };

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

  Future<void> removeMemberFromGroupE2EE(
      String groupId, String memberId) async {
    try {
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

      encryptedGroupKeys.remove(memberId);

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

  Future<void> rotateGroupEncryptionKey(String groupId) async {
    try {
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

      final newGroupKey = CryptoUtils.generateSecureRandomString(32);

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
