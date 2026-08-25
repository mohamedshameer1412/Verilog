// Program 2: Temperature readings from sensors - min, max, average
module temperature_sensor;
  real temp[8];
  real min_t, max_t, sum_t, avg_t;

  initial begin
    temp[0] = 23.5; temp[1] = 31.2; temp[2] = 18.7; temp[3] = 27.0;
    temp[4] = 35.1; temp[5] = 22.4; temp[6] = 29.8; temp[7] = 16.3;

    min_t = temp[0]; max_t = temp[0]; sum_t = 0.0;
    foreach (temp[i]) begin
      sum_t = sum_t + temp[i];
      if (temp[i] < min_t) min_t = temp[i];
      if (temp[i] > max_t) max_t = temp[i];
    end
    avg_t = sum_t / 8.0;

    $display("===== Temperature Sensor Report =====");
    foreach (temp[i]) $display("Sensor %0d : %.1f C", i, temp[i]);
    $display("-------------------------------------");
    $display("Minimum Temperature : %.1f C", min_t);
    $display("Maximum Temperature : %.1f C", max_t);
    $display("Average Temperature : %.2f C", avg_t);
    $display("=====================================");
  end
endmodule
