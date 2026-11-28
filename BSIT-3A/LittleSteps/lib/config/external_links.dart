import 'package:flutter/foundation.dart';

/// External reference, attribution, and support URLs used across LittleSteps.
abstract final class AppLinks {
  /// Philippine Early Childhood Care and Development (ECCD) Council portal.
  static const String eccdCouncil = 'https://eccdcouncil.gov.ph';

  /// DepEd MATATAG Kindergarten Curriculum portal.
  static const String depedMatatag =
      'https://www.deped.gov.ph/matatagcurriculumk147/';

  /// US CDC Learn the Signs. Act Early. developmental milestone portal.
  static const String cdcMilestones =
      'https://www.cdc.gov/ncbddd/actearly/milestones/';

  /// WHO and UNICEF Nurturing Care Framework portal.
  static const String whoNurturingCare = 'https://nurturing-care.org';

  /// American Academy of Pediatrics caregiver guidance portal.
  static const String aapHealthyChildren = 'https://www.healthychildren.org';

  /// Open-Meteo weather data attribution website.
  static const String openMeteo = 'https://open-meteo.com';

  /// Project organization repository page for support and feedback.
  static const String githubOrg = 'https://github.com/Thesis-Titans';
}

/// Resolved presentation metadata for an external framework citation.
@immutable
class ProvenanceLinkInfo {
  /// Creates a [ProvenanceLinkInfo].
  const ProvenanceLinkInfo({
    required this.frameworkTitle,
    this.url,
    this.buttonLabel,
    this.domainCaption,
  });

  /// Human-readable title of the published early childhood framework.
  final String frameworkTitle;

  /// Optional external URL for the issuing organization or guide.
  final String? url;

  /// Optional label for the action button that opens [url].
  final String? buttonLabel;

  /// Optional short domain label shown beneath the button.
  final String? domainCaption;

  /// Resolves a citation string [provenanceSource] to link metadata.
  static ProvenanceLinkInfo resolve(String provenanceSource) {
    if (provenanceSource.contains('MATATAG') ||
        provenanceSource.contains('DepEd')) {
      return const ProvenanceLinkInfo(
        frameworkTitle: 'DepEd MATATAG Kindergarten Curriculum',
        url: AppLinks.depedMatatag,
        buttonLabel: 'Visit DepEd MATATAG portal',
        domainCaption: 'deped.gov.ph',
      );
    }
    if (provenanceSource.contains('NELF')) {
      return const ProvenanceLinkInfo(
        frameworkTitle: 'Philippine National Early Learning Framework (NELF)',
        url: AppLinks.eccdCouncil,
        buttonLabel: 'Visit ECCD Council website',
        domainCaption: 'eccdcouncil.gov.ph',
      );
    }
    if (provenanceSource.contains('NELC')) {
      return const ProvenanceLinkInfo(
        frameworkTitle: 'Philippine National Early Learning Curriculum (NELC)',
        url: AppLinks.eccdCouncil,
        buttonLabel: 'Visit ECCD Council website',
        domainCaption: 'eccdcouncil.gov.ph',
      );
    }
    if (provenanceSource.contains('ECCD')) {
      return const ProvenanceLinkInfo(
        frameworkTitle: 'Early Childhood Care and Development (ECCD) Council',
        url: AppLinks.eccdCouncil,
        buttonLabel: 'Visit ECCD Council website',
        domainCaption: 'eccdcouncil.gov.ph',
      );
    }
    if (provenanceSource.contains('CDC')) {
      return const ProvenanceLinkInfo(
        frameworkTitle: 'CDC Developmental Milestones',
        url: AppLinks.cdcMilestones,
        buttonLabel: 'Visit CDC website',
        domainCaption: 'cdc.gov',
      );
    }
    if (provenanceSource.contains('WHO') ||
        provenanceSource.contains('UNICEF')) {
      return const ProvenanceLinkInfo(
        frameworkTitle: 'WHO & UNICEF Nurturing Care Framework',
        url: AppLinks.whoNurturingCare,
        buttonLabel: 'Visit Nurturing Care website',
        domainCaption: 'nurturing-care.org',
      );
    }
    if (provenanceSource.contains('AAP')) {
      return const ProvenanceLinkInfo(
        frameworkTitle: 'American Academy of Pediatrics (AAP)',
        url: AppLinks.aapHealthyChildren,
        buttonLabel: 'Visit AAP website',
        domainCaption: 'healthychildren.org',
      );
    }
    return const ProvenanceLinkInfo(
      frameworkTitle: 'Published early childhood guide',
    );
  }
}
