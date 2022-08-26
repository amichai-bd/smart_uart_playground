`include "fpga_lab_defines.sv"
`include "smart_uart_defines.sv"

module uart_access

(
    input  logic                      CLK,
    input  logic                      RSTN,
    input  logic                      rx_i,      // Receiver input
    output logic                      tx_o,      // Transmitter output

    interface   remote_access_intrfc            
);

    // receive buffer register, read only
    logic [7:0]       rx_data;
    logic             parity_error;
    logic [3:0]       clr_int;
    logic             tx_uart_ready_out;
    logic             rx_valid;

localparam NS_PER_BIT = (10**9)/`BAUDRATE;  
wire [15:0] cfg_div_val = (NS_PER_BIT/`CLK_PERIOD_NS)-1 ;

// Hardwired configuration registers 
// wire [7:0] UART_REG_LCR = 8'h83; //sets 8N1 and set DLAB to 1  // ??????????????????????????????
wire [7:0] UART_REG_LCR = 8'h03; //sets 8N1 and set DLAB to 0
wire [7:0] UART_REG_IER = 0 ;   // disable interrupts


logic su_rx_non_ascii_msg_on ;
logic su_rx_ascii_msg_on ;
logic su_rx_msg_on ;
logic su_tx_msg_on ;
logic cmd_valid ;
logic su_master_ascii_cmd_done_s ; 

logic enable_smart_uart ;   // enable/disable smart uart escape characters detection (by default enabled)
logic enable_smart_uart_d ; // pre-sample (by default enabled)

logic enable_hashtag ;      // enable/disable "#"  smart-uart commands detection
logic enable_hashtag_d ;    // pre-sampled

    uart_rx uart_rx_i
    (
        .clk_i              ( CLK               ),
        .rstn_i             ( RSTN              ),
        .rx_i               ( rx_i              ),
        .cfg_en_i           ( 1'b1              ),
        .cfg_div_i          ( cfg_div_val       ),
        .cfg_parity_en_i    (1'b0               ),
        .cfg_bits_i         ( UART_REG_LCR[1:0] ),
        .busy_o             (                   ),
        .err_o              ( parity_error      ),
        .err_clr_i          ( 1'b1              ),
        .rx_data_o          ( rx_data           ),
        .rx_valid_o         ( rx_valid          ),
        .rx_ready_i         ( su_rx_msg_on      )
    );
 
    logic [7:0] tx_uart_data_in  ;
    logic tx_uart_valid_in ;
    
    logic su_tx_data_byte_valid ;
    logic [7:0] su_tx_data_byte ;
    
    assign tx_uart_data_in  = su_tx_data_byte       ;  
    assign tx_uart_valid_in = su_tx_data_byte_valid ;

    uart_tx uart_tx_i
    (
        .clk_i              ( CLK               ),
        .rstn_i             ( RSTN              ),
        .tx_o               ( tx_o              ),
        .busy_o             (                   ),
        .cfg_en_i           ( 1'b1              ),
        .cfg_div_i          ( cfg_div_val       ),
        .cfg_parity_en_i    ( UART_REG_LCR[3]   ),
        .cfg_bits_i         ( UART_REG_LCR[1:0] ),
        .cfg_stop_bits_i    ( UART_REG_LCR[2]   ),

        .tx_data_i          ( tx_uart_data_in   ),
        .tx_valid_i         ( tx_uart_valid_in  ),
        .tx_ready_o         ( tx_uart_ready_out )
    );

assign enable_smart_uart = 1 ;        
assign enable_hashtag = 1 ;   
    
  // RX
  
   // Notice Master command support both ascii and value messages
  
   logic [3:0] su_cmd_rx_cntdown , su_cmd_rx_cntdown_d;
   logic su_cmd_rx_detected, su_cmd_rx_cntdown_expired ;
   
   wire capture_su_cmd =   enable_smart_uart && rx_valid && su_cmd_rx_cntdown_expired ;

   wire su_cmd_wr_word     = capture_su_cmd && (rx_data == `SU_CMD_WR_WORD      ) ;
   wire su_cmd_wr_halfword = capture_su_cmd && (rx_data == `SU_CMD_WR_HALFWORD  ) ;
   wire su_cmd_wr_byte     = capture_su_cmd && (rx_data == `SU_CMD_WR_BYTE      ) ;
   wire su_cmd_rd_word     = capture_su_cmd && (rx_data == `SU_CMD_RD_WORD      ) ;
   wire su_cmd_rd_numwords = capture_su_cmd && (rx_data == `SU_CMD_RD_NUMWORDS  ) ;
   
   // Logic to capture master ascii command from"#" to line feed
   
   logic su_master_ascii_cmd ;   
   wire su_master_ascii_cmd_done = su_master_ascii_cmd && (rx_valid && (rx_data==8'h0A)) ;   
   wire su_master_ascii_cmd_d =    (enable_smart_uart && enable_hashtag && (!su_rx_non_ascii_msg_on) && rx_valid && (rx_data=="#")) 
                                || (su_master_ascii_cmd && !su_master_ascii_cmd_done) ;

   always_ff @(posedge CLK, negedge RSTN)
     if(~RSTN)  su_master_ascii_cmd<= 0 ; else su_master_ascii_cmd <= su_master_ascii_cmd_d ; 

   logic su_master_ascii_cmd_rd , su_master_ascii_cmd_wr ;        
   wire su_master_ascii_cmd_rd_d = (su_master_ascii_cmd_rd || (su_master_ascii_cmd && rx_valid && (rx_data=="r"))) && !remote_access_intrfc.rsp_valid ;  // !cmd_valid  ;
   wire su_master_ascii_cmd_wr_d = (su_master_ascii_cmd_wr || (su_master_ascii_cmd && rx_valid && (rx_data=="w"))) && !remote_access_intrfc.rsp_valid ;  // !cmd_valid  ;
 
    always_ff @(posedge CLK, negedge RSTN)
     if(~RSTN)  begin
       su_master_ascii_cmd_rd <= 0 ; 
       su_master_ascii_cmd_wr <= 0 ;        
     end else begin
      su_master_ascii_cmd_rd <= su_master_ascii_cmd_rd_d ; 
      su_master_ascii_cmd_wr <= su_master_ascii_cmd_wr_d ;       
     end
     
    wire rx_data_ascii_is_0_to_9 = ((rx_data>="0")&&(rx_data<="9")) ;
    wire rx_data_ascii_is_a_to_f = ((rx_data>="a")&&(rx_data<="f")) ;  
    wire [7:0] conv_ascii_rx_nibble_val  =  rx_data_ascii_is_0_to_9 ? (rx_data - "0") : 10+(rx_data - "a") ;
        
    wire conv_ascii_rx = rx_valid && (su_master_ascii_cmd_rd || su_master_ascii_cmd_wr) 
                                  && (rx_data_ascii_is_0_to_9 || rx_data_ascii_is_a_to_f) ;
   
    
    logic[63:0] conv_ascii_rx_cmd_addr_data_val ; 
    logic [3:0] conv_ascii_rx_nibble_idx ;
    logic conv_addr_not_data ;
    
    always_ff @(posedge CLK, negedge RSTN)
     if(~RSTN)  begin
        conv_ascii_rx_cmd_addr_data_val  <= 0 ; 
        conv_ascii_rx_nibble_idx <= 0 ; 
        conv_addr_not_data <= 0 ;        
     end else begin
        if (conv_ascii_rx) begin
          if (conv_addr_not_data) conv_ascii_rx_cmd_addr_data_val[63:32] <= {conv_ascii_rx_cmd_addr_data_val[59:32],conv_ascii_rx_nibble_val[3:0]} ;   
          else conv_ascii_rx_cmd_addr_data_val[31:0]  <= {conv_ascii_rx_cmd_addr_data_val[27:0],conv_ascii_rx_nibble_val[3:0]} ;  
          conv_ascii_rx_nibble_idx <= conv_ascii_rx_nibble_idx+1;  
        end 
        if (su_master_ascii_cmd_done_s) begin
          conv_ascii_rx_cmd_addr_data_val <= 0 ;  
          conv_addr_not_data <= 0 ;
        end
        if (su_master_ascii_cmd && rx_valid && rx_data==" ") conv_addr_not_data <= ~conv_addr_not_data ;     
     end
      
    
    wire conv_ascii_rx_valid_d = conv_ascii_rx && (conv_ascii_rx_nibble_idx==0) ;
    logic conv_ascii_rx_valid ;
    always_ff @(posedge CLK, negedge RSTN)
     if(~RSTN) conv_ascii_rx_valid  <= 0 ; else conv_ascii_rx_valid <= conv_ascii_rx_valid_d ; 
       
   // Logic to capture Master value provide commands 

   logic [3:0] su_cmd_rx_set_byte_cntdown ; 
    
   assign su_cmd_rx_set_byte_cntdown = (su_cmd_wr_word      ?  4'd8 : (
                                        su_cmd_wr_halfword  ?  4'd6 : (
                                        su_cmd_wr_byte      ?  4'd5 : (
                                        su_cmd_rd_word      ?  4'd4 : (
                                        su_cmd_rd_numwords  ?  4'd5 : 4'd0))))) ; // TBD cmd_rd_numwords actually  currently not supported supported here
                                                                                  // Implemented by multiple cmd_rd_word                                         
   
   assign su_cmd_rx_detected = (su_cmd_rx_set_byte_cntdown != 4'd0) ;
   
   assign su_cmd_rx_cntdown_expired = (su_cmd_rx_cntdown==4'd0) ;

   assign su_cmd_rx_cntdown_d = (su_cmd_rx_cntdown_expired) ? su_cmd_rx_set_byte_cntdown : 
                                   (rx_valid ? su_cmd_rx_cntdown-1 : su_cmd_rx_cntdown) ; 
   
   always_ff @(posedge CLK, negedge RSTN)
     if(~RSTN) su_cmd_rx_cntdown <= 0 ; else su_cmd_rx_cntdown <= su_cmd_rx_cntdown_d ;
   
   assign su_rx_non_ascii_msg_on = su_cmd_rx_detected || !su_cmd_rx_cntdown_expired ;   
   assign su_rx_ascii_msg_on = su_master_ascii_cmd || su_master_ascii_cmd_d ;   
  
   assign su_rx_msg_on =  su_rx_non_ascii_msg_on || su_rx_ascii_msg_on ;
  
   logic cmd_wr_word_s       ; 
   logic cmd_wr_halfword_s   ;
   logic cmd_wr_byte_s       ; 
   logic cmd_rd_word_s       ;    
   logic cmd_rd_numwords_s   ;   
   logic [7:0][7:0] cmd_addr_data ;
   
   always @(posedge CLK, negedge RSTN) 
   if(~RSTN) 
   begin
    cmd_wr_word_s      <= 0  ;
    cmd_wr_halfword_s  <= 0  ;
    cmd_wr_byte_s      <= 0  ;
    cmd_rd_word_s      <= 0  ;
    cmd_rd_numwords_s  <= 0  ;        
   end else begin
    if (su_cmd_rx_detected) begin
       cmd_wr_word_s      <= su_cmd_wr_word     ; 
       cmd_wr_halfword_s  <= su_cmd_wr_halfword ; 
       cmd_wr_byte_s      <= su_cmd_wr_byte     ; 
       cmd_rd_word_s      <= su_cmd_rd_word     ; 
       cmd_rd_numwords_s  <= su_cmd_rd_numwords ;
    end else if (su_master_ascii_cmd)  begin
       cmd_wr_word_s      <= 0 ; 
       cmd_wr_halfword_s  <= 0 ; 
       cmd_wr_byte_s      <= 0 ; 
       cmd_rd_word_s      <= 0 ; 
       cmd_rd_numwords_s  <= 0 ;       
    end    
   end
   
  
   logic [3:0] cmd_addr_data_idx ;
   
   wire update_cmd_addr_data = conv_ascii_rx_valid || (rx_valid && !su_cmd_rx_cntdown_expired)  ;
   
   always @(posedge CLK, negedge RSTN) 
      if(~RSTN) begin
        cmd_addr_data  <= 64'd0 ;
        cmd_addr_data_idx <= 7 ;
      end
      else if (update_cmd_addr_data) 
      begin
       cmd_addr_data[cmd_addr_data_idx] <= rx_data ;
       cmd_addr_data_idx <=  cmd_addr_data_idx-1 ;
      end
      else if (su_cmd_rx_cntdown_expired || su_master_ascii_cmd_done) begin
        cmd_addr_data_idx <= 7 ;
        cmd_addr_data  <= 64'd0 ;
      end
   
   always @(posedge CLK, negedge RSTN) 
       if(~RSTN) su_master_ascii_cmd_done_s <=0 ; else su_master_ascii_cmd_done_s <= su_master_ascii_cmd_done ;

   always @(posedge CLK, negedge RSTN) 
   if(~RSTN) cmd_valid <=0 ; else cmd_valid <= (  (rx_valid && (su_rx_msg_on && (su_cmd_rx_cntdown==4'd1)))  // Last byte captured , cmd is valid  
                                                || su_master_ascii_cmd_done);                                
                                                 
   assign {remote_access_intrfc.cmd_addr,remote_access_intrfc.cmd_data} = su_master_ascii_cmd_done_s ? conv_ascii_rx_cmd_addr_data_val : cmd_addr_data ;
   assign remote_access_intrfc.cmd_wr_word       =  cmd_wr_word_s  || su_master_ascii_cmd_wr    ;
   assign remote_access_intrfc.cmd_wr_halfword   =  cmd_wr_halfword_s  ;
   assign remote_access_intrfc.cmd_wr_byte       =  cmd_wr_byte_s      ; 
   assign remote_access_intrfc.cmd_rd_word       =  cmd_rd_word_s || su_master_ascii_cmd_rd     ;
   assign remote_access_intrfc.cmd_rd_numwords   =  cmd_rd_numwords_s  ;
   assign remote_access_intrfc.cmd_valid         =  cmd_valid  ;  

// TX

 logic su_tx_msg_on_d , su_tx_msg_on_is_rd_ascii , su_tx_msg_on_is_wr_ascii ;
 logic su_tx_msg_on_is_rd_ascii_d , su_tx_msg_on_is_wr_ascii_d;
 
 logic [3:0] su_cmd_tx_cntdown , su_cmd_tx_cntdown_d ;
  wire cmd_rsp_expected = cmd_rd_word_s || cmd_rd_numwords_s || su_master_ascii_cmd_rd  || su_master_ascii_cmd_wr ;
 
 
 always_comb
 begin
  su_tx_msg_on_d = su_tx_msg_on ;
  su_tx_msg_on_is_rd_ascii_d = su_tx_msg_on_is_rd_ascii ;
  su_tx_msg_on_is_wr_ascii_d = su_tx_msg_on_is_wr_ascii ;  
  
  if (remote_access_intrfc.rsp_valid && cmd_rsp_expected) begin
     su_tx_msg_on_d = 1 ;
     if (su_master_ascii_cmd_rd) su_tx_msg_on_is_rd_ascii_d = 1 ; 
     if (su_master_ascii_cmd_wr) su_tx_msg_on_is_wr_ascii_d = 1 ;      
  end 
  if ((su_cmd_tx_cntdown==4'd0) && tx_uart_ready_out && su_tx_msg_on) begin
    su_tx_msg_on_d = 0 ;
    su_tx_msg_on_is_rd_ascii_d = 0 ;
    su_tx_msg_on_is_wr_ascii_d = 0 ;    
  end
 end
 
 always @(posedge CLK, negedge RSTN) 
   if(~RSTN) su_tx_msg_on <= 0 ; else su_tx_msg_on <= su_tx_msg_on_d ;
   
 always @(posedge CLK, negedge RSTN) 
   if(~RSTN) su_tx_msg_on_is_rd_ascii <= 0 ; else su_tx_msg_on_is_rd_ascii <= su_tx_msg_on_is_rd_ascii_d ;

 always @(posedge CLK, negedge RSTN) 
   if(~RSTN) su_tx_msg_on_is_wr_ascii <= 0 ; else su_tx_msg_on_is_wr_ascii <= su_tx_msg_on_is_wr_ascii_d ;

 always_comb
 begin
  su_cmd_tx_cntdown_d =  su_cmd_tx_cntdown;
  if (remote_access_intrfc.rsp_valid) begin
    if (su_tx_msg_on_is_rd_ascii_d) su_cmd_tx_cntdown_d = 8 ;  // returning 9 (8..0) bytes of 8 nibble ascii  to uart terminal including the line-feed
    else if (su_tx_msg_on_is_wr_ascii_d) su_cmd_tx_cntdown_d = 0 ;  // returning just line-feed    
    else su_cmd_tx_cntdown_d = 4 ;  // returning 5 bytes (4..0) , to Testbench/Smart terminal , 4  SU_CMD_RSP header byte + 4 value bytes
  end
  if (su_tx_msg_on && tx_uart_ready_out) su_cmd_tx_cntdown_d = su_cmd_tx_cntdown - 1 ;
 end
 
 logic [31:0] rsp_data ;
 always @(posedge CLK, negedge RSTN) 
    if(~RSTN) rsp_data <= 0 ; 
    else if (remote_access_intrfc.rsp_valid) rsp_data <= remote_access_intrfc.rsp_data ;
     
 wire [7:0] rsp_data_byte = (su_tx_msg_on_is_rd_ascii||su_tx_msg_on_is_wr_ascii) ? 
                                       ((su_cmd_tx_cntdown==0) ? 8'h0A   // return line feed 
                                                               : nibble_hex_ascii(rsp_data[(su_cmd_tx_cntdown-1)*4+:4])) 
                            :  rsp_data[su_cmd_tx_cntdown*8+:8] ;
                                                                                                                
 assign  su_tx_data_byte = (su_cmd_tx_cntdown==4 &&!su_tx_msg_on_is_rd_ascii) ? `SU_CMD_RSP : rsp_data_byte ;
 assign  su_tx_data_byte_valid = (su_tx_msg_on && tx_uart_ready_out) ;
 
 always @(posedge CLK, negedge RSTN) 
   if(~RSTN) su_cmd_tx_cntdown <= 0 ; else su_cmd_tx_cntdown <=  su_cmd_tx_cntdown_d ;

 //------------------------------------------------------------------------------
  
 function [7:0] nibble_hex_ascii ;
     input [3:0] nibble ; 
      nibble_hex_ascii = (nibble<=9) ? "0" + nibble : "a" +(nibble - 10) ;
 endfunction  
                       
endmodule
