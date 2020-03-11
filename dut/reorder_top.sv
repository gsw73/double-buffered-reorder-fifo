module reorder_top
    #(
        parameter DW = 32,
        parameter AW = 10
    )
    (
        input logic clk,
        input logic rst_n,

        // interface 1:  unordered data
        input logic [DW - 1:0] if1_dut_data,
        input logic [AW - 1:0] if1_dut_offset,
        input logic if1_dut_vld,
        output logic dut_if1_rdy,

        // interface 2:  ordered data
        output logic [DW - 1:0] dut_if2_data,
        output logic dut_if2_vld,
        input logic if2_dut_rdy
    );
    
    // ======================================================================
    // Declarations & Parameters
    logic mem0_full;
    logic mem1_full;
    logic mem0_empty;
    logic mem1_empty;

    logic if1_sample;

    logic push0;
    logic [DW - 1:0] data_in0;
    logic [AW - 1:0] data_offset0;

    logic push1;
    logic [DW - 1:0] data_in1;
    logic [AW - 1:0] data_offset1;

    logic pop0;
    logic pop1;

    logic mem0_lock;
    logic mem1_lock;

    logic mem0rd_st_decode;
    logic mem1rd_st_decode;
    logic mem0wr_st_decode;
    logic mem1wr_st_decode;

    // ======================================================================
    // Combinational Logic
    assign mem0_full = full0;
    assign mem1_full = full1;
    assign mem0_empty = empty0;
    assign mem1_empty = empty1;

    // data is sampled from interface 1 when dut is ready and data is valid
    assign if1_sample = if1_dut_vld && dut_if1_rdy;

    // dut is ready to accept data from interface 1 when either mem0 or mem1
    // are not locked i.e., in one of the memory write states
    assign dut_if1_rdy = mem0wr_state_decode || mem1wr_state_decode;

    // writes to mem0 active
    assign push0 = mem0wr_st_decode ? if1_sample : 1'b0;
    assign data_in0 = mem0wr_st_decode ? if1_dut_data : '0;
    assign data_offset0 = mem0wr_st_decode ? if1_dut_offset : '0;

    // writes to mem0 active
    assign push1 = mem1wr_st_decode ? if1_sample : 1'b0;
    assign data_in1 = mem1wr_st_decode ? if1_dut_data : '0;
    assign data_offset1 = mem1wr_st_decode ? if1_dut_offset : '0;

    // mux for interface 2 depends on rd fsm
    assign dut_if2_data = mem0rd_st_decode ? data_out0 : data_out1;
    assign dut_if2_vld = mem0rd_st_decode ? vld0 : vld1;

    // both memories always see same if2 ready as "pop"
    assign pop0 = if2_dut_rdy;
    assign pop1 = if2_dut_rdy;

    // ======================================================================
    // Registered Logic
    
    // a memory is "locked" when it has filled up and becomes ready for
    // reading i.e., it is locked from being written; the memory becomes
    // "unlocked" once it has emptied
    
    // Register:  mem0_lock
    always_ff @( posedge clk )
        if ( !rst_n )
            mem0_lock <= 1'b0;

        else if ( mem0wr_st_decode && mem0_full )
            mem0_lock <= 1'b1;
    
        else if ( mem0rd_st_decode && mmem0_empty )
            mem0_lock <= 1'b0;

    // Register:  mem1_lock
    always_ff @( posedge clk )
        if ( !rst_n )
            mem1_lock <= 1'b0;
    
        else if ( mem1wr_st_decode && mem1_full )
            mem1_lock <= 1'b1;
    
        else if ( mem1rd_st_decode && mmem1_empty )
            mem1_lock <= 1'b0;

    // ======================================================================
    // Module Instantiations

    // Module:  rd_fsm
    rd_fsm u_rd_fsm (.*);
    
    // Module:  wr_fsm
    wr_fsm u_rs_fsm (.*);

    // Module:  mem0
    reorder_fifo #( .DW(DW), .AW(AW) ) u_mem0
                                       (
                                           .clk,
                                           .rst_n,

                                           .push( push0 ),
                                           .data_in( data_in0 ),
                                           .data_offset( data_offset0 ),
                                           .full( full0 ),

                                           .pop( pop0 ),
                                           .vld( vld0 ),
                                           .data_out( data_out0 ),
                                           .emtpy( emtpy0 )
                                       );

    // Module:  mem1
    reorder_fifo #( .DW(DW), .AW(AW) ) u_mem1
                                       (
                                           .clk,
                                           .rst_n,

                                           .push( push1 ),
                                           .data_in( data_in1 ),
                                           .data_offset( data_offset1 ),
                                           .full( full1 ),

                                           .pop( pop1 ),
                                           .vld( vld1 ),
                                           .data_out( data_out1 ),
                                           .emtpy( emtpy1 )
                                       );

endmodule : reorder_top
