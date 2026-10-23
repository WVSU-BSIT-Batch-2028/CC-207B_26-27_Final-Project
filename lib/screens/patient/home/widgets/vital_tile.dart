import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../models/vital_sign.dart';
import '../../../../widgets/h360_card.dart';
import '../../../../widgets/sparkline.dart';

/// "Health at a Glance": vitals laid out two per row.
class VitalsGrid extends StatelessWidget {
  const VitalsGrid({super.key, required this.vitals});
  final List<VitalSign> vitals;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < vitals.length; i += 2) {
      final second = i + 1 < vitals.length ? VitalTile(vital: vitals[i + 1]) : const SizedBox.shrink();
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: VitalTile(vital: vitals[i])),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: second),
          ],
        ),
      );
      if (i + 2 < vitals.length) rows.add(const SizedBox(height: AppSpacing.md));
    }
    return Column(children: rows);
  }
}

class VitalTile extends StatelessWidget {
  const VitalTile({super.key, required this.vital});
  final VitalSign vital;

  Color get _color {
    switch (vital.type) {
      case VitalType.heartRate:
        return AppColors.heart;
      case VitalType.bloodPressure:
        return AppColors.pressure;
      case VitalType.weight:
        return AppColors.weight;
      case VitalType.sleep:
        return AppColors.sleep;
    }
  }

  IconData get _icon {
    switch (vital.type) {
      case VitalType.heartRate:
        return Icons.favorite_rounded;
      case VitalType.bloodPressure:
        return Icons.water_drop_rounded;
      case VitalType.weight:
        return Icons.monitor_weight_rounded;
      case VitalType.sleep:
        return Icons.bedtime_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final icon = Icon(_icon, size: 20, color: color);
    return H360Card(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: vital.type == VitalType.heartRate ? _Pulse(child: icon) : icon,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  vital.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  vital.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.navy),
                ),
              ),
              const SizedBox(width: 4),
              Text(vital.unit, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          Sparkline(values: vital.trend, color: color),
        ],
      ),
    );
  }
}

/// Gentle heartbeat animation for the heart-rate icon.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.9, end: 1.15).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}
