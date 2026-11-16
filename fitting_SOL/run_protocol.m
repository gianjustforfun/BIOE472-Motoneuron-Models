function r = run_protocol(p, segments)
% RUN_PROTOCOL Simulate a rectangular current-clamp protocol.
% Each row of segments is [current (uA/cm^2), duration (ms)].
% Numerical method: MATLAB ode15s, as used for active HH-type models.
% The neuron starts at the equilibrium defined in model_params.m.

% Solver tolerances and maximum internal step size (ms).
opts = odeset('RelTol',1e-8,'AbsTol',1e-10,'MaxStep',0.1);

t = 0;
y = p.yRest';
I = segments(1,1);

% Simulate each constant-current interval, keeping the final state.
for k = 1:size(segments,1)
    current = segments(k,1);
    duration = segments(k,2);

    [tk,yk] = ode15s(@(t,x) dyn(t,x,p,current), ...
                     [t(end), t(end)+duration], y(end,:)', opts);

    % Skip the repeated time point at the start of each interval.
    t = [t; tk(2:end)];
    y = [y; yk(2:end,:)];
    I = [I; current*ones(length(tk)-1,1)];
end

% Detect action-potential peaks above 0 mV (Signal Processing Toolbox).
% This is a detection cutoff, not the physiological firing threshold.
% Skip findpeaks when the voltage never exceeds 0 mV.
V = y(:,1);

if any(V > 0)
    [~,sp] = findpeaks(V,t,'MinPeakHeight',0);
else
    sp = [];
end
% Detect spikes only if the voltage exceeds 0 mV.
% No spikes are expected during passive or subthreshold tests.
if any(V > 0)
    [~,sp] = findpeaks(V,t,'MinPeakHeight',0);
else
    sp = [];
end

r.t = t;
r.V = V;
r.y = y;
r.I = I;
r.spikes = sp;
end
