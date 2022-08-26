`include "smart_uart_defines.sv"
`include "fpga_lab_defines.sv"

import sock::*; // To support remote python interface

`define VERILOG_STDIN  32'h8000_0000 // Verilog pre-opened
`define VERILOG_STDOUT 32'h8000_0002 // Verilog pre-opened

interface py_uart_bus
  #(
    parameter BAUDRATE  = `BAUDRATE,
    parameter PARITY_EN = `PARITY_EN  
    )
  ( 
    input  uart_rx,
    output logic uart_tx,
    input  enable_uart_tb
  );
  
  timeunit      1ns;
  timeprecision 1ps;
  
  localparam NS_PER_BIT    = 1000000000/BAUDRATE;   
  localparam CLK_PERIOD_NS = `UART_CLK_PERIOD_NS ; 
  localparam CLK_DIV_CNTR  = (NS_PER_BIT/CLK_PERIOD_NS)-1  ; 

  real ns_per_bit_actual ;
  real ns_per_bit_actual_prev ;  
      
  logic [7:0]       character,ms_char,ls_char;
  logic             parity;
  
  
  logic prompt_active = 0 ; 
  logic su_cmd_rsp_active = 0 ; 
  logic su_uart_gateway_msg_on = 0 ;
  logic [31:0] su_arg_word ;

  logic remote_py_mode = 0 ;
  logic rx_in_char_valid = 0 ;
  
  int su_rsp_byte_cnt = 0 ;  // response to smart uart terminal 
  string remote_py_rsp_str ; 
  logic  rsp_expected = 0 ;
  
  chandle h;
  logic remote_py_mode_defined = 0 ;
  logic set_uart_rate_on = 0 ; 
  logic [15:0] clk_div_cntr_ovrd_val = 0 ;
  
  initial
  begin  

    //shall print %t with scaled in ns (-9), with 2 precision digits, and would print the " ns" string
    $timeformat(-9, 0, "ns", 10);
  
    $display("\n\n tb.sv: UART TB INFO: CORRECTED BAUDRATE = %-d , CLK_DIV_CNTR =%-d" , BAUDRATE ,CLK_DIV_CNTR) ;    
    uart_tx   = 1'b1;
`ifdef REMOTE_PY
    remote_py_mode_defined = 1 ;
     ns_per_bit_actual = NS_PER_BIT ;
    //#0 ;    
`endif
  end

  // Capture RX characters
   
  always begin

      @(negedge uart_rx);
      rx_in_char_valid = 0 ;// Mostly for debug
      #(ns_per_bit_actual/2) ;
      for (int i=0;i<=7;i++) 
        #ns_per_bit_actual character[i] = uart_rx;
      if(PARITY_EN == 1)
      begin
        // check parity
        #ns_per_bit_actual parity = uart_rx;
        for (int i=7;i>=0;i--) parity = character[i] ^ parity;
        if(parity == 1'b1)
        begin
          $display("tb.sv: Parity error detected");
        end
      end      
      #ns_per_bit_actual; // STOP BIT
      
      rx_in_char_valid = 1 ; // Mostly for debug
      
      if ((character==`SU_CMD_RSP) && !su_cmd_rsp_active) begin
        su_cmd_rsp_active = 1 ;
        remote_py_rsp_str = "" ;
      end 

      if (su_cmd_rsp_active && (su_rsp_byte_cnt>0)) begin
         if (su_rsp_byte_cnt<5) begin   // skip SU_CMD_RSP byte
           if (character[7:4]<=9) ms_char = "0" + character[7:4]  ;
           else ms_char = "a" +(character[7:4] - 10) ;
           remote_py_rsp_str =  {remote_py_rsp_str,string'(ms_char)} ;  
           if (character[3:0]<=9) ls_char = "0" + character[3:0]  ;
           else ls_char = "a" +(character[3:0] - 10) ;                            
           remote_py_rsp_str =  {remote_py_rsp_str,string'(ls_char)} ;   
         end 
         su_rsp_byte_cnt =  su_rsp_byte_cnt-1 ;
         if (su_rsp_byte_cnt==0) begin
           su_cmd_rsp_active = 0 ;
           $display("%0t tb.sv: Sending remote_py_rsp_str : %s " ,$time,remote_py_rsp_str) ;
	       if(!sock_writeln(h,remote_py_rsp_str)) begin
		     $error("Socket access error");
		     sock_shutdown();
		     $stop();
           end
           rsp_expected = 0 ;
         end
      end  

      else begin  // print input from uart     
           $write("%c", character); // ascii charterer from uart           
           if (su_uart_gateway_msg_on && (character==8'h0A)) begin
              su_uart_gateway_msg_on = 0 ;   
              prompt_active = 1 ;                      
           end                                                                                   
      end    
  end // always 
  
  // Send Terminal-input to DUT 
  logic [7:0] c ;   
 
  logic prompt_msg_on = 0 ;    

  always @(posedge enable_uart_tb) prompt_active = 1'b1 ; 
 
  always @(prompt_active) begin 
     su_uart_gateway_msg_on = 0 ;

     prompt_msg_on = 1 ;
          
     if (!remote_py_mode_defined) $write("Ready> ");
             
     while (prompt_active) begin 
     
           if (!remote_py_mode_defined) c = $fgetc(`VERILOG_STDIN) ;
           
           if (c=="#") su_uart_gateway_msg_on = 1 ;
           
           if  (su_uart_gateway_msg_on && (c=="q")) begin
             $display("\n\nUART TB Detected #q , Quitting \n\n") ;  
             $finish ;
           end  
           
           if  ((c=="p") || remote_py_mode_defined) begin
             $display("\nEntering remote python mode\n") ;  
             prompt_active = 0 ;
             sock_connect ; 
             remote_py_mode = 1 ;
           end   
           
           if (!remote_py_mode) begin
             send_char(c); // send to apb slave for core to read                                           
             prompt_active = (c!=8'h0A) ; // Return control on line feed                                   
             if (!prompt_active) prompt_msg_on = 0 ;  
           end
     end // while
     
   end  // always    

// --------------------------------- Check for remote py commands  ---------------------------------------------

logic wait_after_reset = 1 ;
initial begin
 wait_after_reset = 1 ;
 #1000 ;
 wait_after_reset = 0 ;
end 

 always begin
   if (wait_after_reset) wait (wait_after_reset==0) ; 
   if (!remote_py_mode) wait (remote_py_mode==1) ;   
   if (rsp_expected) wait  (rsp_expected ==0) ;      
   receive_remote_py_cmd ;
 end


// --------------------------------- SEND_CHAR PRIMARY TASK ---------------------------------------------

  task send_char(input logic [7:0] c);
    int i;

    // start bit
    uart_tx = 1'b0;

    for (i = 0; i < 8; i++) begin
      #(ns_per_bit_actual);
      uart_tx = c[i];
    end

    // stop bit
    #(ns_per_bit_actual);
    uart_tx = 1'b1;
    #(ns_per_bit_actual);
  endtask


//--------------------------------------------------------------------

  task sock_connect ;

	// Init
	if(sock_init() < 0) begin
		$error("Error couldn't init the socket");
		$stop();
	end 

	// Connect
	h = sock_open("tcp://localhost:1234");
	if(h == null) begin
		$error("ERROR couldn't connect to socket");
		sock_shutdown();
		$stop();
	end 

	// Send / receive
	if(!sock_writeln(h, "Hello from System-Verilog!")) begin
		$error("Socket access error");
		sock_shutdown();
		$stop();
	end
	$display("tb.sv: %s",sock_readln(h));
  
  endtask
    
//---------------------------------------------------------------------


task receive_remote_py_cmd ; // From now on uart communication is connected to the remote python 

   string  remote_py_cmd_str  ;
   integer str_idx ;
   logic [7:0] rp_c ;
   logic ignore_space ;
   logic is_last_c ;
   logic arg_is_avail ;


   integer byte_idx  ;
   integer nibble_idx  ;
   
   
   while (!rsp_expected) begin

       remote_py_cmd_str = sock_readln(h) ;
      
      $display ("%0t tb.sv: Remote Py Command: %s",$time,remote_py_cmd_str) ; // Debug Option
      
      ignore_space = 0 ;
      is_last_c  = 0 ;
      arg_is_avail = 0 ;
      byte_idx = 0 ;
      nibble_idx = 0 ;
      set_uart_rate_on = 0 ;
            
      for (str_idx=0 ; str_idx < remote_py_cmd_str.len() ; str_idx++) begin
        
                  rp_c = remote_py_cmd_str.getc(str_idx) ; 
                  
                  is_last_c = (str_idx == (remote_py_cmd_str.len()-1)) ;  
                  arg_is_avail = is_last_c || (rp_c==8'h0A) || ((rp_c==" ") && !ignore_space) ;
      

                  if (rp_c=="Q") begin
                        $display("\n\n tb.sv: Detected remote quit command. Quitting \n\n") ;                    
                        sock_close(h);
                        sock_shutdown();
                        $finish ;
                  end else if (rp_c=="W") begin
                       send_char(`SU_CMD_WR_WORD); 
                       ignore_space = 1 ;
                  end  else if (rp_c=="R") begin
                       su_rsp_byte_cnt = 5 ;       // SU_CMD_RSP byte + data word 
                       rsp_expected = 1 ;                       
                       send_char(`SU_CMD_RD_WORD); 
                       ignore_space = 1 ;                    
                  end else if ((rp_c>="0")&&(rp_c<="9")) begin 
                     su_arg_word[(7-nibble_idx)*4+:4] = (rp_c - "0") ;
                     nibble_idx++;   
                     ignore_space = 0 ;                    
                  end else if ((rp_c>="a")&&(rp_c<="f")) begin 
                     su_arg_word[(7-nibble_idx)*4+:4] = 10+(rp_c - "a") ; 
                     nibble_idx++;  
                     ignore_space = 0 ;     
                  end                              
                  
                  if (arg_is_avail) begin                    
                       su_arg_word = su_arg_word >> ((8-nibble_idx)*4) ;                       
                       for (byte_idx=3;byte_idx>=0;byte_idx--) send_char(su_arg_word[(byte_idx*8) +: 8]);
                       nibble_idx = 0 ;
                       byte_idx = 0 ;                      
                  end                  
      end  // for
 end // while         
   
endtask 

endinterface

