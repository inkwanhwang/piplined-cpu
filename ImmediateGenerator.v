`include "opcodes.v"

module ImmediateGenerator(input [31:0] part_of_inst, output reg [31:0] imm_gen_out);
    always @(*) begin
        case (part_of_inst[6:0])
            // I-type instructions
            `ARITHMETIC_IMM: 
                imm_gen_out = $signed({part_of_inst[31:20]});
            `LOAD:
                imm_gen_out =  $signed({part_of_inst[31:20]});
            `JALR:
                imm_gen_out =  $signed({part_of_inst[31:20]});
            // S-type instruction 
            `STORE:
                imm_gen_out = $signed({part_of_inst[31:25], part_of_inst[11:7]});
            // B-type instruction 
            `BRANCH:
                imm_gen_out = $signed({part_of_inst[31:31], part_of_inst[7:7], part_of_inst[30:25], part_of_inst[11:8], 1'b0});
            // J-type instruction 
            `JAL:
                imm_gen_out = $signed({part_of_inst[31:31], part_of_inst[19:12], part_of_inst[20:20], part_of_inst[30:21], 1'b0});
        endcase
    end
endmodule