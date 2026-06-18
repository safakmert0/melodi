import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class EncryptionService {
  static final _random = Random.secure();

  static List<int> _deriveKey(String password, List<int> salt, int iterations) {
    var key = utf8.encode(password);
    for (int i = 0; i < iterations; i++) {
      key = sha256.convert(key + salt).bytes;
    }
    return key;
  }

  static String encrypt(String plaintext, {String? password}) {
    try {
      final pwd = password ?? 'melodi_secret_key_2024';
      final salt = List<int>.generate(16, (_) => _random.nextInt(256));
      final iv = List<int>.generate(12, (_) => _random.nextInt(256));
      final key = _deriveKey(pwd, salt, 10000);
      final combined = [...salt, ...iv];
      final data = utf8.encode(plaintext);
      final encrypted = <int>[];
      for (int i = 0; i < data.length; i++) {
        encrypted.add(data[i] ^ key[i % key.length] ^ iv[i % iv.length]);
      }
      combined.addAll(encrypted);
      return base64Url.encode(combined);
    } catch (e) {
      debugPrint('Encryption failed: $e');
      return plaintext;
    }
  }

  static String decrypt(String ciphertext, {String? password}) {
    try {
      final pwd = password ?? 'melodi_secret_key_2024';
      final decoded = base64Url.decode(ciphertext);
      if (decoded.length < 28) return ciphertext;
      final salt = decoded.sublist(0, 16);
      final iv = decoded.sublist(16, 28);
      final encrypted = decoded.sublist(28);
      final key = _deriveKey(pwd, salt, 10000);
      final decrypted = <int>[];
      for (int i = 0; i < encrypted.length; i++) {
        decrypted.add(encrypted[i] ^ key[i % key.length] ^ iv[i % iv.length]);
      }
      return utf8.decode(decrypted);
    } catch (e) {
      debugPrint('Decryption failed: $e');
      return ciphertext;
    }
  }
}
