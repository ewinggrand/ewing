# Wicklungsatelier für Scilab · Version 1.0

Native Scilab-Anwendung für dreiphasige Statorwicklungen: Nutenspannungsstern, natürliche Zonung, Strangspannungsstern, tatsächliches Wickelschema, Raumharmonische und Luftspaltinduktivität. Die Berechnungen laufen vollständig in Scilab; es wird keine Web-App eingebettet und kein JavaScript-Rechenkern aufgerufen.

## Herunterladen und starten

1. [Scilab Desktop](https://www.scilab.org/download) installieren. Geprüft mit **Scilab 2024.1.0** unter Linux; Scilab 2024.1 oder neuer empfohlen.
2. Das vollständige Paket `wicklungsatelier-scilab.zip` entpacken. Die Unterordner `macros`, `resources` und `tests` zusammenlassen.
3. Scilab öffnen und über **Datei → Ausführen** die Datei **`start.sce`** im entpackten Ordner `wicklungsatelier-scilab` auswählen.

Alternativ in der Scilab-Konsole, mit dem eigenen vollständigen Pfad:

```scilab
exec("C:/MeinOrdner/wicklungsatelier-scilab/start.sce", -1);
```

Unter Linux/macOS entsprechend einen Pfad wie `/home/name/wicklungsatelier-scilab/start.sce` verwenden. Es sind keine ATOMS-Toolbox, kein Node.js, kein Python und keine Internetverbindung zum Ausführen nötig. `loader.sce` lädt ausschließlich die Funktionen und öffnet keine Oberfläche; `start.sce` startet zusätzlich das Bedienfenster.

## Bedienung

Im Hauptfenster stehen links die Wicklung, das Spektrum, die Abwicklung und die Maschinenparameter. Rechts befinden sich Beispiele, Ergebnisansichten, ein kopierbarer Ergebnistext und die Exporte.

- **Q** ist die Nutenzahl, **p** die Polpaarzahl. Die Lochzahl wird daraus berechnet: **q = Q/(6p)** für drei Stränge. Q liegt zwischen 6 und 120.
- **Spulenweite y = 0** aktiviert die Automatik. Eine positive ganze Zahl legt die Weite in Nutteilungen fest. Die Automatik untersucht gleichweite Spulen innerhalb der festen natürlichen 60°-Zonung; dies ist kein allgemeines elektromagnetisches Maschinenoptimum.
- **Berechnen / aktualisieren** übernimmt geänderte Werte. Auch eine Ergebnisansicht berechnet aus den aktuellen Eingaben neu. Die vier Vorlesungsbeispiele sind direkt auswählbar.
- **Analyse** öffnet Nutenspannungsstern, Strangspannungsstern und Zonenplan in einem Scilab-Grafikfenster. Die Strangresultanten enthalten die tatsächlichen vorzeichenbehafteten Seiten beider vorhandenen Lagen.
- **Wickelschema** zeigt offene Einzelspulen oder additive Serienstränge mit U1/U2, V1/V2 und W1/W2. **Blau sind die Zähne; die Leiter liegen in den weißen Nuten dazwischen.** Die Schichten werden seitlich aufgefächert. Der Strangfilter schränkt die Zeichnung ein. `Abwicklung ab Nut = 0` wählt den automatischen Umfangsschnitt, eine Nutnummer dreht nur die Darstellung. Serienfolge und Anschlüsse bleiben gleich. Stern-/Dreieckbrücken werden nicht automatisch ergänzt.
- **Spektrum** zeigt den vorzeichenbehafteten Realteil oder den Betrag der räumlichen Fourier-Koeffizienten, als Strangsumme oder je Spule. K begrenzt die sichtbaren mechanischen Ordnungen; die Nutzgrundwelle liegt bei **k = p**. Vier analytische Folienreferenzen stehen zusätzlich zur Auswahl. Die Polungsumschaltung kehrt das gesamte Spektrum gemeinsam um.
- **Induktivität** öffnet Spulenachsen, die vollständige Selbst-/Gegeninduktivitätsmatrix sowie Durchflutung und Luftspaltflussdichte. Der Ergebnistext enthält auch die Grundwellenmatrix, die endliche Fourier-Matrix, Flussverkettung, Energie und Gruppenfaktoren.
- **Herleitung** zeigt die gewählte der sechs mathematischen Etappen als native Scilab-LaTeX-Grafik mit eingesetzten Zahlen. Die ausführlichen Erklärungen sind im Ergebnistext und im HTML-Bericht enthalten. In der Konsole liefert `ew_inductance_derivation(w,d,"A")` die sechs Etappen als kopierbaren Text.

Die Steuerung und die Diagramme sind eigene Fenster. Für große Q oder lange Formeln das Grafikfenster vergrößern. Mehrere Ansichten können gleichzeitig geöffnet bleiben.

## Maschinenwerte und mathematisches Modell

Q und p allein bestimmen keine Induktivität. Einzugeben sind der **mittlere Luftspaltdurchmesser D = 2r**, die aktive Eisenlänge, der effektive radiale Luftspalt, die Windungszahl je tatsächlicher Spule und die drei Momentanströme. Alle Spulen eines Strangs werden additiv in Serie betrachtet. Die voreingestellten Werte D=100 mm, lFe=100 mm, δ=1 mm und n=10 sind **Beispielwerte**, keine aus der Wicklung ermittelten Maße.

Das Modell setzt ideal magnetisch leitendes Eisen, einen gleichmäßigen dünnen Luftspalt und einen linearen Magnetkreis voraus. Berechnet wird die **Luftspalt-/Hauptinduktivität** ohne Nut- und Wickelkopfstreuung, Sättigung, endliche Eisenpermeabilität und Rotorsalienz. Ein bereits bestimmter Carter-Ersatzluftspalt kann eingegeben werden; die App berechnet ohne Nutabmessungen keine Carter-Zahl.

Die Herleitung behandelt sechs Etappen:

1. Mechanische Spulenmitte, orientierte Feldachse und elektrische Relativlage zur Strangmittelachse. Anschlussrichtung und geometrische Mitte werden getrennt behandelt.
2. Spulenfaktor, komplexer Gruppenfaktor und gewichtete Strangsumme. Die geometrischen Faktoren enthalten noch keinen 1/k-Faktor; dieser entsteht bei der räumlichen Integration.
3. Mittelwertfreie Wicklungsfunktion, Durchflutung Θ = Σ Nₐiₐ und B = μ₀Θ/δ.
4. Integration über die Empfangsspule aus den Folien, einschließlich beider 1/ν-Faktoren, anschließend der Übergang zum vollständigen Statorumfang.
5. Selbst- und Gegeninduktivitäten aus dem stückweisen Gram-Integral sowie unabhängig aus der Fourier-Summe. Alle Stränge behalten denselben mechanischen Winkelbezug.
6. Flussverkettung Ψ = Li, Energie W = ½iᵀLi und die Unterscheidung zwischen Sekanten- und differentieller Induktivität.

Für die dimensionslose Wicklungsfunktion w mit Einheitssprüngen und null Umfangsmittel gilt:

```text
Nₐ(φ) = n · wₐ(φ)
Lₐᵦ = μ₀ r lFe / δ · ∫₀²π Nₐ(φ) Nᵦ(φ) dφ
     = 4 μ₀ r lFe n² / (π δ) · Σₖ Re{ Cₐ,ₖ · conj(Cᵦ,ₖ) }
Ψ = L i
```

Das stückweise Integral wird ohne Fourier-Abbruch ausgewertet. Die endliche Reihe bis K dient als nachvollziehbare Näherung und Konvergenzkontrolle; K verändert das exakte Ergebnis innerhalb dieses Modells nicht. Die Matrix ist symmetrisch und positiv semidefinit. Einzelne Gegeninduktivitäten können negativ sein. Die Beziehung M = −L/2 gilt für eine symmetrische Dreiphasen-Grundwelle, nicht allgemein für die gesamte Wicklung mit allen Raumharmonischen.

Kontrollwerte für die oben genannte Beispielgeometrie, alle Spulen je Strang in Serie:

| Wicklung | Selbstinduktivität | Gegeninduktivität |
| --- | ---: | ---: |
| Q12/p1, Einschicht, y6 | 3,289868 mH | −1,315947 mH |
| Q36/p2, Einschicht, y9 | 7,128048 mH | −2,960881 mH |
| Q12/p5, Zweischicht, y1 | 1,315947 mH | 0 mH |
| Q9/p4, Zweischicht, y1 | 1,267208 mH | −0,048739 mH |

### Spektrumsreferenzen

| Referenz | Formel |
| --- | --- |
| Vollgeteilte Einzelspule | sin(kπ/2)/k |
| 3/2-Wicklung | sin(kπ/3)/k; der Name „3/2“ ist kein Amplitudenfaktor |
| Gesehnte Gruppe | [2cos(kπ/2)sin(2πk/9) − sin(kπ/6)]/k |
| Q9/p4-Gruppe | sin(kπ/9)[−1 + 2cos(2πk/9)]/k |

Die Formeln werden mit ihren tatsächlichen Vorzeichen ausgewertet. Einige Balkenvorzeichen der bereitgestellten Folien weichen von den dortigen Formeln ab. Insbesondere reproduziert beim Q9-Beispiel der Gruppenabstand 2π/9 die angegebenen Beträge. Es werden keine einzelnen Vorzeichen passend zum Bild verändert. Analytische Referenzen ohne festgelegte Maschine erhalten keine erfundene Polpaarzahl.

## Exporte

- **CSV:** Nutlagen und tatsächliche Spulen einschließlich Serienverbindungen und Klemmen; in der Spektrums- bzw. Induktivitätsansicht die entsprechende Datenreihe bzw. Matrix. Trennzeichen ist ein Semikolon, Dezimalzeichen ein Punkt.
- **JSON:** aktuelle Eingaben, alle Berechnungen und das vollständige Layout mit tatsächlichen Verbindungen, Anschlüssen und gewählter Schnittposition. Längen in den Rechenergebnissen stehen in Metern, Induktivitäten in Henry, Ströme in Ampere und Flussverkettungen in Wb·Windungen.
- **SVG:** das zuletzt geöffnete Grafikfenster als skalierbare Vektorgrafik. Für weitere native Scilab-Formate können die Exportfunktionen des Grafikfensters verwendet werden.
- **HTML-Bericht:** alle sechs Etappen mit gesetzten MathML-Formeln, eingesetzten Zahlen, Spulenachsen, Gruppenbeiträgen sowie exakter, Grundwellen- und Fourier-Matrix. Der Bericht ist eigenständig offline lesbar. In einem aktuellen Browser öffnen und bei Bedarf als PDF drucken.

## Ohne Oberfläche rechnen

```scilab
exec("C:/MeinOrdner/wicklungsatelier-scilab/loader.sce", -1);

// Q=9, p=4, Zweischicht, feste Weite1; Weite0 wäre automatisch.
w = ew_compute_winding(9, 4, 2, 1);
s = ew_compute_spectrum(w, 20, "A", "phase-sum");
par = struct("radiusM",0.05, "lengthM",0.1, "gapM",0.001, ..
             "turnsPerCoil",10, "currents",[1;0;0], ..
             "maxOrder",120, "selectedOrder",4);
d = ew_compute_inductance(w, par);
disp(d.matrixH * 1000);           // mH
disp(d.fluxLinkagesWbTurns);     // Wb·Windungen
text = ew_inductance_derivation(w, d, "A");

// Jeweils eigene vorhandene Zielordner/Pfade einsetzen.
ew_export_csv(w, "wicklung.csv");
ew_export_spectrum_csv(s, "spektrum.csv");
ew_export_inductance_csv(d, "induktivitaet.csv");
ew_export_json(w, s, d, "berechnung.json");
ew_export_report(w, d, "herleitung.html");

// Diese Befehle benötigen die Desktop-/Grafikversion:
ew_plot_winding(w, "series", 0, "");
ew_plot_spectrum(s, "real", "A");
ew_plot_derivation(w, d, 5, "A");
```

Stränge heißen `"A"`, `"B"`, `"C"`. Sammlungen wie `w.coils`, `w.slotLayers`, `d.phases`, `d.groups` und `s.coefficients` sind native Scilab-Listen mit Strukturen. `d.matrixH` ist eine reelle 3×3-Matrix, Ströme und Flussverkettungen sind Spaltenvektoren in der Reihenfolge A/B/C. Fehlende Achsen werden als nicht definiert behandelt. Ungültige Eingaben liefern verständliche Fehler; eine im festen Konstruktionsmodell nicht realisierbare Kombination liefert `.valid=%f` und keine erfundenen Spulen.

## Tests und Entwicklung

Die native Suite gegen die unabhängig erzeugten JavaScript-Referenzwerte ausführen:

```sh
scilab-cli -nb -f tests/run_tests.sce
```

Die Suite beendet diesen separaten Scilab-Prozess mit einem eindeutigen Erfolg-/Fehlerstatus. Zum interaktiven Arbeiten stattdessen `loader.sce` bzw. `start.sce` verwenden. Die Referenzdateien liegen bei; zum Ausführen der Tests wird kein Node.js benötigt. `demo.sce` zeigt zusätzlich das Q9/p4-Beispiel.

Das fertige, separat entpackte ZIP wurde mit Scilab 2024.1.0 geprüft: **91 Wicklungsreferenzen, 30 vollständige Layoutvergleiche und 30.192 Assertions**, einschließlich zusätzlicher Induktivitäts- und Exportprüfungen. Die optionale Desktop-Prüfung benötigt die vollständige Grafik-/Java-Laufzeit und einen Bildschirm:

```sh
scilab -nw -nb -f tests/gui_smoke.sce
```

Sie prüft 64 Bedingungen zu den fünf Ansichten, sechs Herleitungsetappen, Beispielen, Eingaben und Exporten. Das sichtbare Bedienfenster wurde außerdem mit Maus und Tastatur geprüft.

Im vollständigen Git-Repository können Entwickler die unabhängigen Referenzdaten mit `npm run fixtures:scilab` aus dem bestehenden JavaScript-Modell erneuern. `npm run build:scilab` setzt die LaTeX-Formeln als MathML und erstellt das veröffentlichbare ZIP. Diese beiden Erzeugungsschritte brauchen Node/npm; die fertige Scilab-Anwendung und ihr Bericht brauchen es nicht.

```text
loader.sce                 Funktionen laden, ohne Oberfläche
start.sce                  Desktop-Oberfläche starten
demo.sce                   Rechenbeispiel
macros/winding.sci         Zonung, vollständige Paarung, automatische Weite
macros/spectrum.sci        Fourier-Koeffizienten und analytische Referenzen
macros/inductance.sci      Achsen, Faktoren, Durchflutung, Fluss und Matrix
macros/graphics.sci        Native Diagramme und periodische Layoutgeometrie
macros/gui.sci             Steuerelemente, Beispiele, Ansichten und Ergebnistext
macros/export.sci          CSV, JSON, SVG, HTML und gesetzte Herleitung
resources/equations.tsv   Gebündelte LaTeX-/MathML-Formeln
tests/                    Native Tests und unabhängige Referenzdaten
```
