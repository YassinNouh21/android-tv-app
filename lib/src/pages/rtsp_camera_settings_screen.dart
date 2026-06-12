import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/const/constants.dart';
import 'package:mawaqit/src/domain/error/rtsp_expceptions.dart';
import 'package:mawaqit/src/state_management/livestream_viewer/live_stream_notifier.dart';
import 'package:mawaqit/src/state_management/livestream_viewer/live_stream_state.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:mawaqit/src/widgets/ScreenWithAnimation.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:mawaqit/src/widgets/safe_youtube_player.dart';

class RTSPCameraSettingsScreen extends ConsumerStatefulWidget {
  const RTSPCameraSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RTSPCameraSettingsScreen> createState() => _RTSPCameraSettingsScreenState();
}

class _RTSPCameraSettingsScreenState extends ConsumerState<RTSPCameraSettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _saveButtonFocusNode = FocusNode();
  late StreamSubscription<bool> keyboardSubscription;

  Timer? _saveUrlTimer;

  @override
  void initState() {
    super.initState();
    dev.log('🖥️ [RTSP_SCREEN] Initializing RTSP Camera Settings Screen');
    var keyboardVisibilityController = KeyboardVisibilityController();
    keyboardSubscription = keyboardVisibilityController.onChange.listen((bool visible) {
      if (!visible) {
        dev.log('⌨️ [RTSP_SCREEN] Keyboard hidden, focusing save button');
        FocusScope.of(context).requestFocus(_saveButtonFocusNode);
      }
    });
  }

  void _saveDebouncedUrl(String url) {
    _saveUrlTimer?.cancel();
    _saveUrlTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(LiveStreamConstants.prefKeyUrl, url);
        dev.log('💾 [RTSP_SCREEN] Auto-saved URL: $url');
      } catch (e) {
        dev.log('[RTSP_SCREEN] Error auto-saving URL: $e');
      }
    });
  }

  @override
  void dispose() {
    dev.log('🧹 [RTSP_SCREEN] Disposing RTSP Camera Settings Screen');
    _urlController.dispose();
    _saveButtonFocusNode.dispose();
    _saveUrlTimer?.cancel();
    keyboardSubscription.cancel();
    super.dispose();
  }

  void _updateUrlController(LiveStreamViewerState state) {
    // Determine which URL to show based on the toggle
    String? urlToShow;

    if (state.useBackofficeStream && state.backofficeStreamUrl != null && state.backofficeStreamUrl!.isNotEmpty) {
      // Show backoffice URL when toggle is ON
      urlToShow = state.backofficeStreamUrl;
      dev.log('📝 [RTSP_SCREEN] Using backoffice URL: $urlToShow');
    } else if (state.streamUrl != null && state.streamUrl!.isNotEmpty) {
      // Show user URL when toggle is OFF
      urlToShow = state.streamUrl;
      dev.log('📝 [RTSP_SCREEN] Using user URL: $urlToShow');
    }

    // Update controller if URL is different
    if (urlToShow != null && _urlController.text != urlToShow) {
      dev.log('📝 [RTSP_SCREEN] Updating URL controller to: $urlToShow');
      _urlController.text = urlToShow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(liveStreamProvider);
    final userPrefs = context.watch<UserPreferencesManager>();
    final mosqueManager = context.read<MosqueManager>();
    final blockedByPermission = mosqueManager.typeIsMosque && !userPrefs.isSecondaryScreen;

    // Update URL controller when state changes
    ref.listen(liveStreamProvider, (previous, next) {
      if (next.hasValue) {
        _updateUrlController(next.value!);
      }
      if (previous != next && next.hasValue && next.value!.streamStatus == LiveStreamStatus.error) {
        dev.log('🚨 [RTSP_SCREEN] Stream error detected');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              S.of(context).streamError,
              style: TextStyle(fontSize: 16.sp),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      if (previous != next && !next.isLoading && next.hasValue && !next.hasError && next.value!.isEnabled) {
        final state = next.value!;

        // Only show snackbar when URL validation status changes
        ScaffoldMessenger.of(context).clearSnackBars();

        String message;
        Color backgroundColor;

        if (state.streamUrl != null && !state.isInvalidUrl) {
          dev.log('[RTSP_SCREEN] Valid RTSP URL detected: ${state.streamUrl}');
          message = S.of(context).validRtspUrl;
          backgroundColor = Colors.green;
        } else if (state.isInvalidUrl) {
          dev.log('[RTSP_SCREEN] Invalid RTSP URL detected: ${state.streamUrl}');
          message = S.of(context).invalidRtspUrl;
          backgroundColor = Colors.red;
        } else {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    });

    return asyncState.when(
      data: (state) {
        dev.log('🏗️ [RTSP_SCREEN] Building screen with state: ${state.isEnabled ? "Enabled" : "Disabled"}');
        // When permission is blocked we collapse to the simple settings layout,
        // even if the stream is technically still enabled in saved state.
        final showStreamingLayout = state.isEnabled && !blockedByPermission;
        return Scaffold(
          appBar: showStreamingLayout
              ? AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                )
              : null,
          body: SafeArea(
            child: Stack(
              children: [
                if (!showStreamingLayout)
                  ScreenWithAnimationWidget(
                    animation: "settings",
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildSettingsContent(state),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          margin: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).dividerColor),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: _buildVideoPreview(state),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildSettingsContent(state),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
      loading: () {
        dev.log('[RTSP_SCREEN] Loading state');
        return Scaffold(
          body: _buildLoadingOverlay(),
        );
      },
      error: (error, stackTrace) {
        dev.log('🚨 [RTSP_SCREEN] Error state: $error');
        if (error is RTSPCameraException) {
          return _buildErrorScreen(error);
        } else {
          return _buildErrorScreen(RTSPStreamUpdateException(error.toString()));
        }
      },
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 20,
              horizontal: 30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  S.of(context).validatingStream,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(RTSPCameraException error) {
    String errorMessage = '';

    errorMessage = S.of(context).somethingWentWrong;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // Instead of invalidating, just re-initialize the settings
                final notifier = ref.read(liveStreamProvider.notifier);
                await notifier.reinitialize();
              },
              child: Text(S.of(context).tryAgain),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview(LiveStreamViewerState state) {
    dev.log('🎥 [RTSP_SCREEN] Building video preview for type: ${state.streamType}');
    final notifier = ref.read(liveStreamProvider.notifier);

    if (state.streamType == LiveStreamType.youtubeLive && notifier.youtubeController != null) {
      return SafeYoutubePlayer(
        controller: notifier.youtubeController!,
        placeholder: Center(
          child: Text(
            'Loading stream...',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        onError: (error) {
          dev.log('[RTSP_SCREEN] YouTube player error: $error');
        },
      );
    }
    if (notifier.videoController != null) {
      return Video(controller: notifier.videoController!);
    }
    return const SizedBox.shrink();
  }

  Widget _buildSettingsContent(LiveStreamViewerState state) {
    dev.log('⚙️ [RTSP_SCREEN] Building settings content');
    final userPrefs = context.watch<UserPreferencesManager>();
    final mosqueManager = context.read<MosqueManager>();
    final requiresSecondaryScreen = mosqueManager.typeIsMosque && !userPrefs.isSecondaryScreen;

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          S.of(context).rtspCameraSettings,
          style: Theme.of(context).textTheme.titleMedium?.apply(fontSizeFactor: 2),
          textAlign: TextAlign.center,
        ),
        const Divider(indent: 50, endIndent: 50),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Text(S.of(context).streamMode, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<StreamTriggerMode>(
                  value: userPrefs.streamTriggerMode,
                  isExpanded: true,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(16),
                  alignment: AlignmentDirectional.centerEnd,
                  onChanged: requiresSecondaryScreen
                      ? null
                      : (value) {
                          if (value == null) return;
                          userPrefs.streamTriggerMode = value;
                          // camera mode = stream auto-replaces workflow when active.
                          // other modes = stream is shown only inside specific workflow items.
                          ref.read(liveStreamProvider.notifier).applyStreamMode(
                                enabled: value != StreamTriggerMode.disabled,
                                replaceWorkflow: value == StreamTriggerMode.camera,
                              );
                        },
                  items: StreamTriggerMode.values.map((mode) {
                    return DropdownMenuItem(
                      value: mode,
                      child: Text(
                        switch (mode) {
                          StreamTriggerMode.disabled => S.of(context).streamModeDisabled,
                          StreamTriggerMode.camera => S.of(context).streamModeCamera,
                          StreamTriggerMode.jumuaOnly => S.of(context).streamModeJumuaOnly,
                          StreamTriggerMode.jumuaAndPrayers => S.of(context).streamModeJumuaAndPrayers,
                        },
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        if (requiresSecondaryScreen) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  S.of(context).streamRequiresSecondaryScreen,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
              ),
            ],
          ),
        ],
        if (!requiresSecondaryScreen && userPrefs.streamTriggerMode != StreamTriggerMode.disabled) ...[
          const SizedBox(height: 12),
          if (state.backofficeStreamUrl != null && state.backofficeStreamUrl!.isNotEmpty) ...[
            SwitchListTile(
              title: Text(S.of(context).mosqueDefault),
              value: state.useBackofficeStream,
              onChanged: (value) {
                dev.log('🏢 [RTSP_SCREEN] Toggling use backoffice stream: $value');
                ref.read(liveStreamProvider.notifier).toggleUseBackofficeStream(value);
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 20),
          Text(
            S.of(context).addRtspUrl,
            style: Theme.of(context).textTheme.bodyLarge?.apply(fontSizeFactor: 1.2),
            textAlign: TextAlign.center,
          ),
          const Divider(indent: 50, endIndent: 50),
          const SizedBox(height: 20),
          TextField(
            controller: _urlController,
            enabled: !state.isFromBackoffice, // Disable if using backoffice URL
            onChanged: (value) {
              // Only save if not using backoffice URL
              if (!state.isFromBackoffice) {
                _saveDebouncedUrl(value);
              }
            },
            onSubmitted: (_) {
              // Only allow submission if not using backoffice URL
              if (!state.isFromBackoffice) {
                dev.log('📤 [RTSP_SCREEN] URL submitted: ${_urlController.text}');
                ref.read(liveStreamProvider.notifier).updateStream(
                      url: _urlController.text,
                    );
              }
            },
            decoration: InputDecoration(
              labelText: S.of(context).enterRtspUrl,
              hintText: state.isFromBackoffice ? S.of(context).urlManagedByMosqueAdmin : S.of(context).hintTextRtspUrl,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              suffixIcon: state.isFromBackoffice ? Icon(Icons.lock, color: Colors.grey) : null,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            focusNode: _saveButtonFocusNode,
            onPressed: state.isFromBackoffice
                ? null // Disable save button when using backoffice URL
                : () async {
                    dev.log('💾 [RTSP_SCREEN] Save button pressed with URL: ${_urlController.text}');
                    // First, show a loading indicator to prevent interactions
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Text(S.of(context).processingRequest),
                          ],
                        ),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );

                    // Wait a moment to ensure UI updates
                    await Future.delayed(const Duration(milliseconds: 100));

                    // Always test RTSP connection first when it's an RTSP URL
                    if (_urlController.text.isNotEmpty && _urlController.text.startsWith('rtsp://')) {
                      final notifier = ref.read(liveStreamProvider.notifier);
                      final isAvailable = await notifier.testRtspConnection(_urlController.text);

                      if (!isAvailable) {
                        // Clear the loading snackbar
                        scaffoldMessenger.clearSnackBars();

                        // Show error message
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.white),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    S.of(context).rtspServerNotAvailable,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return; // Don't proceed if connection fails
                      }
                    }

                    // Only update the stream if the URL has actually changed OR if we need to reconnect
                    if (_urlController.text != state.streamUrl || state.streamStatus != LiveStreamStatus.active) {
                      dev.log('🔄 [RTSP_SCREEN] Updating stream (URL changed or reconnecting)');
                      await Future.delayed(const Duration(milliseconds: 500));

                      ref.read(liveStreamProvider.notifier).updateStream(
                            url: _urlController.text,
                          );
                    } else if (state.streamUrl != null && state.streamUrl!.isNotEmpty) {
                      dev.log('📝 [RTSP_SCREEN] URL unchanged and stream active, only updating workflow flag');
                      // URL hasn't changed and stream is active, just update the workflow flag if needed
                      ref.read(liveStreamProvider.notifier).toggleReplaceWorkflow(state.replaceWorkflow);

                      // Show success message
                      scaffoldMessenger.clearSnackBars();
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white),
                              const SizedBox(width: 12),
                              Text(S.of(context).settingsSavedSuccessfully),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.save),
            label: Text(S.of(context).save),
            style: ButtonStyle(
              padding: MaterialStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                if (states.contains(MaterialState.focused)) {
                  return Theme.of(context).primaryColor;
                }
                return Colors.white;
              }),
              iconColor: MaterialStateProperty.resolveWith<Color>((states) {
                if (states.contains(MaterialState.focused)) {
                  return Colors.white;
                }
                return Colors.black;
              }),
              foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                if (states.contains(MaterialState.focused)) {
                  return Colors.white;
                }
                return Colors.black;
              }),
            ),
          ),
        ],
      ],
    );
  }
}
