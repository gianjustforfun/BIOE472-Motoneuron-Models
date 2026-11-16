% MAIN_FITTING Calibrate the TA-like motoneuron using Hadzipasic et al. (2014).
% Model: modified six-state Molkov et al. (2025) motoneuron.
% Fit only [NaF kinetic factor, Kdr kinetic factor, KCa conductance].
% Leak and effective area are derived from passive targets, not independent fits.
% The solution is phenomenological and need not be unique.

clear; clc;

% Parameter limits and two initial guesses (modeling choices, not measured ranges).
% Columns: [hRate, nRate, gKCa (mS/cm^2)].
bounds = [1 6; 1 10; 0.65 3.5];
starts = [2.5 4 1.8; 4.5 7 2.4];

% Experimental targets for the TA-associated cluster (Hadzipasic et al.).
target.tau = 4.9;      % Membrane time constant (ms).
target.Rin = 48;       % Input resistance (MOhm).
target.SSF = 74.6;     % Last interspike frequency (Hz).
target.ratio = 340.6/74.6; % First/last interspike frequency ratio.

% Nelder-Mead optimization (fminsearch does not require derivatives).
% Any trial outside 'bounds' receives a large penalty in fitting_error.
options = optimset('Display','iter','MaxFunEvals',90,'MaxIter',65, ...
                   'TolX',0.025,'TolFun',0.002);

bestLoss = Inf;
bestIdx = 0;
allTheta = zeros(size(starts));
allLoss = NaN(size(starts,1),1);
exitFlags = NaN(size(starts,1),1);

for k = 1:size(starts,1)
    fprintf('\nFitting start %d of %d\n',k,size(starts,1));
    [theta,~,exitFlags(k)] = fminsearch( ...
        @(x) fitting_error(x,bounds,target), starts(k,:), options);

    [allLoss(k),info] = fitting_error(theta,bounds,target);
    allTheta(k,:) = theta;
    fprintf('Start %d: loss = %.5f, exitflag = %d\n', ...
            k,allLoss(k),exitFlags(k));

    if ~isempty(info) && allLoss(k) < bestLoss
        bestLoss = allLoss(k);
        bestTheta = theta;
        best = info;
        bestIdx = k;
    end
end

if bestIdx == 0
    error('No valid candidate was found. Try different initial guesses.');
end

% Extract the parameters and results of the best fit.
p = best.p;
rh = best.rh;
p.rheobase = rh;  % Store the calculated rheobase in the parameter structure.

tau = best.tau;
Rin = best.Rin;
fif = best.fif;
ssf = best.ssf;

fprintf('\nBest TA-like fit (start %d):\n',bestIdx);
fprintf('hRate %.4f | nRate %.4f | gKCa %.4f mS/cm^2\n',bestTheta);
fprintf('gL %.5f | EL %.3f mV | effective area %.7g cm^2\n', ...
        p.gL,p.EL,p.area);
fprintf('Vrest %.2f mV | Rin %.2f MOhm | tau %.3f ms\n', ...
        p.yRest(1),Rin,tau);
fprintf('FIF %.2f Hz | SSF %.2f Hz | ratio %.3f | rheobase %.3f uA/cm^2\n', ...
        fif,ssf,best.ratio,rh);
fprintf('Loss %.5f | spikes %d | pre/post %d/%d\n', ...
        bestLoss,best.nSpikes,best.nPre,best.nPost);
if exitFlags(bestIdx) ~= 1
    fprintf('Note: optimization stopped without confirmed convergence.\n');
end

if ~exist('results','dir'), mkdir('results'); end
save(fullfile('results','TA_matlab_fitting.mat'), ...
    'bestTheta','bestLoss','p','rh','tau','Rin','fif','ssf', ...
    'allTheta','allLoss','exitFlags','bestIdx');


% -------------------------------------------------------------------------
% Local functions used only by this fitting script.
% -------------------------------------------------------------------------
function [loss,info] = fitting_error(theta,bounds,target)
% One consistent numerical protocol for fitting and final evaluation.
% Invalid candidates receive a high loss rather than being selected.
loss = 1000;
info = [];
low = bounds(:,1)';
high = bounds(:,2)';
if any(~isfinite(theta))
    return;
end
if any(theta < low) || any(theta > high)
    loss = 1000 + sum(max(low-theta,0).^2 + max(theta-high,0).^2);
    return;
end

try
    % Match passive membrane time constant by adjusting the leak conductance.
    p = fit_params(theta);
    for j = 1:3
        [tau,~] = passive_response(p);
        gL = p.gL + p.C*(1/target.tau - 1/tau);
        if gL <= 0.05 || gL >= 0.5
            return;
        end
        p = fit_params(theta,gL);
    end

    % Match Rin using an effective electrical area, not an anatomical area.
    [tau,dV] = passive_response(p);
    testCurrent = 0.05; % Magnitude of hyperpolarizing pulse, uA/cm^2.
    p.area = abs(dV)/(testCurrent*1000*target.Rin);
    Rin = abs(dV)/(testCurrent*1000*p.area);

    % Each candidate is stimulated at 3 times its own 500-ms rheobase.
    rh = find_rheobase(p);
    pre = 1500; pulse = 500; post = 1800;
    r = run_protocol(p,[0 pre; 3*rh pulse; 0 post]);
    s = r.spikes(r.spikes >= pre & r.spikes < pre+pulse);
    nPre = sum(r.spikes < pre);
    nPost = sum(r.spikes >= pre+pulse);
    
    % Require enough spikes to calculate distinct initial and final ISIs.
    if numel(s) < 3 || nPre > 0
        return;
    end

    rates = 1000./diff(s);
    if any(~isfinite(rates)) || any(rates <= 0)
        return;
    end
    fif = rates(1);
    ssf = rates(end);
    ratio = fif/ssf;

    % Weighted relative errors plus a regularization penalty.
    % All weights and the KCa reference 1.185 are modeling choices.
    loss = (2*log(ratio/target.ratio))^2 ...
         + (1.2*log(ssf/target.SSF))^2 ...
         + 0.035*(log(theta(1))^2 + log(theta(2))^2 ...
                    + log(theta(3)/1.185)^2) ...
         + 10*log(tau/target.tau)^2;

    info = struct('p',p,'tau',tau,'Rin',Rin,'rh',rh, ...
        'fif',fif,'ssf',ssf,'ratio',ratio, ...
        'nSpikes',numel(s),'nPre',nPre,'nPost',nPost);
catch ME
    % A candidate whose simulation fails is not accepted by the optimizer.
    warning('Fitting candidate failed: %s',ME.message);
end
end

function [tau,dV] = passive_response(p)
% Effective membrane time constant from a small hyperpolarizing step.
% The 63.2%% rule is exact for a passive first-order membrane, approximate here.
r = run_protocol(p,[-0.05 300]);
dV = r.V(end)-p.yRest(1);
level = p.yRest(1)+(1-exp(-1))*dV;
i = find(r.V <= level,1,'first');
if isempty(i) || i < 2
    error('Cannot measure passive membrane time constant.');
end
tau = r.t(i-1) + (level-r.V(i-1))*(r.t(i)-r.t(i-1)) ...
                 /(r.V(i)-r.V(i-1));
end
