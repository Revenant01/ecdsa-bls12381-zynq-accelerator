module montgomery #(
    parameter WIDTH = 381
) (
    input  wire clk,
    input  wire resetn,
    input  wire start,
    input  wire [WIDTH-1:0] in_a,
    input  wire [WIDTH-1:0] in_b,
    input  wire [WIDTH-1:0] in_m,
    output reg  [WIDTH-1:0] result,
    output reg  done
);

    // Combinational adder/subtractor  
    reg              add_sub;
    reg  [WIDTH+3:0] add_a, add_b;
    wire [WIDTH+4:0] add_res = add_sub ? 
                               ({1'b0, add_a} - {1'b0, add_b}) :
                               ({1'b0, add_a} + {1'b0, add_b});

    localparam [2:0]
        IDLE     = 3'd0,
        PREBM    = 3'd1,
        SETUP    = 3'd2,
        LOOP     = 3'd3,
        FINAL    = 3'd4;

    reg [2:0]       state;
    reg [WIDTH+3:0] C;
    reg [WIDTH+3:0] B_plus_M;
    reg [8:0]       counter;
    
    // Current and next iteration values
    wire [WIDTH+3:0] C_shifted = add_res[WIDTH+4:1];
    wire next_c0 = add_res[1];
    wire [8:0] next_counter = counter + 1'b1;
    wire next_ai = in_a[next_counter];
    
    // Current iteration q computation
    wire current_ai = in_a[counter];
    wire ai_and_b0 = current_ai & in_b[0];
    wire q = C[0] ^ ai_and_b0;

    // Current O_sel selection (combinational)
    wire [WIDTH+3:0] O_sel = (current_ai & q)  ? B_plus_M :
                             (current_ai & !q) ? {{3{1'b0}}, in_b} :
                             (!current_ai & q) ? {{3{1'b0}}, in_m} :
                             {(WIDTH+4){1'b0}};
    
    // Next iteration q computation (for setting up next add_b)
    wire next_ai_and_b0 = next_ai & in_b[0];
    wire next_q = next_c0 ^ next_ai_and_b0;
    
    // Next O_sel (for next iteration setup)
    wire [WIDTH+3:0] next_O_sel = (next_ai & next_q)  ? B_plus_M :
                                  (next_ai & !next_q) ? {{3{1'b0}}, in_b} :
                                  (!next_ai & next_q) ? {{3{1'b0}}, in_m} :
                                  {(WIDTH+4){1'b0}};

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state    <= IDLE;
            C        <= {(WIDTH+4){1'b0}};
            B_plus_M <= {(WIDTH+4){1'b0}};
            counter  <= 9'd0;
            add_a    <= {(WIDTH+4){1'b0}};
            add_b    <= {(WIDTH+4){1'b0}};
            add_sub  <= 1'b0;
            result   <= {WIDTH{1'b0}};
            done     <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        C       <= {(WIDTH+4){1'b0}};
                        counter <= 9'd0;
                        // Precompute B+M
                        add_a   <= {{3{1'b0}}, in_b};
                        add_b   <= {{3{1'b0}}, in_m};
                        add_sub <= 1'b0;
                        state   <= PREBM;
                    end
                end

                PREBM: begin
                    // Store B+M
                    B_plus_M <= add_res[WIDTH+3:0];
                    counter  <= 9'd0;
                    state    <= SETUP;
                end

                SETUP: begin
                    // Now B_plus_M is available, set up first iteration
                    add_a    <= {(WIDTH+4){1'b0}};  // C = 0 initially
                    add_b    <= O_sel;  // O_sel can now use B_plus_M if needed
                    add_sub  <= 1'b0;
                    state    <= LOOP;
                end

                LOOP: begin
                    // Store result
                    C <= C_shifted;
                    
                    if (counter == WIDTH - 1) begin
                        // Final subtraction
                        add_a   <= C_shifted;
                        add_b   <= {{3{1'b0}}, in_m};
                        add_sub <= 1'b1;
                        state   <= FINAL;
                    end else begin
                        counter <= next_counter;
                        // Setup next iteration using pre-computed next_O_sel
                        add_a   <= C_shifted;
                        add_b   <= next_O_sel;  // Use next iteration's O_sel
                        add_sub <= 1'b0;
                        state   <= LOOP;
                    end
                end

                FINAL: begin
                    // Check if C >= M
                    if (!add_res[WIDTH+4]) begin
                        result <= add_res[WIDTH-1:0];
                    end else begin
                        result <= C[WIDTH-1:0];
                    end
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule