module ecdsa (
    input  wire          clk,
    input  wire          resetn,
    output wire   [ 3:0] leds,

    // input registers                     // output registers
    input  wire   [31:0] rin0,             output wire   [31:0] rout0,
    input  wire   [31:0] rin1,             output wire   [31:0] rout1,
    input  wire   [31:0] rin2,             output wire   [31:0] rout2,
    input  wire   [31:0] rin3,             output wire   [31:0] rout3,
    input  wire   [31:0] rin4,             output wire   [31:0] rout4,
    input  wire   [31:0] rin5,             output wire   [31:0] rout5,
    input  wire   [31:0] rin6,             output wire   [31:0] rout6,
    input  wire   [31:0] rin7,             output wire   [31:0] rout7,

    // dma signals
    input  wire [380 :0] dma_rx_data,      output wire [380 :0] dma_tx_data,
    output wire [  31:0] dma_rx_address,   output wire [  31:0] dma_tx_address,
    output reg           dma_rx_start,     output reg           dma_tx_start,
    input  wire          dma_done,
    input  wire          dma_idle,
    input  wire          dma_error
  );

  // CSR Assignments
  wire [31:0] command;
  wire [31:0] rx_addr_start;   // Starting address for RX (will auto-increment by 0x80)
  wire [31:0] tx_addr_start;   // Starting address for TX (will auto-increment by 0x80)
  
  assign command       = rin0;
  assign rx_addr_start = rin1;
  assign tx_addr_start = rin2;

  // RCVD data
  reg [380:0] r_modulus   = 381'h0;
  reg [380:0] r_message   = 381'h0, r_s        = 381'h0, r_K_X_Modn  = 381'h0;
  reg [380:0] r_G_X       = 381'h0, r_G_Y      = 381'h0, r_G_Z       = 381'h0;
  reg [380:0] r_K_X       = 381'h0, r_K_Y      = 381'h0, r_K_Z       = 381'h0;
  reg [380:0] r_Public_X  = 381'h0, r_Public_Y = 381'h0, r_Public_Z  = 381'h0;

  // calc_ecdsa result registers
  wire [380:0] calc_Qx, calc_Qy, calc_Qz;
  wire [380:0] calc_Lx, calc_Ly, calc_Lz;
  wire [380:0] calc_Cx, calc_Cy, calc_Cz;
  wire [380:0] calc_Dx, calc_Dy, calc_Dz;
  wire [380:0] calc_LHS, calc_RHS;
  wire calc_done, calc_busy, calc_valid;
  reg calc_start = 1'b0;

  // Current RX/TX addresses 
  reg [31 :0] current_rx_address = 32'h0;
  reg [31 :0] current_tx_address = 32'h0;
  reg [380:0] current_tx_data;

  // Transfer counter for debugging
  reg [31:0] r_transfer_count = 32'h0;

  // Output registers
  wire [31:0] status;
  wire [31:0] transfer_count;
  assign rout0 = status;
  assign rout1 = transfer_count;
  assign rout2 = current_rx_address;  // DEBUG: show current RX address
  assign rout3 = current_tx_address;  // DEBUG: show current TX address
  assign rout4 = {26'd0, state};      // DEBUG: show current state (6 bits)
  assign rout5 = 32'h0;               // Unused
  assign rout6 = {27'b0, dma_idle, dma_done, dma_error, dma_tx_start, dma_rx_start};  // DEBUG: DMA signals
  assign rout7 = current_tx_data[31:0];  // DEBUG: show lower bits of TX data
  assign transfer_count = r_transfer_count;

  // Command decoding
  wire isCmdComp = (command == 32'd1);
  wire isCmdIdle = (command == 32'd0);

  localparam
    STATE_IDLE        = 6'd0,
    STATE_RX_MOD      = 6'd1,  STATE_RX_MOD_WAIT = 6'd2,
    STATE_RX_MSG      = 6'd3,  STATE_RX_MSG_WAIT = 6'd4,
    STATE_RX_GX       = 6'd5,  STATE_RX_GX_WAIT  = 6'd6,
    STATE_RX_GY       = 6'd7,  STATE_RX_GY_WAIT  = 6'd8,
    STATE_RX_GZ       = 6'd9,  STATE_RX_GZ_WAIT  = 6'd10,
    STATE_RX_KX       = 6'd11, STATE_RX_KX_WAIT  = 6'd12,
    STATE_RX_KY       = 6'd13, STATE_RX_KY_WAIT  = 6'd14,
    STATE_RX_KZ       = 6'd15, STATE_RX_KZ_WAIT  = 6'd16,
    STATE_RX_S        = 6'd17, STATE_RX_S_WAIT   = 6'd18,
    STATE_RX_PX       = 6'd19, STATE_RX_PX_WAIT  = 6'd20,
    STATE_RX_PY       = 6'd21, STATE_RX_PY_WAIT  = 6'd22,
    STATE_RX_PZ       = 6'd23, STATE_RX_PZ_WAIT  = 6'd24,
    STATE_RX_KXM      = 6'd25, STATE_RX_KXM_WAIT = 6'd26,
    STATE_CALC        = 6'd27, STATE_CALC_WAIT   = 6'd28,
    STATE_TX_OUT0     = 6'd29, STATE_TX_OUT0_WAIT= 6'd30,
    STATE_TX_OUT1     = 6'd31, STATE_TX_OUT1_WAIT= 6'd32,
    STATE_TX_OUT2     = 6'd33, STATE_TX_OUT2_WAIT= 6'd34,
    STATE_TX_OUT3     = 6'd35, STATE_TX_OUT3_WAIT= 6'd36,
    STATE_TX_OUT4     = 6'd37, STATE_TX_OUT4_WAIT= 6'd38,
    STATE_TX_OUT5     = 6'd39, STATE_TX_OUT5_WAIT= 6'd40,
    STATE_TX_OUT6     = 6'd41, STATE_TX_OUT6_WAIT= 6'd42,
    STATE_TX_OUT7     = 6'd43, STATE_TX_OUT7_WAIT= 6'd44,
    STATE_TX_OUT8     = 6'd45, STATE_TX_OUT8_WAIT= 6'd46,
    STATE_TX_OUT9     = 6'd47, STATE_TX_OUT9_WAIT= 6'd48,
    STATE_TX_OUT10    = 6'd49, STATE_TX_OUT10_WAIT= 6'd50,
    STATE_TX_OUT11    = 6'd51, STATE_TX_OUT11_WAIT= 6'd52,
    STATE_TX_OUT12    = 6'd53, STATE_TX_OUT12_WAIT= 6'd54,
    STATE_TX_OUT13    = 6'd55, STATE_TX_OUT13_WAIT= 6'd56,
    STATE_TX_OUT14    = 6'd57, STATE_TX_OUT14_WAIT= 6'd58,
    STATE_DONE        = 6'd59;

  reg [5:0] state = STATE_IDLE;
  reg [5:0] next_state;
  
  // Wait counter for DMA to become idle between operations
  reg [3:0] wait_counter = 4'd0;
  reg tx_done_seen = 1'b0; 
  
  
  assign tx_state_done = tx_done_seen && dma_idle && (wait_counter >= 4'd10);

  // State machine combinational logic
  always@(*) begin
    next_state = STATE_IDLE;

    case (state)
      STATE_IDLE         : next_state = (isCmdComp) ? STATE_RX_MOD            : state;
      
      STATE_RX_MOD       : next_state = (~dma_idle) ? STATE_RX_MOD_WAIT       : state;
      STATE_RX_MOD_WAIT  : next_state = (dma_done)  ? STATE_RX_MSG            : state;
      
      STATE_RX_MSG       : next_state = (~dma_idle) ? STATE_RX_MSG_WAIT       : state;
      STATE_RX_MSG_WAIT  : next_state = (dma_done)  ? STATE_RX_GX             : state;
      
      STATE_RX_GX        : next_state = (~dma_idle) ? STATE_RX_GX_WAIT        : state;
      STATE_RX_GX_WAIT   : next_state = (dma_done)  ? STATE_RX_GY             : state;
      
      STATE_RX_GY        : next_state = (~dma_idle) ? STATE_RX_GY_WAIT        : state;
      STATE_RX_GY_WAIT   : next_state = (dma_done)  ? STATE_RX_GZ             : state;
      
      STATE_RX_GZ        : next_state = (~dma_idle) ? STATE_RX_GZ_WAIT        : state;
      STATE_RX_GZ_WAIT   : next_state = (dma_done)  ? STATE_RX_KX             : state;
      
      STATE_RX_KX        : next_state = (~dma_idle) ? STATE_RX_KX_WAIT        : state;
      STATE_RX_KX_WAIT   : next_state = (dma_done)  ? STATE_RX_KY             : state;
      
      STATE_RX_KY        : next_state = (~dma_idle) ? STATE_RX_KY_WAIT        : state;
      STATE_RX_KY_WAIT   : next_state = (dma_done)  ? STATE_RX_KZ             : state;
      
      STATE_RX_KZ        : next_state = (~dma_idle) ? STATE_RX_KZ_WAIT        : state;
      STATE_RX_KZ_WAIT   : next_state = (dma_done)  ? STATE_RX_S              : state;
      
      STATE_RX_S         : next_state = (~dma_idle) ? STATE_RX_S_WAIT         : state;
      STATE_RX_S_WAIT    : next_state = (dma_done)  ? STATE_RX_PX             : state;
      
      STATE_RX_PX        : next_state = (~dma_idle) ? STATE_RX_PX_WAIT        : state;
      STATE_RX_PX_WAIT   : next_state = (dma_done)  ? STATE_RX_PY             : state;
      
      STATE_RX_PY        : next_state = (~dma_idle) ? STATE_RX_PY_WAIT        : state;
      STATE_RX_PY_WAIT   : next_state = (dma_done)  ? STATE_RX_PZ             : state;
      
      STATE_RX_PZ        : next_state = (~dma_idle) ? STATE_RX_PZ_WAIT        : state;
      STATE_RX_PZ_WAIT   : next_state = (dma_done)  ? STATE_RX_KXM            : state;
      
      STATE_RX_KXM       : next_state = (~dma_idle) ? STATE_RX_KXM_WAIT       : state;
      STATE_RX_KXM_WAIT  : next_state = (dma_done)  ? STATE_CALC              : state;
      
      STATE_CALC         : next_state = STATE_CALC_WAIT;
      STATE_CALC_WAIT    : next_state = (calc_done) ? STATE_TX_OUT0           : state;
    
      STATE_TX_OUT0      : next_state = (~dma_idle)     ? STATE_TX_OUT0_WAIT  : state;
      STATE_TX_OUT0_WAIT : next_state = (tx_state_done) ? STATE_TX_OUT1       : state;
      
      STATE_TX_OUT1      : next_state = (~dma_idle)     ? STATE_TX_OUT1_WAIT  : state;
      STATE_TX_OUT1_WAIT : next_state = (tx_state_done) ? STATE_TX_OUT2       : state;
      
      STATE_TX_OUT2      : next_state = (~dma_idle)     ? STATE_TX_OUT2_WAIT  : state;
      STATE_TX_OUT2_WAIT : next_state = (tx_state_done) ? STATE_TX_OUT3       : state;
      
      STATE_TX_OUT3      : next_state = (~dma_idle)     ? STATE_TX_OUT3_WAIT  : state;
      STATE_TX_OUT3_WAIT : next_state = (tx_state_done) ? STATE_TX_OUT4       : state;
      
      STATE_TX_OUT4      : next_state = (~dma_idle)     ? STATE_TX_OUT4_WAIT  : state;
      STATE_TX_OUT4_WAIT : next_state = (tx_state_done) ? STATE_TX_OUT5       : state;
      
      STATE_TX_OUT5      : next_state = (~dma_idle)     ? STATE_TX_OUT5_WAIT  : state;
      STATE_TX_OUT5_WAIT : next_state = (tx_state_done) ? STATE_TX_OUT6       : state;
      
      STATE_TX_OUT6      : next_state = (~dma_idle)     ? STATE_TX_OUT6_WAIT  : state;
      STATE_TX_OUT6_WAIT : next_state = (tx_state_done) ? STATE_TX_OUT7       : state;
      
      STATE_TX_OUT7      : next_state = (~dma_idle)     ? STATE_TX_OUT7_WAIT  : state;
      STATE_TX_OUT7_WAIT : next_state = (tx_state_done) ? STATE_TX_OUT8       : state;
      
      STATE_TX_OUT8      : next_state = (~dma_idle)     ? STATE_TX_OUT8_WAIT  : state;
      STATE_TX_OUT8_WAIT : next_state = (tx_state_done) ? STATE_TX_OUT9       : state;
      
      STATE_TX_OUT9      : next_state = (~dma_idle)     ? STATE_TX_OUT9_WAIT  : state;
      STATE_TX_OUT9_WAIT : next_state = (tx_state_done) ? STATE_TX_OUT10      : state;
      
      STATE_TX_OUT10     : next_state = (~dma_idle)     ? STATE_TX_OUT10_WAIT : state;
      STATE_TX_OUT10_WAIT: next_state = (tx_state_done) ? STATE_TX_OUT11      : state;
      
      STATE_TX_OUT11     : next_state = (~dma_idle)     ? STATE_TX_OUT11_WAIT : state;
      STATE_TX_OUT11_WAIT: next_state = (tx_state_done) ? STATE_TX_OUT12      : state;
      
      STATE_TX_OUT12     : next_state = (~dma_idle)     ? STATE_TX_OUT12_WAIT : state;
      STATE_TX_OUT12_WAIT: next_state = (tx_state_done) ? STATE_TX_OUT13      : state;
      
      STATE_TX_OUT13     : next_state = (~dma_idle)     ? STATE_TX_OUT13_WAIT : state;
      STATE_TX_OUT13_WAIT: next_state = (tx_state_done) ? STATE_TX_OUT14      : state;
      
      STATE_TX_OUT14     : next_state = (~dma_idle)     ? STATE_TX_OUT14_WAIT : state;
      STATE_TX_OUT14_WAIT: next_state = (dma_done)      ? STATE_DONE          : state;
      
      STATE_DONE         : next_state = (isCmdIdle) ? STATE_IDLE : state;
      
      default            : next_state = STATE_IDLE;
    endcase
  end

  // calc_ecdsa instantiation
  calc_ecdsa #(
    .WIDTH_p(381),
    .WIDTH_k(255)
  ) u_calc_ecdsa (
    .clk(clk),
    .resetn(resetn),
    .i_start(calc_start),
    .i_p(r_modulus),
    .i_Gx(r_G_X), .i_Gy(r_G_Y), .i_Gz(r_G_Z),
    .i_m(r_message[254:0]),
    .i_Kx(r_K_X), .i_Ky(r_K_Y), .i_Kz(r_K_Z),
    .i_s(r_s[254:0]),
    .i_Px(r_Public_X), .i_Py(r_Public_Y), .i_Pz(r_Public_Z),
    .i_K_X_Modn(r_K_X_Modn[254:0]),
    .o_Qx(calc_Qx   ), .o_Qy(calc_Qy   ), .o_Qz(calc_Qz),
    .o_Lx(calc_Lx   ), .o_Ly(calc_Ly   ), .o_Lz(calc_Lz),
    .o_Cx(calc_Cx   ), .o_Cy(calc_Cy   ), .o_Cz(calc_Cz),
    .o_Dx(calc_Dx   ), .o_Dy(calc_Dy   ), .o_Dz(calc_Dz),
    .o_LHS(calc_LHS ), .o_RHS(calc_RHS ),
    .o_done(calc_done),
    .o_busy(calc_busy),
    .o_valid(calc_valid)
  );

  // DMA control signals
  assign dma_rx_address = current_rx_address;
  assign dma_tx_address = current_tx_address;
  assign dma_tx_data = current_tx_data;

  always@(posedge clk) begin
    dma_rx_start <= 1'b0;
    dma_tx_start <= 1'b0;

    case (state)
      STATE_RX_MOD, STATE_RX_MSG, STATE_RX_GX, STATE_RX_GY, STATE_RX_GZ,
      STATE_RX_KX, STATE_RX_KY, STATE_RX_KZ, STATE_RX_S,
      STATE_RX_PX, STATE_RX_PY, STATE_RX_PZ, STATE_RX_KXM: begin
        dma_rx_start <= 1'b1;
      end
      STATE_TX_OUT0, STATE_TX_OUT1, STATE_TX_OUT2, STATE_TX_OUT3,
      STATE_TX_OUT4, STATE_TX_OUT5, STATE_TX_OUT6, STATE_TX_OUT7,
      STATE_TX_OUT8, STATE_TX_OUT9, STATE_TX_OUT10, STATE_TX_OUT11,
      STATE_TX_OUT12,STATE_TX_OUT13,STATE_TX_OUT14: begin
        dma_tx_start <= 1'b1;
      end
    endcase
  end

  always@(posedge clk) begin
    if (~resetn) begin
      current_rx_address <= 32'h0;
      current_tx_address <= 32'h0;
    end else begin
      if (state == STATE_IDLE && next_state == STATE_RX_MOD) begin
        current_rx_address <= rx_addr_start;
      end
      else if ((state == STATE_RX_MOD_WAIT && dma_done) ||
               (state == STATE_RX_MSG_WAIT && dma_done) ||
               (state == STATE_RX_GX_WAIT  && dma_done) ||
               (state == STATE_RX_GY_WAIT  && dma_done) ||
               (state == STATE_RX_GZ_WAIT  && dma_done) ||
               (state == STATE_RX_KX_WAIT  && dma_done) ||
               (state == STATE_RX_KY_WAIT  && dma_done) ||
               (state == STATE_RX_KZ_WAIT  && dma_done) ||
               (state == STATE_RX_S_WAIT   && dma_done) ||
               (state == STATE_RX_PX_WAIT  && dma_done) ||
               (state == STATE_RX_PY_WAIT  && dma_done) ||
               (state == STATE_RX_PZ_WAIT  && dma_done)) begin
        current_rx_address <= current_rx_address + 32'h80;
      end
      
      if (state == STATE_RX_KXM_WAIT && dma_done) begin
        current_tx_address <= tx_addr_start;
      end
      else if ((state == STATE_TX_OUT0_WAIT  && tx_state_done) ||
               (state == STATE_TX_OUT1_WAIT  && tx_state_done) ||
               (state == STATE_TX_OUT2_WAIT  && tx_state_done) ||
               (state == STATE_TX_OUT3_WAIT  && tx_state_done) ||
               (state == STATE_TX_OUT4_WAIT  && tx_state_done) ||
               (state == STATE_TX_OUT5_WAIT  && tx_state_done) ||
               (state == STATE_TX_OUT6_WAIT  && tx_state_done) ||
               (state == STATE_TX_OUT7_WAIT  && tx_state_done) ||
               (state == STATE_TX_OUT8_WAIT  && tx_state_done) ||
               (state == STATE_TX_OUT9_WAIT  && tx_state_done) ||
               (state == STATE_TX_OUT10_WAIT && tx_state_done) ||
               (state == STATE_TX_OUT11_WAIT && tx_state_done) ||
               (state == STATE_TX_OUT12_WAIT && tx_state_done) ||
               (state == STATE_TX_OUT13_WAIT && tx_state_done)) begin
        current_tx_address <= current_tx_address + 32'h80;
      end
    end
  end

  // Data storage - received data stored here
  always@(posedge clk) begin
    if (state == STATE_RX_MOD_WAIT && dma_done) begin
      r_modulus <= dma_rx_data;
      r_transfer_count <= r_transfer_count + 1;
    end
    if (state == STATE_RX_MSG_WAIT && dma_done) begin
      r_message <= dma_rx_data;
      r_transfer_count <= r_transfer_count + 1;
    end
    if (state == STATE_RX_GX_WAIT && dma_done) begin
      r_G_X <= dma_rx_data;
      r_transfer_count <= r_transfer_count + 1;
    end
    if (state == STATE_RX_GY_WAIT && dma_done) begin
      r_G_Y <= dma_rx_data;
      r_transfer_count <= r_transfer_count + 1;
    end
    if (state == STATE_RX_GZ_WAIT && dma_done) begin
      r_G_Z <= dma_rx_data;
      r_transfer_count <= r_transfer_count + 1;
    end
    if (state == STATE_RX_KX_WAIT && dma_done) begin
      r_K_X <= dma_rx_data;
      r_transfer_count <= r_transfer_count + 1;
    end
    if (state == STATE_RX_KY_WAIT && dma_done) begin
      r_K_Y <= dma_rx_data;
      r_transfer_count <= r_transfer_count + 1;
    end
    if (state == STATE_RX_KZ_WAIT && dma_done) begin
      r_K_Z <= dma_rx_data;
      r_transfer_count <= r_transfer_count + 1;
    end
    if (state == STATE_RX_S_WAIT && dma_done) begin
      r_s <= dma_rx_data;
      r_transfer_count <= r_transfer_count + 1;
    end
    if (state == STATE_RX_PX_WAIT && dma_done) begin
      r_Public_X <= dma_rx_data;
      r_transfer_count <= r_transfer_count + 1;
    end
    if (state == STATE_RX_PY_WAIT && dma_done) begin
      r_Public_Y <= dma_rx_data;
      r_transfer_count <= r_transfer_count + 1;
    end
    if (state == STATE_RX_PZ_WAIT && dma_done) begin
      r_Public_Z <= dma_rx_data;
      r_transfer_count <= r_transfer_count + 1;
    end
    if (state == STATE_RX_KXM_WAIT && dma_done) begin
      r_K_X_Modn <= dma_rx_data;
      r_transfer_count <= r_transfer_count + 1;
    end
    
    // Reset counter when starting new operation
    if (state == STATE_IDLE && next_state == STATE_RX_MOD) begin
      r_transfer_count <= 32'h0;
    end
  end

  // Control calc_start signal
  always@(posedge clk) begin
    if (~resetn) begin
      calc_start <= 1'b0;
    end else begin
      calc_start <= (state == STATE_CALC);
    end
  end

  // Setup TX data based on current state - send computation results
  always@(posedge clk) begin
    case (state)
      STATE_TX_OUT0 : current_tx_data <= calc_Qx;      // Q point (m*G)
      STATE_TX_OUT1 : current_tx_data <= calc_Qy;
      STATE_TX_OUT2 : current_tx_data <= calc_Qz;
      STATE_TX_OUT3 : current_tx_data <= calc_Lx;      // L point (K_X_Modn*P)
      STATE_TX_OUT4 : current_tx_data <= calc_Ly;
      STATE_TX_OUT5 : current_tx_data <= calc_Lz;
      STATE_TX_OUT6 : current_tx_data <= calc_Cx;      // C point (Q+L)
      STATE_TX_OUT7 : current_tx_data <= calc_Cy;
      STATE_TX_OUT8 : current_tx_data <= calc_Cz;
      STATE_TX_OUT9 : current_tx_data <= calc_Dx;      // D point (s*K)
      STATE_TX_OUT10: current_tx_data <= calc_Dy;
      STATE_TX_OUT11: current_tx_data <= calc_Dz;
      STATE_TX_OUT12: current_tx_data <= calc_LHS;
      STATE_TX_OUT13: current_tx_data <= calc_RHS;
      STATE_TX_OUT14: current_tx_data <= {380'b0, calc_valid};  // Valid flag in LSB
    endcase
  end

  // Track when dma_done pulses
  always@(posedge clk) begin
    if (~resetn) begin
      tx_done_seen <= 1'b0;
    end else if (state == STATE_TX_OUT0_WAIT  || state == STATE_TX_OUT1_WAIT  || 
                 state == STATE_TX_OUT2_WAIT  || state == STATE_TX_OUT3_WAIT  ||
                 state == STATE_TX_OUT4_WAIT  || state == STATE_TX_OUT5_WAIT  ||
                 state == STATE_TX_OUT6_WAIT  || state == STATE_TX_OUT7_WAIT  ||
                 state == STATE_TX_OUT8_WAIT  || state == STATE_TX_OUT9_WAIT  ||
                 state == STATE_TX_OUT10_WAIT || state == STATE_TX_OUT11_WAIT || 
                 state == STATE_TX_OUT12_WAIT || state == STATE_TX_OUT13_WAIT) begin
      if (dma_done) begin
        tx_done_seen <= 1'b1; 
      end
    end else begin
      tx_done_seen <= 1'b0;  
    end
  end

  // Wait counter - gives DMA time to settle between operations
  always@(posedge clk) begin
    if (~resetn) begin
      wait_counter <= 4'd0;
    end else if (state == STATE_TX_OUT0_WAIT  || state == STATE_TX_OUT1_WAIT || 
                 state == STATE_TX_OUT2_WAIT  || state == STATE_TX_OUT3_WAIT ||
                 state == STATE_TX_OUT4_WAIT  || state == STATE_TX_OUT5_WAIT ||
                 state == STATE_TX_OUT6_WAIT  || state == STATE_TX_OUT7_WAIT ||
                 state == STATE_TX_OUT8_WAIT  || state == STATE_TX_OUT9_WAIT ||
                 state == STATE_TX_OUT10_WAIT || state == STATE_TX_OUT11_WAIT||
                 state == STATE_TX_OUT12_WAIT || state == STATE_TX_OUT13_WAIT) begin
      if (tx_done_seen && dma_idle) begin
        wait_counter <= wait_counter + 4'd1;
      end else begin
        wait_counter <= 4'd0;
      end
    end else begin
      wait_counter <= 4'd0;
    end
  end

  // State register
  always@(posedge clk)
    state <= (~resetn) ? STATE_IDLE : next_state;

  // Status signals
  wire isStateIdle = (state == STATE_IDLE);
  wire isStateDone = (state == STATE_DONE);
  assign status = {21'b0, state[5:0], dma_error, isStateIdle, isStateDone};

  // LEDs show state
  assign leds = {dma_error,isStateIdle,calc_valid,isStateDone};

endmodule