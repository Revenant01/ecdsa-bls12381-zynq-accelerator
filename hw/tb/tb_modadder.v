`timescale 1ns / 1ps

`define RESET_TIME 25
`define CLK_PERIOD 10
`define CLK_HALF 5

module tb_modadder();
// Define internal regs and wires
    reg          clk;
    reg          resetn;
    reg  [380:0] in_a;
    reg  [380:0] in_b;
    reg  [380:0] in_m;
    reg          start;
    reg          subtract;
    wire [380:0] result;
    wire         done;

    reg  [380:0] expected;
    reg          result_ok;

    // Instantiating adder
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

    // Generate Clock
    initial begin
        clk = 0;
        forever #`CLK_HALF clk = ~clk;
    end

    // Initialize signals to zero
    initial begin
        in_a     <= 0;
        in_b     <= 0;
        in_m     <= 0;
        subtract <= 0;
        start    <= 0;
    end

    // Reset the circuit
    initial begin
        resetn = 0;
        #`RESET_TIME
        resetn = 1;
    end

    task perform_add;
        input [380:0] a;
        input [380:0] b;
        input [380:0] m;
        begin
            in_a <= a;
            in_b <= b;
            in_m <= m;
            start <= 1'd1;
            subtract <= 1'd0;
            #`CLK_PERIOD;
            start <= 1'd0;
            wait (done==1);
            #`CLK_PERIOD;
        end
    endtask

    task perform_sub;
        input [380:0] a;
        input [380:0] b;
        input [380:0] m;
        begin
            in_a <= a;
            in_b <= b;
            in_m <= m;
            start <= 1'd1;
            subtract <= 1'd1;
            #`CLK_PERIOD;
            start <= 1'd0;
            wait (done==1);
            #`CLK_PERIOD;
        end
    endtask

    initial begin

    #`RESET_TIME

    /*************TEST ADDITION*************/
    
    $display("\nAddition with testvector 1");
    
    #`CLK_PERIOD;
    perform_add(381'h4624e85592081c9f8e7f0164b2697a27428e081266df4c07f0e7cdaec9606e3cc851f68005fe70860bcdafb77e071cc, 
                381'h115759a1c297b3e6d6bf73badfe4ec48c758bf465ae764f0475fd33e176639cf5887e2fcbd2ceb085d05035f16e449f5,
                381'h14936bbbd984a8985f6035c85e2e1256a6a9c418acd2ddbe1efba4460ecd23c4331d001a8dc36270dbf032b2a743b741);
    expected  = 381'h1263c6b42338d1870472e08ccdd719494d7dbaed4827bf2a772abd2f52f1ceef1f0024a2fc96f9fe1d1aba7e7810480;
    wait (done==1);
    result_ok = (expected==result);
    $display("result calculated=%x", result);
    $display("result expected  =%x", expected);
    $display("error            =%x", expected-result);
    #`CLK_PERIOD;   
    
    
    $display("\nAddition with testvector 2");

    // Test addition with large test vectors. 
    // You can generate your own vectors with testvector generator python script.
    perform_add(381'h1d9044140df3687a89c53cb424bd6efa5bb3c9f5179d1417f2d73c221baef2b038db97e8a3bbc48f4cf4df56cdc69b8b,
                381'h1cf3d71dbe6e6fafac3caf9812354da0940538ff66a73600f4fa90c6ab4c991241bbae94ad7aac0e69345e7972591566,
                381'h1dea77546252ff02ba382846784a1e87554a4e74832b3c88854f1ba9b3e747cfd59bbced2edd67435a9bbe1f0de1e9d8);
    expected  = 381'h1c99a3dd6a0ed9277bc9c405bea89e139a6eb47ffb190d906282b13f131443f2a4fb89902259095a5b8d7fb1323dc719;
    wait (done==1);
    result_ok = (expected==result);
    $display("result calculated=%x", result);
    $display("result expected  =%x", expected);
    $display("error            =%x", expected-result);
    #`CLK_PERIOD;     
    
    /*************TEST SUBTRACTION*************/

    $display("\nSubtraction with testvector 1");
    
    #`CLK_PERIOD;
    perform_sub(381'h1, 
                381'h2,
                381'h5);
    expected  = 381'h4;
    wait (done==1);
    result_ok = (expected==result);
    $display("result calculated=%x", result);
    $display("result expected  =%x", expected);
    $display("error            =%x", expected-result);
    #`CLK_PERIOD;    


    $display("\nSubtraction with testvector 2");

    // Test subtraction with large test vectors. 
    // You can generate your own vectors with testvector generator python script.
    perform_sub(381'h78eaa82fc02fa9e8fa7ae8427dac39f2467538ea02d3f30330b6aa07d34787759062845580eacee82122707fa983e7d,
                381'h4e20945d19fe5dad8dd4f7ac97130acc17c4eac9578dd7131f5fa85bba67230b1b74bb1da4fe01cb624418e34e3de97,
                381'h15828d301926339e8664fc07e83b5881141fd79333a880e8db3569e8a5cd53bfb7608840c43242824107f688a771a5e0);
    expected  = 381'h2aca13d2a6314c3b6ca5f095e6992f262eb04e20ab461bf0115701ac18e0646a74edc937dbeccd1cbede579c5b45fe6;
    wait (done==1);
    result_ok = (expected==result);
    $display("result calculated=%x", result);
    $display("result expected  =%x", expected);
    $display("error            =%x", expected-result);
    #`CLK_PERIOD;    
    
    $finish;

    end

endmodule
