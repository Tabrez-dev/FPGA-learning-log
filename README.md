# FPGA-learning-log
Documenting my journey learning FPGA development with the Soan-Papdi board and iCEStudio.

I found the gates. They aren't in the top "Basic" menu like you'd expect; they're actually tucked away in the Collection Manager sidebar on the left. You have to dig into Collection manager > Default Collection > Logic > Sequential to find them.

The "Import Verilog" tool is also pretty buggy. The "OK" button often just freezes when you try to bring in a file. I am still trying to figure this out

Also, just a heads-up on the npm side of things. I had to use --legacy-peer-deps just to get the install to finish, and you have to run npm start from inside the icestudio folder specifically, or it'll throw errors.

> **Tip:** The RTL schematics below were generated using [TerosHDL](https://github.com/TerosTechnology/teroshdl), a VSCode extension for FPGA/ASIC design. It works with Yosys to visualize your Verilog/VHDL as interactive schematics.

<img width="910" height="661" alt="Screenshot from 2026-02-14 14-35-56" src="https://github.com/user-attachments/assets/ca33b56a-e7d1-4784-927f-da9ae8734034" />

## Projects

### 02-logic-gates: D Flip-Flop

My first dive into sequential logic. The DFF is the fundamental building block of state in digital design—it captures input on a clock edge and holds it until the next cycle. This schematic shows how a single bit of memory is built from basic gates.

<img width="787" height="353" alt="image" src="https://github.com/user-attachments/assets/47730a5c-3180-4785-afde-7646f5346357" />


---

### 03-arbiter-fixed: Priority Arbiter

When multiple masters compete for a shared resource, who wins? This fixed-priority arbiter ensures only one request is granted at a time, with higher-priority inputs always winning ties. Essential for bus contention management in SoC designs.

<img width="749" height="352" alt="image" src="https://github.com/user-attachments/assets/39a71a9d-2f09-4333-aa96-15136098a413" />

---

### 05-breathing-led: PWM & Triangle Wave Generator

A "breathing" LED that fades in and out smoothly no CPU, just pure hardware. Uses two counters (8-bit PWM carrier + 27-bit breath timer) and a clever MSB trick to generate a triangle wave. The comparator then converts this to PWM duty cycle. Zero software, 100% silicon.

<img width="723" height="552" alt="image" src="https://github.com/user-attachments/assets/d13be6e8-9a34-49c1-9ab9-7343e1147f04" />
