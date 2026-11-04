import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/sample_data.dart';
import '../../domain/format.dart';
import '../../domain/fuel.dart';
import '../../domain/semaforo.dart';
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Tu bolsillo', style: OndaText.titular(24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Zona aprox.: ${pocket.areaName}',
                    textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: OndaText.cuerpo(12, color: Palette.inkSoft)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Palette.ink, thickness: 1.5, height: 1.5),
          if (usingSampleData)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('DATOS DE EJEMPLO', style: OndaText.antetitulo(color: Palette.inkFaint)),
            ),
          const SizedBox(height: 16),
          _FuelTabs(selected: _fuel, onSelected: (f) => setState(() => _fuel = f)),
          const SizedBox(height: 24),
          SemaforoPanel(pocket: pocket),
          const SizedBox(height: 32),
          _PriceBlock(pocket: pocket),
          const SizedBox(height: 32),
          _Stations(pocket: pocket),
          const SizedBox(height: 32),
          const Divider(color: Palette.ink, thickness: 1.5, height: 1.5),
          const SizedBox(height: 14),
          Text('TU AHORRO', style: OndaText.antetitulo()),
          const SizedBox(height: 10),
          Text(euros(saving), style: OndaText.cifra(48, color: Capa.bolsillo.color)),
          const SizedBox(height: 6),
          Text('este mes, por llenar cuando el semáforo estaba en verde y esperar cuando estaba en rojo.',
              style: OndaText.cuerpo(14, color: Palette.inkSoft)),
        ],
      ),
    );
  }
}

/// Text tabs with an underline, like a newspaper section bar.
class _FuelTabs extends StatelessWidget {
  const _FuelTabs({required this.selected, required this.onSelected});
  final Fuel selected;
  final ValueChanged<Fuel> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runSpacing: 8,
      children: [
        for (final fuel in Fuel.values)
          GestureDetector(
            onTap: () => onSelected(fuel),
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              padding: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: fuel == selected ? Palette.ink : Colors.transparent, width: 2),
                ),
              ),
              child: Text(
                fuel.label,
                style: OndaText.cuerpo(15,
                    weight: fuel == selected ? 600 : 400,
                    color: fuel == selected ? Palette.ink : Palette.inkFaint),
              ),
            ),
          ),
      ],
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.pocket});
  final PocketSnapshot pocket;

  @override
  Widget build(BuildContext context) {
    final change = pocket.change7dSoFar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PRECIO MEDIO EN TU ZONA', style: OndaText.antetitulo()),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(fuelPrice(pocket.averagePrice), style: OndaText.cifra(56)),
            const SizedBox(width: 6),
            Text('€/l', style: OndaText.cuerpo(16, color: Palette.inkSoft)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${cents(change)} en 7 días',
                  textAlign: TextAlign.right, maxLines: 2,
                  style: OndaText.cuerpo(14, weight: 600)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(height: 120, child: PriceChart(values: pocket.last30Days)),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('hace 30 días', style: OndaText.cuerpo(11, color: Palette.inkFaint)),
            const Spacer(),
            Text('hoy', style: OndaText.cuerpo(11, color: Palette.inkFaint)),
          ],
        ),
      ],
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
        Text('LAS MÁS BARATAS CERCA DE TI', style: OndaText.antetitulo()),
        const SizedBox(height: 10),
        for (final s in stations) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.brand, style: OndaText.cuerpo(16, weight: 600)),
                      Text('${s.address} · ${km(s.distanceKm)}',
                          style: OndaText.cuerpo(13, color: Palette.inkSoft)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fuelPrice(s.price), style: OndaText.cifra(24)),
                    _SavingLabel(saving: savingEur(referencePrice: pocket.averagePrice, stationPrice: s.price)),
                  ],
                ),
              ],
            ),
          ),
        ],
        const Divider(),
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
      return Text('por encima de la media', style: OndaText.cuerpo(12, color: Palette.inkFaint));
    }
    return Text('ahorras ${euros(saving)} en 50 l',
        style: OndaText.cuerpo(12, weight: 600, color: Capa.bolsillo.color));
  }
}
