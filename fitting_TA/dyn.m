function dx = dyn(~,x,p,Iapp)
% DYN Six-state, single-compartment motoneuron dynamics.
% Ionic equations: Molkov et al. (2025), Front. Cell. Neurosci.
% DOI: 10.3389/fncel.2025.1710893
% Adaptations: Kv1.2 omitted (gKv1 = 0); NaF/Kdr kinetics rescaled for SOL/TA.
% Units: time ms, voltage mV, Ca mM, current uA/cm^2, capacitance uF/cm^2.
% Limitations: no spatial compartments or dynamic Na+/K+ concentrations;
% NaF/NaP activation is instantaneous, and Ca handling is simplified.

% State vector: [voltage; intracellular Ca; CaL activation; CaL inactivation;
%                NaF inactivation; Kdr activation].
V=x(1); Ca=x(2); mCa=x(3); hCa=x(4);
hNa=x(5); mK=x(6);

% Instantaneous NaF/NaP activation curves from Molkov's model.
% NaP activates at more negative voltages and has no inactivation gate here.
mNaF=1/(1+exp(-(V+35)/7.8));
mNaP=1/(1+exp(-(V+53)/3));

% Ionic current densities (outward current is positive).
% NaF: fast spike upstroke; NaP: sustained depolarizing sodium current.
INaF=p.gNaF*mNaF^3*hNa*(V-p.ENa);
INaP=p.gNaP*mNaP*(V-p.ENa);
% Kdr: delayed rectifier for repolarization (four activation factors).
IKdr=p.gKdr*mK^4*(V-p.EK);
% CaL: voltage-gated Ca entry; KCa: Ca-dependent outward K current.
ICa=p.gCaL*mCa*hCa*(V-p.ECa);
IKCa=p.gKCa*Ca/(Ca+p.Kd)*(V-p.EK);
% CAN: Ca-activated, nonselective inward cation current at negative V.
ICAN=p.gCAN*Ca/(Ca+p.KCAN)*(V-p.ECAN);
% Leak: passive membrane current; E_L is set to balance currents at rest.
IL=p.gL*(V-p.EL);

% Membrane charge balance (current densities divided by specific capacitance).
dV=(Iapp-INaF-INaP-IKdr-ICa-IKCa-ICAN-IL)/p.C;
% Effective Ca dynamics: CaL influx plus first-order removal.
% The long tauCa incorporates CICR phenomenologically (Molkov),
% without explicit intracellular Ca stores or separate CICR states.
dCa=-p.alphaCa*ICa-Ca/p.tauCa;

% Voltage-dependent steady-state gating functions from Molkov.
mCai=1/(1+exp(-(V+27.5)/5.7));
hCai=1/(1+exp((V+52.4)/5.2));
hNai=1/(1+exp((V+55)/7));
mKi=1/(1+exp(-(V+28)/15));
% Original voltage-dependent time constants for NaF inactivation and Kdr.
tauNa=30/(exp((V+50)/15)+exp(-(V+50)/16));
tauK=7/(exp((V+40)/40)+exp(-(V+40)/50));

% Gating ODEs: CaL time constants (0.5, 18 ms) are from Molkov.
% hRate and nRate are fitted multipliers, not measured channel properties.
% Values > 1 speed up both directions of the respective gating dynamics.
dx=[dV;dCa;(mCai-mCa)/.5;(hCai-hCa)/18; ...
    p.hRate*(hNai-hNa)/tauNa; ...
    p.nRate*(mKi-mK)/tauK];
end
