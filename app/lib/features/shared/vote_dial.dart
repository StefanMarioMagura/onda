import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/vote_repository.dart';
import '../../domain/affinity.dart';
import '../../domain/rewards.dart';
import '../../state/rewards_state.dart';
import '../../state/votes_state.dart';

/// Rate an item by sliding a dial: left = "mal", right = "bien", tap = "me da igual".
/// After voting it shows the anonymous totals (only with enough real votes).
class VoteDial extends ConsumerStatefulWidget {
  const VoteDial({super.key, required this.itemId, this.question = '¿QUÉ TE PARECE?'});
  final String itemId;
  final String question;

  @override
  ConsumerState<VoteDial> createState() => _VoteDialState();
}

class _VoteDialState extends ConsumerState<VoteDial> {
  /// Thumb offset from the centre, −1 (fully left) … 1 (fully right).
  double _drag = 0;
  bool _changing = false;

  static const _threshold = 0.45;

  void _commit(Vote vote) {
    HapticFeedback.mediumImpact();
    final previous = ref.read(votesProvider.notifier).cast(widget.itemId, vote);
    ref.read(rewardsProvider.notifier).claim('vote:${widget.itemId}', PointsRules.vote);
    _send(vote, previous);
    setState(() {
      _drag = 0;
      _changing = false;
    });
  }

  /// Sends the anonymous vote without blocking; a failed send never loses the local vote.
  Future<void> _send(Vote vote, Vote? previous) async {
    try {
      await ref.read(voteRepositoryProvider).cast(widget.itemId, vote, previous);
      if (mounted) ref.invalidate(voteTotalsProvider(widget.itemId));
    } catch (e) {
      debugPrint('Vote not sent: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(votesProvider)[widget.itemId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.question, style: OndaText.etiqueta(size: 12, color: Palette.text)),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: current == null || _changing ? _dial() : _result(current),
        ),
      ],
    );
  }

  static const _thumb = 60.0;

  /// Half the distance the thumb can travel, read from the laid-out dial while dragging.
  /// (No LayoutBuilder: cards measure their content with IntrinsicHeight, which it doesn't support.)
  double _travel(BuildContext context) {
    final width = (context.findRenderObject() as RenderBox?)?.size.width ?? 300;
    return ((width - _thumb) / 2).clamp(1, double.infinity);
  }

  Widget _dial() {
    final towards = _drag > 0 ? Palette.verde : Palette.rojo;
    return Builder(
      key: const ValueKey('dial'),
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) =>
            setState(() => _drag = (_drag + d.delta.dx / _travel(context)).clamp(-1, 1)),
        onHorizontalDragEnd: (_) {
          if (_drag >= _threshold) {
            _commit(Vote.bien);
          } else if (_drag <= -_threshold) {
            _commit(Vote.mal);
          } else {
            setState(() => _drag = 0);
          }
        },
        child: Container(
          height: 68,
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Color.lerp(Palette.surfaceHigh, towards.withValues(alpha: 0.35), _drag.abs()),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: Color.lerp(Palette.line, towards, _drag.abs())!, width: 1.5),
          ),
          child: Stack(
            children: [
              Align(
                alignment: const Alignment(-0.82, 0),
                child: _SideLabel('MAL', Palette.rojo, active: _drag < -0.1),
              ),
              Align(
                alignment: const Alignment(0.82, 0),
                child: _SideLabel('BIEN', Palette.verde, active: _drag > 0.1),
              ),
              Align(
                alignment: Alignment(_drag, 0),
                child: GestureDetector(
                  onTap: () => _commit(Vote.igual),
                  child: Container(
                    width: _thumb - 4,
                    height: _thumb - 4,
                    decoration: BoxDecoration(
                      color: _drag.abs() >= _threshold ? towards : Palette.lime,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Palette.lime.withValues(alpha: 0.35), blurRadius: 16)],
                    ),
                    child: Icon(
                      _drag > 0.1
                          ? Icons.thumb_up_rounded
                          : _drag < -0.1
                              ? Icons.thumb_down_rounded
                              : Icons.swap_horiz_rounded,
                      color: Palette.night,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _result(Vote vote) {
    final totals = ref.watch(voteTotalsProvider(widget.itemId)).value;
    final color = switch (vote) {
      Vote.bien => Palette.verde,
      Vote.mal => Palette.rojo,
      Vote.igual => Palette.textSoft,
    };
    return Container(
      key: const ValueKey('result'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Palette.surfaceHigh, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('TU VOTO: ${vote.label.toUpperCase()}', style: OndaText.impacto(22, color: color)),
              ),
              GestureDetector(
                onTap: () => setState(() => _changing = true),
                child: Text('Cambiar', style: OndaText.cuerpo(13, weight: 600, color: Palette.lime)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (totals != null && totals.total >= minVotesToShowTotals)
            _TotalsBar(totals: totals)
          else
            Text('Aún hay pocos votos para mostrar resultados.',
                style: OndaText.cuerpo(13, color: Palette.textSoft)),
        ],
      ),
    );
  }
}

class _SideLabel extends StatelessWidget {
  const _SideLabel(this.text, this.color, {required this.active});
  final String text;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: OndaText.etiqueta(size: 13, color: active ? color : Palette.textFaint));
}

class _TotalsBar extends StatelessWidget {
  const _TotalsBar({required this.totals});
  final VoteTotals totals;

  @override
  Widget build(BuildContext context) {
    String pct(Vote v) => '${(totals.share(v) * 100).round()} %';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(flex: totals.bien, child: Container(color: Palette.verde)),
                Expanded(flex: totals.igual, child: Container(color: Palette.textFaint)),
                Expanded(flex: totals.mal, child: Container(color: Palette.rojo)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('Bien ${pct(Vote.bien)} · Me da igual ${pct(Vote.igual)} · Mal ${pct(Vote.mal)} · ${totals.total} votos',
            style: OndaText.cuerpo(12, color: Palette.textSoft)),
      ],
    );
  }
}
