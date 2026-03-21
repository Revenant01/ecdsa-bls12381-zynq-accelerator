`timescale 1ns / 1ps

module hweval_ec_adder(
    input   clk     ,
    input   resetn  ,
    output  data_ok );

    reg          i_start;
    reg  [380:0] i_p;
    reg  [380:0] i_Xp;
    reg  [380:0] i_Yp;
    reg  [380:0] i_Zp;
    reg  [380:0] i_Xq;
    reg  [380:0] i_Yq;
    reg  [380:0] i_Zq;
    wire [380:0] o_Xr;
    wire [380:0] o_Yr;
    wire [380:0] o_Zr;
    wire         o_done;
    wire         o_busy;
    
    // Instantiating ec_adder module
    ec_adder_v3 #(
        .WIDTH_p(381)
    ) dut (
        .clk     (clk     ),
        .resetn  (resetn  ),
        .i_start (i_start ),
        .i_p     (i_p     ),
        .i_Xp    (i_Xp    ),
        .i_Yp    (i_Yp    ),
        .i_Zp    (i_Zp    ),
        .i_Xq    (i_Xq    ),
        .i_Yq    (i_Yq    ),
        .i_Zq    (i_Zq    ),
        .o_Xr    (o_Xr    ),
        .o_Yr    (o_Yr    ),
        .o_Zr    (o_Zr    ),
        .o_done  (o_done  ),
        .o_busy  (o_busy  )
    );

    reg [1:0] state;

    always @(posedge clk) begin
    
        if (!resetn) begin
            // Initialize with BLS12-381 curve modulus
            i_p      <= 381'h1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab;
            
            // Initialize point P (using simple test values)
            i_Xp     <= 381'b1;
            i_Yp     <= 381'b1;
            i_Zp     <= 381'b1;
            
            // Initialize point Q (using simple test values)
            i_Xq     <= 381'b1;
            i_Yq     <= 381'b1;
            i_Zq     <= 381'b1;
                    
            i_start  <= 1'b0;           
            
            state    <= 2'b00;
            
        end else begin
    
            if (state == 2'b00) begin
                // Keep inputs stable
                i_p      <= i_p;
                i_Xp     <= i_Xp;
                i_Yp     <= i_Yp;
                i_Zp     <= i_Zp;
                i_Xq     <= i_Xq;
                i_Yq     <= i_Yq;
                i_Zq     <= i_Zq;
                
                i_start  <= 1'b1;            
                
                state    <= 2'b01;        
            
            end else if (state == 2'b01) begin
                // Keep inputs stable, deassert start
                i_p      <= i_p;
                i_Xp     <= i_Xp;
                i_Yp     <= i_Yp;
                i_Zp     <= i_Zp;
                i_Xq     <= i_Xq;
                i_Yq     <= i_Yq;
                i_Zq     <= i_Zq;
                        
                i_start  <= 1'b0;           
                
                state    <= o_done ? 2'b10 : 2'b01;
                
            end else begin
                // Update inputs based on results (XOR pattern similar to montgomery)
                i_p      <= i_p;
                i_Xp     <= i_Xq ^ o_Xr[380:0];
                i_Yp     <= o_Yr[380:0];
                i_Zp     <= o_Zr[380:0];
                i_Xq     <= o_Xr[380:0];
                i_Yq     <= i_Yq ^ o_Yr[380:0];
                i_Zq     <= i_Zq ^ o_Zr[380:0];
                                    
                i_start  <= 1'b0;
                            
                state    <= 2'b00;
            end
        end
    end    
    
    // Check that result is valid (at least one coordinate has MSB set)
    assign data_ok = o_done & (o_Xr[380] | o_Yr[380] | o_Zr[380]);
    
endmodule