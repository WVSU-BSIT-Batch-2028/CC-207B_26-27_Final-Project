import 'package:littlesteps/models/milestone.dart';

/// Sample milestone prompts used exclusively by widget tests.
const List<MilestonePrompt> sampleMilestonePrompts = [
  MilestonePrompt(
    id: 'lan-12-01',
    domain: MilestoneDomain.language,
    title: 'Points to familiar objects when named',
    lookFor: [
      'Points at the ball when you say "ball"',
      'Looks toward a named person',
    ],
    ageBand: '12-23 months',
    provenance: 'Source: AAP & CDC Early Communication Guidelines',
  ),
  MilestonePrompt(
    id: 'cog-12-01',
    domain: MilestoneDomain.cognitive,
    title: 'Finds a hidden toy',
    lookFor: [
      'Watches where you hide an item under a cloth or cup',
      'Uncovers or reaches directly for the hidden toy',
    ],
    ageBand: '12-23 months',
    provenance: 'Source: CDC Developmental Milestones (12-23m)',
  ),
  MilestonePrompt(
    id: 'mot-12-01',
    domain: MilestoneDomain.motor,
    title: 'Takes a few steps independently',
    lookFor: ['Walks a few paces without holding onto furniture or hands'],
    ageBand: '12-23 months',
    provenance: 'Source: CDC Developmental Milestones (12-23m)',
  ),
  MilestonePrompt(
    id: 'soc-12-01',
    domain: MilestoneDomain.socioEmotional,
    title: 'Enjoys a back-and-forth moment during play',
    lookFor: [
      'Passes a toy back and forth with you',
      'Smiles or responds when taking turns',
    ],
    ageBand: '12-23 months',
    provenance: 'Source: WHO & UNICEF Nurturing Care Framework',
  ),
  MilestonePrompt(
    id: 'lan-60-01',
    domain: MilestoneDomain.language,
    title: 'Retells familiar stories and notices starting sounds',
    lookFor: [
      'Retells a short story with a beginning, middle, and end',
      'Spots everyday words that start with the same sound',
    ],
    ageBand: '60-71 months',
    provenance: 'Source: DepEd MATATAG Curriculum - Kindergarten (Literacy)',
  ),
];
