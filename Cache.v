module Cache #(parameter LINE_SIZE = 16,
               parameter NUM_SETS = 1,
               parameter NUM_WAYS = 1,
               parameter BLOCK_SIZE = 16) (
    input reset,
    input clk,

    input is_input_valid,
    input [31:0] addr,
    input mem_read,
    input mem_write,
    input [31:0] din,

    output is_ready,
    output is_data_mem_input_valid, 
    output is_data_mem_output_valid,
    output is_output_valid,
    output [BLOCK_SIZE * 8 - 1:0] data_mem_out,
    output [31:0] dout,
    output is_hit);
  // Wire declarations
  wire is_data_mem_ready;
  wire is_data_mem_output_valid;
  wire [BLOCK_SIZE * 8 - 1:0] data_mem_out;
  reg [127:0] data_mem_in;
  reg [31:0] clk_count;
  wire [31:0] cache_data;
  
  // You might need registers to keep the status.
  // Reg declarations
  reg [23:0] tag[0:15];
  reg valid[0:15];
  reg dirty[0:15];
  reg [31:0] data_mem_addr;
  reg [31:0] data[0:3][0:15];
  reg data_mem_read;
  reg data_mem_write;
  wire is_output_valid;
  
  integer i, j;
  assign is_ready = is_data_mem_ready;

  // cache read async
  assign is_hit = ((tag[addr[7:4]] == addr[31:8]) && valid[addr[7:4]]) ? 1 : 0;
  assign dout = data[addr[3:2]][addr[7:4]];
  assign is_output_valid = (is_hit || (is_data_mem_ready && is_data_mem_output_valid));

  // g = addr[1:0]
  // bo = addr[3:2]
  // idx = addr[7:4]
  // tag = addr[31:8]

  // initialize
  always @(*) begin
    if (reset) begin
        for (i = 0; i < 16; i = i + 1) begin
            dirty[i] <= 0;
            valid[i] <= 0;
            tag[i] <= 24'b0;
            for (j = 0; j < 4; j = j + 1) begin
               data[j][i] <= 32'b0;
            end
        end
        clk_count <= 0;
    end
  end

  always @(posedge clk) begin
    if (is_output_valid || !is_input_valid) begin
        clk_count <= 0;
    end
    else begin
      clk_count <= 1;
    end
  end

  always @(*) begin
    if (is_hit && is_input_valid) begin
      data_mem_read <= 0;
      data_mem_write <= 0;
      if (mem_write) begin
         data[addr[3:2]][addr[7:4]] <= din;
         dirty[addr[7:4]] <= 1;
         valid[addr[7:4]] <= 1;
      end
    end
  end

  always @(*) begin
    // cache miss
    if(!is_hit && is_input_valid) begin
        if (dirty[addr[7:4]] && clk_count == 0) begin
            // (evict) write-back
            // memory write request
            data_mem_addr <= {tag[addr[7:4]], addr[7:4]};
            data_mem_read <= 0;
            data_mem_write <= 1;
            data_mem_in <= {data[3][addr[7:4]], data[2][addr[7:4]], data[1][addr[7:4]], data[0][addr[7:4]]};
        end
        // memory read request
        else if (is_data_mem_ready && !is_data_mem_output_valid) begin
          data_mem_read <= 1;
          data_mem_write <= 0;
          data_mem_addr <= (addr >> 4);
        end
        if (is_data_mem_ready && is_data_mem_output_valid) begin
          data_mem_read <= 0;
          data_mem_write <= 0;
          tag[addr[7:4]] <= addr[31:8];
          data[3][addr[7:4]] <= (mem_write && (addr[3:2] == 3)) ? din : data_mem_out[127:96];
          data[2][addr[7:4]] <= (mem_write && (addr[3:2] == 2)) ? din : data_mem_out[95:64];
          data[1][addr[7:4]] <= (mem_write && (addr[3:2] == 1)) ? din : data_mem_out[63:32];  
          data[0][addr[7:4]] <= (mem_write && (addr[3:2] == 0)) ? din : data_mem_out[31:0];
          valid[addr[7:4]] <= 1;
          dirty[addr[7:4]] <= mem_write ? 1 : 0;
        end
    end
  end

  // Instantiate data memory
  DataMemory data_mem(
    .reset(reset),
    .clk(clk),
    .is_input_valid(data_mem_read || data_mem_write),
    .addr(data_mem_addr),        // NOTE: address must be shifted by CLOG2(LINE_SIZE)
    .mem_read(data_mem_read),
    .mem_write(data_mem_write),
    .din(data_mem_in),
    // is output from the data memory valid?
    .is_output_valid(is_data_mem_output_valid),
    .dout(data_mem_out),
    // is data memory ready to accept request?
    .mem_ready(is_data_mem_ready)
  );
endmodule
