`include "fpga_lab_defines.sv"

module fpga_device (

  // Clock and Reset
  input  logic               brd_clk      ,  // Board Clock
  input  logic               brd_rst_n    ,  // Board Reset  
  input                      brd_gp_button,      // General Purpose push button

    // UART bus   
  output logic               uart_tx      , // Connect to UART Cable RX !!!
  input  logic               uart_rx      , // Connect to UART Cable TX !!!
  
  // LEDs output
  
  output [3:0] led    
     
);

localparam LOG2_NUM_REGS_PER_DIR=3;
localparam NUM_REGS_PER_DIR = 2**LOG2_NUM_REGS_PER_DIR;
                                                  
//  FPGA Clocks and Resets  

  wire clk_c0        ; 
  wire clk_c1        ;
  wire clk_c2        ;
  wire clk_c3        ;
  wire pll_locked    ;

  ALTPLL1 u_clocks_resets (
  ///////////////////////////
      .areset    (!brd_rst_n ),
      .inclk0    (brd_clk    ),
      .c0        (clk_c0     ),
      .c1        (clk_c1     ),
      .c2        (clk_c2     ),
      .c3        (clk_c3     ),
      .locked    (pll_locked )
  );

wire clk = clk_c0 ; 

wire pb_rst_n ; // debounced reset , currently applied only in FPGA
wire rst_n ; 


localparam int NUM_DEBOUNCE_CYCLES = ((`DEBOUNCE_MASK_PERIOD_MS*1000)/`CLK_PERIOD_NS) ;

logic [NUM_REGS_PER_DIR-1:0] intrfc_regs_in_valid_pulse ;

logic  [8:0]  mem_addr;
logic  [31:0] mem_wr_data;
logic  [31:0] mem_rd_data;
logic  mem_wr;
logic  mem_rd;

//===============================================================================

// Board Reset debounce

pb_debounce  #(.NUM_STABLE_CYCLES_REQUIRED(NUM_DEBOUNCE_CYCLES)) i_rst_pb_debounce (

 .rst_n(1'b1),  // Not applied since this is the reset button
 .clk(brd_clk), 
 .pb_in(brd_rst_n), 
 .pb_out(pb_rst_n)) ;
 
// debounced reset currently applied only in FPGA
`ifdef ALTERA
assign rst_n = pb_rst_n ;
`else
assign rst_n = brd_rst_n ; 
`endif
 

//===============================================================================

// gp button debounce

pb_debounce  #(.NUM_STABLE_CYCLES_REQUIRED(NUM_DEBOUNCE_CYCLES)) i_gp_pb_debounce (

 .rst_n(rst_n), 
 .clk(clk), 
 .pb_in(brd_gp_button), 
 .pb_out(gp_button)) ;

//===============================================================================



// UART access 

REMOTE_ACCESS_INTRFC  remote_access_intrfc() ;

 uart_access i_uart_access (
 
    .CLK  (clk),
    .RSTN (rst_n),
    .rx_i (uart_rx),      // Receiver input
    .tx_o (uart_tx),      // Transmitter output

    .remote_access_intrfc(remote_access_intrfc.remote)           
);
//===============================================================================


reg [31:0] intrfc_regs_in  [NUM_REGS_PER_DIR-1:0] ; 
reg [31:0] intrfc_regs_out [NUM_REGS_PER_DIR-1:0] ;  

access_regs_and_mem #(.LOG2_NUM_REGS_PER_DIR(3)) i_access_regs_and_mem (
    .CLK(clk),
    .RSTN(rst_n),    
    .remote_access_intrfc(remote_access_intrfc.near),

   .intrfc_regs_in  ( intrfc_regs_in ),
   .intrfc_regs_in_valid_pulse(intrfc_regs_in_valid_pulse),
   .intrfc_regs_out ( intrfc_regs_out ),
   
    .mem_addr     ( mem_addr    ) ,
    .mem_wr_data  ( mem_wr_data ) ,
    .mem_rd_data  ( mem_rd_data ) ,
    .mem_wr       ( mem_wr      ) ,
    .mem_rd       ( mem_rd      ) 
                    
);

//===============================================================================


// Design Wrapper Interface


my_design_intrfc_wrap #(.NUM_REGS_PER_DIR(NUM_REGS_PER_DIR)) i_my_design_intrfc_wrap  (
 
   .clk             (clk),
   .rst_n           (rst_n),
   .gp_button       (gp_button), 
   .intrfc_regs_in  (intrfc_regs_in),
   .intrfc_regs_in_valid_pulse(intrfc_regs_in_valid_pulse),
   .intrfc_regs_out (intrfc_regs_out),
   
   .mem_addr     ( mem_addr    ) ,
   .mem_wr_data  ( mem_wr_data ) ,
   .mem_rd_data  ( mem_rd_data ) ,
   .mem_wr       ( mem_wr      ) ,
   .led          (led)
   //.done       (done)
   
);

//===============================================================================

                  
endmodule

