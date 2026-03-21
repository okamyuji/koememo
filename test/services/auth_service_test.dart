import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/services/auth_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<LocalAuthentication>()])
import 'auth_service_test.mocks.dart';

void main() {
  late MockLocalAuthentication mockLocalAuth;
  late AuthService authService;

  setUp(() {
    mockLocalAuth = MockLocalAuthentication();
    authService = AuthService(localAuth: mockLocalAuth);
  });

  group('AuthService', () {
    test('authenticate returns true on success', () async {
      when(
        mockLocalAuth.authenticate(
          localizedReason: anyNamed('localizedReason'),
          biometricOnly: anyNamed('biometricOnly'),
          persistAcrossBackgrounding: anyNamed('persistAcrossBackgrounding'),
        ),
      ).thenAnswer((_) async => true);

      final result = await authService.authenticate();
      expect(result, isTrue);
    });

    test('authenticate returns false on failure', () async {
      when(
        mockLocalAuth.authenticate(
          localizedReason: anyNamed('localizedReason'),
          biometricOnly: anyNamed('biometricOnly'),
          persistAcrossBackgrounding: anyNamed('persistAcrossBackgrounding'),
        ),
      ).thenAnswer((_) async => false);

      final result = await authService.authenticate();
      expect(result, isFalse);
    });

    test('authenticate returns false on exception', () async {
      when(
        mockLocalAuth.authenticate(
          localizedReason: anyNamed('localizedReason'),
          biometricOnly: anyNamed('biometricOnly'),
          persistAcrossBackgrounding: anyNamed('persistAcrossBackgrounding'),
        ),
      ).thenThrow(Exception('biometric error'));

      final result = await authService.authenticate();
      expect(result, isFalse);
    });

    test('isBiometricAvailable returns true when supported', () async {
      when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
      when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);

      final result = await authService.isBiometricAvailable();
      expect(result, isTrue);
    });

    test('isBiometricAvailable returns false when not supported', () async {
      when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => false);
      when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);

      final result = await authService.isBiometricAvailable();
      expect(result, isFalse);
    });
  });
}
