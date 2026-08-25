// Program 1: Store marks of five subjects, calculate total, average, and grade
module student_marks;
  int marks[5];
  int total;
  real average;
  string grade;

  initial begin
    marks[0] = 85; marks[1] = 72; marks[2] = 90; marks[3] = 65; marks[4] = 78;
    total = 0;
    foreach (marks[i]) total = total + marks[i];
    average = real'(total) / 5.0;
    if      (average >= 90) grade = "A+";
    else if (average >= 80) grade = "A";
    else if (average >= 70) grade = "B";
    else if (average >= 60) grade = "C";
    else if (average >= 50) grade = "D";
    else                    grade = "F";
    $display("===== Student Mark Sheet =====");
    foreach (marks[i]) $display("Subject %0d : %0d", i+1, marks[i]);
    $display("------------------------------");
    $display("Total   : %0d / 500", total);
    $display("Average : %.2f%%", average);
    $display("Grade   : %s", grade);
    $display("==============================");
  end
endmodule
