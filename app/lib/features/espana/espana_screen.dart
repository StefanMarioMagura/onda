import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/luz_repository.dart';
import '../../data/pocket_repository.dart';
import '../../data/stats_repository.dart';
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
                ref.invalidate(spainStatsProvider);
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
                  const _BasketCard(),
                  const SizedBox(height: 12),
                  const _SalaryCard(),
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

class _BasketCard extends ConsumerWidget {
  const _BasketCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      title: 'Cesta de la compra',
      source: 'INE · Índice de Precios de Consumo (alimentos y bebidas no alcohólicas)',
      child: switch (ref.watch(spainStatsProvider)) {
        AsyncData(:final value) when value.foodCpi.isNotEmpty => _Basket(stats: value),
        AsyncError() => Text('No hemos podido cargar los precios.', style: OndaText.cuerpo(14, color: Palette.textSoft)),
        AsyncData() => Text('Sin datos todavía.', style: OndaText.cuerpo(14, color: Palette.textSoft)),
        _ => const LinearProgressIndicator(color: Palette.lime, backgroundColor: Palette.line),
      },
    );
  }
}

class _Basket extends StatelessWidget {
  const _Basket({required this.stats});
  final SpainStats stats;

  @override
  Widget build(BuildContext context) {
    final last = stats.foodCpi.last;
    final general = stats.generalCpi.isEmpty ? null : stats.generalCpi.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(percentSigned(last.value),
                    style: OndaText.cifra(52, color: last.value > 0 ? Palette.ambar : Palette.lime)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('la comida en un año\n(${monthYear(last.period)})',
                    style: OndaText.cuerpo(13, color: Palette.textSoft)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text.rich(TextSpan(style: OndaText.cuerpo(15), children: [
          const TextSpan(text: 'Lo que hace un año eran 100 € de compra, hoy cuesta '),
          TextSpan(text: euros(stats.basketToday(100)!), style: OndaText.cuerpo(15, weight: 700)),
          const TextSpan(text: '.'),
        ])),
        const SizedBox(height: 14),
        SizedBox(height: 50, child: _RateBars(points: stats.foodCpi.length > 12
            ? stats.foodCpi.sublist(stats.foodCpi.length - 12) : stats.foodCpi)),
        const SizedBox(height: 4),
        Text('Subida anual de los alimentos, últimos 12 meses', style: OndaText.cuerpo(11, color: Palette.textFaint)),
        if (general != null) ...[
          const SizedBox(height: 10),
          Text('Todos los precios (IPC general), ${monthYear(general.period)}: ${percentSigned(general.value)}',
              style: OndaText.cuerpo(13)),
        ],
        if (stats.isSample) Text('Datos de ejemplo', style: OndaText.cuerpo(11, color: Palette.textFaint)),
      ],
    );
  }
}

/// Monthly annual-change bars; the latest month highlighted.
class _RateBars extends StatelessWidget {
  const _RateBars({required this.points});
  final List<StatPoint> points;

  @override
  Widget build(BuildContext context) {
    final hi = points.map((p) => p.value.abs()).fold<double>(0.1, (a, b) => b > a ? b : a);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, p) in points.indexed)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 6 + 44 * (p.value.abs() / hi),
              decoration: BoxDecoration(
                color: i == points.length - 1 ? Palette.ambar : Palette.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

class _SalaryCard extends ConsumerWidget {
  const _SalaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      title: 'Salario',
      source: 'INE · Encuesta Anual de Estructura Salarial (ganancia bruta anual por trabajador)',
      child: switch (ref.watch(spainStatsProvider)) {
        AsyncData(:final value) when value.salaryMean.isNotEmpty => _Salary(stats: value),
        AsyncError() => Text('No hemos podido cargar los salarios.', style: OndaText.cuerpo(14, color: Palette.textSoft)),
        AsyncData() => Text('Sin datos todavía.', style: OndaText.cuerpo(14, color: Palette.textSoft)),
        _ => const LinearProgressIndicator(color: Palette.lime, backgroundColor: Palette.line),
      },
    );
  }
}

class _Salary extends StatelessWidget {
  const _Salary({required this.stats});
  final SpainStats stats;

  @override
  Widget build(BuildContext context) {
    final mean = stats.salaryMean.last;
    final median = stats.salaryMedian.isEmpty ? null : stats.salaryMedian.last;
    final change = stats.salaryChangePct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _Figure(label: 'MEDIA ${mean.period.year}', value: eurosWhole(mean.value))),
            if (median != null)
              Expanded(child: _Figure(label: 'MEDIANA ${median.period.year}', value: eurosWhole(median.value), lime: true)),
          ],
        ),
        const SizedBox(height: 10),
        if (median != null)
          Text('La mitad de los trabajadores gana menos de ${eurosWhole(median.value)} brutos al año. '
              'La media sale más alta porque la suben los sueldos más altos.',
              style: OndaText.cuerpo(13, color: Palette.textSoft)),
        if (change != null) ...[
          const SizedBox(height: 8),
          Text('${percentSigned(change)} frente a ${mean.period.year - 1}', style: OndaText.cuerpo(14, weight: 700)),
        ],
        if (stats.isSample) Text('Datos de ejemplo', style: OndaText.cuerpo(11, color: Palette.textFaint)),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.lime = false});
  final String label;
  final String value;
  final bool lime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: OndaText.etiqueta(size: 10)),
        FittedBox(child: Text(value, style: OndaText.cifra(34, color: lime ? Palette.lime : Palette.text))),
      ],
    );
  }
}
