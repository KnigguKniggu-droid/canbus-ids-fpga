// can_ids.v — timing-based CAN intrusion detector in synthesizable Verilog.
//
// A hardware version of the Python timing IDS: it watches CAN frames arriving on the bus
// and raises an alert when a frame violates the learned timing model. This is what would
// sit on an embedded automotive gateway (an FPGA between the CAN transceiver and the ECUs),
// flagging attacks at line rate.
//
// Detection (one cycle of latency):
//   UNKNOWN_ID : an arbitration ID not in the configured baseline table  (flooding/injection)
//   TIMING     : a known ID arriving faster than its minimum period      (spoof/injection)
//
// The baseline table (known IDs + minimum inter-arrival period in clock cycles) is loaded at
// reset — on a real gateway it would be learned during a clean window and written by firmware.

module can_ids #(
    parameter N_IDS    = 4,
    parameter ID_WIDTH = 11,
    parameter TS_WIDTH = 32
)(
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 frame_valid,     // strobe: a CAN frame arrived this cycle
    input  wire [ID_WIDTH-1:0]  arb_id,          // its 11-bit arbitration ID
    output reg                  timing_alert,
    output reg                  unknown_alert,
    output reg  [ID_WIDTH-1:0]  alert_id
);
    // --- baseline model (learned during a clean window in a real deployment) ---
    reg [ID_WIDTH-1:0] known_id   [0:N_IDS-1];
    reg [TS_WIDTH-1:0] min_period [0:N_IDS-1];
    reg [TS_WIDTH-1:0] last_seen  [0:N_IDS-1];
    reg                seen       [0:N_IDS-1];
    reg [TS_WIDTH-1:0] cycle;                     // free-running timestamp

    integer i;
    reg     found;
    integer idx;

    initial begin
        known_id[0] = 11'h0C0; min_period[0] = 80;   // engine RPM  (fast)
        known_id[1] = 11'h0D0; min_period[1] = 80;   // wheel speed
        known_id[2] = 11'h110; min_period[2] = 160;  // brake
        known_id[3] = 11'h320; min_period[3] = 800;  // body control (slow)
        for (i = 0; i < N_IDS; i = i + 1) begin
            last_seen[i] = 0;
            seen[i]      = 1'b0;
        end
        cycle = 0;
    end

    always @(posedge clk) begin
        if (rst) begin
            cycle         <= 0;
            timing_alert  <= 1'b0;
            unknown_alert <= 1'b0;
            alert_id      <= 0;
            for (i = 0; i < N_IDS; i = i + 1)
                seen[i] <= 1'b0;
        end else begin
            cycle         <= cycle + 1;
            timing_alert  <= 1'b0;
            unknown_alert <= 1'b0;

            if (frame_valid) begin
                found = 1'b0;
                idx   = 0;
                for (i = 0; i < N_IDS; i = i + 1)
                    if (known_id[i] == arb_id) begin
                        found = 1'b1;
                        idx   = i;
                    end

                if (!found) begin
                    unknown_alert <= 1'b1;
                    alert_id      <= arb_id;
                end else begin
                    // flag only if we've seen this ID before AND it's too soon
                    if (seen[idx] && ((cycle - last_seen[idx]) < min_period[idx])) begin
                        timing_alert <= 1'b1;
                        alert_id     <= arb_id;
                    end
                    last_seen[idx] <= cycle;
                    seen[idx]      <= 1'b1;
                end
            end
        end
    end
endmodule
