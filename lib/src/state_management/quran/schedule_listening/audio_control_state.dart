// audio_status.dart
import 'package:equatable/equatable.dart';

enum AudioStatus { playing, paused }

class AudioControlState extends Equatable {
  final AudioStatus status;
  final bool isLoading;
  final String? error;
  final bool shouldShowControls;
  final bool isConfigured;
  final bool isStopped;
  final int? currentPlayingSurahId;

  const AudioControlState({
    this.status = AudioStatus.paused,
    this.isLoading = false,
    this.error,
    this.shouldShowControls = false,
    this.isConfigured = false,
    this.isStopped = false,
    this.currentPlayingSurahId,
  });

  AudioControlState copyWith({
    AudioStatus? status,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? shouldShowControls,
    bool? isConfigured,
    bool? isStopped,
    int? currentPlayingSurahId,
    bool clearCurrentSurah = false,
  }) {
    return AudioControlState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      shouldShowControls: shouldShowControls ?? this.shouldShowControls,
      isConfigured: isConfigured ?? this.isConfigured,
      isStopped: isStopped ?? this.isStopped,
      currentPlayingSurahId: clearCurrentSurah ? null : (currentPlayingSurahId ?? this.currentPlayingSurahId),
    );
  }

  @override
  List<Object?> get props =>
      [status, isLoading, error, shouldShowControls, isConfigured, isStopped, currentPlayingSurahId];
}
