import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/app_feedback.dart';

class Lease {
  final int? id;
  final String propertyName;
  final String address;
  final String landlordName;
  final String landlordContact;
  final double monthlyRent;
  final double depositAmount;
  final String leaseStartDate;
  final String leaseEndDate;
  final int noticePeriodDays;
  final String notes;
  final String createdAt;

  Lease({
    this.id,
    required this.propertyName,
    required this.address,
    required this.landlordName,
    required this.landlordContact,
    required this.monthlyRent,
    required this.depositAmount,
    required this.leaseStartDate,
    required this.leaseEndDate,
    required this.noticePeriodDays,
    required this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'propertyName': propertyName,
    'address': address,
    'landlordName': landlordName,
    'landlordContact': landlordContact,
    'monthlyRent': monthlyRent,
    'depositAmount': depositAmount,
    'leaseStartDate': leaseStartDate,
    'leaseEndDate': leaseEndDate,
    'noticePeriodDays': noticePeriodDays,
    'notes': notes,
    'createdAt': createdAt,
  };

  factory Lease.fromMap(Map<String, dynamic> map) => Lease(
    id: map['id'] as int?,
    propertyName: map['propertyName'] as String? ?? '',
    address: map['address'] as String? ?? '',
    landlordName: map['landlordName'] as String? ?? '',
    landlordContact: map['landlordContact'] as String? ?? '',
    monthlyRent: (map['monthlyRent'] as num?)?.toDouble() ?? 0,
    depositAmount: (map['depositAmount'] as num?)?.toDouble() ?? 0,
    leaseStartDate: map['leaseStartDate'] as String? ?? '',
    leaseEndDate: map['leaseEndDate'] as String? ?? '',
    noticePeriodDays: map['noticePeriodDays'] as int? ?? 0,
    notes: map['notes'] as String? ?? '',
    createdAt: map['createdAt'] as String? ?? '',
  );
}

class RentPayment {
  final int? id;
  final int leaseId;
  final double amount;
  final String paymentDate;
  final String paymentMethod;
  final String receiptImagePath;
  final String notes;
  final String createdAt;

  RentPayment({
    this.id,
    required this.leaseId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    required this.receiptImagePath,
    required this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'leaseId': leaseId,
    'amount': amount,
    'paymentDate': paymentDate,
    'paymentMethod': paymentMethod,
    'receiptImagePath': receiptImagePath,
    'notes': notes,
    'createdAt': createdAt,
  };

  factory RentPayment.fromMap(Map<String, dynamic> map) => RentPayment(
    id: map['id'] as int?,
    leaseId: map['leaseId'] as int? ?? 0,
    amount: (map['amount'] as num?)?.toDouble() ?? 0,
    paymentDate: map['paymentDate'] as String? ?? '',
    paymentMethod: map['paymentMethod'] as String? ?? 'cash',
    receiptImagePath: map['receiptImagePath'] as String? ?? '',
    notes: map['notes'] as String? ?? '',
    createdAt: map['createdAt'] as String? ?? '',
  );
}

class RentIncrease {
  final int? id;
  final int leaseId;
  final double oldAmount;
  final double newAmount;
  final String effectiveDate;
  final String notes;
  final String createdAt;

  RentIncrease({
    this.id,
    required this.leaseId,
    required this.oldAmount,
    required this.newAmount,
    required this.effectiveDate,
    required this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'leaseId': leaseId,
    'oldAmount': oldAmount,
    'newAmount': newAmount,
    'effectiveDate': effectiveDate,
    'notes': notes,
    'createdAt': createdAt,
  };

  factory RentIncrease.fromMap(Map<String, dynamic> map) => RentIncrease(
    id: map['id'] as int?,
    leaseId: map['leaseId'] as int? ?? 0,
    oldAmount: (map['oldAmount'] as num?)?.toDouble() ?? 0,
    newAmount: (map['newAmount'] as num?)?.toDouble() ?? 0,
    effectiveDate: map['effectiveDate'] as String? ?? '',
    notes: map['notes'] as String? ?? '',
    createdAt: map['createdAt'] as String? ?? '',
  );
}

class MaintenanceIssue {
  final int? id;
  final int leaseId;
  final String title;
  final String description;
  final String reportedDate;
  final String status;
  final String photosPaths;
  final String notes;
  final String createdAt;

  MaintenanceIssue({
    this.id,
    required this.leaseId,
    required this.title,
    required this.description,
    required this.reportedDate,
    required this.status,
    required this.photosPaths,
    required this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'leaseId': leaseId,
    'title': title,
    'description': description,
    'reportedDate': reportedDate,
    'status': status,
    'photosPaths': photosPaths,
    'notes': notes,
    'createdAt': createdAt,
  };

  factory MaintenanceIssue.fromMap(Map<String, dynamic> map) =>
      MaintenanceIssue(
        id: map['id'] as int?,
        leaseId: map['leaseId'] as int? ?? 0,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        reportedDate: map['reportedDate'] as String? ?? '',
        status: map['status'] as String? ?? 'open',
        photosPaths: map['photosPaths'] as String? ?? '',
        notes: map['notes'] as String? ?? '',
        createdAt: map['createdAt'] as String? ?? '',
      );
}

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'rentlog.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE lease(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          propertyName TEXT,
          address TEXT,
          landlordName TEXT,
          landlordContact TEXT,
          monthlyRent REAL,
          depositAmount REAL,
          leaseStartDate TEXT,
          leaseEndDate TEXT,
          noticePeriodDays INTEGER,
          notes TEXT,
          createdAt TEXT
        )
      ''');
        await db.execute('''
        CREATE TABLE rent_payment(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          leaseId INTEGER,
          amount REAL,
          paymentDate TEXT,
          paymentMethod TEXT,
          receiptImagePath TEXT,
          notes TEXT,
          createdAt TEXT
        )
      ''');
        await db.execute('''
        CREATE TABLE rent_increase(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          leaseId INTEGER,
          oldAmount REAL,
          newAmount REAL,
          effectiveDate TEXT,
          notes TEXT,
          createdAt TEXT
        )
      ''');
        await db.execute('''
        CREATE TABLE maintenance_issue(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          leaseId INTEGER,
          title TEXT,
          description TEXT,
          reportedDate TEXT,
          status TEXT,
          photosPaths TEXT,
          notes TEXT,
          createdAt TEXT
        )
      ''');
      },
    );
  }

  Future<int> insertLease(Lease lease) async {
    try {
      return (await database).insert('lease', lease.toMap());
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return -1;
    }
  }

  Future<List<Lease>> getLeases() async {
    try {
      return (await database)
          .query('lease', orderBy: 'createdAt DESC')
          .then((rows) => rows.map(Lease.fromMap).toList());
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return <Lease>[];
    }
  }

  Future<Lease?> getLatestLease() async {
    try {
      final rows = await (await database).query(
        'lease',
        orderBy: 'createdAt DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Lease.fromMap(rows.first);
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return null;
    }
  }

  Future<int> updateLease(Lease lease) async {
    try {
      return (await database).update(
        'lease',
        lease.toMap(),
        where: 'id=?',
        whereArgs: [lease.id],
      );
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return 0;
    }
  }

  Future<int> deleteLease(int id) async {
    try {
      return (await database).delete('lease', where: 'id=?', whereArgs: [id]);
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return 0;
    }
  }

  Future<void> deleteLeaseAndAssociatedRecords(int leaseId) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('rent_payment', where: 'leaseId=?', whereArgs: [leaseId]);
        await txn.delete('rent_increase', where: 'leaseId=?', whereArgs: [leaseId]);
        await txn.delete(
          'maintenance_issue',
          where: 'leaseId=?',
          whereArgs: [leaseId],
        );
        await txn.delete('lease', where: 'id=?', whereArgs: [leaseId]);
      });
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
    }
  }

  Future<int> insertPayment(RentPayment payment) async {
    try {
      return (await database).insert('rent_payment', payment.toMap());
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return -1;
    }
  }

  Future<List<RentPayment>> getPayments(int leaseId) async {
    try {
      return (await database)
          .query(
            'rent_payment',
            where: 'leaseId=?',
            whereArgs: [leaseId],
            orderBy: 'paymentDate DESC',
          )
          .then((rows) => rows.map(RentPayment.fromMap).toList());
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return <RentPayment>[];
    }
  }

  Future<int> updatePayment(RentPayment payment) async {
    try {
      return (await database).update(
        'rent_payment',
        payment.toMap(),
        where: 'id=?',
        whereArgs: [payment.id],
      );
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return 0;
    }
  }

  Future<int> deletePayment(int id) async {
    try {
      return (await database).delete('rent_payment', where: 'id=?', whereArgs: [id]);
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return 0;
    }
  }

  Future<int> insertIncrease(RentIncrease increase) async {
    try {
      return (await database).insert('rent_increase', increase.toMap());
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return -1;
    }
  }

  Future<List<RentIncrease>> getIncreases(int leaseId) async {
    try {
      return (await database)
          .query(
            'rent_increase',
            where: 'leaseId=?',
            whereArgs: [leaseId],
            orderBy: 'effectiveDate DESC',
          )
          .then((rows) => rows.map(RentIncrease.fromMap).toList());
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return <RentIncrease>[];
    }
  }

  Future<int> updateIncrease(RentIncrease increase) async {
    try {
      return (await database).update(
        'rent_increase',
        increase.toMap(),
        where: 'id=?',
        whereArgs: [increase.id],
      );
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return 0;
    }
  }

  Future<int> deleteIncrease(int id) async {
    try {
      return (await database).delete('rent_increase', where: 'id=?', whereArgs: [id]);
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return 0;
    }
  }

  Future<int> insertIssue(MaintenanceIssue issue) async {
    try {
      return (await database).insert('maintenance_issue', issue.toMap());
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return -1;
    }
  }

  Future<List<MaintenanceIssue>> getIssues(
    int leaseId, {
    String? status,
  }) async {
    try {
      final db = await database;
      final where = status == null ? 'leaseId=?' : 'leaseId=? AND status=?';
      final args = status == null ? [leaseId] : [leaseId, status];
      final rows = await db.query(
        'maintenance_issue',
        where: where,
        whereArgs: args,
        orderBy: 'reportedDate DESC',
      );
      return rows.map(MaintenanceIssue.fromMap).toList();
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return <MaintenanceIssue>[];
    }
  }

  Future<int> updateIssue(MaintenanceIssue issue) async {
    try {
      return (await database).update(
        'maintenance_issue',
        issue.toMap(),
        where: 'id=?',
        whereArgs: [issue.id],
      );
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return 0;
    }
  }

  Future<int> deleteIssue(int id) async {
    try {
      return (await database).delete(
        'maintenance_issue',
        where: 'id=?',
        whereArgs: [id],
      );
    } catch (_) {
      showAppSnackBar('Something went wrong. Please try again.');
      return 0;
    }
  }
}
