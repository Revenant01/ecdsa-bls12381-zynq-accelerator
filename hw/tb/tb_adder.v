`timescale 1ns / 1ps

`define RESET_TIME 25
`define CLK_PERIOD 10
`define CLK_HALF 5

module tb_adder();

    // Define internal regs and wires
    reg          clk;
    reg          resetn;
    reg  [383:0] in_a;
    reg  [383:0] in_b;
    reg          start;
    reg          subtract;
    wire [384:0] result;
    wire         done;

    reg  [384:0] expected;
    reg          result_ok;

    // Instantiating adder
    adder dut (
        .clk      (clk     ),
        .resetn   (resetn  ),
        .start    (start   ),
        .subtract (subtract),
        .in_a     (in_a    ),
        .in_b     (in_b    ),
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
        input [383:0] a;
        input [383:0] b;
        begin
            in_a <= a;
            in_b <= b;
            start <= 1'd1;
            subtract <= 1'd0;
            #`CLK_PERIOD;
            start <= 1'd0;
            wait (done==1);
            #`CLK_PERIOD;
        end
    endtask

    task perform_sub;
        input [383:0] a;
        input [383:0] b;
        begin
            in_a <= a;
            in_b <= b;
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
    
    // Check if 1+1=2
    #`CLK_PERIOD;
    perform_add(384'h1, 
                384'h1);
    expected  = 385'h2;
    wait (done==1);
    result_ok = (expected==result);
    $display("result calculated=%x", result);
    $display("result expected  =%x", expected);
    $display("error            =%x", expected-result);
    #`CLK_PERIOD;   
    
    
    $display("\nAddition with testvector 2");

    // Test addition with large test vectors. 
    // You can generate your own vectors with testvector generator python script.
    perform_add(384'h9a4f3394dc98fe4c848db73c5dc96b0a2a7e1b886c2ec9364776605633b9f97e058bad72cb4712174b7d4fd333192add,
                384'hfeaff962a21920ef1713d574e4add2aedb8e644885b3ef9ffc181bf46723f260d2c2b142ab03dd8f2c97beaefbd2f332);
    expected  = 385'h198ff2cf77eb21f3b9ba18cb142773db9060c7fd0f1e2b8d6438e7c4a9addebded84e5eb5764aefa678150e822eec1e0f;
    wait (done==1);
    result_ok = (expected==result);
    $display("result calculated=%x", result);
    $display("result expected  =%x", expected);
    $display("error            =%x", expected-result);
    #`CLK_PERIOD;     
    
    /*************TEST SUBTRACTION*************/

    $display("\nSubtraction with testvector 1");
    
    // Check if 1-1=0
    #`CLK_PERIOD;
    perform_sub(384'h1, 
                384'h1);
    expected  = 385'h0;
    wait (done==1);
    result_ok = (expected==result);
    $display("result calculated=%x", result);
    $display("result expected  =%x", expected);
    $display("error            =%x", expected-result);
    #`CLK_PERIOD;    


    $display("\nSubtraction with testvector 2");

    // Test subtraction with large test vectors. 
    // You can generate your own vectors with testvector generator python script.
    perform_sub(384'hd5ce5824a6cec11afcff7c314d32802862e5eff4adf95f75eecaea5eb82544aedf70b58b0382d72c79d17834aeedc061,
                384'h99e5018cc22bf76ddada6299274dcb393c6a92bc02d6cc6a51f50f6e3bb36dcf540a4ad3859f660ac19eea7b9bb802c6);
    expected  = 385'h3be95697e4a2c9ad2225199825e4b4ef267b5d38ab22930b9cd5daf07c71d6df8b666ab77de37121b8328db91335bd9b;
    wait (done==1);
    result_ok = (expected==result);
    $display("result calculated=%x", result);
    $display("result expected  =%x", expected);
    $display("error            =%x", expected-result);
    #`CLK_PERIOD;    
    
    $finish;

    end

endmodule
