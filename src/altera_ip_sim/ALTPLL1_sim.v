`include "fpga_lab_defines.sv"

`timescale 1 ns / 1 ns

module ALTPLL1 (

	input	  areset,
	input	  inclk0,
	output	  c0,
	output	  c1,
	output	  c2,
	output	  c3,
	output	  locked );
    
  reg clk ;
 
  initial
  begin
    clk = 1'b0;  
    #(`CLK_PERIOD_NS/2);
    clk = 1'b1;
    forever clk = #(`CLK_PERIOD_NS/2) ~clk;
  end  

  assign c0 = clk ;
       
endmodule    
