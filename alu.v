`include "opcodes.v"

module ALU(input [3:0] alu_op, input [31:0] alu_in_1, input [31:0] alu_in_2, output reg [31:0] alu_result, output reg alu_zero, output reg alu_bcond);

  always @(*) begin
    // branch condition
    if(alu_op[3] == 1) begin
      if(alu_op == `FUNCT_BEQ) alu_bcond = (alu_in_1 == alu_in_2);
      else if(alu_op == `FUNCT_BNE) alu_bcond = (alu_in_1 != alu_in_2);
      else if(alu_op == `FUNCT_BLT) alu_bcond = (alu_in_1 < alu_in_2);
      else if(alu_op == `FUNCT_BGE) alu_bcond = (alu_in_1 >= alu_in_2);
    end
    else alu_bcond = 1'b0;

    // kind of operation
    if(alu_op[3] == 1) alu_result = alu_in_1 + alu_in_2;
    case(alu_op)
        `FUNCT_ADD:
            alu_result = alu_in_1 + alu_in_2;
        `FUNCT_SUB:
            alu_result = alu_in_1 - alu_in_2;
        `FUNCT_OR:
            alu_result = alu_in_1 | alu_in_2;
        `FUNCT_AND:
            alu_result = alu_in_1 & alu_in_2;
        `FUNCT_SLL:
            alu_result = alu_in_1 << alu_in_2;
        `FUNCT_SRL:
            alu_result = alu_in_1 >> alu_in_2;
        `FUNCT_XOR:
            alu_result = alu_in_1 ^ alu_in_2;
    endcase
  end
endmodule

module ALUControlUnit(input [31:0] part_of_inst, output reg [3:0] alu_op);
  reg [6:0] funct7;
  reg [2:0] funct3;
  reg [6:0] opcode;
  
  always @(*) begin
    funct7 = part_of_inst[31:25];
    funct3 = part_of_inst[14:12];
    opcode = part_of_inst[6:0];
    if(opcode == `ARITHMETIC || opcode == `ARITHMETIC_IMM) begin
      if(funct3 == `FUNCT3_ADD) begin
          if(opcode != `ARITHMETIC_IMM && funct7 == `FUNCT7_SUB) alu_op = `FUNCT_SUB;
          else alu_op = `FUNCT_ADD;
      end
      else if(funct3 == `FUNCT3_OR) alu_op = `FUNCT_OR;
      else if(funct3 == `FUNCT3_AND) alu_op = `FUNCT_AND;
      else if(funct3 == `FUNCT3_SLL) alu_op = `FUNCT_SLL;
      else if(funct3 == `FUNCT3_SRL) alu_op = `FUNCT_SRL;
      else if(funct3 == `FUNCT3_XOR) alu_op = `FUNCT_XOR;
    end
    else if((opcode == `LOAD && funct3 == `FUNCT3_LW) || (opcode == `STORE && funct3 == `FUNCT3_SW))
      alu_op = `FUNCT_ADD;
    else if(opcode == `BRANCH) begin
      if(funct3 == `FUNCT3_BEQ) alu_op = `FUNCT_BEQ;
      else if(funct3 == `FUNCT3_BNE) alu_op = `FUNCT_BNE;
      else if(funct3 == `FUNCT3_BLT) alu_op = `FUNCT_BLT;
      else if(funct3 == `FUNCT3_BGE) alu_op = `FUNCT_BGE;
    end
  end
endmodule