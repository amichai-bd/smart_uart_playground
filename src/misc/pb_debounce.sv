
// Push Button is  "1" when unpressed and is "0" while pressed subject to bouncing.

module pb_debounce 
    #(parameter 
       NUM_STABLE_CYCLES_REQUIRED = 0,
       CYCLE_COUNT_WIDTH = $clog2(NUM_STABLE_CYCLES_REQUIRED)  // don't modify
     ) (   
   input rst_n, // Async Reset, In case not available connect to permanent "1" (for example when the push-button is the reset signal itself"
   input clk, 
   input pb_in, 
   output logic pb_out);
  

    logic pb_in_s0 ;       // pb_in sync sample #1
    logic pb_in_synced ;   // pb_in sync sample #2
    logic pb_in_sampled ;  // pb_in sync sample #3
    
    logic [CYCLE_COUNT_WIDTH-1:0] bouncing_mask_cycle_cnt ;
    
    logic bouncing_mask_period_on ;
    
    logic pb_in_toggled ;
        
    // Sync and sample button in
    always @(posedge clk) begin 
      pb_in_s0 <= pb_in;
      pb_in_synced <= pb_in_s0;
      pb_in_sampled <= pb_in_synced;
    end
    
    assign pb_in_toggled = (pb_in_sampled==!pb_in_synced) ; 
                                  
    // bouncing mask counter         
             
    always @(posedge clk or negedge rst_n) 
       if (!rst_n) bouncing_mask_cycle_cnt <= NUM_STABLE_CYCLES_REQUIRED ; // Assume no masking upon reset
       else bouncing_mask_cycle_cnt <= 
         pb_in_toggled ? 0 : (bouncing_mask_period_on ? bouncing_mask_cycle_cnt+1 : NUM_STABLE_CYCLES_REQUIRED) ;
    
    assign bouncing_mask_period_on = bouncing_mask_cycle_cnt < NUM_STABLE_CYCLES_REQUIRED ;
    
      // Notice that in case reset is not applied bouncing_mask_cycle_cnt is expected to 
      // eventually reach NUM_STABLE_CYCLES_REQUIRED upon power-up prior to first button press 
      // and thus bouncing_mask_period_on will deassert in less than NUM_STABLE_CYCLES_REQUIRED after power-up      

    always @(posedge clk or negedge rst_n) 
      if (!rst_n) pb_out <= 1 ;  // Assume un-pressed at reset (if applied)
      else pb_out <= bouncing_mask_period_on ? pb_out :      // Don't update output along the bouncing mask period. 
       (pb_in_toggled ? pb_in_synced : pb_in_sampled) ;      // Update to toggled value , right after non-masked toggle
                                                             // otherwise propagate pb_in  
    
endmodule