import '../domain/discover.dart';
import '../domain/fuel.dart';
import '../domain/news.dart';

/// Fictional content for running without Supabase (tests, quick runs). The UI
/// labels it: "Contenido de ejemplo" / "Datos de ejemplo". With Supabase
/// configured the app shows only real data.

PocketSnapshot samplePocket(Fuel fuel) => fuel == Fuel.gasoleoA ? _gasoleo : _gasolina;

const sampleTopics = <NewsTopic>[
  NewsTopic(
    id: 'tema-ejemplo-1',
    headline: 'Titular de ejemplo sobre una medida del Gobierno',
    summary: 'Entradilla de ejemplo: aquí aparece el resumen corto que publica el propio medio en su RSS.',
    url: 'https://example.com/izquierda',
    outletName: 'Medio A',
    outlets: 3,
    headlines: [
      OutletHeadline(outlet: 'Medio A', side: NewsSide.izquierda, title: 'El Gobierno aprueba la medida de ejemplo', url: 'https://example.com/izquierda'),
      OutletHeadline(outlet: 'Medio B', side: NewsSide.centro, title: 'Aprobada la medida de ejemplo', url: 'https://example.com/centro'),
      OutletHeadline(outlet: 'Medio C', side: NewsSide.derecha, title: 'La oposición critica la medida de ejemplo', url: 'https://example.com/derecha'),
    ],
  ),
  NewsTopic(
    id: 'tema-ejemplo-2',
    headline: 'Titular de ejemplo sobre geopolítica',
    summary: null,
    url: 'https://example.com/mundo',
    outletName: 'Medio D',
    outlets: 2,
    headlines: [
      OutletHeadline(outlet: 'Medio D', side: NewsSide.internacional, title: 'Titular de ejemplo sobre geopolítica', url: 'https://example.com/mundo'),
      OutletHeadline(outlet: 'Medio B', side: NewsSide.centro, title: 'Otro titular de ejemplo sobre el mismo tema', url: 'https://example.com/mundo2'),
    ],
  ),
];

const sampleLatest = <NewsItem>[
  NewsItem(
    id: 'noticia-ejemplo-1',
    topic: 'Medio B',
    title: 'Noticia suelta de ejemplo',
    summary: 'Entradilla de ejemplo de una noticia que no forma parte de los temas del día.',
    url: 'https://example.com/suelta',
    publishedAt: null,
  ),
];

final _gasoleo = PocketSnapshot(
  isSample: true,
  priceArea: 'tu zona',
  fuel: Fuel.gasoleoA,
  areaName: 'Albacete',
  averagePrice: 1.512,
  last30Days: _series(1.486, [
    0, -1, -2, -1, 0, 1, 0, -1, -2, -3, -2, -1, -2, -3, -3, -2, -1, 0, 1, 2, 3, 4, 6, 7, 9, 11,
    13, 16, 20, 26,
  ]),
  expectedChange7d: 0.024,
  reason: 'El Brent en euros ha subido un 6 % en dos semanas, y esas subidas suelen llegar al '
      'surtidor en una o dos semanas.',
  stations: const [
    Station(brand: 'Ballenoil', address: 'Av. de la Mancha, 12', distanceKm: 1.8, price: 1.454),
    Station(brand: 'Plenoil', address: 'C. Hellín, 45', distanceKm: 3.1, price: 1.459),
    Station(brand: 'Petroprix', address: 'Polígono Campollano, calle E', distanceKm: 4.6, price: 1.463),
    Station(brand: 'Repsol', address: 'Av. de España, 30', distanceKm: 0.9, price: 1.539),
  ],
);

final _gasolina = PocketSnapshot(
  isSample: true,
  priceArea: 'tu zona',
  fuel: Fuel.gasolina95,
  areaName: 'Albacete',
  averagePrice: 1.598,
  last30Days: _series(1.592, [
    0, 1, 0, 0, -1, 0, 1, 1, 0, -1, 0, 1, 0, 0, 1, 1, 0, -1, -1, 0, 1, 2, 1, 0, 1, 2, 3, 3, 4, 6,
  ]),
  expectedChange7d: 0.006,
  reason: 'La gasolina sigue menos al crudo que el gasóleo y su precio ya recoge parte de la '
      'subida. Esperamos un movimiento menor de 1 céntimo.',
  stations: const [
    Station(brand: 'Plenoil', address: 'C. Hellín, 45', distanceKm: 3.1, price: 1.549),
    Station(brand: 'Ballenoil', address: 'Av. de la Mancha, 12', distanceKm: 1.8, price: 1.552),
    Station(brand: 'Alcampo', address: 'C. Federico García Lorca, 2', distanceKm: 2.4, price: 1.561),
    Station(brand: 'Cepsa', address: 'Ctra. de Valencia, km 2', distanceKm: 1.2, price: 1.629),
  ],
);

/// Daily prices from a start value plus offsets in tenths of a cent.
List<double> _series(double start, List<int> tenthsOfCent) =>
    [for (final t in tenthsOfCent) start + t / 1000];
