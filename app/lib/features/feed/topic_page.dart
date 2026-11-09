import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/news.dart';
import '../../domain/rewards.dart';
import '../../state/rewards_state.dart';
import '../shared/celebration.dart';
import '../shared/links.dart';
import '../shared/side_rail.dart';
import '../shared/vote_dial.dart';
import 'two_shores_sheet.dart';

/// One of the day's topics: the outlet's headline and extract, who covers it,
/// how each side tells it, a link to read it and the rating dial.
class TopicPage extends ConsumerWidget {
  const TopicPage({super.key, required this.topic});
  final NewsTopic topic;

  void _opened(BuildContext context, WidgetRef ref) {
    if (ref.read(rewardsProvider.notifier).claim('read:${topic.id}', PointsRules.articleOpened)) {
      celebrate(context, PointsRules.articleOpened, label: 'Noticia leída');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const LabelPill(label: 'Tema del día', color: Palette.lime),
                          Text('${topic.outlets} MEDIOS', style: OndaText.etiqueta()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(right: 52),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(topic.headline, style: OndaText.impacto(40)),
                            const SizedBox(height: 8),
                            Text('Titular de ${topic.outletName}',
                                style: OndaText.cuerpo(12, color: Palette.textFaint)),
                            if (topic.summary != null) ...[
                              const SizedBox(height: 14),
                              Text(topic.summary!, style: OndaText.cuerpo(17, color: Palette.textSoft)),
                            ],
                            const SizedBox(height: 18),
                            ReadAtSourceButton(
                              outlet: topic.outletName,
                              url: topic.url,
                              onOpened: () => _opened(context, ref),
                            ),
                            const SizedBox(height: 10),
                            _ShoresButton(topic: topic),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 18),
                      VoteDial(itemId: topic.id, question: '¿QUÉ TE PARECE ESTA NOTICIA?'),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 40,
            child: SideRail(
              id: topic.id,
              narration: topic.summary == null ? topic.headline : '${topic.headline}. ${topic.summary}',
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoresButton extends StatelessWidget {
  const _ShoresButton({required this.topic});
  final NewsTopic topic;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => showTwoShores(context, topic),
      icon: const Icon(Icons.compare_arrows_rounded, size: 18),
      label: Text(topic.bothSides ? 'LAS DOS ORILLAS' : 'CÓMO LO CUENTAN',
          style: OndaText.etiqueta(color: Palette.lime, size: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.lime,
        side: const BorderSide(color: Palette.lime),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    );
  }
}
