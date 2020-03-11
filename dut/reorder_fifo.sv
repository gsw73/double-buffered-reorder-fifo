module reorder_fifo
    #(
        parameter DW = 18,
        parameter AW = 7
    )
    (
        input logic clk,
        input logic rst_n,

        input logic push,
        input logic [DW - 1:0] data_in,
        input logic [AW - 1:0] data_offset,
        output logic full,

        input logic pop,
        output logic vld,
        output logic [DW - 1:0] data_out,
        output logic empty
    );

    // ======================================================================
    // Declarations & Parameters
    localparam CW = AW + 1;
    localparam DEPTH = AW**2;

    logic wen;
    logic [DW - 1:0] wr_data;
    logic [AW - 1:0] wr_addr;
    logic [AW - 1:0] rd_addr_c;
    logic [AW - 1:0] rd_addr_q;
    logic [AW - 1:0] rd_addr;
    logic ren;

    // ======================================================================
    // Combinational Logic

    // there needs to be an incrementor on the read address
    assign rd_addr_c = rd_addr_q + 1;

    // the read address into memory is a muxed version of the
    // combinational, incremented address and the registered address --
    // this allows "reading ahead" when the FIFO is popped to cover
    // the one-clock latency
    assign rd_addr = ren ? rd_addr_c : rd_addr_q;

    // by definition, reorder won't do this because it's tracking empty
    assign ren = pop && !empty;

    // ======================================================================
    // Registered Logic

    // Register:  wen
    //
    // All data is registered before being pushed into memory.
    always_ff @( posedge clk )
        if ( !rst_n )
            wen <= 1'b0;

        else
            wen <= push;

    // Register:  wr_data
    always_ff @( posedge clk )
        if ( !rst_n )
            wr_data <= '0;

        else
            wr_data <= data_in;

    // Register:  wr_addr
    //
    // Unlike a traditional FIFO, the entity passing in the data specifies the
    // offset, or address, at which the data should be written.
    always_ff @( posedge clk )
        if ( !rst_n )
            wr_addr <= '0;

        else
            wr_addr <= data_offset;

    // Register:  rd_addr_q
    //
    // A one-cycle read latency means we use a combinational address to read ahead
    // when data is popped from reorder FIFO.
    always_ff @( posedge clk )
        if ( !rst_n )
            rd_addr_q <= '0;

        else if ( ren )
            rd_addr_q <= rd_addr_c;

    // Register:  cnt
    //
    // Interface needs to be able to de-assert rdy with no latency when it sees
    // the reorder FIFO will fill up.  So this count must be based off earliest
    // version of wen.  There's no worry about FIFO going not-empty when reading
    // starts--and data actually not quite written into memory yet--since reading
    // cannot start until FIFO is full.  A typical FIFO would take into account
    // reads and writes happening on same clock cycle.
    always_ff @( posedge clk )
        if ( !rst_n )
            cnt <= '0;

        else if ( push )
            cnt <= cnt + CW'('d1);

        else if ( ren )
            cnt <= cnt - CW'('d1);

    // Register:  full
    //
    // FIFO writes and reads cannot happen on the same clock cycle.
    always_ff @( posedge clk )
        if ( !rst_n )
            full <= 1'b0;

        else if ( cnt == CW'(DEPTH - 1) && push || cnt == CW'(DEPTH) && !ren )
            full <= 1'b1;

        else
            full <= 1'b0;

    // Register:  empty
    //
    // FIFO writes and reads cannot happen on the same clock cycle.
    always_ff @( posedge clk )
        if ( !rst_n )
            empty <= 1'b0;

        else if ( cnt == CW'('d0) && !push || cnt == CW'('d1) && ren )
            empty <= 1'b1;

        else
            empty <= 1'b0;

    // ======================================================================
    // Module Instantiations

    // Module:  the two-port, one-clock read latency memory
    ram2p #( .DW(DW), .AW(AW) ) u_ram2p (.*);

endmodule : reorder_fifo
