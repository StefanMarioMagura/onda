import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/affinity.dart';
import '../domain/discover.dart';

/// ONDA's own Descubre content: real stories, debates, quizzes and clips,
/// written by hand. News are added to the stream by the news repository.

/// Editorial stances of every rateable item, by id (for the political map).
/// Only debates count: real news have no editorial marking.
final stancesProvider = Provider<Map<String, Stance>>((ref) => {
      for (final d in discoverContent)
        if (d.stance != null) d.id: d.stance!,
    });

const discoverContent = <DiscoverItem>[
  DebateItem(
    id: 'debate-jornada-375',
    statement: 'Reducir la jornada laboral máxima a 37,5 horas semanales sin bajar el sueldo.',
    context: 'Hoy el máximo legal es de 40 horas semanales.',
    stance: Stance({PolAxis.economia: -1}),
  ),
  DebateItem(
    id: 'debate-tope-alquiler',
    statement: 'Limitar por ley el precio del alquiler en las zonas con más tensión.',
    context: 'La ley de vivienda de 2023 permite a las comunidades declarar zonas tensionadas.',
    stance: Stance({PolAxis.economia: -1}),
  ),
  DebateItem(
    id: 'debate-grandes-fortunas',
    statement: 'Subir el impuesto a las grandes fortunas.',
    context: 'Desde 2022 existe un impuesto temporal de solidaridad sobre patrimonios de más de 3 millones de euros.',
    stance: Stance({PolAxis.economia: -1}),
  ),
  DebateItem(
    id: 'debate-subir-smi',
    statement: 'Subir el salario mínimo cada año por encima de la inflación.',
    context: 'El Gobierno lo fija cada año, tras consultar a sindicatos y patronal.',
    stance: Stance({PolAxis.economia: -1}),
  ),
  DebateItem(
    id: 'debate-bajar-irpf',
    statement: 'Bajar el IRPF aunque haya que recortar gasto público.',
    context: 'El IRPF es el impuesto que más recauda el Estado.',
    stance: Stance({PolAxis.economia: 1}),
  ),
  DebateItem(
    id: 'debate-sucesiones',
    statement: 'Eliminar el impuesto de sucesiones y donaciones.',
    context: 'Lo gestionan las comunidades autónomas y varias ya lo han bonificado casi por completo.',
    stance: Stance({PolAxis.economia: 1}),
  ),
  DebateItem(
    id: 'debate-cotizaciones',
    statement: 'Reducir las cotizaciones sociales que pagan las empresas por cada trabajador.',
    context: 'Las cotizaciones financian sobre todo las pensiones.',
    stance: Stance({PolAxis.economia: 1}),
  ),
  DebateItem(
    id: 'debate-despido',
    statement: 'Abaratar el despido para que a las empresas les cueste menos contratar.',
    context: 'La indemnización general por despido improcedente es de 33 días por año trabajado.',
    stance: Stance({PolAxis.economia: 1}),
  ),
  DebateItem(
    id: 'debate-reincidencia',
    statement: 'Endurecer las penas para quien reincide en delitos leves, como los hurtos.',
    context: 'Hoy muchos hurtos de menos de 400 euros se castigan solo con multa.',
    stance: Stance({PolAxis.sociedad: 1}),
  ),
  DebateItem(
    id: 'debate-inmigracion',
    statement: 'Reducir la llegada de inmigrantes y endurecer las expulsiones.',
    context: 'En 2025 vivían en España algo más de 7 millones de personas nacidas en el extranjero.',
    stance: Stance({PolAxis.sociedad: 1}),
  ),
  DebateItem(
    id: 'debate-religion',
    statement: 'Dar más peso a la asignatura de Religión en la escuela.',
    context: 'Hoy es optativa y no cuenta para la nota media.',
    stance: Stance({PolAxis.sociedad: 1}),
  ),
  DebateItem(
    id: 'debate-eutanasia',
    statement: 'Mantener la ley que regula la eutanasia.',
    context: 'La ley está en vigor desde 2021.',
    stance: Stance({PolAxis.sociedad: -1}),
  ),
  DebateItem(
    id: 'debate-regularizacion',
    statement: 'Regularizar a los inmigrantes que ya viven y trabajan en España sin papeles.',
    context: 'En 2024 el Congreso admitió a trámite una iniciativa legislativa popular con este objetivo.',
    stance: Stance({PolAxis.sociedad: -1}),
  ),
  DebateItem(
    id: 'debate-toros',
    statement: 'Prohibir las corridas de toros.',
    context: 'Están protegidas como patrimonio cultural por una ley de 2013.',
    stance: Stance({PolAxis.sociedad: -1}),
  ),
  DebateItem(
    id: 'debate-recentralizar',
    statement: 'Que el Estado vuelva a gestionar la sanidad y la educación.',
    context: 'Hoy las gestionan las comunidades autónomas.',
    stance: Stance({PolAxis.territorio: 1}),
  ),
  DebateItem(
    id: 'debate-castellano-vehicular',
    statement: 'Que el castellano sea lengua vehicular en todas las escuelas de España.',
    context: 'En comunidades con lengua propia, cada una decide cómo reparte las lenguas en la escuela.',
    stance: Stance({PolAxis.territorio: 1}),
  ),
  DebateItem(
    id: 'debate-concierto',
    statement: 'Suprimir el concierto económico vasco y el convenio navarro.',
    context: 'Permiten al País Vasco y a Navarra recaudar sus propios impuestos.',
    stance: Stance({PolAxis.territorio: 1}),
  ),
  DebateItem(
    id: 'debate-financiacion-singular',
    statement: 'Dar a Cataluña una financiación propia, parecida a la del País Vasco.',
    context: 'Hoy Cataluña está en el sistema de financiación común de las comunidades.',
    stance: Stance({PolAxis.territorio: -1}),
  ),
  DebateItem(
    id: 'debate-referendum',
    statement: 'Permitir referéndums de autodeterminación pactados con el Estado.',
    context: 'La Constitución no contempla hoy este tipo de consulta.',
    stance: Stance({PolAxis.territorio: -1}),
  ),
  DebateItem(
    id: 'debate-cercanias',
    statement: 'Traspasar la gestión de los trenes de Cercanías a las comunidades autónomas.',
    context: 'En 2024 se acordó el traspaso de Rodalies a Cataluña.',
    stance: Stance({PolAxis.territorio: -1}),
  ),
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
  FactItem(
    id: 'gasolineras',
    topic: 'Dato',
    figure: '11.400',
    text: 'gasolineras, más o menos, publican sus precios en España. ONDA los revisa cada media hora.',
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
