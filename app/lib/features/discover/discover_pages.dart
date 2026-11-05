import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/discover.dart';
import '../../domain/rewards.dart';
import '../../state/rewards_state.dart';
import '../feed/wave_card_view.dart';
import '../shared/celebration.dart';
import '../shared/side_rail.dart';

/// One full-screen item of the endless "Descubre" stream.
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key, required this.item});
  final DiscoverItem item;

  @override
  Widget build(BuildContext context) {
    final body = switch (item) {
      StoryItem story => _Story(story: story),
      ClipItem clip => _Clip(clip: clip),
      QuizItem quiz => _Quiz(quiz: quiz),
      PredictionItem prediction => _PredictionView(item: prediction),
      FactItem fact => _Fact(fact: fact),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayerPill(label: 'Descubre · ${item.topic}', color: Capa.descubre.color),
          const SizedBox(height: 16),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Story extends StatelessWidget {
  const _Story({required this.story});
  final StoryItem story;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(right: 52),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (story.year != null)
                Text(
                  story.year!,
                  style: OndaText.cifra(80, color: Capa.descubre.color.withValues(alpha: 0.9)),
                ),
              const SizedBox(height: 6),
              Text(story.title, style: OndaText.impacto(40)),
              const SizedBox(height: 16),
              Text(story.body, style: OndaText.cuerpo(17, color: Palette.textSoft)),
              const SizedBox(height: 24),
              ListenButton(text: story.narration),
            ],
          ),
        ),
        Positioned(
          right: 0,
          bottom: 44,
          // The story has its own big listen button.
          child: SideRail(id: story.id, narration: story.narration, showListen: false),
        ),
      ],
    );
  }
}

/// A short clip of kinetic type: beats appear one after another and loop.
/// Tap to pause. Generated from text in the app, so no third-party video rights.
class _Clip extends StatefulWidget {
  const _Clip({required this.clip});
  final ClipItem clip;

  @override
  State<_Clip> createState() => _ClipState();
}

class _ClipState extends State<_Clip> {
  static const beatDuration = Duration(milliseconds: 1800);
  Timer? _timer;
  int _beat = 0;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer = Timer.periodic(beatDuration, (_) {
      setState(() => _beat = (_beat + 1) % widget.clip.beats.length);
    });
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _timer?.cancel();
    } else {
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final beats = widget.clip.beats;
    final text = beats[_beat];
    final isShort = text.length <= 8;
    return GestureDetector(
      onTap: _togglePause,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(color: Palette.surface, borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < beats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: i <= _beat ? Palette.text : Palette.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(widget.clip.title.toUpperCase(), style: OndaText.etiqueta()),
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(
                        begin: 0.85,
                        end: 1.0,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
                      child: child,
                    ),
                  ),
                  // Short beats are shown huge but never split mid-word.
                  child: FittedBox(
                    key: ValueKey(_beat),
                    fit: BoxFit.scaleDown,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isShort ? double.infinity : 320),
                      child: Text(
                        isShort ? text : text.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: isShort
                            ? OndaText.cifra(120, color: Palette.lime).copyWith(
                                shadows: [Shadow(color: Palette.lime.withValues(alpha: 0.5), blurRadius: 30)],
                              )
                            : OndaText.impacto(44),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Icon(
                  _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: Palette.textSoft,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _paused ? 'En pausa · toca para seguir' : 'Toca para pausar',
                    style: OndaText.cuerpo(12, color: Palette.textSoft),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Quiz extends ConsumerStatefulWidget {
  const _Quiz({required this.quiz});
  final QuizItem quiz;

  @override
  ConsumerState<_Quiz> createState() => _QuizState();
}

class _QuizState extends ConsumerState<_Quiz> {
  int? _picked;

  void _pick(int i) {
    if (_picked != null) return;
    setState(() => _picked = i);
    if (i == widget.quiz.correct &&
        ref.read(rewardsProvider.notifier).claim('quiz:${widget.quiz.id}', PointsRules.quizCorrect)) {
      celebrate(context, PointsRules.quizCorrect, label: '¡Correcto!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.quiz;
    final answered = _picked != null;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quiz.question, style: OndaText.impacto(40)),
          const SizedBox(height: 10),
          Text(
            '+${PointsRules.quizCorrect} si aciertas',
            style: OndaText.etiqueta(color: Palette.gold, size: 12),
          ),
          const SizedBox(height: 22),
          for (final (i, option) in quiz.options.indexed) ...[
            _Option(
              text: option,
              state: !answered
                  ? _OptionState.idle
                  : i == quiz.correct
                  ? _OptionState.correct
                  : i == _picked
                  ? _OptionState.wrong
                  : _OptionState.dimmed,
              onTap: () => _pick(i),
            ),
            const SizedBox(height: 10),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: answered
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _picked == quiz.correct ? '¡ACERTASTE!' : 'NO ERA ESA',
                          style: OndaText.impacto(
                            28,
                            color: _picked == quiz.correct ? Palette.verde : Palette.rojo,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(quiz.explanation, style: OndaText.cuerpo(16, color: Palette.textSoft)),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _Option extends StatelessWidget {
  const _Option({required this.text, required this.state, required this.onTap});
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (border, fill, icon) = switch (state) {
      _OptionState.idle => (Palette.line, Palette.surface, null),
      _OptionState.correct => (Palette.verde, Palette.verde.withValues(alpha: 0.12), Icons.check_rounded),
      _OptionState.wrong => (Palette.rojo, Palette.rojo.withValues(alpha: 0.12), Icons.close_rounded),
      _OptionState.dimmed => (Palette.line, Palette.surface.withValues(alpha: 0.5), null),
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: OndaText.cuerpo(
                  17,
                  weight: 600,
                  color: state == _OptionState.dimmed ? Palette.textFaint : Palette.text,
                ),
              ),
            ),
            if (icon != null) Icon(icon, color: border),
          ],
        ),
      ),
    );
  }
}

class _PredictionView extends ConsumerWidget {
  const _PredictionView({required this.item});
  final PredictionItem item;

  void _place(BuildContext context, WidgetRef ref, bool yes) {
    final rewards = ref.read(rewardsProvider.notifier);
    if (!rewards.canAfford(item.stake)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Necesitas ${item.stake} puntos. Completa ondas o acierta quizzes.')),
      );
      return;
    }
    rewards.spend(item.stake);
    ref.read(predictionsProvider.notifier).place(item.id, Prediction(stake: item.stake, saidYes: yes));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placed = ref.watch(predictionsProvider)[item.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.question, style: OndaText.impacto(44)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.gold.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Palette.gold, size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.stake} EN JUEGO', style: OndaText.cifra(24, color: Palette.gold)),
                    Text(
                      'Aciertas: ganas ${item.stake * 2}. Se resuelve ${item.resolvesOn} con el dato del Ministerio.',
                      style: OndaText.cuerpo(13, color: Palette.textSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (placed == null)
          Row(
            children: [
              Expanded(
                child: _BigChoice(label: 'SÍ', filled: true, onTap: () => _place(context, ref, true)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigChoice(label: 'NO', filled: false, onTap: () => _place(context, ref, false)),
              ),
            ],
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Palette.surfaceHigh, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TU PRONÓSTICO: ${placed.saidYes ? 'SÍ' : 'NO'}',
                  style: OndaText.impacto(28, color: Palette.lime),
                ),
                const SizedBox(height: 4),
                Text(
                  'Si aciertas, ${placed.stake * 2} puntos. Te avisamos ${item.resolvesOn}.',
                  style: OndaText.cuerpo(15, color: Palette.textSoft),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _BigChoice extends StatelessWidget {
  const _BigChoice({required this.label, required this.filled, required this.onTap});
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? Palette.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.lime, width: 2),
        ),
        child: Text(label, style: OndaText.impacto(34, color: filled ? Palette.night : Palette.lime)),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.fact});
  final FactItem fact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            fact.figure,
            style: OndaText.cifra(
              140,
              color: Palette.lime,
            ).copyWith(shadows: [Shadow(color: Palette.lime.withValues(alpha: 0.45), blurRadius: 36)]),
          ),
        ),
        const SizedBox(height: 12),
        Text(fact.text, style: OndaText.cuerpo(22, weight: 600)),
        const SizedBox(height: 16),
        Text('Fuente: ${fact.source}', style: OndaText.cuerpo(12, color: Palette.textFaint)),
      ],
    );
  }
}
