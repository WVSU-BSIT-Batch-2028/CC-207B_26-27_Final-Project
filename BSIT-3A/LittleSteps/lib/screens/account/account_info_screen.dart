import 'package:flutter/material.dart';

import '../../config/external_links.dart';
import '../../theme/app_tokens.dart';
import '../../utils/url_helper.dart';
import '../../widgets/responsive_layout.dart';

/// Describes the account information page to display.
enum AccountInfoPage {
  /// Data collection, retention, and caregiver choices notice.
  privacy,

  /// Product overview, non-diagnostic notice, and clinical framework sources.
  about,

  /// Usage guidance, concern escalation, and project support channels.
  help,
}

/// Privacy, about, and help screens.
class AccountInfoScreen extends StatelessWidget {
  /// Creates an [AccountInfoScreen] for [page].
  const AccountInfoScreen({super.key, required this.page});

  /// The informational page variant to render.
  final AccountInfoPage page;

  String get _title => switch (page) {
    AccountInfoPage.privacy => 'Privacy notice',
    AccountInfoPage.about => 'About LittleSteps',
    AccountInfoPage.help => 'Help and support',
  };

  List<_InfoSection> get _sections => switch (page) {
    AccountInfoPage.privacy => const [
      _InfoSection(
        'What we collect',
        'LittleSteps stores the caregiver account, child profile details, '
            'activity plans, observations and journal notes needed to provide '
            'the app features.',
      ),
      _InfoSection(
        'Why we use it',
        'We use this information to show age-aware activities, keep your '
            'plans and notes together, and help you review what you have '
            'observed over time.',
      ),
      _InfoSection(
        'What stays private',
        'Journal notes are not sent with play-idea requests. The Idea helper '
            'receives the age band, time, setting and materials you choose so '
            'it can suggest an activity. A story activity request includes '
            'the book title, subjects and age band.',
      ),
      _InfoSection(
        'The Idea helper',
        'Suggestions are for play ideas only. They are not a developmental '
            'assessment. LittleSteps does not use them to compare children.',
      ),
      _InfoSection(
        'How long we keep it',
        'Your information stays in your account until you delete it. When you '
            'delete a child or your account, the related records are removed.',
      ),
      _InfoSection(
        'Your choices',
        'You can download a copy of your data, delete a child’s records, or '
            'delete your account from Settings.',
      ),
    ],
    AccountInfoPage.about => const [
      _InfoSection(
        'What it is',
        'LittleSteps helps caregivers find simple play ideas, make a plan, '
            'and keep notes about everyday moments with a young child.',
      ),
      _InfoSection(
        'What it is not',
        'LittleSteps is not a medical service or a developmental assessment. '
            'Children develop at different rates. Talk to a health '
            'professional if you have concerns.',
      ),
      _InfoSection(
        'Where content comes from',
        'Activities and milestone prompts are grounded in published pediatric '
            'and early childhood frameworks:',
        links: [
          _ExternalResourceLink(
            title: 'CDC Developmental Milestones (Learn the Signs. Act Early.)',
            domainLabel: 'cdc.gov',
            url: AppLinks.cdcMilestones,
          ),
          _ExternalResourceLink(
            title: 'American Academy of Pediatrics (AAP)',
            domainLabel: 'healthychildren.org',
            url: AppLinks.aapHealthyChildren,
          ),
          _ExternalResourceLink(
            title:
                'WHO Nurturing Care Framework for Early Childhood Development',
            domainLabel: 'nurturing-care.org',
            url: AppLinks.whoNurturingCare,
          ),
          _ExternalResourceLink(
            title: 'Philippine Early Learning Standards (ECCD Council)',
            domainLabel: 'eccdcouncil.gov.ph',
            url: AppLinks.eccdCouncil,
          ),
          _ExternalResourceLink(
            title: 'DepEd MATATAG Kindergarten Curriculum',
            domainLabel: 'deped.gov.ph',
            url: AppLinks.depedMatatag,
          ),
        ],
      ),
      _InfoSection(
        'Who made LittleSteps',
        'LittleSteps is a caregiver support project created by the Thesis '
            'Titans team for the CC 207B final project at West Visayas State '
            'University.',
      ),
    ],
    AccountInfoPage.help => const [
      _InfoSection(
        'How LittleSteps works',
        'Choose a child, explore activities that fit their age band, and add '
            'ideas to your plan. You can record observations and private '
            'journal notes as you go.',
      ),
      _InfoSection(
        'Saving and retrying',
        'Your changes need a connection to save. If a request does not '
            'complete, reconnect and try again. Check the screen for a '
            'confirmation before repeating a delete action.',
      ),
      _InfoSection(
        'Privacy and the Idea helper',
        'The Idea helper uses the activity details you provide to suggest '
            'play. It does not receive your private journal notes. Read the '
            'Privacy notice for more information.',
      ),
      _InfoSection(
        'Worried about your child?',
        'Children develop at different rates. Talk to a health professional '
            'if you have concerns.',
      ),
      _InfoSection(
        'Contact us',
        'For help or feedback with LittleSteps, reach the Thesis Titans team '
            'on GitHub:',
        links: [
          _ExternalResourceLink(
            title: 'Thesis Titans on GitHub',
            domainLabel: 'github.com/Thesis-Titans',
            url: AppLinks.githubOrg,
          ),
        ],
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ResponsiveContentBox(
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.space16),
          itemCount: _sections.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: AppSpacing.space12),
          itemBuilder: (context, index) =>
              _InfoSectionCard(section: _sections[index]),
        ),
      ),
    );
  }
}

class _ExternalResourceLink {
  const _ExternalResourceLink({
    required this.title,
    required this.domainLabel,
    required this.url,
  });

  final String title;
  final String domainLabel;
  final String url;
}

class _InfoSection {
  const _InfoSection(this.title, this.body, {this.links = const []});

  final String title;
  final String body;
  final List<_ExternalResourceLink> links;
}

class _InfoSectionCard extends StatelessWidget {
  const _InfoSectionCard({required this.section});

  final _InfoSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.space16,
              AppSpacing.space16,
              AppSpacing.space16,
              section.links.isEmpty ? AppSpacing.space16 : AppSpacing.space12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.space8),
                Text(section.body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          if (section.links.isNotEmpty) ...[
            const Divider(height: 1),
            for (var index = 0; index < section.links.length; index++) ...[
              if (index > 0) const Divider(height: 1),
              Semantics(
                link: true,
                hint: 'Opens external website',
                child: ListTile(
                  minTileHeight: AppSizes.touchTarget,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space16,
                    vertical: AppSpacing.space4,
                  ),
                  title: Text(
                    section.links[index].title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    section.links[index].domainLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.forest,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: AppColors.forest,
                  ),
                  onTap: () =>
                      openExternalUrl(context, section.links[index].url),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
