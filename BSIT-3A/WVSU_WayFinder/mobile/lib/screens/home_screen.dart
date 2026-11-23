import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../core/time.dart';
import '../data/schedule.dart';

class SearchField extends StatefulWidget {
  const SearchField({super.key, this.initial = '', this.autofocus = false});
  final String initial;
  final bool autofocus;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final q = value.trim();
    if (q.isNotEmpty) context.go('/search?q=${Uri.encodeQueryComponent(q)}');
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        onSubmitted: _submit,
        decoration: InputDecoration(
          hintText: 'Search rooms, offices, buildings',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
        ),
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final quick = [
      ('Campus Map', Icons.map_outlined, '/map'),
      ('Process Documents', Icons.description_outlined, '/processes'),
      ('Find a Teacher', Icons.apartment_outlined, '/directory'),
      ('Ask WayFinder', Icons.chat_bubble_outline, '/guide'),
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('WVSU WAYFINDER', style: TextStyle(fontSize: 12, letterSpacing: 1.4, color: wayBlue, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      const Text('Hi! Where do you need to go?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15)),
      const SizedBox(height: 14),
      const SearchField(),
      const SizedBox(height: 8),
      const NextClassCard(),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: [
          for (final (label, icon, route) in quick)
            Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.go(route),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: wayBlue, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.white, size: 20)),
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    ]);
  }
}

/// When, what, who, which room, and where to tap — the first thing on Home.
class NextClassCard extends StatefulWidget {
  const NextClassCard({super.key, this.now});
  final DateTime Function()? now;

  @override
  State<NextClassCard> createState() => _NextClassCardState();
}

class _NextClassCardState extends State<NextClassCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).schedule;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = (widget.now ?? appClock)();
        final next = nextClass(store.classes, now);
        if (next == null) {
          return Card(
            color: blueSoft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _Label(Icons.calendar_today_outlined, 'MY SCHEDULE'),
                const SizedBox(height: 6),
                const Text('See your next class here', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Upload your IUIS schedule or COR. WayFinder fills in your classes and shows the next room and professor.', style: TextStyle(color: muted)),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: () => context.go('/schedule/import'), child: const Text('Add my Schedule'))),
                TextButton(onPressed: () => context.go('/schedule'), child: const Text('My Schedule')),
              ]),
            ),
          );
        }
        final s = next.session;
        return Card(
          key: const ValueKey('next-class'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: _Label(Icons.calendar_today_outlined, 'NEXT CLASS · ${weekdays[s.weekday - 1].toUpperCase()}')),
                TextButton(onPressed: () => context.go('/schedule'), child: const Text('My Schedule')),
              ]),
              Text(s.subject, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                const Icon(Icons.schedule, size: 16, color: muted),
                Text('${formatClock(s.start)}–${formatClock(s.end)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: goldSoft, borderRadius: BorderRadius.circular(99), border: Border.all(color: gold)),
                  child: Text(relativeStart(next.start, next.end, now), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: blueSoft, borderRadius: BorderRadius.circular(12)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  const Text('ROOM  ', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: muted, fontWeight: FontWeight.w700)),
                  Flexible(child: Text(s.roomCodeRaw.isEmpty ? 'Room not specified' : s.roomCodeRaw, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: navy))),
                ]),
              ),
              if (s.roomPlaceId == null) ...[const SizedBox(height: 8), const Unconfirmed('Room location unconfirmed')],
              if (s.professor != null) ...[
                const SizedBox(height: 10),
                Row(children: [const Icon(Icons.person_outline, size: 18, color: muted), const SizedBox(width: 6), Expanded(child: Text(s.professor!))]),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: s.roomCodeRaw.isEmpty ? null : () => context.go(s.roomPlaceId != null ? '/map?to=${Uri.encodeQueryComponent(s.roomPlaceId!)}' : '/search?q=${Uri.encodeQueryComponent(s.roomCodeRaw)}'),
                  icon: const Icon(Icons.place_outlined, size: 18),
                  label: const Text('Find room'),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 15, color: wayBlue),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: const TextStyle(fontSize: 11, letterSpacing: .8, color: wayBlue, fontWeight: FontWeight.w700))),
      ]);
}

/// Gold dashed-style note for unconfirmed locations.
class Unconfirmed extends StatelessWidget {
  const Unconfirmed(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: goldSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: gold)),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      );
}
