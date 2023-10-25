`include "opcodes.v"

module BranchUnit(input is_jal, input is_jalr, input branch, input alu_bcond, input [31:0] pc_imm, input stall_cond, input [31:0] pc_4, input [31:0] alu_result, input [31:0] next_inst_pc,
    output reg pc_src, output reg is_actually_taken, output reg [31:0] target_pc, output reg [31:0] correct_pc, output reg [31:0] rd_data); // pc, pc+4, rd, pc+imm, rs1+imm
    reg [6:0] opcode;
    always @(*) begin
        if (branch) begin
            // target = pc+imm
            // if alu_bcond: next_pc<-target, else: next_pc<-pc+4
            target_pc = pc_imm;
            is_actually_taken = alu_bcond ? 1 : 0;
            correct_pc = alu_bcond ? pc_imm : pc_4;
            pc_src = (next_inst_pc != correct_pc) ? 1'b1 : 1'b0;
        end
        else if (is_jal) begin
            // pc <- pc+imm
            // GRP[rd] <- pc+4
            is_actually_taken = 1'b1;
            target_pc = pc_imm;
            correct_pc = pc_imm;
            rd_data = pc_4;
            pc_src = (next_inst_pc != correct_pc) ? 1'b1 : 1'b0;
        end
        else if (is_jalr) begin
            // pc <- GPR[rs1]+imm
            // GRP[rd] <- pc+4
            is_actually_taken = 1'b1;
            target_pc = alu_result;
            correct_pc = alu_result;
            rd_data = pc_4;
            pc_src = (next_inst_pc != correct_pc) ? 1'b1 : 1'b0;
        end
        else begin
            is_actually_taken = 1'b0;
            correct_pc = pc_4;
            pc_src = 1'b0;
        end
    end
endmodule