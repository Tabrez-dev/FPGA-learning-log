module dff(
    input clk,// The "Trigger" (Button press)
    input d,// The "Data" to save
    output reg q // The Output (Must be 'reg' because it remembers state)
);
    always @(posedge clk) begin
        q<=d;
    end

endmodule