import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/pocket_repository.dart';
import '../../domain/format.dart';
import '../../domain/fuel.dart';
import '../../domain/semaforo.dart';
import '../shared/top_bar.dart';
import 'price_chart.dart';
import 'semaforo_panel.dart';

/// Fuel detail (from "Tu España"): the semáforo, today's price in the user's area, the cheapest
/// stations nearby.
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
                    if (GoRouter.of(context).canPop())
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Volver',
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('CARBURANTES', style: OndaText.impacto(36)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _dataLabel(pocket.value),
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
                ...switch (pocket) {
                  AsyncData(:final value) => [
                      SemaforoPanel(pocket: value),
                      const SizedBox(height: 16),
                      _PriceCard(pocket: value),
                      const SizedBox(height: 24),
                      _Stations(pocket: value),
                    ],
                  AsyncError() => [
                      _ErrorCard(onRetry: () => ref.invalidate(pocketProvider(_fuel))),
                    ],
                  _ => [const _Loading()],
                },
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dataLabel(PocketSnapshot? pocket) {
    if (pocket == null) return '';
    if (pocket.isSample) return 'Datos de ejemplo · ${pocket.areaName}';
    final day = pocket.forecastDay;
    return day == null ? pocket.priceArea : 'Datos del ${day.day}/${day.month} · ${pocket.priceArea}';
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(child: CircularProgressIndicator(color: Palette.lime, strokeWidth: 3)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Palette.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NO HEMOS PODIDO CARGAR LOS PRECIOS', style: OndaText.impacto(26)),
          const SizedBox(height: 8),
          Text('Comprueba tu conexión e inténtalo de nuevo.', style: OndaText.cuerpo(15, color: Palette.textSoft)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: Palette.lime,
              foregroundColor: Palette.night,
              shape: const StadiumBorder(),
            ),
            child: Text('REINTENTAR', style: OndaText.etiqueta(color: Palette.night, size: 13)),
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
          Text('PRECIO MEDIO · ${pocket.priceArea.toUpperCase()}', style: OndaText.etiqueta()),
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
        Text('LAS MÁS BARATAS CERCA DE ${pocket.areaName.toUpperCase()}',
            style: OndaText.etiqueta(size: 12, color: Palette.text)),
        if (pocket.areaAveragePrice != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Ahorro frente a la media de la zona: ${fuelPrice(pocket.areaAveragePrice!)} €/l '
              '(${pocket.areaStationCount} gasolineras a menos de 10 km)',
              style: OndaText.cuerpo(12, color: Palette.textSoft),
            ),
          ),
        if (stations.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('No hay gasolineras con precio a menos de 10 km.',
                style: OndaText.cuerpo(14, color: Palette.textSoft)),
          ),
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
                    _SavingLabel(saving: savingEur(referencePrice: pocket.stationReferencePrice, stationPrice: s.price)),
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
