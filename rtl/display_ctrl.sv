module display_ctrl (
    input  logic clk,
    input  logic reset,
    input  logic draw_wave,
    input  logic [1:0] mood,
    output logic hsync,
    output logic vsync,
    output logic [2:0] rgb,
    output logic [9:0] x,
    output logic [9:0] y
);

    // VGA 640x480 @ 60Hz
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = 800;

    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = 525;

    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    always_ff @(posedge clk) begin
        if (reset) begin
            h_cnt <= 0;
            v_cnt <= 0;
        end else begin
            if (h_cnt == H_TOTAL-1) begin
                h_cnt <= 0;
                if (v_cnt == V_TOTAL-1)
                    v_cnt <= 0;
                else
                    v_cnt <= v_cnt + 1;
            end else
                h_cnt <= h_cnt + 1;
        end
    end

    assign x = h_cnt;
    assign y = v_cnt;

    assign hsync = ~(h_cnt >= H_VISIBLE + H_FRONT &&
                     h_cnt <  H_VISIBLE + H_FRONT + H_SYNC);

    assign vsync = ~(v_cnt >= V_VISIBLE + V_FRONT &&
                     v_cnt <  V_VISIBLE + V_FRONT + V_SYNC);

    wire visible;
    assign visible = (h_cnt < H_VISIBLE && v_cnt < V_VISIBLE);

    always_comb begin
        if (!visible)
            rgb = 3'b000;
        else if (draw_wave)
            rgb = 3'b111;   // ECG line: white
        else begin
            case (mood)
                2'b00: rgb = 3'b001; // Calm: blue
                2'b01: rgb = 3'b010; // Normal: green
                2'b10: rgb = 3'b100; // Alert: red
                default: rgb = 3'b000;
            endcase
        end
    end

endmodule
