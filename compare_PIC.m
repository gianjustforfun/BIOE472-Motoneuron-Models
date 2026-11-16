function compare_PIC()
% COMPARE_PIC Compare the separate contributions of NaP and CAN.
% Four conditions for each calibrated motoneuron:
%   Both ON, NaP OFF, CAN OFF, Both OFF.
% CaL and KCa remain active in all conditions.
% The injected current is 3 x each model's original ON rheobase.
% No parameters are refitted, and EL remains unchanged.

if ~exist('results','dir'), mkdir('results'); end

models = {'SOL_like','TA_like'};
labels = {'SOL-like','TA-like'};
conditions = {'Both ON','NaP OFF','CAN OFF','Both OFF'};
useNaP = [1 0 1 0];
useCAN = [1 1 0 0];

pre = 1500;
pulse = 500;
post = 1800;
rows = cell(8,15);
traces = cell(2,4);

for i = 1:2
    base = model_params(models{i});
    current = 3*base.rheobase;

    for j = 1:4
        p = base;
        p.gNaP = base.gNaP*useNaP(j);
        p.gCAN = base.gCAN*useCAN(j);

        % Let modified configurations settle without changing EL.
        if j > 1
            resting = run_protocol(p,[0 2000]);
            p.yRest = resting.y(end,:)';
        end

        r = run_protocol(p,[0 pre; current pulse; 0 post]);
        sp = r.spikes(r.spikes >= pre & r.spikes < pre+pulse);
        rates = 1000./diff(sp);

        FIF = NaN; SSF = NaN; ratio = NaN;
        if ~isempty(rates)
            FIF = rates(1);
            SSF = rates(end);
            ratio = FIF/SSF;
        end

        nPre = sum(r.spikes < pre);
        nPost = sum(r.spikes >= pre+pulse);
        nLast100 = sum(sp >= pre+pulse-100);
        lastSpike = NaN;
        if ~isempty(sp)
            lastSpike = sp(end)-pre; % Time since pulse onset (ms).
        end

        idx = (i-1)*4+j;
        rows(idx,:) = {labels{i},conditions{j},p.gNaP,p.gCAN, ...
            p.yRest(1),base.rheobase,current,FIF,SSF,ratio, ...
            nPre,numel(sp),nPost,nLast100,lastSpike};
        traces{i,j} = struct('r',r,'spikes',sp,'rates',rates);

        fprintf('%s | %-8s | Vrest %7.2f mV | FIF %7.2f | ', ...
            labels{i},conditions{j},p.yRest(1),FIF);
        fprintf('SSF %7.2f Hz | spikes %d/%d/%d | last 100 ms: %d\n', ...
            SSF,nPre,numel(sp),nPost,nLast100);
    end
end

T = cell2table(rows,'VariableNames',{'Model','Condition','gNaP','gCAN', ...
    'Vrest_mV','ON_rheobase','Applied_current','FIF_Hz','SSF_Hz', ...
    'FIF_over_SSF','Spikes_pre','Spikes_during','Spikes_post', ...
    'Spikes_last100ms','Last_spike_ms'});
writetable(T,fullfile('results','PIC_components_summary.csv'));

% Separate voltage traces: one panel per condition, never overlapping.
figure();
for i = 1:2
    for j = 1:4
        subplot(2,4,(i-1)*4+j);
        r = traces{i,j}.r;
        plot(r.t-pre,r.V,'k','LineWidth',0.7);
        xlim([-50 550]); ylim([-100 65]); grid on;
        xline(0,':'); xline(pulse,':');
        title(sprintf('%s | %s | %d spikes',labels{i},conditions{j}, ...
            numel(traces{i,j}.spikes)));
        xlabel('Time from pulse onset (ms)');
        ylabel('Membrane potential (mV)');
    end
end
sgtitle('NaP and CAN removal: membrane potential');
exportgraphics(gcf,fullfile('results','PIC_components_voltage.png'), ...
    'Resolution',160);

% Separate instantaneous-rate plots: each condition has its own axes.
figure();
for i = 1:2
    for j = 1:4
        subplot(2,4,(i-1)*4+j); hold on;
        sp = traces{i,j}.spikes;
        rates = traces{i,j}.rates;
        if ~isempty(rates)
            midpoints = (sp(1:end-1)+sp(2:end))/2-pre;
            plot(midpoints,rates,'.-','MarkerSize',9);
        end
        xlim([0 500]); grid on;
        title(sprintf('%s | %s',labels{i},conditions{j}));
        xlabel('Time from pulse onset (ms)');
        ylabel('Instantaneous firing rate (Hz)');
    end
end
sgtitle('NaP and CAN removal: firing-rate adaptation');
exportgraphics(gcf,fullfile('results','PIC_components_frequency.png'), ...
    'Resolution',160);

end
