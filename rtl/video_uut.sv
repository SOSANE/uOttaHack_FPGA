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
localparam [23:0] COLOR_MAZE      = 24'h00_40_80;  // Dark blue for maze
localparam [23:0] COLOR_GHOST_R   = 24'hFF_00_00;  // Red ghost (R)
localparam [23:0] COLOR_GHOST_O1  = 24'hFF_80_00;  // Orange ghost (O)
localparam [23:0] COLOR_GHOST_S1  = 24'hFF_00_FF;  // Magenta ghost (S)
localparam [23:0] COLOR_GHOST_S2  = 24'h00_FF_00;  // Green ghost (S)
localparam [23:0] COLOR_PACMAN    = 24'hFF_FF_00;  // Yellow Pac-Man

// Maze animation offset (faster up/down movement, signed)
reg signed [10:0] maze_offset_y;
reg [7:0] pacman_mouth_angle;  // Pac-Man mouth animation (0-63 for open/close)

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

// Function to draw maze walls and letters (smaller, centered ROSS)
function [23:0] draw_maze;
    input [10:0] px, py;  // Pixel coordinates
    input signed [10:0] offset_y;  // Vertical offset for animation (signed)
    reg signed [10:0] adj_y;
    reg [10:0] center_x, center_y;
    reg [10:0] letter_start_x;
    begin
        center_x = 960;  // Screen center X
        center_y = 540;  // Screen center Y
        adj_y = $signed(py) - offset_y;  // Subtract offset to make maze move
        draw_maze = 24'h0;  // Transparent by default
        
        // Draw Pac-Man style borders around the screen
        // Top border
        if (adj_y < 50 && px >= 50 && px < 1870) begin
            draw_maze = COLOR_MAZE;
        end
        // Bottom border
        if (adj_y >= 1030 && px >= 50 && px < 1870) begin
            draw_maze = COLOR_MAZE;
        end
        // Left border
        if (px < 50 && adj_y >= 50 && adj_y < 1030) begin
            draw_maze = COLOR_MAZE;
        end
        // Right border
        if (px >= 1870 && adj_y >= 50 && adj_y < 1030) begin
            draw_maze = COLOR_MAZE;
        end
        
        // Smaller maze - centered in middle third of screen
        // Maze area: roughly 600x300 pixels centered
        letter_start_x = center_x - 300;  // Start of letters
        
        // Draw "ROSS" letters as maze walls (smaller scale)
        // R - First letter (fixed)
        if (px >= letter_start_x && px < letter_start_x + 120 && adj_y >= center_y - 100 && adj_y < center_y + 100) begin
            // R shape walls - proper R shape
            if ((px >= letter_start_x && px < letter_start_x + 15 && adj_y >= center_y - 100 && adj_y < center_y + 100) ||  // Left vertical
                (px >= letter_start_x + 15 && px < letter_start_x + 105 && adj_y >= center_y - 100 && adj_y < center_y - 85) ||  // Top horizontal
                (px >= letter_start_x + 15 && px < letter_start_x + 105 && adj_y >= center_y - 15 && adj_y < center_y) ||  // Middle horizontal
                (px >= letter_start_x + 105 && px < letter_start_x + 120 && adj_y >= center_y - 100 && adj_y < center_y - 15) ||  // Top right vertical
                (px >= letter_start_x + 60 && px < letter_start_x + 75 && adj_y >= center_y && adj_y < center_y + 100) ||  // Bottom right diagonal
                (px >= letter_start_x + 75 && px < letter_start_x + 90 && adj_y >= center_y + 50 && adj_y < center_y + 100)) begin  // Bottom right vertical
                draw_maze = COLOR_MAZE;
            end
        end
        
        // O - Second letter
        if (px >= letter_start_x + 140 && px < letter_start_x + 260 && adj_y >= center_y - 100 && adj_y < center_y + 100) begin
            // O shape walls (circle/oval)
            if ((px >= letter_start_x + 140 && px < letter_start_x + 155 && adj_y >= center_y - 100 && adj_y < center_y + 100) ||
                (px >= letter_start_x + 245 && px < letter_start_x + 260 && adj_y >= center_y - 100 && adj_y < center_y + 100) ||
                (px >= letter_start_x + 155 && px < letter_start_x + 245 && adj_y >= center_y - 100 && adj_y < center_y - 85) ||
                (px >= letter_start_x + 155 && px < letter_start_x + 245 && adj_y >= center_y + 85 && adj_y < center_y + 100)) begin
                draw_maze = COLOR_MAZE;
            end
        end
        
        // S - Third letter
        if (px >= letter_start_x + 280 && px < letter_start_x + 400 && adj_y >= center_y - 100 && adj_y < center_y + 100) begin
            // S shape walls
            if ((px >= letter_start_x + 280 && px < letter_start_x + 295 && adj_y >= center_y - 100 && adj_y < center_y - 15) ||
                (px >= letter_start_x + 280 && px < letter_start_x + 400 && adj_y >= center_y - 100 && adj_y < center_y - 85) ||
                (px >= letter_start_x + 280 && px < letter_start_x + 400 && adj_y >= center_y - 15 && adj_y < center_y) ||
                (px >= letter_start_x + 385 && px < letter_start_x + 400 && adj_y >= center_y && adj_y < center_y + 100) ||
                (px >= letter_start_x + 280 && px < letter_start_x + 400 && adj_y >= center_y + 85 && adj_y < center_y + 100)) begin
                draw_maze = COLOR_MAZE;
            end
        end
        
        // S - Fourth letter
        if (px >= letter_start_x + 420 && px < letter_start_x + 540 && adj_y >= center_y - 100 && adj_y < center_y + 100) begin
            // S shape walls (same as third)
            if ((px >= letter_start_x + 420 && px < letter_start_x + 435 && adj_y >= center_y - 100 && adj_y < center_y - 15) ||
                (px >= letter_start_x + 420 && px < letter_start_x + 540 && adj_y >= center_y - 100 && adj_y < center_y - 85) ||
                (px >= letter_start_x + 420 && px < letter_start_x + 540 && adj_y >= center_y - 15 && adj_y < center_y) ||
                (px >= letter_start_x + 525 && px < letter_start_x + 540 && adj_y >= center_y && adj_y < center_y + 100) ||
                (px >= letter_start_x + 420 && px < letter_start_x + 540 && adj_y >= center_y + 85 && adj_y < center_y + 100)) begin
                draw_maze = COLOR_MAZE;
            end
        end
    end
endfunction

// Function to draw Pac-Man
function [23:0] draw_pacman;
    input [10:0] px, py;  // Pixel coordinates
    input [10:0] pac_x, pac_y;  // Pac-Man center X, Y
    input [7:0]  mouth_angle;  // Mouth opening angle (0-63)
    reg [10:0] rel_x, rel_y;
    reg [10:0] abs_x, abs_y;
    reg [11:0] dist_sq;
    reg [7:0] angle;
    begin
        if (px >= pac_x) begin
            rel_x = px - pac_x;
            abs_x = px - pac_x;
        end else begin
            rel_x = pac_x - px;
            abs_x = pac_x - px;
        end
        
        if (py >= pac_y) begin
            rel_y = py - pac_y;
            abs_y = py - pac_y;
        end else begin
            rel_y = pac_y - py;
            abs_y = pac_y - py;
        end
        
        // Pac-Man is roughly 30x30 pixels
        if (abs_x > 15 || abs_y > 15) begin
            draw_pacman = 24'h0;  // Transparent
        end else begin
            dist_sq = abs_x * abs_x + abs_y * abs_y;
            
            // Draw circle
            if (dist_sq < 225) begin  // 15^2 = 225
                // Mouth opens to the right (positive X)
                // Mouth opens symmetrically up and down
                // mouth_angle: 0 = closed, 32 = half open, 63 = fully open
                if (rel_x > 0) begin
                    // Right side - check if in mouth opening
                    // Mouth opens symmetrically: exclude pixels where abs(rel_y) < mouth_angle/2
                    if (abs_y < (mouth_angle >> 1)) begin
                        // This pixel is in the mouth opening - don't draw
                        draw_pacman = 24'h0;
                    end else begin
                        draw_pacman = COLOR_PACMAN;
                    end
                end else begin
                    // Left side - always draw
                    draw_pacman = COLOR_PACMAN;
                end
            end else begin
                draw_pacman = 24'h0;
            end
        end
    end
endfunction

// Function to draw ghosts with letters
function [23:0] draw_ghost;
    input [10:0] px, py;  // Pixel coordinates
    input [10:0] gx, gy;  // Ghost center X, Y
    input [23:0] ghost_color;  // Ghost color
    input [7:0]  letter;  // Letter to display (R, O, S, S)
    reg [10:0] rel_x, rel_y;
    reg [10:0] abs_x, abs_y;
    begin
        if (px >= gx) begin
            rel_x = px - gx;
            abs_x = px - gx;
        end else begin
            rel_x = gx - px;
            abs_x = gx - px;
        end
        
        if (py >= gy) begin
            rel_y = py - gy;
            abs_y = py - gy;
        end else begin
            rel_y = gy - py;
            abs_y = gy - py;
        end
        
        // Ghost is roughly 30x30 pixels (smaller)
        if (abs_x > 15 || abs_y > 15) begin
            draw_ghost = 24'h0;  // Transparent
        end else begin
            // Ghost body - proper Pac-Man ghost shape
            // Rounded top (semi-circle)
            if (abs_y < 10) begin
                // Top rounded part
                if (abs_x * abs_x + (abs_y - 10) * (abs_y - 10) < 100) begin
                    draw_ghost = ghost_color;
                end
            end else begin
                // Rectangular body with wavy bottom
                // Wavy bottom pattern: indent every 4 pixels
                if (abs_y < 15) begin
                    // Regular body
                    draw_ghost = ghost_color;
                end else begin
                    // Wavy bottom - create indent pattern
                    if ((abs_x % 4) < 2) begin
                        draw_ghost = ghost_color;
                    end else begin
                        draw_ghost = 24'h0;  // Indent
                    end
                end
            end
            // Ghost eyes (two white circles)
            if ((abs_x >= 4 && abs_x < 7 && abs_y >= 4 && abs_y < 7) ||
                (abs_x >= 8 && abs_x < 11 && abs_y >= 4 && abs_y < 7)) begin
                draw_ghost = 24'hFF_FF_FF;  // White eyes
            end
            // Eye pupils
            if ((abs_x >= 5 && abs_x < 6 && abs_y >= 5 && abs_y < 6) ||
                (abs_x >= 9 && abs_x < 10 && abs_y >= 5 && abs_y < 6)) begin
                draw_ghost = 24'h00_00_00;  // Black pupils
            end
            
            // Draw letter at bottom right of ghost (smaller, visible)
            // Position: bottom right corner (abs_x: 8-14, abs_y: 10-15)
            if (abs_y >= 10 && abs_y < 15 && abs_x >= 8 && abs_x < 15) begin
                case (letter)
                    8'h52: begin  // R (smaller, bottom right)
                        if ((abs_x >= 8 && abs_x < 9 && abs_y >= 10 && abs_y < 14) ||
                            (abs_x >= 9 && abs_x < 11 && abs_y >= 10 && abs_y < 11) ||
                            (abs_x >= 9 && abs_x < 11 && abs_y >= 12 && abs_y < 13) ||
                            (abs_x >= 11 && abs_x < 12 && abs_y >= 10 && abs_y < 12) ||
                            (abs_x >= 9 && abs_x < 10 && abs_y >= 13 && abs_y < 14)) begin
                            draw_ghost = 24'hFF_FF_FF;  // White letter
                        end
                    end
                    8'h4F: begin  // O (smaller, bottom right)
                        if ((abs_x >= 8 && abs_x < 9 && abs_y >= 10 && abs_y < 14) ||
                            (abs_x >= 11 && abs_x < 12 && abs_y >= 10 && abs_y < 14) ||
                            (abs_x >= 9 && abs_x < 11 && abs_y >= 10 && abs_y < 11) ||
                            (abs_x >= 9 && abs_x < 11 && abs_y >= 13 && abs_y < 14)) begin
                            draw_ghost = 24'hFF_FF_FF;
                        end
                    end
                    8'h53: begin  // S (smaller, bottom right)
                        if ((abs_x >= 8 && abs_x < 9 && abs_y >= 10 && abs_y < 12) ||
                            (abs_x >= 8 && abs_x < 11 && abs_y >= 10 && abs_y < 11) ||
                            (abs_x >= 8 && abs_x < 11 && abs_y >= 12 && abs_y < 13) ||
                            (abs_x >= 11 && abs_x < 12 && abs_y >= 13 && abs_y < 14) ||
                            (abs_x >= 8 && abs_x < 11 && abs_y >= 13 && abs_y < 14)) begin
                            draw_ghost = 24'hFF_FF_FF;
                        end
                    end
                endcase
            end
        end
    end
endfunction

// Ghost positions (centered in each letter area, move with maze, don't touch logo)
wire [23:0] maze_color;
wire [23:0] ghost_color [0:3];
wire [23:0] pacman_color;
wire [10:0] ghost_y_base, pacman_y_base;
wire [10:0] ghost_x [0:3];
// Position ghosts above the logo (with spacing so they don't touch)
assign ghost_x[0] = 960 - 300 + 60;   // R
assign ghost_x[1] = 960 - 300 + 200;  // O
assign ghost_x[2] = 960 - 300 + 340;  // S
assign ghost_x[3] = 960 - 300 + 480;  // S
assign ghost_y_base = (maze_offset_y[10]) ? (540 - 150 + (~maze_offset_y + 1)) : (540 - 150 - maze_offset_y);  // Above logo, with spacing
assign pacman_y_base = ghost_y_base;  // Pac-Man moves with maze
assign maze_color = draw_maze(HCNT, VCNT, maze_offset_y);
assign ghost_color[0] = draw_ghost(HCNT, VCNT, ghost_x[0], ghost_y_base, COLOR_GHOST_R, 8'h52);  // R
assign ghost_color[1] = draw_ghost(HCNT, VCNT, ghost_x[1], ghost_y_base, COLOR_GHOST_O1, 8'h4F);  // O
assign ghost_color[2] = draw_ghost(HCNT, VCNT, ghost_x[2], ghost_y_base, COLOR_GHOST_S1, 8'h53);  // S
assign ghost_color[3] = draw_ghost(HCNT, VCNT, ghost_x[3], ghost_y_base, COLOR_GHOST_S2, 8'h53);  // S
assign pacman_color = draw_pacman(HCNT, VCNT, 960 - 350, pacman_y_base, pacman_mouth_angle);  // Pac-Man to the left

integer j;
always @(posedge clk_i) begin
    if (rst_i) begin
        HD <= 1'b0;
        VD <= 1'b0;
        HCNT <= 12'd0;
        VCNT <= 11'd0;
        frame_counter <= 26'd0;
        maze_offset_y <= 11'd0;
        pacman_mouth_angle <= 8'd0;
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
            
            // Animate maze - faster up/down movement (~20 pixels range)
            // Oscillate between -20 and +20 using frame counter (faster)
            if (frame_counter[9:0] < 10'd256) begin
                maze_offset_y <= $signed(frame_counter[6:0] >> 2) - 20;  // -20 to 0 (faster)
            end else begin
                maze_offset_y <= $signed(20 - (frame_counter[6:0] >> 2));  // 0 to +20 (faster)
            end
            
            // Animate Pac-Man mouth (slow biting, smooth)
            // Mouth opens and closes slowly (cycle through 0-32 for smooth animation)
            if (frame_counter[10:0] < 11'd512) begin
                pacman_mouth_angle <= frame_counter[5:0];  // Open mouth (0 to 63)
            end else begin
                pacman_mouth_angle <= 11'd63 - frame_counter[5:0];  // Close mouth (63 to 0)
            end
            
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
        
        // Draw maze (dark blue)
        if (maze_color != 24'h0) begin
            vid_rgb_d1 <= maze_color;
        end
        
        // Draw Pac-Man (on top of maze)
        if (pacman_color != 24'h0) begin
            vid_rgb_d1 <= pacman_color;
        end
        
        // Draw ghosts with letters (on top of maze)
        for (j = 0; j < 4; j = j + 1) begin
            if (ghost_color[j] != 24'h0) begin
                vid_rgb_d1 <= ghost_color[j];
            end
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
