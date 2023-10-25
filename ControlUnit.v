`include "opcodes.v"

module ControlUnit (
                    input [6:0] part_of_inst,
                    output reg mem_read,
                    output reg mem_to_reg,   
                    output reg mem_write,     
                    output reg alu_src,         
                    output reg write_enable,
                    output reg pc_to_reg,
                    output reg is_jal,
                    output reg is_jalr,
                    output reg branch,
                    output reg is_ecall
                    );
                    
    always @(*) begin
          is_jal = (part_of_inst==`JAL) ? 1 : 0;
          is_jalr = (part_of_inst==`JALR) ? 1 : 0;
          branch = (part_of_inst==`BRANCH) ? 1 : 0;
          write_enable = (part_of_inst!=`STORE  && part_of_inst!=`BRANCH) ? 1 : 0;
          alu_src = (part_of_inst!=`ARITHMETIC && part_of_inst!=`BRANCH) ? 1 : 0;
          mem_read = (part_of_inst==`LOAD) ? 1 : 0;
          mem_to_reg = (part_of_inst==`LOAD) ? 1 : 0;
          mem_write = (part_of_inst==`STORE) ? 1 : 0;
          is_ecall = (part_of_inst==`ECALL) ? 1 : 0;
          pc_to_reg = (part_of_inst==`JAL || part_of_inst==`JALR) ? 1 : 0;
    end
endmodule