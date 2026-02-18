module arbiter (
    input  wire [1:0] req,
    output reg  [1:0] gnt
);

    // --- Original Logic ---
    always @(*) begin
        gnt = 2'b00;
        if (req[0]) begin
            gnt[0] = 1'b1;
        end else if (req[1]) begin
            gnt[1] = 1'b1;
        end
    end


    `ifdef FORMAL
    always @(*) begin
        // 1. Safety: Only one grant at a time
        assert(!(gnt[0] && gnt[1]));

        // 2. Priority: Req[0] must disable Gnt[1]
        if (req[0]) begin
            assert(gnt[0] == 1'b1);
            assert(gnt[1] == 1'b0);
        end
    end
    `endif

endmodule 