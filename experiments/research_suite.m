function varargout = research_suite(mode,varargin)
mode=lower(char(mode));
switch mode
case 'frame_count'
    varargout{1} = researchXexperimentsXframeCount(varargin{:});
case 'research_experiments_probe'
    if nargout==0
        researchXexperimentsXrunOne(varargin{:});
    else
        [varargout{1:nargout}] = researchXexperimentsXrunOne(varargin{:});
    end
case 'research_experiments_resumable'
    if nargout==0
        researchXexperimentsXresumable(varargin{:});
    else
        [varargout{1:nargout}] = researchXexperimentsXresumable(varargin{:});
    end
otherwise
    error('Unknown mode %s for %s.',mode,mfilename);
end
end

function F=researchXexperimentsXframeCount(name,cfg)
stage=upper(char(cfg.mode));
switch name
    case 'baseline'
        F=cfg.framesBaseline; if strcmp(stage,'SMOKE'),F=2; elseif strcmp(stage,'FAST'),F=min(F,35); end
    case 'estimation'
        F=cfg.framesEstimation; if strcmp(stage,'SMOKE'),F=2; elseif strcmp(stage,'FAST'),F=min(F,16); end
    case 'ici'
        F=cfg.framesICI; if strcmp(stage,'SMOKE'),F=2; elseif strcmp(stage,'FAST'),F=min(F,8); end
    case 'equalizer'
        F=cfg.framesICI; if strcmp(stage,'SMOKE'),F=2; elseif strcmp(stage,'FAST'),F=min(F,10); end
    case 'otfs'
        F=cfg.framesOTFS; if strcmp(stage,'SMOKE'),F=1; elseif strcmp(stage,'FAST'),F=min(F,5); end
    case 'crosswaveform'
        switch stage
            case 'SMOKE', F=1; case 'FAST', F=4; case 'AUDIT', F=cfg.crosswaveformFramesAudit;
            case 'FULL', F=cfg.crosswaveformFramesFull; otherwise, F=cfg.crosswaveformFramesFull;
        end
    case 'otfsPilot'
        F=cfg.otfsPilotFrames; if strcmp(stage,'SMOKE'),F=1; elseif strcmp(stage,'FAST'),F=min(F,3); end
    case 'pilots'
        F=max(4,min(cfg.framesEstimation,20)); if strcmp(stage,'SMOKE'),F=2; elseif strcmp(stage,'FAST'),F=min(F,8); end
    case 'mismatch'
        F=max(4,min(cfg.framesEstimation,30)); if strcmp(stage,'FAST'),F=min(F,8); end
    case 'mimo'
        F=max(4,min(cfg.framesSystem,25)); if strcmp(stage,'FAST'),F=min(F,8); end
    case 'impairments'
        F=cfg.impairmentFramesAudit; if strcmp(stage,'SMOKE'),F=4; elseif strcmp(stage,'FAST'),F=min(F,60); end
    case 'system'
        F=max(100,min(2000,cfg.framesSystem*10));
    case {'mobility','reference','complexity','resource'}
        F=1;
    otherwise
        F=1;
end
F=double(F);
end

function R=researchXexperimentsXrunOne(name,cfg)
stage=cfg.mode;
switch name
    case 'baseline',      R=researchXexperimentsXbaselineStudy(cfg,stage);
    case 'estimation',    R=researchXexperimentsXestimationStudy(cfg,stage);
    case 'ici',           R=researchXexperimentsXiciStudy(cfg,stage);
    case 'equalizer',     R=researchXexperimentsXequalizerStudy(cfg,stage);
    case 'otfs',          R=researchXexperimentsXotfsStudy(cfg,stage);
    case 'crosswaveform', R=researchXexperimentsXcrosswaveformStudy(cfg,stage);
    case 'pilots',        R=researchXexperimentsXpilotOptimizationStudy(cfg,stage);
    case 'system',        R=researchXexperimentsXsystemStudy(cfg,stage);
    case 'impairments',   R=researchXexperimentsXimpairmentStudy(cfg,stage);
    case 'mobility',      R=researchXexperimentsXmobilityStudy(cfg);
    case 'resource',      R=researchXexperimentsXmimoResourceStudy(cfg);
    case 'mismatch',      R=researchXexperimentsXmismatchStudy(cfg,stage);
    case 'mimo',          R=researchXexperimentsXmimoOfdmStudy(cfg,stage);
    otherwise, error('Unknown study %s.',name);
end
end

function out=researchXexperimentsXresumable(cfg,stage,runControl)
if nargin<3 || isempty(runControl), runControl='RESUME'; end
runControl=upper(char(runControl));
rootDir=fileparts(fileparts(mfilename('fullpath')));
resultsDir=fullfile(rootDir,'results'); if ~exist(resultsDir,'dir'), mkdir(resultsDir); end
mode=upper(char(stage)); numerology=lower(char(cfg.numerology));
checkpointDir=fullfile(resultsDir,'checkpoints'); if ~exist(checkpointDir,'dir'), mkdir(checkpointDir); end
checkpointFile=fullfile(checkpointDir,sprintf('checkpoint_%s_%s.mat',lower(mode),lower(numerology)));
checkpointVersion='V8.5-SCI-CLAIMABLE-CHECKPOINT-1';
fields={'baseline','estimation','ici','equalizer','otfs','crosswaveform','otfsPilot','pilots','system','impairments','mobility','reference','complexity','resource'};
if ismember(mode,{'AUDIT','FULL','MASSIVE'}), fields=[fields {'mismatch','mimo'}]; end

if strcmp(runControl,'RESTART')
    if exist(checkpointFile,'file'), delete(checkpointFile); end
end

out=struct(); completed={}; rngState=[];
if exist(checkpointFile,'file') && ~strcmp(runControl,'RESTART')
    try
        S=load(checkpointFile);
        if isfield(S,'checkpoint')
            cp=S.checkpoint;
        elseif isfield(S,'S')
            cp=S.S;
        else
            error('Checkpoint file contains neither checkpoint nor S variable.');
        end
        compatible=isfield(cp,'version') && strcmp(cp.version,checkpointVersion) && ...
            isfield(cp,'release') && strcmp(cp.release,cfg.release) && ...
            isfield(cp,'mode') && strcmpi(cp.mode,mode) && ...
            isfield(cp,'numerology') && strcmpi(cp.numerology,numerology);
        if compatible
            out=cp.out; completed=cp.completedStages; rngState=cp.rngState;
            if ~isempty(rngState), rng(rngState); end
            fprintf('[RESUME] Loaded checkpoint: %d/%d top-level studies complete.\n',numel(completed),numel(fields));
        else
            fprintf('[RESUME] Existing checkpoint is incompatible with this run and will be replaced.\n');
        end
    catch ME
        fprintf('[RESUME] Checkpoint could not be loaded safely; starting from scratch.\n');
        fprintf('[RESUME] %s\n',ME.message);
    end
end
if isempty(fieldnames(out)), rng(cfg.randomSeed,'twister'); end

for si=1:numel(fields)
    name=fields{si};
    if any(strcmp(completed,name)), continue; end
    fprintf('\n============================================================\n');
    fprintf('[AUDIT] Starting study %d/%d: %s | %s/%s\n',si,numel(fields),name,mode,numerology);
    tStage=tic;
    try
        switch name
            case 'baseline', R=researchXexperimentsXbaselineStudy(cfg,mode);
            case 'estimation', R=researchXexperimentsXestimationStudy(cfg,mode);
            case 'ici', R=researchXexperimentsXiciStudy(cfg,mode);
            case 'equalizer', R=researchXexperimentsXequalizerStudy(cfg,mode);
            case 'otfs', R=researchXexperimentsXotfsStudy(cfg,mode);
            case 'crosswaveform', R=researchXexperimentsXcrosswaveformStudy(cfg,mode);
            case 'otfsPilot', R=otfs_core('otfs_channel_estimation','pilotStudy',cfg,mode);
            case 'pilots', R=researchXexperimentsXpilotOptimizationStudy(cfg,mode);
            case 'system', R=researchXexperimentsXsystemStudy(cfg,mode);
            case 'impairments', R=researchXexperimentsXimpairmentStudy(cfg,mode);
            case 'mobility', R=researchXexperimentsXmobilityStudy(cfg);
            case 'reference', R=analysis_tools('reference_validation');
            case 'complexity', R=analysis_tools('complexity_analysis',cfg.N,cfg.iciBands,[cfg.otfsN cfg.otfsM],min(4,max(cfg.bemOrders)),cfg.otfsIterations);
            case 'resource', R=researchXexperimentsXmimoResourceStudy(cfg);
            case 'mismatch', R=researchXexperimentsXmismatchStudy(cfg,mode);
            case 'mimo', R=researchXexperimentsXmimoOfdmStudy(cfg,mode);
            otherwise, error('Unknown checkpoint stage %s.',name);
        end
        out.(name)=R;
        completed{end+1}=name;
        rngState=rng;
        checkpoint=struct('version',checkpointVersion,'release',cfg.release,'mode',mode,'numerology',numerology, ...
            'completedStages',{completed},'rngState',rngState,'out',out,'updatedAt',datestr(now,30), ...
            'lastCompletedStage',name,'lastStageSeconds',toc(tStage));
        researchXexperimentsXatomic_save(checkpointFile,checkpoint);
        fprintf('[AUDIT] Completed %s in %.3f s; checkpoint saved.\n',name,checkpoint.lastStageSeconds);
    catch ME
        rngState=rng;
        checkpoint=struct('version',checkpointVersion,'release',cfg.release,'mode',mode,'numerology',numerology, ...
            'completedStages',{completed},'rngState',rngState,'out',out,'updatedAt',datestr(now,30), ...
            'failedStage',name,'errorIdentifier',ME.identifier,'errorMessage',ME.message);
        researchXexperimentsXatomic_save(checkpointFile,checkpoint);
        fprintf('[AUDIT] FAILED in study %s. Checkpoint saved.\n',name);
        rethrow(ME);
    end
end

out.metaCheckpoint=struct('checkpointFile',checkpointFile,'completedStages',{completed},'version',checkpointVersion);
end

function researchXexperimentsXatomic_save(fname,S)
tmp=[tempname(fileparts(fname)) '.mat'];
cleanup=onCleanup(@() researchXexperimentsXdelete_if_exists(tmp));
checkpoint=S;
sv=whos('S');
if sv.bytes > 2^31-1
    save(tmp,'checkpoint','-v7.3');
else
    save(tmp,'checkpoint','-v7');
end
movefile(tmp,fname,'f');
end

function researchXexperimentsXdelete_if_exists(f)
if exist(f,'file'), delete(f); end
end

function R=researchXexperimentsXbaselineStudy(cfg,stage)
R.snrDb=cfg.snrDb(:).';
R.theory=physical_core('modem_ofdm','qpsk_theory',R.snrDb).';
R.berAwgn=zeros(size(R.snrDb)); R.berStatic=zeros(size(R.snrDb)); R.berDoppler=zeros(size(R.snrDb));
R.errors=zeros(3,numel(R.snrDb)); R.bits=zeros(3,numel(R.snrDb)); R.ci=zeros(3,numel(R.snrDb));
F=cfg.framesBaseline; if strcmp(stage,'SMOKE'),F=2; elseif strcmp(stage,'FAST'),F=min(F,35); end
p=physical_core('channel_model','profile',cfg.profiles,cfg.activeProfile);
for si=1:numel(R.snrDb)
    for f=1:F
        bits=randi([0 1],cfg.N*cfg.bitsPerSym,1);
        [X,~]=physical_core('modem_ofdm','qammap',bits,cfg.M); [tx,~]=physical_core('modem_ofdm','ofdmtx',X,cfg.Ncp);
        nv=1/(cfg.N*cfg.bitsPerSym*10^(R.snrDb(si)/10));
        y=tx+sqrt(nv/2)*(randn(size(tx))+1j*randn(size(tx)));
        Y=physical_core('modem_ofdm','ofdmdemux',y,cfg.N,cfg.Ncp); bh=physical_core('modem_ofdm','qamdemap',Y,cfg.M);
        R.errors(1,si)=R.errors(1,si)+sum(bh~=bits); R.bits(1,si)=R.bits(1,si)+numel(bits);
        rs=RandStream('twister','Seed',cfg.jakesSeed+5000+f);
        staticPhase=exp(1j*2*pi*rand(rs,1,p.numPaths));
        hs=repmat(sqrt(p.powerLin(:)).'.*staticPhase,numel(tx),1);
        [ys,~]=physical_core('channel_model','apply',tx,p.delay,hs,cfg.fs,nv); Ys=physical_core('modem_ofdm','ofdmdemux',ys,cfg.N,cfg.Ncp);
        Hs=physical_core('channel_model','matrix',hs,p.delay,cfg.N,cfg.Ncp,cfg.fs); bh=physical_core('modem_ofdm','qamdemap',estimation_receiver('equalizers','mmse',Hs,Ys,nv),cfg.M);
        R.errors(2,si)=R.errors(2,si)+sum(bh~=bits); R.bits(2,si)=R.bits(2,si)+numel(bits);
        [ht,~]=physical_core('channel_model',cfg.channelModel,numel(tx),cfg.fd,cfg.fs,p.numPaths,cfg.jakesOsc,p.powerLin,cfg.jakesSeed+f,cfg.ricianKDb,cfg.raysPerCluster,cfg.angularSpreadDeg);
        [yd,~]=physical_core('channel_model','apply',tx,p.delay,ht,cfg.fs,nv); Yd=physical_core('modem_ofdm','ofdmdemux',yd,cfg.N,cfg.Ncp);
        Hd=physical_core('channel_model','matrix',ht,p.delay,cfg.N,cfg.Ncp,cfg.fs); bh=physical_core('modem_ofdm','qamdemap',estimation_receiver('equalizers','mmse',Hd,Yd,nv),cfg.M);
        R.errors(3,si)=R.errors(3,si)+sum(bh~=bits); R.bits(3,si)=R.bits(3,si)+numel(bits);
    end
end
R.berAwgn=R.errors(1,:)./max(R.bits(1,:),1); R.berStatic=R.errors(2,:)./max(R.bits(2,:),1); R.berDoppler=R.errors(3,:)./max(R.bits(3,:),1);
R.ci=researchXexperimentsXstatistics_ci(R.errors,R.bits,0.95);
R.zeroErrorUpperBound=-log(0.05)./max(R.bits,1);
R.resolutionNote='A reported BER of 0 means no observed errors. It is displayed as a one-sided 95% upper bound -log(0.05)/bits; points below that censoring limit are not measured BER values.';
R.snrDefinition='Eb/N0 referenced to useful OFDM symbol energy; CP overhead is excluded from the QPSK analytical baseline.';
R.staticChannelNote='Static and Doppler EVA references use perfect-CSI one-tap MMSE equalization; Doppler still contains unmodeled ICI. Independent per-path phases preserve the intended PDP power.';
end

function R=researchXexperimentsXestimationStudy(cfg,stage)
p=physical_core('channel_model','profile',cfg.profiles,cfg.activeProfile); N=cfg.N; R.snrDb=cfg.snrDb;
R.methods={'LS','DFT-LS','LMMSE','LMMSE-Pilot','Vector-Kalman'};
nM=numel(R.methods);
R.mse=zeros(nM,numel(R.snrDb)); R.nmse=zeros(nM,numel(R.snrDb));
R.msePilot=zeros(nM,numel(R.snrDb));
R.crlb=zeros(1,numel(R.snrDb)); R.classicalPilotCRLB=zeros(1,numel(R.snrDb)); R.runtimeMs=zeros(nM,numel(R.snrDb));
R.mseDiagonal=zeros(nM,numel(R.snrDb));
R.crlbDiagonal=zeros(1,numel(R.snrDb));
R.classicalPilotCRLBDiagonal=zeros(1,numel(R.snrDb));
R.iciPenaltyDb=zeros(nM,numel(R.snrDb));
F=cfg.framesEstimation; if strcmp(stage,'SMOKE'),F=2; elseif strcmp(stage,'FAST'),F=min(F,16); end
Rhh=physical_core('channel_model','cov',N,p.delay,p.powerLin,cfg.fs,cfg.delayModel,cfg.delayFilterHalfLength);
[pilotIdx,di,pv]=estimation_receiver('channel_estimation','pilot_grid',N,cfg.pilotSpacing(2),cfg.pilotValue);
for si=1:numel(R.snrDb)
    acc=zeros(nM,1); accN=zeros(nM,1); accP=zeros(nM,1); tacc=zeros(nM,1); noiseVar=0; Xp=pv;
    for f=1:F
        bits1=randi([0 1],numel(di)*cfg.bitsPerSym,1); bits2=randi([0 1],numel(di)*cfg.bitsPerSym,1);
        [D1,~]=physical_core('modem_ofdm','qammap',bits1,cfg.M); [D2,~]=physical_core('modem_ofdm','qammap',bits2,cfg.M);
        X1=zeros(N,1); X1(di)=D1; X1(pilotIdx)=pv; X2=zeros(N,1); X2(di)=D2; X2(pilotIdx)=pv;
        [tx1,~]=physical_core('modem_ofdm','ofdmtx',X1,cfg.Ncp); [tx2,~]=physical_core('modem_ofdm','ofdmtx',X2,cfg.Ncp); stream=[tx1;tx2];
        noiseVarTD=mean(abs(tx2).^2)/(10^(R.snrDb(si)/10)*cfg.bitsPerSym); noiseVarFD=cfg.N*noiseVarTD;
        [h,~]=physical_core('channel_model',cfg.channelModel,2*(N+cfg.Ncp),cfg.fd,cfg.fs,p.numPaths,cfg.jakesOsc,p.powerLin,cfg.jakesSeed+f,cfg.ricianKDb,cfg.raysPerCluster,cfg.angularSpreadDeg);
        [y,~]=physical_core('channel_model','apply',stream,p.delay,h,cfg.fs,noiseVarTD);
        y1=y(1:N+cfg.Ncp); y2=y(N+cfg.Ncp+1:2*(N+cfg.Ncp));
        Y1=physical_core('modem_ofdm','ofdmdemux',y1,N,cfg.Ncp); Y2=physical_core('modem_ofdm','ofdmdemux',y2,N,cfg.Ncp);
        h2=h(N+cfg.Ncp+1:2*(N+cfg.Ncp),:); H2=physical_core('channel_model','matrix',h2,p.delay,N,cfg.Ncp,cfg.fs); Htrue=diag(H2);
        tic; HlsPrev=estimation_receiver('channel_estimation','ls',Y1,X1,pilotIdx); Hls=estimation_receiver('channel_estimation','ls',Y2,X2,pilotIdx); tacc(1)=tacc(1)+toc;
        [~,tapGrid]=physical_core('channel_model','taps',p.delay,cfg.fs);
        maxTap=min(N,max(2,numel(tapGrid))); tic; Hd=estimation_receiver('channel_estimation','dft',Hls,maxTap); tacc(2)=tacc(2)+toc;
        pilotPower=mean(abs(X2(pilotIdx)).^2);
        tic; Hm=estimation_receiver('channel_estimation','lmmse',Hls,Rhh,pilotPower,noiseVarFD); tacc(3)=tacc(3)+toc;
        z=nan(N,1); z(pilotIdx)=Y2(pilotIdx)./X2(pilotIdx);
        tic; Hp=estimation_receiver('channel_estimation','lmmse_pilot',z(pilotIdx),pilotIdx,Rhh,pilotPower,noiseVarFD); tacc(4)=tacc(4)+toc;
        alphaArg = 2*pi*double(cfg.fd(1))*double(cfg.Tsym(1));
        alpha = double(besselj(0,alphaArg));

        a0 = alpha(1);
        assert(isscalar(a0) && isfinite(real(a0)) && isfinite(imag(a0)), ...
            'Kalman alpha must be a finite scalar.');
        qScale = max(1 - real(a0*conj(a0)), 1e-8);
        assert(isscalar(qScale) && isfinite(qScale), ...
            'Kalman process-noise scale must be a finite scalar.');
        Q = qScale .* Rhh;
        assert(isequal(size(Q),size(Rhh)), ...
            'Kalman process covariance Q must match R_HH dimensions.');
        rv=noiseVarFD./max(abs(X2(pilotIdx)).^2,eps);
        tic; [Hk,~,~]=estimation_receiver('channel_estimation','kalman',z,HlsPrev,Rhh,alpha,Q,rv); tacc(nM)=tacc(nM)+toc;
        ests={Hls,Hd,Hm,Hp,Hk};
        for k=1:nM
            e=mean(abs(ests{k}-Htrue).^2); en=e/max(mean(abs(Htrue).^2),eps); acc(k)=acc(k)+e; accN(k)=accN(k)+en;
            accP(k)=accP(k)+mean(abs(ests{k}(pilotIdx)-Htrue(pilotIdx)).^2);
        end
    end
    R.mse(:,si)=acc/F; R.nmse(:,si)=accN/F; R.msePilot(:,si)=accP/F; R.runtimeMs(:,si)=1000*tacc/F;

    accD=zeros(nM,1); noiseVarFDd=0;
    for f=1:F
        bitsD=randi([0 1],numel(di)*cfg.bitsPerSym,1);
        [DD,~]=physical_core('modem_ofdm','qammap',bitsD,cfg.M);
        XD=zeros(N,1); XD(di)=DD; XD(pilotIdx)=pv;
        [txD,~]=physical_core('modem_ofdm','ofdmtx',XD,cfg.Ncp);
        noiseVarTDD=mean(abs(txD).^2)/(10^(R.snrDb(si)/10)*cfg.bitsPerSym);
        noiseVarFDd=N*noiseVarTDD;
        [hD,~]=physical_core('channel_model',cfg.channelModel,numel(txD),0,cfg.fs,p.numPaths,cfg.jakesOsc,p.powerLin,cfg.jakesSeed+9100+f,cfg.ricianKDb,cfg.raysPerCluster,cfg.angularSpreadDeg);
        [yD,~]=physical_core('channel_model','apply',txD,p.delay,hD,cfg.fs,noiseVarTDD);
        YD=physical_core('modem_ofdm','ofdmdemux',yD,N,cfg.Ncp);
        HD=diag(physical_core('channel_model','matrix',hD,p.delay,N,cfg.Ncp,cfg.fs));
        HlsD=estimation_receiver('channel_estimation','ls',YD,XD,pilotIdx);
        [~,tapGridD]=physical_core('channel_model','taps',p.delay,cfg.fs,cfg.delayModel,cfg.delayFilterHalfLength);
        HdD=estimation_receiver('channel_estimation','dft',HlsD,min(N,max(2,numel(tapGridD))));
        pilotPowerD=mean(abs(XD(pilotIdx)).^2);
        HmD=estimation_receiver('channel_estimation','lmmse',HlsD,Rhh,pilotPowerD,noiseVarFDd);
        zD=YD(pilotIdx)./XD(pilotIdx);
        HpD=estimation_receiver('channel_estimation','lmmse_pilot',zD,pilotIdx,Rhh,pilotPowerD,noiseVarFDd);
        rvD=noiseVarFDd./max(abs(XD(pilotIdx)).^2,eps);
        QD=qScale.*Rhh;
        [HkD,~,~]=estimation_receiver('channel_estimation','kalman', ...
            zD,HpD,Rhh,alpha,QD,rvD);
        estD={HlsD,HdD,HmD,HpD,HkD};
        for k=1:nM, accD(k)=accD(k)+mean(abs(estD{k}-HD).^2); end
        if f==1
            R.crlbDiagonal(si)=mean(estimation_receiver('channel_estimation','bayes_crlb',pilotIdx,XD(pilotIdx),noiseVarFDd,Rhh,N));
            R.classicalPilotCRLBDiagonal(si)=mean(estimation_receiver('channel_estimation','crlb',XD(pilotIdx),noiseVarFDd));
        end
    end
    R.mseDiagonal(:,si)=accD/F;
    R.iciPenaltyDb(:,si)=10*log10(max(R.mse(:,si),eps)./max(R.mseDiagonal(:,si),eps));
    R.classicalPilotCRLB(si)=mean(estimation_receiver('channel_estimation','crlb',Xp,noiseVarFD));
    R.crlb(si)=mean(estimation_receiver('channel_estimation','bayes_crlb',pilotIdx,Xp,noiseVarFD,Rhh,N));
end
R.stateModel='Two-symbol vector Kalman: h_2 = alpha*h_1 + u, Q=(1-|alpha|^2)R_HH; observations are current-symbol pilot-normalized estimates.';
R.kalmanAlpha=alpha; R.kalmanQScale=qScale;
R.kalmanAlphaNote='alpha = J0(2*pi*fd*Tsym), a SCALAR. In V5.3 the built-in pi was shadowed by the pilot index vector at this line, so alpha became J0(2*pilotIdx*fd*Tsym) and the process noise was under-estimated ~10x.';
R.diagonalNote='mseDiagonal is the same estimator family evaluated on a Doppler-free channel, matching the diagonal Gaussian pilot model used by the posterior CRLB. iciPenaltyDb compares the real doubly-dispersive production MSE to that ICI-free reference.';
assert(isscalar(R.kalmanAlpha),'Kalman alpha must be scalar; a vector indicates pi is shadowed again.');
R.crlbDefinition=['The Bayesian posterior bound applies to the diagonal linear-Gaussian pilot model z_p=h_p+v_p/X_p with ' ...
    'the channel covariance Rhh. The production estimation sweep is doubly dispersive, so raw pilot tones also contain ICI; ' ...
    'the diagonal bound is retained as a theoretical reference but is NOT asserted as an exact bound for the Doppler sweep. ' ...
    'The classical pilot variance sigma_w^2/|Xp|^2 likewise applies to the raw diagonal pilot observation model only.'];
R.noiseConvention=['Noise is generated in the time domain with variance noiseVarTD. The unnormalised N-point FFT ' ...
    'in the receiver inflates it to noiseVarFD = N*noiseVarTD in the frequency domain, and that is the value handed ' ...
    'to every frequency-domain estimator, equalizer and bound.'];
end

function R=researchXexperimentsXiciStudy(cfg,stage)
R.fdTu=cfg.iciFdTuGrid; R.sim=zeros(size(R.fdTu)); R.dopplerSecondMomentRatio=cfg.dopplerSecondMomentRatio;
R.theory=estimation_receiver('ici_model','theory',R.fdTu,cfg.dopplerSecondMomentRatio);
R.theoryWorstCase=estimation_receiver('ici_model','theory',R.fdTu,1.0);
R.theoryJakes=estimation_receiver('ici_model','theory',R.fdTu,cfg.dopplerJakesRatio);
R.theoryNote=['Two bracketing small-Doppler asymptotes are reported: Jakes ' ...
    '(E[nu^2]=fd^2/2) and worst case (E[nu^2]=fd^2). The clustered generator lies ' ...
    'between them; R.impliedSecondMomentRatio records where this run actually fell. ' ...
    'No claim is made that the simulation matches either curve exactly.'];
R.theoryNote=['Reference is P_ICI = (pi^2/3)*(E[nu^2]/fd^2)*(fdTu)^2. With uniformly ' ...
    'distributed cluster arrival angles E[nu^2]/fd^2 = 1/2 (the classical Jakes value), ' ...
    'giving (pi^2/6)(fdTu)^2. theoryWorstCase is the commonly quoted (pi^2/3)(fdTu)^2, ' ...
    'which assumes all Doppler energy sits at +/-fd.']; R.ratioDb=zeros(size(R.fdTu));
R.band99=zeros(size(R.fdTu)); R.band999=zeros(size(R.fdTu)); R.bemOrders=cfg.bemOrders; R.bemMSE=zeros(1,numel(R.bemOrders)); R.bemFreqNMSE=zeros(1,numel(R.bemOrders)); R.selfCancelSuppressionDb=zeros(size(R.fdTu)); R.selfCancelRateLoss=0.5;
F=cfg.framesICI; if strcmp(stage,'SMOKE'),F=2; elseif strcmp(stage,'FAST'),F=min(F,8); end
p=physical_core('channel_model','profile',cfg.profiles,cfg.activeProfile);
for i=1:numel(R.fdTu)
    fd=R.fdTu(i)*cfg.deltaF; pICI=0; pD=0; b99=0; b999=0;
    for f=1:F
        [h,~]=physical_core('channel_model',cfg.channelModel,cfg.N+cfg.Ncp,fd,cfg.fs,p.numPaths,cfg.jakesOsc,p.powerLin,cfg.jakesSeed+i+f,cfg.ricianKDb,cfg.raysPerCluster,cfg.angularSpreadDeg);
        H=physical_core('channel_model','matrix',h,p.delay,cfg.N,cfg.Ncp,cfg.fs); [d,ic,~]=estimation_receiver('ici_model','metrics',H);
        pD=pD+d; pICI=pICI+ic; b99=b99+estimation_receiver('ici_model','band',H,0.99); b999=b999+estimation_receiver('ici_model','band',H,0.999);
    end
    R.sim(i)=pICI/F; R.ratioDb(i)=10*log10(max(R.sim(i),eps)/max(pD/F,eps)); R.band99(i)=b99/F; R.band999(i)=b999/F;
    H0=physical_core('channel_model','matrix',physical_core('channel_model',cfg.channelModel,cfg.N+cfg.Ncp,fd,cfg.fs,p.numPaths,cfg.jakesOsc,p.powerLin,cfg.jakesSeed+900+i,cfg.ricianKDb,cfg.raysPerCluster,cfg.angularSpreadDeg),p.delay,cfg.N,cfg.Ncp,cfg.fs);
    [b0,a0,~,~]=estimation_receiver('ici_model','cancel_metrics',H0); R.selfCancelSuppressionDb(i)=b0-a0;
end
Fb=max(8,min(cfg.framesICI,40)); if strcmp(stage,'SMOKE'), Fb=2; elseif strcmp(stage,'FAST'), Fb=min(Fb,8); end
accTap=zeros(1,numel(R.bemOrders)); accFreq=zeros(1,numel(R.bemOrders));
for fb=1:Fb
    [h,~]=physical_core('channel_model',cfg.channelModel,cfg.N+cfg.Ncp,cfg.fd,cfg.fs,p.numPaths,cfg.jakesOsc,p.powerLin,cfg.jakesSeed+3300+fb,cfg.ricianKDb,cfg.raysPerCluster,cfg.angularSpreadDeg);
    Htrue=physical_core('channel_model','matrix',h,p.delay,cfg.N,cfg.Ncp,cfg.fs);
    denFreq=max(mean(abs(Htrue(:)).^2),eps);
    for q=1:numel(R.bemOrders)
        [hhat,~,nmseTap]=estimation_receiver('ici_model','bem',h,R.bemOrders(q));
        Hbem=physical_core('channel_model','matrix',hhat,p.delay,cfg.N,cfg.Ncp,cfg.fs);
        accTap(q)=accTap(q)+mean(nmseTap(:));
        accFreq(q)=accFreq(q)+mean(abs(Htrue(:)-Hbem(:)).^2)/denFreq;
    end
end
R.bemMSE=accTap/Fb; R.bemFreqNMSE=accFreq/Fb; R.bemFrames=Fb;
R.bemMonotoneNote='Orders share each realization, so the tap-domain fit error is monotone non-increasing in Q by construction (nested bases).';
R.impliedSecondMomentRatio=mean(R.sim(R.fdTu<=0.02)./max(estimation_receiver('ici_model','theory',R.fdTu(R.fdTu<=0.02),1.0),eps));
R.bemTheory='CE-BEM approximation is quantified both in tap-time NMSE and induced frequency-domain channel-matrix NMSE.';
end

function R=researchXexperimentsXequalizerStudy(cfg,stage)
R.snrDb=[0 8 16 24 30]; R.bands=cfg.iciBands; R.labels={'ZF','Full-MMSE','PCG-MMSE','PIC','BEM-MMSE'};
R.labels=[R.labels,arrayfun(@(b)sprintf('B%d',b),R.bands,'UniformOutput',false)];
R.fdTuGrid=cfg.equalizerFdTuGrid;
nL=numel(R.labels); nS=numel(R.snrDb); nF=numel(R.fdTuGrid);
R.berByFdTu=zeros(nL,nS,nF); R.runtimeByFdTu=zeros(nL,nS,nF); R.bitsPerPoint=zeros(1,nF);
R.pcgRelResidual=zeros(nS,nF); R.pcgIterationsUsed=zeros(nS,nF); R.pcgConverged=false(nS,nF);
F=cfg.framesICI; if strcmp(stage,'SMOKE'),F=2; elseif strcmp(stage,'FAST'),F=min(F,10); end
p=physical_core('channel_model','profile',cfg.profiles,cfg.activeProfile);
Q=min(4,max(cfg.bemOrders)); bemHalfBand=Q;
for di=1:nF
    fd=R.fdTuGrid(di)*cfg.deltaF;
    for si=1:nS
        err=zeros(nL,1); times=zeros(nL,1); nbits=0; pcgRes=0; pcgIt=0; pcgConv=0;
        for f=1:F
            bits=randi([0 1],cfg.N*cfg.bitsPerSym,1); [X,~]=physical_core('modem_ofdm','qammap',bits,cfg.M); [tx,~]=physical_core('modem_ofdm','ofdmtx',X,cfg.Ncp);
            [h,~]=physical_core('channel_model',cfg.channelModel,numel(tx),fd,cfg.fs,p.numPaths,cfg.jakesOsc,p.powerLin,cfg.jakesSeed+100*di+f,cfg.ricianKDb,cfg.raysPerCluster,cfg.angularSpreadDeg);
            nvTD=mean(abs(tx).^2)/(10^(R.snrDb(si)/10)*cfg.bitsPerSym); nvFD=cfg.N*nvTD;
            [y,~]=physical_core('channel_model','apply',tx,p.delay,h,cfg.fs,nvTD); Y=physical_core('modem_ofdm','ofdmdemux',y,cfg.N,cfg.Ncp);
            H=physical_core('channel_model','matrix',h,p.delay,cfg.N,cfg.Ncp,cfg.fs);
            [Hb,~,~]=estimation_receiver('ici_model','bem_matrix',h,p.delay,cfg.N,cfg.Ncp,cfg.fs,Q);
            detectorList={{'zf'},{'mmse'},{'pcg_mmse',20,1e-6},{'pic',4},{'bem_mmse'}, ...
                {'banded',cfg.iciBands(1)},{'banded',cfg.iciBands(2)},{'banded',cfg.iciBands(3)}, ...
                {'banded',cfg.iciBands(4)},{'banded',cfg.iciBands(5)},{'banded',cfg.iciBands(6)}};
            for k=1:numel(detectorList)
                tic;
                if strcmp(detectorList{k}{1},'bem_mmse')
                    xhat=estimation_receiver('equalizers','bem_mmse',Hb,Y,nvFD,bemHalfBand);
                elseif strcmp(detectorList{k}{1},'pcg_mmse')
                    [xhat,pcgInfo]=estimation_receiver('equalizers','pcg_mmse',H,Y,nvFD,detectorList{k}{2},detectorList{k}{3});
                    pcgRes=pcgRes+pcgInfo.relResidual; pcgIt=pcgIt+pcgInfo.iterations; pcgConv=pcgConv+double(pcgInfo.converged);
                elseif numel(detectorList{k})==2
                    xhat=estimation_receiver('equalizers',detectorList{k}{1},H,Y,nvFD,detectorList{k}{2});
                else
                    xhat=estimation_receiver('equalizers',detectorList{k}{1},H,Y,nvFD);
                end
                times(k)=times(k)+toc*1000;
                bh=physical_core('modem_ofdm','qamdemap',xhat,cfg.M); err(k)=err(k)+sum(bh~=bits);
            end
            nbits=nbits+numel(bits);
        end
        R.berByFdTu(:,si,di)=err/max(nbits,1); R.runtimeByFdTu(:,si,di)=times/F;
        R.bitsPerPoint(di)=nbits;
        R.pcgRelResidual(si,di)=pcgRes/F; R.pcgIterationsUsed(si,di)=pcgIt/F; R.pcgConverged(si,di)=(pcgConv==F);
    end
end
[~,iNom]=min(abs(R.fdTuGrid-cfg.fdTuNominal));
R.nominalIndex=iNom; R.ber=R.berByFdTu(:,:,iNom); R.runtimeMs=R.runtimeByFdTu(:,:,iNom);
[~,iHigh]=max(R.fdTuGrid); R.highDopplerIndex=iHigh;
R.berHighDoppler=R.berByFdTu(:,:,iHigh); R.fdTuHigh=R.fdTuGrid(iHigh);
R.zeroErrorUpperBound=-log(0.05)./max(R.bitsPerPoint,1);
R.numericalNote='Measured runtime is averaged per equalizer call; analytical FLOP estimates are stored separately. BER differences below the one-sided 95% zero-error upper bound -log(0.05)/bitsPerPoint are not resolved.';
R.bemOrder=Q; R.bemHalfBand=bemHalfBand; R.pcgIterations=20; R.pcgTolerance=1e-6;
R.pcgNote=['PCG-MMSE is a TRUNCATED conjugate-gradient solve of the exact MMSE normal equations. ' ...
    'pcgRelResidual records how far from the exact solution it actually stopped. Where it has not ' ...
    'converged, early termination regularises an ill-conditioned ICI matrix and the receiver can ' ...
    'therefore beat the exact full-MMSE solve; it must not be described as solving the exact objective.'];
end

function R=researchXexperimentsXotfsStudy(cfg,stage)
N=cfg.otfsDetectorN; M=cfg.otfsDetectorM; R.snrDb=0:4:24; R.frac=cfg.fractionalDoppler;
R.gridNote=sprintf(['Detector comparison on a synthetic %dx%d DD channel. The grid is a free ' ...
    'parameter here because the path delays and Dopplers are specified directly; the physical ' ...
    '%dx%d frame is used by the cross-waveform study, where a real Doppler must be resolved.'], ...
    N,M,cfg.otfsN,cfg.otfsM);
R.berMF=zeros(numel(R.frac),numel(R.snrDb)); R.berMMSE=R.berMF; R.berMP=R.berMF; R.berGS=R.berMF;
R.integerAnchor=zeros(size(R.frac)); F=cfg.framesOTFS; if strcmp(stage,'SMOKE'),F=1; elseif strcmp(stage,'FAST'),F=min(F,5); end
for fi=1:numel(R.frac)
    for si=1:numel(R.snrDb)
        eMF=0;eMM=0;eMP=0;eGS=0;nb=0;
        for f=1:F
            bits=randi([0 1],N*M*2,1); [s,~]=physical_core('modem_ofdm','qammap',bits,4); Xdd=reshape(s,N,M);
            paths(1)=struct('delayBin',2,'dopplerBin',3,'fracDoppler',R.frac(fi),'gain',1/sqrt(2));
            paths(2)=struct('delayBin',5,'dopplerBin',-2,'fracDoppler',-0.5*R.frac(fi),'gain',1/sqrt(2));
            nv=mean(abs(Xdd(:)).^2)/(10^(R.snrDb(si)/10)*2);
            Ydd=otfs_core('otfs_system','dd_channel',Xdd,paths,nv); Hdd=otfs_core('otfs_system','dd_matrix',paths,N,M);
            thr=1e-4*max(abs(Hdd(:)));
            xmf=otfs_core('otfs_detector','mf',Ydd(:),Hdd,nv);
            xmm=otfs_core('otfs_detector','mmse',Ydd(:),Hdd,nv);
            xmp=otfs_core('otfs_detector','mp',Ydd(:),Hdd,nv,cfg.otfsIterations,thr,cfg.otfsDamping);
            xgs=otfs_core('otfs_detector','gs',Ydd(:),Hdd,nv,cfg.otfsIterations,thr);
            eMF=eMF+sum(physical_core('modem_ofdm','qamdemap',xmf,4)~=bits);
            eMM=eMM+sum(physical_core('modem_ofdm','qamdemap',xmm,4)~=bits);
            eMP=eMP+sum(physical_core('modem_ofdm','qamdemap',xmp,4)~=bits);
            eGS=eGS+sum(physical_core('modem_ofdm','qamdemap',xgs,4)~=bits); nb=nb+numel(bits);
        end
        R.berMF(fi,si)=eMF/max(nb,1); R.berMMSE(fi,si)=eMM/max(nb,1); R.berMP(fi,si)=eMP/max(nb,1); R.berGS(fi,si)=eGS/max(nb,1); R.bitsPerPoint=nb;
    end
    R.integerAnchor(fi)=abs(R.frac(fi))<eps;
end
R.waveform=otfs_core('otfs_system','tx',reshape(physical_core('modem_ofdm','qammap',randi([0 1],N*M*2,1),4),N,M),cfg.otfsNcp);
R.detectors={'MF','MMSE','MP','GS'};
R.validation=['Detectors share the exact DD operator that generated the received signal. ' ...
    'MP is an alphabet-marginalised sparse-graph approximation; GS is the legacy damped ' ...
    'Gauss-Seidel interference canceller, retained only as a low-complexity reference.'];
R.zeroErrorUpperBound=-log(0.05)/max(R.bitsPerPoint,1);
R.sparsityNote=['ddDensity per Doppler point. Fractional Doppler (fd below one Doppler bin) ' ...
    'spreads every path across the Doppler axis and destroys the sparsity message passing needs; ' ...
    'the time-domain operator stays sparse regardless (Li/Yuan/Wei/Yuan, IEEE TWC 2022). ' ...
    'A large ddDensity means the OTFS result is detector-limited, not waveform-limited.'];
end


function R=researchXexperimentsXcrosswaveformStudy(cfg,stage)

R.fdTu=[0.01 0.05 0.10 0.20];
R.snrDb=0:4:24;
R.subcarrierSpacingHz=cfg.deltaF;
R.fdHz=R.fdTu*R.subcarrierSpacingHz;
R.symbolDurationUs=cfg.Tu*1e6;
R.crosswaveformDefinition='f_D T_u with T_u=1/Delta-f; OFDM and OTFS use equal information-symbol count and equal waveform duration.';

R.berOFDM=zeros(numel(R.fdTu),numel(R.snrDb));
R.berOTFS=zeros(size(R.berOFDM));       % matched PCG-MMSE curves
R.berOTFS_MP=zeros(size(R.berOFDM));    % secondary approximate reference
R.crossoverSNR=nan(size(R.fdTu));
R.pcgIterations=25;
R.pcgTolerance=1e-6;
R.ofdmReceiver='PCG-MMSE (25 iterations, tol=1e-6)';
R.otfsReceiver='PCG-MMSE (25 iterations, tol=1e-6)';
R.receiverMatched=true;

switch upper(stage)
    case 'SMOKE', F=1;
    case 'FAST',  F=4;
    case 'AUDIT', F=cfg.crosswaveformFramesAudit;
    case 'FULL', F=cfg.crosswaveformFramesFull;
    otherwise, F=cfg.crosswaveformFramesFull;
end

Ndd=cfg.otfsN; Mdd=cfg.otfsM;
Nofdm=cfg.N; cpOFDM=cfg.Ncp; cpOTFS=cfg.otfsNcp;
p=physical_core('channel_model','profile',cfg.profiles,cfg.activeProfile);
Linfo=Ndd*Mdd;
assert(mod(Linfo,Nofdm)==0,'OTFS information-symbol budget must be divisible by OFDM N.');
Mofdm=Linfo/Nofdm;
lenOFDM=Mofdm*(Nofdm+cpOFDM);
lenOTFS=Mdd*(Ndd+cpOTFS);
assert(lenOFDM==lenOTFS,'Controlled OFDM/OTFS comparison must use equal waveform duration.');
N=Nofdm; M=Mofdm;

R.bitsPerPoint=F*Linfo*cfg.bitsPerSym;
R.confidenceLevel=0.95;
R.zeroErrorUpperBound=-log(1-R.confidenceLevel)/max(R.bitsPerPoint,1);
R.sparsity=repmat(struct('ddNnzPerCol',NaN,'ddDensity',NaN,'timeNnzPerCol',NaN,'timeDensity',NaN,'tolerance',NaN,'note',''),size(R.fdTu));
R.pcgResidualOFDM=zeros(size(R.berOFDM)); R.pcgResidualOTFS=zeros(size(R.berOTFS)); R.pcgConvergedOFDM=false(size(R.berOFDM)); R.pcgConvergedOTFS=false(size(R.berOTFS));
R.errorsOFDM=zeros(size(R.berOFDM)); R.errorsOTFS=zeros(size(R.berOTFS)); R.pairOOnly=zeros(size(R.berOFDM)); R.pairTOnly=zeros(size(R.berOTFS));

for fi=1:numel(R.fdTu)
    fd=R.fdHz(fi);
    eO=zeros(size(R.snrDb)); eT=zeros(size(R.snrDb)); eTMP=zeros(size(R.snrDb)); nb=0; nbMP=0; pairOOnly=zeros(size(R.snrDb)); pairTOnly=zeros(size(R.snrDb));
    for f=1:F
        [h,~]=physical_core('channel_model',cfg.channelModel,lenOFDM,fd,cfg.fs,p.numPaths,...
            cfg.jakesOsc,p.powerLin,cfg.jakesSeed+7000+10*fi+f,cfg.ricianKDb,...
            cfg.raysPerCluster,cfg.angularSpreadDeg);

        bitsO=randi([0 1],Linfo*cfg.bitsPerSym,1);
        bitsT=bitsO;
        [sO,~]=physical_core('modem_ofdm','qammap',bitsO,cfg.M);
        XO=reshape(sO,Nofdm,Mofdm);
        txO=zeros(Nofdm+cpOFDM,Mofdm); HfAll=cell(Mofdm,1);
        for m=1:Mofdm
            [txO(:,m),~]=physical_core('modem_ofdm','ofdmtx',XO(:,m),cpOFDM);
            idx=(m-1)*(Nofdm+cpOFDM)+(1:(Nofdm+cpOFDM));
            HfAll{m}=physical_core('channel_model','matrix',h(idx,:),p.delay,Nofdm,cpOFDM,cfg.fs);
        end
        txOvec=txO(:);
        EbOFDM=sum(abs(txOvec).^2)/numel(bitsO);
        for si=1:numel(R.snrDb)
            nvTD=EbOFDM/(10^(R.snrDb(si)/10));
            nvFD=N*nvTD; % unnormalised OFDM FFT scales noise variance by N
            [yO,~]=physical_core('channel_model','apply',txOvec,p.delay,h(1:lenOFDM,:),cfg.fs,nvTD);
            bhat=false(numel(bitsO),1);
            for m=1:Mofdm
                idx=(m-1)*(Nofdm+cpOFDM)+(1:(Nofdm+cpOFDM));
                YO=physical_core('modem_ofdm','ofdmdemux',yO(idx),Nofdm,cpOFDM);
                [xO,infoO]=estimation_receiver('equalizers','pcg_mmse',HfAll{m},YO,nvFD,R.pcgIterations,R.pcgTolerance);
                if isstruct(infoO)
                    if isfield(infoO,'relResidual'), R.pcgResidualOFDM(fi,si)=max(R.pcgResidualOFDM(fi,si),double(infoO.relResidual)); end
                    if isfield(infoO,'converged'), R.pcgConvergedOFDM(fi,si)=R.pcgConvergedOFDM(fi,si)||logical(infoO.converged); end
                end
                br=(m-1)*Nofdm*cfg.bitsPerSym+(1:Nofdm*cfg.bitsPerSym);
                bhat(br)=physical_core('modem_ofdm','qamdemap',xO,cfg.M);
            end
            errO=(bhat~=bitsO); eO(si)=eO(si)+sum(errO);
        end
        nb=nb+numel(bitsO);

        [sT,~]=physical_core('modem_ofdm','qammap',bitsT,cfg.M);
        XT=reshape(sT,Ndd,Mdd);
        [Hdd,~]=otfs_core('otfs_system','effective_dd_matrix',h,p.delay,Ndd,Mdd,cpOTFS,cfg.fs);
        if f==1
            R.sparsity(fi)=otfs_core('otfs_system','sparsity_diagnostic',Hdd,[]);
        end
        runMP = isfinite(R.sparsity(fi).ddDensity) && R.sparsity(fi).ddDensity < 0.15;
        txT=otfs_core('otfs_system','tx',XT,cpOTFS);
        EbOTFS=sum(abs(txT).^2)/numel(bitsT);
        for si=1:numel(R.snrDb)
            nv=EbOTFS/(10^(R.snrDb(si)/10));
            [yT,~]=physical_core('channel_model','apply',txT,p.delay,h(1:lenOTFS,:),cfg.fs,nv);
            YT=otfs_core('otfs_system','rx',yT,Ndd,Mdd,cpOTFS);

            [xT,infoT]=estimation_receiver('equalizers','pcg_mmse',Hdd,YT(:),nv,R.pcgIterations,R.pcgTolerance);
            if isstruct(infoT)
                if isfield(infoT,'relResidual'), R.pcgResidualOTFS(fi,si)=max(R.pcgResidualOTFS(fi,si),double(infoT.relResidual)); end
                if isfield(infoT,'converged'), R.pcgConvergedOTFS(fi,si)=R.pcgConvergedOTFS(fi,si)||logical(infoT.converged); end
            end
            bhatT=physical_core('modem_ofdm','qamdemap',xT,cfg.M); errT=(bhatT~=bitsT); eT(si)=eT(si)+sum(errT);
            pairOOnly(si)=pairOOnly(si)+sum(errO & ~errT); pairTOnly(si)=pairTOnly(si)+sum(errT & ~errO);

            if runMP
                xTMP=otfs_core('otfs_detector','mp',YT(:),Hdd,nv,cfg.otfsIterations,...
                    1e-4*max(abs(Hdd(:))),cfg.otfsDamping);
                eTMP(si)=eTMP(si)+sum(physical_core('modem_ofdm','qamdemap',xTMP,cfg.M)~=bitsT);
            end
        end
    end

    R.errorsOFDM(fi,:)=eO; R.errorsOTFS(fi,:)=eT; R.pairOOnly(fi,:)=pairOOnly; R.pairTOnly(fi,:)=pairTOnly;
    R.berOFDM(fi,:)=eO/max(nb,1);
    R.berOTFS(fi,:)=eT/max(nb,1);
    if runMP
        nbMP=nb;
        R.berOTFS_MP(fi,:)=eTMP/max(nbMP,1);
    else
        R.berOTFS_MP(fi,:)=NaN(size(eTMP));
    end
    w=find(R.berOTFS(fi,:)<R.berOFDM(fi,:),1,'first');
    if ~isempty(w), R.crossoverSNR(fi)=R.snrDb(w); end
end

R.ciOFDM=researchXexperimentsXstatistics_ci(R.errorsOFDM,R.bitsPerPoint*ones(size(R.errorsOFDM)),R.confidenceLevel);
R.ciOTFS=researchXexperimentsXstatistics_ci(R.errorsOTFS,R.bitsPerPoint*ones(size(R.errorsOTFS)),R.confidenceLevel);
R.deltaBER=(R.errorsOTFS-R.errorsOFDM)/max(R.bitsPerPoint,1);
R.mcnemarP=ones(size(R.deltaBER)); R.mcnemarPExact=ones(size(R.deltaBER)); nPair=R.pairOOnly+R.pairTOnly; use=nPair>0; chi=((abs(R.pairOOnly-R.pairTOnly)-1).^2)./max(nPair,1); R.mcnemarP(use)=erfc(sqrt(max(chi(use),0)/2));
for ii=find(use(:)).'
    ndisc=nPair(ii); k=min(R.pairOOnly(ii),R.pairTOnly(ii)); j=(0:k).';
    logpmf=gammaln(ndisc+1)-gammaln(j+1)-gammaln(ndisc-j+1)-ndisc*log(2);
    R.mcnemarPExact(ii)=min(1,2*sum(exp(logpmf)));
end
R.primaryEndpoint.fdTu=0.10; R.primaryEndpoint.snrDb=20; R.primaryEndpoint.description='Release-designated primary endpoint: paired OFDM-vs-OTFS comparison at f_D T_u=0.10 and E_b/N_0=20 dB using the matched PCG-MMSE receiver and perfect CSI.';
fi0=find(abs(R.fdTu-R.primaryEndpoint.fdTu)<1e-12,1); si0=find(abs(R.snrDb-R.primaryEndpoint.snrDb)<1e-12,1);
if ~isempty(fi0)&&~isempty(si0)
    R.primaryEndpoint.errorsOFDM=R.errorsOFDM(fi0,si0); R.primaryEndpoint.errorsOTFS=R.errorsOTFS(fi0,si0);
    R.primaryEndpoint.bits=R.bitsPerPoint; R.primaryEndpoint.berOFDM=R.berOFDM(fi0,si0); R.primaryEndpoint.berOTFS=R.berOTFS(fi0,si0);
    R.primaryEndpoint.ciOFDM=R.ciOFDM.low(fi0,si0) + [0 1]*(R.ciOFDM.high(fi0,si0)-R.ciOFDM.low(fi0,si0));
    R.primaryEndpoint.ciOTFS=R.ciOTFS.low(fi0,si0) + [0 1]*(R.ciOTFS.high(fi0,si0)-R.ciOTFS.low(fi0,si0));
    R.primaryEndpoint.pMcNemarExact=R.mcnemarPExact(fi0,si0);
    R.primaryEndpoint.pairOOnly=R.pairOOnly(fi0,si0); R.primaryEndpoint.pairTOnly=R.pairTOnly(fi0,si0);
    R.primaryEndpoint.zeroErrorUpperBound=-log(1-R.confidenceLevel)/R.bitsPerPoint;
end
R.pairedData=true;
R.diversityOFDM=researchXexperimentsXdiversitySlope(R.snrDb,R.berOFDM,R.zeroErrorUpperBound);
R.diversityOTFS=researchXexperimentsXdiversitySlope(R.snrDb,R.berOTFS,R.zeroErrorUpperBound);
R.diversityOTFS_MP=researchXexperimentsXdiversitySlope(R.snrDb,R.berOTFS_MP,R.zeroErrorUpperBound);
R.berOTFSBest=R.berOTFS;
mpMask=isfinite(R.berOTFS_MP);
R.berOTFSBest(mpMask)=min(R.berOTFS(mpMask),R.berOTFS_MP(mpMask));

R.diversityNote=['Diversity slopes are descriptive only and are fitted from the MATCHED-PCG curves. ' ...
    'No automatic claim is made that OTFS must have a larger measured slope; finite-frame, ' ...
    'channel-resolution, convergence, and channel-model effects can change the empirical slope.'];

R.cpOFDM=cpOFDM; R.cpOTFS=cpOTFS;
R.Nofdm=Nofdm; R.Mofdm=Mofdm; R.Ndd=Ndd; R.Mdd=Mdd;
R.infoSymbolsPerFrame=Linfo;
R.waveformDurationSamples=lenOFDM;
R.ofdmSymbolsPerFrame=Mofdm; R.otfsSymbolsPerFrame=Mdd;
R.methodNote=['Controlled comparison uses the same physical channel realization, equal information-symbol/bit budget, ' ...
    'equal total waveform duration, and the same PCG-MMSE detector (25 iterations, tol=1e-6). ' ...
    'Eb/N0 is based on the actual CP-inclusive transmitted waveform energy per information bit for both waveforms. ' ...
    'The OTFS message-passing curve is an approximate secondary reference only.'];
R.claimability='Claim scope: matched truncated PCG-MMSE with perfect CSI, fixed 25-frame AUDIT ensemble with paired information bits, equal information bits and equal waveform duration. Zero-error points are reported as upper bounds; no diversity-order claim is made.';
R.channelProfile=cfg.activeProfile;
R.snrDefinition='Measured CP-inclusive transmitted waveform energy per information bit, identical convention for OFDM and OTFS.';
R.dopplerDefinition=sprintf(['f_D T_u uses the useful-symbol duration of the physical OFDM symbol ' ...
    '(N=%d, fs=%.3f MHz, Delta-f=%.1f kHz, T_u=%.3f us). ' ...
    'The matched OTFS frame has Ndd=%d, Mdd=%d and CP=%d; its total duration equals %d OFDM symbols.'], ...
    Nofdm,cfg.fs/1e6,R.subcarrierSpacingHz/1e3,R.symbolDurationUs,Ndd,Mdd,cpOTFS,Mofdm);
end

function R=researchXexperimentsXpilotOptimizationStudy(cfg,stage)
p=physical_core('channel_model','profile',cfg.profiles,cfg.activeProfile); N=cfg.N; R.spacing=cfg.pilotSweep; R.snrDb=cfg.pilotOptimizationSNR; R.mse=zeros(4,numel(R.spacing)); R.overhead=1./R.spacing;
R.freqNyquistBound=1/(2*max(p.delay)*cfg.deltaF); R.timeNyquistBound=1/(2*cfg.fd*cfg.Tsym);
F=max(4,min(cfg.framesEstimation,20)); if strcmp(stage,'SMOKE'),F=2; elseif strcmp(stage,'FAST'),F=min(F,8); end
for si=1:numel(R.spacing)
    [pilotIdx,di,pv]=estimation_receiver('channel_estimation','pilot_grid',N,R.spacing(si),cfg.pilotValue); acc=zeros(4,1);
    for f=1:F
        bits=randi([0 1],numel(di)*cfg.bitsPerSym,1); [D,~]=physical_core('modem_ofdm','qammap',bits,cfg.M); X=zeros(N,1); X(di)=D; X(pilotIdx)=pv; [tx,~]=physical_core('modem_ofdm','ofdmtx',X,cfg.Ncp);
        nvTD=mean(abs(tx).^2)/(10^(R.snrDb/10)*cfg.bitsPerSym); nvFD=cfg.N*nvTD; [h,~]=physical_core('channel_model',cfg.channelModel,N+cfg.Ncp,cfg.fd,cfg.fs,p.numPaths,cfg.jakesOsc,p.powerLin,cfg.jakesSeed+f,cfg.ricianKDb,cfg.raysPerCluster,cfg.angularSpreadDeg);
        [y,~]=physical_core('channel_model','apply',tx,p.delay,h,cfg.fs,nvTD); Y=physical_core('modem_ofdm','ofdmdemux',y,N,cfg.Ncp); Htrue=diag(physical_core('channel_model','matrix',h,p.delay,N,cfg.Ncp,cfg.fs));
        Hls=estimation_receiver('channel_estimation','ls',Y,X,pilotIdx); Rhh=physical_core('channel_model','cov',N,p.delay,p.powerLin,cfg.fs,cfg.delayModel,cfg.delayFilterHalfLength); Hm=estimation_receiver('channel_estimation','lmmse',Hls,Rhh,mean(abs(X).^2),nvFD); z=nan(N,1);z(pilotIdx)=Y(pilotIdx)./X(pilotIdx);alphaRaw=besselj(0,2*pi*double(cfg.fd(1))*double(cfg.Tsym(1))); alpha=double(alphaRaw(1)); alphaPow=real(alpha*conj(alpha)); qScale=max(1-alphaPow,1e-8); Q=qScale.*Rhh; rv=nvFD./max(abs(X(pilotIdx)).^2,eps); Hk=estimation_receiver('channel_estimation','kalman',z,Hls,Rhh,alpha,Q,rv);
        [~,tapGrid]=physical_core('channel_model','taps',p.delay,cfg.fs);
        acc=acc+[mean(abs(Hls-Htrue).^2);mean(abs(Hm-Htrue).^2);mean(abs(Hk-Htrue).^2);mean(abs(estimation_receiver('channel_estimation','dft',Hls,max(2,numel(tapGrid)))-Htrue).^2)];
    end
    R.mse(:,si)=acc/F;
end
R.boundaryText='Frequency pilot spacing bound: Delta k <= 1/(2 tau_max Delta f). Time pilot spacing bound: Delta m <= 1/(2 f_D T_sym). These are the 2-D sampling limits used as design-reference lines, not empirical fits.';
end

function R=researchXexperimentsXsystemStudy(cfg,stage)
R.QAM=cfg.modulationSweep; Nvals=[64 128 256 512]; R.Nvals=Nvals; R.papr99=zeros(numel(R.QAM),numel(Nvals)); R.spectralEfficiency=zeros(numel(R.QAM),numel(Nvals));
frames=max(100,min(2000,cfg.framesSystem*10));
for mi=1:numel(R.QAM)
    M=R.QAM(mi); k=log2(M);
    for ni=1:numel(Nvals)
        N=Nvals(ni); paprAll=zeros(frames,1);
        for f=1:frames
            bits=randi([0 1],N*k,1); [X,~]=physical_core('modem_ofdm','qammap',bits,M); x=ifft(X,N); paprAll(f)=10*log10(max(abs(x).^2)/mean(abs(x).^2));
        end
        R.papr99(mi,ni)=prctile(paprAll,99);
        R.spectralEfficiency(mi,ni)=log2(M)*(1-cfg.Ncp/(N+cfg.Ncp));
    end
end
R.paprFrames=frames;
end


function R=researchXexperimentsXmimoResourceStudy(cfg)
R.snrDb=0:4:24; R.totalPower=1; R.noiseVar=1; R.nModes=8; R.uncertainty=0.15;
g=[4.0 2.8 2.1 1.5 1.0 0.7 0.4 0.2].';
R.gains=g; R.capacityWF=zeros(size(R.snrDb)); R.capacityUniform=zeros(size(R.snrDb)); R.robustCapacity=zeros(size(R.snrDb)); R.qamCeiling=zeros(size(R.snrDb));
R.capacityFormula='C=SUM_k log2(1 + g_k p_k / sigma^2), Gaussian-input Shannon benchmark with perfect CSI.';
for si=1:numel(R.snrDb)
    nv=10^(-R.snrDb(si)/10); totalP=1;
    [p,mu,~]=mimo_resource_allocation('waterfill',g,totalP,nv); R.capacityWF(si)=mimo_resource_allocation('capacity',g,p,nv);
    pu=(totalP/numel(g))*ones(size(g)); R.capacityUniform(si)=mimo_resource_allocation('capacity',g,pu,nv);
    [pr,~,~]=mimo_resource_allocation('robust_waterfill',g,totalP,nv,R.uncertainty); R.robustCapacity(si)=mimo_resource_allocation('capacity',g,pr,nv);
    R.qamCeiling(si)=sum(mimo_resource_allocation('qam_ceiling',g.*pu/nv,cfg.M));
end
R.waterLevelLast=mu;
R.finiteQAMNote='QAM ceiling is min(log2(1+SNR), log2 M) per mode and is not exact finite-alphabet mutual information.';
end

function R=researchXexperimentsXmobilityStudy(cfg)
R.velocityKmh=cfg.velocityGridKmh;
R.velocityFdHz=cfg.fc*(R.velocityKmh/3.6)/cfg.c;
R.velocityFdTu=R.velocityFdHz/cfg.deltaF;
R.generatedFdHz=cfg.fd;
R.generatedFdTu=cfg.fdTuNominal;
p=physical_core('channel_model','profile',cfg.profiles,cfg.activeProfile);
Nmob=max(32768,round(cfg.mobilitySamples));
fsMob=max(8192,2^nextpow2(64*max(cfg.fd,1)));
[h,details]=physical_core('channel_model',cfg.channelModel,Nmob,cfg.fd,fsMob,p.numPaths,cfg.jakesOsc,p.powerLin,cfg.jakesSeed,cfg.ricianKDb,cfg.raysPerCluster,cfg.angularSpreadDeg);
R.channelModel=details.model; R.sampleRateHz=fsMob; R.durationSec=Nmob/fsMob;
R.channelNote=['PDP/envelope are one clustered-ray realization at the configured nominal f_D. ' ...
    'The mobility spectrum comparison uses a long record; Jakes is generated separately as an explicit statistical reference, not as the EVA physical channel model.'];
R.pdpDelayNs=p.delayNs; R.pdpPowerDb=p.powerDb; R.meanTapPower=mean(abs(h).^2,1);
R.fadingTimeMs=(0:size(h,1)-1).'/fsMob*1e3; R.fadingEnvelope=abs(h(:,1));
[f,S]=physical_core('channel_model','psd',h(:,1),fsMob,min(cfg.mobilityPsdSegment,Nmob));
R.psdFrequency=f; R.psd=S; R.psdChecked=any(f>0)&any(S>0);
[hJ,~]=physical_core('channel_model','jakes',Nmob,cfg.fd,fsMob,1,cfg.jakesOsc,1,cfg.jakesSeed+9000,cfg.ricianKDb);
[fJ,SJ]=physical_core('channel_model','psd',hJ(:,1),fsMob,min(cfg.mobilityPsdSegment,Nmob));
R.jakesSampleRateHz=fsMob;
R.jakesFrequency=fJ; R.jakesEmpiricalPSD=SJ;
idx=abs(fJ)<cfg.fd*(1-1e-6);
Sth=zeros(size(fJ)); Sth(idx)=1./(pi*cfg.fd*sqrt(max(1-(fJ(idx)/cfg.fd).^2,realmin)));
Sth=Sth/max(trapz(fJ,Sth),eps);
R.jakesTheoreticalPSD=Sth; R.jakesSupportHz=[-cfg.fd cfg.fd];
outLow=fJ < -cfg.fd; outHigh=fJ > cfg.fd;
outEnergy=trapz(fJ(outLow),SJ(outLow))+trapz(fJ(outHigh),SJ(outHigh));
R.jakesOutOfBandEnergy=max(0,outEnergy)/max(trapz(fJ,SJ),eps);
maxLag=min(round(0.5*Nmob),round(0.5*fsMob/max(cfg.fd,eps)));
step=max(32,round(maxLag/128)); lags=(0:step:maxLag).'; z=hJ(:,1)-mean(hJ(:,1)); p0=mean(abs(z).^2);
acf=zeros(size(lags)); for ii=1:numel(lags), k=lags(ii); if k==0, z1=z; z2=z; else, z1=z(1:end-k); z2=z(1+k:end); end; acf(ii)=mean(z1.*conj(z2))/max(p0,eps); end
R.jakesAcfLags=lags; R.jakesAcf=acf; R.jakesAcfTheory=besselj(0,2*pi*cfg.fd*lags/fsMob); R.jakesAcfRMSE=sqrt(mean(abs(acf-R.jakesAcfTheory).^2));
R.claimability='Claimable channel-statistics scope: long-run clustered EVA is shown as the physical model; the classical Clarke-Jakes PSD/ACF is a separate reference validation.';
end
function R=researchXexperimentsXmismatchStudy(cfg,stage)
p=physical_core('channel_model','profile',cfg.profiles,cfg.activeProfile); N=cfg.N;
R.snrs=[0 10 20 30];
R.model=physical_core('channel_model','cov',N,p.delay,p.powerLin,cfg.fs,cfg.delayModel,cfg.delayFilterHalfLength);
wrongPower=linspace(1,numel(p.powerLin),numel(p.powerLin)); wrongPower=wrongPower/sum(wrongPower);
priors={physical_core('channel_model','cov',N,p.delay,wrongPower,cfg.fs,cfg.delayModel,cfg.delayFilterHalfLength)};
names={'Wrong power weighting (same delays)'};
priors{end+1}=physical_core('channel_model','cov',N,p.delay*0.4,p.powerLin,cfg.fs,cfg.delayModel,cfg.delayFilterHalfLength);
names{end+1}='Delay spread under-estimated (x0.4)';
priors{end+1}=physical_core('channel_model','cov',N,p.delay*2.5,p.powerLin,cfg.fs,cfg.delayModel,cfg.delayFilterHalfLength);
names{end+1}='Delay spread over-estimated (x2.5)';
epaIdx=find(strcmpi({cfg.profiles.name},'EPA'),1);
if ~isempty(epaIdx)
    pe=cfg.profiles(epaIdx);
    priors{end+1}=physical_core('channel_model','cov',N,pe.delay,pe.powerLin,cfg.fs,cfg.delayModel,cfg.delayFilterHalfLength);
    names{end+1}='EPA prior used on an EVA channel';
end
R.priorNames=names; R.wrong=priors{1};
[pilotIdx,~,pv]=estimation_receiver('channel_estimation','pilot_grid',N,4,cfg.pilotValue);
S=zeros(numel(pilotIdx),N); S(:,pilotIdx)=diag(pv);
Rt=R.model; Ip=eye(size(S,1));
R.matchedMSE=zeros(size(R.snrs));
R.mismatchedMSEAll=zeros(numel(priors),numel(R.snrs));
R.penaltyDbAll=zeros(numel(priors),numel(R.snrs));
for si=1:numel(R.snrs)
    nv=1/(10^(R.snrs(si)/10)*cfg.bitsPerSym);
    At=Rt*S'/(S*Rt*S'+nv*Ip);
    R.matchedMSE(si)=researchXexperimentsXwienerMSE(At,S,Rt,nv,N);
    for q=1:numel(priors)
        Aw=priors{q}*S'/(S*priors{q}*S'+nv*Ip);
        R.mismatchedMSEAll(q,si)=researchXexperimentsXwienerMSE(Aw,S,Rt,nv,N);
    end
end
R.penaltyDbAll=10*log10(max(R.mismatchedMSEAll,eps)./max(R.matchedMSE,eps));
R.mismatchedMSE=R.mismatchedMSEAll(1,:); R.penaltyDb=R.penaltyDbAll(1,:);
R.note=['Analytical expected MSE under the true Gaussian channel. Power-only mismatch keeps the correct delay subspace and can be benign; delay-spread mismatch moves the covariance subspace and provides the informative mismatch penalty.'];
end
function m=researchXexperimentsXwienerMSE(A,S,Ctrue,nv,N)
m=real(trace(Ctrue-A*S*Ctrue-Ctrue*S'*A'+A*(S*Ctrue*S'+nv*eye(size(S,1)))*A'))/N;
end

function R=researchXexperimentsXmimoOfdmStudy(cfg,stage)
R.snrDb=cfg.mimoSnrDb; R.berZF=zeros(size(R.snrDb)); R.berMMSE=zeros(size(R.snrDb)); R.runtimeMs=zeros(2,numel(R.snrDb));
R.berMMSEPerfectCSI=zeros(size(R.snrDb)); R.csiAgingPenaltyDb=zeros(size(R.snrDb));
F=max(4,min(cfg.framesSystem,25)); if strcmp(stage,'FAST'),F=min(F,8);end
p=physical_core('channel_model','profile',cfg.profiles,cfg.activeProfile); N=cfg.N; K=2;
for si=1:numel(R.snrDb)
    ez=0; em=0; epc=0; nb=0; tz=0;tm=0;
    for f=1:F
        Xpilot=abs(cfg.mimoPilotAmplitude)*researchXexperimentsXzadoffChu(N,1);
        links=cell(K,K);
        for tx=1:K
            for rx=1:K
                [links{tx,rx},~]=physical_core('channel_model',cfg.channelModel,2*(N+cfg.Ncp),cfg.fd,cfg.fs,p.numPaths,cfg.jakesOsc,p.powerLin,cfg.jakesSeed+1000*f+100*tx+rx,cfg.ricianKDb,cfg.raysPerCluster,cfg.angularSpreadDeg);
            end
        end
        Rt=(cfg.mimoSpatialCorrTx).^(abs((1:K)-(1:K).')); Rr=(cfg.mimoSpatialCorrRx).^(abs((1:K)-(1:K).'));
        Ls=chol(kron(Rt,Rr),'lower');
        for ell=1:p.numPaths
            U=zeros(size(links{1,1},1),K*K); idx=0;
            for tx=1:K
                for rx=1:K
                    idx=idx+1; U(:,idx)=links{tx,rx}(:,ell);
                end
            end
            V=U*Ls.';
            targetPower=sqrt(p.powerLin(ell));
            scale=targetPower/max(sqrt(mean(abs(V(:)).^2)),eps);
            V=V*scale;
            idx=0;
            for tx=1:K
                for rx=1:K
                    idx=idx+1; links{tx,rx}(:,ell)=V(:,idx);
                end
            end
        end
        bits=randi([0 1],N*K*cfg.bitsPerSym,1); [s,~]=physical_core('modem_ofdm','qammap',bits,cfg.M); X=reshape(s,N,K); txBlocks=zeros(N+cfg.Ncp,K);
        for tx=1:K,[txBlocks(:,tx),~]=physical_core('modem_ofdm','ofdmtx',X(:,tx),cfg.Ncp);end
        nvTD=mean(abs(txBlocks(:)).^2)/(10^(R.snrDb(si)/10)*cfg.bitsPerSym); nvFD=cfg.N*nvTD;
        [pilotTx,~]=physical_core('modem_ofdm','ofdmtx',Xpilot,cfg.Ncp);
        Hest=zeros(N,K,K);
        for tx=1:K
            for rx=1:K
                [ypath,~]=physical_core('channel_model','apply',pilotTx,p.delay,links{tx,rx}(1:N+cfg.Ncp,:),cfg.fs,nvTD);
                Yp=physical_core('modem_ofdm','ofdmdemux',ypath,cfg.N,cfg.Ncp); Hest(:,rx,tx)=Yp./Xpilot;
            end
        end
        Yrx=zeros(N+cfg.Ncp,K);
        for rx=1:K
            yr=zeros(N+cfg.Ncp,1);
            for tx=1:K
                [ypath,~]=physical_core('channel_model','apply',txBlocks(:,tx),p.delay,links{tx,rx}(N+cfg.Ncp+1:2*(N+cfg.Ncp),:),cfg.fs,0);yr=yr+ypath;
            end
            Yrx(:,rx)=yr+sqrt(nvTD/2)*(randn(size(yr))+1j*randn(size(yr)));
        end
        Y=fft(Yrx(cfg.Ncp+1:end,:),N);
        Xzf=zeros(N,K);Xmm=zeros(N,K);
        tic;
        for k=1:N,Xzf(k,:)=(squeeze(Hest(k,:,:))\Y(k,:).').';end
        tz=tz+toc*1000;
        tic;
        for k=1:N
            Hk=squeeze(Hest(k,:,:));A=Hk'*Hk+nvFD*eye(K);Xmm(k,:)=(A\(Hk'*Y(k,:).')).';
        end
        tm=tm+toc*1000;
        bZF=physical_core('modem_ofdm','qamdemap',Xzf(:),cfg.M); ez=ez+sum(bZF~=bits);
        bMM=physical_core('modem_ofdm','qamdemap',Xmm(:),cfg.M); em=em+sum(bMM~=bits);
        Ypc=Y;
        Xpc=zeros(N,K);
        Htrue=zeros(N,K,K);
        for tx=1:K
            for rx=1:K
                Htrue(:,rx,tx)=diag(physical_core('channel_model','matrix',links{tx,rx}(N+cfg.Ncp+1:2*(N+cfg.Ncp),:),p.delay,cfg.N,cfg.Ncp,cfg.fs));
            end
        end
        for k=1:N
            Hk=squeeze(Htrue(k,:,:)); A=Hk'*Hk+nvFD*eye(K); Xpc(k,:)=(A\(Hk'*Ypc(k,:).')).';
        end
        bp=physical_core('modem_ofdm','qamdemap',Xpc(:),cfg.M); epc=epc+sum(bp~=bits); nb=nb+numel(bits);
    end
    R.berZF(si)=ez/max(nb,1);R.berMMSE(si)=em/max(nb,1);R.berMMSEPerfectCSI(si)=epc/max(nb,1);R.runtimeMs(:,si)=[tz/F;tm/F];
    R.csiAgingPenaltyDb(si)=10*log10(max(R.berMMSE(si),eps)/max(R.berMMSEPerfectCSI(si),eps));
end
R.pilotType='Zadoff-Chu constant-modulus training sequence';
R.pilotPeakToRms=researchXexperimentsXpeakToRms(researchXexperimentsXzadoffChu(N,1));
R.note='2x2 MIMO-OFDM with clustered EVA per-ray Doppler, separable Tx/Rx spatial correlation, and NOISY sequential constant-modulus training blocks. CSI is aged by one OFDM symbol relative to the data. Data are detected with per-subcarrier ZF and MMSE.'; R.spatialCorrTx=cfg.mimoSpatialCorrTx; R.spatialCorrRx=cfg.mimoSpatialCorrRx;
end

function sl=researchXexperimentsXdiversitySlope(snrDb,ber,floorBer)
sl=nan(size(ber,1),1);
for r=1:size(ber,1)
    b=ber(r,:); good=isfinite(b) & b>max(floorBer,0) & b<0.4;
    if nnz(good)>=3
        x=snrDb(good)/10; y=log10(b(good));
        cf=polyfit(x(:),y(:),1); sl(r)=-cf(1);
    end
end
end

function z=researchXexperimentsXzadoffChu(N,root)
if nargin<2 || isempty(root), root=1; end
assert(gcd(root,N)==1,'Zadoff-Chu root must be coprime with the sequence length.');
n=(0:N-1).';
if mod(N,2)==0, z=exp(-1j*pi*root*n.^2/N); else, z=exp(-1j*pi*root*n.*(n+1)/N); end
end

function R=researchXexperimentsXimpairmentStudy(cfg,stage)
F=max(40,min(cfg.framesSystem*10,500));
if strcmp(stage,'SMOKE'),F=4; elseif strcmp(stage,'FAST'),F=min(F,60); end
R.snrDb=cfg.impairmentSnrDb;
R.cp=cfg.cpStress; R.cpBer=zeros(size(R.cp));
R.phaseNoiseStd=cfg.phaseNoiseStd; R.phaseNoiseBer=zeros(size(R.phaseNoiseStd));
R.impulsiveProb=cfg.impulsiveProb; R.impulsiveBer=zeros(size(R.impulsiveProb));
R.cpErrors=zeros(size(R.cp)); R.cpBits=zeros(size(R.cp));
R.phaseNoiseErrors=zeros(size(R.phaseNoiseStd)); R.phaseNoiseBits=zeros(size(R.phaseNoiseStd));
R.impulsiveErrors=zeros(size(R.impulsiveProb)); R.impulsiveBits=zeros(size(R.impulsiveProb));
p=physical_core('channel_model','profile',cfg.profiles,cfg.activeProfile); N=cfg.N;
[Gtap,~]=physical_core('channel_model','taps',p.delay,cfg.fs);
R.resolvedTapSpanSamples=size(Gtap,1);
R.requiredCpSamples=max(R.resolvedTapSpanSamples-1,0);
assert(R.requiredCpSamples>0,'Resolved channel span must be positive.');
R.channelMode='block-static EVA'; R.estimatedCSI=false; R.perfectCSI=true;
for ci=1:numel(R.cp)
    e=0;n=0; cp=R.cp(ci);
    for ff=1:F
        b0=randi([0 1],N*cfg.bitsPerSym,1); b1=randi([0 1],N*cfg.bitsPerSym,1);
        [X0,~]=physical_core('modem_ofdm','qammap',b0,cfg.M); [X1,~]=physical_core('modem_ofdm','qammap',b1,cfg.M);
        [t0,~]=physical_core('modem_ofdm','ofdmtx',X0,cp); [t1,~]=physical_core('modem_ofdm','ofdmtx',X1,cp);
        stream=[t0;t1]; nv=mean(abs(t1).^2)/(10^(R.snrDb/10)*cfg.bitsPerSym);
        rs=RandStream('twister','Seed',cfg.jakesSeed+6000+ff); staticPhase=exp(1j*2*pi*rand(rs,1,p.numPaths));
        hs=repmat(sqrt(p.powerLin(:)).'.*staticPhase,numel(stream),1);
        [yr,~]=physical_core('channel_model','apply',stream,p.delay,hs,cfg.fs,nv);
        blk=yr(numel(t0)+1:numel(t0)+numel(t1)); Y=physical_core('modem_ofdm','ofdmdemux',blk,N,cp);
        h1=hs(numel(t0)+1:end,:);
        if size(h1,1) < N+cfg.Ncp
            h1=[h1; repmat(h1(end,:),N+cfg.Ncp-size(h1,1),1)];
        end
        H=physical_core('channel_model','matrix',h1,p.delay,N,cfg.Ncp,cfg.fs);
        xhat=estimation_receiver('equalizers','mmse',H,Y,N*nv); bh=physical_core('modem_ofdm','qamdemap',xhat,cfg.M);
        e=e+sum(bh~=b1); n=n+numel(b1);
    end
    R.cpErrors(ci)=e; R.cpBits(ci)=n; R.cpBer(ci)=e/max(n,1);
end
for q=1:numel(R.phaseNoiseStd)
    e=0;n=0;
    for ff=1:F
        bits=randi([0 1],N*cfg.bitsPerSym,1); [X,~]=physical_core('modem_ofdm','qammap',bits,cfg.M); [tx,~]=physical_core('modem_ofdm','ofdmtx',X,cfg.Ncp); nv=mean(abs(tx).^2)/(10^(R.snrDb/10)*cfg.bitsPerSym);
        rs=RandStream('twister','Seed',cfg.jakesSeed+7100+ff); staticPhase=exp(1j*2*pi*rand(rs,1,p.numPaths));
        hImp=repmat(sqrt(p.powerLin(:)).'.*staticPhase,numel(tx),1);
        phi=R.phaseNoiseStd(q)*cumsum(randn(size(tx))); [yc,~]=physical_core('channel_model','apply',tx.*exp(1j*phi),p.delay,hImp,cfg.fs,nv);
        Y=physical_core('modem_ofdm','ofdmdemux',yc,N,cfg.Ncp); H=physical_core('channel_model','matrix',hImp,p.delay,N,cfg.Ncp,cfg.fs);
        bh=physical_core('modem_ofdm','qamdemap',estimation_receiver('equalizers','mmse',H,Y,N*nv),cfg.M); e=e+sum(bh~=bits); n=n+numel(bits);
    end
    R.phaseNoiseErrors(q)=e; R.phaseNoiseBits(q)=n; R.phaseNoiseBer(q)=e/max(n,1);
end
for q=1:numel(R.impulsiveProb)
    e=0;n=0;
    for ff=1:F
        bits=randi([0 1],N*cfg.bitsPerSym,1); [X,~]=physical_core('modem_ofdm','qammap',bits,cfg.M); [tx,~]=physical_core('modem_ofdm','ofdmtx',X,cfg.Ncp); nv=mean(abs(tx).^2)/(10^(R.snrDb/10)*cfg.bitsPerSym);
        rs=RandStream('twister','Seed',cfg.jakesSeed+7200+ff); staticPhase=exp(1j*2*pi*rand(rs,1,p.numPaths));
        hImp=repmat(sqrt(p.powerLin(:)).'.*staticPhase,numel(tx),1);
        [yc,~]=physical_core('channel_model','apply',tx,p.delay,hImp,cfg.fs,nv); imp=rand(size(tx))<R.impulsiveProb(q);
        y=yc+imp.*sqrt(cfg.impulsiveK*nv/2).*(randn(size(tx))+1j*randn(size(tx)));
        Y=physical_core('modem_ofdm','ofdmdemux',y,N,cfg.Ncp); H=physical_core('channel_model','matrix',hImp,p.delay,N,cfg.Ncp,cfg.fs);
        bh=physical_core('modem_ofdm','qamdemap',estimation_receiver('equalizers','mmse',H,Y,N*nv),cfg.M); e=e+sum(bh~=bits); n=n+numel(bits);
    end
    R.impulsiveErrors(q)=e; R.impulsiveBits(q)=n; R.impulsiveBer(q)=e/max(n,1);
end
R.framesPerPoint=F;
R.bitsPerPoint=F*N*cfg.bitsPerSym;
R.zeroErrorUpperBound=-log(0.05)/max(R.bitsPerPoint,1);
R.confidenceLevel=0.95;
R.cpCI=researchXexperimentsXstatistics_ci(R.cpErrors,R.cpBits,R.confidenceLevel);
R.phaseNoiseCI=researchXexperimentsXstatistics_ci(R.phaseNoiseErrors,R.phaseNoiseBits,R.confidenceLevel);
R.impulsiveCI=researchXexperimentsXstatistics_ci(R.impulsiveErrors,R.impulsiveBits,R.confidenceLevel);
R.channelNote='Controlled sweeps use perfect instantaneous CSI and a block-static clustered EVA channel. CP stress includes the previous block to expose ISI when CP is shorter than the resolved tap span; phase-noise and impulsive-noise sweeps isolate their respective impairments from channel-estimation error.';
R.claimability='Claimable only as controlled sensitivity experiments at the stated SNR and physical EVA model; not universal robustness bounds.';
end
function stats=researchXexperimentsXstatistics_ci(errors,bits,confidence)
z=1.95996398454005;
if nargin>=3 && confidence~=0.95, z=-sqrt(2)*erfcinv(2*(0.5+confidence/2)); end
p=errors./max(bits,1); n=max(bits,1); den=1+z^2./n; center=(p+z^2./(2*n))./den; half=z*sqrt(max(p.*(1-p)./n+z^2./(4*n.^2),0))./den;
stats.low=max(center-half,0); stats.high=min(center+half,1); stats.center=p;
end



function r=researchXexperimentsXpeakToRms(x)
x=x(:);
r=max(abs(x))/max(sqrt(mean(abs(x).^2)),eps);
end
