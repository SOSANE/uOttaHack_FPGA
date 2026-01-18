module waveform_gen (
    input  logic        clk,
    input  logic        reset,
    input  logic [9:0]  x,
    input  logic [9:0]  y,
    output logic        draw,
    output logic [7:0]  ecg_sample
);

    reg [7:0] ecg_mem [0:255];
    initial begin
        $readmemh("ecg_data.mem", ecg_mem);
    end

    reg [7:0] index;

    always_ff @(posedge clk) begin
        if (reset)
            index <= 0;
        else if (x == 639)
            index <= index + 1;
    end

    assign ecg_sample = ecg_mem[index];

    // map 0–255 → 0–479
    wire [9:0] ecg_y;
    assign ecg_y = 480 - ((ecg_sample * 480) >> 8);

    assign draw = (x < 640) &&
                  ((y == ecg_y) || (y == ecg_y+1) || (y == ecg_y-1));

endmodule
