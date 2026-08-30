function varargout = physical_core(mode,varargin)
mode=lower(char(mode));
switch mode
case 'ofdm_config'
    if nargout==0
        ofdmXconfigXofdm_config(varargin{:});
    else
        [varargout{1:nargout}] = ofdmXconfigXofdm_config(varargin{:});
    end
case 'channel_model'
    if nargout==0
        channelXmodelXchannel_model(varargin{:});
    else
        [varargout{1:nargout}] = channelXmodelXchannel_model(varargin{:});
    end
case 'modem_ofdm'
    if nargout==0
        modemXofdmXmodem_ofdm(varargin{:});
    else
        [varargout{1:nargout}] = modemXofdmXmodem_ofdm(varargin{:});
    end
case 'monte_carlo'
    if nargout==0
        monteXcarloXmonte_carlo(varargin{:});
    else
        [varargout{1:nargout}] = monteXcarloXmonte_carlo(varargin{:});
    end
case 'validate_config'
    if nargout==0
        validateXconfigXvalidate_config(varargin{:});
    else
        [varargout{1:nargout}] = validateXconfigXvalidate_config(varargin{:});
    end
otherwise
    error('Unknown mode %s for %s.',mode,mfilename);
end
end

function cfg = ofdmXconfigXofdm_config(mode,numerology)

if nargin < 1, mode = 'AUDIT'; end
if nargin < 2 || isempty(numerology), numerology = 'narrow'; end
mode = upper(char(mode));
numerology = lower(char(numerology));

cfg.release = 'V8.5-SCI-CLAIMABLE';
cfg.mode = mode;
cfg.numerology = numerology;

cfg.c = 299792458;
cfg.fc = 2.4e9;
cfg.velocity_kmh = 120;
cfg.velocity = cfg.velocity_kmh/3.6;
cfg.fd = cfg.fc*cfg.velocity/cfg.c;

switch numerology
    case 'narrow'
        cfg.N = 64;  cfg.Ncp = 16;
    case 'wide'
        cfg.N = 256; cfg.Ncp = 32;
    otherwise
        error('Unknown numerology %s. Use narrow or wide.',numerology);
end
cfg.deltaF = 15e3;
cfg.Tu = 1/cfg.deltaF;
cfg.fs = cfg.N*cfg.deltaF;
cfg.Ts = 1/cfg.fs;
cfg.Tcp = cfg.Ncp*cfg.Ts;
cfg.Tsym = cfg.Tu + cfg.Tcp;

cfg.M = 4;
cfg.bitsPerSym = log2(cfg.M);
cfg.modulationName = 'QPSK';
cfg.snrDb = 0:2:30;
cfg.snrDefinition = 'EbN0_useful_symbols';
cfg.noiseFigureDb = 5;

cfg.profiles(1) = ofdmXconfigXlocal_profile('EPA',[0 30 70 90 110 190 410],[0 -1 -2 -3 -8 -17.2 -20.8]);
cfg.profiles(2) = ofdmXconfigXlocal_profile('EVA',[0 30 150 310 370 710 1090 1730 2510],[0 -1.5 -1.4 -3.6 -0.6 -9.1 -7 -12 -16.9]);
cfg.profiles(3) = ofdmXconfigXlocal_profile('ETU',[0 50 120 200 230 500 1600 2300 5000],[ -1 -1 -1 0 0 0 -3 -5 -7]);
cfg.profileNames = {cfg.profiles.name};
cfg.activeProfile = 'EVA';

cfg.velocityGridKmh = [0 30 60 90 120 200 300 500 800];
cfg.fdTuGrid = (cfg.fc*(cfg.velocityGridKmh/3.6)/cfg.c)/cfg.deltaF;

cfg.jakesOsc = 64;
cfg.mobilityPsdSegment = 32768;
cfg.jakesSeed = 20260823;
cfg.ricianKDb = 0;
cfg.channelModel = 'clustered';
cfg.raysPerCluster = 16;
cfg.angularSpreadDeg = 25;
cfg.dopplerSecondMomentRatio = 1.0;   % worst-case (upper) reference
cfg.dopplerJakesRatio        = 0.5;   % classical Jakes (lower) reference
cfg.channelModelNote = 'EVA-PDP clustered per-ray Doppler; Jakes retained only as explicit reference baseline.';

cfg.delayModel = 'fractional';
cfg.delayFilterHalfLength = 4;

cfg.grayMapping = true;

cfg.pilotSpacing = [2 4 8 16];
cfg.pilotValue = 1+1j;
cfg.pilotPower = abs(cfg.pilotValue)^2;
cfg.pilotTimeSpacing = [1 2 4 8];
cfg.pilotOptimizationSNR = 15;
cfg.runtimeRepetitions = 200;
cfg.enableRuntimeMeasurements = true;
cfg.crosswaveformFramesAudit=25; cfg.crosswaveformFramesFull=25;
cfg.impairmentFramesAudit=500;
cfg.mobilitySamples=32768; cfg.mobilityPsdSegment=16384;

cfg.bemOrders = 0:8;
cfg.iciBands = [1 2 4 8 12 16];
cfg.equalizerFdTuGrid = [0.0178 0.10];
cfg.iciFdTuGrid = [0.005 0.01 0.02 0.05 0.1 0.15 0.2];

cfg.otfsN = 32;
cfg.otfsM = 128;

cfg.otfsDetectorN = 32;
cfg.otfsDetectorM = 32;

cfg.otfsDopplerTaps = [];
cfg.otfsQam = 4;
cfg.otfsIterations = 20;
cfg.otfsDamping = 0.7;
cfg.otfsIdiTerms = [];
cfg.otfsNcp = 4;
cfg.otfsUseExactDdMatrix = true;
cfg.otfsPaperAnchor = 'Hadani2017-Mohammed2023';
cfg.fractionalDoppler = [0 0.10 0.25 0.40];
cfg.otfsPilotValue = 1+1j;
cfg.otfsPilotGuard = 6;
cfg.otfsPilotSNR = 0:6:30;
cfg.otfsPilotFrames = 8;

cfg.pilotSweep = [2 4 8 16];
cfg.modulationSweep = [4 16];
cfg.mimoTx = 2;
cfg.mimoRx = 2;
cfg.mimoSnrDb = [0 8 16 24];
cfg.mimoPilotAmplitude = 1+1j;
cfg.mimoDopplerCoupled = true;
cfg.mimoSpatialCorrTx = 0.70;
cfg.mimoSpatialCorrRx = 0.70;
cfg.mimoChannelNote = 'Clustered EVA per-ray Doppler with separable Tx/Rx exponential spatial correlation.';

cfg.cpStress = [0 4 8 12 16 20 24 32];
cfg.phaseNoiseStd = [0 1e-3 3e-3 1e-2 3e-2 1e-1];
cfg.impulsiveProb = [0 1e-3 3e-3 1e-2 3e-2];
cfg.impulsiveK = 100;
cfg.impairmentSnrDb = 20;

switch mode
    case 'SMOKE'
        cfg.minErrors = 50; cfg.maxBits = 2e4;
        cfg.framesBaseline = 4; cfg.framesEstimation = 4; cfg.framesICI = 4;
        cfg.framesOTFS = 2; cfg.framesSystem = 2;
    case 'FAST'
        cfg.minErrors = 200; cfg.maxBits = 8e4;
        cfg.framesBaseline = 40; cfg.framesEstimation = 25; cfg.framesICI = 25;
        cfg.framesOTFS = 12; cfg.framesSystem = 10;
    case 'AUDIT'
        cfg.minErrors = 500; cfg.maxBits = 2e5;
        cfg.framesBaseline = 100; cfg.framesEstimation = 60; cfg.framesICI = 60;
        cfg.framesOTFS = 30; cfg.framesSystem = 20;
    case 'FULL'
        cfg.minErrors = 2e3; cfg.maxBits = 5e5;
        cfg.framesBaseline = 300; cfg.framesEstimation = 180; cfg.framesICI = 180;
        cfg.framesOTFS = 80; cfg.framesSystem = 60;
    case 'MASSIVE'
        cfg.minErrors = 1e4; cfg.maxBits = 2e6;
        cfg.framesBaseline = 1200; cfg.framesEstimation = 600; cfg.framesICI = 600;
        cfg.framesOTFS = 250; cfg.framesSystem = 200;
    otherwise
        error('Unknown mode %s. Use SMOKE, FAST, AUDIT, FULL, or MASSIVE.',mode);
end

cfg.useParallel = license('test','Parallel_Computing_Toolbox') || exist('parfor','builtin') == 5;
cfg.parallel = cfg.useParallel;
cfg.randomSeed = 731245;

cfg.fdTuNominal = cfg.fd*cfg.Tu;
cfg.fdTsymNominal = cfg.fd*cfg.Tsym;

end

function p = ofdmXconfigXlocal_profile(name,delayNs,powerDb)
p.name = name;
p.delayNs = delayNs(:).';
p.powerDb = powerDb(:).';
p.delay = p.delayNs*1e-9;
p.powerLin = 10.^(p.powerDb/10);
p.powerLin = p.powerLin/sum(p.powerLin);
p.numPaths = numel(p.delay);
end


function varargout = channelXmodelXchannel_model(mode,varargin)

switch lower(mode)
    case 'profile'
        varargout{1} = channelXmodelXget_profile(varargin{:});
    case 'jakes'
        [varargout{1},varargout{2}] = channelXmodelXjakes_taps(varargin{:});
    case {'clustered','realistic','doubly_selective'}
        if numel(varargin)<9, varargin{9}=16; end
        if numel(varargin)<10, varargin{10}=25; end
        [varargout{1},varargout{2}] = channelXmodelXclustered_taps(varargin{:});
    case 'apply'
        [varargout{1},varargout{2}] = channelXmodelXapply_channel(varargin{:});
    case 'taps'
        [varargout{1},varargout{2}] = channelXmodelXresolve_taps(varargin{:});
    case 'delay_model'
        [varargout{1:max(nargout,1)}] = channelXmodelXdelay_defaults(varargin{:});
    case 'matrix'
        varargout{1} = channelXmodelXfrequency_matrix(varargin{:});
    case 'cov'
        varargout{1} = channelXmodelXdelay_covariance(varargin{:});
    case 'cov_ideal'
        varargout{1} = channelXmodelXideal_delay_covariance(varargin{:});
    case 'psd'
        [varargout{1},varargout{2}] = channelXmodelXdoppler_psd(varargin{:});
    otherwise
        error('Unknown channel mode %s.',mode);
end
end

function p = channelXmodelXget_profile(profiles,name)
idx = find(strcmpi({profiles.name},name),1);
assert(~isempty(idx),'Unknown channel profile %s.',name);
p = profiles(idx);
end

function [h,details] = channelXmodelXjakes_taps(Ns,fd,fs,nPaths,nOsc,powers,seed,KdB)
if nargin<8 || isempty(seed), seed=1; end
if nargin<9 || isempty(KdB), KdB=-Inf; end
rs = RandStream('twister','Seed',seed);

h = zeros(Ns,nPaths);
t = (0:Ns-1).'/fs;
K = 0; if isfinite(KdB) && KdB>0, K=10^(KdB/10); end

for ell=1:nPaths
    theta = 2*pi*rand(rs,nOsc,1);
    beta = pi*((1:nOsc).'-0.5)/nOsc;
    fosc = fd*cos(beta);
    phase = theta + 2*pi*rand(rs);
    z = zeros(Ns,1);
    for q=1:nOsc
        z = z + exp(1j*(2*pi*fosc(q)*t + phase(q)));
    end
    z = z/sqrt(nOsc);
    z = z/sqrt(mean(abs(z).^2));
    if K>0 && ell==1
        z = sqrt(K/(K+1)) + sqrt(1/(K+1))*z;
    end
    h(:,ell) = sqrt(powers(ell))*z;
end

details.fd = fd;
details.fs = fs;
details.nOsc = nOsc;
details.power = powers(:);
details.seed = seed;
end


function [h,details] = channelXmodelXclustered_taps(Ns,fd,fs,nPaths,nOsc,powers,seed,KdB,rayPerCluster,angularSpreadDeg)
if nargin<8 || isempty(KdB), KdB=0; end
if nargin<9 || isempty(rayPerCluster), rayPerCluster=16; end
if nargin<10 || isempty(angularSpreadDeg), angularSpreadDeg=25; end
assert(nPaths==numel(powers),'nPaths must match the supplied PDP powers.');
assert(rayPerCluster>=4 && mod(rayPerCluster,1)==0,'rayPerCluster must be an integer >= 4.');
assert(angularSpreadDeg>0 && angularSpreadDeg<=90,'angularSpreadDeg must lie in (0,90].');
rs = RandStream('twister','Seed',seed);
t=(0:Ns-1).'/fs;
h=zeros(Ns,nPaths);
rayPower=ones(rayPerCluster,1)/rayPerCluster;
for ell=1:nPaths
    theta0=2*pi*rand(rs);
    theta=theta0 + deg2rad(angularSpreadDeg)*randn(rs,rayPerCluster,1);
    theta=mod(theta+pi,2*pi)-pi;
    phase=2*pi*rand(rs,rayPerCluster,1);
    fdRay=fd*cos(theta);
    z=zeros(Ns,1);
    for q=1:rayPerCluster
        z=z+sqrt(rayPower(q))*exp(1j*(2*pi*fdRay(q)*t+phase(q)));
    end
    z=z/sqrt(mean(abs(z).^2));
    if KdB>0 && ell==1
        K=10^(KdB/10);
        losTheta=theta0; los=exp(1j*2*pi*fd*cos(losTheta)*t);
        z=sqrt(K/(K+1))*los + sqrt(1/(K+1))*z;
        z=z/sqrt(mean(abs(z).^2));
    end
    h(:,ell)=sqrt(powers(ell))*z;
end
details.fd=fd; details.fs=fs; details.nOsc=nOsc; details.power=powers(:);
details.seed=seed; details.rayPerCluster=rayPerCluster;
details.angularSpreadDeg=angularSpreadDeg;
details.model='Clustered per-ray Doppler / EVA-PDP';
end

function [G,tapDelay] = channelXmodelXresolve_taps(delays,fs,model,Lhalf)

if nargin<3, model=[]; end
if nargin<4, Lhalf=[]; end
[defModel,defL]=channelXmodelXdelay_defaults();
if isempty(model), model=defModel; end
if isempty(Lhalf), Lhalf=defL; end
model=lower(char(model));
delays=delays(:).';

persistent cacheKey cacheG cacheD
key=sprintf('%s|%d|%.12g|%s',model,Lhalf,fs,mat2str(delays,12));
if ~isempty(cacheKey) && strcmp(cacheKey,key)
    G=cacheG; tapDelay=cacheD; return;
end

d = delays*fs;
switch model
    case 'rounded'
        idx=round(d); K=max(idx)+1; G=zeros(K,numel(d));
        for ell=1:numel(d), G(idx(ell)+1,ell)=1; end
    case 'fractional'
        K=floor(max(d))+Lhalf+1; G=zeros(K,numel(d));
        for ell=1:numel(d)
            dInt=round(d(ell));
            if abs(d(ell)-dInt)<1e-12
                idx=max(0,min(K-1,dInt));
                G(idx+1,ell)=1;
                continue;
            end
            lo=max(0,floor(d(ell))-Lhalf+1); hi=min(K-1,floor(d(ell))+Lhalf);
            k=(lo:hi).'; xarg=k-d(ell);
            w=0.5*(1+cos(pi*xarg/Lhalf)); w(abs(xarg)>=Lhalf)=0;
            g=channelXmodelXsinc(xarg).*w;
            nrm=norm(g);
            if nrm<eps, g=zeros(size(g)); g(1)=1; nrm=1; end
            G(k+1,ell)=g/nrm;
        end
    otherwise
        error('Unknown delay model %s. Use fractional or rounded.',model);
end
tapDelay=(0:size(G,1)-1).';
cacheKey=key; cacheG=G; cacheD=tapDelay;
end

function [model,Lhalf] = channelXmodelXdelay_defaults(newModel,newLhalf)
persistent M L
if isempty(M), M='fractional'; L=4; end
if nargin>=1 && ~isempty(newModel), M=lower(char(newModel)); end
if nargin>=2 && ~isempty(newLhalf), L=newLhalf; end
model=M; Lhalf=L;
end

function y = channelXmodelXsinc(x)
y=ones(size(x)); nz=abs(x)>eps; y(nz)=sin(pi*x(nz))./(pi*x(nz));
end

function [y,state] = channelXmodelXapply_channel(x,delays,h,fs,noiseVar,model,Lhalf)
if nargin<6, model=[]; end
if nargin<7, Lhalf=[]; end
x = x(:); Nx = numel(x); Ns = size(h,1);
assert(Nx<=Ns,'Channel realization (%d samples) is shorter than the input block (%d).',Ns,Nx);

[G,tapDelay] = channelXmodelXresolve_taps(delays,fs,model,Lhalf);
hInt = h*G.';                                  % Ns-by-nTaps
y = zeros(Nx,1);
for k=1:numel(tapDelay)
    d = tapDelay(k);
    if d>=Nx, continue; end
    n = (1+d):Nx;
    y(n) = y(n) + hInt(n,k).*x(n-d);
end
if nargin>=5 && ~isempty(noiseVar) && noiseVar>0
    y = y + sqrt(noiseVar/2)*(randn(size(y))+1j*randn(size(y)));
end
state.sampleDelay = tapDelay;
state.numTaps = numel(tapDelay);
state.delayModel = model;
state.rxPower = mean(abs(y).^2);
end

function H = channelXmodelXfrequency_matrix(h,delays,N,Ncp,fs)
H = zeros(N,N);
for m=1:N
    X = zeros(N,1); X(m)=1;
    x = ifft(X,N);
    tx = [x(end-Ncp+1:end);x];
    [y,~] = channelXmodelXapply_channel(tx,delays,h,fs,0);
    Y = fft(y(Ncp+1:Ncp+N),N);
    H(:,m)=Y;
end
end

function R = channelXmodelXdelay_covariance(N,delays,powers,fs,model,Lhalf)
if nargin<5, model=[]; end
if nargin<6, Lhalf=[]; end
powers = powers(:);
[G,tapDelay] = channelXmodelXresolve_taps(delays,fs,model,Lhalf);
assert(size(G,2)==numel(powers),'Delay filter bank must have one column per path.');
W = exp(-1j*2*pi*((0:N-1).')*(tapDelay(:).')/N);   % N-by-nTaps
Ghat = W*G;                                        % N-by-nPaths
R = (Ghat.*(powers.'))*Ghat';
R = (R+R')/2;
R = R/(trace(R)/N);
end

function R = channelXmodelXideal_delay_covariance(N,delays,powers,fs)
f = ((0:N-1).').*fs/N;
R = zeros(N,N);
for k=1:N
    for m=1:N
        df = f(k)-f(m);
        R(k,m)=sum(powers(:).*exp(-1j*2*pi*df*delays(:)));
    end
end
R = (R+R')/2;
R = R/(trace(R)/N);
end

function [f,S] = channelXmodelXdoppler_psd(h,fs,segmentLength)
h = h(:)-mean(h);
N = numel(h);
if nargin<3 || isempty(segmentLength), segmentLength=min(N,32768); end
segmentLength=max(16,min(N,round(segmentLength)));
step=max(1,floor(segmentLength/2));
nfft=max(4096,2^nextpow2(segmentLength));
w=0.5-0.5*cos(2*pi*(0:segmentLength-1).'/max(segmentLength-1,1));
U=sum(w.^2);
starts=1:step:max(1,N-segmentLength+1);
Sacc=zeros(nfft,1); nseg=0;
for ii=1:numel(starts)
    idx=starts(ii):(starts(ii)+segmentLength-1);
    if idx(end)>N, break; end
    x=h(idx).*w;
    Hf=fftshift(fft(x,nfft));
    Sacc=Sacc+abs(Hf).^2/(fs*U);
    nseg=nseg+1;
end
if nseg==0
    x=h(:).*w(1:N); Hf=fftshift(fft(x,nfft)); Sacc=abs(Hf).^2/(fs*U); nseg=1;
end
S=Sacc/nseg;
f=(-floor(nfft/2):ceil(nfft/2)-1).'*fs/nfft;
S=S(:);
end

function varargout = modemXofdmXmodem_ofdm(mode,varargin)

switch lower(mode)
    case 'qammap'
        [varargout{1},varargout{2}] = modemXofdmXqam_map(varargin{:});
    case 'qamdemap'
        [varargout{1},varargout{2}] = modemXofdmXqam_demap(varargin{:});
    case 'ofdmtx'
        [varargout{1},varargout{2}] = modemXofdmXofdm_tx(varargin{:});
    case 'ofdmdemux'
        [varargout{1},varargout{2}] = modemXofdmXofdm_rx(varargin{:});
    case 'qpsk_theory'
        varargout{1} = modemXofdmXqpsk_theory(varargin{:});
    case 'papr'
        [varargout{1},varargout{2}] = modemXofdmXpapr_ccdf(varargin{:});
    otherwise
        error('Unknown modem mode: %s',mode);
end
end

function [s,idx] = modemXofdmXqam_map(bits,M)
bits = logical(bits(:)); k = round(log2(M)); levels = sqrt(M); kAx = k/2;
assert(ismember(M,[4 16 64]),'Hand mapper supports 4/16/64-QAM.');
assert(mod(numel(bits),k)==0,'Bit vector length must be a multiple of log2(M).');
B=reshape(bits,k,[]).';
gI=zeros(size(B,1),1); gQ=zeros(size(B,1),1);
for b=1:kAx, gI=2*gI+double(B(:,b)); end
for b=1:kAx, gQ=2*gQ+double(B(:,kAx+b)); end
nI=modemXofdmXgray2bin(gI,kAx); nQ=modemXofdmXgray2bin(gQ,kAx);
Ilev=2*nI-levels+1; Qlev=2*nQ-levels+1;
scale=sqrt((2/3)*(M-1)); s=(Ilev+1j*Qlev)/scale; s=s(:);
idx=nQ*levels+nI; idx=idx(:);
end

function [bits,idx] = modemXofdmXqam_demap(s,M)
k=round(log2(M)); levels=sqrt(M); kAx=k/2; scale=sqrt((2/3)*(M-1)); z=s(:)*scale;
nI=min(levels-1,max(0,round((real(z)+levels-1)/2)));
nQ=min(levels-1,max(0,round((imag(z)+levels-1)/2)));
gI=modemXofdmXbin2gray(nI); gQ=modemXofdmXbin2gray(nQ);
B=false(numel(nI),k);
for b=kAx:-1:1, B(:,b)=mod(gI,2); gI=floor(gI/2); end
for b=kAx:-1:1, B(:,kAx+b)=mod(gQ,2); gQ=floor(gQ/2); end
bits=reshape(B.',[],1); idx=nQ*levels+nI;
end

function n = modemXofdmXgray2bin(g,nbits)
n=g;
for shift=1:nbits-1, n=bitxor(n,bitshift(g,-shift)); end
end

function g = modemXofdmXbin2gray(n)
g=bitxor(n,bitshift(n,-1));
end

function [tx,cp] = modemXofdmXofdm_tx(X,Ncp)
X = X(:); N = numel(X);
x = ifft(X,N);
cp = x(end-Ncp+1:end);
tx = [cp; x];
end

function [X,x] = modemXofdmXofdm_rx(rx,N,Ncp)
rx = rx(:); assert(numel(rx)>=N+Ncp,'Receiver block is too short.');
x = rx(Ncp+1:Ncp+N);
X = fft(x,N);
end

function ber = modemXofdmXqpsk_theory(EbN0dB)
EbN0 = 10.^(EbN0dB(:)/10);
ber = 0.5*erfc(sqrt(EbN0));
end

function [paprDb,ccdf] = modemXofdmXpapr_ccdf(X,thresholdsDb)
X = X(:); p = abs(X).^2/mean(abs(X).^2); paprDb = 10*log10(max(p));
if nargin<2, thresholdsDb = 0:0.25:14; end
ccdf = arrayfun(@(t)mean(10*log10(p)>t),thresholdsDb(:));
end


function [ber,stats] = monteXcarloXmonte_carlo(errors,bits)
errors=double(errors); bits=double(bits); ber=errors/max(bits,1);
[lo,hi]=monteXcarloXwilson(errors,bits,0.95);
stats.errors=errors; stats.bits=bits; stats.lower=lo; stats.upper=hi;
stats.zeroErrorUpperBound=3/max(bits,1);
end

function [lo,hi]=monteXcarloXwilson(k,n,conf)
if n<=0, lo=NaN; hi=NaN; return; end
z=-sqrt(2)*erfcinv(2*(0.5+conf/2)); phat=k/n; d=1+z^2/n;
center=(phat+z^2/(2*n))/d;
half=z*sqrt(phat*(1-phat)/n+z^2/(4*n^2))/d;
lo=max(0,center-half); hi=min(1,center+half);
end


function report = validateXconfigXvalidate_config(cfg)
report.pass = true;
report.messages = {};

assert(cfg.N > 0 && mod(cfg.N,2)==0,'N must be positive and even.');
assert(cfg.deltaF > 0,'Subcarrier spacing must be positive.');
assert(cfg.Ncp >= 1,'CP must contain at least one sample.');

p = cfg.profiles(strcmp(cfg.profileNames,cfg.activeProfile));
if isempty(p), error('Active profile %s not found.',cfg.activeProfile); end

channelXmodelXdelay_defaults(cfg.delayModel,cfg.delayFilterHalfLength);
[~,tapDelay] = channelXmodelXresolve_taps(p.delay,cfg.fs,cfg.delayModel,cfg.delayFilterHalfLength);
report.numTaps = numel(tapDelay);
report.tapSpanSamples = max(tapDelay);
report.distinctRoundedTaps = numel(unique(round(p.delay*cfg.fs)));
report.delayResolution = report.distinctRoundedTaps/p.numPaths;

maxDelay = max(p.delay);
if cfg.Ncp < report.tapSpanSamples
    report.pass = false;
    report.messages{end+1} = 'CP is shorter than the resolved channel tap span.';
end
if report.distinctRoundedTaps < p.numPaths
    if strcmpi(cfg.numerology,'wide')
        report.messages{end+1} = sprintf(['Some %s delays remain within the same integer sample bin: %d of %d ' ...
            'distinct rounded locations (Ts = %.3f us); the configured fractional-delay model retains ' ...
            'the sub-sample delay structure.'], ...
            p.name,report.distinctRoundedTaps,p.numPaths,cfg.Ts*1e6);
    else
        report.messages{end+1} = sprintf(['Sampling rate does not resolve the %s profile: %d of %d ' ...
            'paths fall on distinct samples (Ts = %.3f us). Delay-resolution-dependent studies should use ' ...
            'ofdm_config(mode,''wide'').'], ...
            p.name,report.distinctRoundedTaps,p.numPaths,cfg.Ts*1e6);
    end
end

if abs(sum(p.powerLin)-1) > 1e-12
    report.pass = false;
    report.messages{end+1} = 'Channel powers are not normalized.';
end

if cfg.fdTuNominal > 0.1
    report.messages{end+1} = 'Nominal fdTu is outside the small-Doppler approximation range.';
end

fprintf('\n============================================================\n');
fprintf('CONFIGURATION VALIDATION | %s\n',cfg.mode);
fprintf('============================================================\n');
fprintf('fc                       : %.3f GHz\n',cfg.fc/1e9);
fprintf('velocity                 : %.2f km/h\n',cfg.velocity_kmh);
fprintf('fd                       : %.6f Hz\n',cfg.fd);
fprintf('Delta-f                  : %.3f kHz\n',cfg.deltaF/1e3);
fprintf('N                        : %d\n',cfg.N);
fprintf('Tu                       : %.6f us\n',cfg.Tu*1e6);
fprintf('fs                       : %.6f MHz\n',cfg.fs/1e6);
fprintf('CP                       : %d samples (%.6f us)\n',cfg.Ncp,cfg.Tcp*1e6);
fprintf('numerology               : %s\n',cfg.numerology);
fprintf('active TDL               : %s (%d paths)\n',p.name,p.numPaths);
fprintf('max delay                : %.6f us\n',maxDelay*1e6);
fprintf('delay model              : %s (Lhalf = %d)\n',cfg.delayModel,cfg.delayFilterHalfLength);
fprintf('resolved taps            : %d (span %d samples)\n',report.numTaps,report.tapSpanSamples);
fprintf('delay resolution         : %d/%d paths on distinct samples\n',report.distinctRoundedTaps,p.numPaths);
if cfg.grayMapping, labelName='Gray'; else, labelName='natural binary'; end
fprintf('constellation labelling  : %s\n',labelName);
fprintf('fd*Tu                    : %.8f\n',cfg.fdTuNominal);
fprintf('fd*Tsym                  : %.8f\n',cfg.fdTsymNominal);
otfsFrameSec = cfg.otfsM*(cfg.otfsN+cfg.otfsNcp)/cfg.fs;
otfsDopplerBinHz = 1/otfsFrameSec;
fprintf('OTFS frame               : %d delay x %d Doppler bins, %.0f us\n',cfg.otfsN,cfg.otfsM,otfsFrameSec*1e6);
fprintf('OTFS Doppler bin         : %.0f Hz -> nominal fd = %.2f bins\n',otfsDopplerBinHz,cfg.fd/otfsDopplerBinHz);
otfsL=cfg.otfsN*cfg.otfsM;
fprintf('OTFS DD length           : %d symbols per frame\n',otfsL);
if otfsL>8192
    report.messages{end+1}=sprintf(['OTFS frame holds %d DD symbols. Full-MMSE detection is O(L^3) ' ...
        'and will dominate the run time; consider reducing cfg.otfsM or dropping the linear-MMSE ' ...
        'reference from the detector study.'],otfsL);
end
if cfg.fd/otfsDopplerBinHz < 1
    report.messages{end+1}=sprintf(['OTFS Doppler is unresolved (%.2f bins): it is purely fractional, so every path ' ...
        'spreads across the whole Doppler axis and the delay-Doppler operator stops being sparse. ' ...
        'Message-passing detection is not valid in that regime - increase cfg.otfsM.'],cfg.fd/otfsDopplerBinHz);
end
if cfg.Ncp >= report.tapSpanSamples, fprintf('[PASS] CP covers the resolved tap span.\n'); end
if abs(sum(p.powerLin)-1) <= 1e-12, fprintf('[PASS] Active profile power is normalized.\n'); end
if cfg.fdTuNominal <= 0.1, fprintf('[PASS] Nominal Doppler is compatible with the small-Doppler study.\n'); end
if ~isempty(report.messages)
    fprintf('[WARN] Configuration notes:\n');
    for ii=1:numel(report.messages), fprintf('       - %s\n',report.messages{ii}); end
end
if report.pass
    fprintf('[PASS] Configuration is internally consistent.\n');
else
    fprintf('[FAIL] Configuration validation failed.\n');
    disp(report.messages(:));
    error('Configuration validation failed.');
end
end


