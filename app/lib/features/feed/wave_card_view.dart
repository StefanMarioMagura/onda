import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/wave.dart';
import '../shared/side_rail.dart';
import '../shared/vote_dial.dart';
import 'two_shores_sheet.dart';

/// One card of an onda.
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
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.only(right: 52),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          LayerPill(label: wave.layer.etiqueta, color: color),
                          Text('${step.index + 1}/4 · ${step.label.toUpperCase()}', style: OndaText.etiqueta()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(card.headline, style: OndaText.impacto(step == WaveStep.whatHappened ? 46 : 38)),
                      const SizedBox(height: 16),
                      Text(card.body, style: OndaText.cuerpo(17, color: Palette.textSoft)),
                      if (card.figure != null) ...[
                        const SizedBox(height: 26),
                        BigFigure(value: card.figure!.value, caption: card.figure!.caption, color: color),
                      ],
                      if (card.actions.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _Actions(actions: card.actions, color: color),
                      ],
                      if (isLastWaveCard) ...[
                        const SizedBox(height: 12),
                        VoteDial(itemId: wave.id, question: '¿QUÉ TE PARECE ESTA NOTICIA?'),
                      ],
                      if (wave.shores != null && step == WaveStep.whyItMatters) ...[
                        const SizedBox(height: 22),
                        _ShoresButton(onTap: () => showTwoShores(context, wave.shores!)),
                      ],
                      const Spacer(),
                      const SizedBox(height: 20),
                      if (card.teaser != null) _Teaser(text: card.teaser!, color: color),
                      if (isLastWaveCard) _Teaser(text: 'Toca para completar la onda', color: Palette.gold, reward: true),
                      const SizedBox(height: 12),
                      Text('Fuente: ${wave.source}', style: OndaText.cuerpo(11, color: Palette.textFaint)),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 60,
          child: SideRail(id: '${wave.id}:${step.index}', narration: '${card.headline}. ${card.body}'),
        ),
      ],
    );
  }
}

/// Coloured label with the content layer ("TU BOLSILLO").
class LayerPill extends StatelessWidget {
  const LayerPill({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label.toUpperCase(), style: OndaText.etiqueta(color: color)),
    );
  }
}

/// A key figure in big glowing type.
class BigFigure extends StatelessWidget {
  const BigFigure({super.key, required this.value, required this.caption, required this.color, this.size = 92});
  final String value;
  final String caption;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: OndaText.cifra(size, color: color)
                .copyWith(shadows: [Shadow(color: color.withValues(alpha: 0.45), blurRadius: 28)])),
        const SizedBox(height: 4),
        Text(caption.toUpperCase(), style: OndaText.etiqueta(color: Palette.textSoft, size: 12)),
      ],
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
        for (final (i, action) in actions.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Palette.surface, borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: OndaText.cifra(14, color: Palette.night)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(action, style: OndaText.cuerpo(15))),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ShoresButton extends StatelessWidget {
  const _ShoresButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.compare_arrows_rounded, size: 18),
      label: Text('LAS DOS ORILLAS', style: OndaText.etiqueta(color: Palette.lime, size: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.lime,
        side: const BorderSide(color: Palette.lime),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }
}

class _Teaser extends StatelessWidget {
  const _Teaser({required this.text, required this.color, this.reward = false});
  final String text;
  final Color color;
  final bool reward;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, style: OndaText.cuerpo(16, weight: 700, color: color))),
        Icon(reward ? Icons.bolt_rounded : Icons.arrow_forward_rounded, size: 22, color: color),
      ],
    );
  }
}
