function T = timing_probe(numerology, targetMode)

if nargin<1 || isempty(numerology), numerology='wide'; end
if nargin<2 || isempty(targetMode), targetMode='AUDIT'; end
targetMode=upper(char(targetMode));

rootDir=fileparts(mfilename('fullpath'));
addpath(rootDir);
addpath(genpath(fullfile(rootDir,'src')));
addpath(genpath(fullfile(rootDir,'experiments')));
addpath(genpath(fullfile(rootDir,'validation')));

cfgProbe  = physical_core('ofdm_config','SMOKE',numerology);
cfgFast   = physical_core('ofdm_config','FAST',numerology);
cfgTarget = physical_core('ofdm_config',targetMode,numerology);
physical_core('channel_model','delay_model',cfgProbe.delayModel,cfgProbe.delayFilterHalfLength);

fprintf('\n============================================================\n');
fprintf('TIMING CALIBRATION | numerology %s | target %s\n',numerology,targetMode);
fprintf('Calibration points: SMOKE + FAST for frame-scaled studies\n');
fprintf('OTFS frame %d x %d = %d DD symbols | OFDM N=%d, CP=%d\n', ...
    cfgProbe.otfsN,cfgProbe.otfsM,cfgProbe.otfsN*cfgProbe.otfsM,cfgProbe.N,cfgProbe.Ncp);
fprintf('============================================================\n\n');

S = {
 'baseline',      @(c) researchXprobeCall('baseline',c),      true
 'estimation',    @(c) researchXprobeCall('estimation',c),    true
 'ici',           @(c) researchXprobeCall('ici',c),           true
 'equalizer',     @(c) researchXprobeCall('equalizer',c),     true
 'otfs',          @(c) researchXprobeCall('otfs',c),          true
 'crosswaveform', @(c) researchXprobeCall('crosswaveform',c), true
 'otfsPilot',     @(c) researchXprobeCall('otfsPilot',c),     true
 'pilots',        @(c) researchXprobeCall('pilots',c),        true
 'system',        @(c) researchXprobeCall('system',c),        true
 'impairments',   @(c) researchXprobeCall('impairments',c),   true
 'mobility',      @(c) researchXprobeCall('mobility',c),      false
 'reference',     @(c) researchXprobeCall('reference',c),     false
 'complexity',    @(c) researchXprobeCall('complexity',c),    false
 'resource',      @(c) researchXprobeCall('resource',c),      false
 'mismatch',      @(c) researchXprobeCall('mismatch',c),      true
 'mimo',          @(c) researchXprobeCall('mimo',c),          true
};

n=size(S,1);
T=struct('section',{},'smokeSeconds',{},'smokeFrames',{},'fastSeconds',{},'fastFrames',{}, ...
         'targetFrames',{},'estimatedSeconds',{},'lowSeconds',{},'highSeconds',{}, ...
         'model',{},'status',{},'note',{});

fprintf('%-16s %10s %7s %10s %7s %7s %12s  %s\n', ...
    'section','SMOKE(s)','SF','FAST(s)','FF','TF','est. AUDIT','model/status');
fprintf('%s\n',repmat('-',1,103));

totalProbe=0; totalFast=0;
for i=1:n
    name=S{i,1}; fn=S{i,2}; scaled=S{i,3};
    sF=research_suite('frame_count',name,cfgProbe);
    fF=research_suite('frame_count',name,cfgFast);
    tF=research_suite('frame_count',name,cfgTarget);
    ts=NaN; tf=NaN; status='ok'; note='';

    try
        fn(cfgProbe);
    catch ME
        status='WARMUP_FAILED'; note=ME.message;
    end

    if strcmp(status,'ok')
        t0=tic;
        try
            fn(cfgProbe); ts=toc(t0);
        catch ME
            status='SMOKE_FAILED'; note=ME.message;
        end
    end
    if strcmp(status,'ok') && scaled
        t0=tic;
        try
            fn(cfgFast); tf=toc(t0);
        catch ME
            status='FAST_FAILED'; note=ME.message;
        end
    end

    if strcmp(status,'ok')
        if ~scaled
            est=ts; low=0.90*est; high=1.10*est; model='fixed';
        elseif sF==fF
            est=ts*max(tF,1)/max(sF,1);
            low=0.80*est; high=1.25*est; model='single-point';
            note='SMOKE and FAST use the same frame floor; target is scaled from one point.';
        else
            b=(tf-ts)/(double(fF)-double(sF));
            a=ts-b*double(sF);
            if ~isfinite(b) || b<0
                b=max([ts/max(double(sF),1),tf/max(double(fF),1)]);
                a=0; model='linear-through-origin';
            else
                model='affine-2pt';
            end
            est=max(0,a+b*double(tF));
            extrap=double(tF)/max(double(fF),1);
            margin=0.15;
            if extrap>6
                margin=0.35;
            elseif extrap>3
                margin=0.25;
            end
            low=max(0,est*(1-margin)); high=est*(1+margin);
            note=sprintf('t(F)=%.3fs + %.6fs*F; margin %.0f%%.',a,b,100*margin);
        end
    else
        est=NaN; low=NaN; high=NaN; model='failed';
    end

    if isfinite(ts), totalProbe=totalProbe+ts; end
    if isfinite(tf), totalFast=totalFast+tf; end
    T(end+1)=struct('section',name,'smokeSeconds',ts,'smokeFrames',sF, ...
        'fastSeconds',tf,'fastFrames',fF,'targetFrames',tF,'estimatedSeconds',est, ...
        'lowSeconds',low,'highSeconds',high,'model',model,'status',status,'note',note);

    fprintf('%-16s %10s %7d %10s %7d %7d %12s  %s/%s\n',name, ...
        researchXprobeTime(ts),sF,researchXprobeTime(tf),fF,tF,researchXprobeTime(est),model,status);
    if ~isempty(note), fprintf('%18s%s\n','',note); end
end

fprintf('%s\n',repmat('-',1,103));
totEst=nansum([T.estimatedSeconds]);
totLow=nansum([T.lowSeconds]);
totHigh=nansum([T.highSeconds]);
fprintf('%-16s %10s %7s %10s %7s %7s %12s  range %s - %s\n', ...
    'TOTAL',researchXprobeTime(totalProbe),'','','','','',researchXprobeTime(totEst),researchXprobeTime(totHigh));
fprintf('Planning range (conservative): %s - %s\n',researchXprobeTime(totLow),researchXprobeTime(totHigh));

[~,ord]=sort([T.estimatedSeconds],'descend','MissingPlacement','last');
fprintf('\nDominant sections at %s:\n',targetMode);
for k=1:min(5,numel(ord))
    j=ord(k);
    if isnan(T(j).estimatedSeconds), continue; end
    fprintf('  %-16s %10s  (%4.1f%% of central estimate)\n',T(j).section, ...
        researchXprobeTime(T(j).estimatedSeconds),100*T(j).estimatedSeconds/max(totEst,eps));
end
fprintf('\nThe central estimate is calibrated from the same study functions and the same frame-budget rules used by the production AUDIT pipeline.\n');
fprintf('The interval is a planning margin, not a statistical confidence interval. Checkpoint I/O, final validation, plotting, and machine-level load are excluded.\n\n');
end

function s = researchXprobeTime(t)
if isnan(t), s='n/a'; return; end
if t<90, s=sprintf('%.1f s',t);
elseif t<5400, s=sprintf('%.1f min',t/60);
else, s=sprintf('%.2f h',t/3600); end
end

function researchXprobeCall(name,cfg)
switch name
    case 'baseline',      research_suite('research_experiments_probe','baseline',cfg);
    case 'estimation',    research_suite('research_experiments_probe','estimation',cfg);
    case 'ici',           research_suite('research_experiments_probe','ici',cfg);
    case 'equalizer',     research_suite('research_experiments_probe','equalizer',cfg);
    case 'otfs',          research_suite('research_experiments_probe','otfs',cfg);
    case 'crosswaveform', research_suite('research_experiments_probe','crosswaveform',cfg);
    case 'pilots',        research_suite('research_experiments_probe','pilots',cfg);
    case 'system',        research_suite('research_experiments_probe','system',cfg);
    case 'impairments',   research_suite('research_experiments_probe','impairments',cfg);
    case 'mobility',      research_suite('research_experiments_probe','mobility',cfg);
    case 'mismatch',      research_suite('research_experiments_probe','mismatch',cfg);
    case 'mimo',          research_suite('research_experiments_probe','mimo',cfg);
    case 'otfsPilot',     otfs_core('otfs_channel_estimation','pilotStudy',cfg,'SMOKE');
    case 'reference',     analysis_tools('reference_validation');
    case 'complexity',    analysis_tools('complexity_analysis',cfg.N,cfg.iciBands,[cfg.otfsN cfg.otfsM],min(4,max(cfg.bemOrders)),cfg.otfsIterations);
    case 'resource',      research_suite('research_experiments_probe','resource',cfg);
    otherwise, error('Unknown probe section %s.',name);
end
end
