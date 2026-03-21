`timescale 1ns / 1ps

module ec_mult #(
    parameter WIDTH_p = 381,    // field modulus
    parameter WIDTH_k = 255,    // scalar width 
    parameter WIDTH_i = $clog2(WIDTH_k)
) (
    input  wire                     clk,
    input  wire                     resetn,
    input  wire                     i_start,
    input  wire                     i_ec_add, // 1=Add, 0=Mult
    input  wire [WIDTH_p-1:0]       i_p,
    input  wire [WIDTH_p-1:0]       i_Xp, i_Yp, i_Zp,
    input  wire [WIDTH_p-1:0]       i_Xq, i_Yq, i_Zq,
    input  wire [WIDTH_k-1:0]       i_k,
    output reg  [WIDTH_p-1:0]       o_Xr, o_Yr, o_Zr,
    output reg                      o_done, o_busy
);

    // FSM states
    localparam s_IDLE        = 4'd0;
    localparam s_ADDB        = 4'd1;
    localparam s_WADD        = 4'd2;
    localparam s_CHK1S       = 4'd3;
    localparam s_DOUBLE      = 4'd4;
    localparam s_WAIT_DOUBLE = 4'd5;
    localparam s_ADD         = 4'd6;
    localparam s_WAIT_ADD    = 4'd7;
    localparam s_DONE        = 4'd8;

    reg [3:0] state_q;
    reg ec_adder_start_q;
    reg [WIDTH_p-1:0] ec_adder_Xp_q, ec_adder_Yp_q, ec_adder_Zp_q;
    reg [WIDTH_p-1:0] ec_adder_Xq_q, ec_adder_Yq_q, ec_adder_Zq_q;
    reg [WIDTH_p-1:0] ec_adder_p_q;
    wire [WIDTH_p-1:0] o_ec_adder_Xr, o_ec_adder_Yr, o_ec_adder_Zr;
    wire o_ec_adder_done, o_ec_adder_busy;

    reg [WIDTH_p-1:0] R_x, R_y, R_z; 
    reg [WIDTH_p-1:0] P_x, P_y, P_z; 
    reg [WIDTH_p-1:0] Q_x, Q_y, Q_z; 
    reg [WIDTH_k-1:0] k_reg; 
    reg [WIDTH_i-1:0] bit_idx_q;
    
    wire bit_idx_zero = (bit_idx_q == {WIDTH_i{1'b0}});

    ec_adder_v3 #(.WIDTH_p(WIDTH_p)) u_ecadder_1 (
        .clk(clk), .resetn(resetn), .i_start(ec_adder_start_q), .i_p(ec_adder_p_q),
        .i_Xp(ec_adder_Xp_q), .i_Yp(ec_adder_Yp_q), .i_Zp(ec_adder_Zp_q),
        .i_Xq(ec_adder_Xq_q), .i_Yq(ec_adder_Yq_q), .i_Zq(ec_adder_Zq_q),
        .o_Xr(o_ec_adder_Xr), .o_Yr(o_ec_adder_Yr), .o_Zr(o_ec_adder_Zr),
        .o_done(o_ec_adder_done), .o_busy(o_ec_adder_busy)
    );

    always @(posedge clk) begin
        if (!resetn) begin
            state_q <= s_IDLE;
            ec_adder_start_q <= 0;
            o_done <= 0; o_busy <= 0;
            bit_idx_q <= WIDTH_k-1;
        end else begin
            case (state_q)
                default: begin o_done <= 0; o_busy <= 1; end 
                
                s_IDLE: begin
                    o_done <= 0; o_busy <= 0;
                    if (i_start) begin 
                        o_busy <= 1;
                        bit_idx_q <= WIDTH_k-1;
                        ec_adder_p_q <= i_p;
                        {R_x, R_y, R_z} <= {381'd0, 381'd1, 381'd0};
                        {P_x, P_y, P_z} <= {i_Xp, i_Yp, i_Zp};
                        {Q_x, Q_y, Q_z} <= {i_Xq, i_Yq, i_Zq};
                        k_reg <= i_k;
                        
                        if (i_ec_add) state_q <= s_ADDB;
                        else state_q <= s_CHK1S;
                    end 
                end 
                
                // --- Bypass Mode (Addition) ---
                s_ADDB: begin 
                    {ec_adder_Xp_q, ec_adder_Yp_q, ec_adder_Zp_q} <= {P_x, P_y, P_z};
                    {ec_adder_Xq_q, ec_adder_Yq_q, ec_adder_Zq_q} <= {Q_x, Q_y, Q_z};
                    ec_adder_start_q <= 1;
                    state_q <= s_WADD;
                end 
                
                s_WADD: begin 
                    ec_adder_start_q <= 0;
                    if (o_ec_adder_done) begin 
                        {R_x, R_y, R_z} <= {o_ec_adder_Xr, o_ec_adder_Yr, o_ec_adder_Zr};  
                        state_q <= s_DONE;
                    end
                end
                
                // --- Multiplication Loop ---
                s_CHK1S: begin 
                    if (k_reg[bit_idx_q]) begin 
                       state_q <= s_DOUBLE;
                    end else begin 
                       // BUG FIX: Must check for zero before decrementing!
                       if (bit_idx_zero) state_q <= s_DONE;
                       else begin
                           bit_idx_q <= bit_idx_q - 1;
                           state_q <= s_CHK1S;   
                       end
                    end
                end
                
                s_DOUBLE: begin 
                    {ec_adder_Xp_q, ec_adder_Yp_q, ec_adder_Zp_q} <= {R_x, R_y, R_z};
                    {ec_adder_Xq_q, ec_adder_Yq_q, ec_adder_Zq_q} <= {R_x, R_y, R_z};
                    ec_adder_start_q <= 1;
                    state_q <= s_WAIT_DOUBLE;
                end 
                
                s_WAIT_DOUBLE: begin 
                    ec_adder_start_q <= 0;
                    if (o_ec_adder_done) begin 
                        {R_x, R_y, R_z} <= {o_ec_adder_Xr, o_ec_adder_Yr, o_ec_adder_Zr};
                        if (k_reg[bit_idx_q]) begin 
                            state_q <= s_ADD;
                        end else begin 
                            if (bit_idx_zero) state_q <= s_DONE;
                            else begin
                                bit_idx_q <= bit_idx_q - 1;
                                state_q <= s_DOUBLE;
                            end
                        end
                    end
                end
                
                s_ADD: begin               
                    {ec_adder_Xp_q, ec_adder_Yp_q, ec_adder_Zp_q} <= {R_x, R_y, R_z};
                    {ec_adder_Xq_q, ec_adder_Yq_q, ec_adder_Zq_q} <= {P_x, P_y, P_z};
                    ec_adder_start_q <= 1;
                    state_q <= s_WAIT_ADD;
                end 
                
                s_WAIT_ADD: begin 
                    ec_adder_start_q <= 0;
                    if (o_ec_adder_done) begin 
                        {R_x, R_y, R_z} <= {o_ec_adder_Xr, o_ec_adder_Yr, o_ec_adder_Zr};
                        if (bit_idx_zero) state_q <= s_DONE;
                        else begin
                            bit_idx_q <= bit_idx_q - 1;
                            state_q <= s_DOUBLE;
                        end
                    end
                end
                
                s_DONE: begin 
                    o_busy <= 0; o_done <= 1;
                    state_q <= s_IDLE;
                    {o_Xr, o_Yr, o_Zr} <= {R_x, R_y, R_z};
                end
            endcase
        end
    end
endmodule