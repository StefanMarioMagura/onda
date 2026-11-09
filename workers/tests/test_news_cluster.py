"""Tests for grouping headlines into events."""

from onda_workers.news.cluster import Event, Item, cluster, normalise, select_topics


def items(*pairs):
    return [Item(i, outlet, title) for i, (outlet, title) in enumerate(pairs)]


STORY_PAIRS = (
    ("eldiario", "El Gobierno aprueba la subida del salario mínimo a 1.250 euros"),
    ("abc", "El Gobierno aprueba subir el salario mínimo hasta los 1.250 euros"),
    ("rtve", "Aprobada la subida del salario mínimo: 1.250 euros al mes"),
    ("elmundo", "La subida del salario mínimo a 1.250 euros enfada a la patronal"),
    ("20minutos", "Muere un actor de Hollywood a los 90 años"),
    ("lavanguardia", "El Barça gana al Madrid en el clásico"),
)
STORY = items(*STORY_PAIRS)


def test_same_story_from_several_outlets_is_one_event():
    [event] = cluster(STORY)
    assert event.outlets == {"eldiario", "abc", "rtve", "elmundo"}
    assert "salario mínimo" in event.headline


def test_event_knows_which_sides_covered_it():
    [event] = cluster(STORY)
    assert event.sides == {"izquierda", "derecha", "centro"}
    assert event.both_sides


def test_needs_at_least_three_outlets():
    assert cluster(STORY[:2]) == []


def test_one_outlets_repeated_headlines_do_not_make_an_event():
    same_outlet = items(
        ("abc", "Huelga de médicos en Madrid"),
        ("abc", "La huelga de médicos en Madrid sigue"),
        ("abc", "Tercer día de huelga de médicos en Madrid"),
    )
    assert cluster(same_outlet) == []


def test_events_with_more_outlets_come_first():
    big = items(
        ("eldiario", "Huelga de médicos en Madrid este lunes"),
        ("abc", "Huelga de médicos en Madrid: servicios mínimos"),
        ("rtve", "Comienza la huelga de médicos en Madrid"),
        ("elmundo", "Huelga de médicos en Madrid y colas en urgencias"),
        ("20minutos", "La huelga de médicos en Madrid, en directo"),
    )
    small = items(
        ("eldiario", "Nueva subida del precio del aceite de oliva"),
        ("abc", "El precio del aceite de oliva sube otra vez"),
        ("rtve", "Sube el precio del aceite de oliva en los supermercados"),
    )
    renumbered = [Item(i, it.outlet, it.title) for i, it in enumerate(small + big)]
    events = cluster(renumbered)
    assert [len(e.outlets) for e in events] == [5, 3]


def test_normalise_folds_accents_and_punctuation():
    assert normalise("¿Subirá el IPC? Sí.") == "subira el ipc  si "


def test_lead_prefers_a_headline_with_an_extract():
    with_extract = [
        Item(0, "eldiario", "El Gobierno aprueba la subida del salario mínimo a 1.250 euros"),
        Item(1, "abc", "El Gobierno aprueba subir el salario mínimo hasta los 1.250 euros", "u", "Una entradilla."),
        Item(2, "rtve", "Aprobada la subida del salario mínimo: 1.250 euros al mes"),
    ]
    [event] = cluster(with_extract)
    assert event.lead.outlet == "abc"
    assert event.headline == with_extract[1].title


def test_key_is_stable_when_the_story_grows():
    first = cluster(items(*STORY_PAIRS[:3]))[0]
    grown = cluster(items(*STORY_PAIRS[:4]))[0]
    assert first.key == grown.key == "tema-0"


def event_of(*outlets, score_id=0):
    its = tuple(Item(score_id + i, o, f"Titular {o}") for i, o in enumerate(outlets))
    return Event(its, its[0])


def test_international_needs_two_foreign_outlets():
    assert event_of("bbcmundo", "dw", "abc").international
    assert not event_of("bbcmundo", "abc", "rtve").international


def test_topics_keep_room_for_world_news():
    spanish = [event_of("abc", "rtve", "elmundo", "eldiario", score_id=i * 10) for i in range(8)]
    world = [event_of("bbcmundo", "dw", "rfi", score_id=100), event_of("bbcmundo", "dw", "france24", score_id=200)]
    topics = select_topics(spanish + world, total=8, min_world=2)
    assert len(topics) == 8
    assert sum(e.international for e in topics) == 2
    assert topics[0].score() >= topics[-1].score()


def test_topics_with_few_events():
    only = [event_of("abc", "rtve", "elmundo")]
    assert select_topics(only) == only
    assert select_topics([]) == []
