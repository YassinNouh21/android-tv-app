import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/pages/quran/reading/quran_reading_screen.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:mawaqit/src/pages/quran/widget/download_quran_popup.dart';
import 'package:mawaqit/src/state_management/quran/download_quran/download_quran_notifier.dart';
import 'package:mawaqit/src/state_management/quran/download_quran/download_quran_state.dart';
import 'package:provider/provider.dart' as provider;

/// A wrapper screen for Quran mode that handles the download flow.
/// If Quran files are not downloaded, it shows the download dialog.
/// If the user cancels, it reverts to normal mode.
class QuranModeScreen extends ConsumerStatefulWidget {
  const QuranModeScreen({super.key});

  @override
  ConsumerState<QuranModeScreen> createState() => _QuranModeScreenState();
}

class _QuranModeScreenState extends ConsumerState<QuranModeScreen> {
  bool _hasShownDownloadDialog = false;
  bool _hasShownErrorDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkQuranStatus();
    });
  }

  Future<void> _checkQuranStatus() async {
    // Trigger the download check.
    // The provider stays alive because build() calls ref.watch(downloadQuranNotifierProvider).
    ref.invalidate(downloadQuranNotifierProvider);
  }

  void _revertToNormalMode() {
    final userPrefs = provider.Provider.of<UserPreferencesManager>(context, listen: false);
    userPrefs.appMode = AppMode.normal;
  }

  void _showDownloadDialog() {
    if (_hasShownDownloadDialog) return;
    _hasShownDownloadDialog = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DownloadQuranDialog(
        onSuccess: () {
          // Trigger rebuild to show QuranReadingScreen
          ref.invalidate(downloadQuranNotifierProvider);
        },
        onCancel: () {
          _revertToNormalMode();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadQuranNotifierProvider);

    return downloadState.when(
      data: (state) {
        // Any data state clears error flag so new errors can be shown (C4 fix)
        _hasShownErrorDialog = false;

        // Quran is ready (already downloaded or just finished)
        if (state is NoUpdate || state is Success) {
          // This screen is only mounted when appMode == AppMode.quran.
          // QuranReadingScreen handles its own back-press via isQuranMode flag,
          // so no WillPopScope wrapper is needed here (C1 fix).
          return const QuranReadingScreen(isQuranMode: true);
        }

        // Need to download
        if (state is NeededDownloadedQuran || state is UpdateAvailable) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showDownloadDialog();
          });
          return _buildLoadingScreen();
        }

        // Downloading or extracting - show loading with progress
        if (state is Downloading) {
          return _buildProgressScreen(S.of(context).downloadingQuran, state.progress);
        }

        if (state is Extracting) {
          return _buildProgressScreen(S.of(context).extractingQuran, state.progress);
        }

        // Cancel - revert to normal mode
        if (state is CancelDownload) {
          _hasShownDownloadDialog = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _revertToNormalMode();
          });
          return _buildLoadingScreen();
        }

        // For other states (checking, etc.), show loading
        return _buildLoadingScreen();
      },
      loading: () => _buildLoadingScreen(),
      error: (error, stack) {
        // On error, show error and option to go back
        if (!_hasShownErrorDialog) {
          _hasShownErrorDialog = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showErrorDialog(error);
          });
        }
        return _buildLoadingScreen();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              S.of(context).quran,
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressScreen(String label, double progress) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: progress / 100,
                color: Colors.white,
                backgroundColor: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '${progress.toStringAsFixed(1)}%',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(Object error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).error),
        content: Text(error.toString()),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () {
              Navigator.pop(context);
              _revertToNormalMode();
            },
            child: Text(S.of(context).ok),
          ),
        ],
      ),
    );
  }
}

