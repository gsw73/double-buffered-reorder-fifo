module wr_fsm
    (
        input logic clk,
        input logic rst_n,

        input logic mem0_lock,
        input logic mem1_lock,
        input logic mem0_full,
        input logic mem1_full,

        output logic mem0wr_st_decode,
        output logic mem1wr_st_decode
    );

    // ======================================================================
    // Declarations & Parameters

    enum {MEM0WR_BIT = 0, MEM1WR_BIT = 1, WRWAIT_BIT = 2} wr_state_bits_t;
    typedef enum logic [2:0] {MEM0WR = 3'b001,
                              MEM1WR = 3'b010,
                              WRWAIT = 3'b100} wr_state_t;
    wr_state_t wr_state;

    // ======================================================================
    // Combinational Logic
    assign mem0wr_st_decode = wr_state[MEM0WR_BIT];
    assign mem1wr_st_decode = wr_state[MEM1WR_BIT];
    assign wrwait_st_decode = wr_state[WRWAIT_BIT];

    // ======================================================================
    // State Machines

    always_ff @( posedge clk )
        if ( !rst_n )
            wr_state <= MEM0WR;

        else
            case (1'b1)
                wr_state[MEM0WR_BIT]:
                    if ( mem0_full && !mem1_lock )
                        wr_state <= MEM1WR;

                    else if ( mem0_full )
                        wr_state <= WRWAIT;

                wr_state[MEM1WR_BIT]:
                    if ( mem1_full && !mem0_lock )
                        wr_state <= MEM0WR;

                    else if ( mem1_full )
                        wr_state <= WRWAIT;

                wr_state[WRWAIT_BIT]:
                    if ( !mem0_lock )
                        wr_state <= MEM0WR;

                    else if ( !mem1_lock )
                        wr_state <= MEM1WR;

                default:  // unreachable
                    wr_state <= MEM0WR;

            endcase

endmodule : wr_fsm
