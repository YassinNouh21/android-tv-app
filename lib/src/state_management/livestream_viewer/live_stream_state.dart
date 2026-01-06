import 'package:equatable/equatable.dart';

/// Enumeration of stream types supported by the livestream viewer
enum LiveStreamType { rtsp, youtubeLive }

/// Enumeration of stream statuses
enum LiveStreamStatus {
  idle,
  active,
  error,
  ended,
  connecting, // New status for when trying to reconnect
  unreliable, // New status for when stream quality is poor
}

/// State class for livestream viewer feature
class LiveStreamViewerState extends Equatable {
  /// Whether livestream is enabled
  final bool isEnabled;

  /// URL of the stream (user-configured)
  final String? streamUrl;

  /// URL of the stream from backoffice (fallback when user doesn't configure one)
  final String? backofficeStreamUrl;

  /// Whether to use backoffice stream URL (toggle)
  final bool useBackofficeStream;

  /// Type of stream (RTSP or YouTube)
  final LiveStreamType? streamType;

  /// Whether URL is invalid
  final bool isInvalidUrl;

  /// Whether to replace the main workflow with the stream
  final bool replaceWorkflow;

  /// Whether workflow replacement should be automatic (based on stream status)
  final bool autoReplaceWorkflow;

  /// Current status of the stream
  final LiveStreamStatus streamStatus;

  /// Get the effective stream URL based on toggle
  String? get effectiveStreamUrl {
    // If toggle is ON, use backoffice URL
    if (useBackofficeStream && backofficeStreamUrl != null && backofficeStreamUrl!.isNotEmpty) {
      return backofficeStreamUrl;
    }
    // Otherwise use user-configured URL
    return streamUrl;
  }

  /// Check if currently using backoffice stream
  bool get isFromBackoffice => useBackofficeStream &&
      backofficeStreamUrl != null &&
      backofficeStreamUrl!.isNotEmpty;

  /// Whether the workflow should currently be replaced (computed property)
  /// This considers both manual and automatic replacement modes
  bool get shouldReplaceWorkflow {
    // Stream must be enabled, active, and URL must be valid for any replacement
    if (!isEnabled || streamStatus != LiveStreamStatus.active || isInvalidUrl) {
      return false;
    }

    // In both auto and manual modes, respect the replaceWorkflow setting
    // This ensures that if user explicitly disables it, it stays disabled
    return replaceWorkflow;
  }

  const LiveStreamViewerState({
    this.isEnabled = false,
    this.streamUrl,
    this.backofficeStreamUrl,
    this.useBackofficeStream = false,
    this.streamType,
    this.isInvalidUrl = false,
    this.replaceWorkflow = false,
    this.autoReplaceWorkflow = true,
    this.streamStatus = LiveStreamStatus.idle,
  });

  /// Create a copy of this state with specified attributes replaced
  LiveStreamViewerState copyWith({
    bool? isEnabled,
    String? streamUrl,
    String? backofficeStreamUrl,
    bool? useBackofficeStream,
    LiveStreamType? streamType,
    bool? isInvalidUrl,
    bool? replaceWorkflow,
    bool? autoReplaceWorkflow,
    LiveStreamStatus? streamStatus,
  }) {
    return LiveStreamViewerState(
      isEnabled: isEnabled ?? this.isEnabled,
      streamUrl: streamUrl ?? this.streamUrl,
      backofficeStreamUrl: backofficeStreamUrl ?? this.backofficeStreamUrl,
      useBackofficeStream: useBackofficeStream ?? this.useBackofficeStream,
      streamType: streamType ?? this.streamType,
      isInvalidUrl: isInvalidUrl ?? this.isInvalidUrl,
      replaceWorkflow: replaceWorkflow ?? this.replaceWorkflow,
      autoReplaceWorkflow: autoReplaceWorkflow ?? this.autoReplaceWorkflow,
      streamStatus: streamStatus ?? this.streamStatus,
    );
  }

  @override
  List<Object?> get props => [
        isEnabled,
        streamUrl,
        backofficeStreamUrl,
        useBackofficeStream,
        streamType,
        isInvalidUrl,
        replaceWorkflow,
        autoReplaceWorkflow,
        streamStatus,
      ];

  @override
  String toString() {
    return 'LiveStreamViewerState{isEnabled: $isEnabled, streamUrl: $streamUrl, streamType: $streamType, isInvalidUrl: $isInvalidUrl, replaceWorkflow: $replaceWorkflow, autoReplaceWorkflow: $autoReplaceWorkflow, streamStatus: $streamStatus} \n\n';
  }
}
