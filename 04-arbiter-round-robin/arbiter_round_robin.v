module arbiter_round_robin (
    input  wire [1:0] req,
    output reg  [1:0] gnt,
    // Formal Verification needs an external clock input.
    // In hardware, this port is ignored/empty.
    input  wire clk_formal 
);

    // --- HARDWARE UNIVERSE (Physical Chip) ---
    `ifndef FORMAL
        wire clk_internal;
        // 1. The Physical Oscillator
        SB_HFOSC inthosc (
            .CLKHFPU(1'b1),
            .CLKHFEN(1'b1),
            .CLKHF(clk_internal)
        );
        
        // 2. The Huge Counter
        reg [23:0] counter;
        reg slow_tick_reg;
        always @(posedge clk_internal) begin
            counter <= counter + 1;
            slow_tick_reg <= (counter == 0);
        end

        // Define the clock and tick for the main logic
        wire clk = clk_internal;
        wire slow_tick = slow_tick_reg;
    `endif

    // --- FORMAL UNIVERSE 1: SIGNALS ---
    `ifdef FORMAL
        // 1. Use the fake external clock
        wire clk = clk_formal;
        // 2. Force the tick to be ALWAYS TRUE so we don't wait 16 million cycles
        wire slow_tick = 1'b1; 
    `endif


    // --- THE LOGIC (The part we actually want to prove) ---
    reg priority_token = 0;

    always @(posedge clk) begin
        if (slow_tick) begin
            gnt <= 2'b00; 

            if (priority_token == 0) begin
                if (req[0]) begin
                    gnt[0] <= 1'b1;
                    priority_token <= 1; // Req 0 served -> Token passes to 1
                end else if (req[1]) begin
                    gnt[1] <= 1'b1;
                    // Req 1 served (even though low priority) -> Token stays/becomes 0 (Low for 1)
                    priority_token <= 0; 
                end
            end 
            else begin // priority_token == 1
                if (req[1]) begin
                    gnt[1] <= 1'b1;
                    priority_token <= 0; // Req 1 served -> Token passes to 0
                end else if (req[0]) begin
                    gnt[0] <= 1'b1;
                    // Req 0 served (even though low priority) -> Token stays/becomes 1 (Low for 0)
                    priority_token <= 1;
                end
            end
        end
    end

    // --- FORMAL UNIVERSE 2: PROOFS ---
    `ifdef FORMAL
    
    // 1. Helper to know if "Yesterday" exists
    reg f_past_valid = 0;
    always @(posedge clk) begin
        f_past_valid <= 1;
    end

    // 2. CONSTRAINT: Start Clean
    // Force the tool to start with everything OFF
    initial begin
        gnt = 2'b00;
        priority_token = 1'b0;
    end

   // 3. ASSERTIONS
    always @(posedge clk) begin
        // Only check assertions after the first clock cycle
        if (f_past_valid) begin
            
            // Property 1: Mutual Exclusion (Safety)
            // Never grant both at the same time.
            assert(!(gnt[0] && gnt[1]));

            // Property 2: Fairness (Strict Round Robin)
            // If I am currently granted, the token MUST be pointing to the other person.
            // (This proves that I cannot hold the token while I am using the resource)
            if (gnt[0]) assert(priority_token == 1);
            if (gnt[1]) assert(priority_token == 0);
        end
    end
    `endif

endmodule