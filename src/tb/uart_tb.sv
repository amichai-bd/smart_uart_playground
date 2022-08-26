
`include "fpga_lab_defines.sv"
`include "smart_uart_defines.sv"

`define VERILOG_STDIN  32'h8000_0000 // Verilog pre-opened
`define VERILOG_STDOUT 32'h8000_0002 // Verilog pre-opened

interface uart_bus
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
 

  localparam NS_PER_BIT = 1000000000/BAUDRATE;   
  localparam CLK_PERIOD_NS = `CLK_PERIOD_NS ;
  localparam CLK_DIV_CNTR = (NS_PER_BIT/CLK_PERIOD_NS)-1 ; 

    
  logic [7:0]       character,ms_char,ls_char;
  logic             parity;
  logic [31:0]      dpi_ret_val ;  // dpi tasks return values
  
  
  logic prompt_active = 0 ; 
  logic su_cmd_rsp_active = 0 ; 
  logic su_uart_gateway_msg_on = 0 ;

  int su_rsp_byte_cnt = 0 ;  // response to smart uart terminal 
  int dpi_rsp_byte_cnt = 0 ; // response to mem_dpi.svh
  
  initial
  begin  
    $display("\n\nUART TB INFO: BAUDRATE = %-d , CLK_DIV_CNTR =%-d" , BAUDRATE ,CLK_DIV_CNTR) ;    
    uart_tx   = 1'b1;
  end

  // Capture RX characters

  always begin

      @(negedge uart_rx);
      #(NS_PER_BIT/2) ;
      for (int i=0;i<=7;i++) 
        #NS_PER_BIT character[i] = uart_rx;
      if(PARITY_EN == 1)
      begin
        // check parity
        #NS_PER_BIT parity = uart_rx;
        for (int i=7;i>=0;i--) parity = character[i] ^ parity;
        if(parity == 1'b1)
        begin
          $display("Parity error detected");
        end
      end      
      #NS_PER_BIT; // STOP BIT
      
      if (character==`SU_CMD_RSP) su_cmd_rsp_active = 1 ;

      if (su_cmd_rsp_active && (su_rsp_byte_cnt>0)) begin
         if (su_rsp_byte_cnt<5) begin   // skip SU_CMD_RSP byte
           if (character[7:4]<=9) ms_char = "0" + character[7:4]  ;
           else ms_char = "a" +(character[7:4] - 10) ;
           $write("%c", ms_char);
           if (character[3:0]<=9) ls_char = "0" + character[3:0]  ;
           else ls_char = "a" +(character[3:0] - 10) ;                            
           $write("%c", ls_char);
         end 
         su_rsp_byte_cnt =  su_rsp_byte_cnt-1 ;
         if (su_rsp_byte_cnt==0) su_cmd_rsp_active = 0 ;
      end  
      else if (su_cmd_rsp_active && (dpi_rsp_byte_cnt>0)) begin 
         if (dpi_rsp_byte_cnt<5) dpi_ret_val[(dpi_rsp_byte_cnt-1)*8 +: 8] = character ; // skip SU_CMD_RSP byte
         dpi_rsp_byte_cnt =  dpi_rsp_byte_cnt-1 ; 
         if (dpi_rsp_byte_cnt==0) su_cmd_rsp_active = 0 ;         
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

  integer byte_idx = 0 ;
  logic dpi_msg_on = 0 ; 
  logic prompt_msg_on = 0 ;    

  always @(posedge enable_uart_tb) prompt_active = 1'b1 ; 
 
  always @(prompt_active) begin               
     su_uart_gateway_msg_on = 0 ;

     if (dpi_msg_on) wait (!dpi_msg_on) ; // Avoid collision on tx 
     
     prompt_msg_on = 1 ;
     $write("Ready> ");
     
     while (prompt_active) begin     
           c = $fgetc(`VERILOG_STDIN) ;           
           if (c=="#") su_uart_gateway_msg_on = 1 ; 
           if  (su_uart_gateway_msg_on && (c=="q")) begin
             $display("\n\nUART TB Detected #q , Quitting \n\n") ;  
             $finish ;
           end            
           send_char(c); // send to apb slave for core to read                                           
           prompt_active = (c!=8'h0A) ; // Return control on line feed                                   
           if (!prompt_active) prompt_msg_on = 0 ;           
     end // while
     
   end  // always    

// --------------------------------- SEND_CHAR PRIMARY TASK ---------------------------------------------

  task send_char(input logic [7:0] c);
    int i;

    // start bit
    uart_tx = 1'b0;

    for (i = 0; i < 8; i++) begin
      #(NS_PER_BIT);
      uart_tx = c[i];
    end

    // stop bit
    #(NS_PER_BIT);
    uart_tx = 1'b1;
    #(NS_PER_BIT);
  endtask

// ---------------------- DPI TASKS TO INTERFACE WITH C/C++ IN CASE APPLIED ----------------------

 // Master Read/Write over uart, mostly to suppurt mem_dpi.svh debugger interface

  task uart_read_nword;
    input   [31:0] addr;
    input int      n;
    inout [31:0] data_out[];
    logic [31:0] word_addr ;
    if (prompt_msg_on) wait (!prompt_msg_on) ; // Avoid collision on tx    
    dpi_msg_on = 1 ;
    word_addr = addr ;
    for (int i=0;i<n;i++) begin
       word_addr = addr + 4*i ;
       send_char(`SU_CMD_RD_WORD);
       dpi_rsp_byte_cnt = 5 ;  // SU_CMD_RSP byte + data word
       for (byte_idx=3;byte_idx>=0;byte_idx--) send_char(word_addr[(byte_idx*8) +: 8]);   
       wait (su_cmd_rsp_active==1) ;
       wait (dpi_rsp_byte_cnt==0) ;  
       data_out[i][31:0] = uart.dpi_ret_val[31:0] ; 
     end  
     dpi_msg_on = 0 ;
  endtask
  
 
  task uart_read_word;
    input   [31:0] addr;
    output  [31:0] data;
    logic   [31:0] tmp[1];
    begin
      uart_read_nword(addr, 1, tmp);
      data = tmp[0];
    end
  endtask

  task uart_read_halfword;
    input   [31:0] addr;
    output  [15:0] data;

    logic   [31:0] temp;
    begin
      uart_read_word({addr[31:2], 2'b00}, temp);

      case (addr[1])
        1'b0: data[15:0] = temp[15: 0];
        1'b1: data[15:0] = temp[31:16];
      endcase
    end
  endtask

  task uart_read_byte;
    input   [31:0] addr;
    output  [ 7:0] data;

    logic   [31:0] temp;
    begin
      uart_read_word({addr[31:2], 2'b00}, temp);

      case (addr[1:0])
        2'b00: data[7:0] = temp[ 7: 0];
        2'b01: data[7:0] = temp[15: 8];
        2'b10: data[7:0] = temp[23:16];
        2'b11: data[7:0] = temp[31:24];
      endcase
    end
  endtask

  task uart_write_word;
    input   [31:0] addr;
    input   [31:0] data;
    int b ;
    begin
       send_char(`SU_CMD_WR_WORD);
       for (b=3;b>=0;b--) send_char(addr[(b*8) +: 8]);    
       for (b=3;b>=0;b--) send_char(data[(b*8) +: 8]);       
    end
  endtask
 
  task uart_write_halfword;
    input   [31:0] addr;
    input   [15:0] data;
    logic   [31:0] temp;
    begin
      uart_read_word({addr[31:2], 2'b00}, temp);

      case (addr[1])
        1'b0: temp[15: 0] = data[15:0];
        1'b1: temp[31:16] = data[15:0];
      endcase

      uart_write_word({addr[31:2], 2'b00}, temp);
    end
  endtask

  task uart_write_byte;
    input   [31:0] addr;
    input   [ 7:0] data;

    logic   [31:0] temp;
    begin
      uart_read_word({addr[31:2], 2'b00}, temp);

      case (addr[1:0])
        2'b00: temp[ 7: 0] = data[7:0];
        2'b01: temp[15: 8] = data[7:0];
        2'b10: temp[23:16] = data[7:0];
        2'b11: temp[31:24] = data[7:0];
      endcase

      uart_write_word({addr[31:2], 2'b00}, temp);
    end
  endtask

endinterface

