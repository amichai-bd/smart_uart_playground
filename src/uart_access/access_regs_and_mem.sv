
`include "smart_uart_defines.sv"

module access_regs_and_mem #(
  parameter LOG2_NUM_REGS_PER_DIR=3,
  parameter NUM_REGS_PER_DIR = 2**LOG2_NUM_REGS_PER_DIR
)
  (

    input  logic                      CLK,
    input  logic                      RSTN,    

    interface  remote_access_intrfc,

    output logic [31:0] intrfc_regs_in  [NUM_REGS_PER_DIR-1:0] ,  // Output from uart access regs -> Input to my_design_wrap
    output logic [NUM_REGS_PER_DIR-1:0] intrfc_regs_in_valid_pulse,
    
    input         [31:0] intrfc_regs_out [NUM_REGS_PER_DIR-1:0] ,  // Output from my_design_wrap -> Input to  uart access regs   
  
    output [8:0]  mem_addr,
    output [31:0] mem_wr_data,
    input  [31:0] mem_rd_data,
    output mem_wr,
    output mem_rd
      
);


logic wr_reg ;
logic rd_reg ;
logic [LOG2_NUM_REGS_PER_DIR-1:0] reg_idx ;
logic [31:0] reg_data_in ;
logic [31:0] reg_data_out ; 
logic reg_access_done_pulse ;

logic mem_access ;
logic mem_access_done_pulse ;

logic [NUM_REGS_PER_DIR-1:0] intrfc_regs_in_valid_pulse_d ;

always_comb
begin
	intrfc_regs_in_valid_pulse_d[NUM_REGS_PER_DIR-1:0] = 0 ;
	if (wr_reg) intrfc_regs_in_valid_pulse_d[reg_idx] = 1'b1 ;
end

always_ff @ (posedge CLK, negedge RSTN) begin
	if(!RSTN) intrfc_regs_in_valid_pulse <= 0 ;
	else intrfc_regs_in_valid_pulse <= intrfc_regs_in_valid_pulse_d ;
end

assign mem_access = (remote_access_intrfc.cmd_addr[15:12]==4'ha) ;

// Registers Access
assign wr_reg = remote_access_intrfc.cmd_wr_word && remote_access_intrfc.cmd_valid && !mem_access ; 
assign rd_reg = remote_access_intrfc.cmd_rd_word && remote_access_intrfc.cmd_valid && !mem_access ;    
assign reg_idx = remote_access_intrfc.cmd_addr[3:0] ;    
assign reg_data_in = remote_access_intrfc.cmd_data ; 


// Memory Access
assign mem_wr = remote_access_intrfc.cmd_wr_word && remote_access_intrfc.cmd_valid && mem_access ; 
assign mem_rd = remote_access_intrfc.cmd_rd_word && remote_access_intrfc.cmd_valid && mem_access ;    
assign mem_addr = remote_access_intrfc.cmd_addr[8:0] ;    
assign mem_wr_data = remote_access_intrfc.cmd_data ; 

assign remote_access_intrfc.rsp_data  = mem_access_done_pulse ? mem_rd_data          : reg_data_out ;
assign remote_access_intrfc.rsp_valid = mem_access_done_pulse ? mem_access_done_pulse : reg_access_done_pulse ;


int i ;
// Write Input Registers
always_ff @(posedge CLK, negedge RSTN)
     if(~RSTN) for (i=0;i<NUM_REGS_PER_DIR;i++) intrfc_regs_in[i] <= 32'b0 ;
     else if (wr_reg) intrfc_regs_in[reg_idx] <= reg_data_in  ; 

// Read Output Registers
always_ff @(posedge CLK, negedge RSTN)
     if(~RSTN)  reg_data_out <= 0 ; else if (rd_reg) reg_data_out <= intrfc_regs_out[reg_idx] ; 

// done pulse
always_ff @(posedge CLK, negedge RSTN)
    if(~RSTN)  reg_access_done_pulse <= 0 ; else reg_access_done_pulse <= (wr_reg || rd_reg) ;


always_ff @(posedge CLK, negedge RSTN)
    if(~RSTN)  mem_access_done_pulse <= 0 ; else mem_access_done_pulse <= (mem_wr || mem_rd) ;


endmodule
