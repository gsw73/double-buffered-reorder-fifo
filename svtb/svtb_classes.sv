package dbrf_sim_pkg;
    timeunit 1ns;
    timeprecision 100ps;

// ============================================================================

    class RandcRange;

        randc bit [7:0] value;
        int max_value;

        function new (int max_value=10);
            this.max_value = max_value;
        endfunction

        constraint c_max_value{value < max_value;}

    endclass : RandcRange

// ============================================================================

    class DUTdata#(parameter DATA_WIDTH=16, OFFSET_WIDTH=10);

        rand bit [DATA_WIDTH-1:0] data_content;
        bit [OFFSET_WIDTH-1:0] data_offset;
        bit sof;
        bit eof;

    endclass : DUTdata

// ==========================================================================

    class UnOrdDataAgent#(parameter DW=32, AW=10);

        localparam NUM_FULL_PKTS=4;

        mailbox mbxSB;
        mailbox mbxIF1;
        DUTdata d;
        RandcRange rr = new (1 << AW);
        int num_elements = NUM_FULL_PKTS*(1 << AW);

        function new (mailbox mbxSB, mailbox mbxIF1);
            this.mbxSB = mbxSB;
            this.mbxIF1 = mbxIF1;
        endfunction : new

        task run();
            bit [AW-1:0] cnt;
            DUTdata#(.DATA_WIDTH(DW), .OFFSET_WIDTH(AW)) data_element;
            cnt = '0;

            repeat (num_elements)
                begin
                    data_element = new;
                    assert (data_element.randomize());
                    assert (rr.randomize());
                    data_element.sof = cnt == 0 ? 1'b1:1'b0;
                    data_element.eof = cnt == (1 << AW)-1 ? 1'b1:1'b0;
                    data_element.data_offset = rr.value[AW-1:0];
                    $display("sof=%b, eof=%b, os=%d, d=%h", data_element.sof, data_element.eof, data_element.data_offset, data_element.data_content);

                    mbxSB.put(data_element);
                    mbxIF1.put(data_element);
                    cnt++;
                end
        endtask : run

    endclass : UnOrdDataAgent

// ==========================================================================

    class IF1xactor#(parameter DW=32, AW=10);

        mailbox mbxIF1;
        virtual reorder_if#(.DW(DW), .AW(AW)).TB sig_h;

        function new( mailbox mbxIF1, virtual reorder_if#(.DW(DW), .AW(AW)).TB s );
            this.mbxIF1 = mbxIF1;
            sig_h = s;
        endfunction

        task run();
            DUTdata#(.DATA_WIDTH(DW), .OFFSET_WIDTH(AW)) data_element;

            forever begin
                mbxIF1.get(data_element);
                repeat($urandom() & 3) @(sig_h.cb);

                sig_h.cb.if1_dut_vld <= 1'b1;
                sig_h.cb.if1_dut_data <= data_element.data_content;
                sig_h.cb.if1_dut_offset <= data_element.data_offset;

                @(sig_h.cb);
                wait (sig_h.cb.dut_if1_rdy);
                sig_h.cb.if1_dut_vld <= 1'b0;
                sig_h.cb.if1_dut_data <= '0;
                sig_h.cb.if1_dut_offset <= '0;
            end

        endtask : run

    endclass : IF1xactor

// ==========================================================================

    class IF2xactor#(parameter DW=32, AW=10);

        mailbox mbxIF2;
        virtual reorder_if #(.DW(DW), .AW(AW) ).TB sig_h;
        bit [DW-1:0] data_word;

        function new( mailbox mbxIF2, virtual reorder_if#(.DW(DW), .AW(AW)).TB s );
            this.mbxIF2 = mbxIF2;
            sig_h = s;
        endfunction

        task run();
            fork
                forever begin
                    repeat($urandom & 3) @(sig_h.cb);
                    sig_h.cb.if2_dut_rdy <= 1'b1;
                    repeat($urandom & 3) @(sig_h.cb);
                    sig_h.cb.if2_dut_rdy <= 1'b0;
                end
            join_none

            forever begin
                wait (sig_h.cb.dut_if2_vld && sig_h.cb.if2_dut_rdy);
                data_word = sig_h.cb.dut_if2_data;
                mbxIF2.put(data_word);
                @(sig_h.cb);
            end

        endtask : run

    endclass : IF2xactor

// ==========================================================================

    class ScoreBoard#(parameter DW=32, AW=10);

        mailbox mbxSB;
        mailbox mbxIF2;

        function new (mailbox mbxSB, mailbox mbxIF2);
            this.mbxSB = mbxSB;
            this.mbxIF2 = mbxIF2;
        endfunction : new

        task run();
            DUTdata#(.DATA_WIDTH(DW), .OFFSET_WIDTH(AW)) d_golden [2**AW];
            bit [DW-1:0] d_dut [2**AW];
            DUTdata#(.DATA_WIDTH(DW), .OFFSET_WIDTH(AW)) data_element;
            bit [DW-1:0] data_content, data_golden, data_dut;
            int pkt_num = 0;
            int error_found = 0;
            int data_el;

            forever begin
                // collect full packet from SB
                for (int i = 0; i < 2 ** AW; i++) begin
                    mbxSB.get(data_element);
                    d_golden[data_element.data_offset] = data_element;
                end

                // collect full packet from DUT
                for (int i = 0; i < 2 ** AW; i++) begin
                    mbxIF2.get(data_content);
                    d_dut[i] = data_content;
                end

                // compare
                for (int i = 0; i < 2 ** AW; i++) begin
                    $display("PKT%02d, EL%04d:  DGO=%h, DUT=%h", pkt_num, i, d_golden[i].data_content, d_dut[i]);
                    if (!error_found) begin
                        if (d_golden[i].data_content != d_dut[i]) begin
                            error_found = 1;
                            data_golden = d_golden[i].data_content;
                            data_dut = d_dut[i];
                            data_el = i;
                        end
                    end
                end

                if (error_found) begin
                    $display("ERROR!  PKT%02d, EL%04d: DGO=%h, DUT=%h", pkt_num, data_el, data_golden, data_dut);
                    $finish();
                end
                pkt_num++;
            end

        endtask : run

    endclass : ScoreBoard

// =======================================================================

    class SVTBEnv#(parameter DW=41, parameter AW=10);

        IF1xactor#(.DW(DW), .AW(AW)) if1x;
        IF2xactor#(.DW(DW), .AW(AW)) if2x;
        UnOrdDataAgent#(.DW(DW), .AW(AW)) unordAgent;
        ScoreBoard#(.DW(DW), .AW(AW)) sbA;

        mailbox mbxSB;
        mailbox mbxIF2;
        mailbox mbxIF1;
        virtual reorder_if#(.DW(DW), .AW(AW)).TB sig_h;

        function new (virtual reorder_if#(.DW(DW), .AW(AW)).TB s);
            mbxSB = new ();
            mbxIF2 = new ();
            mbxIF1 = new ();

            sig_h = s;

            unordAgent = new (mbxSB, mbxIF1);
            sbA = new (mbxSB, mbxIF2);
            if1x = new (mbxIF1, s);
            if2x = new (mbxIF2, s);
        endfunction

        task run();
            fork
                unordAgent.run();
                sbA.run();
                if1x.run();
                if2x.run();
            join_none
        endtask

    endclass : SVTBEnv
endpackage : dbrf_sim_pkg
