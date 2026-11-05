import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../domain/discover.dart';
import '../domain/fuel.dart';
import '../domain/wave.dart';

/// Sample content for the prototype. Clearly fictional: the UI shows a
/// "Datos de ejemplo" label until these providers read from Supabase.
const usingSampleData = true;

final todayWavesProvider = Provider<List<Wave>>((ref) => _waves);

final pocketProvider = Provider.family<PocketSnapshot, Fuel>((ref, fuel) =>
    fuel == Fuel.gasoleoA ? _gasoleo : _gasolina);

/// Euros saved this month by following the semáforo (sample).
final monthlySavingProvider = Provider<double>((ref) => 4.20);

/// Pool the endless "Descubre" stream is built from (see discoverAt).
final discoverPoolProvider = Provider<List<DiscoverItem>>((ref) => _discover);

const _discover = <DiscoverItem>[
  StoryItem(
    id: 'campoamor',
    topic: 'Historia política',
    year: '1931',
    title: 'Clara Campoamor ganó el voto de las mujeres casi sola',
    body: 'En las Cortes de 1931 defendió el sufragio femenino frente a buena parte de su propio '
        'partido. El 1 de octubre se aprobó por 161 votos a 121, y en 1933 las españolas votaron '
        'por primera vez en unas elecciones generales.',
  ),
  QuizItem(
    id: 'barril',
    topic: 'Quiz',
    question: '¿Cuántos litros tiene un barril de petróleo?',
    options: ['100 litros', '159 litros', '200 litros'],
    correct: 1,
    explanation: 'Un barril son 42 galones estadounidenses: unos 159 litros. Por eso un barril a 75 \$ '
        'son menos de 50 céntimos por litro de crudo.',
  ),
  ClipItem(
    id: 'diesel-2022',
    topic: 'Clip · Economía',
    title: 'Por qué el gasóleo superó a la gasolina',
    beats: [
      '2022',
      'El gasóleo pasó a costar más que la gasolina',
      'Rusia era el gran proveedor de diésel de Europa',
      'Las sanciones cortaron ese suministro',
      'Menos oferta, el mismo consumo',
      'Resultado: el precio se disparó',
    ],
  ),
  StoryItem(
    id: 'salas',
    topic: 'Ciencia',
    year: '1989',
    title: 'La patente de Margarita Salas fue la más rentable del CSIC',
    body: 'Estudiando un virus que infecta bacterias, su equipo descubrió una enzima, la ADN '
        'polimerasa del fago phi29, capaz de copiar ADN de forma muy eficaz. Hoy se usa en '
        'laboratorios de todo el mundo para analizar muestras genéticas diminutas.',
  ),
  PredictionItem(
    id: 'gasoleo-semana',
    topic: 'Predicción',
    question: '¿Subirá el gasóleo más de 1 céntimo esta semana?',
    stake: 20,
    resolvesOn: 'el miércoles 11',
  ),
  FactItem(
    id: 'gasolineras',
    topic: 'Dato',
    figure: '11.457',
    text: 'gasolineras publicaron sus precios hoy en España. ONDA las revisa cada media hora.',
    source: 'Ministerio para la Transición Ecológica',
  ),
  StoryItem(
    id: 'cajal',
    topic: 'Ciencia',
    year: '1906',
    title: 'Ramón y Cajal dibujó el cerebro antes de que pudiera fotografiarse',
    body: 'Con un microscopio y tinta china demostró que el sistema nervioso está formado por '
        'células independientes, las neuronas. Ganó el Nobel en 1906 y sus dibujos aún se usan '
        'para enseñar neurociencia.',
  ),
  QuizItem(
    id: 'impuestos',
    topic: 'Quiz',
    question: '¿Qué parte de lo que pagas por la gasolina son impuestos?',
    options: ['Una cuarta parte', 'Alrededor de la mitad', 'Tres cuartas partes'],
    correct: 1,
    explanation: 'Entre el impuesto especial sobre hidrocarburos y el IVA del 21 %, los impuestos '
        'suelen rondar la mitad del precio final.',
  ),
  ClipItem(
    id: 'euribor',
    topic: 'Clip · Tu dinero',
    title: 'El euríbor en 20 segundos',
    beats: [
      'Euríbor',
      'El interés al que se prestan dinero los bancos europeos',
      'Casi todas las hipotecas variables van atadas a él',
      'Sube el euríbor: sube tu cuota',
      'Baja el euríbor: baja tu cuota',
    ],
  ),
  StoryItem(
    id: 'reforma-politica',
    topic: 'Historia política',
    year: '1976',
    title: 'Las Cortes de Franco votaron su propio final',
    body: 'En noviembre de 1976, las Cortes franquistas aprobaron la Ley para la Reforma Política, '
        'que abría paso a elecciones democráticas. En diciembre, el 94 % de los votantes la '
        'respaldó en referéndum.',
  ),
  FactItem(
    id: 'renovables',
    topic: 'Dato',
    figure: '57 %',
    text: 'de la electricidad que se generó en España en 2024 fue renovable: más de la mitad, por segundo año seguido.',
    source: 'Red Eléctrica',
  ),
];

const _waves = [
  Wave(
    id: 'brent-sube',
    layer: Capa.bolsillo,
    source: 'Ministerio para la Transición Ecológica · EIA',
    cards: [
      WaveCard(
        headline: 'El petróleo sube un 6 % en dos semanas',
        body: 'El barril de Brent ha pasado de 71 a 75 dólares desde finales de octubre, '
            'tras los recortes de producción anunciados por varios países exportadores.',
        figure: KeyFigure('+6 %', 'Brent en 14 días'),
        teaser: '¿Cuándo lo notarás en la gasolinera?',
      ),
      WaveCard(
        headline: 'Lo que pasa con el crudo llega al surtidor en una o dos semanas',
        body: 'Las gasolineras compran combustible con antelación, así que las subidas del '
            'petróleo tardan unos días en trasladarse. En el último año, cada subida del 5 % '
            'del Brent acabó en unos 2 céntimos más por litro.',
        teaser: '¿Cuánto es eso para ti?',
      ),
      WaveCard(
        headline: 'Unos 1,20 € más cada vez que llenas el depósito',
        body: 'Con un depósito de 50 litros y la subida que esperamos para el gasóleo, '
            'cada repostaje te costaría algo más que la semana pasada.',
        figure: KeyFigure('+1,20 €', 'por depósito de 50 l'),
        teaser: '¿Puedes evitarlo?',
      ),
      WaveCard(
        headline: 'Si te queda menos de medio depósito, llena esta semana',
        body: 'El semáforo está en verde para el gasóleo en tu zona.',
        actions: [
          'Llena antes del fin de semana.',
          'La gasolinera más barata a menos de 5 km te ahorra 2,90 € por depósito.',
          'Si puedes esperar dos semanas, no compensa: se espera que siga alta.',
        ],
      ),
    ],
  ),
  Wave(
    id: 'smi',
    layer: Capa.pais,
    source: 'BOE · INE',
    shores: TwoShores(
      supporters: 'Destacan que el salario mínimo ha perdido poder de compra '
          'con la inflación de los últimos años y que la subida ayuda a 2 millones de personas.',
      critics: 'Advierten de que encarece la contratación para pequeños '
          'negocios del campo y la hostelería, sobre todo en las regiones con salarios más bajos.',
      sharedFacts: [
        'La subida es de 50 € al mes en 14 pagas.',
        'Se aplica desde el 1 de enero.',
        'Afecta sobre todo a menores de 25 años y a empleos a tiempo parcial.',
      ],
    ),
    cards: [
      WaveCard(
        headline: 'El salario mínimo sube 50 euros al mes',
        body: 'El Gobierno ha aprobado la subida del salario mínimo interprofesional para el '
            'próximo año, tras negociarla con los sindicatos.',
        figure: KeyFigure('+50 €', 'al mes, en 14 pagas'),
        teaser: '¿Por qué hay tanta discusión?',
      ),
      WaveCard(
        headline: 'Más sueldo para unos, más costes para otros',
        body: 'Es una de las medidas que más divide: mejora los ingresos más bajos, pero sube el '
            'coste de contratar. Mira cómo lo cuenta cada lado y en qué coinciden.',
        teaser: '¿Y a ti, cómo te afecta?',
      ),
      WaveCard(
        headline: 'Si cobras el mínimo, 700 € más al año',
        body: 'Si no lo cobras, lo notarás de forma indirecta: algunos servicios con mucha mano '
            'de obra, como la hostelería, suelen subir precios en los meses siguientes.',
        figure: KeyFigure('700 €', 'más al año con el salario mínimo'),
        teaser: '¿Tienes que hacer algo?',
      ),
      WaveCard(
        headline: 'Comprueba tu nómina de enero',
        body: 'La subida es automática, pero conviene revisarla.',
        actions: [
          'Mira que tu nómina de enero refleje el nuevo importe.',
          'Si trabajas a tiempo parcial, la subida es proporcional a tus horas.',
        ],
      ),
    ],
  ),
  Wave(
    id: 'bce-tipos',
    layer: Capa.mundo,
    source: 'Banco Central Europeo · Banco de España',
    cards: [
      WaveCard(
        headline: 'El Banco Central Europeo baja los tipos de interés',
        body: 'El BCE ha recortado un cuarto de punto el precio del dinero porque la inflación '
            'en la zona euro ya está cerca de su objetivo del 2 %.',
        figure: KeyFigure('−0,25', 'puntos'),
        teaser: '¿Qué tiene que ver con tu hipoteca?',
      ),
      WaveCard(
        headline: 'El euríbor suele moverse antes que el BCE',
        body: 'El euríbor, el índice al que van ligadas la mayoría de hipotecas variables, '
            'ya había bajado al anticipar la decisión. Ahora se espera que se estabilice.',
        teaser: '¿Cuánto bajará tu cuota?',
      ),
      WaveCard(
        headline: 'Unos 25 € menos al mes en una hipoteca media',
        body: 'Para una hipoteca variable de 150.000 € a 25 años, en la próxima revisión anual.',
        figure: KeyFigure('−25 €', 'al mes, hipoteca de 150.000 €'),
        teaser: '¿Y si tu hipoteca es fija?',
      ),
      WaveCard(
        headline: 'Si es variable, mira cuándo te toca revisión',
        body: 'Si es fija, tu cuota no cambia. Los depósitos y cuentas remuneradas pagarán algo menos.',
        actions: [
          'Busca en tu contrato el mes de revisión del euríbor.',
          'Si tienes un depósito a punto de vencer, compara antes de renovarlo.',
        ],
      ),
    ],
  ),
  Wave(
    id: 'luz-finde',
    layer: Capa.bolsillo,
    source: 'Red Eléctrica · OMIE',
    cards: [
      WaveCard(
        headline: 'La luz será un 30 % más barata este domingo',
        body: 'Se espera mucho viento y sol y poca demanda, así que el precio mayorista de la '
            'electricidad bajará con fuerza el fin de semana.',
        figure: KeyFigure('−30 %', 'domingo frente a un día laborable'),
        teaser: '¿Lo notarás en tu factura?',
      ),
      WaveCard(
        headline: 'Solo si tienes la tarifa regulada',
        body: 'Con la tarifa regulada (PVPC), el precio cambia cada hora. Con tarifa fija de '
            'mercado libre pagas lo mismo cualquier día.',
        teaser: '¿Cuánto puedes ahorrar?',
      ),
      WaveCard(
        headline: 'Unos 2 € por mover la colada y el lavavajillas',
        body: 'Poner lavadora, secadora y lavavajillas el domingo entre las 13 y las 17 h en lugar de '
            'un martes por la tarde.',
        figure: KeyFigure('2 €', 'de ahorro este fin de semana'),
        teaser: '¿Qué hago?',
      ),
      WaveCard(
        headline: 'Deja los electrodomésticos grandes para el domingo',
        body: 'Las horas más baratas serán las del mediodía.',
        actions: [
          'Programa la lavadora y el lavavajillas entre las 13 y las 17 h.',
          'Si tienes coche eléctrico, cárgalo a esa hora.',
        ],
      ),
    ],
  ),
  Wave(
    id: 'aranceles',
    layer: Capa.mundo,
    source: 'Comisión Europea · ICEX',
    cards: [
      WaveCard(
        headline: 'Estados Unidos sube los aranceles al aceite de oliva europeo',
        body: 'Washington aplicará un arancel del 15 % al aceite de oliva importado de la Unión '
            'Europea a partir del próximo mes.',
        figure: KeyFigure('15 %', 'de arancel'),
        teaser: '¿Por qué importa en España?',
      ),
      WaveCard(
        headline: 'España vende allí uno de cada cinco litros que exporta',
        body: 'Estados Unidos es el segundo mayor comprador de aceite español. Si exportar sale más '
            'caro, parte de ese aceite se quedará en Europa.',
        teaser: '¿Y eso es bueno o malo para ti?',
      ),
      WaveCard(
        headline: 'Puede que el aceite baje un poco en el súper',
        body: 'Con más aceite en el mercado europeo, los analistas esperan una ligera bajada de '
            'precio en los próximos meses. Para los productores, en cambio, es una mala noticia.',
        figure: KeyFigure('−3 %', 'precio esperado en tienda'),
        teaser: '¿Merece la pena esperar para comprar?',
      ),
      WaveCard(
        headline: 'No hace falta acumular aceite',
        body: 'La bajada, si llega, será pequeña y gradual.',
        actions: [
          'Compra lo que necesites, sin hacer acopio.',
          'Compara el precio por litro entre formatos: la garrafa de 5 l suele salir más barata.',
        ],
      ),
    ],
  ),
];

final _gasoleo = PocketSnapshot(
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
