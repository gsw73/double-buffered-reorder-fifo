// ==========================================================================
// Interface

interface reorder_if
    #(
        parameter DW = 8,
        parameter AW = 5
    )
    (
        input bit clk
    );
    timeunit 1ns;
    timeprecision 100ps;

    logic rst_n = 0;

    // interface 1:  unordered data into DUT
    logic [DW - 1:0] if1_dut_data = DW'('d0);
    logic [AW - 1:0] if1_dut_offset = AW'('d0);
    logic if1_dut_vld = 1'b0;
    logic dut_if1_rdy;

    // interface 2:  ordered data out of DUT
    logic [DW - 1:0] dut_if2_data;
    logic dut_if2_vld;
    logic if2_dut_rdy = 0;

    default clocking cb @(posedge clk);
        output #1 rst_n;
        output #1 if1_dut_data, if1_dut_offset, if1_dut_vld;
        input dut_if1_rdy;
        inout if2_dut_rdy;
        input dut_if2_data, dut_if2_vld;
    endclocking : cb

    modport TB (clocking cb);

endinterface : reorder_if

// ==========================================================================
// Test Bench Top

module svtb;
    timeunit 1ns;
    timeprecision 100ps;
    parameter DATA_WIDTH = 16;
    parameter OFFSET_WIDTH = 4;

    logic clk;

    // instantiate the interface
    reorder_if #( .DW( DATA_WIDTH ), .AW( OFFSET_WIDTH ) ) u_reorder_if( clk );

    // instantiate the main test
    main_prg #(.DW( DATA_WIDTH ), .AW( OFFSET_WIDTH) ) u_main_prg( .sig_h(u_reorder_if.TB) );

    initial begin
        $dumpfile( "dump.vcd" );
        $dumpvars( 0 );
    end

    initial
    begin
        $timeformat( -9, 1, "ns", 8 );

        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // connect DUT
    reorder_top #(.DW(DATA_WIDTH), .AW(OFFSET_WIDTH)) u_reorder_top
                                                      (
                                                          .clk( clk ),
                                                          .rst_n(u_reorder_if.rst_n),
                                                          .if1_dut_data(u_reorder_if.if1_dut_data),
                                                          .if1_dut_offset(u_reorder_if.if1_dut_offset),
                                                          .if1_dut_vld(u_reorder_if.if1_dut_vld),
                                                          .dut_if1_rdy(u_reorder_if.dut_if1_rdy),
                                                          .dut_if2_data(u_reorder_if.dut_if2_data),
                                                          .dut_if2_vld(u_reorder_if.dut_if2_vld),
                                                          .if2_dut_rdy(u_reorder_if.if2_dut_rdy)
                                                      );

endmodule : svtb

// ==========================================================================
// Main Program

program automatic main_prg
    import dbrf_sim_pkg::*;
    #( parameter DW = 12, AW = 10 )( reorder_if.TB sig_h );

    SVTBEnv#(.DW(DW), .AW(AW)) env;

    initial
    begin
        env = new( sig_h );

        sig_h.cb.rst_n <= 1'b0;
        #50 sig_h.cb.rst_n <= 1'b1;
        repeat( 10 ) @(sig_h.cb);

        env.run();

        repeat( 500 ) @(sig_h.cb);
    end
endprogram : main_prg
