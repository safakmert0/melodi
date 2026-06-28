import 'dart:convert';

import 'database_service.dart';

class EQPreset {
  final String name;
  final List<double> gains;

  const EQPreset({required this.name, required this.gains});

  Map<String, dynamic> toMap() => {'name': name, 'gains': gains};

  factory EQPreset.fromMap(Map<String, dynamic> map) => EQPreset(
        name: map['name'] as String,
        gains: List<double>.from(map['gains'] as List),
      );
}

class AudioEffectsService {
  static final AudioEffectsService _instance = AudioEffectsService._();
  factory AudioEffectsService() => _instance;
  AudioEffectsService._();

  final DatabaseService _db = DatabaseService.instance;

  static const List<EQPreset> _builtinPresets = [
    EQPreset(name: 'Flat', gains: [0.0, 0.0, 0.0, 0.0, 0.0]),
    EQPreset(name: 'Bass Boost', gains: [6.0, 4.0, 0.0, -1.0, -2.0]),
    EQPreset(name: 'Treble Boost', gains: [-2.0, -1.0, 0.0, 4.0, 6.0]),
    EQPreset(name: 'Vocal', gains: [-2.0, 0.0, 4.0, 3.0, 0.0]),
    EQPreset(name: 'Electronic', gains: [5.0, 3.0, 0.0, 2.0, 5.0]),
    EQPreset(name: 'Rock', gains: [5.0, 3.0, -1.0, 3.0, 5.0]),
    EQPreset(name: 'Pop', gains: [-1.0, 2.0, 5.0, 3.0, -1.0]),
    EQPreset(name: 'Jazz', gains: [3.0, 0.0, -1.0, 2.0, 4.0]),
    EQPreset(name: 'Classical', gains: [4.0, 2.0, 0.0, 2.0, 4.0]),
    EQPreset(name: 'Acoustic', gains: [3.0, 1.0, 0.0, 2.0, 3.0]),
    EQPreset(name: 'Dance', gains: [5.0, 3.0, 0.0, 3.0, 6.0]),
    EQPreset(name: 'Podcast', gains: [-1.0, 2.0, 5.0, 3.0, 1.0]),
  ];

  List<EQPreset> _userPresets = [];
  EQPreset _currentPreset = _builtinPresets[0];
  List<double> _customGains = [0.0, 0.0, 0.0, 0.0, 0.0];

  Future<void> initialize() async {
    await loadUserPresets();
  }

  List<EQPreset> get builtinPresets => List.unmodifiable(_builtinPresets);

  List<EQPreset> get userPresets => List.unmodifiable(_userPresets);

  List<EQPreset> get allPresets => [..._builtinPresets, ..._userPresets];

  EQPreset get currentPreset => _currentPreset;

  List<double> get currentGains => List.unmodifiable(_customGains);

  void applyPreset(String presetName) {
    final preset = allPresets.firstWhere(
      (p) => p.name == presetName,
      orElse: () => _builtinPresets[0],
    );
    _currentPreset = preset;
    _customGains = List.from(preset.gains);
  }

  void setCustomEQ(List<double> gains) {
    if (gains.length != 5) return;
    _customGains = List.from(gains);
    _currentPreset = EQPreset(name: 'Custom', gains: gains);
  }

  Future<void> saveUserPreset(String name, List<double> gains) async {
    if (gains.length != 5) return;
    final preset = EQPreset(name: name, gains: gains);
    _userPresets.removeWhere((p) => p.name == name);
    _userPresets.add(preset);
    await _persistUserPresets();
  }

  Future<void> deleteUserPreset(String name) async {
    _userPresets.removeWhere((p) => p.name == name);
    await _persistUserPresets();
    if (_currentPreset.name == name) {
      applyPreset('Flat');
    }
  }

  Future<void> loadUserPresets() async {
    final json = await _db.getSetting('user_eq_presets');
    if (json == null || json.isEmpty) return;
    try {
      final list = jsonDecode(json) as List;
      _userPresets = list.map((m) => EQPreset.fromMap(m as Map<String, dynamic>)).toList();
    } catch (_) {}
  }

  Future<void> _persistUserPresets() async {
    final json = jsonEncode(_userPresets.map((p) => p.toMap()).toList());
    await _db.setSetting('user_eq_presets', json);
  }
}