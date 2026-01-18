/****************************************************************************
FILENAME     :  fpga_top_tb.sv
PROJECT      :  ECG Neural Network Display
DESCRIPTION  :  Testbench for fpga_top with neural network classifier
****************************************************************************/

`timescale 1ns / 1ps

module fpga_top_tb;

    // Clock period (25 MHz = 40ns)
    localparam CLK_PERIOD = 40;

    // Signals
    logic clk;
    logic reset;
    logic hsync;
    logic vsync;
    logic [2:0] rgb;

    // Instantiate DUT
    fpga_top dut (
        .clk(clk),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .rgb(rgb)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test stimulus
    initial begin
        $display("========================================");
        $display("ECG Neural Network Display Testbench");
        $display("========================================");
        
        // Reset
        reset = 1;
        repeat(10) @(posedge clk);
        reset = 0;
        
        $display("Reset released, starting simulation...");
        
        // Run for a few frames (each frame ~16.7ms at 60Hz)
        // At 25MHz, one frame = 800*525 = 420,000 clocks
        repeat(50000) @(posedge clk);
        
        $display("");
        $display("Sample outputs:");
        $display("  hsync=%b vsync=%b rgb=%03b", hsync, vsync, rgb);
        
        // Continue for more cycles
        repeat(100000) @(posedge clk);
        
        $display("");
        $display("========================================");
        $display("Simulation completed successfully!");
        $display("========================================");
        
        $finish;
    end

    // Monitor mood changes
    logic [1:0] prev_mood;
    initial prev_mood = 2'b00;
    
    always @(posedge clk) begin
        if (dut.mood != prev_mood) begin
            prev_mood <= dut.mood;
            case (dut.mood)
                2'b00: $display("Time %0t: Mood changed to CALM (blue)", $time);
                2'b01: $display("Time %0t: Mood changed to NORMAL (green)", $time);
                2'b10: $display("Time %0t: Mood changed to ALERT (red)", $time);
                default: $display("Time %0t: Mood changed to UNKNOWN", $time);
            endcase
        end
    end

    // Waveform dump
    initial begin
        $dumpfile("fpga_top_tb.vcd");
        $dumpvars(0, fpga_top_tb);
    end

endmodule
