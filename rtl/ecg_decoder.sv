module ecg_decoder (
    input  logic [7:0] ecg_sample,
    output logic [1:0] mood
);
    // 00 = Calm (blue)
    // 01 = Normal (green)
    // 10 = Alert (red)

    always_comb begin
        if (ecg_sample < 8'h60)
            mood = 2'b00;
        else if (ecg_sample < 8'hA0)
            mood = 2'b01;
        else
            mood = 2'b10;
    end
endmodule
