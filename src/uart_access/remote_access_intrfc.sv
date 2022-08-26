
interface REMOTE_ACCESS_INTRFC() ;


    // Command
    logic cmd_wr_word     ; 
    logic cmd_wr_halfword ;
    logic cmd_wr_byte     ; 
    logic cmd_rd_word     ;    
    logic cmd_rd_numwords ;    
    
    logic [31:0] cmd_addr   ;
    logic [31:0] cmd_data   ; 
    logic        cmd_valid  ;
    // Response             ;
    logic [31:0] rsp_data   ;
    logic        rsp_valid  ;


  // Remote Side
  //***************************************
  modport remote
  (
    // Command
   
    output cmd_wr_word        , 
    output cmd_wr_halfword    ,
    output cmd_wr_byte        , 
    output cmd_rd_word        ,    
    output cmd_rd_numwords    ,      
    
    output cmd_addr   ,
    output cmd_data   ,  
    output cmd_valid  ,
    // Response
    input  rsp_data   ,
    input  rsp_valid  
  );

  // Local Side
  //***************************************
  modport near
  (

    input cmd_wr_word        , 
    input cmd_wr_halfword    ,
    input cmd_wr_byte        , 
    input cmd_rd_word        ,    
    input cmd_rd_numwords    ,      

    input cmd_addr   ,
    input cmd_data   ,  
    input cmd_valid  ,
    // Response
    output rsp_data   ,
    output rsp_valid  
  );

endinterface


