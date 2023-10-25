module ForwardingUnit(input [4:0] rs1_ID, input [4:0] rs2_ID, input [4:0] rs1_EX, input [4:0] rs2_EX, input [4:0] rd_MEM, input [4:0] rd_WB, input EX_MEM_reg_write, input MEM_WB_reg_write,
                        output reg [1:0] forward_A, output reg [1:0] forward_B);
    always @(*) begin
    if((rs1_EX!=0)&&(rs1_EX==rd_MEM)&&EX_MEM_reg_write) begin // dist=1
        forward_A = 2'b10;
    end
    else if((rs1_EX!=0)&&(rs1_EX==rd_WB)&&MEM_WB_reg_write) begin // dist=2
        forward_A = 2'b01;
    end
    else begin // dist>=3
        forward_A = 2'b00;
    end
    if((rs2_EX!=0)&&(rs2_EX==rd_MEM)&&EX_MEM_reg_write) begin // dist=1
        forward_B = 2'b10;
    end
    else if((rs2_EX!=0)&&(rs2_EX==rd_WB)&&MEM_WB_reg_write) begin // dist=2
        forward_B = 2'b01;
    end
    else begin // dist>=3
        forward_B = 2'b00;
    end
    end
endmodule