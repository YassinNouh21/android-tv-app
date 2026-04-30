import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mawaqit/src/const/constants.dart';
import 'package:mawaqit/src/domain/model/quran/moshaf_model.dart';
import 'package:mawaqit/src/domain/model/quran/surah_model.dart';
import 'package:mawaqit/src/state_management/quran/recite/quran_audio_player_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mawaqit/src/data/repository/quran/recite_impl.dart';
import 'package:mawaqit/src/domain/model/quran/audio_file_model.dart';
import 'package:mawaqit/src/helpers/connectivity_provider.dart';
import 'package:mawaqit/src/models/address_model.dart';
import 'package:mawaqit/src/state_management/quran/recite/download_audio_quran/download_audio_quran_notifier.dart';
import 'package:mawaqit/src/state_management/quran/recite/download_audio_quran/download_audio_quran_state.dart';

class QuranAudioPlayer extends AsyncNotifier<QuranAudioPlayerState> {
  final AudioPlayer audioPlayer = AudioPlayer();
  ConcatenatingAudioSource playlist = ConcatenatingAudioSource(children: []);
  int index = 0;
  List<SurahModel> localSuwar = [];
  late StreamSubscription<int?> currentIndexSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  // Persisted session context
  String _sessionReciterId = ''; // ignore: prefer_final_fields
  String _sessionMoshafId = ''; // ignore: prefer_final_fields

  Future<void> _savePlaybackSession() async {
    final currentIndex = audioPlayer.currentIndex ?? 0;
    if (localSuwar.isEmpty || currentIndex >= localSuwar.length) return;
    final surah = localSuwar[currentIndex];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(QuranConstant.kLastPlayedReciterId, _sessionReciterId);
    await prefs.setString(QuranConstant.kLastPlayedMoshafId, _sessionMoshafId);
    await prefs.setInt(QuranConstant.kLastPlayedSurahId, surah.id);
    await prefs.setInt(QuranConstant.kLastPlayedPositionMs, audioPlayer.position.inMilliseconds);
    await prefs.setString(QuranConstant.kLastPlayedSurahJson, jsonEncode(surah.toJson()));
    log('quran: QuranAudioPlayer: saved session surah=${surah.id} pos=${audioPlayer.position.inMilliseconds}ms');
  }

  static Future<Map<String, dynamic>?> getLastPlaybackSession() async {
    final prefs = await SharedPreferences.getInstance();
    final reciterId = prefs.getString(QuranConstant.kLastPlayedReciterId);
    final moshafId = prefs.getString(QuranConstant.kLastPlayedMoshafId);
    final surahId = prefs.getInt(QuranConstant.kLastPlayedSurahId);
    final positionMs = prefs.getInt(QuranConstant.kLastPlayedPositionMs);
    final surahJson = prefs.getString(QuranConstant.kLastPlayedSurahJson);
    if (reciterId == null || moshafId == null || surahId == null || surahJson == null) return null;
    return {
      'reciterId': reciterId,
      'moshafId': moshafId,
      'surahId': surahId,
      'positionMs': positionMs ?? 0,
      'surahJson': surahJson,
    };
  }

  static Future<void> clearLastPlaybackSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(QuranConstant.kLastPlayedReciterId);
    await prefs.remove(QuranConstant.kLastPlayedMoshafId);
    await prefs.remove(QuranConstant.kLastPlayedSurahId);
    await prefs.remove(QuranConstant.kLastPlayedPositionMs);
    await prefs.remove(QuranConstant.kLastPlayedSurahJson);
  }

  @override
  QuranAudioPlayerState build() {
    ref.onDispose(() {
      audioPlayer.dispose();
      currentIndexSubscription.cancel();
      _playerStateSubscription?.cancel();
      log('quran: QuranAudioPlayer: disposed');
    });
    log('quran: QuranAudioPlayer: build');

    return QuranAudioPlayerState(
      playerState: AudioPlayerState.stopped,
      audioPlayer: audioPlayer,
      position: Duration.zero,
      reciterName: '',
      surahName: '',
      arabicSurahName: '',
    );
  }

  Future<void> downloadAudio({
    required String reciterId,
    required String moshafId,
    required int surahId,
    required String url,
  }) async {
    final audioRepository = await ref.read(reciteImplProvider.future);
    final audioFileModel = AudioFileModel(
      reciterId,
      moshafId,
      surahId.toString(),
      url,
    );

    final downloadStateNotifier = ref.read(
      downloadStateProvider(
        DownloadStateProviderParameter(reciterId: reciterId, moshafId: moshafId),
      ).notifier,
    );

    downloadStateNotifier.updateDownloadProgress(surahId, 0);

    try {
      await audioRepository.downloadAudio(audioFileModel, (progress) {
        downloadStateNotifier.updateDownloadProgress(surahId, progress / 100);
      });

      downloadStateNotifier.markAsDownloaded(surahId);

      await getDownloadedSuwarByReciterAndRiwayah(
        moshafId: moshafId,
        reciterId: reciterId,
      );

      // Swap source to local file if this surah is NOT currently playing
      await _swapToLocalSourceIfNotPlaying(
        surahId: surahId,
        reciterId: reciterId,
        moshafId: moshafId,
      );
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> _swapToLocalSourceIfNotPlaying({
    required int surahId,
    required String reciterId,
    required String moshafId,
  }) async {
    final currentIndex = audioPlayer.currentIndex;
    final surahIndex = localSuwar.indexWhere((s) => s.id == surahId);

    // Only swap if surah is in playlist and NOT currently playing
    if (surahIndex != -1 && surahIndex != currentIndex) {
      try {
        final audioRepository = await ref.read(reciteImplProvider.future);
        final localPath = await audioRepository.getLocalSurahPath(
          reciterId: reciterId,
          surahNumber: surahId.toString(),
          moshafId: moshafId,
        );

        // Remove old remote source and insert local source at same position
        await playlist.removeAt(surahIndex);
        await playlist.insert(surahIndex, AudioSource.uri(Uri.file(localPath)));

        log('quran: Swapped surah $surahId to local file: $localPath');
      } catch (e) {
        log('quran: Failed to swap surah $surahId to local: $e');
        // Non-fatal: surah will still work from remote or next session
      }
    }
  }

  Future<void> _updatePlayerState() async {
    final index = audioPlayer.currentIndex ?? 0;
    final position = audioPlayer.position;

    if (index < localSuwar.length) {
      state = AsyncData(
        state.value!.copyWith(
          surahName: localSuwar[index].name,
          arabicSurahName: localSuwar[index].arabicName,
          playerState: audioPlayer.playing ? AudioPlayerState.playing : AudioPlayerState.paused,
          position: position,
        ),
      );
    }
  }

  Future<int> _downloadAllSuwar(
    List<SurahModel> suwar,
    String reciterId,
    String moshafId,
    String server,
  ) async {
    final downloadStateNotifier = ref.read(
      downloadStateProvider(
        DownloadStateProviderParameter(reciterId: reciterId, moshafId: moshafId),
      ).notifier,
    );

    int downloadedCount = 0;
    for (final surah in suwar) {
      final downloadState = ref.read(
        downloadStateProvider(
          DownloadStateProviderParameter(reciterId: reciterId, moshafId: moshafId),
        ),
      );
      if (!downloadState.downloadedSuwar.contains(surah.id)) {
        downloadStateNotifier.setDownloadStatus(DownloadStatus.downloading);
        await downloadAudio(
          reciterId: reciterId,
          moshafId: moshafId,
          surahId: surah.id,
          url: surah.getSurahUrl(server),
        );
        downloadedCount++;
      }
    }
    return downloadedCount;
  }

  Future<void> downloadAllSuwar({
    required String reciterId,
    required String moshafId,
    required MoshafModel moshaf,
    required List<SurahModel> suwar,
  }) async {
    try {
      state = AsyncLoading();
      final downloadedCount = await _downloadAllSuwar(
        suwar,
        reciterId,
        moshafId,
        moshaf.server,
      );
      state = AsyncData(state.value!);

      final downloadStateNotifier = ref.read(
        downloadStateProvider(
          DownloadStateProviderParameter(reciterId: reciterId, moshafId: moshafId),
        ).notifier,
      );

      if (downloadedCount > 0) {
        downloadStateNotifier.setDownloadStatus(DownloadStatus.completed);
      } else {
        downloadStateNotifier.setDownloadStatus(DownloadStatus.noNewDownloads);
      }
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> getDownloadedSuwarByReciterAndRiwayah({
    required String reciterId,
    required String moshafId,
  }) async {
    final audioRepository = await ref.read(reciteImplProvider.future);
    try {
      final downloadedAudioList = await audioRepository.getDownloadedSuwarByReciterAndRiwayah(
        reciterId: reciterId,
        moshafId: moshafId,
      );

      final downloadedSurahIds =
          downloadedAudioList.map((file) => int.parse(file.path.split('/').last.split('.').first)).toSet();

      final downloadStateNotifier = ref.read(
        downloadStateProvider(
          DownloadStateProviderParameter(reciterId: reciterId, moshafId: moshafId),
        ).notifier,
      );

      downloadStateNotifier.initializeDownloadedSuwar(downloadedSurahIds);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  void initialize({
    required MoshafModel moshaf,
    required SurahModel surah,
    required List<SurahModel> suwar,
    required String reciterId,
  }) async {
    try {
      _sessionReciterId = reciterId;
      _sessionMoshafId = moshaf.id.toString();

      final audioRepository = await ref.read(reciteImplProvider.future);
      List<AudioSource> audioSources = [];
      localSuwar = [];

      for (var s in suwar) {
        bool isDownloaded = await audioRepository.isSurahDownloaded(
          reciterId: reciterId,
          moshafId: moshaf.id.toString(),
          surahNumber: s.id,
        );

        if (isDownloaded) {
          String localPath = await audioRepository.getLocalSurahPath(
            reciterId: reciterId,
            surahNumber: s.id.toString(),
            moshafId: moshaf.id.toString(),
          );
          audioSources.add(AudioSource.uri(Uri.file(localPath)));
          localSuwar.add(s);
          log('quran: QuranAudioPlayer: isDownloaded: ${s.name}, path: $localPath');
        } else if (ref.read(connectivityProvider).hasValue &&
            ref.read(connectivityProvider).value == ConnectivityStatus.connected) {
          audioSources.add(AudioSource.uri(Uri.parse(s.getSurahUrl(moshaf.server))));
          localSuwar.add(s);
          log('quran: QuranAudioPlayer: isOnline: ${s.name}, url: ${s.getSurahUrl(moshaf.server)}');
        }
      }

      if (audioSources.isEmpty) {
        throw Exception('No audio sources available');
      }

      playlist.clear();
      playlist.addAll(audioSources);
      index = localSuwar.indexOf(surah);

      // Check for a saved playback position for this exact surah/reciter/moshaf
      Duration initialPosition = Duration.zero;
      final savedSession = await getLastPlaybackSession();
      if (savedSession != null &&
          savedSession['reciterId'] == reciterId &&
          savedSession['moshafId'] == moshaf.id.toString() &&
          savedSession['surahId'] == surah.id) {
        initialPosition = Duration(milliseconds: savedSession['positionMs'] as int);
        log('quran: QuranAudioPlayer: restoring position ${initialPosition.inSeconds}s for surah ${surah.id}');
      }

      await audioPlayer.setAudioSource(playlist, initialIndex: index, initialPosition: initialPosition);

      currentIndexSubscription = audioPlayer.currentIndexStream.listen((index) {
        log('quran: QuranAudioPlayer: currentIndexStream called');
        _savePlaybackSession();
        _updatePlayerState();
      });

      // Cancel existing subscription before creating a new one
      await _playerStateSubscription?.cancel();
      _playerStateSubscription = audioPlayer.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          clearLastPlaybackSession();
        }
        _updatePlayerState();
      });

      state = AsyncData(
        state.value!.copyWith(
          surahName: surah.name,
          arabicSurahName: surah.arabicName,
          reciterName: moshaf.name,
        ),
      );
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> play() async {
    state = AsyncData(
      state.value!.copyWith(
        playerState: AudioPlayerState.playing,
      ),
    );
    await audioPlayer.play();
  }

  Future<void> pause() async {
    state = AsyncData(
      state.value!.copyWith(
        playerState: AudioPlayerState.paused,
      ),
    );
    await audioPlayer.pause();
    await _savePlaybackSession();
  }

  Future<void> stop() async {
    await audioPlayer.stop();
    state = AsyncData(
      state.value!.copyWith(
        playerState: AudioPlayerState.stopped,
      ),
    );
  }

  Future<void> saveAndStop() async {
    await _savePlaybackSession();
    await stop();
  }

  Future<void> seekTo(Duration position) async {
    try {
      await audioPlayer.seek(position);
      state = AsyncData(
        state.value!.copyWith(
          position: position,
        ),
      );
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  void dispose() {
    audioPlayer.dispose();
    state = AsyncData(
      state.value!.copyWith(
        playerState: AudioPlayerState.stopped,
      ),
    );
  }

  Future<void> seekToNext() async {
    try {
      await audioPlayer.seekToNext();
      log('quran: QuranAudioPlayer: seekToNext called');
    } catch (e, s) {
      log('quran: QuranAudioPlayer: seekToNext error: $e');
      state = AsyncError(e, s);
    }
  }

  Future<void> seekToPrevious() async {
    try {
      await audioPlayer.seekToPrevious();
      log('quran: QuranAudioPlayer: seekToPrevious called');
    } catch (e, s) {
      log('quran: QuranAudioPlayer: seekToPrevious error: $e');
      state = AsyncError(e, s);
    }
  }

  Future<void> shuffle() async {
    state = await AsyncValue.guard(() async {
      final bool isShuffled = !state.value!.isShuffled;
      await audioPlayer.setShuffleModeEnabled(isShuffled);

      // Disable repeat when enabling shuffle
      if (isShuffled) {
        await audioPlayer.setLoopMode(LoopMode.off);
      }

      return state.value!.copyWith(
        isShuffled: isShuffled,
        isRepeating: isShuffled ? false : state.value!.isRepeating,
      );
    });
  }

  Future<void> repeat() async {
    state = await AsyncValue.guard(() async {
      final isRepeating = !state.value!.isRepeating;

      // Disable shuffle when enabling repeat
      if (isRepeating) {
        await audioPlayer.setShuffleModeEnabled(false);
        await audioPlayer.setLoopMode(LoopMode.one);
      } else {
        await audioPlayer.setLoopMode(LoopMode.off);
      }

      return state.value!.copyWith(
        isRepeating: isRepeating,
        isShuffled: isRepeating ? false : state.value!.isShuffled,
      );
    });
  }

  Future<void> toggleVolume() async {
    state = await AsyncValue.guard(() async {
      await Future.delayed(Duration(seconds: 1));
      return state.value!.copyWith(isVolumeOpened: !state.value!.isVolumeOpened);
    });
  }

  Future<void> closeVolume() async {
    state = await AsyncValue.guard(() async {
      await Future.delayed(Duration(seconds: 0));
      return state.value!.copyWith(isVolumeOpened: false);
    });
  }

  Future<void> resetIsVolumeOpened() async {
    state = await AsyncValue.guard(() async {
      return state.value!.copyWith(isVolumeOpened: false);
    });
  }

  Future<void> setVolume(double volume) async {
    if (volume < 0.0) volume = 0.0;
    if (volume > 1.0) volume = 1.0;

    await audioPlayer.setVolume(volume);
    state = AsyncData(
      state.value!.copyWith(
        volume: volume,
      ),
    );
  }

  Future<void> increaseVolume() async {
    final newVolume = (state.value!.volume + 0.1).clamp(0.0, 1.0);
    await setVolume(newVolume);
  }

  Future<void> decreaseVolume() async {
    final newVolume = (state.value!.volume - 0.1).clamp(0.0, 1.0);
    await setVolume(newVolume);
  }

  Stream<Duration> get positionStream => audioPlayer.positionStream;
}

final quranPlayerNotifierProvider =
    AsyncNotifierProvider<QuranAudioPlayer, QuranAudioPlayerState>(QuranAudioPlayer.new);
