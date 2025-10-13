// prayer_audio_service.dart
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mawaqit/src/services/notification/notification_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'dart:developer';
import 'package:path_provider/path_provider.dart';

class PrayerAudioService {
  static AudioPlayer? _audioPlayer;
  static final _dio = Dio();

  static Future<void> playPrayer(String adhanAsset, bool adhanFromAssets) async {
    _audioPlayer = AudioPlayer();
    final session = await _configureAudioSession();
    await session.setActive(true);
    await _audioPlayer?.setVolume(1);

    try {
      if (adhanFromAssets) {
        await _audioPlayer?.setAsset(adhanAsset);
        Future.delayed(const Duration(minutes: 1), () {
          NotificationService.dismissNotification();
        });
      } else {
        await _loadAudioFromCacheOrUrl(adhanAsset);
      }

      await _audioPlayer?.play();

      _audioPlayer?.playbackEventStream.listen((event) {
        if (event.processingState == ProcessingState.completed) {
          session.setActive(false);
          if (!adhanFromAssets) {
            NotificationService.dismissNotification();
          }
        }
      });
    } catch (e) {
      log('❌ Prayer audio service error: $e');
      await session.setActive(false);
      rethrow;
    }
  }

  /// Load audio from cache first, only download if not cached
  static Future<void> _loadAudioFromCacheOrUrl(String url) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = url.split('/').last;
      final cacheFile = File('${tempDir.path}/audio_$fileName');

      // Check if file exists in cache
      if (await cacheFile.exists()) {
        log('📦 Loading prayer audio from cache: ${cacheFile.path}');
        final bytes = await cacheFile.readAsBytes();
        final audioData = Uint8List.fromList(bytes).buffer.asByteData();
        final source = JustAudioBytesSource(audioData);
        await _audioPlayer?.setAudioSource(source);
        log('✅ Prayer audio loaded from cache successfully');
        return;
      }

      // File not in cache, try to download
      log('⬇️ Cache miss, downloading prayer audio from network: $url');
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data == null) {
        throw Exception('No data received from server');
      }

      // Save to cache for next time
      await cacheFile.writeAsBytes(response.data!);
      log('💾 Prayer audio cached to: ${cacheFile.path}');

      // Play the downloaded audio
      final audioData = Uint8List.fromList(response.data!).buffer.asByteData();
      final source = JustAudioBytesSource(audioData);
      await _audioPlayer?.setAudioSource(source);
      log('✅ Prayer audio loaded from network successfully');
    } catch (e) {
      log('❌ Failed to load audio: $e');
      throw Exception('Failed to load prayer audio - device may be offline and audio not cached');
    }
  }

  static Future<void> stopAudio() async {
    await _audioPlayer?.stop();
    await _audioPlayer?.dispose();
    _audioPlayer = null;
  }

  static Future<AudioSession> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.audibilityEnforced,
        usage: AndroidAudioUsage.alarm,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
    return session;
  }
}

// Helper class for audio data source
class JustAudioBytesSource extends StreamAudioSource {
  final ByteData _buffer;

  JustAudioBytesSource(this._buffer);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _buffer.lengthInBytes;
    return StreamAudioResponse(
      sourceLength: _buffer.lengthInBytes,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_buffer.buffer.asUint8List(start, end - start)),
      contentType: 'audio/mpeg',
    );
  }
}
