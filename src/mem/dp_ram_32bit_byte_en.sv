
module dp_ram_32bit_byte_en
  #(
    parameter ADDR_WIDTH = 8
  )(
    // Clock and Reset
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

  localparam words = 2**ADDR_WIDTH;

  logic [3:0][7:0] mem[words];

  always @(posedge clk)
  begin
    if (we_a_i)
    begin
      if (be_a_i[0])
        mem[addr_a_i][0] <= wdata_a_i[7:0];
      if (be_a_i[1])
        mem[addr_a_i][1] <= wdata_a_i[15:8];
      if (be_a_i[2])
        mem[addr_a_i][2] <= wdata_a_i[23:16];
      if (be_a_i[3])
        mem[addr_a_i][3] <= wdata_a_i[31:24];
    end

    rdata_a_o <=  mem[addr_a_i] ;

    if (we_b_i)
    begin
      if (be_b_i[0])
        mem[addr_b_i][0] <= wdata_b_i[7:0];
      if (be_b_i[1])
        mem[addr_b_i][1] <= wdata_b_i[15:8];
      if (be_b_i[2])
        mem[addr_b_i][2] <= wdata_b_i[23:16];
      if (be_b_i[3])
        mem[addr_b_i][3] <= wdata_b_i[31:24];
    end

   rdata_b_o <=  mem[addr_b_i] ;  
  
  end
  
  


endmodule
