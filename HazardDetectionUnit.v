module HazardDetectionUnit(input [6:0] opcode,
                           input [4:0] rs1_ID,
                           input [4:0] rs2_ID,
                           input [4:0] rd_EX,
                           input MemRead_EX,
                           output reg pc_write,
                           output reg IF_ID_write,
                           output reg control_op);
    wire use_rs1_IR_ID, use_rs2_IR_ID;
    assign use_rs1_IR_ID = (opcode == `ARITHMETIC || opcode == `ARITHMETIC_IMM || opcode == `LOAD || opcode == `STORE || opcode == `BRANCH || opcode == `JALR) && (rs1_ID!=0);
    assign use_rs2_IR_ID = (opcode == `ARITHMETIC || opcode == `STORE || opcode == `BRANCH) && (rs2_ID!=0);

    always@(*) begin
        if((((rs1_ID==rd_EX)&&use_rs1_IR_ID) || ((rs2_ID==rd_EX)&&use_rs2_IR_ID)) && MemRead_EX) begin
            pc_write=0;
            IF_ID_write=0;
            control_op=1;
        end
        else begin
            pc_write=1;
            IF_ID_write=1;
            control_op=0;
        end
    end
endmodule