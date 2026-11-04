import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/sample_data.dart';
import '../../domain/wave.dart';
import 'end_of_feed.dart';
import 'wave_card_view.dart';

/// Today's ondas: vertical swipe between ondas, tap or horizontal swipe between
/// the 4 cards of each one. The feed ends: after the last onda comes a closing
/// screen and nothing else (docs/diseno/principios.md).
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

  void _nextWave() => _pages.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final waves = ref.watch(todayWavesProvider);
    final finished = _current >= waves.length;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _Masthead(position: _current, total: waves.length, finished: finished),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              scrollDirection: Axis.vertical,
              itemCount: waves.length + 1,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (context, i) => i < waves.length
                  ? WavePage(key: ValueKey(waves[i].id), wave: waves[i], onFinished: _nextWave)
                  : EndOfFeed(wavesRead: waves.length),
            ),
          ),
        ],
      ),
    );
  }
}

/// Newspaper-style header: wordmark, date and position in today's edition.
class _Masthead extends StatelessWidget {
  const _Masthead({required this.position, required this.total, required this.finished});
  final int position;
  final int total;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Onda', style: OndaText.titular(24)),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(spanishDate(DateTime.now()),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: OndaText.cuerpo(12, color: Palette.inkSoft)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  finished ? 'Completado' : '${position + 1} de $total',
                  style: OndaText.cuerpo(12, weight: 600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Palette.ink, thickness: 1.5, height: 1.5),
          if (usingSampleData)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('CONTENIDO DE EJEMPLO', style: OndaText.antetitulo(color: Palette.inkFaint)),
              ),
            ),
        ],
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
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
              height: 3,
              color: i <= current ? color : Palette.rule,
            ),
          ),
        ],
      ],
    );
  }
}

const _weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _months = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// "Miércoles, 4 de noviembre".
String spanishDate(DateTime d) {
  final weekday = _weekdays[d.weekday - 1];
  return '${weekday[0].toUpperCase()}${weekday.substring(1)}, ${d.day} de ${_months[d.month - 1]}';
}
