import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:mawaqit/main.dart';
import 'package:mawaqit/src/const/constants.dart';
import 'package:mawaqit/src/module/dio_module.dart';
import 'package:mawaqit/src/state_management/app_update/app_update_notifier.dart';
import 'package:mawaqit/src/state_management/manual_app_update/manual_update_state.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:xml/xml.dart';

final manualUpdateNotifierProvider = AsyncNotifierProvider<ManualUpdateNotifier, UpdateState>(() {
  return ManualUpdateNotifier();
});

class ManualUpdateNotifier extends AsyncNotifier<UpdateState> {
  static const platform = MethodChannel(TurnOnOffTvConstant.kNativeMethodsChannel);
  static final _versionRegex = RegExp(r'v(\d+\.\d+\.\d+)');
  static final _buildNumberRegex = RegExp(r'v\d+\.\d+\.\d+-(\d+)');
  static const _cacheDuration = Duration(days: 5);

  late final Dio _dio;
  CancelToken? _cancelToken;
  Map<String, dynamic>? _cachedLatestApk;
  DateTime? _cacheTimestamp;

  @override
  Future<UpdateState> build() async {
    // Use existing Dio provider for better testability
    final dioModule = ref.read(
      dioProvider(
        DioProviderParameter(
          baseUrl: '',
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ),
    );
    _dio = dioModule.dio;
    _cachedLatestApk = null;
    _cacheTimestamp = null;
    return const UpdateState();
  }

  void cancelUpdate() {
    _cancelToken?.cancel('Update cancelled by user');
    _cancelToken = null;

    _cleanupDownloadedFile();

    state = const AsyncValue.data(
      UpdateState(
        status: UpdateStatus.cancelled,
        message: 'Update cancelled',
      ),
    );
  }

  void _cleanupDownloadedFile() {
    final filePath = state.value?.filePath;
    if (filePath != null) {
      try {
        final file = File(filePath);
        if (file.existsSync()) file.deleteSync();
      } catch (e) {
        debugPrint('Error cleaning up file: $e');
      }
    }
  }

  Future<void> checkForUpdates(String currentVersion) async {
    state = const AsyncLoading();
    // Implement time-based cache invalidation (5 days) instead of clearing on every check
    if (_cacheTimestamp != null && DateTime.now().difference(_cacheTimestamp!) > _cacheDuration) {
      _cachedLatestApk = null;
      _cacheTimestamp = null;
    }
    try {
      // For all devices, check S3 for updates and install via system installer
      final hasUpdate = await _isUpdateAvailableForRootedDevice(currentVersion);

      if (hasUpdate) {
        final latestApk = await _getLatestApk();
        final latestVersion = _extractVersionFromFileName(latestApk['fileName']);
        final latestBuildNumber = _extractBuildNumberFromFileName(latestApk['fileName']);

        // Validate S3 key to prevent path traversal
        final key = latestApk['key'] as String;
        if (key.contains('..') || key.contains('//')) {
          throw Exception('Invalid S3 key format: $key');
        }

        final downloadUrl = '${ManualUpdateConstant.s3DownloadBaseUrl}/$key';

        state = AsyncData(state.value!.copyWith(
          status: UpdateStatus.available,
          message: 'Update available',
          downloadUrl: downloadUrl,
          currentVersion: currentVersion,
          availableVersion: '$latestVersion-$latestBuildNumber',
        ));
      } else {
        state = AsyncData(UpdateState(
          status: UpdateStatus.notAvailable,
          message: 'You are using the latest version',
          currentVersion: currentVersion,
        ));
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<bool> _isUpdateAvailableForRootedDevice(String currentVersion) async {
    final latestVersion = await _getLatestVersion();
    return _compareVersions(latestVersion, currentVersion) > 0;
  }

  Future<List<Map<String, dynamic>>> _fetchS3ApkList() async {
    final response = await _dio.get(ManualUpdateConstant.s3BucketListUrl);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch APK list from S3: ${response.statusCode}');
    }

    // Parse XML response from S3 with error handling
    try {
      final document = XmlDocument.parse(response.data);
      final contents = document.findAllElements('Contents');

      final apkList = <Map<String, dynamic>>[];

      for (var content in contents) {
        // Check if Key element exists before accessing
        final keyElements = content.findElements('Key');
        if (keyElements.isEmpty) continue;

        final key = keyElements.first.innerText;

        // Only include APK files with version pattern (MAWAQIT-For-TV-v*.apk)
        if (key.contains(ManualUpdateConstant.apkPrefix) && key.endsWith('.apk')) {
          // Check if LastModified element exists before accessing
          final lastModifiedElements = content.findElements('LastModified');
          if (lastModifiedElements.isEmpty) continue;

          final lastModified = lastModifiedElements.first.innerText;

          apkList.add({
            'key': key,
            'lastModified': lastModified,
            'fileName': key.split('/').last,
          });
        }
      }

      return apkList;
    } on XmlParserException catch (e) {
      throw Exception('Failed to parse S3 response XML: $e');
    } catch (e) {
      throw Exception('Unexpected error parsing S3 response: $e');
    }
  }

  Future<Map<String, dynamic>> _getLatestApk() async {
    // Return cached result if available
    if (_cachedLatestApk != null) {
      return _cachedLatestApk!;
    }

    final apkList = await _fetchS3ApkList();
    if (apkList.isEmpty) {
      throw Exception('No APK found in S3');
    }

    // Sort by version and build number to get the latest
    apkList.sort((a, b) {
      final versionA = _extractVersionFromFileName(a['fileName']);
      final versionB = _extractVersionFromFileName(b['fileName']);
      final versionCompare = _compareVersions(versionB, versionA);
      if (versionCompare != 0) return versionCompare;
      final buildA = _extractBuildNumberFromFileName(a['fileName']);
      final buildB = _extractBuildNumberFromFileName(b['fileName']);
      return buildB - buildA;
    });

    _cachedLatestApk = apkList.first;
    _cacheTimestamp = DateTime.now(); // Set cache timestamp
    return _cachedLatestApk!;
  }

  Future<String> _getLatestVersion() async {
    final latestApk = await _getLatestApk();
    return _extractVersionFromFileName(latestApk['fileName']);
  }

  String _extractVersionFromFileName(String fileName) {
    // Extract version from filename like "MAWAQIT-For-TV-v1.28.0-603.apk"
    final match = _versionRegex.firstMatch(fileName);
    if (match != null) {
      final version = match.group(1);
      if (version != null) {
        return version;
      }
    }
    throw Exception('Could not extract version from filename: $fileName');
  }

  int _extractBuildNumberFromFileName(String fileName) {
    final match = _buildNumberRegex.firstMatch(fileName);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 0;
  }

  Future<void> downloadAndInstallUpdate() async {
    final downloadUrl = state.value?.downloadUrl;
    if (downloadUrl == null) return;

    try {
      _cancelToken = CancelToken();

      state = AsyncValue.data(state.value!.copyWith(
        status: UpdateStatus.downloading,
        message: 'Downloading update...',
      ));

      final filePath = await _downloadApk(downloadUrl);

      // Check if cancelled after download
      if (_cancelToken?.isCancelled ?? false) return;

      state = AsyncValue.data(state.value!.copyWith(
        status: UpdateStatus.installing,
        message: 'Installing update...',
        filePath: filePath,
      ));

      await _installApk(filePath);

      state = AsyncValue.data(state.value!.copyWith(
        status: UpdateStatus.completed,
        message: 'Update completed successfully',
      ));
    } catch (e, st) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return; // Already handled by cancelUpdate
      }

      _handleUpdateError(e, st);
    } finally {
      _cancelToken = null;
    }
  }

  void _handleUpdateError(Object e, StackTrace st) {
    _cleanupDownloadedFile();

    state = AsyncValue.data(state.value!.copyWith(
      status: UpdateStatus.error,
      message: 'Update failed: ${e.toString()}',
    ));
  }

  Future<String> _downloadApk(String url) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/update.apk';

      await _dio.download(
        url,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            state = AsyncValue.data(state.value!.copyWith(progress: progress));
          }
        },
      );

      return filePath;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        throw e; // Rethrow cancellation to be handled in downloadAndInstallUpdate
      }
      throw Exception('Error downloading APK: $e');
    }
  }

  Future<void> _installApk(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('APK file not found');
      }

      // Sideload flavor: use FileProvider + REQUEST_INSTALL_PACKAGES
      // Googleplay flavor: use root (su pm install)
      final method = kIsSideloadFlavor ? 'installApk' : 'installApkRoot';

      final result = await platform.invokeMethod(method, {
        'filePath': filePath,
      });

      if (result != true) {
        throw Exception('Installation failed');
      }
    } on PlatformException catch (e) {
      if (!kIsSideloadFlavor && (e.code == 'NOT_ROOTED' || e.code == 'INSTALL_FAILED')) {
        // Root install not available — fall back to opening the Play Store
        await ref.read(appUpdateProvider.notifier).openStore();
        return;
      }
      throw Exception('Error installing APK: $e');
    } catch (e) {
      throw Exception('Error installing APK: $e');
    }
  }

  int _compareVersions(String v1, String v2) {
    final version1 = v1.replaceAll('v', '').split('.');
    final version2 = v2.replaceAll('v', '').split('.');
    for (var i = 0; i < version1.length && i < version2.length; i++) {
      final num1 = int.parse(version1[i]);
      final num2 = int.parse(version2[i]);
      if (num1 != num2) {
        return num1 - num2;
      }
    }
    return version1.length - version2.length;
  }
}
