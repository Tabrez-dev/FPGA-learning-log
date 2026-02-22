/**
 * Project: 05-breathing-led
 * Architecture: PWM Controller with Triangle Wave Generation
 * * INTUITION FOR FIRMWARE ENGINEERS:
 * 1. pwm_counter    -> This is your "PWM Period" timer (Autoreload register).
 * 2. breath_counter -> This is your "Main Loop" delay timer.
 * 3. brightness     -> This is your "Duty Cycle" (Capture/Compare register).
 * 4. Comparator (<) -> This is the hardware output logic that toggles the pin.
 */

module breathing (
    output wire led
);

    // --- 1. The Physical Clock Source ---
    // Why: Digital logic is just a "statue" without a clock. We use the internal 
    // Lattice high-frequency oscillator (SB_HFOSC) to provide 48 million pulses/sec.
    wire clk;
    SB_HFOSC inthosc (
        .CLKHFPU(1'b1), // Power up the oscillator
        .CLKHFEN(1'b1), // Enable the oscillator
        .CLKHF(clk)    // The raw 48 MHz signal
    );

    // --- 2. The Fast Counter (PWM Carrier) ---
    // Why: We need a high-frequency flicker (187.5 kHz) that the eye can't see.
    // Analogy: This is your "PWM Period." It defines the window of time 
    // in which we decide to stay ON or OFF.
    (* keep = 1 *) reg [7:0] pwm_counter = 0;
    always @(posedge clk) begin
        pwm_counter <= pwm_counter + 1;
    end

    // --- 3. The Slow Counter (The Breathing Heartbeat) ---
    // Why: 48MHz is too fast for humans. We use a massive 27-bit register to 
    // "slow down" time. 
    // Math: 2^27 cycles / 48,000,000 Hz ≈ 2.8 seconds for a full cycle.
    (* keep = 1 *) reg [26:0] breath_counter = 0;
    always @(posedge clk) begin
        breath_counter <= breath_counter + 1;
    end

    // --- 4. The Triangle Wave Logic (Math Trick) ---
    // Why: We want the LED to fade UP then DOWN. Instead of a complex "if/else" 
    // state machine in C, we use the MSB (Most Significant Bit) as a direction flag.
    
    // Bit 26 stays '0' for 1.4s, then '1' for 1.4s. 
    (* keep = 1 *) wire direction = breath_counter[26]; 

    // Bits 25-18 are our 8-bit "brightness level" that increments slowly.
    (* keep = 1 *) wire [7:0] magnitude = breath_counter[25:18]; 

    // Why use ~magnitude?: 
    // When direction is 0: brightness goes 0 -> 255 (Fade In)
    // When direction is 1: brightness goes 255 -> 0 (Fade Out) using bit-inversion.
    // Firmware equivalent: brightness = direction ? (0xFF ^ magnitude) : magnitude;
    (* keep = 1 *) wire [7:0] brightness;
    assign brightness = direction ? ~magnitude : magnitude;

    // --- 5. The PWM Comparator ---
    // Why: This is the actual D/A (Digital to Analog) conversion.
    // If the fast counter is below the slow brightness limit, the LED is ON.
    // This creates a variable "Duty Cycle" (the ratio of ON time to OFF time).
    // 
    assign led = (pwm_counter < brightness);

endmodule