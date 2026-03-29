import 'package:flutter_test/flutter_test.dart';
import 'package:labguard/src/features/about/domain/about_runtime_status.dart';

void main() {
  test('parses public service readiness payload', () {
    final status = AboutRuntimeStatus.fromJson(const {
      'status': 'ok',
      'service': 'labguard-api',
      'brandAttribution': 'Built by Emilo Labs',
      'timestamp': '2026-03-29T00:00:00.000Z',
      'readiness': {
        'stage': 'operator_preview',
        'summary': 'VPN regions are not ready yet.',
        'seededBootstrapActive': true,
        'vpnRegions': [
          {
            'regionCode': 'uk-lon',
            'name': 'UK — London',
            'locationLabel': 'London, United Kingdom',
            'ready': false,
            'availabilityState': 'not_configured',
            'availabilityMessage':
                'This region is reserved for this account but the live service is not configured yet.',
          },
        ],
      },
    });

    expect(status.reachable, isTrue);
    expect(status.stage, 'operator_preview');
    expect(status.vpnRegions.single.name, 'UK — London');
    expect(status.vpnRegions.single.ready, isFalse);
  });
}
