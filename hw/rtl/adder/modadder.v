module modadder #(
    parameter WIDTH = 381
) (
    input clk,
    input resetn,
    input start,
    input subtract,
    input wire [WIDTH-1:0] in_a,
    input wire [WIDTH-1:0] in_b,
    input wire [WIDTH-1:0] in_m, 
    output reg [WIDTH-1:0] result,
    output reg done
);
    wire [WIDTH:0] S1_Result;
    assign S1_Result = subtract ? (in_a - in_b) : (in_a + in_b);
    wire Cout_S1_Sub = S1_Result[WIDTH];
    
    reg [WIDTH:0] P_Res;  
    reg [WIDTH-1:0] P_M;         
    reg P_Subtract;               
    reg P_Cout_Sub;
    
    reg [WIDTH:0] P2_Res;
    reg [WIDTH:0] P2_M;
    reg P2_correction;
    reg P2_subtract;
    
    reg [WIDTH:0] P3_Res;
    reg [WIDTH:0] P3_M;
    reg P3_correction;
    reg P3_subtract;
    
    wire correction_add = (P_Res >= P_M);
    wire correction_sub = P_Cout_Sub;
    
    wire [WIDTH:0] S4_Result;
    assign S4_Result = P3_correction ? (P3_subtract ? (P3_Res + P3_M) : (P3_Res - P3_M)) : P3_Res;
    
    reg [2:0] state;
    localparam CYCLE1 = 3'b001;
    localparam CYCLE2 = 3'b010;
    localparam CYCLE3 = 3'b011;
    localparam CYCLE4 = 3'b100;
    
    always @(posedge clk) begin
        if (!resetn) begin
            state <= CYCLE1;
            done <= 1'b0;
            result <= 0;
            P_Res <= 0;
            P_M <= 0;
            P_Subtract <= 0;
            P_Cout_Sub <= 0;
            P2_Res <= 0;
            P2_M <= 0;
            P2_correction <= 0;
            P2_subtract <= 0;
            P3_Res <= 0;
            P3_M <= 0;
            P3_correction <= 0;
            P3_subtract <= 0;
        end else begin
            done <= 1'b0;
            
            case (state)
//                IDLE: begin
//                    if (start) begin
//                        state <= CYCLE1;
//                    end
//                end
                
                CYCLE1: begin
                    if (start) begin
                        P_Res <= S1_Result;
                        P_M <= in_m;
                        P_Subtract <= subtract;
                        P_Cout_Sub <= Cout_S1_Sub;
                        state <= CYCLE2;
                    end
                end
                
                CYCLE2: begin
                    P2_Res <= P_Res;
                    P2_M <= P_M;
                    P2_subtract <= P_Subtract;
                    
                    if (P_Subtract) begin
                        P2_correction <= correction_sub;
                    end else begin
                        P2_correction <= correction_add;
                    end
                    
                    state <= CYCLE3;
                end
                
                CYCLE3: begin
                    P3_Res <= P2_Res;
                    P3_M <= P2_M;
                    P3_correction <= P2_correction;
                    P3_subtract <= P2_subtract;
                    state <= CYCLE4;
                end
                
                CYCLE4: begin
                    result <= S4_Result[WIDTH-1:0];
                    done <= 1'b1;
                    state <= CYCLE1;
                end
            endcase
        end
    end
endmodule