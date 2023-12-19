import 'package:nidus_smpt/src/enums.dart';
import 'package:nidus_smpt/src/models/email/email.dart';
import 'package:postgres/postgres.dart';

/// {@template database}
/// [Database] class handles all the execute's to the database
/// {@endtemplate}
class Database {
  /// {@macro database}
  Database(this.connection);

  /// The connection to the database
  late final Connection connection;

  ///
  static Future<Connection> initialConnection({
    required String host,
    required String databaseName,
    required String userName,
    required String password,
    required int port,
    SslMode? sslMode,
  }) async {
    return Connection.open(
      Endpoint(
        host: host,
        database: databaseName,
        username: userName,
        password: password,
        port: port,
      ),
      settings: sslMode != null
          ? ConnectionSettings(
              sslMode: sslMode,
            )
          : null,
    );
  }

  ///
  Future<void> initialFixture(String schema) async {
    await connection.execute('''
      CREATE TABLE IF NOT EXISTS $schema.EmailQueue (
      id SERIAL PRIMARY KEY,
      createdAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      sentAt TIMESTAMP,
      "to" VARCHAR(255) NOT NULL,
      subject VARCHAR(255) NOT NULL,
      body TEXT NOT NULL,
      status INT NOT NULL DEFAULT 0,
    );
  ''');

    await connection.execute('''
      CREATE TABLE IF NOT EXISTS $schema.EmailSent (
      id SERIAL PRIMARY KEY,
      createdAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      sentAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "to" VARCHAR(255) NOT NULL,
      subject VARCHAR(255) NOT NULL,
      body TEXT NOT NULL,
      status INT NOT NULL DEFAULT 0,
      followUpAt TIMESTAMP,
    );
  ''');

    return;
  }

  /// This method allows the insertion of an email to the queue.
  Future<void> insertEmailToQueue({
    required String email,
    required String subject,
    required String body,
    required EmailStatus status,
    DateTime? sentAt,
  }) async {
    try {
      await connection.execute(
        Sql.named(
          'INSERT INTO emailqueue ("to", subject, body, sentat, status) VALUES (@to, @subject, @body, @sentat, @status)',
        ),
        parameters: {
          'to': email,
          'subject': subject,
          'body': body,
          'sentat': sentAt,
          'status': status.index,
        },
      );
      return;
    } catch (e) {
      rethrow;
    }
  }

  /// This method allows the insertion of an email to the sent table.
  Future<void> insertEmailSent({
    required String email,
    required String subject,
    required String body,
    int? followUpDays,
  }) async {
    try {
      await connection.execute(
        Sql.named(
          'INSERT INTO emailsent ("to", subject, body, sentat, status, followupat) VALUES (@to, @subject, @body, @sentat, @status, @followupat)',
        ),
        parameters: {
          'to': email,
          'subject': subject,
          'body': body,
          'sentat': DateTime.now(),
          'status': EmailStatus.sent.index,
          'followupat': followUpDays != null
              ? DateTime.now().add(Duration(days: followUpDays))
              : null,
        },
      );
      return;
    } catch (e) {
      rethrow;
    }
  }

  /// This method allows the update of an email to the sent table when the email
  /// has been read.
  Future<void> updateEmailAsRead(
    String id,
  ) async {
    try {
      await connection.execute(
        Sql.named('UPDATE emailsent SET status = @status WHERE id = @id'),
        parameters: {
          'id': id,
          'status': EmailStatus.read.index,
        },
      );
      return;
    } catch (e) {
      rethrow;
    }
  }

  /// This method fetch all the emails in the queue. This emails can be
  /// failures or scheduled emails.
  Future<List<Email>> fetchEmailsInQueue() async {
    try {
      final query = await connection.execute(
        'SELECT * FROM emailqueue WHERE sentat IS NULL',
      );

      final results = query.map(
        (row) {
          return Email(
            id: row[0] as int? ?? 0,
            createdAt: row[1] as DateTime? ?? DateTime.now(),
            sentAt: row[2] as DateTime?,
            email: row[3] as String? ?? '-',
            subject: row[4] as String? ?? '-',
            body: row[5] as String? ?? '-',
            status: EmailStatus.values[row[6] as int? ?? 0],
          );
        },
      ).toList();

      return results;
    } catch (e) {
      rethrow;
    }
  }

  /// This method deletes an email from the queue. Mostly once the email has
  /// been sent.
  Future<void> deleteEmailsInQueue(int id) async {
    try {
      await connection.execute(
        Sql.named('DELETE FROM emailqueue WHERE id = @id'),
        parameters: {
          'id': id,
        },
      );
      return;
    } catch (e) {
      rethrow;
    }
  }

  /// This will fetch a list of emails in a date range.
  Future<List<Email>> fetchEmailsInDateRange(DateTime datetime) async {
    try {
      final query = await connection.execute(
        Sql.named(
          '''
              SELECT * FROM emailsent 
              WHERE sentat <= @datetime 
              AND status != @readStatus
              ''',
        ),
        parameters: {
          'datetime': datetime,
          'readStatus': EmailStatus.read.index,
        },
      );

      final results = query.map(
        (row) {
          return Email(
            id: row[0] as int? ?? 0,
            createdAt: row[1] as DateTime? ?? DateTime.now(),
            sentAt: row[2] as DateTime? ?? DateTime.now(),
            email: row[3] as String? ?? '-',
            subject: row[4] as String? ?? '-',
            body: row[5] as String? ?? '-',
            status: EmailStatus.values[row[6] as int? ?? 0],
          );
        },
      ).toList();

      return results;
    } catch (e) {
      rethrow;
    }
  }

  /// This will fetch a list of emails with followUp value
  Future<List<Email>> fetchEmailsWithFollowUp() async {
    try {
      final query = await connection.execute(
        Sql.named(
          '''
              SELECT * FROM emailsent 
                WHERE followupat IS NOT NULL
              ''',
        ),
      );

      final results = query.map(
        (row) {
          return Email(
            id: row[0] as int? ?? 0,
            createdAt: row[1] as DateTime? ?? DateTime.now(),
            sentAt: row[2] as DateTime? ?? DateTime.now(),
            email: row[3] as String? ?? '-',
            subject: row[4] as String? ?? '-',
            body: row[5] as String? ?? '-',
            status: EmailStatus.values[row[6] as int? ?? 0],
            followUpAt: row[7] as DateTime? ?? DateTime.now(),
          );
        },
      ).toList();

      return results;
    } catch (e) {
      rethrow;
    }
  }
}
