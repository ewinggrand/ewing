// Linear stator air-gap model. All phases retain ONE mechanical coordinate.
// Unit-turn winding functions have the actual signed slot-side jumps and zero
// circumference mean. The primary L matrix is their exact piecewise Gram
// integral; a separate shared-coordinate Fourier sum demonstrates convergence.

function value = ew_i_mod(value, period)
    value = modulo(modulo(value, period) + period, period);
endfunction

function parts = ew_i_complex(value)
    re = real(value); im = imag(value); magnitude = abs(value);
    if abs(re) < 1d-12 then re = 0; end
    if abs(im) < 1d-12 then im = 0; end
    if magnitude < 1d-12 then magnitude = 0; end
    parts = struct("real", re, "imag", im, "magnitude", magnitude);
endfunction

function index = ew_i_phase_index(phase)
    index = find(["A"; "B"; "C"] == phase);
    if size(index, "*") <> 1 then error("Unbekannter Strang: " + string(phase)); end
endfunction

function ew_i_require(value, name, lower, upper, integer, lowerInclusive)
    if size(value, "*") <> 1 then error(name + ": Ein skalarer Wert ist erforderlich."); end
    if ~isreal(value) | isnan(value) | isinf(value) then
        error(name + ": Ein endlicher reeller Wert ist erforderlich.");
    end
    if lowerInclusive then outside = value < lower; else outside = value <= lower; end
    if outside | value > upper | (integer & value <> floor(value)) then
        error(msprintf("%s: Wert außerhalb des zulässigen Bereichs (%g bis %g).", name, lower, upper));
    end
endfunction

function parameters = ew_inductance_parameters(winding, options)
    if argn(2) < 2 then options = struct(); end
    parameters = struct("radiusM", 0.05, "lengthM", 0.1, "gapM", 0.001, ..
        "turnsPerCoil", 10, "currents", [1; 0; 0], "maxOrder", 120, ..
        "selectedOrder", 1, "sampleCount", 361);
    if isfield(winding, "polePairs") then parameters.selectedOrder = winding.polePairs; end
    names = ["radiusM"; "lengthM"; "gapM"; "turnsPerCoil"; "currents"; ..
        "maxOrder"; "selectedOrder"; "sampleCount"];
    for index = 1:size(names, "*")
        name = names(index);
        if isfield(options, name) then parameters(name) = options(name); end
    end
    ew_i_require(parameters.radiusM, "Luftspaltradius r / m", 0, 100, %f, %f);
    ew_i_require(parameters.lengthM, "Aktive Eisenlänge / m", 0, 100, %f, %f);
    ew_i_require(parameters.gapM, "Wirksamer Luftspalt / m", 0, 1, %f, %f);
    ew_i_require(parameters.turnsPerCoil, "Windungen je Spule", 0, 1d6, %t, %f);
    if size(parameters.currents, "*") <> 3 then error("Drei Strangströme [iA; iB; iC] sind erforderlich."); end
    parameters.currents = matrix(parameters.currents, 3, 1);
    for index = 1:3
        ew_i_require(parameters.currents(index), "Strangstrom / A", -1d6, 1d6, %f, %t);
    end
    ew_i_require(parameters.maxOrder, "Höchste Raumordnung K", 1, 2000, %t, %t);
    ew_i_require(parameters.selectedOrder, "Ausgewählte Raumordnung k", 1, 2000, %t, %t);
    ew_i_require(parameters.sampleCount, "Kurvenstützpunkte", 16, 1441, %t, %t);
    parameters.polePitchM = %nan;
    if isfield(winding, "polePairs") then
        if winding.polePairs > 0 then parameters.polePitchM = %pi * parameters.radiusM / winding.polePairs; end
    end
endfunction

function message = ew_i_winding_error(winding)
    message = "";
    if ~isfield(winding, "valid") then message = "Eine gültige vollständige Wicklung ist erforderlich."; return; end
    if ~winding.valid then message = "Ohne gültige vollständige Wicklung werden keine Induktivitäten berechnet."; return; end
    if ~isfield(winding, "coils") | ~isfield(winding, "slotLayers") then
        message = "Tatsächliche Spulen und Nutlagen fehlen."; return;
    end
    if length(winding.coils) == 0 then message = "Es sind keine Spulen vorhanden."; return; end
    Q = winding.slots;
    occupied = zeros(Q, 2); signs = zeros(Q, 2); used = zeros(Q, 2);
    for index = 1:length(winding.slotLayers)
        side = winding.slotLayers(index);
        if side.slot < 1 | side.slot > Q | side.slot <> floor(side.slot) | ..
            side.layer < 1 | side.layer > 2 | side.layer <> floor(side.layer) | ..
            ~or(side.sign == [-1, 1]) then
            message = "Ungültige tatsächliche Spulenseite."; return;
        end
        phase = ew_i_phase_index(side.phase);
        if occupied(side.slot, side.layer) <> 0 then message = "Eine Nutlage wurde mehrfach belegt."; return; end
        occupied(side.slot, side.layer) = phase; signs(side.slot, side.layer) = side.sign;
    end
    phases = zeros(3, 1); ids = emptystr(0, 1);
    for index = 1:length(winding.coils)
        coil = winding.coils(index); phase = ew_i_phase_index(coil.phase);
        if or(ids == coil.id) then message = "Mehrfach verwendete Spulenkennung."; return; end
        ids($ + 1) = coil.id;
        if coil.span < 1 | coil.span >= Q | coil.span <> floor(coil.span) | ~or(coil.direction == [-1, 1]) then
            message = "Ungültige Spulenweite oder Orientierung."; return;
        end
        if ew_i_mod(coil.positiveSlot - 1 + coil.direction * coil.span, Q) + 1 <> coil.negativeSlot then
            message = "Spulenweite und Nutpaar stimmen nicht überein."; return;
        end
        ss = [coil.positiveSlot, coil.negativeSlot]; ll = [coil.positiveLayer, coil.negativeLayer];
        for endIndex = 1:2
            slot = ss(endIndex); layer = ll(endIndex); expectedSign = 3 - 2 * endIndex;
            if slot < 1 | slot > Q | layer < 1 | layer > 2 then message = "Ungültiges Spulenende."; return; end
            if occupied(slot, layer) <> phase | signs(slot, layer) <> expectedSign | used(slot, layer) <> 0 then
                message = "Spulen und vorzeichenbehaftete Nutlagen stimmen nicht überein."; return;
            end
            used(slot, layer) = 1;
        end
        phases(phase) = phases(phase) + 1;
    end
    if sum(used) <> length(winding.slotLayers) | or(phases == 0) then
        message = "Die Spulen müssen alle vorhandenen Seiten aller drei Stränge eindeutig verwenden.";
    end
endfunction

function coefficient = ew_i_raw_coefficient(winding, order)
    coefficient = zeros(3, 1) + %i * zeros(3, 1);
    for index = 1:length(winding.slotLayers)
        side = winding.slotLayers(index); phase = ew_i_phase_index(side.phase);
        angle = 2 * %pi * order * (side.slot - 1) / winding.slots;
        coefficient(phase) = coefficient(phase) + side.sign * exp(-%i * angle) / (2 * %i * order);
    end
endfunction

function axis = ew_i_axis(coefficient, polePairs)
    axis = %nan;
    if abs(coefficient) >= 1d-11 then
        axis = ew_i_mod(-atan(imag(coefficient), real(coefficient)) / polePairs, 2 * %pi / polePairs);
    end
endfunction

function coefficient = ew_i_coil_coefficient(coil, order)
    coefficient = sin(order * coil.signedSpanRad / 2) / order * exp(-%i * order * coil.centerRad);
endfunction

function factors = ew_i_factors(coils, order, referenceAxis)
    count = length(coils); reference = referenceAxis;
    if isnan(reference) then reference = 0; end
    distribution = 0; raw = 0; common = %t;
    for index = 1:count
        coil = coils(index);
        distribution = distribution + coil.direction * exp(-%i * order * (coil.centerRad - reference));
        raw = raw + ew_i_coil_coefficient(coil, order);
        if abs(coil.betaRad - coils(1).betaRad) > 1d-11 then common = %f; end
    end
    pitch = %nan;
    if common then pitch = sin(order * coils(1).betaRad / 2); end
    if abs(pitch) < 1d-12 then pitch = 0; end
    factors = struct("order", order, "pitchFactor", pitch, ..
        "distributionFactor", ew_i_complex(distribution / count), ..
        "rawCoefficient", ew_i_complex(raw), "windingFactor", order * abs(raw) / count, ..
        "referenceAxisRad", referenceAxis);
endfunction

function groups = ew_i_groups(geometry, phaseAxes, selectedOrder, polePairs)
    // Consecutive physical centers form a group. Join fragments at the 0/2pi
    // display seam: a drawing cut must not alter the physical group factor.
    phases = ["A"; "B"; "C"]; count = length(geometry); centers = zeros(count, 1);
    for index = 1:count, centers(index) = geometry(index).centerRad; end
    [sorted, order] = gsort(centers, "g", "i");
    definitions = list(); lastPhase = "";
    for index = 1:count
        coil = geometry(order(index));
        if coil.phase <> lastPhase then
            definitions($ + 1) = struct("phase", coil.phase, "indices", order(index));
        else
            group = definitions($); group.indices($ + 1) = order(index); definitions($) = group;
        end
        lastPhase = coil.phase;
    end
    if length(definitions) > 1 then
        first = definitions(1); last = definitions($);
        if first.phase == last.phase then
            first.indices = [matrix(last.indices, 1, -1), matrix(first.indices, 1, -1)];
            definitions(1) = first; definitions($) = null();
        end
    end
    groups = list(); phaseCounts = zeros(3, 1);
    for index = 1:count
        phase = ew_i_phase_index(geometry(index).phase); phaseCounts(phase) = phaseCounts(phase) + 1;
    end
    for index = 1:length(definitions)
        definition = definitions(index); members = list(); ids = emptystr(0, 1);
        for memberIndex = matrix(definition.indices, 1, -1)
            members($ + 1) = geometry(memberIndex); ids($ + 1) = geometry(memberIndex).id;
        end
        phase = ew_i_phase_index(definition.phase);
        factor = ew_i_factors(members, polePairs, 0); raw = factor.rawCoefficient.real + %i * factor.rawCoefficient.imag;
        axis = ew_i_axis(raw, polePairs); axisForSum = axis; phaseAxis = phaseAxes(phase);
        if isnan(axisForSum) then axisForSum = 0; end
        if isnan(phaseAxis) then phaseAxis = 0; end
        selected = ew_i_factors(members, selectedOrder, axis);
        fundamental = ew_i_factors(members, polePairs, axis);
        weight = length(members) / phaseCounts(phase);
        factor = selected.distributionFactor;
        selected.weight = weight;
        selected.phaseContribution = ew_i_complex(weight * (factor.real + %i * factor.imag) * exp(-%i * selectedOrder * (axisForSum - phaseAxis)));
        factor = fundamental.distributionFactor;
        fundamental.weight = weight;
        fundamental.phaseContribution = ew_i_complex(weight * (factor.real + %i * factor.imag) * exp(-%i * polePairs * (axisForSum - phaseAxis)));
        groups($ + 1) = struct("id", "group-" + string(index), "phase", definition.phase, ..
            "coilIds", ids, "coilCount", length(members), "axisRad", axis, ..
            "axisDeg", axis * 180 / %pi, "selected", selected, "fundamental", fundamental);
    end
endfunction

function data = ew_compute_inductance(winding, options)
    if argn(2) < 2 then options = struct(); end
    parameters = ew_inductance_parameters(winding, options);
    phaseNames = ["A"; "B"; "C"]; mu0 = 4 * %pi * 1d-7;
    data = struct(); data.valid = %f;
    data.slots = winding.slots; data.polePairs = winding.polePairs; data.layers = winding.layers;
    data.parameters = parameters; data.phaseOrder = phaseNames;
    data.matrixH = []; data.harmonicMatrixH = []; data.fundamentalMatrixH = [];
    data.fluxLinkagesWbTurns = []; data.energyJ = %nan;
    data.phases = list(); data.coils = list(); data.groups = list(); data.segments = list();
    data.samples = list(); data.harmonics = list(); data.relativeTruncationError = %nan;
    data.warnings = emptystr(0, 1);
    message = ew_i_winding_error(winding);
    if message <> "" then data.warnings = message; return; end
    Q = winding.slots; p = winding.polePairs; K = parameters.maxOrder;
    turns = parameters.turnsPerCoil; currents = parameters.currents;
    geometric = mu0 * parameters.radiusM * parameters.lengthM / parameters.gapM;
    prefactor = 4 * geometric * turns^2 / %pi;
    if parameters.gapM / parameters.radiusM > 0.05 then
        data.warnings($ + 1) = "Der Luftspalt ist gegenüber dem Radius groß; die dünne Luftspaltnäherung wird ungenauer.";
    end
    fundamentalCoefficients = ew_i_raw_coefficient(winding, p);
    phaseAxes = zeros(3, 1);
    for phase = 1:3, phaseAxes(phase) = ew_i_axis(fundamentalCoefficients(phase), p); end
    geometry = list(); phaseGeometry = list(list(), list(), list());
    for index = 1:length(winding.coils)
        coil = winding.coils(index); phase = ew_i_phase_index(coil.phase);
        coil.positiveAngleRad = 2 * %pi * (coil.positiveSlot - 1) / Q;
        coil.negativeAngleRad = 2 * %pi * (coil.negativeSlot - 1) / Q;
        coil.betaRad = 2 * %pi * coil.span / Q; coil.signedSpanRad = coil.direction * coil.betaRad;
        coil.betaElectricalRad = p * coil.betaRad;
        coil.betaDeg = coil.betaRad * 180 / %pi; coil.betaElectricalDeg = p * coil.betaDeg;
        coil.centerRad = ew_i_mod(coil.positiveAngleRad + coil.signedSpanRad / 2, 2 * %pi);
        coil.centerDeg = coil.centerRad * 180 / %pi;
        geometry($ + 1) = coil; members = phaseGeometry(phase); members($ + 1) = coil; phaseGeometry(phase) = members;
    end
    for phase = 1:3
        members = phaseGeometry(phase);
        data.phases($ + 1) = struct("phase", phaseNames(phase), "coilCount", length(members), ..
            "turnsSeries", turns * length(members), "axisRad", phaseAxes(phase), ..
            "axisDeg", phaseAxes(phase) * 180 / %pi, ..
            "selected", ew_i_factors(members, parameters.selectedOrder, phaseAxes(phase)), ..
            "fundamental", ew_i_factors(members, p, phaseAxes(phase)));
    end
    data.groups = ew_i_groups(geometry, phaseAxes, parameters.selectedOrder, p);
    for index = 1:length(geometry)
        coil = geometry(index); phase = ew_i_phase_index(coil.phase);
        coil.axisRad = ew_i_axis(ew_i_coil_coefficient(coil, p), p); coil.axisDeg = coil.axisRad * 180 / %pi;
        coil.phaseAxisRad = phaseAxes(phase); coil.phaseAxisDeg = coil.phaseAxisRad * 180 / %pi;
        coil.relativeElectricalRad = ew_i_mod(p * (coil.axisRad - coil.phaseAxisRad) + %pi, 2 * %pi) - %pi;
        coil.relativeElectricalDeg = coil.relativeElectricalRad * 180 / %pi;
        coil.relativeMechanicalRad = coil.relativeElectricalRad / p;
        coil.relativeMechanicalDeg = coil.relativeElectricalDeg / p;
        coil.groupId = "";
        for groupIndex = 1:length(data.groups)
            group = data.groups(groupIndex);
            if or(group.coilIds == coil.id) then coil.groupId = group.id; break; end
        end
        coil.selected = ew_i_factors(list(coil), parameters.selectedOrder, phaseAxes(phase));
        coil.fundamental = ew_i_factors(list(coil), p, phaseAxes(phase));
        data.coils($ + 1) = coil;
    end
    if or(isnan(phaseAxes)) then data.warnings($ + 1) = "Eine verschwindende Grundwelle besitzt keine definierte Strangmittelachse."; end
    // Equal angular slot intervals make the exact Gram integral particularly
    // transparent. The DC subtraction enforces zero net radial air-gap flux.
    jumps = zeros(Q, 3);
    for index = 1:length(winding.slotLayers)
        side = winding.slotLayers(index); phase = ew_i_phase_index(side.phase);
        jumps(side.slot, phase) = jumps(side.slot, phase) + side.sign;
    end
    unitWinding = cumsum(jumps, 1); unitWinding = unitWinding - ones(Q, 1) * mean(unitWinding, 1);
    turnFunction = turns * unitWinding; width = 2 * %pi / Q;
    theta = turnFunction * currents; b = mu0 * theta / parameters.gapM;
    for index = 1:Q
        data.segments($ + 1) = struct("startRad", (index - 1) * width, "endRad", index * width, ..
            "widthRad", width, "winding", unitWinding(index, :)', "turnFunction", turnFunction(index, :)', ..
            "thetaAmpereTurns", theta(index), "bTesla", b(index));
    end
    data.matrixH = geometric * width * (turnFunction' * turnFunction);
    data.harmonicMatrixH = zeros(3, 3);
    coefficientMatrix = zeros(3, K) + %i * zeros(3, K);
    for order = 1:K
        coefficients = ew_i_raw_coefficient(winding, order); coefficientMatrix(:, order) = coefficients;
        contribution = prefactor * real(coefficients * coefficients');
        data.harmonicMatrixH = data.harmonicMatrixH + contribution;
        coefficientParts = struct("A", ew_i_complex(coefficients(1)), "B", ew_i_complex(coefficients(2)), "C", ew_i_complex(coefficients(3)));
        data.harmonics($ + 1) = struct("order", order, "coefficients", coefficientParts, ..
            "contributionMatrixH", contribution, "isFundamental", order == p);
    end
    data.fundamentalMatrixH = prefactor * real(fundamentalCoefficients * fundamentalCoefficients');
    data.fluxLinkagesWbTurns = data.matrixH * currents;
    data.energyJ = real(currents' * data.fluxLinkagesWbTurns) / 2;
    denominator = norm(data.matrixH, "fro");
    data.relativeTruncationError = 0;
    if denominator > 0 then data.relativeTruncationError = norm(data.matrixH - data.harmonicMatrixH, "fro") / denominator; end
    sampleAngles = linspace(0, 2 * %pi, parameters.sampleCount);
    harmonicTheta = zeros(1, parameters.sampleCount);
    for order = 1:K
        scalarCoefficient = currents' * coefficientMatrix(:, order);
        harmonicTheta = harmonicTheta + 2 * turns / %pi * real(scalarCoefficient * exp(%i * order * sampleAngles));
    end
    for index = 1:parameters.sampleCount
        angle = sampleAngles(index); position = angle / width;
        after = ew_i_mod(floor(position + 1d-10), Q) + 1;
        exactTheta = theta(after);
        if abs(position - round(position)) < 1d-9 then
            before = ew_i_mod(round(position) - 1, Q) + 1;
            exactTheta = (theta(after) + theta(before)) / 2;
        end
        data.samples($ + 1) = struct("angleRad", angle, "angleDeg", angle * 180 / %pi, ..
            "thetaAmpereTurns", exactTheta, "bTesla", mu0 * exactTheta / parameters.gapM, ..
            "harmonicThetaAmpereTurns", harmonicTheta(index), "harmonicBTesla", mu0 * harmonicTheta(index) / parameters.gapM);
    end
    data.geometricFactor = geometric; data.fourierPrefactorH = prefactor; data.valid = %t;
    data.model = struct("coordinate", "Gemeinsamer mechanischer Winkel phi=2*pi*(Nut-1)/Q; Nutzgrundwelle k=p.", ..
        "assumptions", "Linear, muFe unendlich, gleichmäßiger dünner Luftspalt, gleiche Windungen je Spule, additive Strangserie.", ..
        "excluded", "Nut- und Wickelkopfstreuung, Sättigung, Eisenreluktanz, Rotorwicklung und Salienz.", ..
        "exact", "Exaktes stückweises Gram-Integral über den gesamten Statorumfang.");
endfunction

function lines = ew_inductance_derivation(winding, data, phase)
    if argn(2) < 3 then phase = "A"; end
    if type(phase) == 1 then phaseIndex = phase; else phaseIndex = ew_i_phase_index(phase); end
    phaseName = ["A"; "B"; "C"](phaseIndex);
    lines = ["Induktivitätsherleitung – sechs Etappen"; ..
        "Modell: ideal magnetisch leitendes Eisen, linearer Magnetkreis, gleichmäßiger dünner Luftspalt."; ..
        "Luftspalt-/Hauptinduktivität ohne Nut- und Wickelkopfstreuung oder Sättigung."];
    if ~data.valid then
        lines = [lines; "Keine vollständige gültige Wicklung verfügbar."; matrix(data.warnings, -1, 1)]; return;
    end
    par = data.parameters; phaseData = data.phases(phaseIndex);
    lines = [lines; ""; "1. Mechanische Spulenmitten und orientierte Strangmittelachse"; ..
        "phi_s = 2*pi*(s-1)/Q; beta = 2*pi*y/Q; epsilon_c = +/-1"; ..
        "gamma_c = phi_(c,+) + epsilon_c*beta/2"; ..
        "alpha_c = -arg(C_(c,p))/p; alpha_a = -arg(C_(a,p))/p (mod 2*pi/p)"; ..
        "Delta_alpha_(c,el) = wrap_[−pi,pi)(p*(alpha_c-alpha_a))"; ..
        msprintf("Q=%d, p=%d, y=%d; Strang %s: alpha_a=%.8g Grad mechanisch.", winding.slots, winding.polePairs, winding.coilSpan, phaseName, phaseData.axisDeg)];
    for index = 1:length(data.coils)
        coil = data.coils(index);
        if coil.phase == phaseName then
            lines($ + 1) = msprintf("%s: Mitte gamma=%.8g Grad; epsilon=%g; MMF-Achse=%.8g Grad; relativer elektrischer Winkel=%.8g Grad.", ..
                coil.id, coil.centerDeg, coil.direction, coil.axisDeg, coil.relativeElectricalDeg);
        end
    end
    lines = [lines; ""; "2. Spulen-, Gruppen- und Strangfaktoren als komplexe Vektorsummen"; ..
        "D_(c,k)=exp(-j*k*phi_(c,+))-exp(-j*k*phi_(c,-))"; ..
        "S_k=sin(k*beta/2); xi_k=S_k/k; C_(c,k)=epsilon_c*xi_k*exp(-j*k*gamma_c)"; ..
        "G_(g,k)=(1/N_(c,g))*sum_(c in g) epsilon_c*exp(-j*k*(gamma_c-alpha_g))"; ..
        "H_(a,k)=sum_g (N_(c,g)/N_(c,a))*G_(g,k)*exp(-j*k*(alpha_g-alpha_a))"; ..
        "k_(w,a,k)=abs(S_k*H_(a,k)); C_(a,k)=N_(c,a)*S_k*H_(a,k)*exp(-j*k*alpha_a)/k"; ..
        "1/k gehört zum integrierten Fourier-Koeffizienten, nicht zum dimensionslosen Wicklungsfaktor."; ..
        msprintf("k=%d: S_k=%.10g, |H|=%.10g, k_w=%.10g; %d Spulen in Serie.", ..
            par.selectedOrder, phaseData.selected.pitchFactor, phaseData.selected.distributionFactor.magnitude, ..
            phaseData.selected.windingFactor, phaseData.coilCount)];
    lines = [lines; ""; "3. Wicklungsfunktion, Durchflutung und Luftspaltflussdichte"; ..
        "w_a(phi): Einheitssprünge an den wirklichen Leiterseiten, Umfangsmittel null."; ..
        "N_a(phi)=n*w_a(phi); Theta(phi)=sum_a N_a(phi)*i_a"; ..
        "w_a(phi)=(2/pi)*Re(sum_(k>=1) C_(a,k)*exp(j*k*phi))"; ..
        "B(phi)=mu0*Theta(phi)/delta_eff, mu0=4*pi*10^(-7) H/m"; ..
        msprintf("r=%.10g m; lFe=%.10g m; delta_eff=%.10g m; n=%d Windungen je Spule.", par.radiusM, par.lengthM, par.gapM, par.turnsPerCoil); ..
        msprintf("i=[%.10g; %.10g; %.10g] A. Endliche Fourier-Summe bis K=%d.", par.currents(1), par.currents(2), par.currents(3), par.maxOrder)];
    lines = [lines; ""; "4. Flussverkettung durch Integration der Empfangsspule"; ..
        "Folienmodell einer Periode 2*tau_p; lokale elektrische Raumordnung nu:"; ..
        "xi_(S,nu)=sin(nu*pi*wS/(2*tau_p))/nu; entsprechend xi_(R,nu)."; ..
        "Integral_-wS/2^wS/2 cos(nu*pi*(x-xR)/tau_p) dx"; ..
        "=2*tau_p/(nu*pi)*sin(nu*pi*wS/(2*tau_p))*cos(nu*pi*xR/tau_p)"; ..
        "Psi_SR=(mu0/delta)*(4*tau_p/pi^2)*lFe*nS*nR*iR*sum_nu xiS*xiR*cos(nu*pi*xR/tau_p)"; ..
        "Für die ganze Maschine: tau_p=pi*r/p und p Perioden; mechanisches k zählt den vollen Umfang."; ..
        "Allgemein: Psi_a=r*lFe*Integral_0^(2*pi) N_a(phi)*B(phi) dphi."; ..
        msprintf("Tatsächliche Polteilung tau_p=%.10g mm.", par.polePitchM * 1000)];
    lines = [lines; ""; "5. Selbst- und Gegeninduktivitäten"; ..
        "Psi_a=sum_b L_ab*i_b; L_ab=(mu0*r*lFe/delta)*Integral N_a*N_b dphi"; ..
        "Exakt stückweise: L_ab=(mu0*r*lFe*n^2/delta)*sum_j w_(a,j)*w_(b,j)*Delta_phi_j"; ..
        "Fourier: L_ab=(4*mu0*r*lFe*n^2/(pi*delta))*sum_k Re(C_(a,k)*conj(C_(b,k)))"; ..
        "Für L_aa steht |C_(a,k)|^2. Gemeinsamen Winkelbezug aller Stränge bewahren!"; ..
        "Die Matrix ist symmetrisch und positiv semidefinit; Gegeninduktivitäten können negativ sein."; ..
        "M=-L/2 gilt für die symmetrische Grundwelle, nicht allgemein für alle Raumharmonischen."; ..
        msprintf("Fourier-Vorfaktor=%.12g H; relativer Matrix-Abbruchfehler=%.8g Prozent.", data.fourierPrefactorH, data.relativeTruncationError * 100); ..
        "Exakte Luftspaltmatrix in mH (Zeilen Empfang A/B/C, Spalten Erregung A/B/C):"];
    for index = 1:3
        lines($ + 1) = msprintf("[ % .12g  % .12g  % .12g ]", data.matrixH(index, 1) * 1000, data.matrixH(index, 2) * 1000, data.matrixH(index, 3) * 1000);
    end
    lines = [lines; ""; "6. Eingesetzte Ströme, Flussverkettung und Energie"; ..
        msprintf("Psi_%s = (%.10g)*(%.10g) + (%.10g)*(%.10g) + (%.10g)*(%.10g) = %.12g mWb", ..
            phaseName, data.matrixH(phaseIndex, 1) * 1000, par.currents(1), data.matrixH(phaseIndex, 2) * 1000, par.currents(2), ..
            data.matrixH(phaseIndex, 3) * 1000, par.currents(3), data.fluxLinkagesWbTurns(phaseIndex) * 1000); ..
        msprintf("Psi=[%.12g; %.12g; %.12g] mWb; Windungszahl ist bereits enthalten.", data.fluxLinkagesWbTurns(1) * 1000, data.fluxLinkagesWbTurns(2) * 1000, data.fluxLinkagesWbTurns(3) * 1000); ..
        "W_mag=0.5*i^T*L*i=(mu0*r*lFe/(2*delta))*Integral Theta(phi)^2 dphi >=0"; ..
        msprintf("Gespeicherte magnetische Energie W_mag=%.12g mJ.", data.energyJ * 1000); ..
        "L_ab=dPsi_a/di_b. L_aa=Psi_a/i_a nur bei allen übrigen Strangströmen null."; ..
        "Im linearen Modell sind Sekanten- und differentielle Induktivität gleich; ein Sättigungsmodell fehlt hier."];
endfunction
