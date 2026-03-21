`timescale 1ns / 1ps

module adder(
  input  wire          clk,
  input  wire          resetn,
  input  wire          start,
  input  wire          subtract,
  input  wire [383:0] in_a,
  input  wire [383:0] in_b,
  output reg  [384:0] result,
  output reg          done    
  );

  always @(posedge clk) begin: addition
    result <= in_a + in_b;
  end
  
  always @(posedge clk) 
  begin
    done <= start;
  end

endmodule
