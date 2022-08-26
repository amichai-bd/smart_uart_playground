

module my_design_intrfc_wrap #(parameter NUM_REGS_PER_DIR=8) (
    input clk,       // Clock
    input rst_n,     // low when reset 
    input gp_button, // General Purpose push button
    
    input [31:0] intrfc_regs_in [NUM_REGS_PER_DIR-1:0] ,
    input  [NUM_REGS_PER_DIR-1:0] intrfc_regs_in_valid_pulse,
    
    output [31:0] intrfc_regs_out [NUM_REGS_PER_DIR-1:0],
    output [3:0] led,  // led output
    
    //output done,       // operation done indication

    input   [8:0]  mem_addr,
    input   [31:0] mem_wr_data,
    output  [31:0] mem_rd_data,
    input mem_wr

);
                                                 
   my_design_example  i_my_design_example (   

    // General Interface
    .clk(clk),
    .rst_n(rst_n),
    .gp_button(gp_button),
    .led(led),
    //.done(done),  

    .remote_mem_addr  ( mem_addr    ) ,
    .remote_mem_wdata ( mem_wr_data ) ,
    .remote_mem_rdata ( mem_rd_data ) ,
    .remote_mem_wr    ( mem_wr      ) ,
                        
    // My Design specific interface
    .in(intrfc_regs_in[0]),
    .in_valid_pulse(intrfc_regs_in_valid_pulse[0]),
    
    .select(intrfc_regs_in[1]),
    .select_valid_pulse(intrfc_regs_in_valid_pulse[1]), 
    
    .result(intrfc_regs_out[0])
 
   ) ;
   

endmodule

