% Run transient model adjusting elevation as we go
% simple approximation for dsmb with basin weights

clear
tic
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Parameters
flg_weigh = 1;
flg_match = 0;

% 0=initMIP; 1=MIROC8.5; 2=NorESM8.5; 3=CANSM8.5; 4=MIROC4.5; 5=M37 MIROC8.5;
% 6=MAR39 MIROC8.5
iscen = 7;

% flag for type t0 t2
flg_t=0;
%flg_t=2;
%flg_t=3;
%flg_t=5;

% flag for plotting 
flg_plot=0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

load cmap_dsmb

colors=get(0,'DefaultAxesColorOrder');

% basin definition
load(['../Data/Basins/ExtBasinMasks25_05000m.mat']);
x1 = 1:size(bas.basinIDs,1);
y1 = 1:size(bas.basinIDs,2);
nb = length(bas.ids);
[y,x] = meshgrid(y1,x1);

% area factors
da = ncload('../Data/Grid/af2_ISMIP6_GrIS_05000m.nc');
af2 = double(da.af2(:,:));

% dim
dx=5000;dy=5000;

% param
secpyear = 31556926;
rhof = 1000;
rhoi = 910;

% basin weights
load(['../Data/Basins/ExtBasinScale25_nn7_50_05000m.mat'], 'wbas');

% MAR39
if (iscen == 6)
    d0=load('../Data/MAR/trans_DSMB_MARv3.9_MIROC5_rcp85.mat');
    load trans_lookup_MAR39_MIROC5_rcp85_b25
    modscen='M39_MIROC5_rcp85';
end
% ISMIP6
if (iscen == 7)
    d0=ncload(['../Data/RCM/aSMB_MARv3.9-yearly-MIROC5-rcp85-2015-2100_05000m.nc']);
    d1=ncload(['../Data/RCM/dSMBdz_MARv3.9-yearly-MIROC5-rcp85-2015-2100_05000m.nc']);
    % lookup table 
    lookup = ncload(['../Data/lookup/TaSMB_trans_lookup_b25_MARv3.9-MIROC5-rcp85.nc']);
    modscen='M39_MIROC5-rcp85';
end

% dummy lookup for zero
dummy0 = lookup.aSMB_ltbl(:,1,1);

% load initmip models
load ../Data/initMIP/fi_A5.mat

% fix JPL
ix = find(isnan(fi.init{19}.orog));
fi.init{19}.orog(ix) = 0;

ix = find((fi.init{19}.sftgif)<0.);
fi.init{19}.sftgif(ix) = 0;

for m=1:fi.n
%for m=2:33
%for m=19

    amod = fi.igrpmod{m}
    
    %% load data
    mask = fi.init{m}.sftgif;
    sur = fi.init{m}.orog;
    sur(isnan(sur)) = 0.;
    sur_re = sur;
    sur0 = sur;
    thi = fi.init{m}.lithk.*mask;
    thi(isnan(thi)) = 0.;
    thi_re = thi;
    bed = sur-thi;
    

    nt=length(lookup.time);

    bint_re=zeros(nb,nt);

    %% output array
    tdsmb_re=zeros(size(d0.aSMB));
    tsur=zeros(size(d0.aSMB));
    tsur_re=zeros(size(d0.aSMB));

    %for t=1 % year loop
    for t=1:nt % year loop

        dsd=d0.aSMB(:,:,t) * secpyear / rhof;
        dsd_re=zeros(size(dsd));

        %% loop through basins
        for b=1:nb
            %% set current basin and lookup
% Determine surface to calculate remapping on
            if(flg_t==0)
                %% sur0: constant sur
                eval(['sur_b=sur0.*(bas.basin' num2str(b) './bas.basin' num2str(b) ');']);
                eval(['ima_b=mask.*(bas.basin' num2str(b) './bas.basin' num2str(b) ');']);
            elseif(flg_t==1)
                %% sur: sur changing with MAR DSMB
                eval(['sur_b=sur.*(bas.basin' num2str(b) './bas.basin' num2str(b) ');']);
                eval(['ima_b=mask.*(bas.basin' num2str(b) './bas.basin' num2str(b) ');']);
            elseif(flg_t==2)
                %% sur_re: sur changing with remapped MAR DSMB
                eval(['sur_b=sur_re.*(bas.basin' num2str(b) './bas.basin' num2str(b) ');']);
                eval(['ima_b=mask.*(bas.basin' num2str(b) './bas.basin' num2str(b) ');']);
            elseif(flg_t==3)
                %% sur0: constant sur + dSMB/dz (below)
                eval(['sur_b=sur0.*(bas.basin' num2str(b) './bas.basin' num2str(b) ');']);
                eval(['ima_b=mask.*(bas.basin' num2str(b) './bas.basin' num2str(b) ');']);
            elseif(flg_t==4)
                %% sur: sur changing with MAR DSMB + dSMB/dz (below)
                eval(['sur_b=sur.*(bas.basin' num2str(b) './bas.basin' num2str(b) ');']);
                eval(['ima_b=mask.*(bas.basin' num2str(b) './bas.basin' num2str(b) ');']);
            elseif(flg_t==5)
                %% sur_re: sur changing with remapped MAR DSMB + dSMB/dz (below)
                eval(['sur_b=sur_re.*(bas.basin' num2str(b) './bas.basin' num2str(b) ');']);
                eval(['ima_b=mask.*(bas.basin' num2str(b) './bas.basin' num2str(b) ');']);
            else
                disp(['Warning: not an option for flg_t=', num2str(flg_t) ])
                return;
            end

            look0=lookup.aSMB_ltbl(:,wbas.n0(b),t);
            %% set neighbor basin and lookup
            look0 = dummy0;
            if (wbas.n0(b)>0)
                look0=lookup.aSMB_ltbl(:,wbas.n0(b),t);
            end
            look1 = dummy0;
            if (wbas.n1(b)>0)
                look1=lookup.aSMB_ltbl(:,wbas.n1(b),t);
            end
            look2 = dummy0;
            if (wbas.n2(b)>0)
                look2=lookup.aSMB_ltbl(:,wbas.n2(b),t);
            end
            look3 = dummy0;
            if (wbas.n3(b)>0)
                look3=lookup.aSMB_ltbl(:,wbas.n3(b),t);
            end
            look4 = dummy0;
            if (wbas.n4(b)>0)
                look4=lookup.aSMB_ltbl(:,wbas.n4(b),t);
            end
            look5 = dummy0;
            if (wbas.n5(b)>0)
                look5=lookup.aSMB_ltbl(:,wbas.n5(b),t);
            end
            look6 = dummy0;
            if (wbas.n6(b)>0)
                look6=lookup.aSMB_ltbl(:,wbas.n6(b),t);
            end
            %% use lookup table to determine DSMB
            dsd_b0 = interp1(lookup.z,look0(:),sur_b);
            dsd_b1 = interp1(lookup.z,look1(:),sur_b);
            dsd_b2 = interp1(lookup.z,look2(:),sur_b);
            dsd_b3 = interp1(lookup.z,look3(:),sur_b);
            dsd_b4 = interp1(lookup.z,look4(:),sur_b);
            dsd_b5 = interp1(lookup.z,look5(:),sur_b);
            dsd_b6 = interp1(lookup.z,look6(:),sur_b);

            if (flg_weigh == 0)
                %% combine according to weights
                dsd_b = dsd_b0.*wbas.wg;
            else
                dsd_b = dsd_b0.*wbas.wgc0 + dsd_b1.*wbas.wgc1 + dsd_b2.*wbas.wgc2 + dsd_b3.*wbas.wgc3 + dsd_b4.*wbas.wgc4 + dsd_b5.*wbas.wgc5 + dsd_b6.*wbas.wgc6;
            end
%    shade(dsd_b)

            %% extended integral dsmb for this basin
            dsd_ex = dsd.*ima_b;
            bint_ex(b)=nansum(nansum(dsd_ex.*af2))*dx*dy;
            
            %% mask
            dsd_b = dsd_b.*mask;

            %% integral dsmb for this basin
            bint_re(b)=nansum(nansum(dsd_b.*af2))*dx*dy;

            if (flg_match == 1)        
                %% adjust to match total
                dsd_b = dsd_b * (lookup.bint(b)/bint_re(b));
            end
            
            %% check integral again 
            bint_out(b)=nansum(nansum(dsd_b.*af2))*dx*dy;

            %% replace nan by zeros to add all basins together
            dsd_b(isnan(dsd_b))=0;
            dsd_re = dsd_re+dsd_b;

        end
        %% end basin loop

        if(flg_t==3 | flg_t==4 | flg_t==5 )
            %% dSMB/dz
            dsmb = d0.TdSMBdz(:,:,t) .* (sur-sur0);
            dsmb_re = d0.TdSMBdz(:,:,t) .* (sur_re-sur0);
            dsd = dsd + dsmb;
            dsd_re = dsd_re + dsmb_re;
        end
        
        dsd_re = dsd_re * secpyear / rhof * rhof/rhoi;

        %% update surface elevation
        thi_re = max(thi_re + dsd_re, 0);
        sur_re = bed + thi_re;
        thi = max(thi + dsd, 0);
        sur = bed + thi;
        tsur_re(:,:,t) = sur_re;
        tsur(:,:,t) = sur;

        %% collect results
        tdsmb_re(:,:,t) = dsd_re;    


        if (flg_plot) 
            shade_bg(dsd_re)
            colormap(cmap)
            caxis([-4,1])
            print('-dpng', '-r300', ['dsmb_' modscen '_re' sprintf('%02d',t)]) 
            close
            shade_bg(dsd.*mask)
            colormap(cmap)
            caxis([-4,1])
            print('-dpng', '-r300', ['dsmb_' modscen '_or' sprintf('%02d',t)]) 
            close
        end


    end
    %% end time loop

    if(flg_t==0)
        save(['../Data/initMIP/transient0_' modscen, '_' amod],'tsur_re','tsur')
    elseif(flg_t==1)
        save(['../Data/initMIP/transient1_' modscen, '_' amod],'tsur_re','tsur')
    elseif(flg_t==2)
        save(['../Data/initMIP/transient2_' modscen, '_' amod],'tsur_re','tsur')
    elseif(flg_t==3)
        save(['../Data/initMIP/transient3_' modscen, '_' amod],'tsur_re','tsur')
    elseif(flg_t==4)
        save(['../Data/initMIP/transient4_' modscen, '_' amod],'tsur_re','tsur')
    elseif(flg_t==5)
        save(['../Data/initMIP/transient5_' modscen, '_' amod],'tsur_re','tsur')
    end

end
%% model loop
toc
