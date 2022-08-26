`include "fpga_lab_defines.sv"

module my_design_example  (
 
    // General Interface
    input clk,        // Clock
    input rst_n,      // low when reset 
    input gp_button,  // General Purpose push button
    output [3:0] led, // led output
    //output done,      // Full operation done indication (optional)
    
    
    // My Design specific interface
    input  [31:0] in ,                  // Connected to Input reg  #0
    input         in_valid_pulse, 
    
    input  [31:0] select ,              // Connected to Input reg  #1
    input         select_valid_pulse,   
        
    output reg [31:0] result,           // Connected to Output reg #0
    
    // Memory Interface 
    // Optional usage, but do not remove.
    
    input  [8:0]    remote_mem_addr,
    input  [31:0]   remote_mem_wdata,
    output [31:0]   remote_mem_rdata,
    input           remote_mem_wr
    
    
      
);

	
// ================================ SIMPLE COMB SUM/SUB ============================
   
  logic select_sampled ;
   
  // Sample Select

	always @(posedge clk or negedge rst_n) begin
		
		if (~rst_n)
			select_sampled <= 1'b0;			
		else if (select_valid_pulse) begin        
			select_sampled <= select ;
		end
	end
	

  // Calculate

	always @(posedge clk or negedge rst_n) begin
		
		if (~rst_n)
			result <= 32'b0;			
		else if (in_valid_pulse) begin
			if (select_sampled==0)
				result <= result + in;
			else
				result <= result - in;
		end
	end


	
// =============================== Memory Instantiation and usage example =========================================

    // Port A used for remote access
     
    logic        remote_mem_we     ;            
    logic [3:0]  remote_mem_be     ;     

    assign remote_mem_we    = remote_mem_wr  ;
    assign remote_mem_be    = 4'b1111 ;
    
    // Port B to controlled by my design - TMP DISABLED

      
    logic [8:0]  mem_addr  ; 
    logic [31:0] mem_wdata ;            
    logic [31:0] mem_rdata ;            
    logic        mem_we    ;            
    logic [3:0]  mem_be    ;     
        
    assign mem_addr   = '0 ; 
    assign mem_wdata  = '0 ;                      
    assign mem_we     = '0 ;            
    assign mem_be     = '0 ;      


dp_ram_wrap_512x32_byte_enable mem (

    .clk         ( clk ),             
    
    // Port A used for remote access
                      
    .addr_a_i    ( remote_mem_addr  ),      //   [8:0]  
    .wdata_a_i   ( remote_mem_wdata ),      //   [31:0]            
    .rdata_a_o   ( remote_mem_rdata ),      //   [31:0]            
    .we_a_i      ( remote_mem_we    ),      //                     
    .be_a_i      ( remote_mem_be    ),      //   [3:0]             

     // Port B to controlled by my design 
                       
    .addr_b_i    ( mem_addr  ),             //   [8:0]  
    .wdata_b_i   ( mem_wdata ),             //   [31:0]            
    .rdata_b_o   ( mem_rdata ),             //   [31:0]            
    .we_b_i      ( mem_we    ),             //                     
    .be_b_i      ( mem_be    )              //   [3:0]             
  );

	
// ================================ Count on leds the number of gp_button presses =================================

  logic prev_gp_button ;
  logic gp_button_rose ;
  logic [3:0] cnt ;


  always @(posedge clk or negedge rst_n)
    if (~rst_n) prev_gp_button<=1 ;    // Same as non-pressed button
    else  prev_gp_button <= gp_button ;
    
  assign gp_button_rose = gp_button && !prev_gp_button ;

  always @(posedge clk or negedge rst_n)
    if (~rst_n) cnt<=4'b0 ; 
    else 
     if (gp_button_rose) cnt <= cnt+1 ;

  assign led = ~cnt[3:0] ;
         
            
endmodule

