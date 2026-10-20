// Independent physical fixtures and invariants. The abstract three-coil
// fixture below tests geometry; it is not advertised as a machine winding.
function winding = ew_test_inductance_fixture(span)
    names = ["A"; "B"; "C"];
    winding = struct("valid", %t, "slots", 12, "polePairs", 1, ..
        "layers", 2, "coilSpan", span, "coils", list(), "slotLayers", list());
    for index = 1:3
        layer = 1;
        if index == 3 then layer = 2; end
        positive = 1 + 3 * (index - 1);
        negative = ew_mod(positive - 1 + span, 12) + 1;
        coil = struct("id", names(index) + "1", "phase", names(index), ..
            "positiveSlot", positive, "negativeSlot", negative, ..
            "positiveLayer", layer, "negativeLayer", layer, "span", span, "direction", 1);
        winding.coils($ + 1) = coil;
        winding.slotLayers($ + 1) = struct("slot", positive, "layer", layer, "sign", 1, "phase", names(index));
        winding.slotLayers($ + 1) = struct("slot", negative, "layer", layer, "sign", -1, "phase", names(index));
    end
endfunction

function checks = ew_test_inductance()
    checks = 0;
    abstract = ew_compute_inductance(ew_test_inductance_fixture(6));
    parameters = abstract.parameters;
    mu0 = 4 * %pi * 1d-7;
    scale = mu0 * parameters.radiusM * parameters.lengthM * parameters.turnsPerCoil^2 / parameters.gapM;
    // Integral of the full-pitch zero-mean rectangular W^2 is pi/2.
    assert_checkalmostequal(abstract.matrixH(1, 1), scale * %pi / 2, 1d-12, 1d-15); checks = checks + 1;
    assert_checkalmostequal(abstract.matrixH(1, 2), 0, 1d-12, 1d-15); checks = checks + 1;
    assert_checkalmostequal(abstract.matrixH(1, 3), -scale * %pi / 2, 1d-12, 1d-15); checks = checks + 1;
    // The slide's Fourier identity sum_(odd k) 1/k^2 = pi^2/8.
    assert_checkalmostequal(abstract.fourierPrefactorH * %pi^2 / 8, scale * %pi / 2, 1d-12, 1d-15); checks = checks + 1;
    short = ew_compute_inductance(ew_test_inductance_fixture(4)); beta = 2 * %pi / 3;
    assert_checkalmostequal(short.matrixH(1, 1), scale * beta * (1 - beta / (2 * %pi)), 1d-12, 1d-15); checks = checks + 1;

    fixtures = [12,1,1,6; 36,2,1,0; 12,5,2,1; 9,4,2,1];
    expected = [3.2898681336964524,-1.3159472534785808; ..
        7.128047623008983,-2.9608813203268065; ..
        1.3159472534785808,0; 1.2672084663127074,-0.0487387871658734];
    for index = 1:4
        winding = ew_compute_winding(fixtures(index,1), fixtures(index,2), fixtures(index,3), fixtures(index,4));
        data = ew_compute_inductance(winding);
        assert_checktrue(data.valid); checks = checks + 1;
        assert_checkalmostequal(data.matrixH(1,1)*1000, expected(index,1), 1d-10, 1d-12); checks = checks + 1;
        assert_checkalmostequal(data.matrixH(1,2)*1000, expected(index,2), 1d-10, 1d-12); checks = checks + 1;
        assert_checktrue(size(ew_inductance_derivation(winding,data,"A"),1) >= 60); checks = checks + 1;
    end
    cases = 0;
    for Q = [6,9,12,18,24,36,60,120]
        poles = unique([1,2,4,5,max(1,floor(Q/4)),floor(Q/2)-1]);
        for p = matrix(poles,1,-1)
            if p > floor(Q/2) then continue; end
            for layers = 1:2
                winding = ew_compute_winding(Q,p,layers,0);
                if ~winding.valid then continue; end
                options = struct("maxOrder",20,"sampleCount",16,"selectedOrder",17,"currents",[2;-0.5;0.7]);
                data = ew_compute_inductance(winding,options);
                assert_checktrue(data.valid); checks = checks + 1;
                assert_checktrue(data.energyJ >= -1d-14); checks = checks + 1;
                assert_checkalmostequal(data.matrixH,data.matrixH',1d-12,1d-14); checks = checks + 1;
                assert_checkalmostequal(data.matrixH*options.currents,data.fluxLinkagesWbTurns,1d-12,1d-14); checks = checks + 1;
                assert_checktrue(min(spec(data.matrixH)) > -1d-12); checks = checks + 1;
                assert_checktrue(min(spec(data.matrixH-data.harmonicMatrixH)) > -1d-12); checks = checks + 1;
                for phase = 1:3
                    spectrum = ew_compute_spectrum(winding,20,data.phaseOrder(phase),"phase-sum");
                    for k = 1:20
                        coefficient = data.harmonics(k).coefficients(data.phaseOrder(phase));
                        assert_checkalmostequal(coefficient.real,spectrum.coefficients(k).rawReal,1d-10,1d-12); checks = checks + 1;
                        assert_checkalmostequal(coefficient.imag,spectrum.coefficients(k).rawImag,1d-10,1d-12); checks = checks + 1;
                    end
                    selected = data.phases(phase).selected; groupSum = 0;
                    for groupIndex = 1:length(data.groups)
                        group = data.groups(groupIndex);
                        if group.phase <> data.phaseOrder(phase) then continue; end
                        contribution = group.selected.phaseContribution;
                        groupSum = groupSum + contribution.real + %i*contribution.imag;
                    end
                    expectedFactor = selected.distributionFactor.real + %i*selected.distributionFactor.imag;
                    assert_checkalmostequal(groupSum,expectedFactor,1d-10,1d-12); checks = checks + 1;
                    assert_checkalmostequal(data.phases(phase).fundamental.windingFactor,winding.phases(phase).kw,1d-10,1d-12); checks = checks + 1;
                end
                // A common origin shift cannot alter self/mutual inductances.
                rotated = winding;
                for index = 1:length(rotated.coils)
                    coil = rotated.coils(index);
                    coil.positiveSlot = ew_mod(coil.positiveSlot,Q)+1;
                    coil.negativeSlot = ew_mod(coil.negativeSlot,Q)+1;
                    rotated.coils(index) = coil;
                end
                for index = 1:length(rotated.slotLayers)
                    side = rotated.slotLayers(index); side.slot = ew_mod(side.slot,Q)+1;
                    rotated.slotLayers(index) = side;
                end
                shifted = ew_compute_inductance(rotated,options);
                assert_checkalmostequal(shifted.matrixH,data.matrixH,1d-10,1d-12); checks = checks + 1;
                for index = 1:length(data.coils)
                    delta = ew_mod(shifted.coils(index).relativeElectricalRad-data.coils(index).relativeElectricalRad+%pi,2*%pi)-%pi;
                    assert_checkalmostequal(delta,0,1d-10,1d-12); checks = checks + 1;
                end
                // Reversing only phase A changes its mutual signs, not L_AA.
                flipped = winding;
                for index = 1:length(flipped.coils)
                    coil = flipped.coils(index);
                    if coil.phase <> "A" then continue; end
                    oldSlot = coil.positiveSlot; oldLayer = coil.positiveLayer;
                    coil.positiveSlot = coil.negativeSlot; coil.positiveLayer = coil.negativeLayer;
                    coil.negativeSlot = oldSlot; coil.negativeLayer = oldLayer;
                    coil.direction = -coil.direction; flipped.coils(index) = coil;
                end
                for index = 1:length(flipped.slotLayers)
                    side = flipped.slotLayers(index);
                    if side.phase == "A" then side.sign = -side.sign; flipped.slotLayers(index) = side; end
                end
                reversed = ew_compute_inductance(flipped,options); polarity = diag([-1;1;1]);
                assert_checkalmostequal(reversed.matrixH,polarity*data.matrixH*polarity,1d-10,1d-12); checks = checks + 1;
                cases = cases + 1;
            end
        end
    end
    winding = ew_compute_winding(9,4,2,1);
    low = ew_compute_inductance(winding,struct("maxOrder",20,"sampleCount",16));
    high = ew_compute_inductance(winding,struct("maxOrder",1200,"sampleCount",16));
    assert_checktrue(high.relativeTruncationError < low.relativeTruncationError); checks = checks + 1;
    assert_checktrue(high.relativeTruncationError < 0.003); checks = checks + 1;
    zero = ew_compute_inductance(winding,struct("currents",[0;0;0]));
    assert_checkequal(zero.fluxLinkagesWbTurns,[0;0;0]); checks = checks + 1;
    assert_checkequal(zero.energyJ,0); checks = checks + 1;
    assert_checkalmostequal(zero.matrixH,low.matrixH,1d-12,1d-14); checks = checks + 1;
    malformed = winding; coil = malformed.coils(1); coil.negativeSlot = coil.positiveSlot; malformed.coils(1) = coil;
    assert_checkfalse(ew_compute_inductance(malformed).valid); checks = checks + 1;
    message = "";
    try; ew_compute_inductance(winding,struct("gapM",0)); catch; message = lasterror(); end
    assert_checktrue(message <> ""); checks = checks + 1;
    mprintf("Induktivität: %d Prüfungen, %d gültige Maschinen plus analytische Kontrollspulen.\n",checks,cases);
endfunction
