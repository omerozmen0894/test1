// lib/core/database/progress_model.dart
import 'package:isar/isar.dart';

part 'progress_model.g.dart';

@collection
class LevelProgress {
  Id id = Isar.autoIncrement;
  @Index(composite: [CompositeIndex('levelNumber')], unique: true)
  late String uid;
  late int levelNumber;
  late bool completed;
  late int bestMoves;
  late int playCount;
  late DateTime completedAt;

  LevelProgress();
  factory LevelProgress.create({
    required String uid,
    required int levelNumber,
    required int moves,
  }) =>
      LevelProgress()
        ..uid = uid
        ..levelNumber = levelNumber
        ..completed = true
        ..bestMoves = moves
        ..playCount = 1
        ..completedAt = DateTime.now();
}

@collection
class DailyRecord {
  Id id = Isar.autoIncrement;
  @Index(composite: [CompositeIndex('dateKey')], unique: true)
  late String uid;
  late String dateKey;
  late bool completed;
  late int moves;
  late int timeSeconds;
  late DateTime completedAt;

  DailyRecord();
  factory DailyRecord.create({
    required String uid,
    required String dateKey,
    required int moves,
    required int timeSeconds,
  }) =>
      DailyRecord()
        ..uid = uid
        ..dateKey = dateKey
        ..completed = true
        ..moves = moves
        ..timeSeconds = timeSeconds
        ..completedAt = DateTime.now();
}

@collection
class StreakRecord {
  Id id = Isar.autoIncrement;
  @Index(unique: true)
  late String uid;
  late int currentStreak;
  late int bestStreak;
  late List<String> completedDays;
  late List<String> badgeIds; // rozet id listesi
  late List<String> badgeData; // JSON string listesi

  StreakRecord();
  factory StreakRecord.empty(String uid) => StreakRecord()
    ..uid = uid
    ..currentStreak = 0
    ..bestStreak = 0
    ..completedDays = []
    ..badgeIds = []
    ..badgeData = [];
}

@collection
class CustomLevel {
  Id id = Isar.autoIncrement;
  late String uid; // oluşturan kullanıcı
  late String title;
  late int size;
  late String startJson; // Cell JSON
  late String endJson;
  late String wallsJson; // Cell[] JSON
  late DateTime createdAt;
  late int playCount;
  late double rating; // 0–5
  late int ratingCount;
  @Index()
  late bool isPublished; // Firebase'de yayınlı mı

  CustomLevel();
}

@collection
class AppSettings {
  Id id = Isar.autoIncrement;
  @Index(unique: true)
  late String uid;
  late String themeId;
  late bool soundEnabled;
  late bool hapticsEnabled;
  late bool adsRemoved;
  late bool premiumUnlocked;
  late String displayName;
  late int totalHints; // kalan hint hakkı

  AppSettings();
  factory AppSettings.defaults([String uid = 'local']) => AppSettings()
    ..uid = uid
    ..themeId = 'classic'
    ..soundEnabled = true
    ..hapticsEnabled = true
    ..adsRemoved = false
    ..premiumUnlocked = false
    ..displayName = 'Oyuncu'
    ..totalHints = 3;
}

@collection
class OfflineScore {
  Id id = Isar.autoIncrement;
  late String displayName;
  late int totalCompleted;
  late int bestStreak;
  late int dailyCompleted;
  late DateTime recordedAt;

  OfflineScore();
  factory OfflineScore.create({
    required String displayName,
    required int totalCompleted,
    required int bestStreak,
    required int dailyCompleted,
  }) =>
      OfflineScore()
        ..displayName = displayName
        ..totalCompleted = totalCompleted
        ..bestStreak = bestStreak
        ..dailyCompleted = dailyCompleted
        ..recordedAt = DateTime.now();
}
