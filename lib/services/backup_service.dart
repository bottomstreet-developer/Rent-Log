import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class BackupService {
  static const _lastBackupKey = 'last_backup_date';

  static Future<String?> getLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastBackupKey);
  }

  static Future<void> _saveLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateFormat('MMM d, yyyy').format(DateTime.now());
    await prefs.setString(_lastBackupKey, now);
  }

  static Future<bool> backupNow() async {
    try {
      final db = DatabaseHelper.instance;
      final leases = await db.getLeases();
      final payments = <Map<String, dynamic>>[];
      final increases = <Map<String, dynamic>>[];
      for (final lease in leases) {
        final id = lease.id;
        if (id == null) continue;
        final p = await db.getPayments(id);
        final i = await db.getIncreases(id);
        payments.addAll(p.map((e) => e.toMap()));
        increases.addAll(i.map((e) => e.toMap()));
      }
      final issues = <MaintenanceIssue>[];
      for (final lease in leases) {
        final id = lease.id;
        if (id == null) continue;
        issues.addAll(await db.getIssues(id));
      }
      final backup = {
        'version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'leases': leases.map((e) => e.toMap()).toList(),
        'payments': payments,
        'rent_increases': increases,
        'maintenance_issues': issues.map((e) => e.toMap()).toList(),
      };
      final json = jsonEncode(backup);
      final dir = await getTemporaryDirectory();
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final file = File('${dir.path}/rentlog_backup_$date.json');
      await file.writeAsString(json);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'RentLog Backup',
      );
      await _saveLastBackupDate();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> restoreBackup() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return false;
      final path = result.files.single.path;
      if (path == null) return false;
      final file = File(path);
      final json = await file.readAsString();
      final data = jsonDecode(json) as Map<String, dynamic>;
      final db = await DatabaseHelper.instance.database;
      await db.delete('maintenance_issue');
      await db.delete('rent_increase');
      await db.delete('rent_payment');
      await db.delete('lease');
      final leases = (data['leases'] as List)
          .map((e) => Lease.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      for (final lease in leases) {
        await db.insert(
          'lease',
          lease.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      final payments = (data['payments'] as List)
          .map(
            (e) =>
                RentPayment.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      for (final payment in payments) {
        await db.insert(
          'rent_payment',
          payment.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      final increases = (data['rent_increases'] as List)
          .map(
            (e) =>
                RentIncrease.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      for (final increase in increases) {
        await db.insert(
          'rent_increase',
          increase.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      final issues = (data['maintenance_issues'] as List)
          .map(
            (e) => MaintenanceIssue.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
      for (final issue in issues) {
        await db.insert(
          'maintenance_issue',
          issue.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      return true;
    } catch (e, st) {
      debugPrint('Restore error: $e');
      debugPrint('$st');
      return false;
    }
  }
}
