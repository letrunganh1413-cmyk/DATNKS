clc; clear; close all;
% thong so VOC

wnom=2*pi*50;
Vmax=61*sqrt(2);
Ve=60*sqrt(2);
Pe1=36;
Pe2=36;
Qe1=0;
Qe2=0;
trise=0.05;
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



% tổng hợp bộ bù lead cho dòng điện

fc=1800; % tần số cắt mạch vòng dòng điện
theta=60;% tính pha bộ bù
fz=fc*sqrt((1-sin(theta*pi/180))/(1+sin(theta*pi/180)));
fp=fc*sqrt((1+sin(theta*pi/180))/(1-sin(theta*pi/180)));
%tinh toan bo bu Lead (PD)
numc=[1/(2*pi*fz) 1];
denc=[1/(2*pi*fp) 1];
Gc1=tf(numc,denc);  %*tf([1 2*pi*fl],[1 0]);

% Thông số hệ thống
R = 48.4;
Rf = 0.3;
L = 1.3e-3;
Cf = 20e-6;
Udc = 100;
if Udc==100
sw=1;
sw1=1;
sw2=20;
else 
    sw=4;
    sw1=20;
    sw2=1;
end

s = tf('s');
fsw = 10e3;
wh=2*pi*50;


% Định nghĩa hàm truyền không có trễ
G = 1 / (Rf + s * L);

% Xấp xỉ trễ bằng chuỗi Padé bậc 1
Td = (0.75e-4);  
[num, den] = pade(Td, 1);
Delay_Pade = tf(num, den);

% Hàm truyền có trễ
G_delay = G * Delay_Pade*Gc1;
%G_delay = G * Delay_Pade;
% Tần số cần khảo sát (rad/s)
w_target = 2 * pi *1800 ;    %1000
wci=w_target ;
% Tính magnitude và phase tại tần số w_target
[mag1, phase1] = bode(G , w_target);

[mag2, phase2] = bode(G_delay, w_target);


% Chuyển kết quả thành giá trị vô hướng
mag1 = squeeze(mag1);
mag2 = squeeze(mag2);
phase1 = squeeze(phase1);
phase2 = squeeze(phase2);

% Điều chỉnh pha về khoảng [-180, 0]
phase1 = mod(phase1, -360);
phase2 = mod(phase2, -360);

% pr dong
PM=60;
pha2=PM-phase2-180;
kpi=(1/mag2)*sqrt(1/(1+tan(pha2*pi/180)^2));
kii=-kpi*tan(pha2*pi/180)*wci;




kpri1=(1/mag2)*sqrt(1/(1+tan(pha2*pi/180)^2));
kiri1=tan(pha2*pi/180)*kpri1*(wh^2-wci^2)/wci;
Gi1=kpi+(kii)/s;
%Gi1=kpri1+kiri1*s/(s^2+wh^2);
Gi3=kiri1*s/(s^2+(wh*3)^2)*0.87e-2;
Gi5=kiri1*s/(s^2+(wh*5)^2)*2.49e-2;
Gi7=kiri1*s/(s^2+(wh*7)^2)*0.27e-2;
Gi9=kiri1*s/(s^2+(wh*9)^2)*1.18e-2;
Gi11=kiri1*s/(s^2+(wh*11)^2)*1.73e-2;
Gi=Gi1+Gi3+Gi5+Gi7+Gi9+Gi11;

[num1,den1]=tfdata(Gi1*Gc1,'v');


% ---- VẼ ĐỒ THỊ BODE ----
% Dải tần số
w = logspace(1, 5, 1000000);  % Từ 10^1 đến 10^5 rad/s

% Tính Bode của hệ thống
[mag1_all, phase1_all] = bode(G* Delay_Pade , w);
[mag2_all, phase2_all] = bode(G * Delay_Pade*Gc1 , w);

% Chuyển kết quả thành vector
mag1_all = squeeze(mag1_all);
mag2_all = squeeze(mag2_all);
phase1_all = squeeze(phase1_all);
phase2_all = squeeze(phase2_all);

% Điều chỉnh pha về khoảng [-180, 0]
phase1_all = mod(phase1_all, -360);
phase2_all = phase2_all -360;

figure;

% Biểu đồ biên độ
subplot(2,1,1);
semilogx(w/(2*pi), 20*log10(mag1_all), 'b', 'LineWidth', 1.5); hold on;
semilogx(w/(2*pi), 20*log10(mag2_all), 'r', 'LineWidth', 1.5);
grid on;
xlabel('Tần số (Hz)');
ylabel('Biên độ (dB)');
legend('G(s)', 'G(s) có trễ ');

% Biểu đồ pha
subplot(2,1,2);
semilogx(w/(2*pi), phase1_all, 'b', 'LineWidth', 1.5); hold on;
semilogx(w/(2*pi), phase2_all, 'r', 'LineWidth', 1.5);
grid on;
xlabel('Tần số (Hz)');
ylabel('Pha (°)');
legend('G(s)', 'G(s) có trễ');
ylim([-180 180]); % Giới hạn trục pha từ 0 đến -180 độ
hold on
% In kết quả ra màn hình
fprintf('Tại tần số 1600 Hz (%.2f rad/s):\n', w_target);
fprintf(' - Pha của G(s) có trễ: %.2f°\n',phase1);
fprintf(' - Pha của G(s) có trễ thêm lead: %.2f°\n', phase2);

% bộ điều khiển áp nhá
fc2=200;
 %fl2=fc2/20;
theta2=20;%tinh pha bo bu 
fz2=fc2*sqrt((1-sin(theta2*pi/180))/(1+sin(theta2*pi/180)));
 fp2=fc2*sqrt((1+sin(theta2*pi/180))/(1-sin(theta2*pi/180)));
 %tinh toan bo bu Lead (PD)
 numc2=[1/(2*pi*fz2) 1];
 denc2=[1/(2*pi*fp2) 1];
 Gc12=tf(numc2,denc2); %*tf([1 2*pi*fl2],[1 0]);
 % Xấp xỉ trễ bằng chuỗi Padé bậc 1
Td2 = 1e-4;  
[num2, den2] = pade(Td2, 1);
Delay_Pade2 = tf(num2, den2);
%bo ap
 wc2=2*pi*500;
Giv=1/(Cf*s);
%G_delay2 = Giv * Delay_Pade2*Gc12;
Gik=G_delay*Gi1/(1+G_delay*Gi1);

G_delay2 = Giv;

[mag12, phase12] = bode(Giv, wc2);
[mag22, phase22] = bode(G_delay2, wc2);
% Chuyển kết quả thành giá trị vô hướng
mag12 = squeeze(mag12);
mag22 = squeeze(mag22);
phase12 = squeeze(phase12);
phase22 = squeeze(phase22);

% Điều chỉnh pha về khoảng [-180, 0]
phase12 = mod(phase12, -360);
phase22 = mod(phase22, -360);

% In kết quả ra màn hình
fprintf('Tại tần số 500 Hz (%.2f rad/s):\n', w_target);
fprintf(' - Pha của Giv(s) không trễ: %.2f°\n', phase12);
fprintf(' - Pha của Giv(s) có trễ: %.2f°\n', phase22);
pha4=PM-phase22-180;
kprv1=(1/mag22)*sqrt(1/(1+tan(pha4*pi/180)^2));
kirv1=tan(pha4*pi/180)*kprv1*(wh^2-wc2^2)/wc2;
Gv1=kprv1+(kirv1)*s/(s^2+wh^2);
%Gv1=kprv1+(2*(kirv1-10)*2)*s/(s^2+wh^2+ 2*2*s);
Gv3=kirv1*s/(s^2+(wh*3)^2)*0.001;
Gv5=kirv1*s/(s^2+(wh*5)^2)*2.9e-2;
Gv7=kirv1*s/(s^2+(wh*7)^2)*0.77e-2;
Gv9=kirv1*s/(s^2+(wh*9)^2)*1.31e-2;
Gv11=kirv1*s/(s^2+(wh*11)^2)*1.2e-2;
Gv=Gv1+Gv3;

[num2,den2]=tfdata(Gv1*Gc12,'v');
Ts=1/20000;
Ts1=1/20000;

%Gu2=c2d(Gv1*Gc12, Ts1,'tustin');
Gu2=c2d(Gv1, Ts1,'tustin');
[num_nz2, den_nz2]= tfdata(Gu2,'v');
% roi rac 1/s
Gu5=c2d(1/s,1/20000,'tustin');
[num_nz3, den_nz3]= tfdata(Gu5,'v');

b1=2-(wh*Ts1)^2; % he so y_k_1
b2=-1; % he so y_k_2
b3=kprv1; %he so u_k
b4=kirv1*Ts1+kprv1*((wh*Ts1)^2-2); % he so u_k_1
b5=kprv1-kirv1*Ts1; %he so u_k_2

%G1=c2d(Gi1*(1/Delay_Pade), Ts,'tustin');
G1=c2d(Gi1*Gc1, Ts,'tustin');
[num_nz1, den_nz1]= tfdata(G1,'v');
a1=(8-2*(wh^2)*(Ts^2))/(4+(wh^2)*(Ts^2)); % he so y_k_1
a2=-1; % he so y_k_2
a3=(4*kpri1+kpri1*(wh^2)*(Ts^2)+2*kiri1*Ts)/(4+(wh^2)*(Ts^2)); %he so u_k
a4=(-8*kpri1+2*kpri1*(wh^2)*(Ts^2))/(4+(wh^2)*(Ts^2)); % he so u_k_1
a5=(4*kpri1+kpri1*(wh^2)*(Ts^2)-2*kiri1*Ts)/(4+(wh^2)*(Ts^2)); %he so u_k_2


G_pilead=Gc1*Gi1;
[num_pilead, den_pilead] = tfdata(G_pilead, 'v');
m1 = num_pilead(1);
m2 = num_pilead(2);
m3 = num_pilead(3);

n1 = den_pilead(1);
n2 = den_pilead(2);
n3 = den_pilead(3);

m4 = (4*m1/Ts^2+2*m2/Ts+m3)/(4*n1/Ts^2+2*n2/Ts+n3);
m5 = (-8*m1/Ts^2+2*m3)/(4*n1/Ts^2+2*n2/Ts+n3);
m6 = (4*m1/Ts^2-2*m2/Ts+m3)/(4*n1/Ts^2+2*n2/Ts+n3);

n5 = -(-8*n1/Ts^2+2*n3)/(4*n1/Ts^2+2*n2/Ts+n3);
n6 = -(4*n1/Ts^2-2*n2/Ts+n3)/(4*n1/Ts^2+2*n2/Ts+n3);
% C funtion cho Pi dong
c1=1; % he so di voi uk-1
c2=kpi+kii*Ts/2; % he do di voi ek
c3=kii*Ts/2-kpi; % he so di voi ek-1
% khau vi phan dien ap tu C
T=(1/(2*pi*5000))^2;
x1=Cf/(T+Ts);
x2=T/(T+Ts);
