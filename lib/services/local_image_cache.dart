import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart';

class LocalImageCache {
  static const _dbName = 'cid_local_storage';
  static const _storeName = 'incident_images';

  static Future<Database?> _openDb() async {
    if (!kIsWeb) return null;
    final factory = getIdbFactory();
    if (factory == null) return null;
    return factory.open(
      _dbName,
      version: 1,
      onUpgradeNeeded: (VersionChangeEvent e) {
        final db = e.database;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      },
    );
  }

  static Future<void> saveImageLocally(String key, Uint8List bytes) async {
    if (!kIsWeb) return;
    try {
      debugPrint('CACHE SAVE IMAGE: $key');
      final db = await _openDb();
      if (db == null) return;
      final txn = db.transaction(_storeName, idbModeReadWrite);
      await txn.objectStore(_storeName).put(bytes, key);
      await txn.completed;
    } catch (e) {
      debugPrint('CACHE SAVE IMAGE ERROR: $e');
    }
  }

  static Future<Uint8List?> getImage(String key) async {
    if (!kIsWeb) return null;
    try {
      debugPrint('CACHE LOAD IMAGE: $key');
      final db = await _openDb();
      if (db == null) return null;
      final txn = db.transaction(_storeName, idbModeReadOnly);
      final result = await txn.objectStore(_storeName).getObject(key);
      await txn.completed;
      if (result is Uint8List) return result;
    } catch (e) {
      debugPrint('CACHE LOAD IMAGE ERROR: $e');
    }
    return null;
  }

  static Future<void> deleteImage(String key) async {
    if (!kIsWeb) return;
    try {
      final db = await _openDb();
      if (db == null) return;
      final txn = db.transaction(_storeName, idbModeReadWrite);
      await txn.objectStore(_storeName).delete(key);
      await txn.completed;
    } catch (e) {
      debugPrint('CACHE DELETE IMAGE ERROR: $e');
    }
  }

  static Future<void> clearIncidentImages(String incidentId) async {
    if (!kIsWeb) return;
    try {
      debugPrint('CACHE CLEAR INCIDENT: $incidentId');
      final db = await _openDb();
      if (db == null) return;
      final txn = db.transaction(_storeName, idbModeReadWrite);
      final store = txn.objectStore(_storeName);
      final cursors = store.openCursor(autoAdvance: true);
      await for (final cursor in cursors) {
        final key = cursor.key.toString();
        if (key.startsWith(incidentId)) {
          await store.delete(cursor.key);
        }
      }
      await txn.completed;
    } catch (e) {
      debugPrint('CACHE CLEAR INCIDENT ERROR: $e');
    }
  }
}
