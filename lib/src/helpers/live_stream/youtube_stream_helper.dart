import 'dart:async';
import 'dart:developer' as dev;

import 'package:mawaqit/src/domain/error/live_stream_exceptions.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Helper class to handle YouTube stream operations
class YouTubeStreamHelper {
  YoutubePlayerController? _controller;

  /// Get the current active controller
  YoutubePlayerController? get controller => _controller;

  /// Clean up resources
  Future<void> dispose() async {
    if (_controller != null) {
      try {
        final controllerToDispose = _controller!;
        _controller = null;
        controllerToDispose.dispose();
        dev.log('🎥 [YOUTUBE_HELPER] Disposed YouTube controller');
      } catch (e) {
        dev.log('⚠️ [YOUTUBE_HELPER] Error disposing YouTube controller: $e');
        _controller = null;
      }
    }
  }

  /// Extract YouTube channel ID from URL
  String? extractChannelId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // Handle youtube.com URLs
    if (uri.host == 'youtube.com' || uri.host == 'www.youtube.com' || uri.host == 'm.youtube.com') {
      final pathSegments = uri.pathSegments;

      // Handle /channel/CHANNEL_ID format
      if (pathSegments.isNotEmpty && pathSegments[0] == 'channel' && pathSegments.length > 1) {
        final channelId = pathSegments[1].split('?').first;
        dev.log('[YOUTUBE_HELPER] Extracted channel ID: $channelId');
        return channelId;
      }

      // Handle /@USERNAME format
      if (pathSegments.isNotEmpty && pathSegments[0].startsWith('@')) {
        return pathSegments[0];
      }
    }

    return null;
  }

  /// Get the current live video ID from a YouTube channel
  /// Uses the same logic as the old MawaqitYoutubePlayer: checks for videos with null duration (live streams)
  Future<String?> getLiveVideoFromChannel(String channelId) async {
    final yt = YoutubeExplode();
    try {
      final uploads = yt.channels.getUploads(channelId);

      // Check first 10 videos for live streams (videos with null duration)
      await for (final video in uploads.take(10)) {
        // Live streams have null duration
        if (video.duration == null) {
          final videoId = video.id.value;
          dev.log('[YOUTUBE_HELPER] Found live stream: $videoId');
          yt.close();
          return videoId;
        }
      }

      yt.close();
      return null;
    } catch (e) {
      dev.log('[YOUTUBE_HELPER] Error fetching live video: $e');
      yt.close();
      return null;
    }
  }

  /// Extract YouTube video ID from URL
  /// If URL is a channel URL, attempts to fetch the current live video from that channel
  Future<String?> extractVideoId(String url) async {
    // First check if it's a channel URL
    final channelId = extractChannelId(url);
    if (channelId != null) {
      final liveVideoId = await getLiveVideoFromChannel(channelId);
      if (liveVideoId != null) {
        return liveVideoId;
      }
      return null;
    }

    // Try standard YouTube URL extraction first
    final regularId = YoutubePlayer.convertUrlToId(url);
    if (regularId != null && regularId.isNotEmpty) {
      return regularId;
    }

    // Manual extraction for various YouTube URL formats
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // Handle youtu.be short URLs (e.g., https://youtu.be/VIDEO_ID)
    if (uri.host == 'youtu.be') {
      if (uri.pathSegments.isNotEmpty) {
        return uri.pathSegments[0].split('?').first;
      }
    }

    // Handle youtube.com URLs
    if (uri.host == 'youtube.com' || uri.host == 'www.youtube.com' || uri.host == 'm.youtube.com') {
      final pathSegments = uri.pathSegments;

      // Handle /live/VIDEO_ID format
      if (pathSegments.contains('live') && pathSegments.length > 1) {
        final liveIndex = pathSegments.indexOf('live');
        if (liveIndex < pathSegments.length - 1) {
          return pathSegments[liveIndex + 1].split('?').first;
        }
      }

      // Handle /watch?v=VIDEO_ID format
      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v'];
      }

      // Handle /embed/VIDEO_ID format
      if (pathSegments.isNotEmpty && pathSegments[0] == 'embed' && pathSegments.length > 1) {
        return pathSegments[1].split('?').first;
      }

      // Handle /v/VIDEO_ID format
      if (pathSegments.isNotEmpty && pathSegments[0] == 'v' && pathSegments.length > 1) {
        return pathSegments[1].split('?').first;
      }
    }

    return null;
  }

  /// Validate if a YouTube video is a live stream
  ///
  /// [videoId] The YouTube video ID to validate
  /// [strictValidation] If true, throws an exception when validation fails.
  ///                    If false, returns false on validation errors (useful for graceful degradation)
  Future<bool> validateLiveStream(
    String videoId, {
    bool strictValidation = false,
  }) async {
    try {
      dev.log('🔍 [YOUTUBE_HELPER] Validating YouTube video with YoutubeExplode (strict: $strictValidation)');
      final yt = YoutubeExplode();

      try {
        // First check if the video exists and we can get its metadata
        final video = await yt.videos.get(videoId).timeout(
          const Duration(seconds: 10), // Increased timeout from 5 to 10 seconds
          onTimeout: () {
            dev.log('⏰ [YOUTUBE_HELPER] Timeout validating YouTube video');
            throw TimeoutException('Timed out attempting to validate YouTube video');
          },
        );

        // Check if the video is marked as a live stream
        final isLive = video.isLive;
        dev.log('🎥 [YOUTUBE_HELPER] YouTube video is live: $isLive');

        // Close the YoutubeExplode client
        yt.close();

        return isLive;
      } catch (e) {
        // Make sure to close the client even if an error occurs
        yt.close();
        rethrow;
      }
    } catch (e) {
      dev.log('⚠️ [YOUTUBE_HELPER] Error checking if YouTube video is live: $e');

      if (strictValidation) {
        throw LiveStreamInitializationException('Unable to verify if YouTube video is a live stream: $e');
      } else {
        // In non-strict mode, log the error but allow the video to proceed
        dev.log('⚠️ [YOUTUBE_HELPER] Validation failed but continuing in non-strict mode');
        return false; // Return false but don't throw
      }
    }
  }

  /// Initialize a YouTube player controller for the given video ID
  YoutubePlayerController initializeController(String videoId) {
    // Dispose existing controller if any
    dispose();

    // Create a new controller
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: false,
        hideControls: true,
        isLive: true,
        useHybridComposition: false,
        forceHD: false,
      ),
    );

    dev.log('🎥 [YOUTUBE_HELPER] Created YouTube player controller');
    return _controller!;
  }

  /// Process a YouTube URL and return a valid video ID
  ///
  /// [url] The YouTube URL to process
  /// [validateLive] If true, validates that the video is a live stream (may be slow/fail)
  ///                If false, skips validation and returns the video ID directly
  ///
  /// Throws an exception if the URL is invalid
  Future<String> processYouTubeUrl(
    String url, {
    bool validateLive = false,
  }) async {
    dev.log('🔍 [YOUTUBE_HELPER] Processing YouTube URL: $url (validateLive: $validateLive)');

    // Extract video ID (now async to support channel lookup)
    final videoId = await extractVideoId(url);
    if (videoId == null || videoId.isEmpty) {
      dev.log('❌ [YOUTUBE_HELPER] Could not extract video ID from URL: $url');
      throw InvalidStreamUrlException('Could not extract valid video ID from YouTube URL');
    }

    dev.log('✅ [YOUTUBE_HELPER] Extracted video ID: $videoId');

    // Skip validation if not required
    if (!validateLive) {
      dev.log('⏭️ [YOUTUBE_HELPER] Skipping live stream validation');
      return videoId;
    }

    // Validate live stream (non-strict mode - won't throw on validation errors)
    try {
      final isLive = await validateLiveStream(videoId, strictValidation: false);

      if (!isLive) {
        dev.log('⚠️ [YOUTUBE_HELPER] Video may not be a live stream, but proceeding anyway');
      } else {
        dev.log('✅ [YOUTUBE_HELPER] Confirmed video is a live stream');
      }
    } catch (e) {
      // If validation fails, log it but continue anyway
      dev.log('⚠️ [YOUTUBE_HELPER] Validation failed but proceeding: $e');
    }

    // Return video ID
    return videoId;
  }
}
