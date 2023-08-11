function corruptedTable = corruptSignalsTampa(inputTable)
    PosNoiseVar=10e-7;
    corruptedTable=inputTable;
    corruptedTable.x=inputTable.x+mean(inputTable.x)*PosNoiseVar.*randn(height(inputTable),1);
   corruptedTable.y=inputTable.y+mean(inputTable.y)*PosNoiseVar.*randn(height(inputTable),1);
   corruptedTable.coreData_speed=inputTable.coreData_speed+mean(inputTable.coreData_speed)*PosNoiseVar.*randn(height(inputTable),1);
   corruptedTable.coreData_accelset_long=inputTable.coreData_accelset_long+mean(inputTable.coreData_accelset_long)*PosNoiseVar.*randn(height(inputTable),1);
   corruptedTable.coreData_accelset_lat=inputTable.coreData_accelset_lat+mean(inputTable.coreData_accelset_lat)*PosNoiseVar.*randn(height(inputTable),1);
   corruptedTable.corrupted=ones(height(inputTable),1);
% Uncomment for visualiation used for paper
%    scatter(inputTable.x,inputTable.y);
% hold on;scatter(corruptedTable.x,corruptedTable.y);
% xlabel('Longitude (deg.)','FontSize', 14,'FontName','Times');
% ylabel('Latitude (deg.)','FontSize', 14,'FontName','Times');
% legend('Original Data','Corrupted Data',...
%      'FontSize', 14,'FontName','Times','Location','northeast')
%  saveas(gcf,'CorruptionExample.png')

end 