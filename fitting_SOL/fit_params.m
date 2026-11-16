function p = fit_params(theta, gL)
% FIT_PARAMS Build a SOL-like candidate for the fitting routine.
% Based on the six-state model adapted from Molkov et al. (2025).
% theta = [hRate, nRate, gKCa (mS/cm^2)]: three fitted parameters.
% Kinetic factors scale both directions of NaF/Kdr gating, not just recovery.
% These factors and fitted conductances are not direct measurements.

% Optional leak conductance: initial passive estimate if not supplied.
% gL is subsequently recalibrated to the 8.9-ms membrane time constant.
if nargin < 2
    gL = 1/8.9;
end
if numel(theta) ~= 3
    error('theta must be [hRate, nRate, gKCa].');
end

% Membrane properties and ion reversal potentials from Molkov's code.
% Note: gCaL = 0.01 follows the code; the paper also reports 0.05.
p.C = 1; p.gNaF = 120; p.gCaL = .01;
p.ENa = 55; p.ECa = 80; p.ECAN = 0;
p.EK = 26.54*log(4/140);

% Calcium-dependent activation and effective calcium dynamics (Molkov).
% tauCa = 250 ms represents CICR indirectly, without explicit Ca stores.
p.Kd = .2e-3; p.KCAN = .74e-3;
p.alphaCa = 5e-6; p.tauCa = 250;

% Shared NaP/CAN conductances chosen during model calibration.
% These are not measured SOL-specific conductances.
p.gNaP = .01; p.gCAN = 1.05;

% SOL-associated resting potential: Hadzipasic et al. (2014), cluster 1.
% gKdr = 100 follows Molkov for the same three-parameter fitting approach as TA.
% The previous SOL manual model used gKdr = 60; it is NOT reused here.
p.Vtarget = -70.3; p.gKdr = 100;
p.hRate = theta(1); p.nRate = theta(2); p.gKCa = theta(3);
p.gL = gL;

% Assigned later by the fitting protocol, not free optimization variables.
p.area = NaN; p.rheobase = NaN;

% Construct an equilibrium at Vtarget, with no injected current.
% Gating variables are initialized at their steady-state values.
V = p.Vtarget;
mCa = 1/(1+exp(-(V+27.5)/5.7));
hCa = 1/(1+exp((V+52.4)/5.2));
hNa = 1/(1+exp((V+55)/7));
mK = 1/(1+exp(-(V+28)/15));

% Calcium equilibrium follows dCa/dt = 0 for the simplified Ca equation.
Ca = p.tauCa*p.alphaCa*p.gCaL*mCa*hCa*(p.ECa-V);
mNaF = 1/(1+exp(-(V+35)/7.8));
mNaP = 1/(1+exp(-(V+53)/3));

% Sum all currents except leak at the selected resting potential.
Iother = p.gNaF*mNaF^3*hNa*(V-p.ENa) ...
       + p.gNaP*mNaP*(V-p.ENa) + p.gKdr*mK^4*(V-p.EK) ...
       + p.gCaL*mCa*hCa*(V-p.ECa) ...
       + p.gKCa*Ca/(Ca+p.Kd)*(V-p.EK) ...
       + p.gCAN*Ca/(Ca+p.KCAN)*(V-p.ECAN);

% Enforce zero net membrane current: Iother + gL*(V - EL) = 0.
% EL is derived for each candidate, not fitted independently.
p.EL = V + Iother/p.gL;

% Initial state: [V; Ca; mCaL; hCaL; hNaF; mKdr].
p.yRest = [V; Ca; mCa; hCa; hNa; mK];
end
