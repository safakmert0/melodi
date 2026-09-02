// Placeholder DI - Riverpod migration in progress
import 'package:flutter_riverpod/flutter_riverpod.dart';
final isAppStoreBuildProvider = Provider<bool>((ref) => const bool.fromEnvironment('APP_STORE'));
