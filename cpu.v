// Submit this file with other files you created.
// Do not touch port declarations of the module 'CPU'.

// Guidelines
// 1. It is highly recommened to `define opcodes and something useful.
// 2. You can modify modules (except InstMemory, DataMemory, and RegisterFile)
// (e.g., port declarations, remove modules, define new modules, ...)
// 3. You might need to describe combinational logics to drive them into the module (e.g., mux, and, or, ...)
// 4. `include files if required
module PC(input reset, input clk, input ctrl, input [31:0] next_pc, output reg [31:0] current_pc);
  always @(posedge clk) begin
    if (reset) current_pc <= 32'b0;
    else if(ctrl) current_pc <= next_pc;
  end
endmodule

module adder(input [31:0] input0, input [31:0] input1, output reg [31:0] result);
  always @(*) begin
      result = input0 + input1;
  end
endmodule

module Mux_1bit(input [31:0] input0, input [31:0] input1, input ctrl, output reg [31:0] result);
  always @(*) begin
      result = (ctrl ? input1 : input0);
  end
endmodule

module Mux_2bit(input [31:0] input0, input [31:0] input1, input [31:0] input2, input [1:0] ctrl, output reg [31:0] result);
  always @(*) begin
      case(ctrl)
        2'b00: result = input0;
        2'b01: result = input1;
        2'b10: result = input2;
      endcase
  end
endmodule

module HaltDetector(input is_ecall, input [31:0] x17, output reg is_halt);
  always @(*) begin
     is_halt = (is_ecall && (x17 == 32'ha)) ? 1 : 0;
  end
endmodule

module CPU(input reset,       // positive reset signal
           input clk,         // clock signal
           output is_halted
           ); // Whehther to finish simulation
  /***** Wire declarations *****/
  wire [31:0] current_pc;
  wire [31:0] next_pc, predicted_pc;
  wire [31:0] instr;
  wire signed [31:0] rs1_data, rs2_data, rd_data_1, rd_data, imm_value, target_pc, correct_pc, jump_rd_data;
  wire mem_read, mem_write, mem_to_reg, reg_write, is_ecall, pc_to_reg, is_halt, is_jal, is_jalr, branch;
  wire control_op;
  wire [1:0] forward_A, forward_B;
  wire [1:0] alu_src;
  wire [4:0] alu_op;
  wire [4:0] rs1, rs2, rd;
  wire [31:0] n_pc_4, pc_4, pc_imm, alu_input1, alu_input2, alu_input2_in, alu_result;
  wire [31:0] mem_data;
  wire pc_write, alu_zero;
  wire pc_src;
  wire IF_ID_write; // reg to wire
  wire is_input_valid, is_output_valid, is_ready, is_hit;

  /***** Register declarations *****/
  // You need to modify the width of registers
  // In addition,
  // 1. You might need other pipeline registers that are not described below
  // 2. You might not need registers described below
  /***** IF/ID pipeline registers *****/
  reg [31:0] IF_ID_inst;           // will be used in ID stage
  reg [31:0] IF_ID_pc;
  /***** ID/EX pipeline registers *****/
  // From the control unit
  reg ID_EX_is_jal;         // will be used in EX stage
  reg ID_EX_is_jalr;         // will be used in EX stage
  reg ID_EX_branch;         // will be used in EX stage
  reg ID_EX_alu_src;        // will be used in EX stage
  reg ID_EX_mem_write;      // will be used in MEM stage
  reg ID_EX_mem_read;       // will be used in MEM stage
  reg ID_EX_mem_to_reg;     // will be used in WB stage
  reg ID_EX_reg_write;      // will be used in WB stage
  reg ID_EX_pc_to_reg; // will be used in MEM stage
  reg ID_EX_is_ecall; 
  // From others
  reg [31:0] ID_EX_rs1_data;
  reg [31:0] ID_EX_rs2_data;
  reg [31:0] ID_EX_imm;
  reg [31:0] ID_EX_predicted_pc;
  reg [31:0] ID_EX_ALU_ctrl_unit_input;
  reg [31:0] ID_EX_pc;
  reg [4:0] ID_EX_rs1; // for forwarding unit
  reg [4:0] ID_EX_rs2; // for forwarding unit
  reg [4:0] ID_EX_rd; // for forwarding unit
  /***** EX/MEM pipeline registers *****/
  // From the control unit
  reg EX_MEM_mem_write;     // will be used in MEM stage
  reg EX_MEM_mem_read;      // will be used in MEM stage
  reg EX_MEM_mem_to_reg;    // will be used in WB stage
  reg EX_MEM_reg_write;     // will be used in WB stage
  reg EX_MEM_is_halted;     // will be used in WB stage
  reg EX_MEM_pc_to_reg; // will be used in MEM stage
  
  // From others
  reg [31:0] EX_MEM_target_pc;
  reg [31:0] EX_MEM_alu_out;
  reg [31:0] EX_MEM_dmem_data;
  reg [31:0] EX_MEM_jump_rd_data;
  reg [4:0] EX_MEM_rd;

  /***** MEM/WB pipeline registers *****/
  // From the control unit
  reg MEM_WB_mem_to_reg;    // will be used in WB stage
  reg MEM_WB_reg_write;     // will be used in WB stage
  reg MEM_WB_is_halted;     // will be used in WB stage -> is_halted
  reg MEM_WB_pc_to_reg; // will be used in MEM stage
  // From others
  reg [31:0] MEM_WB_mem_to_reg_src_1;
  reg [31:0] MEM_WB_mem_to_reg_src_2;
  reg [31:0] MEM_WB_jump_rd_data;
  reg [4:0] MEM_WB_rd;      // for forwarding unit

  // ---------- Update program counter ----------
  // PC must be updated on the rising edge (positive edge) of the clock.
  PC pc(
    .reset(reset),       // input (Use reset to initialize PC. Initial value must be 0)
    .clk(clk),         // input
    .ctrl(pc_write && !stall_cond),         // input
    .next_pc(next_pc),     // input
    .current_pc(current_pc)   // output
  );

  BranchPredictor branch_predictor (
    .reset(reset),
    .clk(clk),
    .jump_or_branch(ID_EX_is_jal || ID_EX_is_jalr || ID_EX_branch),
    .is_actually_taken(is_actually_taken),
    .current_pc(current_pc),
    .prev_pc(ID_EX_pc),
    .target_pc(target_pc),
    .predicted_pc(predicted_pc)
  );

  // adder pc_adder(
  //   .input0(current_pc),
  //   .input1(32'b100),
  //   .result(n_pc_4)
  // );

  Mux_1bit pc_mux(
    .input0(predicted_pc),
    .input1(correct_pc),
    .ctrl(pc_src),
    .result(next_pc)
  );

  // ---------- Instruction Memory ----------
  InstMemory imem(
    .reset(reset),   // input
    .clk(clk),     // input
    .addr(current_pc),    // input
    .dout(instr)     // output
  );

  // Update IF/ID pipeline registers here
  always @(posedge clk) begin
    if (reset || (pc_src && !stall_cond)) begin
      IF_ID_inst <= 0;
      //IF_ID_write <= 1'b1;
    end
    else begin
      //IF_ID_write <= ir_write;
      if (IF_ID_write && !stall_cond) begin
        IF_ID_inst <= instr;
        IF_ID_pc <= current_pc;
      end
    end
  end

  Mux_1bit rs1_mux(
    .input0(IF_ID_inst[19:15]),
    .input1(5'b10001), // x17
    .ctrl(is_ecall),
    .result(rs1)
  );

  // ---------- Register File ----------
  RegisterFile reg_file (
    .reset (reset),        // input
    .clk (clk),          // input
    .rs1 (rs1),          // input
    .rs2 (IF_ID_inst[24:20]),          // input
    .rd (MEM_WB_rd),           // input
    .rd_din (rd_data),       // input
    .write_enable (MEM_WB_reg_write),    // input
    .rs1_dout (rs1_data),     // output
    .rs2_dout (rs2_data)      // output
  );
 
  HaltDetector halt_detector (
    .is_ecall(ID_EX_is_ecall),
    .x17(alu_input1),
    .is_halt(is_halt) // output
  );

  // ---------- Control Unit ----------
  ControlUnit ctrl_unit (
    .part_of_inst(IF_ID_inst[6:0]),  // input
    .mem_read(mem_read),      // output
    .mem_to_reg(mem_to_reg),    // output
    .mem_write(mem_write),     // output
    .alu_src(alu_src),       // output
    .write_enable(reg_write),  // output
    .is_jal(is_jal),  // output
    .is_jalr(is_jalr),  // output
    .branch(branch),  // output
    .pc_to_reg(pc_to_reg),        // output
    .is_ecall(is_ecall)       // output (ecall inst)
  );

  // ---------- Immediate Generator ----------
  ImmediateGenerator imm_gen(
    .part_of_inst(IF_ID_inst),  // input
    .imm_gen_out(imm_value)    // output
  );

  // Update ID/EX pipeline registers here
  always @(posedge clk) begin
    if (reset || (pc_src && !stall_cond)) begin
      ID_EX_alu_src <= 2'b00;
      ID_EX_mem_write <= 1'b0;      
      ID_EX_mem_read <= 1'b0; 
      ID_EX_mem_to_reg <= 1'b0; 
      ID_EX_reg_write <= 1'b0;
      ID_EX_is_ecall <= 1'b0;
      ID_EX_pc_to_reg <= 1'b0;
      ID_EX_is_jal <= 1'b0;       // will be used in EX stage
      ID_EX_is_jalr <= 1'b0;         // will be used in EX stage
      ID_EX_branch <= 1'b0;         // will be used in EX stage
      // From others
      ID_EX_pc <= 32'b0;
      ID_EX_rs1_data <= 32'b0;
      ID_EX_rs2_data <= 32'b0;
      ID_EX_imm <= 32'b0;
      ID_EX_ALU_ctrl_unit_input <= 32'b0;
      ID_EX_rs1 <= 5'b0;
      ID_EX_rs2 <= 5'b0;
      ID_EX_rd <= 5'b0;
    end
    else if (!stall_cond) begin
      ID_EX_alu_src <= control_op ? 0 : alu_src;
      ID_EX_mem_write <= control_op ? 0 : mem_write;      
      ID_EX_mem_read <= control_op ? 0 : mem_read;
      ID_EX_mem_to_reg <= control_op ? 0 : mem_to_reg;
      ID_EX_reg_write <= control_op ? 0 : reg_write;
      ID_EX_pc_to_reg <= control_op ? 0: pc_to_reg;
      ID_EX_is_jal <= control_op ? 0 : is_jal;
      ID_EX_is_jalr <= control_op ? 0 : is_jalr; 
      ID_EX_branch <= control_op ? 0 : branch;        
      // From others
      ID_EX_rs1_data <= rs1_data;
      ID_EX_rs2_data <= rs2_data;
      ID_EX_imm <= imm_value;
      ID_EX_ALU_ctrl_unit_input <= IF_ID_inst[31:0];
      ID_EX_rs1 <= rs1;
      ID_EX_rs2 <= IF_ID_inst[24:20];
      ID_EX_rd <= IF_ID_inst[11:7];
      ID_EX_is_ecall <= is_ecall;
      ID_EX_pc <= IF_ID_pc;
    end
  end

 ForwardingUnit forwarding_unit(
    .rs1_ID(rs1),
    .rs2_ID(IF_ID_inst[24:20]),
    .rs1_EX(ID_EX_rs1),
    .rs2_EX(ID_EX_rs2),
    .rd_MEM(EX_MEM_rd), //ID_EX_rd
    .rd_WB(MEM_WB_rd),
    .EX_MEM_reg_write(EX_MEM_reg_write),
    .MEM_WB_reg_write(MEM_WB_reg_write),
    .forward_A(forward_A),
    .forward_B(forward_B)
  );

  Mux_2bit alu_src1_mux(
    .input0(ID_EX_rs1_data),
    .input1(rd_data),
    .input2(EX_MEM_alu_out),
    .ctrl(forward_A),
    .result(alu_input1)
  );

  Mux_2bit alu_scr2_mux(
    .input0(ID_EX_rs2_data),
    .input1(rd_data),
    .input2(EX_MEM_alu_out),
    .ctrl(forward_B),
    .result(alu_input2_in)
  );

  Mux_1bit alu_scr2_2_mux(
    .input0(alu_input2_in),
    .input1(ID_EX_imm),
    .ctrl(ID_EX_alu_src),
    .result(alu_input2)
  );

  // ---------- ALU Control Unit ----------
  ALUControlUnit alu_ctrl_unit (
    .part_of_inst(ID_EX_ALU_ctrl_unit_input),  // input
    .alu_op(alu_op)         // output
  );

  // ---------- ALU ----------
  ALU alu (
    .alu_op(alu_op),      // input
    .alu_in_1(alu_input1),    // input
    .alu_in_2(alu_input2),    // input
    .alu_result(alu_result),  // output
    .alu_zero(alu_zero),     // output
    .alu_bcond(alu_bcond) // output
  );

  adder pc_imme_adder(
    .input0(ID_EX_pc),
    .input1(ID_EX_imm),
    .result(pc_imm)
  );

  adder pc_4_adder(
    .input0(ID_EX_pc),
    .input1(32'b100),
    .result(pc_4)
  );      

  BranchUnit branch_unit(
    .is_jal(ID_EX_is_jal),
    .is_jalr(ID_EX_is_jalr),
    .branch(ID_EX_branch),
    .alu_bcond(alu_bcond),
    .pc_imm(pc_imm),
    .pc_4(pc_4),
    .alu_result(alu_result),
    .pc_src(pc_src),
    .stall_cond(stall_cond),
    .is_actually_taken(is_actually_taken),
    .next_inst_pc(IF_ID_pc),
    .correct_pc(correct_pc),
    .target_pc(target_pc),
    .rd_data(jump_rd_data)
  );

  // Update EX/MEM pipeline registers here
  always @(posedge clk) begin
    if (reset) begin
      EX_MEM_mem_write <= 1'b0;     
      EX_MEM_mem_read <= 1'b0;      
      EX_MEM_mem_to_reg <= 1'b0;    
      EX_MEM_reg_write <= 1'b0;       
      EX_MEM_is_halted <= 1'b0;        
      EX_MEM_alu_out <= 32'b0;   
      EX_MEM_dmem_data <= 32'b0; 
      EX_MEM_jump_rd_data <= 32'b0;
      EX_MEM_rd <= 5'b0; 
    end
    else if (!stall_cond) begin
      EX_MEM_mem_write <= ID_EX_mem_write;     
      EX_MEM_mem_read <= ID_EX_mem_read;     
      EX_MEM_mem_to_reg <= ID_EX_mem_to_reg;    
      EX_MEM_reg_write <= ID_EX_reg_write;       
      EX_MEM_is_halted <= is_halt;       
      EX_MEM_alu_out <= alu_result;
      EX_MEM_dmem_data <= alu_input2_in;
      EX_MEM_pc_to_reg <= ID_EX_pc_to_reg;
      EX_MEM_jump_rd_data <= jump_rd_data;
      EX_MEM_rd <= ID_EX_rd;
    end
  end

  Cache cache(
    .reset(reset),
    .clk(clk),
    .is_input_valid(EX_MEM_mem_read || EX_MEM_mem_write),
    .addr(EX_MEM_alu_out),
    .mem_read(EX_MEM_mem_read),
    .mem_write(EX_MEM_mem_write),
    .din(EX_MEM_dmem_data),
    .is_ready(is_ready),
    .is_output_valid(is_output_valid),
    .is_data_mem_input_valid(is_data_mem_input_valid),
    .is_data_mem_output_valid(is_data_mem_output_valid),
    .data_mem_out(data_mem_out),
    .dout(mem_data),
    .is_hit(is_hit)
    );

  assign stall_cond = (EX_MEM_mem_read || EX_MEM_mem_write) && !(is_ready && is_output_valid && is_hit) ?  1 : 0;

  // ---------- Data Memory ----------
  // DataMemory dmem(
  //   .reset (reset),      // input
  //   .clk (clk),        // input
  //   .addr (EX_MEM_alu_out),       // input
  //   .din (EX_MEM_dmem_data),        // input
  //   .mem_read (EX_MEM_mem_read),   // input
  //   .mem_write (EX_MEM_mem_write),  // input
  //   .dout (mem_data)        // output -> MEM_WB_mem_to_reg_src_1
  // );

  // Update MEM/WB pipeline registers here
  always @(posedge clk) begin
    if (reset) begin
      MEM_WB_mem_to_reg <= 1'b0;
      MEM_WB_reg_write <= 1'b0;
      MEM_WB_is_halted <= 1'b0;
      MEM_WB_mem_to_reg_src_1 <= 32'b0;
      MEM_WB_mem_to_reg_src_2 <= 32'b0;
      MEM_WB_jump_rd_data <= 32'b0;
      MEM_WB_rd <= 5'b0;
    end
    else if(!stall_cond) begin
      MEM_WB_mem_to_reg <= EX_MEM_mem_to_reg;  
      MEM_WB_reg_write <= EX_MEM_reg_write;  
      MEM_WB_is_halted <= EX_MEM_is_halted;
      MEM_WB_mem_to_reg_src_1 <= mem_data;
      MEM_WB_pc_to_reg <= EX_MEM_pc_to_reg;
      MEM_WB_jump_rd_data <= EX_MEM_jump_rd_data;
      MEM_WB_mem_to_reg_src_2 <= EX_MEM_alu_out;
      MEM_WB_rd <= EX_MEM_rd;
    end
  end

  Mux_1bit rd_data_mux(
    .input0(MEM_WB_mem_to_reg_src_2),
    .input1(MEM_WB_mem_to_reg_src_1),
    .ctrl(MEM_WB_mem_to_reg),
    .result(rd_data_1)
  );

  Mux_1bit rd_data_mux2(
    .input0(rd_data_1),
    .input1(MEM_WB_jump_rd_data),
    .ctrl(MEM_WB_pc_to_reg),
    .result(rd_data)
  );

 // ---------- HazardDetectionUnit & ForwardingUnit ---------- 
 HazardDetectionUnit hazard_detection_unit(
    .opcode(IF_ID_inst[6:0]),
    .rs1_ID(IF_ID_inst[19:15]),
    .rs2_ID(IF_ID_inst[24:20]),
    .rd_EX(ID_EX_rd),
    .MemRead_EX(ID_EX_mem_read),
    .pc_write(pc_write), // output
    .IF_ID_write(IF_ID_write), // output
    .control_op(control_op)
  );

  assign is_halted = MEM_WB_is_halted;
endmodule
