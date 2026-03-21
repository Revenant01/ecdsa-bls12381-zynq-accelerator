module ec_adder_v3 #(
    parameter WIDTH_p = 381
) (
    // General control
    input wire clk,
    input wire resetn,

    // input control
    input wire i_start,

    // curve modulus (p)
    input wire [WIDTH_p-1 : 0] i_p,

    // Input points P, Q (Projective coordinates XYZ)
    input wire [WIDTH_p-1 : 0] i_Xp,
    input wire [WIDTH_p-1 : 0] i_Yp,
    input wire [WIDTH_p-1 : 0] i_Zp,

    input wire [WIDTH_p-1 : 0] i_Xq,
    input wire [WIDTH_p-1 : 0] i_Yq,
    input wire [WIDTH_p-1 : 0] i_Zq,  // tie to one if second point is affine


    //output point R = P + Q
    output reg [WIDTH_p-1 : 0] o_Xr,
    output reg [WIDTH_p-1 : 0] o_Yr,
    output reg [WIDTH_p-1 : 0] o_Zr,

    //output control
    output reg o_done,
    output reg o_busy
);


  reg [WIDTH_p -1 : 0] r_Xp,r_Yp,r_Zp;
  reg [WIDTH_p -1 : 0] r_Xq,r_Yq,r_Zq;
  reg [WIDTH_p -1 : 0] r_p;

  // First modular adder 
  reg r_modaddSub1_start_q, r_modaddSub1_sub_q;
  reg [WIDTH_p-1:0] r_modaddSub1_a_q, r_modaddSub1_b_q, r_modaddSub1_m_q;
  wire w_modaddSub1_done;
  wire [WIDTH_p-1:0] w_modaddSub1_res;

  modadder #(.WIDTH(WIDTH_p)) u_modaddSub1 (
      .clk(clk),
      .resetn(resetn),
      .start(r_modaddSub1_start_q),
      .subtract(r_modaddSub1_sub_q),
      .in_a(r_modaddSub1_a_q),
      .in_b(r_modaddSub1_b_q),
      .in_m(r_modaddSub1_m_q),
      .result(w_modaddSub1_res),
      .done(w_modaddSub1_done));

  // Second modular adder 
  reg r_modaddSub2_start_q, r_modaddSub2_sub_q;
  reg [WIDTH_p-1:0] r_modaddSub2_a_q, r_modaddSub2_b_q, r_modaddSub2_m_q;
  wire w_modaddSub2_done;
  wire [WIDTH_p-1:0] w_modaddSub2_res;

  modadder #(.WIDTH(WIDTH_p)) u_modaddSub2 (
      .clk(clk),
      .resetn(resetn),
      .start(r_modaddSub2_start_q),
      .subtract(r_modaddSub2_sub_q),
      .in_a(r_modaddSub2_a_q),
      .in_b(r_modaddSub2_b_q),
      .in_m(r_modaddSub2_m_q),
      .result(w_modaddSub2_res),
      .done(w_modaddSub2_done));
      
      
      
  // Third modular adder 
  reg r_modaddSub3_start_q, r_modaddSub3_sub_q;
  reg [WIDTH_p-1:0] r_modaddSub3_a_q, r_modaddSub3_b_q, r_modaddSub3_m_q;
  wire w_modaddSub3_done;
  wire [WIDTH_p-1:0] w_modaddSub3_res;

  modadder #(.WIDTH(WIDTH_p)) u_modaddSub3 (
      .clk(clk),
      .resetn(resetn),
      .start(r_modaddSub3_start_q),
      .subtract(r_modaddSub3_sub_q),
      .in_a(r_modaddSub3_a_q),
      .in_b(r_modaddSub3_b_q),
      .in_m(r_modaddSub3_m_q),
      .result(w_modaddSub3_res),
      .done(w_modaddSub3_done));
      
      
      

  // First Montgomery Multiplier
  reg r_montMul1_start_q;
  reg [WIDTH_p-1:0] r_montMul1_a_q, r_montMul1_b_q, r_montMul1_m_q;
  wire w_montMul1_done;
  wire [WIDTH_p-1:0] w_montMul1_res;


  montgomery #(.WIDTH(WIDTH_p)) u_montMul1 (
      .clk(clk),
      .resetn(resetn),
      .start(r_montMul1_start_q),
      .in_a(r_montMul1_a_q),
      .in_b(r_montMul1_b_q),
      .in_m(r_montMul1_m_q),
      .result(w_montMul1_res),
      .done(w_montMul1_done));
      
      

  // Temp registers
  reg [WIDTH_p-1 : 0] t_m0, t_m1, t_m2, t_m3, t_m4, t_m5, t_m6, t_m7, t_m8, t_m9, t_m10, t_m11;
  reg [WIDTH_p-1 : 0] t_s0,t_s1, t_s2, t_s3,t_s4, t_s5,t_s6, t_s7, t_s8,t_s9, t_s10, t_s11, t_s12,t_s13,t_s14, t_s15,t_Sx,t_Sy,t_Sz;
  reg [WIDTH_p-1 : 0] t_2m0, t_3m0, t_2m2, t_4m2, t_8m2, t_12m2, t_2s10, t_4s10, t_8s10;
  
  reg [5:0] state_q;
  
  // States
  localparam s_IDLE   = 5'd0;
  localparam s_STG1   = 5'd1;
  localparam s_WSTG1  = 5'd2;
  localparam s_STG2   = 5'd3;
  localparam s_WSTG2  = 5'd4;
  localparam s_STG3   = 5'd5;
  localparam s_WSTG3  = 5'd6;
  localparam s_STG4   = 5'd7;
  localparam s_WSTG4  = 5'd8;
  localparam s_STG5   = 5'd9;
  localparam s_WSTG5  = 5'd10;
  localparam s_STG6   = 5'd11;
  localparam s_WSTG6  = 5'd12;
  localparam s_STG7   = 5'd13;
  localparam s_WSTG7  = 5'd14;
  localparam s_STG8   = 5'd15;
  localparam s_WSTG8  = 5'd16;
  localparam s_STG9   = 5'd17;
  localparam s_WSTG9  = 5'd18;
  localparam s_STG10  = 5'd19;
  localparam s_WSTG10 = 5'd20;
  localparam s_STG11  = 5'd21;
  localparam s_WSTG11 = 5'd22;
  localparam s_STG12  = 5'd23;
  localparam s_WSTG12 = 5'd24;
  localparam s_STG13  = 5'd25;
  localparam s_WSTG13 = 5'd26;
  localparam s_STG14  = 5'd27;
  localparam s_WSTG14 = 5'd28;
  localparam s_STG15  = 5'd29;
  localparam s_WSTG15 = 5'd30;
  localparam s_DONE   = 5'd31;
  localparam s_SCHK   = 6'd32;
  localparam s_SINF   = 6'd32;
  
  
  wire modd13_done   = w_modaddSub1_done && w_modaddSub2_done && w_modaddSub3_done;
  
  reg p_inf;
  reg q_inf;
  
  
  always @ (posedge clk) begin 
    if (!resetn) begin 
         {r_Xp,r_Yp,r_Zp} <= 'b0;
         {r_Xq,r_Yq,r_Zq} <= 'b0;
         r_p <= 'b0;
        
        {t_m0, t_m1, t_m2, t_m3, t_m4, t_m5, t_m6, t_m7, t_m8, t_m9, t_m10, t_m11} <= 'b0;
        {t_s0,t_s1, t_s2, t_s3,t_s4, t_s5,t_s6, t_s7, t_s8,t_s9, t_s10, t_s11, t_s12,t_s13,t_s14, t_s15,t_Sx,t_Sy,t_Sz} <= 'b0;
        
        {t_2m0, t_3m0, t_2m2, t_4m2, t_8m2, t_12m2, t_2s10, t_4s10, t_8s10} <= 'b0;
        
        {r_modaddSub1_start_q, r_modaddSub1_sub_q} <= 2'b00;
        {r_modaddSub1_a_q, r_modaddSub1_b_q, r_modaddSub1_m_q} <= 'b0;
        
        {r_modaddSub2_start_q, r_modaddSub2_sub_q} <= 2'b00;
        {r_modaddSub2_a_q, r_modaddSub2_b_q, r_modaddSub2_m_q} <= 'b0;
        
        {r_modaddSub3_start_q, r_modaddSub3_sub_q} <= 2'b00;
        {r_modaddSub3_a_q, r_modaddSub3_b_q, r_modaddSub3_m_q} <= 'b0;
        
        
        {r_montMul1_start_q, r_montMul1_a_q, r_montMul1_b_q, r_montMul1_m_q} <= 'b0;
   
        {o_Xr, o_Yr, o_Zr, o_done, o_busy} <= 'b0;
        
        {p_inf, q_inf} <= 2'b00;
        
        state_q <= s_IDLE;

    end else begin 
    
        case (state_q)
            default: begin 
                o_done <= 1'b0;
                o_busy <= 1'b0;
                {p_inf, q_inf} <= 2'b00;
            end 
            
            s_IDLE: begin 
                o_done <= 1'b0;
                o_busy <= 1'b0;
                if (i_start) begin 
                    o_busy <= 1'b1;
                    
                    {t_m0, t_m1, t_m2, t_m3, t_m4, t_m5, t_m6, t_m7, t_m8, t_m9, t_m10, t_m11} <= 'b0;
                    {t_s0,t_s1, t_s2, t_s3,t_s4, t_s5,t_s6, t_s7, t_s8,t_s9, t_s10, t_s11, t_s12,t_s13,t_s14, t_s15} <= 'b0;
                    {t_2m0, t_3m0, t_2m2, t_4m2, t_8m2, t_12m2, t_2s10, t_4s10, t_8s10} <= 'b0;
                    
                    {r_Xp,r_Yp,r_Zp} <= {i_Xp,i_Yp,i_Zp};
                    {r_Xq,r_Yq,r_Zq} <= {i_Xq,i_Yq,i_Zq};
                    r_p <= i_p; 
                    
                    p_inf <=  ({i_Xp,i_Yp,i_Zp} == {381'd0,381'd1,381'd0})? 1'b1 : 1'b0; 
                    q_inf <=  ({i_Xq,i_Yq,i_Zq} == {381'd0,381'd1,381'd0})? 1'b1 : 1'b0; 
                    
                    state_q <= s_STG1;
                end else begin 
                    state_q <= s_IDLE;
                end
            
            end
            
            s_SCHK: begin 
                case ({p_inf,q_inf})
                    2'b00: begin
                        state_q <= s_STG1;
                    end
                    2'b01:  begin
                        {t_Sx,t_Sy,t_Sz} <= {r_Xp,r_Yp,r_Zp};
                        state_q <= s_DONE;
                    end
                    2'b10:  begin 
                        {t_Sx,t_Sy,t_Sz} <= {r_Xq,r_Yq,r_Zq};
                        state_q <= s_DONE;
                    end
                    2'b11: begin 
                        {t_Sx,t_Sy,t_Sz} <= {381'd0,381'd1,381'd0};
                        state_q <= s_DONE;
                    end                
                endcase            
            end 
            
                    
            s_STG1: begin 
            
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b111;
                r_montMul1_start_q <= 1'b1;
               
                {r_modaddSub1_a_q, r_modaddSub1_b_q, r_modaddSub1_m_q, r_modaddSub1_sub_q} <= {r_Xp,r_Yp,r_p,1'b0};
                {r_modaddSub2_a_q, r_modaddSub2_b_q, r_modaddSub2_m_q, r_modaddSub2_sub_q} <= {r_Xq,r_Yq,r_p,1'b0};
                {r_modaddSub3_a_q, r_modaddSub3_b_q, r_modaddSub3_m_q, r_modaddSub3_sub_q} <= {r_Xp,r_Zp,r_p,1'b0};
                               
                
                {r_montMul1_a_q, r_montMul1_b_q, r_montMul1_m_q} <= {r_Xp,r_Xq,r_p};
                
                state_q <= s_WSTG1; 
            
            end 
            
            s_WSTG1: begin 
            
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b000;
                r_montMul1_start_q <= 1'b0;
                
                if (w_montMul1_done) begin 
                    t_m0 <= w_montMul1_res;
                    {t_s0, t_s1, t_s2} <= {w_modaddSub1_res, w_modaddSub2_res, w_modaddSub3_res};
                    
                    state_q <= s_STG2;
                    
                end else begin 
                    state_q <= s_WSTG1;
                end
                     
            end
            
                                  
            s_STG2: begin 
                        
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b111;
                r_montMul1_start_q <= 1'b1;
               
                {r_modaddSub1_a_q, r_modaddSub1_b_q, r_modaddSub1_m_q, r_modaddSub1_sub_q} <= {r_Xq,r_Zq,r_p,1'b0};               
                {r_modaddSub2_a_q, r_modaddSub2_b_q, r_modaddSub2_m_q, r_modaddSub2_sub_q} <= {r_Yp,r_Zp,r_p,1'b0};
                {r_modaddSub3_a_q, r_modaddSub3_b_q, r_modaddSub3_m_q, r_modaddSub3_sub_q} <= {r_Yq,r_Zq,r_p,1'b0};;
                               
                
                {r_montMul1_a_q, r_montMul1_b_q, r_montMul1_m_q} <= {r_Yp,r_Yq,r_p};
                
                state_q <= s_WSTG2; 
            
            end 
            
            
            s_WSTG2: begin
                     
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b000;
                r_montMul1_start_q  <= 1'b0;
                
                if (w_montMul1_done) begin 
                    t_m1 <= w_montMul1_res;
                    {t_s3, t_s4, t_s5} <= {w_modaddSub1_res, w_modaddSub2_res, w_modaddSub3_res};
                    
                    state_q <= s_STG3;
                    
                end else begin 
                    state_q <= s_WSTG2;
                end 
                
            end
            
            s_STG3: begin 
                r_montMul1_start_q  <= 1'b1;
                {r_montMul1_a_q, r_montMul1_b_q, r_montMul1_m_q} <= {r_Zp,r_Zq,r_p};
                
                state_q = s_WSTG3;
            
            end 
            
            
            s_WSTG3: begin 
                r_montMul1_start_q  <= 1'b0;
                
                if (w_montMul1_done) begin 
                    t_m2 <= w_montMul1_res;
                    state_q <= s_STG4;
                    
                end else begin 
                    state_q <= s_WSTG3;
                end 
            
            end
            
            
            
            s_STG4: begin 
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b111;
                r_montMul1_start_q  <= 1'b1;
                
                {r_modaddSub1_a_q, r_modaddSub1_b_q, r_modaddSub1_m_q, r_modaddSub1_sub_q} <= {t_m0 ,t_m1,r_p,1'b0};
                {r_modaddSub2_a_q, r_modaddSub2_b_q, r_modaddSub2_m_q, r_modaddSub2_sub_q} <= {t_m0 ,t_m2,r_p,1'b0};
                {r_modaddSub3_a_q, r_modaddSub3_b_q, r_modaddSub3_m_q, r_modaddSub3_sub_q} <= {t_m1,t_m2,r_p,1'b0};
                
                {r_montMul1_a_q, r_montMul1_b_q, r_montMul1_m_q} <= {t_s0,t_s1,r_p};
                
                state_q = s_WSTG4;
            
            end 
            
            
            s_WSTG4: begin 
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b000;
                r_montMul1_start_q  <= 1'b0;
                
                if (w_montMul1_done) begin 
                    {t_s6, t_s7, t_s8} <= {w_modaddSub1_res, w_modaddSub2_res, w_modaddSub3_res};
                    t_m3 <= w_montMul1_res;
                    
                    state_q <= s_STG5;
                    
                end else begin 
                    state_q <= s_WSTG4;
                end 
            
            end
            
            s_STG5: begin 
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b111;
                r_montMul1_start_q  <= 1'b1;
                
                {r_modaddSub1_a_q, r_modaddSub1_b_q, r_modaddSub1_m_q, r_modaddSub1_sub_q} <= {t_m0 ,t_m0 ,r_p,1'b0}; 
                {r_modaddSub2_a_q, r_modaddSub2_b_q, r_modaddSub2_m_q, r_modaddSub2_sub_q} <= {t_m2 ,t_m2 ,r_p,1'b0};
                {r_modaddSub3_a_q, r_modaddSub3_b_q, r_modaddSub3_m_q, r_modaddSub3_sub_q} <= {t_m3 ,t_s6 ,r_p,1'b1};
                
                {r_montMul1_a_q, r_montMul1_b_q, r_montMul1_m_q} <= {t_s2,t_s3,r_p};
                
                state_q = s_WSTG5;
            
            end 
            
            
            s_WSTG5: begin 
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b000;
                r_montMul1_start_q  <= 1'b0;
                
                if (w_montMul1_done) begin 
                    {t_2m0, t_2m2, t_s9} <= {w_modaddSub1_res, w_modaddSub2_res, w_modaddSub3_res};
                    t_m4 <= w_montMul1_res;
                    
                    state_q <= s_STG6;
                    
                end else begin 
                    state_q <= s_WSTG5;
                end 
            
            end
            
            s_STG6: begin 
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b111;
                r_montMul1_start_q  <= 1'b1;
                
                {r_modaddSub1_a_q, r_modaddSub1_b_q, r_modaddSub1_m_q, r_modaddSub1_sub_q} <= {t_2m0,t_m0 ,r_p,1'b0}; 
                {r_modaddSub2_a_q, r_modaddSub2_b_q, r_modaddSub2_m_q, r_modaddSub2_sub_q} <= {t_2m2,t_2m2,r_p,1'b0};
                {r_modaddSub3_a_q, r_modaddSub3_b_q, r_modaddSub3_m_q, r_modaddSub3_sub_q} <= {t_m4 ,t_s7 ,r_p,1'b1};
                
                {r_montMul1_a_q, r_montMul1_b_q, r_montMul1_m_q} <= {t_s4,t_s5,r_p};
                
                state_q = s_WSTG6;
            
            end 
            
            
            s_WSTG6: begin 
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b000;
                r_montMul1_start_q  <= 1'b0;
                
                if (w_montMul1_done) begin 
                    {t_s12, t_4m2, t_s10} <= {w_modaddSub1_res, w_modaddSub2_res, w_modaddSub3_res};
                    t_m5 <= w_montMul1_res;
                    
                    state_q <= s_STG7;
                    
                end else begin 
                    state_q <= s_WSTG6;
                end 
            
            end
            
            
            s_STG7: begin 
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b111;
                r_montMul1_start_q  <= 1'b1;
                
                {r_modaddSub1_a_q, r_modaddSub1_b_q, r_modaddSub1_m_q, r_modaddSub1_sub_q} <= {t_m5 ,t_s8 ,r_p,1'b1}; 
                {r_modaddSub2_a_q, r_modaddSub2_b_q, r_modaddSub2_m_q, r_modaddSub2_sub_q} <= {t_4m2,t_4m2,r_p,1'b0};
                {r_modaddSub3_a_q, r_modaddSub3_b_q, r_modaddSub3_m_q, r_modaddSub3_sub_q} <= {t_s10,t_s10,r_p,1'b0};
                
                {r_montMul1_a_q, r_montMul1_b_q, r_montMul1_m_q} <= {t_s12,t_s9,r_p};
                
                state_q = s_WSTG7;
            
            end 
            
            
            s_WSTG7: begin 
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b000;
                r_montMul1_start_q  <= 1'b0;
                
                if (w_montMul1_done) begin 
                    {t_s11, t_8m2, t_2s10} <= {w_modaddSub1_res, w_modaddSub2_res, w_modaddSub3_res};
                    t_m11 <= w_montMul1_res;
                    
                    state_q <= s_STG8;
                    
                end else begin 
                    state_q <= s_WSTG7;
                end 
            
            end
            
            
            
            s_STG8: begin 
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b111;
                r_montMul1_start_q  <= 1'b0;
                
                {r_modaddSub1_a_q, r_modaddSub1_b_q, r_modaddSub1_m_q, r_modaddSub1_sub_q} <= {t_m5 ,t_s8 ,r_p,1'b1}; //won't be used
                {r_modaddSub2_a_q, r_modaddSub2_b_q, r_modaddSub2_m_q, r_modaddSub2_sub_q} <= {t_8m2,t_4m2,r_p,1'b0};
                {r_modaddSub3_a_q, r_modaddSub3_b_q, r_modaddSub3_m_q, r_modaddSub3_sub_q} <= {t_2s10,t_2s10,r_p,1'b0};
                
                {r_montMul1_a_q, r_montMul1_b_q, r_montMul1_m_q} <= {t_s12,t_s9,r_p};
                
                state_q = s_WSTG8;
            
            end 
            
            
            s_WSTG8: begin 
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b000;
                r_montMul1_start_q  <= 1'b0;
                
                if (modd13_done) begin 
                    {t_12m2, t_4s10} <= {w_modaddSub2_res, w_modaddSub3_res};
                    state_q <= s_STG9;
                    
                end else begin 
                    state_q <= s_WSTG8;
                end 
            
            end
            
            
            
            
            s_STG9: begin 
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b111;
                r_montMul1_start_q  <= 1'b0;
                
                {r_modaddSub1_a_q, r_modaddSub1_b_q, r_modaddSub1_m_q, r_modaddSub1_sub_q} <= {t_m1  ,t_12m2 ,r_p,1'b0}; //won't be used
                {r_modaddSub2_a_q, r_modaddSub2_b_q, r_modaddSub2_m_q, r_modaddSub2_sub_q} <= {t_m1  ,t_12m2 ,r_p,1'b1};
                {r_modaddSub3_a_q, r_modaddSub3_b_q, r_modaddSub3_m_q, r_modaddSub3_sub_q} <= {t_4s10,t_4s10 ,r_p,1'b0};
                
                
                state_q = s_WSTG9;
            
            end 
            
            
            s_WSTG9: begin 
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b000;
                r_montMul1_start_q  <= 1'b0;
                
                if (modd13_done) begin 
                    {t_s13, t_s14, t_8s10} <= {w_modaddSub1_res, w_modaddSub2_res, w_modaddSub3_res};
                    state_q <= s_STG10;
                    
                end else begin 
                    state_q <= s_WSTG9;
                end 
            
            end
            
            
            
            s_STG10: begin 
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b111;
                r_montMul1_start_q  <= 1'b1;
                
                {r_modaddSub1_a_q, r_modaddSub1_b_q, r_modaddSub1_m_q, r_modaddSub1_sub_q} <= {t_m1  ,t_12m2 ,r_p,1'b0}; //won't be used
                {r_modaddSub2_a_q, r_modaddSub2_b_q, r_modaddSub2_m_q, r_modaddSub2_sub_q} <= {t_m1  ,t_12m2 ,r_p,1'b1}; // won't be used
                {r_modaddSub3_a_q, r_modaddSub3_b_q, r_modaddSub3_m_q, r_modaddSub3_sub_q} <= {t_8s10,t_4s10 ,r_p,1'b0};
                
                {r_montMul1_a_q, r_montMul1_b_q, r_montMul1_m_q} <= {t_s14,t_s9,r_p};
                state_q = s_WSTG10;
            
            end 
            
            
            s_WSTG10: begin 
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b000;
                r_montMul1_start_q  <= 1'b0;
                
                if (w_montMul1_done) begin 
                    t_s15 <= w_modaddSub3_res;
                    t_m6 <= w_montMul1_res;
                    state_q <= s_STG11;
                    
                end else begin 
                    state_q <= s_WSTG10;
                end 
            
            end
            
            
            
            s_STG11: begin 
                r_montMul1_start_q  <= 1'b1;
                {r_montMul1_a_q, r_montMul1_b_q, r_montMul1_m_q} <= {t_s15,t_s11,r_p};
                
                state_q = s_WSTG11;
            
            end 
            
            
            s_WSTG11: begin 
                r_montMul1_start_q  <= 1'b0;
                
                if (w_montMul1_done) begin 
                    t_m7 <= w_montMul1_res;
                    state_q <= s_STG12;
                    
                end else begin 
                    state_q <= s_WSTG11;
                end 
            
            end
            
            
            s_STG12: begin 
                r_montMul1_start_q  <= 1'b1;
                {r_montMul1_a_q, r_montMul1_b_q, r_montMul1_m_q} <= {t_s13,t_s14,r_p};
                
                state_q = s_WSTG12;
            
            end 
            
            
            s_WSTG12: begin 
                r_montMul1_start_q  <= 1'b0;
                
                if (w_montMul1_done) begin 
                    t_m8 <= w_montMul1_res;
                    state_q <= s_STG13;
                    
                end else begin 
                    state_q <= s_WSTG12;
                end 
            
            end
            
            
            
            
            s_STG13: begin 
                r_montMul1_start_q  <= 1'b1;
                {r_montMul1_a_q, r_montMul1_b_q, r_montMul1_m_q} <= {t_s12,t_s15,r_p};
                
                state_q = s_WSTG13;
            
            end 
            
            
            s_WSTG13: begin 
                r_montMul1_start_q  <= 1'b0;
                
                if (w_montMul1_done) begin 
                    t_m9 <= w_montMul1_res;
                    state_q <= s_STG14;
                    
                end else begin 
                    state_q <= s_WSTG13;
                end 
            
            end
            
            
            
           s_STG14: begin 
                r_montMul1_start_q  <= 1'b1;
                {r_montMul1_a_q, r_montMul1_b_q, r_montMul1_m_q} <= {t_s13,t_s11,r_p};
                
                state_q = s_WSTG14;
            
            end 
            
            
            s_WSTG14: begin 
                r_montMul1_start_q  <= 1'b0;
                
                if (w_montMul1_done) begin 
                    t_m10 <= w_montMul1_res;
                    state_q <= s_STG15;
                    
                end else begin 
                    state_q <= s_WSTG14;
                end 
            
            end
            
            
            s_STG15: begin 
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b111;
                
                {r_modaddSub1_a_q, r_modaddSub1_b_q, r_modaddSub1_m_q, r_modaddSub1_sub_q} <= {t_m6  ,t_m7  ,r_p,1'b1}; 
                {r_modaddSub2_a_q, r_modaddSub2_b_q, r_modaddSub2_m_q, r_modaddSub2_sub_q} <= {t_m8  ,t_m9  ,r_p,1'b0};
                {r_modaddSub3_a_q, r_modaddSub3_b_q, r_modaddSub3_m_q, r_modaddSub3_sub_q} <= {t_m10 ,t_m11 ,r_p,1'b0};
                
                state_q = s_WSTG15;
            
            end 
            
            
            s_WSTG15: begin 
                {r_modaddSub1_start_q,r_modaddSub2_start_q,r_modaddSub3_start_q} <= 3'b000;
                
                if (modd13_done) begin 
                    {t_Sx,t_Sy,t_Sz} <= {w_modaddSub1_res, w_modaddSub2_res, w_modaddSub3_res};
                    
                    state_q <= s_DONE;
                    
                end else begin 
                    state_q <= s_WSTG15;
                end 
            end
            
            
            s_DONE : begin 
                o_done <= 1'b1;
                {o_Xr,o_Yr,o_Zr} <= {t_Sx,t_Sy,t_Sz};
                state_q <= s_IDLE;
            end 
            
        endcase
    
    end    
  end 

endmodule


