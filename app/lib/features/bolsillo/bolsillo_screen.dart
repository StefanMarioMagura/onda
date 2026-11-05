import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/sample_data.dart';
import '../../domain/format.dart';
import '../../domain/fuel.dart';
import '../../domain/semaforo.dart';
import '../shared/top_bar.dart';
import 'price_chart.dart';
import 'semaforo_panel.dart';

/// "Tu bolsillo": the semáforo, today's price in the user's area, the cheapest
/// stations nearby and what following the semáforo has saved.
class BolsilloScreen extends ConsumerStatefulWidget {
  const BolsilloScreen({super.key});

  @override
  ConsumerState<BolsilloScreen> createState() => _BolsilloScreenState();
}

class _BolsilloScreenState extends ConsumerState<BolsilloScreen> {
  Fuel _fuel = Fuel.gasoleoA;

  @override
  Widget build(BuildContext context) {
    final pocket = ref.watch(pocketProvider(_fuel));
    final saving = ref.watch(monthlySavingProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const TopBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('TU BOLSILLO', style: OndaText.impacto(36)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${usingSampleData ? 'Datos de ejemplo · ' : ''}${pocket.areaName}',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OndaText.cuerpo(12, color: Palette.textFaint),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _FuelTabs(selected: _fuel, onSelected: (f) => setState(() => _fuel = f)),
                const SizedBox(height: 16),
                SemaforoPanel(pocket: pocket),
                const SizedBox(height: 16),
                _PriceCard(pocket: pocket),
                const SizedBox(height: 24),
                _Stations(pocket: pocket),
                const SizedBox(height: 16),
                _SavingCard(saving: saving),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelTabs extends StatelessWidget {
  const _FuelTabs({required this.selected, required this.onSelected});
  final Fuel selected;
  final ValueChanged<Fuel> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final fuel in Fuel.values)
          GestureDetector(
            onTap: () => onSelected(fuel),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: fuel == selected ? Palette.lime : Palette.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                fuel.label.toUpperCase(),
                style: OndaText.etiqueta(size: 12, color: fuel == selected ? Palette.night : Palette.textSoft),
              ),
            ),
          ),
      ],
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.pocket});
  final PocketSnapshot pocket;

  @override
  Widget build(BuildContext context) {
    final change = pocket.change7dSoFar;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Palette.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PRECIO MEDIO EN TU ZONA', style: OndaText.etiqueta()),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: fuelPrice(pocket.averagePrice), style: OndaText.cifra(64)),
                    TextSpan(text: ' €/l', style: OndaText.cuerpo(16, color: Palette.textSoft)),
                  ])),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${cents(change)}\nen 7 días',
                    textAlign: TextAlign.right, style: OndaText.cuerpo(13, weight: 700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(height: 110, child: PriceChart(values: pocket.last30Days)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('HACE 30 DÍAS', style: OndaText.etiqueta(size: 9, color: Palette.textFaint)),
              const Spacer(),
              Text('HOY', style: OndaText.etiqueta(size: 9, color: Palette.textFaint)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stations extends StatelessWidget {
  const _Stations({required this.pocket});
  final PocketSnapshot pocket;

  @override
  Widget build(BuildContext context) {
    final stations = [...pocket.stations]..sort((a, b) => a.price.compareTo(b.price));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LAS MÁS BARATAS CERCA', style: OndaText.etiqueta(size: 12, color: Palette.text)),
        const SizedBox(height: 10),
        for (final (i, s) in stations.indexed) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Palette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: i == 0 ? Palette.lime : Colors.transparent, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (i == 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('LA MÁS BARATA', style: OndaText.etiqueta(size: 9, color: Palette.lime)),
                        ),
                      Text(s.brand, style: OndaText.cuerpo(16, weight: 700)),
                      Text('${s.address} · ${km(s.distanceKm)}',
                          style: OndaText.cuerpo(12, color: Palette.textSoft)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fuelPrice(s.price), style: OndaText.cifra(28)),
                    _SavingLabel(saving: savingEur(referencePrice: pocket.averagePrice, stationPrice: s.price)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SavingLabel extends StatelessWidget {
  const _SavingLabel({required this.saving});
  final double saving;

  @override
  Widget build(BuildContext context) {
    if (saving == 0) {
      return Text('sobre la media', style: OndaText.cuerpo(11, color: Palette.textFaint));
    }
    return Text('−${euros(saving)} / 50 l', style: OndaText.cuerpo(12, weight: 700, color: Palette.lime));
  }
}

class _SavingCard extends StatelessWidget {
  const _SavingCard({required this.saving});
  final double saving;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.lime.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.lime.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(euros(saving),
              style: OndaText.cifra(48, color: Palette.lime)
                  .copyWith(shadows: [Shadow(color: Palette.lime.withValues(alpha: 0.4), blurRadius: 20)])),
          const SizedBox(width: 14),
          Expanded(
            child: Text('ahorrados este mes siguiendo el semáforo',
                style: OndaText.cuerpo(14, color: Palette.textSoft)),
          ),
        ],
      ),
    );
  }
}
