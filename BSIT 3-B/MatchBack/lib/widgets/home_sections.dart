import 'package:flutter/material.dart';

import '../screens/ai_match_screen.dart';
import '../screens/browse_reports_screen.dart';
import '../screens/claim_screen.dart';
import '../screens/found_report_screen.dart';
import '../screens/lost_report_screen.dart';
import '../screens/my_claims_screen.dart';
import '../screens/staff_claims_screen.dart';
import '../theme/paper_theme.dart';
import 'home_parts.dart';
import 'paper_widgets.dart';

/// The content of each page section. [open] pushes a screen.
class HomeSections {
  const HomeSections(this.open, {this.isStaff = true});

  final void Function(Widget screen) open;
  final bool isStaff;

  // Hero

  Widget hero(bool wide) {
    final headline = Paper.display(wide ? 46 : 30);

    return Column(
      children: [
        Text('welcome to', style: Paper.hand(28)),
        const SizedBox(height: 8),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 44 : 20,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Paper.tomato, width: 2.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('MatchBack', style: Paper.display(wide ? 104 : 52)),
            ),
            const Positioned(
              top: -24,
              left: -12,
              child: TornLabel('LOST & FOUND', color: Paper.mint, angle: -0.06),
            ),
            const Positioned(
              bottom: -24,
              right: -12,
              child: TornLabel(
                'STAFF VERIFIED',
                color: Paper.mustard,
                angle: 0.05,
              ),
            ),
          ],
        ),
        const SizedBox(height: 64),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text("Lost it? Let's ", style: headline),
            Scribble(child: Text('match', style: headline)),
            Text(' it back.', style: headline),
          ],
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Report lost or found items, receive AI-assisted match suggestions, '
            'and follow the verified claim process.',
            textAlign: TextAlign.center,
            style: Paper.body(17),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          runSpacing: 18,
          children: [
            PaperButton(
              label: 'Report Lost Item',
              icon: Icons.search_rounded,
              onPressed: () => open(const LostReportScreen()),
            ),
            PaperButton(
              label: 'Report Found Item',
              icon: Icons.add_circle_outline_rounded,
              onPressed: () => open(const FoundReportScreen()),
            ),
            PaperButton(
              label: 'Browse Reports',
              icon: Icons.grid_view_rounded,
              fill: Colors.white,
              textColor: Paper.ink,
              onPressed: () => open(const BrowseReportsScreen()),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('scroll for the short version', style: Paper.hand(26)),
            const SizedBox(width: 6),
            const DoodleArrow(),
          ],
        ),
      ],
    );
  }

  // How it works

  Widget how(bool wide) {
    Widget step(
      String n,
      String title,
      String text,
      Color color,
      double angle,
    ) {
      return SizedBox(
        width: 310,
        child: StickyNote(
          color: color,
          angle: angle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n, style: Paper.mono(13)),
              const SizedBox(height: 6),
              Text(title, style: Paper.display(30)),
              const SizedBox(height: 10),
              Text(text, style: Paper.hand(24)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading('the short version', 'How it works', wide),
        const SizedBox(height: 44),
        Wrap(
          spacing: 36,
          runSpacing: 40,
          children: [
            step(
              '01',
              'Report',
              'Lost or found something? Describe it in a minute. Keep personal details out of public descriptions.',
              Paper.mustard,
              -0.03,
            ),
            step(
              '02',
              'Match',
              'Browse reports, or ask the AI matcher for possible matches based on public descriptions.',
              Paper.mint,
              0.025,
            ),
            step(
              '03',
              'Claim',
              'Submit a claim with a private detail. Staff verify it before anything is handed back.',
              Paper.blush,
              -0.02,
            ),
          ],
        ),
      ],
    );
  }

  // Get started

  Widget actions(bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Paper.ink, width: 1.4),
            borderRadius: BorderRadius.circular(4),
            color: Colors.white,
          ),
          child: Text('pick a path', style: Paper.hand(26)),
        ),
        const SizedBox(height: 14),
        Text('How can we help?', style: Paper.display(wide ? 54 : 38)),
        const SizedBox(height: 8),
        Text(
          'Choose an action to manage a lost-and-found report.',
          style: Paper.body(16),
        ),
        const SizedBox(height: 40),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 640 ? 2 : 1;
            final w = (c.maxWidth - 28 * (cols - 1)) / cols;
            return Wrap(
              spacing: 28,
              runSpacing: 36,
              children: [
                SizedBox(
                  width: w,
                  child: ActionCard(
                    tab: 'OPTION 01',
                    color: Paper.mint,
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Report Found Item',
                    text: 'Help return an item you found on campus.',
                    cta: 'Create Report',
                    angle: -0.012,
                    onTap: () => open(const FoundReportScreen()),
                  ),
                ),
                SizedBox(
                  width: w,
                  child: ActionCard(
                    tab: 'OPTION 02',
                    color: Paper.mustard,
                    icon: Icons.manage_search_rounded,
                    title: 'Browse Reports',
                    text: 'Search and filter active lost-and-found reports.',
                    cta: 'Browse Items',
                    angle: 0.01,
                    onTap: () => open(const BrowseReportsScreen()),
                  ),
                ),
                SizedBox(
                  width: w,
                  child: ActionCard(
                    tab: 'OPTION 03',
                    color: Paper.blush,
                    icon: Icons.verified_user_outlined,
                    title: 'Submit a Claim',
                    text: 'Request staff verification before an item is returned.',
                    cta: 'Start a Claim',
                    angle: 0.012,
                    onTap: () => open(const ClaimScreen()),
                  ),
                ),
                SizedBox(
                  width: w,
                  child: ActionCard(
                    tab: 'OPTION 04',
                    color: Paper.sky,
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'My Claim Status',
                    text: 'Check whether your claim is pending or completed.',
                    cta: 'View My Claims',
                    angle: -0.01,
                    onTap: () => open(const MyClaimsScreen()),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // AI match

  Widget ai(bool wide) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI MATCH SUGGESTIONS',
          style: Paper.mono(12, color: Paper.mustard),
        ),
        const SizedBox(height: 14),
        Text(
          'Let the matcher do the digging.',
          style: Paper.display(wide ? 44 : 32, color: Colors.white),
        ),
        const SizedBox(height: 14),
        Text(
          'Compare item descriptions for possible matches. It only suggests; staff still verify ownership.',
          style: Paper.body(16, color: const Color(0xFFD8D0C4)),
        ),
        const SizedBox(height: 28),
        PaperButton(
          label: 'Find Matches',
          icon: Icons.auto_awesome_rounded,
          fill: Paper.mustard,
          textColor: Paper.ink,
          onPressed: () => open(const AiMatchScreen()),
        ),
      ],
    );

    final note = StickyNote(
      color: Paper.mint,
      angle: 0.035,
      width: 270,
      child: Text(
        'The AI only sees public descriptions. Your private details stay private.',
        style: Paper.hand(26),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(wide ? 44 : 28),
          decoration: const BoxDecoration(
            color: Paper.ink,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(28),
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 14,
                offset: Offset(4, 8),
              ),
            ],
          ),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: 40),
                    note,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [text, const SizedBox(height: 32), note],
                ),
        ),
        const Positioned(
          top: -10,
          left: 30,
          child: Tape(angle: -0.1, width: 90),
        ),
        const Positioned(
          top: -10,
          right: 30,
          child: Tape(angle: 0.09, width: 90),
        ),
      ],
    );
  }

  // Contact

  Widget contact(bool wide) {
    final privacy = StickyNote(
      color: Paper.mustard,
      angle: -0.02,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PRIVACY REMINDER', style: Paper.mono(12)),
          const SizedBox(height: 10),
          Text(
            'Do not place student IDs, phone numbers, or other personal details in public item descriptions.',
            style: Paper.hand(27),
          ),
        ],
      ),
    );

    final staff = HoverLift(
      angle: 0.01,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Paper.ink, width: 1.6),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(8),
          ),
          boxShadow: const [BoxShadow(color: Paper.ink, offset: Offset(5, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'for the lost-and-found office',
              style: Paper.hand(26, color: Paper.tomato),
            ),
            const SizedBox(height: 6),
            Text('Staff Review', style: Paper.display(32)),
            const SizedBox(height: 10),
            Text(
              'Review claims, mark items ready for collection, and record '
              'the handover.',
              style: Paper.body(15.5),
            ),
            const SizedBox(height: 22),
            PaperButton(
              label: 'Open Staff Review',
              icon: Icons.admin_panel_settings_outlined,
              onPressed: () => open(const StaffClaimsScreen()),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading('before you go', 'Good to know', wide),
        const SizedBox(height: 44),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: privacy),
              if (isStaff) ...[
                const SizedBox(width: 48),
                Expanded(child: staff),
              ],
            ],
          )
        else
          Column(
            children: [
              privacy,
              if (isStaff) ...[const SizedBox(height: 40), staff],
            ],
          ),
      ],
    );
  }

  Widget footer() {
    return Container(
      width: double.infinity,
      color: Paper.ink,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          Text(
            'MATCHBACK | CAMPUS LOST AND FOUND',
            style: Paper.mono(12, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'keep it, find it, match it back.',
            style: Paper.hand(24, color: Paper.mustard),
          ),
        ],
      ),
    );
  }
}
