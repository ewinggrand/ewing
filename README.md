# Wicklungsatelier

Interaktive deutschsprachige Web-App zum Entwurf dreiphasiger Statorwicklungen aus **Nutenzahl Q** und **Polpaarzahl p**. Fachliche Grundlage sind die bereitgestellten Vorlesungsfolien zum Nutenspannungsstern, zur natürlichen Zonung und zum Wickelschema. Alle Diagramme werden aus der Berechnung als SVG erzeugt.

## App herunterladen und öffnen

1. **[Offline-App als ZIP](downloads/wicklungsatelier-offline.zip)** öffnen und auf GitHub **Download raw file** wählen (Download-Symbol).
2. Die ZIP-Datei auf dem eigenen Rechner entpacken.
3. `wicklungsatelier.html` per Doppelklick im Browser öffnen.

Es sind keine Installation und keine Internetverbindung nötig. Alternativ das gesamte Repository über **Code → Download ZIP** herunterladen; die fertige App liegt im Unterordner `downloads/`.

Die direkt ausführbare **[HTML-Datei](downloads/wicklungsatelier.html)** ist ebenfalls enthalten. Auf GitHub wird deren Quelltext angezeigt; zum Ausführen die Datei herunterladen und im eigenen Browser öffnen.

## Starten

Voraussetzung: Node.js 20.19+ oder 22.12+ und npm (in der Cloud mit Node 24 geprüft).

```sh
cd /workspace/ewing
npm ci --cache /workspace/.npm-cache
npm run dev -- --port 5173 --strictPort
```

`npm run build` erstellt die statische Anwendung in `dist/`. `npm run preview -- --port 4173 --strictPort` startet die Vorschau des Produktionsbuilds. Es werden kein Backend, keine Datenbank und keine Zugangsdaten benötigt. Berechnungen und Exporte erfolgen im Browser; die App verwendet keine externen Schriftarten oder Analyse-Dienste.

## Bedienung

### Ohne Installation direkt im Browser öffnen

`downloads/wicklungsatelier.html` ist die mitgelieferte eigenständige Version. Der lokale Build erstellt dieselbe App in `dist/wicklungsatelier.html` und ein ZIP-Paket in `dist/wicklungsatelier-offline.zip`. Sie benötigt keinen Webserver und keine Internetverbindung. Berechnung, Diagramme und Exporte funktionieren auch offline.

Zum Neuerstellen nach Quelländerungen:

```sh
npm run build:standalone
```

Vor dem Commit einer neuen Download-Version `npm run build:downloads` ausführen. Dieser ausdrückliche Release-Schritt aktualisiert die versionierten Dateien unter `downloads/`; die normale Einrichtung verändert diese Dateien nicht. Generierte HTML- und ZIP-Dateien nicht von Hand bearbeiten.

Die Cloud-Einrichtungsansicht stellt keine automatisch erreichbare Webvorschau bereit. Das Veröffentlichen der Cloud-Umgebung speichert die Entwicklungsumgebung; für eine öffentliche Website ist ein separates Webhosting nötig. Alternativ die eigenständige HTML-Datei verwenden.

### Parameter und Ergebnisse

1. Q (6–120), p (1 bis Q/2), Ein-/Zweischicht und automatische oder feste Spulenweite wählen.
2. **Wicklung berechnen** anklicken. Die Ergebnisse bleiben bis zur nächsten Berechnung erhalten; geänderte Parameter sind gekennzeichnet.
3. Im Nutenspannungsstern oder Zonenplan eine Nut auswählen. Die Auswahl hebt die zugehörigen Leiter im Wickelschema hervor. Die Stränge A, B und C sind einzeln filterbar.
4. In **Wickelschema** zwischen offenen Einzelspulen und additiver Serienverschaltung mit U1/U2, V1/V2 und W1/W2 wechseln. Die automatische Abwicklung hält Spulengruppen möglichst zusammen. Über **Abwicklung beginnen bei** lässt sich ausschließlich der angezeigte Umfangsschnitt drehen; die Serienfolge und die Klemmen bleiben gleich. Stern-/Dreieckbrücken sind nicht enthalten.
5. **Berechnungsweg** erklärt Formeln, Vorzeichen, Bewertungsmaßstab und Grenzen. **Exportieren** bietet Nutbelegung und Spulen als CSV, sichtbare Diagramme als SVG und die vollständige Berechnung als JSON.
6. **Spektrum** zeigt die räumlichen Fourier-Koeffizienten der aktuellen Wicklung oder vier analytische Vergleichskurven. Strang, Normierung, höchste Ordnung, Realteil/Betrag und Strangpolung lassen sich auswählen. Eine Spektrallinie anklicken, um ihre Werte zu sehen; Spektrums-CSV sowie SVG und JSON stehen als Export bereit.

Die blauen Rechtecke stellen **Zähne** dar. Alle aktiven Spulenseiten liegen in den **weißen Nuten zwischen den Zähnen**. Große Wickelschemata können innerhalb ihrer Karte horizontal gescrollt werden. Die SVGs bleiben unabhängig von der Bildschirmauflösung skalierbar.

### Wickelschema und Spulengruppen

Die Zeichnung wird aus denselben tatsächlichen Spulenseiten und Spulenverbindungen aufgebaut wie Spannungssterne und Spektrum. Die Köpfe haben eine gemeinsame Steigung; ihre Höhe folgt der mechanischen Spulenweite. Der untere V-Kopf jeder Spule besitzt zwei getrennte offene Enden. Eine geschlossene, kurzgeschlossene Einzelwindung wird nicht gezeichnet.

Im Serienmodus verbindet jede Brücke das negative Ende einer Spule mit dem positiven Anfang der nächsten Spule desselben Strangs. Der kanonische Serienpfad wird einmal aus der automatischen Gruppenanordnung bestimmt und bleibt bei manueller Drehung der Abwicklung identisch. Brücken verwenden getrennte Höhen, wenn ihre horizontalen Abschnitte überlappen; voneinander getrennte Gruppen können die kleinen lokalen Höhen wiederverwenden. Helle Unterlegungen trennen Kreuzungen optisch. Offene Klemmen liegen in der Nähe der zugehörigen Gruppe.

Für **Q9, p4, Zweischicht, y1** beginnt die automatische Abwicklung in **Nut9** und zeigt neun vollständige Zahnspulen:

| Strang | Additive Serienfolge   | Anfang      | Ende        |
| ------ | ---------------------- | ----------- | ----------- |
| A      | U1 → A9 → A1 → A2 → U2 | Nut1, Lage2 | Nut2, Lage1 |
| B      | V1 → B3 → B4 → B5 → V2 | Nut4, Lage2 | Nut5, Lage1 |
| C      | W1 → C6 → C7 → C8 → W2 | Nut7, Lage2 | Nut8, Lage1 |

Die Nutfolge lautet **9,1,2,3,4,5,6,7,8,9**. Die beiden Randachsen stellen dieselbe Nut am Umfangsschnitt dar: Nut9/Lage1 erscheint links, Nut9/Lage2 rechts. Insgesamt werden genau **18 aktive Seiten** gezeichnet, jede genau einmal. Lage1 liegt zur Lesbarkeit rechts, Lage2 links innerhalb einer Nut; dies ist eine seitliche grafische Auffächerung, keine Änderung der tatsächlichen Schichtung.

Die Pfeile zeigen die positive Richtung der benannten Stranganschlüsse. Die beigefügte Zahnspulen-Vorlage zeigt gegenüber dieser Zuordnung eine gemeinsame Umkehr der Anschlussrichtung. Durch Vertauschen der beiden Anschlüsse jedes Strangs kehren sich alle betreffenden Pfeile und Spannungen um. Die Zeichnung passt keine einzelnen Spulenzeichen an eine Vorlage an.

Die Polteilung **τp=Q/(2p)** ist mit ihrer tatsächlichen mechanischen Länge im Nutraster markiert. Gesplittete Spulenköpfe und Serienbrücken werden am Umfangsschnitt in korrekter Höhe fortgesetzt. Zahn- und Nutnummern bezeichnen unterschiedliche Objekte; die obere Zonenleiste zeigt ausdrücklich die Belegung der ersten Lage. Unter der Zeichnung stehen die tatsächlichen Serienketten. CSV enthält zusätzlich Verbindungen und Klemmen; JSON enthält das vollständige Layout mit Topologie und Schnittposition. Ein SVG-Export hält die gewählte Abwicklung und die Polteilung fest.

## Raumspektrum der Wicklung

Die bisherigen Wicklungsfaktoren sind Beträge geometrischer Zeigersummen. Das neue Spektrum enthält zusätzlich die Integration zur räumlichen Wicklungsfunktion und damit den **Faktor 1/k**. Es wird aus den tatsächlich vorhandenen, vorzeichenbehafteten Spulenseiten beider Lagen berechnet:

```text
φn = 2π(n−1)/Q                 mechanische Nutlage
Dk = Σ sn · exp(−j k φn)       mechanische Raumordnung k ≥ 1
Ck = Dk / (2 j k)             Strangsumme
Ck,Spule = Ck / Nc            mittlere Spule; Nc = Spulenzahl des Strangs
```

Die Skalierung entspricht π mal dem komplexen Fourier-Koeffizienten einer Wicklungsfunktion mit Einheitssprüngen an den Leitern. Dadurch hat eine vollgeteilte Einzelspule die Referenz **sin(kπ/2)/k**. Ohne gültiges Wickelschema wird keine Kurve berechnet.

**k ist mechanisch**, im Unterschied zur bisherigen elektrischen Ordnung ν. Die Nutzgrundwelle der berechneten Wicklung liegt bei **k=p**, und ν=k/p. Insbesondere liegt sie bei Q9/p4 an k4. Ihr Betrag ist bei der Strangsumme **Nc·kw1/p** und je Spule **kw1/p**. Eine Grundwelle oberhalb des gewählten Plotbereichs wird weiterhin berechnet und als außerhalb des Bereichs gekennzeichnet.

Für die aktuelle Wicklung wird ein einziger mechanischer Bezugswinkel **φ0=arg(Cp)/p** festgelegt. Alle Ordnungen werden mit **exp(−jkφ0)** gedreht; die Nutzgrundwelle ist dann positiv reell. **Re(Ck)** ist der vorzeichenbehaftete Realteil, **|Ck|** der davon getrennte Amplitudenbetrag. Der Imaginärteil bleibt in Detailkarte, Tabelle und Export erhalten. Eine Umkehr der Strangpolung multipliziert alle komplexen Koeffizienten gemeinsam mit −1. Negative Realteile bedeuten keine negativen Frequenzen und beweisen keinen Feld-Drehsinn.

### Vergleich mit den bereitgestellten Spektrumsfolien

| Referenz                 | Ausgewertete Formel                                                 |
| ------------------------ | ------------------------------------------------------------------- |
| Vollgeteilte Einzelspule | sin(kπ/2)/k                                                         |
| 3/2-Wicklung             | sin(kπ/3)/k; „3/2“ ist der Name, kein zusätzlicher Amplitudenfaktor |
| Gesehnte Spulengruppe    | [2 cos(kπ/2) sin(2πk/9) − sin(kπ/6)]/k                              |
| 9-Nuten-Spulengruppe, p4 | sin(kπ/9)[−1 + 2 cos(2πk/9)]/k                                      |

Die Formeln werden unverändert ausgewertet. Die gesehnte Referenz besitzt gegenüber dem gezeichneten Beispiel eine gemeinsame Vorzeichenumkehr, die sich mit der Polungsumschaltung nachvollziehen lässt. Beim 9-Nuten-Beispiel reproduziert ein Gruppenabstand von **2π/9** die angegebenen Beträge; die Lesart des kleinen Gruppenexponenten in der Abbildung ist nicht eindeutig. Einzelne positive Folienbalken stimmen nicht mit den vorzeichenbehafteten Formelwerten überein. Dieser Unterschied wird angezeigt; es werden keine einzelnen Vorzeichen angepasst, um einen Plot nachzuzeichnen.

Die analytischen Referenzen erhalten keine erfundene Polpaarzahl. Wo eine Nutzgrundwelle nicht festgelegt ist, wird ein ausdrücklich benannter Bezugskoeffizient angezeigt. Das Spektrum beschreibt idealisierte Linienleiter und gleiche Windungszahlen; Stromspektren, Flussdichten und mit-/gegenläufige Drehfelder erfordern zusätzliche Maschinen- und Erregungsdaten.

## Mathematisches Modell

- Drei Stränge mit identischen Windungszahlen und gleichen idealisierten Nutspannungen.
- Lochzahl **q = Q/(6p)**; elektrischer Nutwinkel **α = 360°p/Q**; Polteilung **τp = Q/(2p)**.
- Elektrischer Winkel der Nut n: **θn = (n−1)α**. Mehrere Nuten können denselben elektrischen Winkel haben.
- Feste natürliche 60°-Zonenfolge **+A, −C, +B, −A, +C, −B**. Zonen werden deterministisch gegenüber den vorhandenen Sternstrahlen ausgerichtet. Für die Folienreferenz Q12/p1 entsteht **+A,+A,−C,−C,+B,+B,−A,−A,+C,+C,−B,−B**.
- Die Strangspannung ist die komplexe Summe aller tatsächlichen zugehörigen Spulenseiten **Σ sign(n)·exp(jθn)**. Negative Seiten werden vor der Summierung um 180° gedreht. Der Grundwellen-Wicklungsfaktor ist der Betrag der Summe geteilt durch die Seitenzahl des Strangs.
- **Einschicht:** vollständige Paarung positiver und negativer Seiten desselben Strangs über ein bipartites Matching. Jede Nut wird genau einmal belegt, jede Spule hat die gewählte mechanische Weite.
- **Zweischicht:** jede Seite der ersten Lage wird mit einer um y Nuten versetzten, entgegengesetzt orientierten Seite der zweiten Lage verbunden. Beide Lagen werden für die Spannung und Wicklungsfaktoren ausgewertet.
- Ein gültiger Entwurf benötigt eine vollständige Spulenpaarung und drei von null verschiedene, gleich große Strangspannungen mit 120° Versatz. Scheitert dies, werden Zonung und Diagnose angezeigt, aber keine erfundenen Spulen ausgegeben.
- Raumharmonische werden analog mit **exp(jνθn)** berechnet. Die angezeigten Werte sind geometrische Wicklungsfaktoren und kein Strom- oder Feldspektrum einer konkreten Maschine.

### Was bedeutet „automatisch“?

Der geprüfte Kandidatenraum umfasst **gleichweite Spulen mit y = 1 bis ceil(Q/(2p))**, begrenzt auf höchstens Q/2, bei fester Zonung. Unter den vollständigen und symmetrischen Kandidaten gewinnt der höchste Grundwellen-Wicklungsfaktor, bei Gleichstand die kürzere Weite. In Einschicht ändert die Paarung bei fester Zonung den Strangstern nicht; dort verkürzt die Automatik die Weite.

Das ist **kein allgemeines elektromagnetisches Optimum**. Andere Zonungen, gemischte Weiten, Parallelzweige, Nutgeometrie, Drahtquerschnitt, thermische Grenzen, Wickelkopfkreuzungen und eine gemeinsame Bewertung von Oberwellen oder Verlusten werden nicht optimiert. Eine im Modell ungültige Kombination ist nicht generell physikalisch ausgeschlossen. Die Serienverbindungen folgen der kanonischen geometrischen Gruppenfolge; ihre zweidimensionale Darstellung ist kein Nachweis eines fertigungsgerechten dreidimensionalen Wickelkopfs.

### Referenzen

| Eingabe | Ausführung                      | Ergebnis                                        |
| ------- | ------------------------------- | ----------------------------------------------- |
| Q12, p1 | Einschicht, y6 (Folienbeispiel) | q2, 6 Spulen, kw1 = cos15° = 0,9659258          |
| Q12, p1 | Einschicht, automatisch         | y5, gleicher kw1 wie die Referenz               |
| Q36, p2 | Einschicht, automatisch         | y9, 18 Spulen, kw1 = 0,9597951                  |
| Q12, p5 | Zweischicht, automatisch        | y1, 12 Spulen, kw1 = 0,9330127                  |
| Q9, p4  | Zweischicht, automatisch        | y1, 9 Spulen, kw1 = 0,9452136                   |
| Q18, p2 | Einschicht, automatisch         | Im festen Zonenmodell nicht vollständig paarbar |

## Prüfen

```sh
npm test
npm run build
```

Die Tests prüfen bekannte Referenzwerte, die vollständige und eindeutige Seitenbelegung, korrekte Lagen und Vorzeichen, mechanische Spulenweiten, tatsächliche Vektorsummen, 120°-Symmetrie, Kandidatenauswahl und ungültige Eingaben. Die Oberfläche wurde zusätzlich in Chromium mit allen Beispielen, Filter, Nutauswahl, Exporten und einer mobilen Ansicht geprüft.

## Struktur

```text
src/domain/winding.js       Rechenmodell ohne UI-Abhängigkeiten
src/domain/windingLayout.js Kanonische Seriennetze und periodische Zeichengeometrie
src/domain/spectrum.js      Räumliche Fourier-Koeffizienten und Referenzformeln
src/components/Diagrams.jsx SVG-Sterne, Zonenplan und Wickelschema
src/components/SpectrumPanel.jsx Interaktiver Spektrumsplot und Koeffizienten
src/App.jsx                Eingaben, Ergebnisse, Erklärungen und Export
src/styles.css             Responsive Oberfläche
tests/winding.test.js       Numerische Referenzen und Modellinvarianten
tests/winding-layout.test.js Eindeutige Leiterseiten, Seriennetze und Schnittinvarianten
tests/spectrum.test.js      Fourier-Referenzen, Normierung und Phasenursprung
```

Jede Cloud-Aufgabe läuft bereits in einer isolierten Umgebung. Für weitere Arbeit den vorhandenen Checkout verwenden; ein zusätzlicher Git-Worktree ist nicht nötig.
