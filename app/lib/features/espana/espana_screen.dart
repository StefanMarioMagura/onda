import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/luz_repository.dart';
import '../../data/pocket_repository.dart';
import '../../domain/format.dart';
import '../../domain/fuel.dart';
import '../bolsillo/semaforo_panel.dart';
import '../shared/top_bar.dart';

/// "Tu España": what it costs to live in Spain, with official data only.
class EspanaScreen extends ConsumerWidget {
  const EspanaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const TopBar(),
          Expanded(
            child: RefreshIndicator(
              color: Palette.lime,
              onRefresh: () async {
                ref.invalidate(luzTodayProvider);
                ref.invalidate(pocketProvider);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                children: [
                  Text('TU ESPAÑA', style: OndaText.impacto(36)),
                  Text('Lo que cuesta vivir, con datos oficiales.', style: OndaText.cuerpo(14, color: Palette.textSoft)),
                  const SizedBox(height: 18),
                  const _FuelCard(),
                  const SizedBox(height: 12),
                  const _LuzCard(),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(child: _SoonCard(title: 'Salario medio', source: 'INE')),
                      SizedBox(width: 12),
                      Expanded(child: _SoonCard(title: 'Cesta de la compra', source: 'INE · IPC')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.onTap, this.source});
  final String title;
  final Widget child;
  final VoidCallback? onTap;
  final String? source;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Palette.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title.toUpperCase(), style: OndaText.etiqueta(size: 12, color: Palette.text))),
                if (onTap != null) const Icon(Icons.chevron_right_rounded, color: Palette.textSoft),
              ],
            ),
            const SizedBox(height: 12),
            child,
            if (source != null) ...[
              const SizedBox(height: 12),
              Text('Fuente: $source', style: OndaText.cuerpo(11, color: Palette.textFaint)),
            ],
          ],
        ),
      ),
    );
  }
}

class _FuelCard extends ConsumerWidget {
  const _FuelCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      title: 'Carburantes',
      source: 'Ministerio para la Transición Ecológica',
      onTap: () => context.go('/espana/carburantes'),
      child: Row(
        children: [
          for (final fuel in Fuel.values) ...[
            if (fuel != Fuel.values.first) const SizedBox(width: 12),
            Expanded(
              child: switch (ref.watch(pocketProvider(fuel))) {
                AsyncData(:final value) => _FuelTile(fuel: fuel, price: value.averagePrice, verdict: value.signal.verdict,
                    color: signalColor(value.signal)),
                AsyncError() => Text('Sin datos', style: OndaText.cuerpo(13, color: Palette.textSoft)),
                _ => const LinearProgressIndicator(color: Palette.lime, backgroundColor: Palette.line),
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _FuelTile extends StatelessWidget {
  const _FuelTile({required this.fuel, required this.price, required this.verdict, required this.color});
  final Fuel fuel;
  final double price;
  final String verdict;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(fuel.label, style: OndaText.cuerpo(13, color: Palette.textSoft)),
        FittedBox(child: Text('${fuelPrice(price)} €', style: OndaText.cifra(32))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
          child: Text(verdict.toUpperCase(), style: OndaText.etiqueta(size: 10, color: color)),
        ),
      ],
    );
  }
}

class _LuzCard extends ConsumerWidget {
  const _LuzCard();

  String _hour(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:00';
  String _kwh(double v) => '${v.toStringAsFixed(3).replaceAll('.', ',')} €';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final luz = ref.watch(luzTodayProvider);
    return _Card(
      title: 'Luz hoy · tarifa regulada (PVPC)',
      source: 'Red Eléctrica · €/kWh sin impuestos',
      child: switch (luz) {
        AsyncData(value: final day?) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AHORA', style: OndaText.etiqueta(size: 10)),
                        FittedBox(
                          child: Text(_kwh(day.priceAt(DateTime.now()) ?? day.average),
                              style: OndaText.cifra(44, color: Palette.lime)),
                        ),
                      ],
                    ),
                  ),
                  Text('media ${_kwh(day.average)}', style: OndaText.cuerpo(13, color: Palette.textSoft)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(height: 60, child: _HourBars(day: day)),
              const SizedBox(height: 10),
              Text('Más barata a las ${_hour(day.cheapest.$1)} (${_kwh(day.cheapest.$2)}) · '
                  'más cara a las ${_hour(day.priciest.$1)} (${_kwh(day.priciest.$2)})',
                  style: OndaText.cuerpo(13)),
              if (day.isSample)
                Text('Datos de ejemplo', style: OndaText.cuerpo(11, color: Palette.textFaint)),
            ],
          ),
        AsyncData() => Text('Los precios de hoy aún no están cargados.',
            style: OndaText.cuerpo(14, color: Palette.textSoft)),
        AsyncError() => Text('No hemos podido cargar el precio de la luz.',
            style: OndaText.cuerpo(14, color: Palette.textSoft)),
        _ => const LinearProgressIndicator(color: Palette.lime, backgroundColor: Palette.line),
      },
    );
  }
}

/// 24 bars, the current hour highlighted; the cheapest hours in lime.
class _HourBars extends StatelessWidget {
  const _HourBars({required this.day});
  final LuzDay day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final lo = day.cheapest.$2;
    final hi = day.priciest.$2;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (hour, price) in day.hours)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              height: 10 + 50 * ((price - lo) / ((hi - lo) == 0 ? 1 : hi - lo)),
              decoration: BoxDecoration(
                color: hour.hour == now.hour && hour.day == now.day
                    ? Palette.text
                    : price <= lo + (hi - lo) * 0.25
                        ? Palette.lime
                        : Palette.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

class _SoonCard extends StatelessWidget {
  const _SoonCard({required this.title, required this.source});
  final String title;
  final String source;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: OndaText.etiqueta(size: 11, color: Palette.textSoft)),
          const Spacer(),
          Text('PRÓXIMAMENTE', style: OndaText.etiqueta(size: 11, color: Palette.textFaint)),
          Text(source, style: OndaText.cuerpo(11, color: Palette.textFaint)),
        ],
      ),
    );
  }
}
