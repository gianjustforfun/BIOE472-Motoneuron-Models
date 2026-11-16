% MAIN Simulate two calibrated SOL-like and TA-like motoneuron models.
% Based on Molkov et al. (2025), calibrated to Hadzipasic et al. (2014).
% Fitting stays separate; NaP/CAN comparisons run after the main simulations.
% FIF and SSF are the first and last interspike frequencies, respectively.

clear; clc; close all;
if ~exist('results','dir')
    mkdir('results');
end

models = {'SOL_like','TA_like'};
labels = {'SOL-like motoneuron','TA-like motoneuron'};
pre = 1500;       % Baseline before the pulse (ms).
pulse = 500;      % Current pulse duration (ms), following Hadzipasic.
post = 1800;      % Recovery after the pulse (ms).
testCurrent = -0.05;  % Small hyperpolarizing current for passive properties (uA/cm^2).
rows = cell(numel(models),11);

for k = 1:numel(models)
    % Load fixed parameters. Rheobase was estimated numerically and saved.
    p = model_params(models{k});
    rh = p.rheobase;

    % Apply a 500-ms pulse at three times the model's own rheobase.
    r = run_protocol(p,[0 pre; 3*rh pulse; 0 post]);

    % Firing frequency = 1000 / interspike interval (ISI in ms).
    % SSF uses the last ISI; this alone does not prove a steady state.
    sp = r.spikes(r.spikes >= pre & r.spikes < pre+pulse);
    rates = 1000./diff(sp);
    fif = rates(1);
    ssf = rates(end);

    % Passive response to a small negative current pulse.
    % Rin uses an effective area calibrated to the experimental target;
    % it is not an independent prediction of membrane resistance.
    passive = run_protocol(p,[testCurrent 300]);
    dv = passive.V(end)-p.yRest(1);
    Rin = abs(dv)/(abs(testCurrent)*1000*p.area);  % MOhm.

    % Membrane time constant: time to reach 63.2% of the passive response.
    level = p.yRest(1)+(1-exp(-1))*dv;
    idx = find(passive.V <= level,1,'first');
    tau = passive.t(idx-1)+(level-passive.V(idx-1)) ...
        *(passive.t(idx)-passive.t(idx-1)) ...
        /(passive.V(idx)-passive.V(idx-1));

    % Check that firing occurs only during the applied current pulse.
    npre = sum(r.spikes < pre);
    npost = sum(r.spikes >= pre+pulse);
    fprintf('\n%s | Vrest %.2f mV | Rin %.2f MOhm | tau %.2f ms\n', ...
        labels{k},p.yRest(1),Rin,tau);
    fprintf('FIF %.2f, SSF %.2f Hz, ratio %.2f | spikes %d / %d / %d\n', ...
        fif,ssf,fif/ssf,npre,numel(sp),npost);

    % Save one summary row per motoneuron.
    rows(k,:) = {labels{k},p.hRate,p.nRate,p.gKCa,p.gL, ...
        p.yRest(1),Rin,tau,rh,fif,ssf};

    % Plot the membrane voltage, firing rate, and injected current.
    figure();
    subplot(3,1,1);
    plot(r.t-pre,r.V,'k'); xlim([-50 550]); ylim([-100 65]); grid on;
    xline(0,':'); xline(pulse,':'); title(labels{k});
    ylabel('Membrane potential (mV)');

    subplot(3,1,2);
    plot((sp(1:end-1)+sp(2:end))/2-pre,rates,'k.-'); grid on;
    xlim([0 pulse]); ylabel('Instantaneous rate (Hz)');

    subplot(3,1,3);
    plot(r.t-pre,r.I,'k','LineWidth',1.3); grid on;
    xlim([-50 550]); xlabel('Time from pulse onset (ms)');
    ylabel('Applied current (uA/cm2)');
    exportgraphics(gcf,fullfile('results',[models{k} '.png']),'Resolution',150);
end

% Export numerical results for comparison with experimental targets.
T = cell2table(rows,'VariableNames',{'Condition','hNaF_rate','mKdr_rate', ...
    'gKCa','gL','Vrest_mV','Rin_MOhm','tau_ms','rheobase','FIF_Hz','SSF_Hz'});
T.ratio_FIF_SSF = T.FIF_Hz./T.SSF_Hz;
writetable(T,fullfile('results','summary_matlab.csv'));

% Run the four NaP/CAN conditions for both motoneurons.
compare_PIC();
