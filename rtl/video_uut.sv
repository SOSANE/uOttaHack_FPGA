/****************************************************************************
FILENAME     :  video_uut.sv
PROJECT      :  Hack-a-Thon 2026
****************************************************************************/

/*  INSTANTIATION TEMPLATE  -------------------------------------------------

video_uut video_uut (       
    .clk_i          ( ),//               
    .cen_i          ( ),// video clock enable
    .rst_i          ( ),//
    .vid_sel_i      ( ),//
    .vid_rgb_i      ( ),//[23:0] = R[23:16], G[15:8], B[7:0]
    .vh_blank_i     ( ),//[ 1:0] = {Vblank, Hblank}
    .dvh_sync_i     ( ),//[ 2:0] = {D_sync, Vsync , Hsync }
    // Output signals
    .dvh_sync_o     ( ),//[ 2:0] = {D_sync, Vsync , Hsync }  delayed
    .vid_rgb_o      ( ) //[23:0] = R[23:16], G[15:8], B[7:0] delayed
);

-------------------------------------------------------------------------- */


module video_uut (
    input  wire         clk_i           ,// clock
    input  wire         cen_i           ,// clock enable
    input  wire         rst_i           ,// reset
    input  wire         vid_sel_i       ,// select between video sources
    input  wire [23:0]  vid_rgb_i       ,// [23:0] = R[23:16], G[15:8], B[7:0]
    input  wire [1:0]   vh_blank_i      ,// input  video timing signals
    input  wire [2:0]   dvh_sync_i      ,// HDMI timing signals
    output wire [2:0]   dvh_sync_o      ,// HDMI timing signals delayed
    output wire [23:0]  vid_rgb_o        // [23:0] = R[23:16], G[15:8], B[7:0]
); 

// Delayed signals for edge detection
reg HD, VD;  // Horizontal Delay, Vertical Delay
wire HR, HF, VR, VF;  // Horizontal Rising/Falling, Vertical Rising/Falling

// Counters
reg [11:0] HCNT;  // Horizontal counter: 0-1920
reg [10:0] VCNT;  // Vertical counter: 0-1024 (actually 0-1079 for 1080p)

// Edge detection
assign HR = ~HD && vh_blank_i[0];  // Horizontal Rising edge (entering blank)
assign HF = HD && ~vh_blank_i[0];  // Horizontal Falling edge (leaving blank)
assign VR = ~VD && vh_blank_i[1];  // Vertical Rising edge (entering blank)
assign VF = VD && ~vh_blank_i[1];  // Vertical Falling edge (leaving blank)

// Animation counter
reg [25:0] frame_counter;

// Snowflake parameters
localparam NUM_SNOWFLAKES = 12;
localparam SNOWFLAKE_SIZE = 16;  // Size of each snowflake

// Snowflake positions and properties
reg [10:0] snowflake_x [0:NUM_SNOWFLAKES-1];  // X positions
reg [10:0] snowflake_y [0:NUM_SNOWFLAKES-1];  // Y positions
reg [7:0]  snowflake_rot [0:NUM_SNOWFLAKES-1];  // Rotation angle (0-255)
reg [3:0]  snowflake_speed [0:NUM_SNOWFLAKES-1];  // Fall speed (1-15)

// Colors
localparam [23:0] COLOR_SNOWFLAKE = 24'hFF_FF_FF;  // White snowflakes
localparam [23:0] COLOR_BG_DARK  = 24'h00_00_20;  // Dark blue background
localparam [23:0] COLOR_BG       = 24'h00_00_40;  // Slightly lighter blue

reg [23:0]  vid_rgb_d1;
reg [2:0]   dvh_sync_d1;

// Function to draw a simple snowflake pattern
function [23:0] draw_snowflake;
    input [10:0] px, py;  // Pixel coordinates
    input [10:0] sx, sy;  // Snowflake center X, Y
    input [7:0]  rot;     // Rotation (not used in simplified version)
    reg [10:0] rel_x, rel_y;
    reg [10:0] abs_x, abs_y;
    begin
        // Calculate relative position (absolute value)
        if (px >= sx) begin
            rel_x = px - sx;
            abs_x = px - sx;
        end else begin
            rel_x = sx - px;
            abs_x = sx - px;
        end
        
        if (py >= sy) begin
            rel_y = py - sy;
            abs_y = py - sy;
        end else begin
            rel_y = sy - py;
            abs_y = sy - py;
        end
        
        // Check if pixel is within snowflake bounds
        if (abs_x > SNOWFLAKE_SIZE/2 || abs_y > SNOWFLAKE_SIZE/2) begin
            draw_snowflake = 24'h0;  // Transparent
        end else begin
            // Simple snowflake pattern: center + 4 lines (horizontal, vertical, 2 diagonals)
            // Center dot
            if (abs_x < 2 && abs_y < 2) begin
                draw_snowflake = COLOR_SNOWFLAKE;
            end
            // Horizontal line
            else if (abs_y < 2 && abs_x < SNOWFLAKE_SIZE/2) begin
                draw_snowflake = COLOR_SNOWFLAKE;
            end
            // Vertical line
            else if (abs_x < 2 && abs_y < SNOWFLAKE_SIZE/2) begin
                draw_snowflake = COLOR_SNOWFLAKE;
            end
            // Diagonal 1: check if on line y = x (within tolerance)
            else if (abs_x == abs_y && abs_x < SNOWFLAKE_SIZE/2) begin
                draw_snowflake = COLOR_SNOWFLAKE;
            end
            // Diagonal 2: check if on line y = -x (within tolerance) - simplified
            else if ((abs_x + abs_y < 3) && (abs_x > 1 || abs_y > 1)) begin
                draw_snowflake = COLOR_SNOWFLAKE;
            end
            else begin
                draw_snowflake = 24'h0;  // Transparent
            end
        end
    end
endfunction

// Check if any snowflake is at this pixel
wire [23:0] snowflake_color [0:NUM_SNOWFLAKES-1];
genvar i;
generate
    for (i = 0; i < NUM_SNOWFLAKES; i = i + 1) begin : gen_snowflakes
        assign snowflake_color[i] = draw_snowflake(HCNT, VCNT, snowflake_x[i], snowflake_y[i], snowflake_rot[i]);
    end
endgenerate

integer j;
always @(posedge clk_i) begin
    if (rst_i) begin
        HD <= 1'b0;
        VD <= 1'b0;
        HCNT <= 12'd0;
        VCNT <= 11'd0;
        frame_counter <= 26'd0;
        for (j = 0; j < NUM_SNOWFLAKES; j = j + 1) begin
            snowflake_x[j] <= (j * 160) % 1920;  // Distribute across screen
            snowflake_y[j] <= (j * 90) % 1080;   // Stagger vertically
            snowflake_rot[j] <= j * 21;           // Different rotation
            snowflake_speed[j] <= (j % 8) + 1;    // Speed 1-8
        end
        vid_rgb_d1 <= 24'h00_00_00;
        dvh_sync_d1 <= 3'b000;
    end else if(cen_i) begin
        // Update delayed signals
        HD <= vh_blank_i[0];  // Horizontal blank delay
        VD <= vh_blank_i[1];  // Vertical blank delay
        
        // Horizontal counter: 0-1920
        // Reset on HF (falling edge = leaving blank = start of visible line)
        // Increment only when not blanking
        if (HF) begin  // Horizontal falling edge (leaving blank = start of visible line)
            HCNT <= 12'd0;
        end else if (!vh_blank_i[0]) begin  // Not blanking - increment
            HCNT <= HCNT + 1;
        end
        
        // Vertical counter: 0-1079 (for 1080p)
        // Reset on VF (falling edge = leaving blank = start of frame)
        // Increment on HR (rising edge = entering blank = end of line)
        if (VF) begin  // Vertical falling edge (leaving blank = start of frame)
            VCNT <= 11'd0;
            // Update animation once per frame
            frame_counter <= frame_counter + 1;
            
            // Animate snowflakes
            for (j = 0; j < NUM_SNOWFLAKES; j = j + 1) begin
                // Move snowflake down
                if (snowflake_y[j] + snowflake_speed[j] >= 1080) begin
                    // Reset to top with random X position
                    snowflake_y[j] <= 11'd0;
                    snowflake_x[j] <= (snowflake_x[j] + 137) % 1920;  // Pseudo-random
                end else begin
                    snowflake_y[j] <= snowflake_y[j] + snowflake_speed[j];
                end
                
                // Rotate snowflake
                snowflake_rot[j] <= snowflake_rot[j] + (j % 4) + 1;  // Different rotation speeds
            end
        end else if (HR) begin  // Horizontal rising edge (entering blank = end of line)
            VCNT <= VCNT + 1;
        end
        
        // Draw background with gradient
        if (VCNT < 540) begin
            vid_rgb_d1 <= COLOR_BG_DARK + ((540 - VCNT) >> 4);
        end else begin
            vid_rgb_d1 <= COLOR_BG_DARK + ((VCNT - 540) >> 4);
        end
        
        // Draw snowflakes on top (check each snowflake, later ones draw on top)
        for (j = 0; j < NUM_SNOWFLAKES; j = j + 1) begin
            if (snowflake_color[j] != 24'h0) begin
                vid_rgb_d1 <= snowflake_color[j];
            end
        end
        
        dvh_sync_d1 <= dvh_sync_i;
    end
end

// OUTPUT
assign dvh_sync_o  = dvh_sync_d1;
assign vid_rgb_o   = vid_rgb_d1;

endmodule
