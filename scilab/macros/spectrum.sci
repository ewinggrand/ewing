// Mechanical spatial Fourier coefficients of actual signed slot sides.
// C_k = D_k/(2*i*k), D_k = sum s exp(-i*k*phi), W_k=C_k/pi.
// This file requires winding.sci (input validation and nonnegative modulo).

function value = ew_spectrum_small(value)
    if abs(value) < 1d-11 then value = 0; end
endfunction

function coefficient = ew_spectrum_coefficient(order, rawReal, rawImag, referenceRad, kw, fundamentalOrder, fundamentalAmplitude)
    angle = order * referenceRad;
    realPart = ew_spectrum_small(rawReal * cos(angle) + rawImag * sin(angle));
    imagPart = ew_spectrum_small(rawImag * cos(angle) - rawReal * sin(angle));
    amplitude = ew_spectrum_small(sqrt(rawReal * rawReal + rawImag * rawImag));
    phaseDeg = 0; rawPhaseDeg = 0;
    if amplitude <> 0 then
        phaseDeg = atan(imagPart, realPart) * 180 / %pi;
        rawPhaseDeg = atan(rawImag, rawReal) * 180 / %pi;
    end
    if ~isempty(kw) then kw = ew_spectrum_small(kw); end
    isFundamental = %f;
    if ~isempty(fundamentalOrder) then isFundamental = order == fundamentalOrder; end
    relative = []; signedRelative = [];
    if fundamentalAmplitude > 1d-11 then
        relative = amplitude / fundamentalAmplitude;
        signedRelative = realPart / fundamentalAmplitude;
    end
    coefficient = struct("order", order, "real", realPart, "imag", imagPart, ..
        "amplitude", amplitude, "phaseDeg", phaseDeg, "rawReal", ew_spectrum_small(rawReal), ..
        "rawImag", ew_spectrum_small(rawImag), "rawPhaseDeg", rawPhaseDeg, "kw", kw, ..
        "isFundamental", isFundamental, "relativeToFundamental", relative, ..
        "signedRelativeToFundamental", signedRelative);
endfunction

function [rawReal, rawImag, kw] = ew_spectrum_raw(sides, Q, order, scale)
    dReal = 0; dImag = 0;
    for n = 1:length(sides)
        side = sides(n);
        angle = 2 * %pi * (side.slot - 1) * order / Q;
        dReal = dReal + side.sign * cos(angle);
        dImag = dImag - side.sign * sin(angle);
    end
    rawReal = dImag / (2 * order * scale);
    rawImag = -dReal / (2 * order * scale);
    kw = sqrt(dReal * dReal + dImag * dImag) / length(sides);
endfunction

function spectrum = ew_compute_spectrum(winding, maxOrder, phase, normalization)
    if argn(2) < 2 then maxOrder = 20; end
    if argn(2) < 3 then phase = "A"; end
    if argn(2) < 4 then normalization = "phase-sum"; end
    ew_require_integer(maxOrder, "Hoechste Raumordnungszahl K", 1, 120);
    maxOrder = double(maxOrder);
    if type(phase) <> 10 then error("Der Strang muss A, B oder C sein."); end
    if size(phase, "*") <> 1 then error("Einen einzelnen Strang A, B oder C waehlen."); end
    if ~or(phase == ["A" "B" "C"]) then error("Der Strang muss A, B oder C sein."); end
    if type(normalization) <> 10 then error("Normierung: phase-sum oder per-coil waehlen."); end
    if size(normalization, "*") <> 1 then error("Eine einzelne Normierung waehlen."); end
    if ~or(normalization == ["phase-sum" "per-coil"]) then error("Normierung: phase-sum oder per-coil waehlen."); end
    p = winding.polePairs;
    normalizationText = "Strangsumme: C_k = D_k/(2 i k); alle tatsaechlichen Spulenseiten werden addiert.";
    if normalization == "per-coil" then normalizationText = "Pro Spule: C_k = D_k/(2 i k Nc); Nc ist die Spulenzahl des Strangs."; end
    spectrum = struct("valid", %f, "phase", phase, "polePairs", p, "maxOrder", maxOrder, ..
        "fundamentalOrder", p, "coilCountPhase", 0, "normalization", normalization, ..
        "normalizationText", normalizationText, "mechanicalReferenceRad", [], ..
        "mechanicalReferenceDeg", [], "coefficients", list(), "fundamental", [], ..
        "convention", "D_k=sum s exp(-i k phi); phi=2*pi*(Nut-1)/Q. Alle Ordnungen erhalten einen gemeinsamen Phasenursprung phi0=arg(C_p)/p.", ..
        "warnings", emptystr(0, 1));
    if ~winding.valid then
        spectrum.warnings = "Ohne gueltiges Wickelschema wird kein Spektrum berechnet.";
        return;
    end
    sides = list(); positiveCount = 0; negativeCount = 0;
    for n = 1:length(winding.slotLayers)
        side = winding.slotLayers(n);
        if side.phase <> phase then continue; end
        sides($ + 1) = side;
        if side.sign == 1 then positiveCount = positiveCount + 1; end
        if side.sign == -1 then negativeCount = negativeCount + 1; end
        if side.slot < 1 | side.slot > winding.slots | floor(side.slot) <> side.slot | ~or(side.sign == [-1 1]) then
            spectrum.warnings = "Die tatsaechlichen vorzeichenbehafteten Spulenseiten sind ungueltig.";
            return;
        end
    end
    if positiveCount == 0 | positiveCount <> negativeCount then
        spectrum.warnings = "Der Strang besitzt keine vollstaendigen, vorzeichenrichtig zugeordneten Spulenseiten.";
        return;
    end
    spectrum.coilCountPhase = positiveCount;
    scale = 1;
    if normalization == "per-coil" then scale = positiveCount; end
    [rawReal, rawImag, kw] = ew_spectrum_raw(sides, winding.slots, p, scale);
    fundamentalAmplitude = sqrt(rawReal * rawReal + rawImag * rawImag);
    if fundamentalAmplitude < 1d-11 then
        spectrum.warnings = "Die Grundwelle dieses Strangs ist null; ihr Phasenursprung ist nicht definiert.";
        return;
    end
    referenceRad = atan(rawImag, rawReal) / p;
    coefficients = list();
    for order = 1:maxOrder
        [r, im, factor] = ew_spectrum_raw(sides, winding.slots, order, scale);
        coefficients($ + 1) = ew_spectrum_coefficient(order, r, im, referenceRad, factor, p, fundamentalAmplitude);
    end
    spectrum.valid = %t;
    spectrum.mechanicalReferenceRad = referenceRad;
    spectrum.mechanicalReferenceDeg = referenceRad * 180 / %pi;
    spectrum.coefficients = coefficients;
    spectrum.fundamental = ew_spectrum_coefficient(p, rawReal, rawImag, referenceRad, kw, p, fundamentalAmplitude);
endfunction

function value = ew_reference_value(id, k)
    select id
    case "full-pitch" then
        value = sin(k * %pi / 2) / k;
    case "short-pitch" then
        value = sin(k * %pi / 3) / k;
    case "chorded-group" then
        value = (2 * cos(k * %pi / 2) * sin(2 * %pi * k / 9) - sin(k * %pi / 6)) / k;
    case "q9-group" then
        value = sin(k * %pi / 9) * (-1 + 2 * cos(2 * %pi * k / 9)) / k;
    else
        error("Die analytische Spektrumsreferenz ist unbekannt.");
    end
endfunction

function references = ew_spectrum_references()
    references = list();
    references($ + 1) = struct("id", "full-pitch", "title", "Vollgeteilte Einzelspule", ..
        "formula", "xi_k = sin(k*pi/2)/k", "fundamentalOrder", [], "referenceOrder", 1, "coilCountPhase", 1, ..
        "description", "180 Grad Weite im Formelwinkel; gerade Ordnungen verschwinden. Eine Maschinenpolpaarzahl ist nicht vorgegeben.", "referenceNote", "");
    references($ + 1) = struct("id", "short-pitch", "title", "3/2-Wicklung", ..
        "formula", "xi_k = sin(k*pi/3)/k", "fundamentalOrder", [], "referenceOrder", 1, "coilCountPhase", [], ..
        "description", "120 Grad Spulenweite. 3/2 ist der Name und kein zusaetzlicher Amplitudenfaktor.", "referenceNote", "");
    references($ + 1) = struct("id", "chorded-group", "title", "Gesehnte Spulengruppe", ..
        "formula", "xi_k = (2*cos(k*pi/2)*sin(2*pi*k/9)-sin(k*pi/6))/k", ..
        "fundamentalOrder", [], "referenceOrder", 1, "coilCountPhase", 3, ..
        "description", "Ueberlagerung der angegebenen Gruppenbeitraege mit ihren Fourier-Vorzeichen.", ..
        "referenceNote", "Der Folienplot besitzt gegenueber dieser Formel eine gemeinsame Umkehr der Strangpolung. Keine Einzelvorzeichen werden angepasst.");
    references($ + 1) = struct("id", "q9-group", "title", "9-Nuten-Spulengruppe", ..
        "formula", "xi_k = sin(k*pi/9)*(-1+2*cos(2*pi*k/9))/k", ..
        "fundamentalOrder", 4, "referenceOrder", 4, "coilCountPhase", 3, ..
        "description", "Gruppenabstand 2*pi/9, Nutzgrundwelle mechanisch k=4.", ..
        "referenceNote", "Die unklare Bildlesart pi/9 wird als Nutabstand 2*pi/9 interpretiert. Bei k=2 bis 5 sind Formelwerte negativ, waehrend Folienbalken positive Betraege zeigen. Keine Einzelkorrektur.");
endfunction

function spectrum = ew_reference_spectrum(id, maxOrder)
    if argn(2) < 2 then maxOrder = 20; end
    ew_require_integer(maxOrder, "Hoechste Raumordnungszahl K", 1, 120);
    maxOrder = double(maxOrder);
    if type(id) <> 10 then error("Eine einzelne Spektrumsreferenz waehlen."); end
    if size(id, "*") <> 1 then error("Eine einzelne Spektrumsreferenz waehlen."); end
    references = ew_spectrum_references();
    found = %f;
    for n = 1:length(references)
        reference = references(n);
        if reference.id == id then found = %t; break; end
    end
    if ~found then error("Die analytische Spektrumsreferenz ist unbekannt."); end
    fundamentalAmplitude = 0;
    if ~isempty(reference.fundamentalOrder) then fundamentalAmplitude = abs(ew_reference_value(id, reference.fundamentalOrder)); end
    coefficients = list();
    for order = 1:maxOrder
        coefficients($ + 1) = ew_spectrum_coefficient(order, ew_reference_value(id, order), 0, 0, [], reference.fundamentalOrder, fundamentalAmplitude);
    end
    fundamental = [];
    if ~isempty(reference.fundamentalOrder) then
        fundamental = ew_spectrum_coefficient(reference.fundamentalOrder, ew_reference_value(id, reference.fundamentalOrder), 0, 0, [], reference.fundamentalOrder, fundamentalAmplitude);
    end
    warnings = emptystr(0, 1);
    if reference.referenceNote <> "" then warnings = reference.referenceNote; end
    spectrum = reference;
    spectrum.valid = %t;
    spectrum.phase = "A";
    spectrum.polePairs = reference.fundamentalOrder;
    spectrum.maxOrder = maxOrder;
    spectrum.normalization = "formula";
    spectrum.normalizationText = "Unveraenderte Amplituden der angegebenen Formel; keine automatische Normierung.";
    spectrum.mechanicalReferenceRad = 0;
    spectrum.mechanicalReferenceDeg = 0;
    spectrum.coefficients = coefficients;
    spectrum.fundamental = fundamental;
    spectrum.referenceCoefficient = ew_spectrum_coefficient(reference.referenceOrder, ew_reference_value(id, reference.referenceOrder), 0, 0, [], reference.fundamentalOrder, fundamentalAmplitude);
    spectrum.convention = "Reelle, vorzeichenbehaftete Koeffizienten der angegebenen Formel ohne nachtraegliche Grundwellenrotation.";
    spectrum.warnings = warnings;
endfunction
