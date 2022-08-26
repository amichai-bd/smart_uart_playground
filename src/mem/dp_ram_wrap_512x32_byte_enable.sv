
`ifdef ALTERA
`define ALTERA_MEM
`endif

module dp_ram_wrap_512x32_byte_enable
  #(
    parameter ADDR_WIDTH = 9
  )(
    input  logic clk,

    input  logic [ADDR_WIDTH-1:0]  addr_a_i,
    input  logic [31:0]            wdata_a_i,
    output logic [31:0]            rdata_a_o,
    input  logic                   we_a_i,
    input  logic [3:0]             be_a_i,

    input  logic [ADDR_WIDTH-1:0]  addr_b_i,
    input  logic [31:0]            wdata_b_i,
    output logic [31:0]            rdata_b_o,
    input  logic                   we_b_i,
    input  logic [3:0]             be_b_i
  );

`ifdef ALTERA_MEM

dp_ram_512x32	dp_ram_512x32_inst (
	.address_a ( addr_a_i ),
	.address_b ( addr_b_i ),
	.byteena_a ( be_a_i ),
	.byteena_b ( be_b_i ),
	.clock     ( clk),
	.data_a    ( wdata_a_i ),
	.data_b    ( wdata_b_i ),
	.wren_a    ( we_a_i ),
	.wren_b    ( we_b_i ),
	.q_a       ( rdata_a_o ),
	.q_b       ( rdata_b_o )
 );

`else
dp_ram_32bit_byte_en
#(
  .ADDR_WIDTH ( ADDR_WIDTH )
  )
  dp_ram_i
  (
    .clk       ( clk       ),

    .addr_a_i  ( addr_a_i  ),
    .wdata_a_i ( wdata_a_i ),
    .rdata_a_o ( rdata_a_o ),
    .we_a_i    ( we_a_i    ),
    .be_a_i    ( be_a_i    ),

    .addr_b_i  ( addr_b_i  ),
    .wdata_b_i ( wdata_b_i ),
    .rdata_b_o ( rdata_b_o ),
    .we_b_i    ( we_b_i    ),
    .be_b_i    ( be_b_i    )
    );
`endif

endmodule

