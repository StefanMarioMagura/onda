import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/parties_ches2024.dart';
import '../../data/discover_content.dart';
import '../../domain/affinity.dart';
import '../../state/rewards_state.dart';
import '../../state/votes_state.dart';
import '../shared/top_bar.dart';
import 'political_map.dart';

final affinityProvider = Provider<AffinityResult>((ref) => computeAffinity(
      votes: ref.watch(votesProvider),
      stances: ref.watch(stancesProvider),
      parties: partiesChes2024,
    ));

class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardsProvider);
    final votes = ref.watch(votesProvider);
    final consent = ref.watch(politicalMapConsentProvider);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const TopBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                Text('TU PERFIL', style: OndaText.impacto(36)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Stat('${rewards.streakDays}', 'días seguidos', Palette.gold),
                    const SizedBox(width: 8),
                    _Stat('${rewards.points}', 'puntos', Palette.gold),
                    const SizedBox(width: 8),
                    _Stat('${votes.length}', 'valoraciones', Palette.lime),
                  ],
                ),
                const SizedBox(height: 24),
                if (!consent) const _ConsentCard() else const _PoliticalMap(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Palette.surface, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(child: Text(value, style: OndaText.cifra(30, color: color))),
            Text(label.toUpperCase(), style: OndaText.etiqueta(size: 9)),
          ],
        ),
      ),
    );
  }
}

class _ConsentCard extends ConsumerWidget {
  const _ConsentCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.lime.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿A QUÉ PARTIDO TE PARECES?', style: OndaText.impacto(32)),
          const SizedBox(height: 10),
          Text(
            'Con tus respuestas a los debates de Descubre, ONDA te sitúa en un mapa político de tres '
            'ejes y te dice a qué partido te pareces más, según las posiciones que les dan expertos '
            'independientes (encuesta CHES 2024).',
            style: OndaText.cuerpo(15, color: Palette.textSoft),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => showConsent(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: Palette.lime,
                foregroundColor: Palette.night,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('ACTIVAR MI MAPA POLÍTICO', style: OndaText.etiqueta(color: Palette.night, size: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Explicit, separate consent (GDPR art. 9): nothing is computed until the box is ticked.
Future<void> showConsent(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _ConsentSheet(),
  );
}

class _ConsentSheet extends ConsumerStatefulWidget {
  const _ConsentSheet();

  @override
  ConsumerState<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends ConsumerState<_ConsentSheet> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ANTES DE ACTIVARLO', style: OndaText.impacto(30)),
          const SizedBox(height: 12),
          for (final line in const [
            'Tus opiniones políticas son datos especialmente protegidos.',
            'El mapa se calcula solo en este móvil: tus valoraciones no se envían a ningún sitio.',
            'Al servidor solo llega un contador anónimo por noticia, sin saber quién votó.',
            'Nunca lo usamos para elegir qué noticias ves ni para publicidad.',
            'Puedes desactivarlo y borrar tus valoraciones cuando quieras desde tu perfil.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.check_rounded, size: 18, color: Palette.lime),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(line, style: OndaText.cuerpo(15, color: Palette.textSoft))),
                ],
              ),
            ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _accepted,
            onChanged: (v) => setState(() => _accepted = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Palette.lime,
            checkColor: Palette.night,
            title: Text(
              'Doy mi consentimiento explícito para que ONDA calcule en este móvil mi perfil político '
              'a partir de mis valoraciones.',
              style: OndaText.cuerpo(14),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _accepted
                  ? () {
                      ref.read(politicalMapConsentProvider.notifier).set(true);
                      Navigator.of(context).pop();
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: Palette.lime,
                foregroundColor: Palette.night,
                disabledBackgroundColor: Palette.surfaceHigh,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('ACTIVAR', style: OndaText.etiqueta(color: _accepted ? Palette.night : Palette.textFaint, size: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PoliticalMap extends ConsumerWidget {
  const _PoliticalMap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(affinityProvider);
    final top = result.matches.firstOrNull;
    final eco = result.position[PolAxis.economia];
    final soc = result.position[PolAxis.sociedad];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TU MAPA POLÍTICO', style: OndaText.etiqueta(size: 12, color: Palette.text)),
        const SizedBox(height: 10),
        if (top == null)
          _Empty(result: result)
        else
          _TopMatch(match: top, family: politicalFamily(result.position), partial: !result.isComplete),
        const SizedBox(height: 18),
        if (eco != null && soc != null) ...[
          Compass(parties: partiesChes2024, user: Offset(eco, soc), highlight: top?.party),
          const SizedBox(height: 18),
        ],
        for (final axis in PolAxis.values) ...[
          AxisBar(axis: axis, value: result.position[axis], parties: partiesChes2024, votes: result.evidence[axis]!),
          const SizedBox(height: 16),
        ],
        if (result.matches.length > 1) ...[
          Text('PARECIDO CON CADA PARTIDO', style: OndaText.etiqueta(size: 11, color: Palette.text)),
          const SizedBox(height: 8),
          for (final m in result.matches.take(6)) _MatchRow(match: m),
          const SizedBox(height: 16),
        ],
        _Method(),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _confirmDelete(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: Palette.rojo,
                side: const BorderSide(color: Palette.rojo),
                shape: const StadiumBorder(),
              ),
              child: const Text('Borrar mis valoraciones'),
            ),
            TextButton(
              onPressed: () => ref.read(politicalMapConsentProvider.notifier).set(false),
              child: Text('Desactivar mapa político', style: OndaText.cuerpo(14, color: Palette.textSoft)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.surfaceHigh,
        title: const Text('¿Borrar todas tus valoraciones?'),
        content: const Text('Se borran de este móvil y tu mapa político vuelve a empezar. '
            'Los contadores anónimos de cada noticia no cambian.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok == true) ref.read(votesProvider.notifier).clearAll();
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.result});
  final AffinityResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Palette.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VALORA PARA DESCUBRIRLO', style: OndaText.impacto(28)),
          const SizedBox(height: 8),
          Text(
            'Desliza el dial en los debates que irás encontrando en Descubre. Con '
            '$minVotesPerAxis valoraciones en un eje ya te situamos en él.',
            style: OndaText.cuerpo(15, color: Palette.textSoft),
          ),
        ],
      ),
    );
  }
}

class _TopMatch extends StatelessWidget {
  const _TopMatch({required this.match, required this.family, required this.partial});
  final PartyMatch match;
  final String family;
  final bool partial;

  @override
  Widget build(BuildContext context) {
    final p = match.party;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.gold.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Palette.gold.withValues(alpha: 0.10), blurRadius: 30)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TE PARECES MÁS A', style: OndaText.etiqueta(color: Palette.gold, size: 12)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(p.short.toUpperCase(),
                      style: OndaText.impacto(72, color: Palette.gold).copyWith(
                          shadows: [Shadow(color: Palette.gold.withValues(alpha: 0.4), blurRadius: 24)])),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('${(match.similarity * 100).round()} %', style: OndaText.cifra(32, color: Palette.text)),
              ),
            ],
          ),
          Text(p.name, style: OndaText.cuerpo(14, color: Palette.textSoft)),
          if (p.leader != null) ...[
            const SizedBox(height: 10),
            Text.rich(TextSpan(style: OndaText.cuerpo(16), children: [
              const TextSpan(text: 'Tu personaje político: '),
              TextSpan(text: p.leader, style: OndaText.cuerpo(16, weight: 700, color: Palette.text)),
              TextSpan(text: ', líder de ${p.short}', style: OndaText.cuerpo(14, color: Palette.textSoft)),
            ])),
          ],
          const SizedBox(height: 10),
          Text('Tu familia política: $family', style: OndaText.cuerpo(16, weight: 600, color: Palette.lime)),
          if (partial) ...[
            const SizedBox(height: 8),
            Text('Resultado provisional: aún faltan valoraciones en algún eje.',
                style: OndaText.cuerpo(12, color: Palette.textFaint)),
          ],
        ],
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match});
  final PartyMatch match;

  @override
  Widget build(BuildContext context) {
    final pct = (match.similarity * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 74, child: Text(match.party.short, style: OndaText.cuerpo(14, weight: 700))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: match.similarity,
                minHeight: 6,
                backgroundColor: Palette.line,
                color: Palette.textSoft,
              ),
            ),
          ),
          SizedBox(width: 48, child: Text('$pct %', textAlign: TextAlign.right, style: OndaText.cuerpo(13))),
        ],
      ),
    );
  }
}

class _Method extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CÓMO SE CALCULA', style: OndaText.impacto(30)),
              const SizedBox(height: 12),
              Text(
                'Los partidos están colocados según la Chapel Hill Expert Survey 2024, una encuesta '
                'académica a expertos en política de cada país (variables lrecon, galtan y regions, de 0 a 10). '
                'ONDA no decide dónde está cada partido.\n\n'
                'Cada debate tiene una marca editorial: hacia qué lado de cada eje '
                'empuja estar a favor. Tu posición es la media de tus respuestas con esas marcas, y el '
                'parecido con cada partido depende de la distancia entre tu punto y el suyo.\n\n'
                'Las noticias reales también se valoran, pero no cuentan aquí: no tienen esa marca.\n\n'
                'Es una orientación, no un test oficial: con más respuestas, más fiable.',
                style: OndaText.cuerpo(15, color: Palette.textSoft),
              ),
            ],
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: Palette.lime),
          const SizedBox(width: 6),
          Flexible(
            child: Text('Cómo se calcula y de dónde salen los datos',
                style: OndaText.cuerpo(14, weight: 600, color: Palette.lime)),
          ),
        ],
      ),
    );
  }
}
