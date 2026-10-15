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
4. In **Wickelschema** zwischen einzelnen Spulen und additiver Serienverschaltung mit U1/U2, V1/V2 und W1/W2 wechseln. Jede Klemme gehört zu einem Ende des jeweiligen Strangs; Stern-/Dreieckbrücken sind nicht enthalten.
5. **Berechnungsweg** erklärt Formeln, Vorzeichen, Bewertungsmaßstab und Grenzen. **Exportieren** bietet Nutbelegung und Spulen als CSV, sichtbare Diagramme als SVG und die vollständige Berechnung als JSON.

Die blauen Rechtecke stellen **Zähne** dar. Alle aktiven Spulenseiten liegen in den **weißen Nuten zwischen den Zähnen**. Große Wickelschemata können innerhalb ihrer Karte horizontal gescrollt werden. Die SVGs bleiben unabhängig von der Bildschirmauflösung skalierbar.

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

Das ist **kein allgemeines elektromagnetisches Optimum**. Andere Zonungen, gemischte Weiten, Parallelzweige, Nutgeometrie, Drahtquerschnitt, thermische Grenzen, Wickelkopfkreuzungen und eine gemeinsame Bewertung von Oberwellen oder Verlusten werden nicht optimiert. Eine im Modell ungültige Kombination ist nicht generell physikalisch ausgeschlossen. Die Serienverbindungen folgen der deterministischen Spulenliste und werden nicht geometrisch optimiert.

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
src/components/Diagrams.jsx SVG-Sterne, Zonenplan und Wickelschema
src/App.jsx                Eingaben, Ergebnisse, Erklärungen und Export
src/styles.css             Responsive Oberfläche
tests/winding.test.js       Numerische Referenzen und Modellinvarianten
```

Jede Cloud-Aufgabe läuft bereits in einer isolierten Umgebung. Für weitere Arbeit den vorhandenen Checkout verwenden; ein zusätzlicher Git-Worktree ist nicht nötig.
