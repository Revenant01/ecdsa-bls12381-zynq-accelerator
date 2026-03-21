`timescale 1ns / 1ps

module hweval_modadder (
    input   clk     ,
    input   resetn  ,
    output  data_ok );

    reg           start;
    reg           subtract;
    reg  [380:0] in_a;
    reg  [380:0] in_b;
    reg  [380:0] in_m;
    wire [380:0] result;
    wire          done;
       
    // Instantiate the adder    
    modadder dut (
        .clk      (clk     ),
        .resetn   (resetn  ),
        .start    (start   ),
        .subtract (subtract),
        .in_a     (in_a    ),
        .in_b     (in_b    ),
        .in_m     (in_m    ),
        .result   (result  ),
        .done     (done    ));

    reg [1:0] state;

    always @(posedge(clk)) begin
    
        if (!resetn) begin
            in_a     <= 381'b1;
            in_b     <= 381'b1;
            in_m     <= 381'h1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab;
            subtract <= 1'b0;
                    
            start    <= 1'b0;           
            
            state    <= 2'b00;
        end else begin
    
            if (state == 2'b00) begin
                in_a     <= in_a;
                in_b     <= in_b;
                in_m     <= in_m;
                subtract <= subtract;
                
                start    <= 1'b1;            
                
                state    <= 2'b01;        
            
            end else if(state == 2'b01) begin
                in_a     <= in_a;
                in_b     <= in_b;
                in_m     <= in_m;
                subtract <= subtract;
                        
                start    <= 1'b0;           
                
                state    <= done ? 2'b10 : 2'b01;
            end
            
            else begin
                in_a     <= in_b ^ result[380:0];
                in_b     <= result[380:0];
                in_m     <= result[380:0] ^ 381'h1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab;
                subtract <= result[380] & result[379];
                                    
                start    <= 1'b0;
                            
                state    <= 2'b00;
            end
        end
    end    
    
    assign data_ok = done & result[380] & result[379];
    
endmodule
