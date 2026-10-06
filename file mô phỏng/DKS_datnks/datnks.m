clc; clear; close all;
% thong so VOC

wnom=2*pi*50;
Vmax=61*sqrt(2);
Ve=60*sqrt(2);
Pe1=48;
Pe2=24;
Qe1=0;
Qe2=0;
trise=0.01;
dentaw=pi/6;
kv=Vmax/sqrt(2);
ki1=Ve/(sqrt(2)*Pe1);
ki2=Ve/(sqrt(2)*Pe2);

anpha=Vmax^3/(2*Ve*Vmax^2-2*Ve^3);
o=2*anpha;
Cmax=anpha*trise/3;
Cmin=Vmax*Qe1/(2*Pe1*Ve*dentaw);
if Cmax>=Cmin
C=(Cmax+Cmin)/2;
else 
    C=Cmin;
end


Rf=0.5;
L=1.3e-3;
% 0.5e-3;
Cf=20e-6;  
%8e-6;
Udc=100;
%Rf = 0.993;
%L = 3.9714e-3;
%Cf = 8.2e-6;
wh=2*pi*50;
s=tf('s');
fsw = 10e3;
Gim=1/(Rf+s*L);% ham truyen mach vong dong dien
wci=2*pi*2000;  % tần số cắt mạch vòng dòng điện
wc2=2*pi*400;%tần số cắt mạch vòng điện áp
[mag1,pha1]=bode(Gim,wci);
PM=60;
pha2=PM-pha1-180;
% bo PI
kpi=(1/mag1)*sqrt(1/(1+tan(pha2*pi/180)^2));
kii=-kpi*tan(pha2*pi/180)*wci;
% bo PR
kpri1=(1/mag1)*sqrt(1/(1+tan(pha2*pi/180)^2));
kiri1=tan(pha2*pi/180)*kpri1*(wh^2-wci^2)/wci;
%Gi1=kpri1+kiri1*s/(s^2+wh^2);
Gi1= kpi+kii/s;
[num1,den1]=tfdata(Gi1,'v');
G5=Gi1*Gim;
bode(G5)
grid on


% tong hop mach vong dien ap
PM1=60;
Giv=1/(Cf*s);
[mag3,pha3]=bode(Giv,wc2);
pha4=PM1-pha3-180;
%kpv=1/(mag3*sqrt(1+tan(pha4*pi/180)^2));
%kiv=-kpv*tan(pha4*pi/180)*wc2;
%Gv1=kpv+kiv/s;
kprv1=(1/mag3)*sqrt(1/(1+tan(pha4*pi/180)^2));
kirv1=tan(pha4*pi/180)*kprv1*(wh^2-wc2^2)/wc2;
Gv1=kprv1+kirv1*s/(s^2+wh^2);

[num2,den2]=tfdata(Gv1,'v');

Ts=1/20000;
% C funtion cho Pi dong
c1=1; % he so di voi uk-1
c2=kpi+kii*Ts/2; % he do di voi ek
c3=kii*Ts/2-kpi; % he so di voi ek-1
% roi rac hoa bdk dien ap
Ts1=1/20000;

%b1=(8-2*(wh^2)*(Ts1^2))/(4+(wh^2)*(Ts1^2)); % he so y_k_1
%b2=-1; % he so y_k_2
%b3=(4*kprv1+kprv1*wh^2*Ts1^2+2*kirv1*Ts1)/(4+wh^2*Ts1^2); %he so u_k
%b4=(-8*kprv1+2*kprv1*wh^2*Ts1^2)/(4+wh^2*Ts1^2); % he so u_k_1
%b5=(4*kprv1+kprv1*wh^2*Ts1^2-2*kirv1*Ts1)/(4+wh^2*Ts1^2); %he so u_k_2


b1=2-(wh*Ts1)^2; % he so y_k_1
b2=-1; % he so y_k_2
b3=kprv1; %he so u_k
b4=kirv1*Ts1+kprv1*((wh*Ts1)^2-2); % he so u_k_1
b5=kprv1-kirv1*Ts1; %he so u_k_2


% bo dk dong pr
a1=(8-2*(wh^2)*(Ts^2))/(4+(wh^2)*(Ts^2)); % he so y_k_1
a2=-1; % he so y_k_2
a3=(4*kpri1+kpri1*(wh^2)*(Ts^2)+2*kiri1*Ts)/(4+(wh^2)*(Ts^2)); %he so u_k
a4=(-8*kpri1+2*kpri1*(wh^2)*(Ts^2))/(4+(wh^2)*(Ts^2)); % he so u_k_1
a5=(4*kpri1+kpri1*(wh^2)*(Ts^2)-2*kiri1*Ts)/(4+(wh^2)*(Ts^2)); %he so u_k_2

Gu1=c2d(Gi1, Ts,'tustin');
[num_nz1, den_nz1]= tfdata(Gu1,'v');
Gu2=c2d(Gv1, Ts1,'tustin');
[num_nz2, den_nz2]= tfdata(Gu2,'v');
