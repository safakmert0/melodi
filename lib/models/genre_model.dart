class GenreModel {
  final String id;
  final String name;
  final int songCount;
  final List<String> songIds;

  GenreModel({
    required this.id,
    required this.name,
    required this.songCount,
    required this.songIds,
  });
}
