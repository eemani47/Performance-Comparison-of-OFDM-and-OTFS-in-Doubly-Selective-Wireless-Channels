function varargout = estimation_receiver(mode,varargin)
mode=lower(char(mode));
switch mode
case 'channel_estimation'
    if nargout==0
        channelXestimationXchannel_estimation(varargin{:});
    else
        [varargout{1:nargout}] = channelXestimationXchannel_estimation(varargin{:});
    end
case 'equalizers'
    if nargout==0
        equalizersXequalizers(varargin{:});
    else
        [varargout{1:nargout}] = equalizersXequalizers(varargin{:});
    end
case 'ici_model'
    if nargout==0
        iciXmodelXici_model(varargin{:});
    else
        [varargout{1:nargout}] = iciXmodelXici_model(varargin{:});
    end
otherwise
    error('Unknown mode %s for %s.',mode,mfilename);
end
end

function varargout = channelXestimationXchannel_estimation(mode,varargin)

switch lower(mode)
    case 'pilot_grid'
        [varargout{1:nargout}] = channelXestimationXpilot_grid(varargin{:});
    case 'ls'
        varargout{1} = channelXestimationXls_est(varargin{:});
    case 'dft'
        varargout{1} = channelXestimationXdft_est(varargin{:});
    case 'lmmse'
        varargout{1} = channelXestimationXlmmse_est(varargin{:});
    case 'lmmse_pilot'
        varargout{1} = channelXestimationXlmmse_pilot(varargin{:});
    case 'kalman'
        [varargout{1:nargout}] = channelXestimationXkalman_vector(varargin{:});
    case 'bem'
        [varargout{1:nargout}] = channelXestimationXbem_est(varargin{:});
    case 'crlb'
        varargout{1} = channelXestimationXclassical_crlb(varargin{:});
    case 'bayes_crlb'
        varargout{1} = channelXestimationXbayesian_crlb(varargin{:});
    otherwise
        error('Unknown estimator mode: %s',mode);
end
end

function [pilotIdx,dataIdx,pilotValues] = channelXestimationXpilot_grid(N,spacing,value)
pilotIdx = (1:spacing:N).';
dataIdx = setdiff((1:N).',pilotIdx);
pilotValues = repmat(value,numel(pilotIdx),1);
end

function H = channelXestimationXls_est(Y,X,pilotIdx)
Y = Y(:); X = X(:); pilotIdx = pilotIdx(:);
Hp = Y(pilotIdx)./X(pilotIdx);
H = interp1(pilotIdx,Hp,(1:numel(Y)).','linear','extrap');
H = H(:);
end

function H = channelXestimationXdft_est(Hls,maxTap)
Hls = Hls(:); N = numel(Hls);
maxTap = min(max(1,round(maxTap)),N);
h = ifft(Hls,N);
h(maxTap+1:end) = 0;
H = fft(h,N);
H = H(:);
end

function H = channelXestimationXlmmse_est(Hls,Rhh,sigX2,sigW2)
Hls = Hls(:);
Rhh = (Rhh+Rhh')/2;
Rhh = Rhh + 1e-10*trace(Rhh)/size(Rhh,1)*eye(size(Rhh));
regularizedNoise = max(real(sigW2)/max(real(sigX2),eps),eps);
H = Rhh*((Rhh + regularizedNoise*eye(size(Rhh)))\Hls);
H = H(:);
end

function H = channelXestimationXlmmse_pilot(z,pilotIdx,Rhh,pilotPower,sigW2)
z=z(:); pilotIdx=pilotIdx(:);
Rhh=(Rhh+Rhh')/2;
sig = max(real(sigW2)/max(real(pilotPower),eps),eps);
Rhp = Rhh(:,pilotIdx);
Rpp = Rhh(pilotIdx,pilotIdx) + sig*eye(numel(pilotIdx));
H = Rhp*(Rpp\z);
H = H(:);
end

function [Hhat,P,K] = channelXestimationXkalman_vector(z,H0,P0,alpha,qCov,rCov)

H0 = H0(:); z = z(:); N = numel(H0);
if nargin<3 || isempty(P0), P0 = eye(N); end
if isscalar(P0), P0 = P0*eye(N); end
if nargin<4 || isempty(alpha), alpha = 0.99; end
if nargin<5 || isempty(qCov), qCov = (1-abs(alpha)^2)*P0; end
if isscalar(qCov), qCov = qCov*eye(N); end
if nargin<6 || isempty(rCov), rCov = 1e-3; end

alpha = alpha(1);
A = alpha*eye(N);
P0 = (P0+P0')/2;
Q = (qCov+qCov')/2;

obs = find(isfinite(z));
if isempty(obs)
    Hhat = A*H0;
    P = A*P0*A' + Q;
    K = zeros(N,0);
    return;
end

C = zeros(numel(obs),N);
for k=1:numel(obs), C(k,obs(k)) = 1; end
R = channelXestimationXnormalize_measurement_cov(rCov,numel(obs));

Hpred = A*H0;
Ppred = A*P0*A' + Q;
Ppred = (Ppred+Ppred')/2;

innov = z(obs)-C*Hpred;
S = C*Ppred*C' + R;
S = (S+S')/2 + 1e-12*eye(size(S));
K = (Ppred*C')/S;
Hhat = Hpred + K*innov;
I = eye(N);
P = (I-K*C)*Ppred*(I-K*C)' + K*R*K';
P = (P+P')/2;
end

function R = channelXestimationXnormalize_measurement_cov(rCov,nObs)
if isscalar(rCov)
    R = real(rCov)*eye(nObs);
elseif isvector(rCov)
    rCov = real(rCov(:));
    if numel(rCov)~=nObs
        error('Measurement variance vector has %d entries, expected %d.',numel(rCov),nObs);
    end
    R = diag(rCov);
else
    R = real(rCov);
    if any(size(R)~=[nObs nObs])
        error('Measurement covariance must be scalar, vector, or %d-by-%d.',nObs,nObs);
    end
end
R = R + 1e-12*eye(nObs);
end

function [Hhat,coeff,nmse] = channelXestimationXbem_est(h,Q)
h = squeeze(h);
if isvector(h), h=h(:); end
[Ns,L] = size(h);
n = (0:Ns-1).'; q = (-Q:Q);
B = exp(1j*2*pi*(n*q)/Ns);
coeff = zeros(2*Q+1,L);
Hhat = zeros(size(h));
for ell=1:L
    coeff(:,ell) = B\h(:,ell);
    Hhat(:,ell) = B*coeff(:,ell);
end
num = mean(abs(h-Hhat).^2,1);
den = max(mean(abs(h).^2,1),eps);
nmse = num./den;
end

function c = channelXestimationXclassical_crlb(pilotValues,noiseVar)
pilotValues = pilotValues(:);
c = real(noiseVar)./max(abs(pilotValues).^2,eps);
end

function C = channelXestimationXbayesian_crlb(pilotIdx,pilotValues,noiseVar,Rhh,N)

if nargin<5 || isempty(N), N = size(Rhh,1); end
Rhh = (Rhh+Rhh')/2;
Rhh = Rhh + 1e-10*trace(Rhh)/N*eye(N);
info = pinv(Rhh);
for k=1:numel(pilotIdx)
    idx = pilotIdx(k);
    rv = real(noiseVar)/max(abs(pilotValues(k))^2,eps);
    info(idx,idx) = info(idx,idx) + 1/max(rv,eps);
end
C = pinv((info+info')/2);
C = real(diag(C));
end


function [Xhat,info]=equalizersXequalizers(mode,H,Y,noiseVar,B,varargin)

info=struct('iterations',NaN,'relResidual',NaN,'converged',true);
switch lower(mode)
    case 'zf'
        d=diag(H); d(abs(d)<1e-12)=1e-12;
        Xhat=Y(:)./d;
    case 'mmse'
        N=size(H,2); A=H'*H+max(real(noiseVar),1e-12)*eye(N);
        Xhat=A\(H'*Y(:));
    case 'banded'
        if nargin<5 || isempty(B), B=4; end
        Hb=equalizersXband_matrix(H,B); N=size(H,1);
        A=Hb'*Hb+max(real(noiseVar),1e-12)*eye(N);
        Xhat=A\(Hb'*Y(:));
    case 'pic'
        if nargin<5 || isempty(B), B=4; end
        Xhat=equalizersXequalizers('banded',H,Y,noiseVar,B);
        D=diag(diag(H)); O=H-D;
        for it=1:4
            residual=Y(:)-O*Xhat;
            Xhat=equalizersXequalizers('zf',D,residual,noiseVar);
        end
    case 'bem_mmse'
        if nargin<5 || isempty(B), B=4; end
        Hb=equalizersXband_matrix(H,max(0,round(B))); N=size(H,2);
        A=Hb'*Hb+max(real(noiseVar),1e-12)*eye(N);
        Xhat=A\(Hb'*Y(:));
    case 'pcg_mmse'
        maxIter=20; tol=1e-6;
        if nargin>=5 && ~isempty(B), maxIter=round(B); end
        if ~isempty(varargin), tol=varargin{1}; end
        Hc=H; y=Y(:); N=size(Hc,2); reg=max(real(noiseVar),1e-12);
        Aop=@(x) Hc'*(Hc*x)+reg*x; b=Hc'*y;
        Xhat=zeros(N,1); r=b-Aop(Xhat); pvec=r; rsold=r'*r;
        info.iterations=0; info.relResidual=sqrt(real(rsold))/max(norm(b),eps); info.converged=false;
        if abs(rsold)<tol^2, info.converged=true; Xhat=Xhat(:); return; end
        for it=1:maxIter
            Ap=Aop(pvec); alpha=rsold/max(real(pvec'*Ap),eps); Xhat=Xhat+alpha*pvec;
            r=r-alpha*Ap; rsnew=r'*r; info.iterations=it;
            if sqrt(real(rsnew)) <= tol*max(norm(b),1), info.converged=true; break; end
            pvec=r+(rsnew/max(real(rsold),eps))*pvec; rsold=rsnew;
        end
        info.relResidual=norm(b-Aop(Xhat))/max(norm(b),eps);
    case 'runtime'
        reps=1e3;
        if ~isempty(varargin), reps=varargin{1}; end
        tic;
        for r=1:reps
            switch lower(B)
                case 'zf', equalizersXequalizers('zf',H,Y,noiseVar);
                case 'mmse', equalizersXequalizers('mmse',H,Y,noiseVar);
                otherwise, equalizersXequalizers('banded',H,Y,noiseVar,B);
            end
        end
        Xhat=toc/reps;
    otherwise
        error('Unknown equalizer mode %s.',mode);
end
Xhat=Xhat(:);
end

function Hb=equalizersXband_matrix(H,B)
N=size(H,1); Hb=zeros(size(H));
for k=1:N
    lo=max(1,k-B); hi=min(N,k+B);
    Hb(k,lo:hi)=H(k,lo:hi);
end
end


function varargout = iciXmodelXici_model(mode,varargin)

switch lower(mode)
    case 'metrics'
        [varargout{1:nargout}]=iciXmodelXici_metrics(varargin{:});
    case 'band'
        varargout{1}=iciXmodelXrequired_band(varargin{:});
    case 'theory'
        varargout{1}=iciXmodelXtheory(varargin{:});
    case 'bem'
        [varargout{1:nargout}]=iciXmodelXbem_fit(varargin{:});
    case 'bem_matrix'
        [varargout{1:nargout}]=iciXmodelXbem_matrix(varargin{:});
    case 'cancel'
        varargout{1}=iciXmodelXself_cancel(varargin{:});
    case 'cancel_metrics'
        [varargout{1:nargout}]=iciXmodelXcancel_metrics(varargin{:});
    otherwise
        error('Unknown ICI mode %s.',mode);
end
end

function [pD,pICI,ratioDb]=iciXmodelXici_metrics(H)
N=size(H,1);
D=diag(diag(H)); O=H-D;
pD  = sum(abs(diag(D)).^2)/N;      % mean desired power per subcarrier
pICI= sum(abs(O(:)).^2)/N;         % mean leaked power per subcarrier
ratioDb=10*log10(max(pICI,eps)/max(pD,eps));
end

function B=iciXmodelXrequired_band(H,energyFraction)
if nargin<2, energyFraction=0.99; end
N=size(H,1); E=abs(H).^2; total=sum(E(:));
energy=0;
for B=0:N-1
    energy=0;
    for k=1:N
        lo=max(1,k-B); hi=min(N,k+B);
        energy=energy+sum(E(k,lo:hi));
    end
    if energy/max(total,eps)>=energyFraction, return; end
end
end

function v=iciXmodelXtheory(fdTu,secondMomentRatio)
if nargin<2 || isempty(secondMomentRatio), secondMomentRatio=0.5; end
v=(pi^2/3)*secondMomentRatio*(fdTu.^2);
end

function [Hhat,C,nmse]=iciXmodelXbem_fit(h,Q)
h=squeeze(h); if isvector(h), h=h(:); end
[Ns,L]=size(h); n=(0:Ns-1).'; q=-Q:Q;
B=exp(1j*2*pi*(n*q)/Ns);
C=zeros(2*Q+1,L); Hhat=zeros(size(h));
for ell=1:L
    C(:,ell)=B\h(:,ell);
    Hhat(:,ell)=B*C(:,ell);
end
nmse=mean(abs(h-Hhat).^2,1)./max(mean(abs(h).^2,1),eps);
end

function [HB,C,nmse]=iciXmodelXbem_matrix(h,delays,N,Ncp,fs,Q)
[HB,C,nmse]=iciXmodelXbem_fit(h,Q);
HB=HB(:,1:numel(delays));
HBmat=physical_core('channel_model','matrix',HB,delays,N,Ncp,fs);
HB=HBmat;
end

function y=iciXmodelXself_cancel(X)
X=X(:); y=zeros(size(X));
for k=1:2:numel(X)-1
    a=(X(k)-X(k+1))/2;
    y(k)=a; y(k+1)=-a;
end
end


function [beforeDb,afterDb,deltaDb,rateLoss] = iciXmodelXcancel_metrics(H)
N=size(H,1); M=floor(N/2); G=zeros(N,M);
for m=1:M
    G(2*m-1,m)=1/sqrt(2);
    G(2*m,m)=-1/sqrt(2);
end
Heff=G'*H*G; D0=diag(diag(H)); O0=H-D0;
De=diag(diag(Heff)); Oe=Heff-De;
beforeDb=10*log10(max(sum(abs(O0(:)).^2)/N,eps)/max(sum(abs(diag(D0)).^2)/N,eps));
afterDb =10*log10(max(sum(abs(Oe(:)).^2)/M,eps)/max(sum(abs(diag(De)).^2)/M,eps));
deltaDb=beforeDb-afterDb; rateLoss=1-(M/N);
end


