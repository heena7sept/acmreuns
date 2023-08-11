
%% Import and Align 
%Step 1: Import data from sample Tampa CV file
%Lines 5 - 8 show how "truncated" file was generated from original file 
%due to excessive length of original sample file for GitHub upload
% fileName='Tampa_CV_Pilot_Basic_Safety_Message__BSM__Sample.csv';
% carData=readtable(fileName);
% carDataShort=carData(1:5400,:);
% writetable(carDataShort,'Tampa_CV_SampleFileTimeTruncated.csv')
fileName='Tampa_CV_SampleFileTimeTruncated.csv';
carData=readtable(fileName);
%Step 2: Truncate into only things needed for this project
TimeofDayStamp=53;carTS=13;carID=12;posCol=51;speedCol=26;accelX=19;accelY=18;
carDataTrunc=carData(:,[TimeofDayStamp,carTS,carID,posCol,speedCol,accelX,accelY]);
carIDs=sort(unique(carData.coreData_id));
%Step 3: Seperate posCol into x and y
for k=1:height(carDataTrunc)
    currPosString=carDataTrunc.coreData_position{k};
    carDataTrunc.t(k)=carDataTrunc.metadata_generatedAt_timeOfDay(k)*60^2;
    newStr = split(currPosString,["("," ", ")"]);
    carDataTrunc.x(k)=str2num(newStr{3});
    carDataTrunc.y(k)=str2num(newStr{4});
end
carDataTrunc.coreData_position=[];
carDataTrunc.metadata_generatedAt_timeOfDay=[];
%fix timestamps
for j=1:length(carIDs)
singleCarData=carDataTrunc(carDataTrunc.coreData_id==carIDs(j),:);
singleCarData=sortrows(singleCarData,'coreData_secMark'); %sort by car time
t=singleCarData.t; %RSU Time
carT=singleCarData.coreData_secMark; %Car Time
singleCarData.t=t(1)*ones(length(t),1)+[carT-carT(1)]./1000;
carDataTrunc(carDataTrunc.coreData_id==carIDs(j),:)=singleCarData;
%scatter(singleCarData.x,singleCarData.y);hold on;
end
carDataTrunc=sortrows(carDataTrunc,"t");
carDataTrunc.coreData_secMark=[];
%truncate time 
tMax=4*60*60;
carDataTrunc=carDataTrunc(carDataTrunc.t<tMax,:);

%upsample data
% for m=1:length(carIDs)
%     carDataTruncCurrCar=carDataTrunc(carDataTrunc.coreData_id==carIDs(m),:);
%     
% end
% due to non-uniform time interval, begin by finding continuous reporting
% intervals for each car
%% form time intervals for each car
CarIDs=unique(carDataTrunc.coreData_id);
numCars=numel(CarIDs);
contThresh=1; %length of time for which car reporting is not considered continuous
for currCar=1:numCars
  tCurrCar=carDataTrunc(carDataTrunc.coreData_id==CarIDs(currCar),'t'); %full duration
  timeDisc=find(diff(tCurrCar.t)>0.5);
  currCarStartsInds(currCar)={[1;timeDisc+1]};
  currCarEndsInds(currCar)={[timeDisc;numel(tCurrCar.t)]};
end
%% Peer Report 
%can we add the peer measurement gimmick?
%add in "peer reported ID column" and "corrupted" column 
carDataTrunc.perReportID=carDataTrunc.coreData_id;
carDataTrunc.corrupted=zeros(height(carDataTrunc),1);
carDataTrunc.t=carDataTrunc.t-carDataTrunc.t(1);
carDataTrunc.peerReported=zeros(height(carDataTrunc),1);
%loop needs to go through in "time" as well
t=carDataTrunc.t;
minObsDur=4; %must be in observation for time seconds
tMin=t(1);tMax=max(t);numIts=1;
% currEndTime=tMin+minObsDur;currStartTime=tMin;
%Initialize start and stop time values
currStartTime=min(carDataTrunc.t);currEndTime=currStartTime+minObsDur;
% currStartTime=1665.3;currEndTime=currStartTime+minObsDur;

distThresh=1;carDataPeerReportedTotal=[];
while currEndTime<tMax
%     currStartTime;
%     currEndTime;
    %extract current observation window data
    carDataTruncCurrWin=carDataTrunc...
          (carDataTrunc.t>=currStartTime & ...
           carDataTrunc.t<=currEndTime,:);

    
    %throw away any cars not present the whole time
    currCars=unique(carDataTruncCurrWin.coreData_id);
    m=0; %used to count # of current cars
    for j=1:length(currCars)
        tCCGlobal=carDataTrunc(carDataTrunc.coreData_id==currCars(j),'t');
        tCC=carDataTruncCurrWin(carDataTruncCurrWin.coreData_id==currCars(j),'t');
        startInds=currCarStartsInds(find(CarIDs==currCars(j)));startInds=startInds{1};
        stopInds=currCarEndsInds(find(CarIDs==currCars(j)));stopInds=stopInds{1};
        startTimes=tCCGlobal.t(startInds);stopTimes=tCCGlobal.t(stopInds);
        CurrInd=max(find(currStartTime>=startTimes));
        tCCMin=tCCGlobal.t(startInds(CurrInd));
        tCCMax=tCCGlobal.t(stopInds(CurrInd));
        if (tCCMax-tCCMin)>=minObsDur
            currCarsAlwaysPresent(m+1)=currCars(j);%car is at every data point
            m=m+1;
        end
    end
    %m
    if m>1 %ie: if more than one car present whole time, make peer reports
        m;   
        for k=1:length(currCarsAlwaysPresent)
                % trajectory of current car in window
                xCurrCar=carDataTruncCurrWin...
                    {carDataTruncCurrWin.coreData_id==currCarsAlwaysPresent(k),'x'};
                yCurrCar=carDataTruncCurrWin...
                    {carDataTruncCurrWin.coreData_id==currCarsAlwaysPresent(k),'y'};
                
                % test proximity for every other car and make report
                otherCars=setdiff(currCarsAlwaysPresent,currCarsAlwaysPresent(k));
                for r=1:(length(currCarsAlwaysPresent)-1) %for every other car
                 xCurrOtherCar=carDataTruncCurrWin...
                    {carDataTruncCurrWin.coreData_id==otherCars(r),'x'};
                yCurrOtherCar=carDataTruncCurrWin...
                     {carDataTruncCurrWin.coreData_id==otherCars(r),'y'};
        %        scatter(xCurrCar,yCurrCar);hold on;
        %        scatter(xCurrOtherCar,yCurrOtherCar);
                %compute distance threshold
                postCC=[xCurrCar,yCurrCar];
                postOC=[xCurrOtherCar,yCurrOtherCar];
                for b=1:length(xCurrOtherCar)
                    [d1(b),d2(b)] = pos2dist(postCC(1,:),postOC(1,:));
                end
                    if max(d1)<distThresh
                        %make peer report
                        carDataPeerReportedAll=carDataTruncCurrWin...
                            (carDataTruncCurrWin.coreData_id==otherCars(r),:);
                        carDataPeerReportedLast=carDataPeerReportedAll(height(carDataPeerReportedAll),:);
                        carDataPeerReportedLast.perReportID=currCarsAlwaysPresent(k);%currCarsAlwaysPresent(k).*ones(6,1);
                        carDataPeerReportedLast.peerReported=1;
                        carDataPeerReportedTotal =...
                            [carDataPeerReportedTotal;carDataPeerReportedLast];
                    end
                end 
            end 
    end 
    %update times
    numIts=numIts+1;
    currStartTime=t(numIts);
    currEndTime=currStartTime+minObsDur;
    
    %clear some vaiables to avoid length issues...
    clearvars currCarsAlwaysPresent currCars d1 d2
    
end
%merge tables
carDataFinal=sortrows([carDataTrunc;carDataPeerReportedTotal],'t');
height(carDataFinal(carDataFinal.peerReported==1,:))

% scatter(carDataTrunc.x,carDataTrunc.y)
% hold on;scatter(carDataPeerReportedTotal.x,carDataPeerReportedTotal.y)
% xlabel('Longitude (deg.)','FontSize', 14,'FontName','Times');
% ylabel('Latitude (deg.)','FontSize', 14,'FontName','Times');
% legend('Self-Reported','Peer-Estimated',...
%     'FontSize', 14,'FontName','Times','Location','northwest')
% saveas(gcf,'TrajectoryFigSelfAndPeer.png')

%% perform corruption
perCarsBad=0.3;
carsFinal=unique(carDataFinal.coreData_id);
numCarsFinal=length(carsFinal);
numBadCars=round(perCarsBad*numCarsFinal); 
badCars=sort(randperm(numCarsFinal,numBadCars)); 

%to begin, corrupt "self-reports" for bad car
for k=1:length(badCars) %for each car
    %step 1: Extract data table for "bad" car self reports
%     currBadCar=carDataFinal(carDataFinal.id==carsFinal(badCars(k))...
%                              & carDataFinal.perReportID==carsFinal(badCars(k)),:);
%   
  currBadCar=carDataFinal(carDataFinal.perReportID==carsFinal(badCars(k)),:);
    %corrupt self report data...
    currBadCarCorrupt=corruptSignalsTampa(currBadCar);
 carDataFinal(carDataFinal.perReportID==carsFinal(badCars(k)),:)=currBadCarCorrupt;
end 

writetable(carDataFinal,'ExampleOutputFile.csv')
