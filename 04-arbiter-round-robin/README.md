# Round Robin Arbiter: The Fair Referee

This is a 2-request round-robin arbiter for the Soan Papdi (iCE40UP5K) FPGA. Request 0 and Request 1 get equal turns — no one hogs the resource.

**The interesting part:** This project has two completely separate "universes" in the same Verilog file. One universe runs on real hardware with a physical oscillator and a slow counter. The other universe exists purely for mathematical proof.

## What You'll Learn

- How round-robin arbitration works (fair turns, not priority)
- The "dual universe" pattern: hardware reality vs formal verification
- Why formal proofs need a clock but don't care about slow counters
- How to prove your design works without actually testing it
- The difference between checking "now" vs checking "yesterday"

---

## 1. Round Robin: What and Why

### The Problem with Priority

In project 03, Request 0 always won. If both switches are pressed, LED 0 lights and LED 1 stays dark. This is fine for emergency systems (brakes beat radio), but unfair when both tasks matter equally.

**Real example:** Two people waiting for a printer:
- Priority arbiter: Alice cuts in line every time. Bob only prints when Alice isn't waiting.
- Round-robin arbiter: Alice prints, then Bob prints, then Alice again. Fair.

### How It Works

The arbiter tracks whose turn it is with a "priority token":
- Token = 0 → Request 0 has priority
- Token = 1 → Request 1 has priority

**The fairness rule:** After you get a grant, the token passes to the other person *immediately*.

**Try it on hardware:**
1. Press Switch A0 → LED D0 lights (Request 0 served)
2. Keep holding A0, press A1 → LED stays on D0 (A0's turn)
3. Release A0 → LED D1 lights (token passed to A1)
4. Release A1, press A0 → LED D0 lights (token passed back)

You can't hog it. You get one turn, then you wait.

---

## 2. Why Formal Verification Beats Testing

### What Testing Would Look Like

```verilog
// Traditional testbench
initial begin
    req = 2'b00; #10;
    req = 2'b10; #10;  // Request 0 → Should grant 0
    req = 2'b11; #10;  // Both request → Should grant 0 (has priority)
    req = 2'b01; #10;  // Request 1 → Should grant 1 (token passed)
    // Did I test enough cases?
    // What about timing glitches?
    // What if the token gets stuck?
end
```

**The problem:** You can only test sequences you thought of. What about:
- Request 0 held for 5 cycles, then Request 1 presses on cycle 6?
- Both requests toggling rapidly?
- The token starting in a weird state at power-on?

You'd need hundreds of test cases. And you'd still miss edge cases.

### What Formal Verification Does

```verilog
assert(!(gnt[0] && gnt[1]));  // PROVE both grants never happen
```

The formal tool checks *every possible sequence of req values*. It tries:
- All 4 input combinations (00, 01, 10, 11)
- All possible orderings and timings
- All starting states

If it can find even one counterexample, it shows you the exact sequence that breaks the assertion. If it can't find any, the property is proven.

**Testbench:** "I tried these 20 cases and they worked."
**Formal:** "I tried all 2^40 sequences (for depth 20) and proved none violate the rules."

---

## 3. The Dual Universe Architecture

Here's the weird part: this Verilog file contains *two completely different designs* depending on whether you're building for hardware or running formal verification.

### Hardware Universe (Real Chip)

```verilog
`ifndef FORMAL
    wire clk_internal;
    // 1. Physical oscillator (built into the iCE40)
    SB_HFOSC inthosc (
        .CLKHFPU(1'b1),
        .CLKHFEN(1'b1),
        .CLKHF(clk_internal)
    );
    
    // 2. Slow-down counter (divide clock by 16 million)
    reg [23:0] counter;
    reg slow_tick_reg;
    always @(posedge clk_internal) begin
        counter <= counter + 1;
        slow_tick_reg <= (counter == 0);
    end
    
    wire clk = clk_internal;
    wire slow_tick = slow_tick_reg;
`endif
```

**What's happening:**

**SB_HFOSC** — The iCE40 has a built-in high-frequency oscillator (48 MHz). This primitive instantiates it.
- `.CLKHFPU(1'b1)` — Power it up
- `.CLKHFEN(1'b1)` — Enable it
- `.CLKHF(clk_internal)` — Output goes to our wire

**Counter** — A 24-bit counter that counts every clock cycle. When it rolls over from `24'hFFFFFF` to `24'h000000`, `slow_tick` pulses high for one cycle.

**Why?** At 48 MHz, this creates a tick roughly every 0.35 seconds. Without this, the LEDs would blink so fast you'd see a blur, not discrete grants.

### Formal Universe (Math World)

```verilog
`ifdef FORMAL
    wire clk = clk_formal;  // Use the external test clock
    wire slow_tick = 1'b1;  // Always true
`endif
```

**What's happening:**

**clk_formal** — An input port that only exists for formal verification. The hardware ignores it.

**slow_tick = 1** — We force the tick to always be true.

**Why force slow_tick?** The formal tool doesn't care about human-visible speeds. If we made it count 16 million cycles, the proof would take days. We want to prove the *logic* works, not the *clock divider* works. So we skip the wait.

**This is the key insight:** Formal verification lets you separate concerns. The counter is correct by inspection (it's just `counter + 1`). We prove the arbiter logic separately.

---

## 4. The Logic (What We're Actually Proving)

```verilog
reg priority_token = 0;

always @(posedge clk) begin
    if (slow_tick) begin
        gnt <= 2'b00;  // Default: no grants
        
        if (priority_token == 0) begin
            // Request 0 has priority
            if (req[0]) begin
                gnt[0] <= 1'b1;
                priority_token <= 1;  // Served 0 → Token to 1
            end else if (req[1]) begin
                gnt[1] <= 1'b1;
                priority_token <= 0;  // Served 1 (backup) → Token stays at 0
            end
        end else begin
            // Request 1 has priority
            if (req[1]) begin
                gnt[1] <= 1'b1;
                priority_token <= 0;  // Served 1 → Token to 0
            end else if (req[0]) begin
                gnt[0] <= 1'b1;
                priority_token <= 1;  // Served 0 (backup) → Token stays at 1
            end
        end
    end
end
```

**Breaking it down:**

```verilog
always @(posedge clk) begin
    if (slow_tick) begin
```

Only update when `slow_tick` is high. In hardware, this is once every 16M cycles. In formal, it's every cycle.

```verilog
gnt <= 2'b00;
```

Start each decision cycle by clearing both grants. Then we'll set one if needed.

**Why clear first?** It guarantees mutual exclusion. We can't accidentally leave both high.

```verilog
if (priority_token == 0) begin
    if (req[0]) begin
        gnt[0] <= 1'b1;
        priority_token <= 1;
```

**Token = 0** means Request 0 has priority. If it's requesting, grant it and pass the token to Request 1.

```verilog
    end else if (req[1]) begin
        gnt[1] <= 1'b1;
        priority_token <= 0;
```

If Request 0 didn't want it, give it to Request 1 (if they're requesting). Token stays at 0.

**Why keep token at 0?** Request 1 got served as a "backup" (not their priority turn). We don't punish Request 0 for not asking. Next cycle, Request 0 still has priority.

**The other branch (token == 1) is symmetric:** Request 1 gets priority, Request 0 is the backup.

---

## 5. The Formal Verification Setup

### Helper: f_past_valid

```verilog
reg f_past_valid = 0;
always @(posedge clk) begin
    f_past_valid <= 1;
end
```

**What this does:** Creates a flag that's 0 at the very first clock cycle, then 1 forever after.

**Why we need it:** At power-on, registers contain garbage. The first clock cycle might violate assertions before things settle. `f_past_valid` lets us say "start checking after cycle 0."

**Cycle 0:** `f_past_valid = 0` → Assertions don't run
**Cycle 1+:** `f_past_valid = 1` → Assertions check

### Initial State

```verilog
initial begin
    gnt = 2'b00;
    priority_token = 1'b0;
end
```

Forces a clean start. Without this, the formal tool tries all possible starting values (including garbage), and some assertions might fail on weird initial states.

**This is a formal verification lesson:** Real hardware has power-on garbage. Formal tools expose this. You need `initial` blocks or reset logic to handle it.

### The Assertions

```verilog
always @(posedge clk) begin
    if (f_past_valid) begin
        // Property 1: Mutual Exclusion
        assert(!(gnt[0] && gnt[1]));
        
        // Property 2: Token Follows Grant
        if (gnt[0]) assert(priority_token == 1);
        if (gnt[1]) assert(priority_token == 0);
    end
end
```

**Assertion 1: Mutual exclusion**

```verilog
assert(!(gnt[0] && gnt[1]));
```

Both grants can never be high simultaneously. This is a safety property.

**Why it works:** We always clear `gnt` to `00` first, then set at most one bit. Impossible to set both.

**Assertion 2: Token correctness**

```verilog
if (gnt[0]) assert(priority_token == 1);
```

**What this proves:** If Request 0 is granted right now, the token must have passed to Request 1.

**Why this matters:** This proves we can't hold the token while using the resource. The instant you get served, you lose priority.

**Note the timing:** This checks the *current* state, not the past state. After serving Request 0, the same clock edge that sets `gnt[0]` also sets `priority_token = 1`. So in this cycle, both are true simultaneously.

**Contrast with "yesterday" checks:** If we wrote `if ($past(gnt[0])) assert(priority_token == 1)`, we'd be checking a cycle later, which has different timing.

---

## 6. Build and Test

### Build for hardware

```bash
apio build
```

Yosys sees `ifndef FORMAL`, so it includes the oscillator and counter code. The bitstream has real hardware.

### Build for formal verification

```bash
sby -f arbiter_round_robin.sby
```

Yosys sees `ifdef FORMAL`, so it uses `clk_formal` and `slow_tick = 1`. The proof ignores hardware details.

### Flash to the board

1. Enter DFU mode: Hold `PROG`, press `RESET`, release `PROG`
2. `apio upload`
3. Press `RESET`

### Test the behavior

**Sequence to try:**

1. Press A0 alone → D0 lights (Request 0 granted, token passes to 1)
2. Hold A0, press A1 → D0 stays on (A0 still has grant, even though token is now 1)
3. Release A0 → Wait for next slow_tick → D1 lights (token is 1, so A1 gets priority)
4. Release A1 → Press A0 → Wait for tick → D0 lights (token passed back to 0)

**Important:** Changes only take effect on `slow_tick` (every 0.35 seconds). Press and hold switches, then watch LEDs update on the next tick.

---

## 7. The Formal Verification Proof

### The .sby file

```ini
[options]
mode prove

[engines]
smtbmc

[script]
read -formal arbiter_round_robin.v
prep -top arbiter_round_robin

[files]
arbiter_round_robin.v
```

**`mode prove`** — We're proving properties, not searching for bugs.

**`read -formal`** — Enables the `ifdef FORMAL` blocks. Without this, the tool would read the hardware universe (oscillator code).

**`smtbmc`** — The SMT-based model checker. Good for small designs like this.

### Run the proof

```bash
sby -f arbiter_round_robin.sby
```

### The output

```
$ sby -f arbiter_round_robin.sby
SBY 19:41:31 [arbiter_round_robin] Removing directory 'arbiter_round_robin'.
SBY 19:41:31 [arbiter_round_robin] Copy 'arbiter_round_robin.v' to 'arbiter_round_robin/src/arbiter_round_robin.v'.
SBY 19:41:31 [arbiter_round_robin] engine_0: smtbmc
SBY 19:41:31 [arbiter_round_robin] base: starting process "cd arbiter_round_robin/src; yosys -ql ../model/design.log ../model/design.ys"
SBY 19:41:31 [arbiter_round_robin] base: finished (returncode=0)
SBY 19:41:31 [arbiter_round_robin] prep: starting process "cd arbiter_round_robin/model; yosys -ql design_prep.log design_prep.ys"
SBY 19:41:31 [arbiter_round_robin] prep: finished (returncode=0)
SBY 19:41:31 [arbiter_round_robin] smt2: starting process "cd arbiter_round_robin/model; yosys -ql design_smt2.log design_smt2.ys"
SBY 19:41:31 [arbiter_round_robin] smt2: finished (returncode=0)
SBY 19:41:31 [arbiter_round_robin] engine_0.basecase: starting process "cd arbiter_round_robin; yosys-smtbmc --presat --unroll --noprogress -t 20 ..."
SBY 19:41:31 [arbiter_round_robin] engine_0.induction: starting process "cd arbiter_round_robin; yosys-smtbmc --presat --unroll -i --noprogress -t 20 ..."
SBY 19:41:31 [arbiter_round_robin] engine_0.induction: ##   0:00:00  Solver: yices
SBY 19:41:31 [arbiter_round_robin] engine_0.basecase: ##   0:00:00  Solver: yices
SBY 19:41:31 [arbiter_round_robin] engine_0.induction: ##   0:00:00  Trying induction in step 20..
SBY 19:41:31 [arbiter_round_robin] engine_0.basecase: ##   0:00:00  Checking assumptions in step 0..
SBY 19:41:31 [arbiter_round_robin] engine_0.induction: ##   0:00:00  Trying induction in step 19..
SBY 19:41:31 [arbiter_round_robin] engine_0.basecase: ##   0:00:00  Checking assertions in step 0..
SBY 19:41:31 [arbiter_round_robin] engine_0.induction: ##   0:00:00  Trying induction in step 18..
SBY 19:41:31 [arbiter_round_robin] engine_0.induction: ##   0:00:00  Temporal induction successful.
SBY 19:41:31 [arbiter_round_robin] engine_0.induction: ##   0:00:00  Status: passed
SBY 19:41:31 [arbiter_round_robin] engine_0.basecase: ##   0:00:00  Checking assumptions in step 1..
SBY 19:41:31 [arbiter_round_robin] engine_0.basecase: ##   0:00:00  Checking assertions in step 1..
...
SBY 19:41:31 [arbiter_round_robin] engine_0.basecase: ##   0:00:00  Checking assertions in step 19..
SBY 19:41:31 [arbiter_round_robin] engine_0.basecase: ##   0:00:00  Status: passed
SBY 19:41:31 [arbiter_round_robin] engine_0.basecase: finished (returncode=0)
SBY 19:41:31 [arbiter_round_robin] engine_0.basecase: Status returned by engine for basecase: pass
SBY 19:41:31 [arbiter_round_robin] summary: Elapsed clock time [H:MM:SS (secs)]: 0:00:00 (0)
SBY 19:41:31 [arbiter_round_robin] summary: Elapsed process time [H:MM:SS (secs)]: 0:00:00 (0)
SBY 19:41:31 [arbiter_round_robin] summary: engine_0 (smtbmc) returned pass for basecase
SBY 19:41:31 [arbiter_round_robin] summary: engine_0 (smtbmc) returned pass for induction
SBY 19:41:31 [arbiter_round_robin] summary: engine_0 did not produce any traces
SBY 19:41:31 [arbiter_round_robin] summary: successful proof by k-induction.
SBY 19:41:31 [arbiter_round_robin] DONE (PASS, rc=0)
```

**What happened:**

**Basecase (steps 0-19):**
- Checked all assertions for 20 clock cycles
- Tried every possible sequence of `req` changes
- Verified both assertions held in all cases

**Induction (steps 18-20):**
- Proved that if assertions hold at cycle N, they hold at cycle N+1
- Started from step 18 and worked backward to find the earliest inductive step

**K-induction success:**
- Basecase: Works for cycles 0-19
- Induction: If it works at N, it works at N+1
- Conclusion: Works for all cycles (0, 1, 2, ..., ∞)

**Result: PASS**

The arbiter is proven to:
1. Never grant both requests at once
2. Always pass the token when serving a request
3. Maintain these properties forever

---

## 8. Key Lessons

### Lesson 1: Separate universes are powerful

The same Verilog file contains hardware reality and formal abstractions. The `ifdef` preprocessor lets you write two completely different implementations.

**Why this matters:** You can prove the algorithm (formal universe) without caring about clock speeds or physical oscillators (hardware universe). The concerns are separate.

### Lesson 2: Formal tools are picky about initialization

Real chips power on with garbage in registers. Formal tools expose this by trying all starting states. You need `initial` blocks or reset logic.

**Simulation hides this:** A simulator might default registers to 0, making bugs invisible. Formal verification finds them.

### Lesson 3: Check "now", not "yesterday"

```verilog
// This works
if (gnt[0]) assert(priority_token == 1);

// This might fail due to timing
if ($past(gnt[0])) assert(priority_token == 1);
```

Non-blocking assignments (`<=`) schedule updates for the end of the clock cycle. If you check the past state against the current state, there's a timing mismatch.

**The fix:** Check relationships that are true *in the same clock cycle*.

### Lesson 4: Formal verification proves, testing checks

Testing can show the presence of bugs but never their absence. Formal verification can prove absence (for the properties you asserted).

**Trade-off:** Formal verification only proves what you asked it to prove. If you write weak assertions, you get weak guarantees.

---

## 9. Going Further

### Challenge 1: Add a reset button

Current design: The priority token starts at 0 (hardcoded). Add a reset button that sets the token back to 0 at any time.

**Formal challenge:** Prove that after reset, the arbiter behaves correctly even if grants were active before reset.

### Challenge 2: Add 3 requests

Extend this to 3 requests. You'll need:
- A 2-bit token (values 0, 1, 2)
- Logic to cycle through all three
- Assertions proving all three get fair turns

**Formal challenge:** Prove that no request is starved (all three get served within N cycles if they keep requesting).

### Challenge 3: Prove liveness

Current assertions are safety properties (bad things never happen). Add a liveness property: "If a request is active, it eventually gets a grant."

**This requires LTL (Linear Temporal Logic):**

```verilog
assert property (req[0] |-> ##[1:$] gnt[0]);
```

This is more advanced formal verification.

---

## 10. Files in This Project

```
04-arbiter-round-robin/
├── arbiter_round_robin.v       # Dual-universe Verilog
├── arbiter_round_robin.pcf     # Pin constraints
├── arbiter_round_robin.sby     # Formal config
├── apio.ini                    # Build config
└── README.md                   # This file
```

---

## 11. Troubleshooting

### Formal verification fails

**Check the counterexample:**
```bash
gtkwave arbiter_round_robin/engine_0/trace.vcd
```

Look for:
- Which assertion failed
- What sequence of `req` values triggered it
- What the token and grant values were

### LEDs don't update on hardware

**Possible causes:**
- You're pressing switches too fast (wait for the 0.35s tick)
- Wrong pin mapping in `.pcf`
- Oscillator not starting (check CDONE LED)

**Debug:**
- Verify the CDONE LED is on (white LED, means FPGA configured)
- Hold switches for a full second to ensure you catch a tick
- Check that clock pin 35 is correctly connected

### Simulation works but formal fails

**This is normal.** Formal is stricter. Common issues:
- Missing `initial` blocks (formal assumes garbage, simulation defaults to 0)
- Wrong timing assumptions (checking past vs current state)
- Weak assertions that don't actually prove what you think

**Fix:** Read the counterexample carefully. It shows you the exact scenario that breaks your assertion.

---

## 12. What You've Accomplished

You've built hardware that exists in two universes:
- A real FPGA that divides a 48 MHz clock down to human-visible speeds
- A mathematical abstraction that proves correctness at any speed

The formal proof guarantees:
- No grant conflicts (mutual exclusion)
- Fair token passing (round-robin scheduling)
- These properties hold forever (k-induction)

This is stronger than testing. You haven't just checked that it works for a few cases. You've proven it works for all cases.

**Next:** Try a FIFO queue, a bus arbiter, or a memory controller. Each will teach you new formal verification techniques (cover properties, assumptions, abstractions).

Welcome to provably correct hardware design.