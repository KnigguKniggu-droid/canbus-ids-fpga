// can_ids_tb.v — self-checking testbench for the hardware CAN IDS.
// Feeds normal periodic traffic (no alerts), then injects a too-fast frame on a known ID
// (TIMING) and a flood of an unknown ID (UNKNOWN_ID), and checks the alerts fire.
`timescale 1ns/1ps

module can_ids_tb;
    reg         clk = 0;
    reg         rst = 1;
    reg         frame_valid = 0;
    reg  [10:0] arb_id = 0;
    wire        timing_alert, unknown_alert;
    wire [10:0] alert_id;

    integer timing_count = 0;
    integer unknown_count = 0;

    can_ids dut (
        .clk(clk), .rst(rst), .frame_valid(frame_valid), .arb_id(arb_id),
        .timing_alert(timing_alert), .unknown_alert(unknown_alert), .alert_id(alert_id)
    );

    always #5 clk = ~clk;   // 100 MHz

    always @(posedge clk) begin
        if (timing_alert) begin
            timing_count = timing_count + 1;
            $display("[%0t ns] TIMING alert  id=0x%03h", $time, alert_id);
        end
        if (unknown_alert) begin
            unknown_count = unknown_count + 1;
            $display("[%0t ns] UNKNOWN alert id=0x%03h", $time, alert_id);
        end
    end

    task send_frame(input [10:0] id);
        begin
            @(posedge clk); frame_valid <= 1; arb_id <= id;
            @(posedge clk); frame_valid <= 0;
        end
    endtask

    integer k;
    initial begin
        $dumpfile("can_ids.vcd");
        $dumpvars(0, can_ids_tb);
        @(posedge clk); rst <= 0;

        // --- NORMAL traffic: 0C0 every ~92 cycles (> min_period 80) -> no alerts ---
        for (k = 0; k < 5; k = k + 1) begin
            send_frame(11'h0C0);
            repeat (90) @(posedge clk);
        end
        $display("-- after normal traffic: timing=%0d unknown=%0d (expect 0/0)",
                 timing_count, unknown_count);

        // --- ATTACK 1: injection on known ID 0x0C0, only ~22 cycles apart (< 80) ---
        send_frame(11'h0C0);
        repeat (20) @(posedge clk);
        send_frame(11'h0C0);
        repeat (10) @(posedge clk);

        // --- ATTACK 2: DoS flood with unknown ID 0x000 ---
        for (k = 0; k < 3; k = k + 1) begin
            send_frame(11'h000);
            repeat (5) @(posedge clk);
        end
        repeat (20) @(posedge clk);

        $display("-- final: timing=%0d unknown=%0d", timing_count, unknown_count);
        if (timing_count >= 1 && unknown_count >= 3)
            $display("RESULT: PASS  (detected injection + unknown-ID flood, no false alarms)");
        else
            $display("RESULT: FAIL");
        $finish;
    end
endmodule
