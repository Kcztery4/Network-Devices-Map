# Network Devices Map

Samodzielna aplikacja (Godot 4.5) do wizualizacji sieci na mapie: nakładanie
urządzeń sieciowych (Rack, Switch, Access Point) na podkład mapy (PNG/SVG),
rysowanie połączeń uplink między nimi oraz zapis/wczytanie projektu i eksport
widoku do PNG.

## Funkcje

- Wczytanie podkładu mapy (PNG lub SVG)
- Dodawanie urządzeń: Rack, Switch, Access Point
- Dokowanie Switchy do Racków (przeciągnij i upuść)
- Rysowanie strzałek uplink (Copper / Fiber 1G / Fiber 10G) między urządzeniami
- Nazywanie i skalowanie obiektów
- Zapis/wczytanie projektu (Godot `Resource`/`.tres`)
- Eksport widoku mapy do PNG

## Wymagania

- [Godot Engine 4.5](https://godotengine.org/)

## Uruchomienie

1. Otwórz folder projektu w Godot Engine (`project.godot`).
2. Uruchom scenę główną (`F5`) lub zbuduj `.exe` przez Project → Export.

## Status

Projekt w aktywnym rozwoju, etapami — patrz historia commitów.

## Licencja

Brak jawnej licencji na razie — wszelkie prawa zastrzeżone, chyba że autor
zdecyduje inaczej.
