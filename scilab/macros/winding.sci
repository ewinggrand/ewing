// Wicklungsatelier: reproducible natural 60-degree phase-belt construction.
// Public API: ew_compute_winding(Q, p, layers, span), span=0 means automatic.
// Collections are Scilab lists of structs; warnings are a column string vector.
// Angles in this module are electrical degrees, except the mechanical span y.

function value = ew_mod(value, period)
    value = double(value);
    period = double(period);
    value = modulo(modulo(value, period) + period, period);
endfunction

function ew_require_integer(value, name, minimum, maximum)
    if type(value) <> 1 & type(value) <> 8 then
        error(name + " muss eine reelle ganze Zahl sein.");
    end
    if size(value, "*") <> 1 then
        error(name + " muss ein einzelner Zahlenwert sein.");
    end
    if ~isreal(value) then error(name + " muss reell sein."); end
    if isnan(value) | isinf(value) then error(name + " muss endlich sein."); end
    if value <> floor(value) | value < minimum | value > maximum then
        error(msprintf("%s muss ganzzahlig zwischen %d und %d liegen.", name, minimum, maximum));
    end
endfunction

function value = ew_gcd(a, b)
    while b <> 0
        remainder = modulo(a, b);
        a = b;
        b = remainder;
    end
    value = a;
endfunction

function value = ew_angular_distance(a, b)
    value = abs(ew_mod(a - b + 180, 360) - 180);
endfunction

function [assignments, alphaDeg, offsetDeg] = ew_slot_assignments(Q, p)
    phases = ["A" "C" "B" "A" "C" "B"];
    signs = [1 -1 1 -1 1 -1];
    alphaDeg = 360 * p / Q;
    distinctStep = 360 * ew_gcd(Q, p) / Q;
    offsetDeg = -min(distinctStep / 2, 30);
    assignments = list();
    for n = 1:Q
        angle = ew_mod((n - 1) * alphaDeg, 360);
        belt = modulo(floor((ew_mod(angle - offsetDeg, 360) + 1d-9) / 60), 6) + 1;
        signValue = signs(belt);
        phase = phases(belt);
        prefix = "+";
        if signValue < 0 then prefix = "-"; end
        assignments($ + 1) = struct("slot", n, "angleDeg", angle, ..
            "x", cos(angle * %pi / 180), "y", sin(angle * %pi / 180), ..
            "phase", phase, "sign", signValue, "zone", prefix + phase, "zoneIndex", belt - 1);
    end
endfunction

function phases = ew_phase_results(sides, harmonic)
    if argn(2) < 2 then harmonic = 1; end
    names = ["A" "B" "C"];
    phases = list();
    for phaseIndex = 1:3
        phase = names(phaseIndex);
        x = 0; y = 0; count = 0;
        positiveSlots = []; negativeSlots = [];
        for n = 1:length(sides)
            side = sides(n);
            if side.phase <> phase then continue; end
            angle = side.angleDeg * harmonic * %pi / 180;
            x = x + side.sign * cos(angle);
            y = y + side.sign * sin(angle);
            count = count + 1;
            if side.sign > 0 then
                positiveSlots($ + 1) = side.slot;
            else
                negativeSlots($ + 1) = side.slot;
            end
        end
        magnitude = sqrt(x * x + y * y);
        angleDeg = 0;
        if magnitude >= 1d-9 then angleDeg = ew_mod(atan(y, x) * 180 / %pi, 360); end
        kw = 0;
        if count > 0 then kw = magnitude / count; end
        if abs(x) < 1d-9 then x = 0; end
        if abs(y) < 1d-9 then y = 0; end
        phases($ + 1) = struct("phase", phase, "x", x, "y", y, ..
            "magnitude", magnitude, "angleDeg", angleDeg, "kw", kw, ..
            "sideCount", count, "positiveSlots", positiveSlots, "negativeSlots", negativeSlots);
    end
endfunction

function state = ew_phase_symmetry(phases)
    magnitudes = [phases(1).magnitude phases(2).magnitude phases(3).magnitude];
    average = mean(magnitudes);
    imbalance = 1;
    if average >= 1d-9 then imbalance = max(abs(magnitudes - average)) / average; end
    phaseError = max(ew_angular_distance(phases(2).angleDeg - phases(1).angleDeg, 120), ..
        ew_angular_distance(phases(3).angleDeg - phases(1).angleDeg, 240));
    state = struct("balanced", average > 1d-9 & imbalance < 1d-7 & phaseError < 1d-6, ..
        "imbalance", imbalance, "phaseErrorDeg", phaseError);
endfunction

function coil = ew_coil_record(id, phase, positiveSlot, negativeSlot, span, Q, positiveLayer, negativeLayer)
    direction = -1;
    if ew_mod(negativeSlot - positiveSlot, Q) == span then direction = 1; end
    coil = struct("id", id, "phase", phase, "positiveSlot", positiveSlot, ..
        "negativeSlot", negativeSlot, "span", span, "positiveLayer", positiveLayer, ..
        "negativeLayer", negativeLayer, "direction", direction);
endfunction

// Augmenting paths, not greedy pairing: equal-width full match is required.
function [found, matched, visited] = ew_match_visit(positiveSlot, negativeMask, span, Q, matched, visited)
    found = %f;
    neighbors = [ew_mod(positiveSlot - 1 + span, Q) + 1, ew_mod(positiveSlot - 1 - span, Q) + 1];
    for candidateIndex = 1:2
        negativeSlot = neighbors(candidateIndex);
        if ~negativeMask(negativeSlot) then continue; end
        if visited(negativeSlot) then continue; end
        visited(negativeSlot) = %t;
        if matched(negativeSlot) == 0 then
            matched(negativeSlot) = positiveSlot;
            found = %t;
            return;
        end
        [canMove, matched, visited] = ew_match_visit(matched(negativeSlot), negativeMask, span, Q, matched, visited);
        if canMove then
            matched(negativeSlot) = positiveSlot;
            found = %t;
            return;
        end
    end
endfunction

function [coils, complete] = ew_single_layer_coils(assignments, span)
    Q = length(assignments);
    names = ["A" "B" "C"];
    coils = list();
    complete = %f;
    for phaseIndex = 1:3
        phase = names(phaseIndex);
        positive = []; negative = [];
        for n = 1:Q
            side = assignments(n);
            if side.phase <> phase then continue; end
            if side.sign > 0 then positive($ + 1) = n; else negative($ + 1) = n; end
        end
        if size(positive, "*") == 0 | size(positive, "*") <> size(negative, "*") then return; end
        negativeMask = zeros(1, Q) == 1;
        negativeMask(negative) = %t;
        matched = zeros(1, Q);
        for n = 1:size(positive, "*")
            visited = zeros(1, Q) == 1;
            [found, matched, visited] = ew_match_visit(positive(n), negativeMask, span, Q, matched, visited);
            if ~found then return; end
        end
        // JavaScript reference sorts the matching by positive slot before IDs.
        for n = 1:size(positive, "*")
            negativeSlot = find(matched == positive(n));
            if size(negativeSlot, "*") <> 1 then return; end
            coils($ + 1) = ew_coil_record(phase + string(n), phase, positive(n), negativeSlot(1), span, Q, 1, 1);
        end
    end
    complete = %t;
endfunction

function [coils, sides] = ew_double_layer_coils(assignments, span, alphaDeg)
    Q = length(assignments);
    coils = list();
    unsortedSides = list();
    for n = 1:Q
        side = assignments(n);
        side.layer = 1;
        unsortedSides($ + 1) = side;
    end
    for n = 1:Q
        side = assignments(n);
        secondSlot = ew_mod(side.slot - 1 + span, Q) + 1;
        angle = ew_mod((secondSlot - 1) * alphaDeg, 360);
        prefix = "+";
        if side.sign > 0 then prefix = "-"; end
        second = struct("slot", secondSlot, "layer", 2, "angleDeg", angle, ..
            "phase", side.phase, "sign", -side.sign, "zone", prefix + side.phase, ..
            "x", cos(angle * %pi / 180), "y", sin(angle * %pi / 180));
        unsortedSides($ + 1) = second;
        if side.sign > 0 then
            coil = ew_coil_record(side.phase + string(side.slot), side.phase, side.slot, secondSlot, span, Q, 1, 2);
        else
            coil = ew_coil_record(side.phase + string(side.slot), side.phase, secondSlot, side.slot, span, Q, 2, 1);
        end
        coils($ + 1) = coil;
    end
    sides = list();
    for slot = 1:Q
        for n = 1:length(unsortedSides)
            side = unsortedSides(n);
            if side.slot == slot then sides($ + 1) = side; end
        end
    end
endfunction

function winding = ew_compute_winding(Q, p, layers, span)
    if argn(2) < 3 then layers = 1; end
    if argn(2) < 4 then span = 0; end
    ew_require_integer(Q, "Nutenzahl Q", 6, 120);
    ew_require_integer(p, "Polpaarzahl p", 1, floor(Q / 2));
    ew_require_integer(layers, "Schichtzahl", 1, 2);
    ew_require_integer(span, "Spulenweite y (0 = automatisch)", 0, floor(Q / 2));
    // Explicit Scilab int32/int64 inputs obey the same real-valued formulas.
    Q = double(Q); p = double(p); layers = double(layers); span = double(span);
    [assignments, alphaDeg, offsetDeg] = ew_slot_assignments(Q, p);
    polePitch = Q / (2 * p);
    maxAutoSpan = min(ceil(polePitch), floor(Q / 2));
    if span == 0 then spans = 1:maxAutoSpan; else spans = span; end
    baseSides = list();
    for n = 1:Q
        side = assignments(n);
        side.layer = 1;
        baseSides($ + 1) = side;
    end
    candidates = list();
    selectedIndex = 1;
    validCount = 0;
    bestKw = -1;
    bestSpan = %inf;
    for candidateIndex = 1:size(spans, "*")
        width = spans(candidateIndex);
        if layers == 1 then
            [coils, complete] = ew_single_layer_coils(assignments, width);
            sides = baseSides;
        else
            [coils, sides] = ew_double_layer_coils(assignments, width, alphaDeg);
            complete = %t;
        end
        phases = ew_phase_results(sides);
        state = ew_phase_symmetry(phases);
        kw = (phases(1).kw + phases(2).kw + phases(3).kw) / 3;
        valid = complete & length(coils) > 0 & state.balanced;
        candidate = struct("span", width, "coils", coils, "slotLayers", sides, ..
            "phases", phases, "balanced", state.balanced, "imbalance", state.imbalance, ..
            "phaseErrorDeg", state.phaseErrorDeg, "kw", kw, "complete", complete, "valid", valid);
        candidates($ + 1) = candidate;
        if valid then
            validCount = validCount + 1;
            if kw > bestKw + 1d-9 | (abs(kw - bestKw) <= 1d-9 & width < bestSpan) then
                bestKw = kw;
                bestSpan = width;
                selectedIndex = candidateIndex;
            end
        end
    end
    selected = candidates(selectedIndex);
    warnings = emptystr(0, 1);
    if ~selected.valid then
        if layers == 1 & modulo(Q, 2) <> 0 then
            warnings($ + 1, 1) = "Eine Einschichtwicklung benoetigt eine gerade Nutenzahl: Jede Spule belegt zwei verschiedene Nuten.";
        end
        if ~selected.balanced then
            warnings($ + 1, 1) = "Die feste 60-Grad-Zonung ergibt keine symmetrischen, von null verschiedenen Strangspannungen mit 120 Grad Versatz.";
        end
        if layers == 1 & ~selected.complete then
            if span == 0 then
                warnings($ + 1, 1) = msprintf("Innerhalb der geprueften Weiten 1 bis %d lassen sich diese Seiten nicht vollstaendig zu gleichweiten Spulen paaren.", maxAutoSpan);
            else
                warnings($ + 1, 1) = msprintf("Bei Spulenweite %d lassen sich diese Seiten nicht vollstaendig zu Spulen paaren.", span);
            end
        end
        warnings($ + 1, 1) = "In diesem festen Zonenmodell kein gueltiges Wickelschema. Andere Zonungen oder Wicklungstopologien sind damit nicht ausgeschlossen.";
    end
    harmonics = list();
    for order = [1 3 5 7 11 13]
        values = ew_phase_results(selected.slotLayers, order);
        factor = (values(1).kw + values(2).kw + values(3).kw) / 3;
        harmonics($ + 1) = struct("order", order, "factor", factor);
    end
    selectedCoils = list();
    if selected.valid then selectedCoils = selected.coils; end
    selection = "Manuell vorgegebene Spulenweite; vollstaendige Paarung und Strangsymmetrie werden geprueft.";
    scope = msprintf("Gleichweite Spulen mit y = %d; feste Zonung, drei Straenge.", span);
    if span == 0 then
        selection = "Symmetrische realisierbare Kandidaten: hoechster Grundwellen-Wicklungsfaktor, bei Gleichstand kuerzeste Spulenweite.";
        scope = msprintf("Gleichweite Spulen mit y = 1 bis %d (aufgerundete Polteilung); feste Zonung, drei Straenge.", maxAutoSpan);
    end
    note = "Die zweite Lage wird um y Nuten versetzt und mit umgekehrtem Vorzeichen gebildet. Der Strangstern summiert beide Lagen.";
    if layers == 1 then
        note = "Bei fester Einschicht-Zonung bleibt der Strangstern fuer vollstaendige Paarungen gleich. Die Automatik verkuerzt unter gueltigen Paarungen die Weite.";
    end
    method = struct("name", "Natuerliche 60-Grad-Zonung", ..
        "description", "Nutenspannungsstern -> feste Zonen -> vorzeichenrichtige Summe der tatsaechlichen Spulenseiten -> vollstaendige Spulenpaarung.", ..
        "selection", selection, "candidateScope", scope, "note", note, ..
        "limitation", "Optimierung innerhalb dieses Modells; Kupferbedarf, Wickelkopfkreuzungen, Oberwellen, Verluste und Fertigbarkeit werden nicht gemeinsam optimiert.");
    metrics = struct("kw", selected.kw, "imbalance", selected.imbalance, ..
        "phaseErrorDeg", selected.phaseErrorDeg, "coilCount", length(selectedCoils), ..
        "candidateCount", length(candidates), "validCandidateCount", validCount);
    winding = struct("slots", Q, "polePairs", p, "layers", layers, "q", Q / (6 * p), ..
        "alphaDeg", alphaDeg, "polePitch", polePitch, "coilSpan", selected.span, ..
        "requestedCoilSpan", span, "zoneOffsetDeg", offsetDeg, "slotAssignments", assignments, ..
        "slotLayers", selected.slotLayers, "coils", selectedCoils, "phases", selected.phases, ..
        "harmonics", harmonics, "balanced", selected.balanced, "valid", selected.valid, ..
        "warnings", warnings, "metrics", metrics, "method", method);
endfunction
