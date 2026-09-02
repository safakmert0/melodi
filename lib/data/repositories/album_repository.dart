import 'package:melodi/data/models/song.dart';
class DbService { const DbService(); }
class MelodiCore { const MelodiCore(); }
class AlbumRepository {
  final DbService db;
  final MelodiCore melodiCore;
  const AlbumRepository({required this.db, required this.melodiCore});
}
