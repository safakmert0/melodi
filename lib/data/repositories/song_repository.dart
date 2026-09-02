import 'package:melodi/core/errors.dart';
import 'package:melodi/data/models/song.dart';
import 'package:melodi/data/datasources/native/melodi_core.dart';
class SongRepository {
  final DbService db;
  final MelodiCore melodiCore;
  const SongRepository({required this.db, required this.melodiCore});
}
class DbService { const DbService(); }
