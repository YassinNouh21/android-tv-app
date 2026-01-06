import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:audio_session/audio_session.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/const/constants.dart';
import 'package:mawaqit/src/services/notification/notification_service.dart';
import 'package:mawaqit/src/services/notification/prayer_audio_service.dart';

class UnifiedBackgroundService with WidgetsBindingObserver {
  static final UnifiedBackgroundService _instance = UnifiedBackgroundService._internal();
  static bool _isInitialized = false;
  static bool _shouldShowNotification = false;
  static AudioPlayer? _audioPlayer;
  static Duration? _savedPosition;

  // Store subscriptions for cleanup
  static final List<StreamSubscription> _eventSubscriptions = [];
  static StreamSubscription? _playbackEventSubscription;
  static StreamSubscription? _playerStateSubscription;
  static Timer? _scheduleCheckTimer;

  factory UnifiedBackgroundService() => _instance;

  UnifiedBackgroundService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  static bool isPlaying() => _audioPlayer?.playing ?? false;
  static AudioPlayer? get player => _audioPlayer;

  /// Initialize the unified background service
  ///
  /// Note: The _isInitialized flag is isolate-local and serves as an optimization
  /// to avoid redundant configuration calls within the same isolate. The actual
  /// service lifecycle is managed by FlutterBackgroundService and checked via
  /// service.isRunning(), which queries the platform service state.
  static Future<void> initializeService() async {
    try {
      final service = FlutterBackgroundService();

      // Always check if service is running and stop it first
      final isRunning = await service.isRunning();

      // If already initialized in this isolate and the service is running,
      // don't reinitialize. This is safe because:
      // 1. service.isRunning() checks the actual platform service state
      // 2. _isInitialized prevents redundant configuration in this isolate
      if (_isInitialized && isRunning) {
        developer.log('UnifiedBackgroundService already initialized and running');
        return;
      }

      // Stop existing service if running
      await _stopExistingService(service);

      // Configure and start fresh
      await _configureAndStartService(service);
      await NotificationService.dismissNotification();

      _isInitialized = true;
      developer.log('UnifiedBackgroundService initialized successfully');
    } catch (e, stackTrace) {
      _isInitialized = false;
      developer.log('UnifiedBackgroundService initialization failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await setNotificationVisibility(false);
        await pauseBackgroundOperations();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        await initializeService();
        await setNotificationVisibility(true);
        await resumeBackgroundOperations();
        break;
    }
  }

  static Future<void> setNotificationVisibility(bool shouldShow) async {
    _shouldShowNotification = shouldShow;
    final service = FlutterBackgroundService();
    if (!await _ensureServiceRunning(service)) return;
    service.invoke('updateNotificationVisibility', {'shouldShow': shouldShow});
  }

  static Future<void> pauseBackgroundOperations() async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) return;
    service.invoke('pauseOperations');
    await NotificationService.dismissNotification();
    await PrayerAudioService.stopAudio();
    await stopPlayback();
  }

  static Future<void> resumeBackgroundOperations() async {
    final service = FlutterBackgroundService();
    if (!await _ensureServiceRunning(service)) return;
    service.invoke('resumeOperations');
  }

  static Future<bool> _ensureServiceRunning(FlutterBackgroundService service) async {
    if (!await service.isRunning()) {
      await initializeService();
      return await service.isRunning();
    }
    return true;
  }

  /// Stop existing service and wait for it to complete shutdown
  ///
  /// Uses polling instead of a fixed delay to ensure the service has actually
  /// stopped before proceeding. This adapts to different device speeds and
  /// ensures cleanup is complete.
  static Future<void> _stopExistingService(FlutterBackgroundService service) async {
    if (!await service.isRunning()) {
      return;
    }

    developer.log('Stopping existing background service...');
    service.invoke('stopService');

    // Poll for service shutdown with timeout
    final stopwatch = Stopwatch()..start();
    const timeout = Duration(milliseconds: BackgroundServiceConstants.serviceStopTimeoutMs);
    const pollInterval = Duration(milliseconds: BackgroundServiceConstants.serviceStopPollIntervalMs);

    while (await service.isRunning()) {
      if (stopwatch.elapsed > timeout) {
        developer.log('Warning: Service stop timed out after ${timeout.inMilliseconds}ms');
        break;
      }
      await Future.delayed(pollInterval);
    }

    stopwatch.stop();
    if (!await service.isRunning()) {
      developer.log('Service stopped successfully in ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  static Future<void> _configureAndStartService(FlutterBackgroundService service) async {
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        autoStartOnBoot: false,
        isForegroundMode: true,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    await service.startService();
  }

  // Audio-related methods
  static Future<void> playAudio(dynamic surahSource, {bool createPlaylist = false}) async {
    try {
      if (_audioPlayer == null) {
        _audioPlayer = AudioPlayer();
        await _configureAudioSession();
        await _setupAudioSource(surahSource, createPlaylist);
      }

      if (_savedPosition != null && _audioPlayer?.audioSource != null) {
        await _audioPlayer?.seek(_savedPosition!);
        _savedPosition = null;
      }

      await _startPlayback(createPlaylist);
      FlutterBackgroundService().invoke('kAudioStateChanged', {'isPlaying': true});
    } catch (e) {
      print('Error playing audio: $e');
      FlutterBackgroundService().invoke('kAudioStateChanged', {'isPlaying': false});
    }
  }

  static Future<void> stopPlayback() async {
    try {
      _savedPosition = _audioPlayer?.position;
      await _audioPlayer?.pause();
      FlutterBackgroundService().invoke('kAudioStateChanged', {'isPlaying': false});
    } catch (e) {
      print('Error stopping playback: $e');
    }
  }

  // Audio configuration methods
  static Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ),
    );
    await session.setActive(true);
    await _audioPlayer?.setVolume(1.0);
  }

  static Future<void> _setupAudioSource(dynamic surahSource, bool createPlaylist) async {
    if (_audioPlayer?.audioSource == null) {
      if (createPlaylist) {
        await _setupPlaylist(surahSource);
      } else {
        await _setupSingleAudio(surahSource);
      }
      _savedPosition = null;
    }
  }

  static Future<void> _setupPlaylist(dynamic surahSource) async {
    final playlist = ConcatenatingAudioSource(
      children: (surahSource as List).map((source) {
        if (source is String) {
          return AudioSource.uri(Uri.parse(source));
        } else if (source is AudioSource) {
          return source;
        }
        throw ArgumentError('Invalid source type: ${source.runtimeType}');
      }).toList(),
    );
    await _audioPlayer?.setAudioSource(playlist);
    await _audioPlayer?.setLoopMode(LoopMode.all);
  }

  static Future<void> _setupSingleAudio(dynamic surahSource) async {
    final source = surahSource is String ? AudioSource.uri(Uri.parse(surahSource)) : surahSource as AudioSource;
    await _audioPlayer?.setAudioSource(source);
    await _audioPlayer?.setLoopMode(LoopMode.one);
  }

  static Future<void> _startPlayback(bool createPlaylist) async {
    await _audioPlayer?.play();

    // Cancel existing subscriptions before creating new ones
    await _playbackEventSubscription?.cancel();
    await _playerStateSubscription?.cancel();

    _playbackEventSubscription = _audioPlayer?.playbackEventStream.listen((event) {
      if (event.processingState == ProcessingState.completed && !createPlaylist) {
        _audioPlayer?.seek(Duration.zero);
        _audioPlayer?.play();
        _savedPosition = null;
        FlutterBackgroundService().invoke('kAudioStateChanged', {'isPlaying': true});
      }
    });

    _playerStateSubscription = _audioPlayer?.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      FlutterBackgroundService().invoke('kAudioStateChanged', {'isPlaying': isPlaying});
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      Hive.init(appDocDir.path);
      print('✅ Hive initialized in background service at: ${appDocDir.path}');
    } catch (e) {
      print('⚠️ Failed to initialize Hive in background service: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('language_code') ?? 'en';
    final locale = Locale(langCode);

    final localizations = await AppLocalizations.delegate.load(locale);

    S.setCurrent(localizations);

    _setupServiceListeners(service);
    _setupPeriodicScheduleCheck(service);
  }

  static void _setupServiceListeners(ServiceInstance service) {
    // Clear existing subscriptions before setting up new ones
    _cleanupEventSubscriptions();

    bool isPaused = false;
    bool shouldShowNotification = _shouldShowNotification;

    if (service is AndroidServiceInstance) {
      _eventSubscriptions.add(
        service.on('setAsForeground').listen((_) => service.setAsForegroundService()),
      );
      _eventSubscriptions.add(
        service.on('setAsBackground').listen((_) => service.setAsBackgroundService()),
      );
    }
    _eventSubscriptions.add(
      service.on('updateLocalization').listen((event) async {
        if (event != null && event.containsKey('language_code')) {
          final langCode = event['language_code'];
          final locale = Locale(langCode);

          final localizations = await AppLocalizations.delegate.load(locale);
          S.setCurrent(localizations);
        }
      }),
    );
    // Notification-related listeners
    _eventSubscriptions.add(
      service.on('stopService').listen((_) async {
        await _cleanupAllResources();
        service.stopSelf();
      }),
    );
    _eventSubscriptions.add(
      service.on('updateNotificationVisibility').listen((event) {
        if (event?['shouldShow'] != null) {
          shouldShowNotification = event!['shouldShow'] as bool;
        }
      }),
    );
    _eventSubscriptions.add(
      service.on('pauseOperations').listen((_) {
        isPaused = true;
        PrayerAudioService.stopAudio();
        NotificationService.dismissNotification();
      }),
    );
    _eventSubscriptions.add(
      service.on('resumeOperations').listen((_) => isPaused = false),
    );
    _eventSubscriptions.add(
      service.on('prayerTime').listen((event) async {
        print("called service prayerTime $shouldShowNotification");

        if (event != null && !isPaused && shouldShowNotification) {
          await _handlePrayerTime(event);
        }
      }),
    );

    // Audio-related listeners
    _eventSubscriptions.add(
      service.on('update_schedule').listen((_) async {
        await ScheduleManager.checkSchedule();
      }),
    );
    _eventSubscriptions.add(
      service.on('restart_schedule').listen((_) async {
        if (isPlaying()) {
          await stopPlayback();
        }
        _audioPlayer?.dispose();
        _audioPlayer = null;
        await ScheduleManager.checkSchedule();
      }),
    );
    _eventSubscriptions.add(
      service.on('kStopAudio').listen((_) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(BackgroundScheduleAudioServiceConstant.kManualPause, true);
        await stopPlayback();
        service.invoke('kAudioStateChanged', {'isPlaying': false});
      }),
    );
    _eventSubscriptions.add(
      service.on('kGetPlaybackState').listen((_) async {
        service.invoke('kAudioStateChanged', {'isPlaying': isPlaying()});
      }),
    );
    _eventSubscriptions.add(
      service.on('kResumeAudio').listen((_) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(BackgroundScheduleAudioServiceConstant.kManualPause, false);
        if (isPlaying()) {
          await player?.play();
          service.invoke('kAudioStateChanged', {'isPlaying': true});
        } else {
          await ScheduleManager.checkSchedule();
        }
      }),
    );
  }

  /// Cleanup all event subscriptions
  static void _cleanupEventSubscriptions() {
    for (var subscription in _eventSubscriptions) {
      subscription.cancel();
    }
    _eventSubscriptions.clear();
  }

  /// Cleanup all resources (timers, subscriptions, audio player)
  static Future<void> _cleanupAllResources() async {
    _cleanupEventSubscriptions();
    await _playbackEventSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    _scheduleCheckTimer?.cancel();
    await _audioPlayer?.dispose();
    _playbackEventSubscription = null;
    _playerStateSubscription = null;
    _scheduleCheckTimer = null;
    _audioPlayer = null;
  }

  static void _setupPeriodicScheduleCheck(ServiceInstance service) {
    // Cancel existing timer before creating a new one
    _scheduleCheckTimer?.cancel();

    _scheduleCheckTimer = Timer.periodic(Duration(minutes: 1), (timer) async {
      print("Checking schedule: ${DateTime.now()}");
      await ScheduleManager.checkSchedule();
    });
  }

  static Future<void> _handlePrayerTime(Map<dynamic, dynamic> event) async {
    final prayerName = event['prayer'] as String;
    final shouldPlayAdhan = event['shouldPlayAdhan'] as bool;
    final adhanAsset = event['adhanAsset'] as String;
    final adhanFromAssets = event['adhanFromAssets'] as bool;
    final salahName = event['salahName'] as String;
    print("called service prayerTime $salahName $prayerName");

    await NotificationService.showPrayerNotification(salahName, prayerName, shouldPlayAdhan);

    if (shouldPlayAdhan) {
      try {
        await PrayerAudioService.playPrayer(adhanAsset, adhanFromAssets);
        print("Prayer audio played successfully for $salahName");
      } catch (e) {
        print("Failed to play prayer audio for $salahName: $e");
        // If audio fails, still show notification
      }
    }
  }
}

/// Schedule management class
class ScheduleManager {
  static Future<void> checkSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final isManuallyPaused = prefs.getBool(BackgroundScheduleAudioServiceConstant.kManualPause) ?? false;
    final isScheduleEnabled = prefs.getBool(BackgroundScheduleAudioServiceConstant.kScheduleEnabled) ?? false;
    final isPendingSchedule = prefs.getBool(BackgroundScheduleAudioServiceConstant.kPendingSchedule) ?? false;

    if (!isScheduleEnabled || isPendingSchedule) {
      if (UnifiedBackgroundService.isPlaying()) {
        await UnifiedBackgroundService.stopPlayback();
        FlutterBackgroundService().invoke('kAudioStateChanged', {'isPlaying': false});
      }
      return;
    }

    final scheduleData = await _getScheduleData(prefs);
    if (scheduleData == null) return;

    final currentTime = TimeOfDay.now();
    final isInTimeRange = _isTimeInRange(currentTime, scheduleData.startTime, scheduleData.endTime);

    if (isInTimeRange && !isManuallyPaused) {
      if (UnifiedBackgroundService.isPlaying()) {
        await UnifiedBackgroundService.stopPlayback();
      }
      await _startScheduledPlayback(scheduleData);
      FlutterBackgroundService().invoke('kAudioStateChanged', {'isPlaying': true});
    } else if (!isInTimeRange) {
      if (UnifiedBackgroundService.isPlaying()) {
        await UnifiedBackgroundService.stopPlayback();
        FlutterBackgroundService().invoke('kAudioStateChanged', {'isPlaying': false});
      }
      await prefs.setBool(BackgroundScheduleAudioServiceConstant.kManualPause, false);
    }
  }

  static Future<ScheduleData?> _getScheduleData(SharedPreferences prefs) async {
    final startTimeString = prefs.getString(BackgroundScheduleAudioServiceConstant.kStartTime);
    final endTimeString = prefs.getString(BackgroundScheduleAudioServiceConstant.kEndTime);

    if (startTimeString == null || endTimeString == null) return null;

    return ScheduleData(
      startTime: _parseTimeOfDay(startTimeString),
      endTime: _parseTimeOfDay(endTimeString),
      isRandomEnabled: prefs.getBool(BackgroundScheduleAudioServiceConstant.kRandomEnabled) ?? false,
      randomUrls: prefs.getStringList(BackgroundScheduleAudioServiceConstant.kRandomUrls),
      selectedSurah: prefs.getInt(BackgroundScheduleAudioServiceConstant.kSelectedSurah) ?? 0,
      selectedSurahUrl: prefs.getString(BackgroundScheduleAudioServiceConstant.kSelectedSurahUrl),
    );
  }

  static Future<void> _startScheduledPlayback(ScheduleData scheduleData) async {
    final service = FlutterBackgroundService();

    try {
      if (scheduleData.isRandomEnabled && scheduleData.randomUrls != null) {
        await UnifiedBackgroundService.playAudio(scheduleData.randomUrls, createPlaylist: true);
      } else if (scheduleData.selectedSurahUrl != null) {
        final surahIdStr = scheduleData.selectedSurah.toString().padLeft(3, '0');
        final surahUrl = "${scheduleData.selectedSurahUrl}$surahIdStr.mp3";
        await UnifiedBackgroundService.playAudio(surahUrl);
      }

      service.invoke('kAudioStateChanged', {'isPlaying': true});
    } catch (e) {
      print('Error starting scheduled playback: $e');
      service.invoke('kAudioStateChanged', {'isPlaying': false});
    }
  }

  static TimeOfDay _parseTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final now = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      return now >= startMinutes && now < endMinutes;
    }
    return now >= startMinutes || now < endMinutes;
  }
}

/// Data class for schedule information
class ScheduleData {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isRandomEnabled;
  final List<String>? randomUrls;
  final int selectedSurah;
  final String? selectedSurahUrl;

  ScheduleData({
    required this.startTime,
    required this.endTime,
    required this.isRandomEnabled,
    this.randomUrls,
    required this.selectedSurah,
    this.selectedSurahUrl,
  });
}
