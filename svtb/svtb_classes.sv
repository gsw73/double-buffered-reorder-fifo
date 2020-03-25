class DUTdata #( parameter DATA_WIDTH = 16, OFFSET_WIDTH = 10 );

    rand bit [DATA_WIDTH - 1:0] data_content;
    randc bit [OFFSET_WIDTH - 1:0] data_offset;
    bit sof;
    bit eof;

endclass : DUTdata

// ==========================================================================

class UnOrdDataAgent #( parameter DW = 32, AW = 10 );

    mailbox mbxSB;
    mailbox mbxIF1;
    DUTdata d;

    function new ( mailbox mbxSB, mailbox mbxIF1 );
        this.mbxSB = mbxSB;
        this.mbxIF1 = mbxIF1;
    endfunction : new

    task run();
        bit [AW - 1:0] cnt;
        DUTdata#(.DATA_WIDTH(DW),.OFFSET_WIDTH(AW)) data_element;
        cnt = '0;

        repeat ( 4096 )
        begin
            data_element = new;
            assert (data_element.randomize());
            data_element.sof = cnt == 0 ? 1'b1 : 1'b0;
            data_element.eof = cnt == (1<<AW) - 1 ? 1'b1 : 1'b0;

            mbxSB.put(data_element);
            mbxIF1.put(data_element);
            cnt++;
        end
    endtask : run

endclass : UnOrdDataAgent

// ==========================================================================

class IF1xactor #( parameter DW = 32, AW = 10 );

    mailbox mbxIF1;
    virtual reorder_if#(.DW(DW), .AW(AW) ).TB sig_h;

    function new( mailbox mbxIF1, virtual reorder_if#(.DW(DW), .AW(AW)).TB s );
        this.mbxIF1 = mbxIF1;
        sig_h = s;
    endfunction

    task run();
        DUTdata#(.DATA_WIDTH(DW), .OFFSET_WIDTH(AW)) data_element;

        forever begin
            mbxIF1.get(data_element);

            sig_h.cb.if1_dut_vld <= 1'b1;
            sig_h.cb.if1_dut_data <= data_element.data_content;
            sig_h.cb.if1_dut_offset <= data_element.data_offset;

            wait( sig_h.cb.dut_if1_rdy ) ;
            @( sig_h.cb )
            sig_h.cb.if1_dut_vld <= 1'b0;
        end

    endtask : run

endclass : IF1xactor

// ==========================================================================

class IF2xactor #( parameter DW = 32, AW = 10 );

    mailbox mbxIF2;
    virtual reorder_if #(.DW(DW), .AW(AW) ).TB sig_h;
    bit [DW - 1:0] data_word;

    function new( mailbox mbxIF2, virtual reorder_if#(.DW(DW), .AW(AW)).TB s );
        this.mbxIF2 = mbxIF2;
        sig_h = s;
    endfunction

    task run();
        forever begin
            sig_h.cb.if2_dut_rdy <= 1'b1;
            wait ( sig_h.cb.dut_if2_vld && sig_h.cb.if2_dut_rdy ) ;
            data_word = sig_h.cb.dut_if2_data;
            mbxIF2.put(data_word);
            @( sig_h.cb );
        end

    endtask : run

endclass : IF2xactor

// ==========================================================================

class ScoreBoard #( parameter DW = 32, AW = 10 );

    mailbox mbxSB;
    mailbox mbxIF2;
    DUTdata d;

    function new ( mailbox mbxSB, mailbox mbxIF2 );
        this.mbxSB = mbxSB;
        this.mbxIF2 = mbxIF2;
    endfunction : new

    task run();

    endtask : run

endclass : ScoreBoard

// =======================================================================

class SVTBEnv #( parameter DW = 41, parameter AW = 10 );

    IF1xactor#(.DW(DW), .AW(AW)) if1x;
    IF2xactor#(.DW(DW), .AW(AW)) if2x;
    UnOrdDataAgent#(.DW(DW), .AW(AW)) unordAgent;
    ScoreBoard#(.DW(DW), .AW(AW)) sbA;

    mailbox mbxSB;
    mailbox mbxIF2;
    mailbox mbxIF1;
    virtual reorder_if#(.DW(DW), .AW(AW)).TB sig_h;

    function new( virtual reorder_if#(.DW(DW), .AW(AW)).TB s );
        mbxSB = new();
        mbxIF2 = new();
        mbxIF1 = new();

        sig_h = s;

        unordAgent = new( mbxSB, mbxIF1 );
        sbA = new( mbxSB, mbxIF2 );
        if1x = new( mbxIF1, s );
        if2x = new( mbxIF2, s );
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
