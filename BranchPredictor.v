`include "opcodes.v"

module BranchPredictor(
    input reset,
    input clk,
    input jump_or_branch,
    input is_actually_taken,
    input [31:0] current_pc,
    input [31:0] prev_pc,
    input [31:0] target_pc,
    output reg [31:0] predicted_pc
    );

    reg [4:0] index;
    reg [4:0] prev_index;

    reg [24:0] tag_table[0:31];
    reg [31:0] BTB[0:31];
    reg [1:0] BHT[0:31];
    reg is_taken;

    integer i;

    always @(*) begin
        if (jump_or_branch) begin
            prev_index = prev_pc[6:2];
            if (tag_table[prev_index] == prev_pc[31:7]) begin
                BHT[prev_index] = is_actually_taken ?
                        (BHT[prev_index] < 2'b11 ? BHT[prev_index] + 2'b01 : BHT[prev_index])
                        : (BHT[prev_index] > 2'b00 ? BHT[prev_index] - 2'b01 : BHT[prev_index]);
            end
            else begin
                if (is_actually_taken) begin
                    tag_table[prev_index] <= prev_pc[31:7];
                    BTB[prev_index] <= target_pc;
                    BHT[prev_index] <= 2'b01;
                end
            end
        end
    end

    always @(*) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1) begin
                BTB[i] = 32'bx;
                BHT[i] = 2'bx;
                tag_table[i] = 24'bx;
            end
        end
        else begin
            index = current_pc[6:2];
            if (tag_table[index] == current_pc[31:7]) begin
                is_taken = BHT[index] >= 2'b10 ? 1 : 0;
                predicted_pc = (is_taken) ? BTB[index] : current_pc + 32'b100;
            end
            else begin
                predicted_pc = current_pc + 32'b100;
            end
        end
    end
endmodule