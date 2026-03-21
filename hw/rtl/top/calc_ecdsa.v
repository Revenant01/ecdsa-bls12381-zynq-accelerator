`timescale 1ns / 1ps

module calc_ecdsa #(
    parameter WIDTH_p = 381,    // field modulus
    parameter WIDTH_k = 255    // scalar width 
) (
    input  wire                     clk,
    input  wire                     resetn,
    input  wire                     i_start,
    input  wire [WIDTH_p-1:0]       i_p,
    
    input  wire [WIDTH_p-1:0]       i_Gx, i_Gy, i_Gz,
    input  wire [WIDTH_k-1:0]       i_m,
    
    input  wire [WIDTH_p-1:0]       i_Kx, i_Ky, i_Kz,
    input  wire [WIDTH_k-1:0]       i_s,
       
    input  wire [WIDTH_p-1:0]       i_Px, i_Py, i_Pz,
    input  wire [WIDTH_k-1:0]       i_K_X_Modn,

    
    output reg  [WIDTH_p-1:0]       o_Qx, o_Qy, o_Qz,
    output reg  [WIDTH_p-1:0]       o_Lx, o_Ly, o_Lz,
    output reg  [WIDTH_p-1:0]       o_Cx, o_Cy, o_Cz,
    output reg  [WIDTH_p-1:0]       o_Dx, o_Dy, o_Dz,
    
    output reg  [WIDTH_p-1:0]       o_LHS, o_RHS,
    
    output reg                      o_done, o_busy, o_valid
    );
    
    
   // input data registers 
  reg [WIDTH_p-1 :0] r_modulus;
  
  reg [WIDTH_k-1 :0] r_m   , r_s   , r_K_X_Modn;
  reg [WIDTH_p-1 :0] r_G_X , r_G_Y , r_G_Z     ;
  reg [WIDTH_p-1 :0] r_K_X , r_K_Y , r_K_Z     ;
  reg [WIDTH_p-1 :0] r_P_X , r_P_Y , r_P_Z     ; 
      
  // output data registers    
  reg [WIDTH_p-1:0] r_Q_x, r_Q_y, r_Q_z;
  reg [WIDTH_p-1:0] r_L_x, r_L_y, r_L_z;
  reg [WIDTH_p-1:0] r_C_x, r_C_y, r_C_z;
  reg [WIDTH_p-1:0] r_D_x, r_D_y, r_D_z; // C prime
  
  reg [WIDTH_p-1: 0] r_LHS, r_RHS;
  
  reg r_valid;
  

    reg r_ec_mult_Start, r_ec_mult_add;
    reg  [WIDTH_p-1: 0] r_ec_mult_p; 
    reg  [WIDTH_k-1: 0] r_ec_mult_k;
    reg  [WIDTH_p-1: 0] r_ec_mult_Xp, r_ec_mult_Yp, r_ec_mult_Zp;   
    reg  [WIDTH_p-1: 0] r_ec_mult_Xq, r_ec_mult_Yq, r_ec_mult_Zq;  
    wire [WIDTH_p-1: 0] o_ec_mult_Xr, o_ec_mult_Yr, o_ec_mult_Zr;
    wire o_ec_mult_done, o_ec_mult_busy;
    // Instantiate EC multiplier
    ec_mult #(.WIDTH_p(WIDTH_p),.WIDTH_k(WIDTH_k)) u_ec_mult_1 (
        .clk      (clk), .resetn (resetn),
        .i_start  (r_ec_mult_Start ), .i_ec_add (r_ec_mult_add),
        .i_p      (r_ec_mult_p ),
        .i_Xp     (r_ec_mult_Xp), .i_Yp(r_ec_mult_Yp), .i_Zp (r_ec_mult_Zp),
        .i_Xq     (r_ec_mult_Xq), .i_Yq(r_ec_mult_Yq), .i_Zq (r_ec_mult_Zq),
        .i_k      (r_ec_mult_k ),
        .o_Xr     (o_ec_mult_Xr), .o_Yr(o_ec_mult_Yr), .o_Zr(o_ec_mult_Zr),
        .o_done   (o_ec_mult_done), .o_busy(o_ec_mult_busy));
        
        
     
    reg                       r_mont_start;
    reg  [WIDTH_p-1 :0] r_mont_a, r_mont_b; 
    wire [WIDTH_p-1 :0]         o_mont_res; 
    wire                       o_mont_done;
    montgomery #(.WIDTH(WIDTH_p)) u_mont_1(
    .clk (clk), .resetn (resetn),. start(r_mont_start),
    .in_a(r_mont_a), .in_b (r_mont_b),.in_m (r_ec_mult_p),
    .result (o_mont_res), .done(o_mont_done));
    
 
    reg [3:0] state_q;
    
    localparam s_IDLE = 4'd0,
               s_CALQ = 4'd1,
               s_WATQ = 4'd2,
               s_CALL = 4'd3,
               s_WATL = 4'd4,
               s_CALD = 4'd5,
               s_WATD = 4'd6,
               s_CALC = 4'd7,
               s_WATC = 4'd8,
               s_CMLS = 4'd9,
               s_WMLS = 4'd10,
               s_CMRS = 4'd11,
               s_WMRS = 4'd12,
               s_CMPR = 4'd13,
               s_DONE = 4'd14;
               
          
    always @ (posedge clk) begin 
        if (!resetn) begin 
            state_q <= s_IDLE;
            
            // input data registers 
            r_modulus <= 'b0;             
            {r_m   , r_s   , r_K_X_Modn} <= 'b0;
            {r_G_X , r_G_Y , r_G_Z     } <= 'b0;
            {r_K_X , r_K_Y , r_K_Z     } <= 'b0;
            {r_P_X , r_P_Y , r_P_Z     } <= 'b0;
               
            // output data registers    
            {r_Q_x, r_Q_y, r_Q_z} <= 'b0;
            {r_L_x, r_L_y, r_L_z} <= 'b0;
            {r_C_x, r_C_y, r_C_z} <= 'b0;
            {r_D_x, r_D_y, r_D_z} <= 'b0; 
            
            {r_LHS, r_RHS} <= 'b0;

   
            {r_ec_mult_Start, r_ec_mult_add} <= 2'b00;
            {r_ec_mult_p,r_ec_mult_Xp, r_ec_mult_Yp, r_ec_mult_Zp,r_ec_mult_k} <= 'b0;   
            {r_ec_mult_Xq, r_ec_mult_Yq, r_ec_mult_Zq} <= 'b0; 
            
            r_mont_start <= 1'b0;
            {r_mont_a, r_mont_b} <= 'b0; 
            
            
            {o_Qx, o_Qy, o_Qz} <= 'b0;
            {o_Lx, o_Ly, o_Lz} <= 'b0;
            {o_Cx, o_Cy, o_Cz} <= 'b0;
            {o_Dx, o_Dy, o_Dz} <= 'b0;
            {o_LHS, o_RHS} <= 'b0;
            {o_done, o_busy}   <= 2'b00;     
            r_valid <= 1'b0;
        end else begin 
        
            case (state_q)
               s_IDLE: begin 
                 {o_done, o_busy, o_valid}  <= 3'b000;
                 if (i_start) begin 
                    {o_done, o_busy} <= 2'b01;
                    r_modulus <= i_p;
                    {r_G_X, r_G_Y, r_G_Z, r_m}        <= {i_Gx, i_Gy, i_Gz, i_m}; 
                    {r_K_X, r_K_Y, r_K_Z, r_s}        <= {i_Kx, i_Ky, i_Kz, i_s}; 
                    {r_P_X, r_P_Y, r_P_Z, r_K_X_Modn} <= {i_Px, i_Py, i_Pz, i_K_X_Modn}; 
                    state_q <= s_CALQ;
                    
                 end else begin 
                    state_q <= s_IDLE;
                 end     
               end 
            
               s_CALQ: begin 
                 {r_ec_mult_Start, r_ec_mult_add} <= 2'b10;
                 {r_ec_mult_Xp, r_ec_mult_Yp, r_ec_mult_Zp} <= {r_G_X, r_G_Y, r_G_Z}; 
                 {r_ec_mult_p,r_ec_mult_k} <= {r_modulus,r_m};     
               
                 state_q <= s_WATQ;
               end
               
               s_WATQ: begin 
                 {r_ec_mult_Start, r_ec_mult_add} <= 2'b00;
                 
                 if (o_ec_mult_done) begin 
                    {r_Q_x, r_Q_y, r_Q_z} <= {o_ec_mult_Xr, o_ec_mult_Yr, o_ec_mult_Zr};
                    state_q <= s_CALL;
                 end else begin 
                    state_q <= s_WATQ;
                 end
               
               end
               
               
               s_CALL: begin 
                 {r_ec_mult_Start, r_ec_mult_add} <= 2'b10;
                 {r_ec_mult_Xp, r_ec_mult_Yp, r_ec_mult_Zp} <= {r_P_X, r_P_Y, r_P_Z}; 
                 {r_ec_mult_p,r_ec_mult_k} <= {r_modulus,r_K_X_Modn};     
               
                 state_q <= s_WATL;
               end
               
               s_WATL: begin          
                 {r_ec_mult_Start, r_ec_mult_add} <= 2'b00;
                 
                 if (o_ec_mult_done) begin 
                    {r_L_x, r_L_y, r_L_z} <= {o_ec_mult_Xr, o_ec_mult_Yr, o_ec_mult_Zr};
                    state_q <= s_CALD;
                 end else begin 
                    state_q <= s_WATL;
                 end
               
               end
               
               
               s_CALD: begin 
                 {r_ec_mult_Start, r_ec_mult_add} <= 2'b10;
                 {r_ec_mult_Xp, r_ec_mult_Yp, r_ec_mult_Zp} <= {r_K_X, r_K_Y, r_K_Z}; 
                 {r_ec_mult_p,r_ec_mult_k} <= {r_modulus,r_s};     
               
                 state_q <= s_WATD;               
               end 
               
               s_WATD: begin 
                 {r_ec_mult_Start, r_ec_mult_add} <= 2'b00;
                 
                 if (o_ec_mult_done) begin 
                    {r_D_x, r_D_y, r_D_z} <= {o_ec_mult_Xr, o_ec_mult_Yr, o_ec_mult_Zr};
                    state_q <= s_CALC;
                 end else begin 
                    state_q <= s_WATD;
                 end               
               end
               
               s_CALC: begin 
                 {r_ec_mult_Start, r_ec_mult_add} <= 2'b11;
                 {r_ec_mult_Xp, r_ec_mult_Yp, r_ec_mult_Zp} <= {r_Q_x, r_Q_y, r_Q_z}; 
                 {r_ec_mult_Xq, r_ec_mult_Yq, r_ec_mult_Zq} <= {r_L_x, r_L_y, r_L_z}; 
                 {r_ec_mult_p,r_ec_mult_k} <= {r_modulus,r_s};     
               
                 state_q <= s_WATC;               
               end 
               
               s_WATC: begin 
                 {r_ec_mult_Start, r_ec_mult_add} <= 2'b00;
                 
                 if (o_ec_mult_done) begin 
                    {r_C_x, r_C_y, r_C_z} <= {o_ec_mult_Xr, o_ec_mult_Yr, o_ec_mult_Zr};
                    
                    state_q <= s_CMLS;  
                 end else begin 
                    state_q <= s_WATC;
                 end               
               end
               
               
               s_CMLS: begin 
                 r_mont_start <= 1'b1;
                 {r_mont_a,r_mont_b,r_ec_mult_p} <= {r_C_z,r_D_x,r_modulus};
                 
                 state_q <= s_WMLS;
               end
               
               s_WMLS: begin 
                 r_mont_start <= 1'b0;
                 if (o_mont_done) begin 
                    r_LHS <= o_mont_res;
                    
                    state_q <= s_CMRS;
                 end else begin 
                    state_q <= s_WMLS;
                 end
               
               end
               
               s_CMRS: begin 
                 r_mont_start <= 1'b1;
                 {r_mont_a,r_mont_b,r_ec_mult_p} <= {r_D_z,r_C_x,r_modulus};
                 
                 state_q <= s_WMRS;
               end
               
               s_WMRS: begin 
                 r_mont_start <= 1'b0;
                 if (o_mont_done) begin 
                    r_RHS <= o_mont_res;
                    
                    state_q <= s_CMPR;
                 end else begin 
                    state_q <= s_WMRS;
                 end             
               end
               
               s_CMPR: begin
                 r_valid <= (r_LHS == r_RHS);
                 state_q <= s_DONE;
               end
                                         
               s_DONE: begin 
                 {o_done,o_busy, o_valid}    <= {1'b1,1'b0,r_valid};
                 {o_Qx, o_Qy, o_Qz} <= {r_Q_x, r_Q_y, r_Q_z};
                 {o_Lx, o_Ly, o_Lz} <= {r_L_x, r_L_y, r_L_z};
                 {o_Cx, o_Cy, o_Cz} <= {r_C_x, r_C_y, r_C_z};
                 {o_Dx, o_Dy, o_Dz} <= {r_D_x, r_D_y, r_D_z};
                 {o_LHS, o_RHS}     <= {r_LHS, r_RHS};
                 state_q <= s_IDLE;
               end
            
            endcase
        
        
        end
    
    end 

endmodule
