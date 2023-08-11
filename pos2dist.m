function [d1,d2] = pos2dist(point1,point2)
% Distance:
% d1: distance in km based on Haversine formula
% d2: distance in km based on Pythagoras theorem

% Inputs:
%   point1: lat lon of origin point [lat lon]
%   point2: lat lon of destination point [lat lon]
%
% Outputs:
%   d1: distance calculated by Haversine formula
%   d2: distance calculated based on Pythagoran theorem
%
% Example 1, short distance:
%   point1 = [-43 172];
%   point2 = [-44 171];
%   [d1 d2] = pos2dist(point1,point2)
%   d1 =
%           137.365669065197 (km)
%   d2 =
%           137.368179013869 (km)
%
% Example 2, longer distance:
%   point1 = [-43 172];
%   point2 = [20 -108];
%   [d1 d2] = pos2dist(point1,point2)
%   d1 =
%           10734.8931427602 (km)
%   d2 =
%           31303.4535270825 (km)

radius = 6371; % Earth radius

lat1 = point1(1)*pi/180;
lat2 = point2(1)*pi/180;
lon1 = point1(2)*pi/180;
lon2 = point2(2)*pi/180;

deltaLat = lat2-lat1;
deltaLon = lon2-lon1;

a = sin((deltaLat)/2)^2 + cos(lat1)*cos(lat2) * sin(deltaLon/2)^2;
c = 2*atan2(sqrt(a),sqrt(1-a));

x = deltaLon*cos((lat1+lat2)/2);
y = deltaLat;

d1 = radius*c; % Haversine distance
d2 = radius*sqrt(x*x + y*y); % Pythagoran distance

end