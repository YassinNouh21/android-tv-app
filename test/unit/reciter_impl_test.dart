import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mawaqit/src/data/repository/quran/recite_impl.dart';
import 'package:mawaqit/src/data/data_source/quran/recite_remote_data_source.dart';
import 'package:mawaqit/src/data/data_source/quran/reciter_local_data_source.dart';
import 'package:mawaqit/src/domain/model/quran/reciter_model.dart';
import 'package:mawaqit/src/domain/error/recite_exception.dart';

class MockReciteRemoteDataSource extends Mock implements ReciteRemoteDataSource {}

class MockReciteLocalDataSource extends Mock implements ReciteLocalDataSource {}

void main() {
  late ReciteImpl reciteImpl;
  late MockReciteRemoteDataSource mockRemoteDataSource;
  late MockReciteLocalDataSource mockLocalDataSource;

  setUp(() {
    mockRemoteDataSource = MockReciteRemoteDataSource();
    mockLocalDataSource = MockReciteLocalDataSource();
    reciteImpl = ReciteImpl(mockRemoteDataSource, mockLocalDataSource);
  });

  group('getAllReciters with caching', () {
    final testReciters = [ReciterModel(1, 'Reciter 1', 'A', []), ReciterModel(2, 'Reciter 2', 'B', [])];
    // Expected reciters after merging with alternate language (nameAlternate is populated)
    final mergedReciters = [
      ReciterModel(1, 'Reciter 1', 'A', [], 'Reciter 1'),
      ReciterModel(2, 'Reciter 2', 'B', [], 'Reciter 2'),
    ];

    test('returns cached data when cache is valid and not empty', () async {
      // Arrange
      when(() => mockLocalDataSource.getReciters()).thenAnswer((_) async => testReciters);
      when(() => mockLocalDataSource.getLastUpdatedTimestamp()).thenReturn(Option.of(DateTime.now())); // Cache is fresh

      // Act
      final result = await reciteImpl.getAllReciters(language: 'en');

      // Assert
      expect(result, equals(testReciters));
      verifyNever(() => mockRemoteDataSource.getReciters(language: any(named: 'language')));
    });

    test('fetches from remote when cache is expired', () async {
      // Arrange
      final expiredDate = DateTime.now().subtract(Duration(days: 31));
      when(() => mockLocalDataSource.getReciters()).thenAnswer((_) async => testReciters);
      when(() => mockLocalDataSource.getLastUpdatedTimestamp()).thenReturn(Option.of(expiredDate));
      when(() => mockRemoteDataSource.getReciters(language: any(named: 'language')))
          .thenAnswer((_) async => testReciters);
      when(() => mockLocalDataSource.clearAllReciters()).thenAnswer((_) async {});
      when(() => mockLocalDataSource.saveReciters(any())).thenAnswer((_) async {});

      // Act
      final result = await reciteImpl.getAllReciters(language: 'en');

      // Assert
      verify(() => mockLocalDataSource.clearAllReciters()).called(1);
      verify(() => mockRemoteDataSource.getReciters(language: 'en')).called(1);
      // Verify saveReciters is called with merged reciters (nameAlternate populated)
      verify(() => mockLocalDataSource.saveReciters(mergedReciters)).called(1);
      expect(result, equals(mergedReciters));
    });

    group('getAllReciters with caching', () {
      final testReciters = [ReciterModel(1, 'Reciter 1', 'A', []), ReciterModel(2, 'Reciter 2', 'B', [])];
      // Expected reciters after merging with alternate language
      final mergedReciters = [
        ReciterModel(1, 'Reciter 1', 'A', [], 'Reciter 1'),
        ReciterModel(2, 'Reciter 2', 'B', [], 'Reciter 2'),
      ];

      test('fetches from remote when cache is empty', () async {
        // Arrange
        when(() => mockLocalDataSource.getReciters()).thenAnswer((_) async => []);
        when(() => mockLocalDataSource.getLastUpdatedTimestamp()).thenReturn(Option.of(DateTime.now()));
        when(() => mockRemoteDataSource.getReciters(language: any(named: 'language')))
            .thenAnswer((_) async => testReciters);
        when(() => mockLocalDataSource.clearAllReciters()).thenAnswer((_) async => Future<void>.value());
        when(() => mockLocalDataSource.saveReciters(any())).thenAnswer((_) async => Future<void>.value());

        // Act
        final result = await reciteImpl.getAllReciters(language: 'en');

        // Assert
        verify(() => mockRemoteDataSource.getReciters(language: 'en')).called(1);
        // Verify saveReciters is called with merged reciters (nameAlternate populated)
        verify(() => mockLocalDataSource.saveReciters(mergedReciters)).called(1);
        expect(result, equals(mergedReciters));
      });
    });

    test('returns cached data when remote fetch fails', () async {
      // Arrange
      when(() => mockLocalDataSource.getReciters()).thenAnswer((_) async => testReciters);
      when(() => mockLocalDataSource.getLastUpdatedTimestamp())
          .thenReturn(Option.of(DateTime.now().subtract(Duration(days: 31))));
      when(() => mockRemoteDataSource.getReciters(language: any(named: 'language')))
          .thenThrow(Exception('Network error'));
      when(() => mockLocalDataSource.clearAllReciters()).thenAnswer((_) async {});

      // Act
      final result = await reciteImpl.getAllReciters(language: 'en');

      // Assert
      verify(() => mockRemoteDataSource.getReciters(language: 'en')).called(1);
      expect(result, equals(testReciters));
    });

    test('throws exception when remote fails and cache is empty', () async {
      // Arrange
      when(() => mockLocalDataSource.getReciters()).thenAnswer((_) async => []);
      when(() => mockLocalDataSource.getLastUpdatedTimestamp())
          .thenReturn(Option.of(DateTime.now().subtract(Duration(days: 31))));
      when(() => mockRemoteDataSource.getReciters(language: any(named: 'language')))
          .thenThrow(Exception('Network error'));
      when(() => mockLocalDataSource.clearAllReciters()).thenAnswer((_) async {});

      // Act & Assert
      expect(
        () => reciteImpl.getAllReciters(language: 'en'),
        throwsA(isA<FetchRecitersFailedException>()),
      );
    });
  });
}
