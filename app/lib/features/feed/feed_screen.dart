import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/sample_data.dart';
import '../../domain/discover.dart';
import '../../domain/rewards.dart';
import '../../domain/wave.dart';
import '../../state/rewards_state.dart';
import '../discover/discover_pages.dart';
import '../shared/celebration.dart';
import '../shared/top_bar.dart';
import 'milestone_page.dart';
import 'wave_card_view.dart';

/// The feed: today's ondas first, then a milestone, then "Descubre" with no end.
/// Vertical swipe moves between items; inside an onda, taps move between cards.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _pages = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() => _pages.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);

  void _waveFinished(Wave wave) {
    if (ref.read(rewardsProvider.notifier).claim('wave:${wave.id}', PointsRules.waveRead)) {
      celebrate(context, PointsRules.waveRead, label: 'Onda completada');
    }
    _next();
  }

  void _onPageChanged(int index, int waveCount) {
    setState(() => _current = index);
    if (index == waveCount &&
        ref.read(rewardsProvider.notifier).claim('milestone:today', PointsRules.dailyMilestone)) {
      celebrate(context, PointsRules.dailyMilestone, label: 'Día completado');
    }
  }

  @override
  Widget build(BuildContext context) {
    final waves = ref.watch(todayWavesProvider);
    final pool = ref.watch(discoverPoolProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          TopBar(trailing: _SectionLabel(index: _current, waveCount: waves.length)),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              scrollDirection: Axis.vertical,
              // No itemCount: after today's ondas the feed keeps going.
              onPageChanged: (i) => _onPageChanged(i, waves.length),
              itemBuilder: (context, i) {
                if (i < waves.length) {
                  return WavePage(
                    key: ValueKey(waves[i].id),
                    wave: waves[i],
                    onFinished: () => _waveFinished(waves[i]),
                  );
                }
                if (i == waves.length) return MilestonePage(wavesRead: waves.length);
                final next = discoverAt(pool, i - waves.length - 1);
                return DiscoverPage(key: ValueKey(next.key), item: next.item);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.index, required this.waveCount});
  final int index;
  final int waveCount;

  @override
  Widget build(BuildContext context) {
    final text = index < waveCount ? 'HOY ${index + 1}/$waveCount' : 'DESCUBRE';
    final color = index < waveCount ? Palette.text : Capa.descubre.color;
    return Text(text, maxLines: 1, overflow: TextOverflow.fade, softWrap: false,
        style: OndaText.etiqueta(color: color, size: 12));
  }
}

/// One onda: 4 cards with a segmented progress bar.
class WavePage extends StatefulWidget {
  const WavePage({super.key, required this.wave, required this.onFinished});
  final Wave wave;
  final VoidCallback onFinished;

  @override
  State<WavePage> createState() => _WavePageState();
}

class _WavePageState extends State<WavePage> {
  final _cards = PageController();
  int _card = 0;

  @override
  void dispose() {
    _cards.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final target = _card + delta;
    if (target >= widget.wave.cards.length) {
      widget.onFinished();
    } else if (target >= 0) {
      _cards.animateToPage(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wave = widget.wave;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepProgress(count: wave.cards.length, current: _card, color: wave.layer.color),
          const SizedBox(height: 18),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              // Story-style navigation: left third goes back, the rest goes forward.
              onTapUp: (details) {
                final width = context.size?.width ?? 1;
                _go(details.localPosition.dx < width / 3 ? -1 : 1);
              },
              child: PageView.builder(
                controller: _cards,
                itemCount: wave.cards.length,
                onPageChanged: (i) => setState(() => _card = i),
                itemBuilder: (context, i) => WaveCardView(
                  wave: wave,
                  card: wave.cards[i],
                  step: WaveStep.values[i],
                  isLastWaveCard: i == wave.cards.length - 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.count, required this.current, required this.color});
  final int count;
  final int current;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 4,
              decoration: BoxDecoration(
                color: i <= current ? color : Palette.line,
                borderRadius: BorderRadius.circular(2),
                boxShadow: i == current
                    ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                    : null,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
