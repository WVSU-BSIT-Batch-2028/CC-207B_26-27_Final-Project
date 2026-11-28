import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/config/app_config.dart';
import 'package:littlesteps/config/external_links.dart';

void main() {
  group('AppConfig', () {
    test('validateForRelease is a no-op outside release mode', () {
      expect(AppConfig.validateForRelease, returnsNormally);
    });
  });

  group('ProvenanceLinkInfo.resolve', () {
    test('resolves DepEd MATATAG citations', () {
      final info = ProvenanceLinkInfo.resolve(
        'DepEd MATATAG Curriculum - Kindergarten (PDF pp. 18-19)',
      );
      expect(info.url, AppLinks.depedMatatag);
      expect(info.domainCaption, 'deped.gov.ph');
    });

    test('resolves ECCD Council NELF and NELC citations', () {
      expect(
        ProvenanceLinkInfo.resolve('ECCD Council NELF (2010)').url,
        AppLinks.eccdCouncil,
      );
      expect(
        ProvenanceLinkInfo.resolve('NELC LRP 3 (2015)').url,
        AppLinks.eccdCouncil,
      );
    });

    test('resolves WHO/UNICEF, CDC, and AAP citations', () {
      expect(
        ProvenanceLinkInfo.resolve('WHO & UNICEF Care for Child Development')
            .url,
        AppLinks.whoNurturingCare,
      );
      expect(
        ProvenanceLinkInfo.resolve('CDC Learn the Signs. Act Early.').url,
        AppLinks.cdcMilestones,
      );
      expect(
        ProvenanceLinkInfo.resolve('AAP Safe Sleep Policy').url,
        AppLinks.aapHealthyChildren,
      );
    });

    test('returns fallback metadata for unrecognized citations', () {
      final info = ProvenanceLinkInfo.resolve('Custom Caregiver Activity');
      expect(info.url, isNull);
      expect(info.frameworkTitle, 'Published early childhood guide');
    });
  });
}
