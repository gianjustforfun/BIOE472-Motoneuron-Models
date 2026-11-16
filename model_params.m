function p = model_params(condition)
% MODEL_PARAMS Calibrated parameters for SOL-like and TA-like motoneurons.
% Based on the six-state Molkov model (Kv1.2 removed: gKv1 = 0).
% Units: ms, mV, uA/cm^2, mS/cm^2, uF/cm^2, mM.
% Both SOL-like and TA-like models were calibrated numerically.
% Fitted parameters are model estimates, not direct measurements.

% Shared conductances, capacitance, reversal potentials (Molkov code).
% Note: gCaL = 0.01 in the repository; the article also lists 0.05.
p.C=1; p.gNaF=120; p.gCaL=.01;
p.ENa=55; p.ECa=80; p.ECAN=0;
p.EK=26.54*log(4/140);  % [K+]out = 4 mM, [K+]in = 140 mM.

% Calcium-dependent current constants and effective CICR dynamics (Molkov).
p.Kd=.2e-3; p.KCAN=.74e-3;
p.alphaCa=5e-6; p.tauCa=250;

% hRate and nRate rescale NaF/Kdr gating speeds; 1 = original Molkov.
p.hRate=1; p.nRate=1;

% Shared calibrated NaP/CAN levels, not measured in SOL or TA.
p.gNaP=.01; p.gCAN=1.05;

switch condition
    case 'SOL_like'
        % SOL-like target: Hadzipasic cluster 1 (Vrest = -70.3 mV).
        p.Vtarget = -70.3;

        % Original Molkov Kdr conductance, shared with TA-like.
        p.gKdr = 100;

        % Numerically fitted parameters (updated fitting).
        p.hRate = 0.8831005817202662;
        p.nRate = 0.3519733081847274;
        p.gKCa = 0.8335601089772888;

        % Leak conductance calibrated to tau = 8.9 ms.
        p.gL = 0.10448386558117018;

        % Effective electrical area derived from Rin = 95.4 MOhm.
        p.area = 9.566538424497626e-05;

        % Numerical rheobase for a 500-ms current pulse.
        p.rheobase = 0.86181640625;

    case 'TA_like'
        % TA-like target: Hadzipasic cluster 3 (Vrest = -74.2 mV).
        p.Vtarget = -74.2;

        % Original Molkov Kdr conductance, shared with SOL-like.
        p.gKdr = 100;

        % Numerically fitted parameters (updated fitting).
        p.hRate = 4.711388620598399;
        p.nRate = 6.804273234097027;
        p.gKCa = 2.3890445345840963;

        % Leak conductance calibrated to tau = 4.9 ms.
        p.gL = 0.18330878832335062;

        % Effective electrical area derived from Rin = 48 MOhm.
        p.area = 1.0497291222517192e-04;

        % Numerical rheobase for a 500-ms current pulse.
        p.rheobase = 2.861328125;
end

% Compute leak equilibrium E_L such that the chosen Vrest is an exact
% equilibrium of the six-state neuron, not just its leak current.
V=p.Vtarget;
mCa=1/(1+exp(-(V+27.5)/5.7)); hCa=1/(1+exp((V+52.4)/5.2));
hNa=1/(1+exp((V+55)/7)); mK=1/(1+exp(-(V+28)/15));
Ca=p.tauCa*p.alphaCa*p.gCaL*mCa*hCa*(p.ECa-V);
mNaF=1/(1+exp(-(V+35)/7.8));
mNaP=1/(1+exp(-(V+53)/3));
Iother=p.gNaF*mNaF^3*hNa*(V-p.ENa) ...
    +p.gNaP*mNaP*(V-p.ENa) + p.gKdr*mK^4*(V-p.EK) ...
    +p.gCaL*mCa*hCa*(V-p.ECa) ...
    +p.gKCa*Ca/(Ca+p.Kd)*(V-p.EK) ...
    +p.gCAN*Ca/(Ca+p.KCAN)*(V-p.ECAN);
p.EL=V+Iother/p.gL;
p.yRest=[V;Ca;mCa;hCa;hNa;mK];
end
