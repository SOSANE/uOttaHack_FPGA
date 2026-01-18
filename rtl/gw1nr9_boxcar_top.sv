/****************************************************************************
FILENAME     :  gw1nr9_boxcar_top.sv
PROJECT      :  Hack-a-Thon 2026
DESCRIPTION  :  Top-level module for GW1NR-9 board with boxcar neural network
                Includes button input, LED output, and automatic demo mode
****************************************************************************/

module gw1nr9_boxcar_top (
    input  wire        sys_clk,      // 27MHz system clock on GW1NR-9
    input  wire        sys_rst_n,    // Active-low reset button
    input  wire [3:0]  btn,          // 4 push buttons
    output wire [5:0]  led           // 6 LEDs
);

// Parameters
parameter WIDTH = 16;
parameter FRAC_BITS = 10;

// Internal signals
reg clk;
reg rst;
reg start;
reg signed [WIDTH-1:0] x_input;
wire signed [WIDTH-1:0] y_output;
wire valid;
wire [5:0] led_nn;

// Clock divider for slower demo (27MHz -> ~10Hz for visible LED changes)
reg [23:0] clk_div_counter;
reg clk_slow;

always_ff @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        clk_div_counter <= 0;
        clk_slow <= 0;
    end else begin
        if (clk_div_counter >= 24'd2_700_000) begin  // ~10Hz
            clk_div_counter <= 0;
            clk_slow <= ~clk_slow;
        end else begin
            clk_div_counter <= clk_div_counter + 1;
        end
    end
end

// Use system clock for NN computation (fast)
// Use slow clock for demo mode (visible)
assign clk = sys_clk;
assign rst = ~sys_rst_n;

// Demo mode: automatically cycle through test inputs
reg [3:0] demo_state;
reg [25:0] demo_counter;
reg demo_trigger;

// Convert real to fixed-point helper
function signed [WIDTH-1:0] real_to_fixed;
    input real val;
    begin
        real_to_fixed = $rtoi(val * 1024.0);  // Q5.10 format
    end
endfunction

always_ff @(posedge clk_slow or posedge rst) begin
    if (rst) begin
        demo_state <= 0;
        demo_counter <= 0;
        demo_trigger <= 0;
    end else begin
        demo_trigger <= 1;  // Trigger inference every slow clock
        demo_counter <= demo_counter + 1;
        
        // Cycle through demo states every ~1 second
        if (demo_counter >= 26'd10) begin
            demo_counter <= 0;
            demo_state <= demo_state + 1;
            if (demo_state >= 12)
                demo_state <= 0;
        end
    end
end

// Select input based on demo state or button press
always_comb begin
    case (demo_state)
        4'd0:  x_input = real_to_fixed(-3.0);
        4'd1:  x_input = real_to_fixed(-2.5);
        4'd2:  x_input = real_to_fixed(-2.0);
        4'd3:  x_input = real_to_fixed(-1.5);
        4'd4:  x_input = real_to_fixed(-1.0);
        4'd5:  x_input = real_to_fixed(-0.5);
        4'd6:  x_input = real_to_fixed(0.0);
        4'd7:  x_input = real_to_fixed(0.5);
        4'd8:  x_input = real_to_fixed(1.0);
        4'd9:  x_input = real_to_fixed(1.5);
        4'd10: x_input = real_to_fixed(2.0);
        4'd11: x_input = real_to_fixed(2.5);
        4'd12: x_input = real_to_fixed(3.0);
        default: x_input = 0;
    endcase
    
    // Override with button input if pressed
    if (btn[0]) x_input = real_to_fixed(-2.0);
    if (btn[1]) x_input = real_to_fixed(-1.0);
    if (btn[2]) x_input = real_to_fixed(1.0);
    if (btn[3]) x_input = real_to_fixed(2.0);
end

// Start signal generation
reg start_prev;
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        start <= 0;
        start_prev <= 0;
    end else begin
        start_prev <= demo_trigger;
        start <= demo_trigger && !start_prev;  // Edge detection
    end
end

// Instantiate neural network
boxcar_nn #(
    .WIDTH(WIDTH),
    .FRAC_BITS(FRAC_BITS)
) nn_inst (
    .clk_i(clk),
    .rst_i(rst),
    .start_i(start),
    .x_input(x_input),
    .y_output(y_output),
    .valid_o(valid),
    .led_o(led_nn)
);

// LED output
assign led = led_nn;

endmodule
