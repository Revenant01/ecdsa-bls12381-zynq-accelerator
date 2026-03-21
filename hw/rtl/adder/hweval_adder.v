`timescale 1ns / 1ps

module hweval_adder (
    input   clk     ,
    input   resetn  ,
    output  data_ok );

    reg           start;
    reg           subtract;
    reg  [383:0] in_a;
    reg  [383:0] in_b;
    wire [384:0] result;
    wire         done;
       
    // Instantiate the adder    
    adder dut (
        .clk      (clk     ),
        .resetn   (resetn  ),
        .start    (start   ),
        .subtract (subtract),
        .in_a     (in_a    ),
        .in_b     (in_b    ),
        .result   (result  ),
        .done     (done    ));

    reg [1:0] state;

    always @(posedge(clk)) begin
    
        if (!resetn) begin
            in_a     <= 384'b1;
            in_b     <= 384'b1;
            subtract <= 1'b0;
                    
            start    <= 1'b0;           
            
            state    <= 2'b00;
        end else begin
    
            if (state == 2'b00) begin
                in_a     <= in_a;
                in_b     <= in_b;
                subtract <= subtract;
                
                start    <= 1'b1;            
                
                state    <= 2'b01;        
            
            end else if(state == 2'b01) begin
                in_a     <= in_a;
                in_b     <= in_b;
                subtract <= subtract;
                        
                start    <= 1'b0;           
                
                state    <= done ? 2'b10 : 2'b01;
            end
            
            else begin
                in_a     <= in_b ^ result[383:0];
                in_b     <= result[383:0];
                subtract <= result[384] & result[383];
                                    
                start    <= 1'b0;
                            
                state    <= 2'b00;
            end
        end
    end    
    
    assign data_ok = done & result[384] & result[383];
    
endmodule
