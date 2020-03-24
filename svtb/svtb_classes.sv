class DUTdata #( parameter DATA_WIDTH = 16, OFFSET_WIDTH = 10 );

    rand bit [DATA_WIDTH - 1:0] data_content;
    rand bit [OFFSET_WIDTH - 1:0] data_offset; // FIXME
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

    function run();

    endfunction : run

endclass : IF1xactor

// ==========================================================================

class IF2xactor #( parameter DW = 32, AW = 10 );

    mailbox mbxIF2;
    virtual reorder_if #(.DW(DW), .AW(AW) ).TB sig_h;

    function new( mailbox mbxIF1, virtual reorder_if#(.DW(DW), .AW(AW)).TB s );
        this.mbxIF1 = mbxIF1;
        sig_h = s;
    endfunction

    function run();

    endfunction : run

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

class SVTBEnv #( parameter DW = 41, AW = 10 );

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

endclass : SBTBEnv
