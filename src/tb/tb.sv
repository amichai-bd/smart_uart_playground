`include "fpga_lab_defines.sv"
`include "smart_uart_defines.sv"

module tb;

  timeunit      1ns;
  timeprecision 1ps;
    
  logic brd_clk   ; 
  logic brd_rst_n ;
  logic brd_gp_button;
  
  logic uart_rx   ;
  logic uart_tx   ;
  
  logic [3:0] led ;
  
  logic enable_uart_tb ;
  
  integer i;

//================================================================================

// FPGA Instance

  fpga_device i_fpga_device (
  
    .brd_clk     ( brd_clk),     // input 
    .brd_rst_n   ( brd_rst_n),   // input  
    .brd_gp_button   ( brd_gp_button ),  // input
    .uart_tx     ( uart_tx),     // output 
    .uart_rx     ( uart_rx),     // input  
    .led         (  led	  )      // output 
     
                            
     
  ) ;
  
//================================================================================

// EXTERNAL UART pseudo terminal Interface

`ifdef REMOTE_PY
 py_uart_bus
`else
 uart_bus
`endif 
 
  #(
    .BAUDRATE(`BAUDRATE),
    .PARITY_EN(`PARITY_EN)
  )
  uart
  (
    .uart_rx         ( uart_tx ),
    .uart_tx         ( uart_rx ),
    .enable_uart_tb   (enable_uart_tb)   
  );
//================================================================================

// Board-like clock and reset

initial brd_clk = 0 ;
always #(`CLK_PERIOD_NS/2) brd_clk = !brd_clk ;
   
 initial begin  
    enable_uart_tb = 1'b0; 
    brd_rst_n = 1'b1;
    //#(`DEBOUNCE_MASK_PERIOD_MS*1000+10*`CLK_PERIOD_NS) ;     
	#(10*`CLK_PERIOD_NS) ;     
    brd_rst_n = 1'b0;
	#(10*`CLK_PERIOD_NS) ;     
    //#(`DEBOUNCE_MASK_PERIOD_MS*1000+10*`CLK_PERIOD_NS) ;      
    brd_rst_n = 1'b1;    
    enable_uart_tb = 1'b1;    
 end
 
 
 //================================================================================

// Simulate the button:

 initial begin
	brd_gp_button = 1'b0;
	for (i=0; i < 20; i=i+1) begin
		#(8460*`CLK_PERIOD_NS);
		brd_gp_button = ~brd_gp_button; 
	end
 end
endmodule
