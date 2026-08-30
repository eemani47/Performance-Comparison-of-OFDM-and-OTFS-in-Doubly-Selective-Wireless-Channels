function varargout=mimo_resource_allocation(mode,varargin)
switch lower(mode)
    case 'waterfill'
        [varargout{1:nargout}]=waterfill(varargin{:});
    case 'joint_waterfill'
        [varargout{1:nargout}]=waterfill(varargin{:});
    case 'robust_waterfill'
        [varargout{1:nargout}]=robust_waterfill(varargin{:});
    case 'capacity'
        varargout{1}=capacity(varargin{:});
    case 'qam_ceiling'
        varargout{1}=qam_ceiling(varargin{:});
    otherwise
        error('Unknown resource-allocation mode %s.',mode);
end
end

function [p,mu,capacityBits] = waterfill(gain,totalPower,noiseVar)
gain=max(real(gain(:)),eps); totalPower=max(real(totalPower),0); noiseVar=max(real(noiseVar),eps);
if totalPower==0, p=zeros(size(gain)); mu=0; capacityBits=0; return; end
lo=0; hi=max(noiseVar./gain)+totalPower+1;
for it=1:100
    mu=(lo+hi)/2; p=max(mu-noiseVar./gain,0);
    if sum(p)>totalPower, hi=mu; else, lo=mu; end
end
mu=(lo+hi)/2; p=max(mu-noiseVar./gain,0);
if sum(p)>0
    res=totalPower-sum(p); active=p>0;
    if any(active) && abs(res)>1e-12*max(totalPower,1), p(active)=p(active)+res/sum(active); end
end
capacityBits=sum(log2(1+gain.*p/noiseVar));
end

function [p,mu,C]=robust_waterfill(gain,totalPower,noiseVar,relUncertainty)
gain=max(real(gain(:)),eps); u=min(max(real(relUncertainty),0),0.99); worstGain=gain*(1-u).^2;
[p,mu,C]=waterfill(worstGain,totalPower,noiseVar);
end

function C=capacity(gain,p,noiseVar)
gain=max(real(gain(:)),eps); p=max(real(p(:)),0); C=sum(log2(1+gain.*p/max(real(noiseVar),eps)));
end

function eta=qam_ceiling(snrLinear,M)
eta=min(log2(1+max(real(snrLinear(:)),0)),log2(M));
end
