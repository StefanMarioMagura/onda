import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/wave.dart';
import 'two_shores_sheet.dart';

/// One card of an onda, laid out like a page of a newspaper.
class WaveCardView extends StatelessWidget {
  const WaveCardView({
    super.key,
    required this.wave,
    required this.card,
    required this.step,
    required this.isLastWaveCard,
  });

  final Wave wave;
  final WaveCard card;
  final WaveStep step;
  final bool isLastWaveCard;

  @override
  Widget build(BuildContext context) {
    final color = wave.layer.color;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: wave.layer.etiqueta.toUpperCase(), style: OndaText.antetitulo(color: color)),
                    TextSpan(text: '   ${step.index + 1}/4 · ${step.label.toUpperCase()}',
                        style: OndaText.antetitulo()),
                  ]),
                ),
                const SizedBox(height: 14),
                Text(card.headline, style: OndaText.titular(step == WaveStep.whatHappened ? 36 : 30)),
                const SizedBox(height: 18),
                Text(card.body, style: OndaText.cuerpo(17, color: Palette.ink.withValues(alpha: 0.86))),
                if (card.figure != null) ...[
                  const SizedBox(height: 28),
                  _Figure(figure: card.figure!, color: color),
                ],
                if (card.actions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _Actions(actions: card.actions, color: color),
                ],
                if (wave.shores != null && step == WaveStep.whyItMatters) ...[
                  const SizedBox(height: 24),
                  _ShoresButton(onTap: () => showTwoShores(context, wave.shores!)),
                ],
                const Spacer(),
                const SizedBox(height: 24),
                if (card.teaser != null) _Teaser(text: card.teaser!),
                if (isLastWaveCard) const _Teaser(text: 'Desliza hacia arriba para la siguiente', up: true),
                const SizedBox(height: 14),
                Text('Fuente: ${wave.source}', style: OndaText.cuerpo(11, color: Palette.inkFaint)),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.figure, required this.color});
  final KeyFigure figure;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(figure.value, style: OndaText.cifra(64, color: color)),
          const SizedBox(height: 6),
          Text(figure.caption, style: OndaText.cuerpo(14, color: Palette.inkSoft)),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.actions, required this.color});
  final List<String> actions;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, action) in actions.indexed) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 32, child: Text('${i + 1}', style: OndaText.cifra(22, color: color))),
                Expanded(child: Text(action, style: OndaText.cuerpo(16))),
              ],
            ),
          ),
        ],
        const Divider(),
      ],
    );
  }
}

class _ShoresButton extends StatelessWidget {
  const _ShoresButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.ink,
        side: const BorderSide(color: Palette.ink),
        shape: const RoundedRectangleBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Las dos orillas', style: OndaText.cuerpo(15, weight: 600)),
          const SizedBox(width: 10),
          Text('cómo lo cuenta cada lado', style: OndaText.cuerpo(13, color: Palette.inkSoft)),
        ],
      ),
    );
  }
}

class _Teaser extends StatelessWidget {
  const _Teaser({required this.text, this.up = false});
  final String text;
  final bool up;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, style: OndaText.cuerpo(15, weight: 600))),
        Icon(up ? Icons.keyboard_arrow_up_rounded : Icons.arrow_forward_rounded, size: 20),
      ],
    );
  }
}
