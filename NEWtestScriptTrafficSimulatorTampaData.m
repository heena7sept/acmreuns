
%% Import/Truncate Section
% Section Description: This section imports raw data from the 
% time-truncated CSV Tampa BSM data file and removes all variables 
% other than basic kinematic data: 1) TimeofDayStamp (this is the synchronized RSU
% low-resolution timestamp), 2) carTS (this is the unsychronized millisecond
% level precision car timestamp), 3) posCol (contains cars' positions in
% lat/long coordinates), 4) speedCol (magnitude of radial velocity), 5)
% accelX, 6) accelY
 
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
carDataTrunc=carData(:,[6,TimeofDayStamp,carTS,carID,posCol,speedCol,accelX,accelY]);
carIDs=sort(unique(carData.coreData_id));
%Step 3: Seperate posCol into x and y
for k=1:height(carDataTrunc)
    currPosString=carDataTrunc.coreData_position{k};
    currRSUString=extractAfter(carDataTrunc.metadata_RSUID{k},"thea");
    carDataTrunc.RSUID(k)=str2num(currRSUString);
    carDataTrunc.t(k)=carDataTrunc.metadata_generatedAt_timeOfDay(k)*60^2;
    newStr = split(currPosString,["("," ", ")"]);
    carDataTrunc.x(k)=str2num(newStr{3});
    carDataTrunc.y(k)=str2num(newStr{4});
    
end
%Throw away columns which have been converted
carDataTrunc.metadata_RSUID=[];
carDataTrunc.coreData_position=[];
carDataTrunc.metadata_generatedAt_timeOfDay=[];


%% Timestamp Generation Section 
% This section is utilized to generate syncrhonized high-resoluion time-stamps for each vehicle 
% This process involves - 1) extracting a portion of the aggregate data
% table corresponding to each vehicle, 2) extracting the first RSU
% timestamp (synchronized across file), 3) extracting the local timestamps broadcast 
% by the car, and 4) defining a new syncronized high resolution timestamp
% by adding the changes in the car timestamp between messages to the first
% RSU timestamp
for j=1:length(carIDs) %for each car
    singleCarData=carDataTrunc(carDataTrunc.coreData_id==carIDs(j),:); %grab all data for a car
    singleCarData=sortrows(singleCarData,{'t','coreData_secMark'},{'ascend','ascend'});
    t=singleCarData.t; %RSU Time
    carT=singleCarData.coreData_secMark; %Car Time
    %check if timewrapping occurs, if so unwrap at RSU timestamp level
    if(min(diff(carT))<-40e3)
        %wrapping occurs, update all car timestamps
%         figure(1);
%         scatter(singleCarData.t,singleCarData.coreData_secMark);
%         xlabel('Meta Time');ylabel('Core Time');title('Wrapped');

        % Step 1: Address potential problem of wrap point occuring within a
        % meta timetsamp with multiple coreData timestamps
        needsUnWrappedIndicesStart=find(diff(carT)<-40e3)+1; %find potential start points of wrapping in coreData/car time
        matchingMetaTimes=unique(t(needsUnWrappedIndicesStart))%find corresponding metaData timestamps associated with these wrap points
        %"wrapping within" TS problem denoted by wrap points occuring within
        %adjacent TS
        if length(matchingMetaTimes)>1 %i.e.: if there is a potential problem
            for k=1:(length(matchingMetaTimes)-1) %for each unique candidate meta wrap point pair
                if (round(matchingMetaTimes(k+1)-matchingMetaTimes(k))==1)  %condition used to check if wrap occured witin metaTS
                    %reorder points within initial meta TS correctly
                    carTNeedsReordered=carT(t==matchingMetaTimes(k)); %extract portion of coreData that needs reordered (ie: in starting meta TS)
                    localReorderPoint=find(diff(carTNeedsReordered)>40e3)+1; %note that within this time series, the point of reordering is also denoted by a negative spike
                    carTReordered=[carTNeedsReordered(localReorderPoint:length(carTNeedsReordered));carTNeedsReordered(1:(localReorderPoint-1))]; %unwrap locally
                    carT(t==matchingMetaTimes(k))=carTReordered; %place reordered values back in original carT variable
                    singleCarData.coreData_secMark=carT;%update table
                    matchingMetaTimes(k)=[]; %remove first meta TS in adjacent pair, a
                    needsUnWrappedIndicesStart(k)=[]; %and corresponding false alarm coreDataTS
                    if length(matchingMetaTimes)==1
                        break
                    end %used to continue out of if condition which fixes within meta TS wrap problem, go back and check for additional occurences of problem (not likely?)
                end
            end
        end

        %Step 2: Actually unwrap timestamps after above fix across all
        %times per car
        needsUnWrappedIndicesStart=[needsUnWrappedIndicesStart;length(carT)]; %add end timestamp on for implementation convenience
        for m=1:(length(needsUnWrappedIndicesStart)-1) %for each timestamp that needs unwrapped, -1 since end timestamp was ended
            needsUnWrappedIndices=needsUnWrappedIndicesStart(m):(needsUnWrappedIndicesStart(m+1)-1);
            carT(needsUnWrappedIndices)=carT(needsUnWrappedIndices)+60e3*m; %add on a full clock cycle multiple

        end

        % At this point, unwrapping has completed, so store the data back in
        % single car table
        singleCarData.coreData_secMark=carT;
        singleCarData=sortrows(singleCarData,{'t','coreData_secMark'},{'ascend','ascend'});
%         figure(2);scatter(singleCarData.t,singleCarData.coreData_secMark);
%         xlabel('Meta Time');ylabel('Core Time');title('Unwrapped');
    end

    %After unwrapping has occured if needed, combine and actually make the
    %timestamp
    singleCarData.t=t(1)*ones(length(t),1)+[carT-carT(1)]./1000; 
    carDataTrunc(carDataTrunc.coreData_id==carIDs(j),:)=singleCarData;
    %scatter(singleCarData.x,singleCarData.y);hold on;
end
carDataTrunc=sortrows(carDataTrunc,"t"); %sort by the newly combined high res time
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

distThresh=.1;carDataPeerReportedTotal=[];
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
    %currBadCarCorrupt=corruptSignalsTampa(currBadCar);

    currBadCarCorrupt=corruptSignalsTampa_Marbellas_Test(currBadCar);

 carDataFinal(carDataFinal.perReportID==carsFinal(badCars(k)),:)=currBadCarCorrupt;
end 

writetable(carDataFinal,'ExampleOutputFile.csv')

%Visualization figures for demo...
% scatter(carDataFinal.x(carDataFinal.peerReported==0),...
%     carDataFinal.y(carDataFinal.peerReported==0));
% hold on;
% scatter(carDataFinal.x(carDataFinal.peerReported==1),...
%     carDataFinal.y(carDataFinal.peerReported==1));
% xlabel('Latitude (deg)');ylabel('Longitude (deg)');
% legend('Self-Reported','Peer Estimated','Location','northwest')




%%ORIGINAL RANDOM OFFSET CODE
% 
% offset_rate = 0.01;
% time = carDataFinal.t;
% true_reading = carDataFinal.x;
% faulty_reading = true_reading;
% 
% portion_to_offset = 0.20; % Adjust this value as needed (0.2 means 20% of the data will have an offset)
% num_data_points = numel(faulty_reading);
% num_offset_points = round(portion_to_offset * num_data_points);

% offset_indices = randperm(num_data_points, num_offset_points);
% faulty_reading(offset_indices) = true_reading(offset_indices) + offset_rate;
% 
% carDataFinal.FaultyReadingOffset = faulty_reading;
% writetable(carDataFinal, 'Car Data Final.xlsx');
% 
% scatter(carDataFinal.x, carDataFinal.y);
% hold on;
% scatter(carDataFinal.FaultyReadingOffset, carDataFinal.y);
% 
% % Add labels and legend to the plot
% xlabel('Longitude (deg.)', 'FontSize', 14, 'FontName', 'Times');
% ylabel('Latitude (deg.)', 'FontSize', 14, 'FontName', 'Times');
% legend('Original', 'Faulty Reading with Offset');
% title('Scatter Plot of Faulty Reading with Offset at 20%');
% % 


%%OFFSET WITH REPUTATION SCORES


offset_rate = 0.01;
time = carDataFinal.t;
true_reading = carDataFinal.x;
faulty_reading = true_reading;

reputation_scores = ones(size(faulty_reading));

portion_to_offset = 0.20; 
num_data_points = numel(faulty_reading);
num_offset_points = round(portion_to_offset * num_data_points);


offset_indices = randperm(num_data_points, num_offset_points);
faulty_reading(offset_indices) = true_reading(offset_indices) + offset_rate;

carDataFinal.FaultyReadingOffset = faulty_reading;
reputation_scores(offset_indices) = -1;
carDataFinal.ReputationScore = reputation_scores;
writetable(carDataFinal, 'Car Data Final.xlsx');

figure;
plot(time, reputation_scores, 'b', 'LineWidth', 2);
xlabel('Time', 'FontSize', 14, 'FontName', 'Times');
ylabel('Reputation Score', 'FontSize', 14, 'FontName', 'Times');
title('Reputation Score vs Time', 'FontSize', 16, 'FontName', 'Times');
grid on;




