%%ORIGINAL OFFSET CODE

% 
% offset_rate = 0.01;
% time = carDataFinal.t;
% true_reading = carDataFinal.x;
% faulty_reading = true_reading;
% 
% portion_to_offset = 0.20;
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
% reputation scores get added here
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
