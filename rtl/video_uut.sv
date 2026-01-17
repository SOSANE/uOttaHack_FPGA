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

localparam [23:0] RGB_COLOUR = 24'hD0_10_80; // R=128, G=16,  B=128

// Track pixel position
reg [10:0] pixel_x, pixel_y;

// Animation counter (counts frames for slow animation)
reg [25:0] frame_counter;

// Box position (will move)
reg [10:0] box_x, box_y;
reg        box_dir_x, box_dir_y;  // Direction: 1 or 0

reg [23:0]  vid_rgb_d1;
reg [2:0]   dvh_sync_d1;

always @(posedge clk_i) begin
    if (rst_i) begin
        pixel_x <= 0;
        pixel_y <= 0;
        frame_counter <= 0;
        box_x <= 200;  // Start position
        box_y <= 200;
        box_dir_x <= 1;
        box_dir_y <= 1;
    end else if(cen_i) begin
        // Track pixel position
        if (vh_blank_i[0]) begin  // Hblank - new line
            pixel_x <= 0;
            if (vh_blank_i[1]) begin  // Vblank - new frame
                pixel_y <= 0;
                // Update animation once per frame
                frame_counter <= frame_counter + 1;
                
                // Move box every 2 frames (slower animation)
                if (frame_counter[1:0] == 2'b00) begin
                    // Move box X
                    if (box_dir_x == 1) begin
                        if (box_x < 1700) box_x <= box_x + 10;
                        else box_dir_x <= 0;  // Bounce right
                    end else begin
                        if (box_x > 10) box_x <= box_x - 10;
                        else box_dir_x <= 1;  // Bounce left
                    end
                    
                    // Move box Y
                    if (box_dir_y == 1) begin
                        if (box_y < 900) box_y <= box_y + 10;
                        else box_dir_y <= 0;  // Bounce bottom
                    end else begin
                        if (box_y > 10) box_y <= box_y - 10;
                        else box_dir_y <= 1;  // Bounce top
                    end
                end
            end else begin
                pixel_y <= pixel_y + 1;
            end
        end else begin
            pixel_x <= pixel_x + 1;
        end
        
        // Draw: white box, black background
        if ((pixel_x >= box_x && pixel_x < box_x + 200) &&
            (pixel_y >= box_y && pixel_y < box_y + 200)) begin
            vid_rgb_d1 <= 24'hFF_FF_FF;  // White box
        end else begin
            vid_rgb_d1 <= 24'h00_00_00;  // Black background
        end
        
        dvh_sync_d1 <= dvh_sync_i;
    end
end

// OUTPUT
assign dvh_sync_o  = dvh_sync_d1;
assign vid_rgb_o   = vid_rgb_d1;

endmodule

