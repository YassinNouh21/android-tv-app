import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/src/helpers/CrashlyticsWrapper.dart';
import 'package:mawaqit/src/const/constants.dart';
import 'package:mawaqit/src/domain/error/live_stream_exceptions.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:mawaqit/src/helpers/live_stream/rtsp_stream_helper.dart';
import 'package:mawaqit/src/helpers/live_stream/youtube_stream_helper.dart';
import 'package:mawaqit/src/state_management/livestream_viewer/live_stream_state.dart';

/// Notifier for the livestream viewer feature
class LiveStreamNotifier extends AsyncNotifier<LiveStreamViewerState> {
  /// Helper for YouTube streams
  final _youtubeHelper = YouTubeStreamHelper();

  /// Helper for RTSP streams
  final _rtspHelper = RTSPStreamHelper();

  /// Timer for stream reconnection attempts
  Timer? _reconnectTimer;

  /// Timer for periodic stream status monitoring
  Timer? _statusCheckTimer;

  /// Whether we're using extended interval for server unavailable
  bool _usingExtendedReconnectInterval = false;

  /// Timestamp for buffering start time
  int? _bufferingStartTime;

  /// Controller for RTSP video
  VideoController? _videoController;

  /// Controller for YouTube video
  YoutubePlayerController? _youtubeController;

  /// Public getter for video controller
  VideoController? get videoController => _videoController;

  /// Public getter for youtube controller
  YoutubePlayerController? get youtubeController => _youtubeController;

  @override
  Future<LiveStreamViewerState> build() async {
    dev.log('🏗️ [LIVE_STREAM] Building LiveStream Notifier');

    // Setup cleanup when notifier is disposed
    ref.onDispose(() async {
      dev.log('🧹 [LIVE_STREAM] Provider disposed, cleaning up');
      _stopReconnectTimer();
      _stopStatusCheckTimer();
      await _dispose();
    });

    final settings = await _initializeSettings();

    // Start status monitoring if stream is active during initialization
    if (settings.streamStatus == LiveStreamStatus.active) {
      dev.log('🔄 [LIVE_STREAM] Starting status monitoring for active stream during build');
      _startStatusCheckTimer();
    }

    return settings;
  }

  /// Dispose all resources
  Future<void> _dispose() async {
    try {
      dev.log('🧹 [LIVE_STREAM] Starting disposal of controllers');

      // Stop all timers first
      _stopReconnectTimer();
      _stopStatusCheckTimer();

      // Clear controllers from notifier BEFORE disposing to prevent widget access
      _youtubeController = null;
      _videoController = null;

      if (state.hasValue) {
        state = AsyncValue.data(
          state.value!.copyWith(
            streamStatus: LiveStreamStatus.idle,
          ),
        );
        dev.log('🔄 [LIVE_STREAM] Cleared controllers from notifier');

        // Give widgets time to rebuild with null controllers
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Now safely dispose helpers
      await _youtubeHelper.dispose();
      await _rtspHelper.dispose();

      dev.log('🧹 [LIVE_STREAM] Controllers disposed successfully');
    } catch (e) {
      dev.log('🚨 [LIVE_STREAM] Error in controller disposal: $e');
    }
  }

  /// Initialize settings from SharedPreferences
  Future<LiveStreamViewerState> _initializeSettings() async {
    try {
      dev.log('⚙️ [LIVE_STREAM] Initializing settings from SharedPreferences');
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(LiveStreamConstants.prefKeyEnabled) ?? false;
      final savedUrl = prefs.getString(LiveStreamConstants.prefKeyUrl);
      final backofficeUrl = prefs.getString(LiveStreamConstants.prefKeyBackofficeUrl);
      final useBackofficeStream = prefs.getBool(LiveStreamConstants.prefKeyUseBackofficeStream) ?? false;
      final replaceWorkflow = prefs.getBool(LiveStreamConstants.prefKeyReplaceWorkflow) ?? false;
      final autoReplaceWorkflow = prefs.getBool(LiveStreamConstants.prefKeyAutoReplaceWorkflow) ?? true;

      // Determine effective URL based on toggle
      final effectiveUrl =
          (useBackofficeStream && backofficeUrl != null && backofficeUrl.isNotEmpty) ? backofficeUrl : savedUrl;

      dev.log(
        '📊 [LIVE_STREAM] Loaded settings - Enabled: $isEnabled, URL: $effectiveUrl, UseBackoffice: $useBackofficeStream, ReplaceWorkflow: $replaceWorkflow',
      );

      if (!isEnabled || effectiveUrl == null || effectiveUrl.isEmpty) {
        dev.log('[LIVE_STREAM] No saved settings found, returning default state');
        return LiveStreamViewerState(
          isEnabled: isEnabled,
          streamUrl: savedUrl,
          backofficeStreamUrl: backofficeUrl,
          useBackofficeStream: useBackofficeStream,
          isInvalidUrl: false,
          replaceWorkflow: replaceWorkflow,
          autoReplaceWorkflow: autoReplaceWorkflow,
        );
      }

      return await _initializeFromSavedUrl(
        isEnabled: isEnabled,
        url: effectiveUrl,
        savedUrl: savedUrl,
        backofficeUrl: backofficeUrl,
        useBackofficeStream: useBackofficeStream,
        replaceWorkflow: replaceWorkflow,
      );
    } catch (e) {
      dev.log('🚨 [LIVE_STREAM] Error initializing settings: $e');
      throw LiveStreamInitializationException(e.toString());
    }
  }

  /// Initialize from saved URL
  Future<LiveStreamViewerState> _initializeFromSavedUrl({
    required bool isEnabled,
    required String url,
    String? savedUrl,
    String? backofficeUrl,
    bool useBackofficeStream = false,
    bool? replaceWorkflow,
  }) async {
    try {
      dev.log('🔄 [LIVE_STREAM] Initializing from saved URL: $url');

      // Clean up any existing resources first
      _stopReconnectTimer();
      _stopStatusCheckTimer();
      await _dispose();

      // Determine the stream type and initialize accordingly
      if (LiveStreamConstants.youtubeUrlRegex.hasMatch(url)) {
        dev.log('🎥 [LIVE_STREAM] Detected YouTube URL, handling YouTube stream');
        final videoWithString = await _handleYoutubeStream(url);

        // Set controllers in notifier
        _youtubeController = videoWithString.$1;
        _videoController = null;

        final newState = LiveStreamViewerState(
          isEnabled: isEnabled,
          streamUrl: useBackofficeStream ? savedUrl : videoWithString.$2,
          backofficeStreamUrl: backofficeUrl,
          useBackofficeStream: useBackofficeStream,
          streamStatus: LiveStreamStatus.active,
          streamType: LiveStreamType.youtubeLive,
          isInvalidUrl: false,
          replaceWorkflow: replaceWorkflow ?? false,
          autoReplaceWorkflow: true,
        );

        // Start status monitoring for active stream
        _startStatusCheckTimer();

        return newState;
      } else if (url.startsWith('rtsp://')) {
        dev.log('🎬 [LIVE_STREAM] Detected RTSP URL, handling RTSP stream');
        try {
          // Don't skip server check during manual initialization
          final controller = await _handleRtspStream(url, skipServerCheck: false);

          // Set controllers in notifier
          _videoController = controller;
          _youtubeController = null;

          final newState = LiveStreamViewerState(
            isEnabled: isEnabled,
            streamUrl: useBackofficeStream ? savedUrl : url,
            backofficeStreamUrl: backofficeUrl,
            useBackofficeStream: useBackofficeStream,
            streamStatus: LiveStreamStatus.active,
            streamType: LiveStreamType.rtsp,
            isInvalidUrl: false,
            replaceWorkflow: replaceWorkflow ?? false,
            autoReplaceWorkflow: true,
          );

          dev.log('[LIVE_STREAM] RTSP stream initialized successfully with active status');

          // Start status monitoring for active stream
          _startStatusCheckTimer();

          return newState;
        } catch (e) {
          dev.log('[LIVE_STREAM] RTSP stream failed during initialization: $e');

          // Clear controllers on failure
          _videoController = null;
          _youtubeController = null;

          // Return idle state instead of throwing, so user can try again
          return LiveStreamViewerState(
            isEnabled: isEnabled,
            streamUrl: useBackofficeStream ? savedUrl : url,
            backofficeStreamUrl: backofficeUrl,
            useBackofficeStream: useBackofficeStream,
            streamStatus: LiveStreamStatus.idle,
            streamType: LiveStreamType.rtsp,
            isInvalidUrl: false,
            replaceWorkflow: replaceWorkflow ?? false,
            autoReplaceWorkflow: true,
          );
        }
      } else {
        dev.log('🚨 [LIVE_STREAM] Invalid URL format: $url');
        throw InvalidStreamUrlException('Invalid URL format: $url');
      }
    } catch (e) {
      dev.log('[LIVE_STREAM] Error initializing from saved URL: $e');
      if (e is InvalidStreamUrlException) {
        return LiveStreamViewerState(
          isEnabled: isEnabled,
          streamUrl: useBackofficeStream ? savedUrl : url,
          backofficeStreamUrl: backofficeUrl,
          useBackofficeStream: useBackofficeStream,
          isInvalidUrl: true,
          replaceWorkflow: replaceWorkflow ?? false,
          autoReplaceWorkflow: true,
          streamStatus: LiveStreamStatus.idle,
        );
      }
      return LiveStreamViewerState(
        isEnabled: isEnabled,
        streamUrl: useBackofficeStream ? savedUrl : url,
        backofficeStreamUrl: backofficeUrl,
        useBackofficeStream: useBackofficeStream,
        replaceWorkflow: replaceWorkflow ?? false,
        autoReplaceWorkflow: true,
        streamStatus: LiveStreamStatus.idle,
      );
    }
  }

  /// Toggle livestream enabled state
  Future<void> toggleEnabled(bool isEnabled) async {
    dev.log('🔌 [LIVE_STREAM] Toggling livestream enabled state: $isEnabled');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(LiveStreamConstants.prefKeyEnabled, isEnabled);

    if (!isEnabled) {
      // Disabling: First clear workflow, then dispose
      await toggleReplaceWorkflow(false);

      // Stop all timers
      _stopReconnectTimer();
      _stopStatusCheckTimer();

      await _dispose();

      // Get the current URLs to preserve them
      final currentUrl = state.value?.streamUrl;
      final currentBackofficeUrl = state.value?.backofficeStreamUrl;

      // Set final disabled state but preserve the URLs
      state = AsyncValue.data(
        LiveStreamViewerState(
          isEnabled: false,
          streamUrl: currentUrl,
          backofficeStreamUrl: currentBackofficeUrl,
          streamStatus: LiveStreamStatus.idle,
          autoReplaceWorkflow: true,
        ),
      );
    } else {
      // Enabling: Initialize with loading state, then setup stream
      state = const AsyncValue.loading();

      state = await AsyncValue.guard(() async {
        final savedUrl = prefs.getString(LiveStreamConstants.prefKeyUrl);
        final backofficeUrl = prefs.getString(LiveStreamConstants.prefKeyBackofficeUrl);
        final useBackofficeStream = prefs.getBool(LiveStreamConstants.prefKeyUseBackofficeStream) ?? false;
        final replaceWorkflow = prefs.getBool(LiveStreamConstants.prefKeyReplaceWorkflow) ?? false;
        final autoReplaceWorkflow = prefs.getBool(LiveStreamConstants.prefKeyAutoReplaceWorkflow) ?? true;

        // Determine effective URL based on toggle
        final effectiveUrl =
            (useBackofficeStream && backofficeUrl != null && backofficeUrl.isNotEmpty) ? backofficeUrl : savedUrl;

        if (effectiveUrl != null && effectiveUrl.isNotEmpty) {
          dev.log('🔄 [LIVE_STREAM] Re-enabling with URL: $effectiveUrl');

          // Clean up any existing state first
          await _dispose();

          // Initialize fresh stream
          final newState = await _initializeFromSavedUrl(
            isEnabled: isEnabled,
            url: effectiveUrl,
            savedUrl: savedUrl,
            backofficeUrl: backofficeUrl,
            useBackofficeStream: useBackofficeStream,
            replaceWorkflow: replaceWorkflow,
          );

          dev.log('[LIVE_STREAM] Successfully re-enabled stream with status: ${newState.streamStatus}');
          return newState;
        } else {
          dev.log('[LIVE_STREAM] No saved URL found, returning default state');
          return LiveStreamViewerState(
            isEnabled: isEnabled,
            streamUrl: savedUrl,
            backofficeStreamUrl: backofficeUrl,
            useBackofficeStream: useBackofficeStream,
            isInvalidUrl: false,
            replaceWorkflow: replaceWorkflow,
            autoReplaceWorkflow: autoReplaceWorkflow,
            streamStatus: LiveStreamStatus.idle,
          );
        }
      });
    }
  }

  /// Apply a stream trigger mode in one pass: persist replaceWorkflow first so
  /// the re-initialization inside [toggleEnabled] picks up the fresh value.
  /// Avoids racing two concurrent toggles that both rewrite the state.
  Future<void> applyStreamMode({required bool enabled, required bool replaceWorkflow}) async {
    dev.log('🔌 [LIVE_STREAM] Applying stream mode - enabled: $enabled, replaceWorkflow: $replaceWorkflow');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(LiveStreamConstants.prefKeyReplaceWorkflow, replaceWorkflow);

    await toggleEnabled(enabled);
  }

  /// toggle replace workflow
  Future<void> toggleReplaceWorkflow(bool isEnabled) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async {
        dev.log('🔌 [LIVE_STREAM] Toggling replace workflow: $isEnabled');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(LiveStreamConstants.prefKeyReplaceWorkflow, isEnabled);

        if (!isEnabled) {
          _stopReconnectTimer();
        }

        await Future.delayed(const Duration(milliseconds: LiveStreamConstants.streamInitDelayMs));

        return state.value!.copyWith(
          replaceWorkflow: isEnabled,
        );
      },
    );
  }

  /// Toggle automatic workflow replacement
  Future<void> toggleAutoReplaceWorkflow(bool isEnabled) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async {
        dev.log('🔌 [LIVE_STREAM] Toggling auto replace workflow: $isEnabled');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(LiveStreamConstants.prefKeyAutoReplaceWorkflow, isEnabled);

        await Future.delayed(const Duration(milliseconds: LiveStreamConstants.streamInitDelayMs));

        return state.value!.copyWith(
          autoReplaceWorkflow: isEnabled,
        );
      },
    );
  }

  /// Toggle use of backoffice stream URL
  Future<void> toggleUseBackofficeStream(bool useBackoffice) async {
    dev.log('🏢 [LIVE_STREAM] Toggling use backoffice stream: $useBackoffice');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(LiveStreamConstants.prefKeyUseBackofficeStream, useBackoffice);

    // Reinitialize stream with new toggle state
    await reinitialize();
  }

  /// Reinitialize the provider (used for error recovery)
  Future<void> reinitialize() async {
    try {
      dev.log('🔄 [LIVE_STREAM] Reinitializing LiveStream provider');

      // Clean up current state
      _stopReconnectTimer();
      _stopStatusCheckTimer();
      await _dispose();

      // Reset to loading state
      state = const AsyncValue.loading();

      // Re-initialize from settings
      final newState = await _initializeSettings();
      state = AsyncValue.data(newState);

      // Restart status monitoring if stream is active
      if (newState.streamStatus == LiveStreamStatus.active) {
        dev.log('🔄 [LIVE_STREAM] Restarting status monitoring for active stream');
        _startStatusCheckTimer();
      }

      dev.log('[LIVE_STREAM] Reinitialization completed successfully');
    } catch (e) {
      dev.log('🚨 [LIVE_STREAM] Error during reinitialization: $e');
      state = AsyncValue.error(
        LiveStreamInitializationException('Reinitialization failed: $e'),
        StackTrace.current,
      );
    }
  }

  /// Test RTSP connection without updating the stream
  Future<bool> testRtspConnection(String url) async {
    try {
      if (!url.startsWith('rtsp://')) {
        return false;
      }

      dev.log('🔍 [LIVE_STREAM] Testing RTSP connection: $url');
      final isAvailable = await _rtspHelper.checkRtspServerAvailability(url);

      if (isAvailable) {
        dev.log('[LIVE_STREAM] RTSP server is reachable');
      } else {
        dev.log('[LIVE_STREAM] RTSP server is not reachable');
      }

      return isAvailable;
    } catch (e) {
      dev.log('🚨 [LIVE_STREAM] Error testing RTSP connection: $e');
      return false;
    }
  }

  /// Update backoffice stream URL (called when mosque data is updated)
  Future<void> updateBackofficeUrl(String? backofficeUrl) async {
    try {
      dev.log('🏢 [LIVE_STREAM] Updating backoffice URL: $backofficeUrl');

      final prefs = await SharedPreferences.getInstance();

      if (backofficeUrl == null || backofficeUrl.isEmpty) {
        await prefs.remove(LiveStreamConstants.prefKeyBackofficeUrl);
        dev.log('🗑️ [LIVE_STREAM] Removed backoffice URL');
      } else {
        await prefs.setString(LiveStreamConstants.prefKeyBackofficeUrl, backofficeUrl);
        dev.log('💾 [LIVE_STREAM] Saved backoffice URL');
      }

      // Reinitialize to apply the new backoffice URL
      await reinitialize();
    } catch (e, s) {
      dev.log('🚨 [LIVE_STREAM] Error updating backoffice URL: $e');
      await CrashlyticsWrapper.sendException(e, s);
    }
  }

  /// Update stream with new URL and settings
  Future<void> updateStream({
    required String url,
  }) async {
    // Set state to loading
    state = const AsyncValue.loading();
    dev.log('⏳ [LIVE_STREAM] Set state to loading');

    // IMPORTANT: Small delay to allow any UI components to detach from the controllers
    await Future.delayed(const Duration(milliseconds: LiveStreamConstants.streamInitDelayMs));

    try {
      if (url.isEmpty) {
        dev.log('[LIVE_STREAM] Empty URL provided');
        throw StreamUrlNotProvidedException();
      }

      dev.log('🔍 [LIVE_STREAM] Processing URL: $url');

      // Try to cleanup URL - sometimes there are extra parameters or spaces
      String cleanUrl = url.trim();

      // Save settings to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LiveStreamConstants.prefKeyUrl, cleanUrl);

      // Stop any existing timers when manually updating stream
      _stopReconnectTimer();
      _stopStatusCheckTimer();

      dev.log('🧹 [LIVE_STREAM] Disposed controllers before creating new ones');

      // Clear controllers in notifier first to prevent UI from using old ones
      _youtubeController = null;
      _videoController = null;

      // Explicitly set status to connecting while initializing
      if (state.hasValue) {
        state = AsyncValue.data(
          state.value!.copyWith(
            streamStatus: LiveStreamStatus.connecting,
          ),
        );
      }

      // Allow UI to update before creating new controllers
      await Future.delayed(Duration(milliseconds: 50));

      // Handle YouTube URLs
      if (LiveStreamConstants.youtubeUrlRegex.hasMatch(cleanUrl)) {
        dev.log('🎥 [LIVE_STREAM] Initializing YouTube player');
        final videoWithString = await _handleYoutubeStream(cleanUrl);

        // Set controller in notifier
        _youtubeController = videoWithString.$1;
        _videoController = null;

        state = AsyncValue.data(
          state.value!.copyWith(
            streamStatus: LiveStreamStatus.active,
            streamUrl: videoWithString.$2,
            streamType: LiveStreamType.youtubeLive,
            isInvalidUrl: false, // Reset invalid URL flag
          ),
        );

        // Start status monitoring for active stream
        _startStatusCheckTimer();
      }
      // Handle RTSP URLs
      else if (cleanUrl.startsWith('rtsp://')) {
        dev.log('🎬 [LIVE_STREAM] Initializing RTSP player');
        final controller = await _handleRtspStream(cleanUrl);

        // Set controller in notifier
        _videoController = controller;
        _youtubeController = null;

        state = AsyncValue.data(
          state.value!.copyWith(
            streamStatus: LiveStreamStatus.active,
            streamUrl: cleanUrl,
            streamType: LiveStreamType.rtsp,
            isInvalidUrl: false, // Reset invalid URL flag
          ),
        );

        dev.log('[LIVE_STREAM] RTSP stream successfully initialized and set to active');

        // Start status monitoring for active stream
        _startStatusCheckTimer();
      } else {
        throw InvalidStreamUrlException('Invalid URL format: $cleanUrl');
      }
    } catch (e, s) {
      // Clean up on error
      await _dispose();

      dev.log('🚨 [LIVE_STREAM] Error updating stream: $e');

      if (e is InvalidStreamUrlException || e is StreamUrlNotProvidedException) {
        // Preserve replaceWorkflow when handling URL errors
        state = AsyncValue.data(
          state.value!.copyWith(
            isEnabled: false,
            streamUrl: url,
            isInvalidUrl: true,
            streamStatus: LiveStreamStatus.error,
          ),
        );
        dev.log('[LIVE_STREAM] Updated state for invalid URL');
      } else {
        state = AsyncValue.error(LiveStreamUpdateException(e.toString()), s);
      }
    }
  }

  /// Handle YouTube stream initialization
  Future<(YoutubePlayerController, String)> _handleYoutubeStream(
    String url,
  ) async {
    try {
      dev.log('🎥 [LIVE_STREAM] Handling YouTube stream for URL: $url');

      // Process YouTube URL and get video ID
      final videoId = await _youtubeHelper.processYouTubeUrl(url);

      // Initialize YouTube controller
      final controller = _youtubeHelper.initializeController(videoId);

      // Form standardized URL
      final standardUrl = 'https://www.youtube.com/watch?v=$videoId';

      return (controller, standardUrl);
    } catch (e) {
      dev.log('🚨 [LIVE_STREAM] Error handling YouTube stream: $e');

      throw LiveStreamUpdateException(e.toString());
    }
  }

  /// Handle RTSP stream initialization
  Future<VideoController> _handleRtspStream(String url, {bool skipServerCheck = false}) async {
    try {
      dev.log('🎬 [LIVE_STREAM] Handling RTSP stream for URL: $url');

      // Only check server availability if not skipping (e.g., during user submission)
      if (!skipServerCheck) {
        final isServerAvailable = await _rtspHelper.checkRtspServerAvailability(url);
        if (!isServerAvailable) {
          throw LiveStreamUpdateException('RTSP server is not available at $url');
        }
      }

      // Initialize RTSP player
      final videoController = await _rtspHelper.initializePlayer(url);

      // Setup error and completion listeners
      _rtspHelper.setupListeners(
        onError: (error) => _handleStreamError(error),
        onCompleted: () => _handleStreamEnded(),
      );

      return videoController;
    } catch (e) {
      dev.log('🚨 [LIVE_STREAM] Error handling RTSP stream: $e');
      await _rtspHelper.dispose();
      throw LiveStreamUpdateException(e.toString());
    }
  }

  /// Start timer for stream reconnection attempts
  void _startReconnectTimer() {
    dev.log(
        '⏱️ [LIVE_STREAM] Starting stream reconnection timer (${LiveStreamConstants.streamReconnectIntervalSeconds}s)');
    _reconnectTimer?.cancel();
    _usingExtendedReconnectInterval = false;
    _reconnectTimer = Timer.periodic(
      const Duration(seconds: LiveStreamConstants.streamReconnectIntervalSeconds),
      (timer) async {
        if (state.hasValue && state.value!.isEnabled) {
          await _attemptStreamReconnection();
        }
      },
    );
  }

  /// Start timer for reconnection when server is unavailable (longer interval)
  void _startServerUnavailableTimer() {
    dev.log(
        '⏱️ [LIVE_STREAM] Starting server unavailable timer (${LiveStreamConstants.serverUnavailableReconnectIntervalSeconds}s)');
    _reconnectTimer?.cancel();
    _usingExtendedReconnectInterval = true;
    _reconnectTimer = Timer.periodic(
      const Duration(seconds: LiveStreamConstants.serverUnavailableReconnectIntervalSeconds),
      (timer) async {
        if (state.hasValue && state.value!.isEnabled) {
          await _attemptStreamReconnection();
        }
      },
    );
  }

  /// Stop timer for stream reconnection attempts
  void _stopReconnectTimer() {
    dev.log('⏱️ [LIVE_STREAM] Stopping reconnection timer');
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _usingExtendedReconnectInterval = false;
  }

  /// Start timer for periodic stream status monitoring
  void _startStatusCheckTimer() {
    dev.log(
        '⏱️ [LIVE_STREAM] Starting stream status check timer (every ${LiveStreamConstants.statusCheckIntervalSeconds}s)');
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(
      const Duration(seconds: LiveStreamConstants.statusCheckIntervalSeconds),
      (timer) async {
        if (state.hasValue && state.value!.isEnabled) {
          dev.log('🔍 [LIVE_STREAM] Running periodic status check');
          await checkStreamStatus();
        }
      },
    );
  }

  /// Stop timer for periodic stream status monitoring
  void _stopStatusCheckTimer() {
    dev.log('⏱️ [LIVE_STREAM] Stopping status check timer');
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
  }

  /// Handle stream error
  Future<void> _handleStreamError(String error) async {
    dev.log('[LIVE_STREAM] Stream error detected: $error');

    // Stop status monitoring when error occurs
    _stopStatusCheckTimer();

    // Update state to reflect error
    if (state.hasValue) {
      final currentState = state.value!;

      // Set status to connecting and start reconnection timer
      state = AsyncValue.data(
        currentState.copyWith(
          streamStatus: LiveStreamStatus.connecting,
        ),
      );
      dev.log('🔄 [LIVE_STREAM] Updated state to connecting');

      // Start reconnection timer with 1 minute interval if the replace workflow is enabled
      if (currentState.replaceWorkflow) {
        _startReconnectTimer();
      } else {
        dev.log('🔄 [LIVE_STREAM] Starting reconnection timer without workflow replacement');
      }

      // If still not connected after 1 minute, disable workflow replacement
      Future.delayed(const Duration(minutes: 1), () async {
        if (state.hasValue && state.value!.streamStatus == LiveStreamStatus.connecting) {
          dev.log('[LIVE_STREAM] Reconnection timeout after 1 minute');
          await toggleReplaceWorkflow(false);
        }
      });
    }
  }

  /// Handle stream ended
  Future<void> _handleStreamEnded() async {
    dev.log('🏁 [LIVE_STREAM] Stream ended detected');

    // Stop status monitoring when stream ends
    _stopStatusCheckTimer();

    // Update state to reflect ended stream
    if (state.hasValue) {
      final currentState = state.value!;
      final wasReplacingWorkflow = currentState.replaceWorkflow;

      // Store the previous workflow state in SharedPreferences for restoration after reconnection
      if (wasReplacingWorkflow) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(LiveStreamConstants.prefKeyPreviousWorkflowReplacement, true);
        dev.log('💾 [LIVE_STREAM] Saved previous workflow replacement state for restoration');
      }

      // Update state with ended status
      state = AsyncValue.data(
        currentState.copyWith(
          streamStatus: LiveStreamStatus.ended,
        ),
      );
      dev.log('🔄 [LIVE_STREAM] Updated state for stream ended');

      // Immediately disable workflow replacement to stop showing black screen
      if (wasReplacingWorkflow) {
        dev.log('🏠 [LIVE_STREAM] Immediately disabling workflow replacement to stop black screen');
        await toggleReplaceWorkflow(false);
      }

      // Start reconnection attempts ONLY if stream actually ended
      dev.log('🔄 [LIVE_STREAM] Starting reconnection timer for ended stream');
      _startReconnectTimer();
    }
  }

  /// Update stream status and handle reconnection timer logic
  void _updateStreamStatus(LiveStreamStatus status) {
    if (state.hasValue && state.value!.streamStatus != status) {
      dev.log('🔄 [LIVE_STREAM] Updating stream status to: $status');

      final currentState = state.value!;
      state = AsyncValue.data(currentState.copyWith(streamStatus: status));

      // Stop reconnection timer when stream becomes active
      if (status == LiveStreamStatus.active) {
        dev.log('[LIVE_STREAM] Stream is active, stopping reconnection timer');
        _stopReconnectTimer();
      }
    }
  }

  /// Public method to update stream status from outside components
  void updateStreamStatus(LiveStreamStatus status) {
    dev.log('🔄 [LIVE_STREAM] Public update of stream status to: $status');
    _updateStreamStatus(status);
  }

  /// Check stream status and update if needed
  Future<void> checkStreamStatus() async {
    if (!state.hasValue || !state.value!.isEnabled) {
      dev.log('🔍 [LIVE_STREAM] Skipping status check - no state or disabled');
      return;
    }

    final currentState = state.value!;
    dev.log(
        '🔍 [LIVE_STREAM] Checking stream status - Current status: ${currentState.streamStatus}, Type: ${currentState.streamType}');

    // Check YouTube stream status
    if (currentState.streamType == LiveStreamType.youtubeLive && _youtubeController != null) {
      try {
        final playerState = _youtubeController!.value.playerState;

        if (playerState == PlayerState.ended) {
          await _handleStreamEnded();
        } else if (playerState == PlayerState.buffering) {
          // Check if player has been buffering too long
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          if (_bufferingStartTime == null) {
            _bufferingStartTime = timestamp;
            dev.log('⏳ [LIVE_STREAM] YouTube buffering started');
          } else if (timestamp - _bufferingStartTime! > LiveStreamConstants.bufferTimeoutMs) {
            dev.log('[LIVE_STREAM] YouTube buffering timeout detected');
            // Set status to unreliable instead of error
            state = AsyncValue.data(
              currentState.copyWith(
                streamStatus: LiveStreamStatus.unreliable,
              ),
            );
            _bufferingStartTime = null;
          }
        } else {
          // Reset buffering timestamp if we're not buffering
          if (_bufferingStartTime != null) {
            dev.log('🔄 [LIVE_STREAM] YouTube buffering ended, resetting timestamp');
            _bufferingStartTime = null;
          }
        }
      } catch (e, s) {
        dev.log('[LIVE_STREAM] Error checking YouTube stream status: $e');
        await CrashlyticsWrapper.sendException(e, s);
        await _handleStreamError('YouTube status check error: $e');
      }
    }
    // Check RTSP stream status
    else if (currentState.streamType == LiveStreamType.rtsp && _videoController != null) {
      try {
        // REMOVED: Server availability check that was causing disconnects
        // DON'T DO THIS: final serverAvailable = await _rtspHelper.checkRtspServerAvailability(streamUrl);

        // Only check if the current stream is still active
        final isActive = await _rtspHelper.checkStreamActive();

        if (!isActive && currentState.streamStatus == LiveStreamStatus.active) {
          dev.log('[LIVE_STREAM] RTSP stream is no longer active');
          await _handleStreamEnded();
        } else if (isActive && currentState.streamStatus != LiveStreamStatus.active) {
          dev.log('[LIVE_STREAM] RTSP stream is healthy');
          // Optionally update status to active if it was in an error state
          _updateStreamStatus(LiveStreamStatus.active);
        }
      } catch (e, s) {
        dev.log('[LIVE_STREAM] Error checking RTSP stream status: $e');
        await CrashlyticsWrapper.sendException(e, s);
        await _handleStreamError('RTSP status check error: $e');
      }
    }
  }

  /// Attempt to reconnect to the stream - ONLY called when stream has actually failed
  Future<void> _attemptStreamReconnection() async {
    if (!state.hasValue || !state.value!.isEnabled) {
      dev.log('🔄 [LIVE_STREAM] Skipping reconnection - no state or disabled');
      return;
    }

    final currentState = state.value!;
    final url = currentState.streamUrl;

    if (url == null || url.isEmpty) {
      dev.log('🔄 [LIVE_STREAM] Skipping reconnection - no URL');
      return;
    }

    // IMPORTANT: Only attempt reconnection if stream is NOT active
    if (currentState.streamStatus == LiveStreamStatus.active) {
      dev.log('[LIVE_STREAM] Stream is already active, skipping reconnection attempt');
      return;
    }

    dev.log('🔄 [LIVE_STREAM] Attempting reconnection to: $url (status: ${currentState.streamStatus})');

    try {
      // For RTSP streams, check server availability first
      if (currentState.streamType == LiveStreamType.rtsp) {
        final isServerAvailable = await _rtspHelper.checkRtspServerAvailability(url);
        if (!isServerAvailable) {
          dev.log('[LIVE_STREAM] RTSP server not available, switching to extended reconnection interval');
          // Switch to longer interval timer for server unavailable
          _startServerUnavailableTimer();
          return;
        } else {
          dev.log('[LIVE_STREAM] RTSP server is available, proceeding with reconnection');
          // Server is available, use normal reconnection interval if we were using extended
          if (_usingExtendedReconnectInterval) {
            dev.log('🔄 [LIVE_STREAM] Switching back to normal reconnection interval');
            _startReconnectTimer();
          }
        }
      }

      // Set status to connecting
      state = AsyncValue.data(
        currentState.copyWith(
          streamStatus: LiveStreamStatus.connecting,
        ),
      );

      // Reinitialize the stream
      await updateStream(url: url);

      // If successful, the updateStream method will set status to active
      if (state.hasValue && state.value!.streamStatus == LiveStreamStatus.active) {
        dev.log('[LIVE_STREAM] Successfully reconnected to stream');

        // Start status monitoring for reconnected stream
        _startStatusCheckTimer();

        // Stop reconnection timer since we're connected
        _stopReconnectTimer();

        // Restore workflow replacement if it was previously enabled
        final prefs = await SharedPreferences.getInstance();
        final shouldRestoreWorkflow = prefs.getBool(LiveStreamConstants.prefKeyPreviousWorkflowReplacement) ?? false;

        if (shouldRestoreWorkflow) {
          dev.log('🔄 [LIVE_STREAM] Restoring workflow replacement');
          await prefs.setBool(LiveStreamConstants.prefKeyPreviousWorkflowReplacement, false);
          await toggleReplaceWorkflow(true);
        }
      }
    } catch (e, s) {
      dev.log('[LIVE_STREAM] Reconnection attempt failed: $e');
      await CrashlyticsWrapper.sendException(e, s);
      // Keep trying to reconnect (timer will call this method again)
    }
  }

  /// Pause all streams
  Future<void> pauseStreams() async {
    dev.log('⏸️ [LIVE_STREAM] Pausing all streams');

    // Pause YouTube stream
    _youtubeHelper.controller?.pause();

    // Pause RTSP stream
    await _rtspHelper.pause();
  }

  /// Resume all streams
  Future<void> resumeStreams() async {
    dev.log('▶️ [LIVE_STREAM] Resuming all streams');

    // Resume YouTube stream
    _youtubeHelper.controller?.play();

    // Resume RTSP stream
    await _rtspHelper.play();
  }
}

/// Provider for the livestream viewer feature
final liveStreamProvider = AsyncNotifierProvider<LiveStreamNotifier, LiveStreamViewerState>(() {
  return LiveStreamNotifier();
});
