"""Tests for grouping headlines into events."""

from onda_workers.news.cluster import Item, cluster, normalise


def items(*pairs):
    return [Item(i, outlet, title) for i, (outlet, title) in enumerate(pairs)]


STORY = items(
    ("eldiario", "El Gobierno aprueba la subida del salario mínimo a 1.250 euros"),
    ("abc", "El Gobierno aprueba subir el salario mínimo hasta los 1.250 euros"),
    ("rtve", "Aprobada la subida del salario mínimo: 1.250 euros al mes"),
    ("elmundo", "La subida del salario mínimo a 1.250 euros enfada a la patronal"),
    ("20minutos", "Muere un actor de Hollywood a los 90 años"),
    ("lavanguardia", "El Barça gana al Madrid en el clásico"),
)


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
