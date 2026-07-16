import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_satellite/config/feature_flags.dart';

void main() {
  tearDown(() {
    FeatureFlags.debugReleaseOverride = null;
    FeatureFlags.debugPlatformOverride = null;
  });

  group('FeatureFlags gate', () {
    test('в debug гейт игнорируется — фичи доступны даже на Android', () {
      FeatureFlags.debugReleaseOverride = false;
      FeatureFlags.debugPlatformOverride = TargetPlatform.android;

      expect(FeatureFlags.isGateActive, isFalse);
      expect(FeatureFlags.isEnabled(Feature.cloudSync), isTrue);
      expect(FeatureFlags.isEnabled(Feature.userCity), isTrue);
    });

    test('release + Android — гейт активен, фичи скрыты', () {
      FeatureFlags.debugReleaseOverride = true;
      FeatureFlags.debugPlatformOverride = TargetPlatform.android;

      expect(FeatureFlags.isGateActive, isTrue);
      expect(FeatureFlags.isEnabled(Feature.cloudSync), isFalse);
      expect(FeatureFlags.isEnabled(Feature.userCity), isFalse);
    });

    test('release, но не Android — гейт игнорируется', () {
      FeatureFlags.debugReleaseOverride = true;
      FeatureFlags.debugPlatformOverride = TargetPlatform.iOS;

      expect(FeatureFlags.isGateActive, isFalse);
      expect(FeatureFlags.isEnabled(Feature.cloudSync), isTrue);
      expect(FeatureFlags.isEnabled(Feature.userCity), isTrue);
    });
  });
}
