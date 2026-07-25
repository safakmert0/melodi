import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/database_service.dart';

class ListeningHistoryScreen extends StatefulWidget {
  const ListeningHistoryScreen({super.key});

  @override
  State<ListeningHistoryScreen> createState() => _ListeningHistoryScreenState();
}

class _ListeningHistoryScreenState extends State<ListeningHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _selectedDateHistory = [];
  List<Map<String, dynamic>> _groupedHistory = [];
  List<Map<String, dynamic>> _topTracks = [];
  List<Map<String, dynamic>> _topArtists = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseService.instance;
      final history = await db.getListeningHistoryByDate(_selectedDate);
      final grouped = await db.getListeningHistoryGroupedByDate(limitDays: 30);
      final topTracks = await db.getTopTracksByPeriod(10, 'all');
      final topArtists = await db.getTopArtistsByPeriod(10, 'all');
      final stats = await db.getListeningStats();

      if (mounted) {
        setState(() {
          _selectedDateHistory = history;
          _groupedHistory = grouped;
          _topTracks = topTracks;
          _topArtists = topArtists;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() => _selectedDate = date);
    _loadDateHistory(date);
  }

  Future<void> _loadDateHistory(DateTime date) async {
    final db = DatabaseService.instance;
    final history = await db.getListeningHistoryByDate(date);
    if (mounted) {
      setState(() => _selectedDateHistory = history);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: MelodiTheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppLocale.tr('listening_history'),
          style: MelodiTheme.heading(size: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: MelodiTheme.primaryGreen,
          labelColor: MelodiTheme.primaryGreen,
          unselectedLabelColor: MelodiTheme.onSurfaceVariant,
          tabs: [
            Tab(text: AppLocale.tr('calendar')),
            Tab(text: AppLocale.tr('statistics')),
            Tab(text: AppLocale.tr('suggestions')),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: MelodiTheme.primaryGreen))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCalendarTab(),
                _buildStatisticsTab(),
                _buildSuggestionsTab(),
              ],
            ),
    );
  }

  Widget _buildCalendarTab() {
    return Column(
      children: [
        _buildMiniCalendar(),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                _formatDate(_selectedDate),
                style: TextStyle(
                  color: MelodiTheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_selectedDateHistory.length} ${AppLocale.tr('songs')}',
                style: TextStyle(
                  color: MelodiTheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _selectedDateHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded,
                          size: 64,
                          color: MelodiTheme.onSurfaceVariant.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        AppLocale.tr('no_listening_history'),
                        style: TextStyle(
                            color: MelodiTheme.onSurfaceVariant, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _selectedDateHistory.length,
                  itemBuilder: (context, index) {
                    final event = _selectedDateHistory[index];
                    return _buildHistoryTile(event);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMiniCalendar() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final datesWithHistory =
        _groupedHistory.map((g) => g['date'] as String).toSet();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MelodiTheme.containerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 24),
                color: MelodiTheme.onSurfaceVariant,
                onPressed: () {
                  final newMonth =
                      DateTime(_selectedDate.year, _selectedDate.month - 1);
                  _onDateSelected(newMonth);
                },
              ),
              Text(
                _getMonthName(_selectedDate.month),
                style: TextStyle(
                  color: MelodiTheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 24),
                color: MelodiTheme.onSurfaceVariant,
                onPressed: () {
                  final newMonth =
                      DateTime(_selectedDate.year, _selectedDate.month + 1);
                  _onDateSelected(newMonth);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children:
                ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      color: MelodiTheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          _buildCalendarGrid(firstDay, lastDay, datesWithHistory),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(
      DateTime firstDay, DateTime lastDay, Set<String> datesWithHistory) {
    final firstWeekday = firstDay.weekday;
    final totalDays = lastDay.day;
    final today = DateTime.now();

    final cells = <Widget>[];
    for (int i = 1; i < firstWeekday; i++) {
      cells.add(const Expanded(child: SizedBox()));
    }
    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(firstDay.year, firstDay.month, day);
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final hasHistory = datesWithHistory.contains(dateStr);
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isSelected = date.year == _selectedDate.year &&
          date.month == _selectedDate.month &&
          date.day == _selectedDate.day;

      cells.add(
        Expanded(
          child: GestureDetector(
            onTap: () => _onDateSelected(date),
            child: Container(
              height: 36,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? MelodiTheme.primaryGreen
                    : isToday
                        ? MelodiTheme.primaryGreen.withOpacity(0.15)
                        : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      color: isSelected ? Colors.white : MelodiTheme.onSurface,
                      fontSize: 13,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (hasHistory && !isSelected)
                    Positioned(
                      bottom: 4,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: MelodiTheme.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 7) {
      final rowCells = cells.sublist(i, (i + 7).clamp(0, cells.length));
      while (rowCells.length < 7) {
        rowCells.add(const Expanded(child: SizedBox()));
      }
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: rowCells),
      ));
    }

    return Column(children: rows);
  }

  Widget _buildStatisticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsOverview(),
          const SizedBox(height: 24),
          _buildSectionHeader(AppLocale.tr('top_tracks')),
          const SizedBox(height: 12),
          _buildTopTracksList(),
          const SizedBox(height: 24),
          _buildSectionHeader(AppLocale.tr('top_artists')),
          const SizedBox(height: 12),
          _buildTopArtistsList(),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    final totalTimeMs = _stats['totalListeningTimeMs'] ?? 0;
    final hours = (totalTimeMs / 3600000).floor();
    final minutes = ((totalTimeMs % 3600000) / 60000).floor();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MelodiTheme.primaryGreen.withOpacity(0.15),
            MelodiTheme.primaryGreen.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MelodiTheme.primaryGreen.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.play_circle_outline_rounded,
            '${_stats['totalPlays'] ?? 0}',
            AppLocale.tr('total_plays'),
          ),
          _buildStatItem(
            Icons.access_time_rounded,
            '${hours}sa ${minutes}dk',
            AppLocale.tr('total_listening_time'),
          ),
          _buildStatItem(
            Icons.person_outline_rounded,
            '${_stats['uniqueArtists'] ?? 0}',
            AppLocale.tr('unique_artists'),
          ),
          _buildStatItem(
            Icons.music_note_rounded,
            '${_stats['uniqueTracks'] ?? 0}',
            AppLocale.tr('songs'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 24, color: MelodiTheme.primaryGreen),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: MelodiTheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: MelodiTheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: MelodiTheme.onSurfaceVariant,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTopTracksList() {
    if (_topTracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            AppLocale.tr('no_listening_history'),
            style: TextStyle(color: MelodiTheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      children: List.generate(_topTracks.length, (index) {
        final track = _topTracks[index];
        return _buildTrackTile(
          rank: index + 1,
          title: track['title'] as String? ?? '',
          artist: track['artist'] as String? ?? '',
          playCount: track['playCount'] as int? ?? 0,
        );
      }),
    );
  }

  Widget _buildTopArtistsList() {
    if (_topArtists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            AppLocale.tr('no_listening_history'),
            style: TextStyle(color: MelodiTheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      children: List.generate(_topArtists.length, (index) {
        final artist = _topArtists[index];
        return _buildArtistTile(
          rank: index + 1,
          name: artist['artist'] as String? ?? '',
          playCount: artist['playCount'] as int? ?? 0,
        );
      }),
    );
  }

  Widget _buildSuggestionsTab() {
    final now = DateTime.now();
    final hour = now.hour;
    String timeOfDay;
    if (hour >= 6 && hour < 12) {
      timeOfDay = 'morning';
    } else if (hour >= 12 && hour < 18) {
      timeOfDay = 'afternoon';
    } else if (hour >= 18 && hour < 24) {
      timeOfDay = 'evening';
    } else {
      timeOfDay = 'night';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSuggestionSection(
            AppLocale.tr('time_based_suggestion'),
            Icons.access_time_rounded,
            _getTimeOfDayLabel(timeOfDay),
          ),
          const SizedBox(height: 24),
          _buildSuggestionSection(
            AppLocale.tr('recent_favorites'),
            Icons.history_rounded,
            null,
          ),
          const SizedBox(height: 24),
          _buildSuggestionSection(
            AppLocale.tr('top_this_week'),
            Icons.trending_up_rounded,
            null,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionSection(
      String title, IconData icon, String? subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: MelodiTheme.primaryGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: MelodiTheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: MelodiTheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: _topTracks.isEmpty
              ? Center(
                  child: Text(
                    AppLocale.tr('not_enough_data'),
                    style: TextStyle(color: MelodiTheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _topTracks.take(10).length,
                  itemBuilder: (context, index) {
                    final track = _topTracks[index];
                    return _buildSuggestionCard(
                      track['title'] as String? ?? '',
                      track['artist'] as String? ?? '',
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(String title, String artist) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: MelodiTheme.containerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  MelodiTheme.primaryGreen.withOpacity(0.3),
                  MelodiTheme.primaryGreen.withOpacity(0.1)
                ],
              ),
            ),
            child: const Icon(Icons.music_note_rounded,
                color: MelodiTheme.primaryGreen),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MelodiTheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MelodiTheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> event) {
    final playedAt =
        DateTime.tryParse(event['playedAt'] as String? ?? '') ?? DateTime.now();
    final timeStr =
        '${playedAt.hour.toString().padLeft(2, '0')}:${playedAt.minute.toString().padLeft(2, '0')}';
    final isSkip = (event['isSkip'] as int? ?? 0) == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MelodiTheme.containerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSkip
                  ? Colors.orange.withOpacity(0.1)
                  : MelodiTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isSkip ? Icons.fast_forward_rounded : Icons.music_note_rounded,
              size: 22,
              color: isSkip ? Colors.orange : MelodiTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['title'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MelodiTheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event['artist'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MelodiTheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeStr,
            style: TextStyle(
              color: MelodiTheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTile({
    required int rank,
    required String title,
    required String artist,
    required int playCount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MelodiTheme.containerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: rank <= 3
                    ? MelodiTheme.primaryGreen
                    : MelodiTheme.onSurfaceVariant,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MelodiTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.music_note_rounded,
                size: 22, color: MelodiTheme.primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MelodiTheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MelodiTheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$playCount ${AppLocale.tr('times')}',
            style: TextStyle(
              color: MelodiTheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistTile({
    required int rank,
    required String name,
    required int playCount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MelodiTheme.containerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: rank <= 3
                    ? MelodiTheme.primaryGreen
                    : MelodiTheme.onSurfaceVariant,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MelodiTheme.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded,
                size: 22, color: MelodiTheme.primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: MelodiTheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$playCount ${AppLocale.tr('times')}',
            style: TextStyle(
              color: MelodiTheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }

  String _getMonthName(int month) {
    final months = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    return months[month];
  }

  String _getTimeOfDayLabel(String timeOfDay) {
    switch (timeOfDay) {
      case 'morning':
        return AppLocale.tr('morning_suggestion');
      case 'afternoon':
        return AppLocale.tr('afternoon_suggestion');
      case 'evening':
        return AppLocale.tr('evening_suggestion');
      case 'night':
        return AppLocale.tr('night_suggestion');
      default:
        return '';
    }
  }
}
