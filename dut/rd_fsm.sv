module rd_fsm
    (
        input logic clk,
        input logic rst_n,

        input logic mem0_lock,
        input logic mem1_lock,
        input logic mem0_empty,
        input logic mem1_empty,

        output logic mem0rd_st_decode,
        output logic mem1rd_st_decode
    );

    // ======================================================================
    // Declarations & Parameters

    enum {MEM0RD_BIT = 0, MEM1RD_BIT = 1, RDWAIT_BIT = 2} rd_state_bits_t;
    typedef enum logic [2:0] {MEM0RD = 3'b001,
                              MEM1RD = 3'b010,
                              RDWAIT = 3'b100} rd_state_t;
    rd_state_t rd_state;

    // ======================================================================
    // Combinational Logic
    assign mem0rd_st_decode = rd_state[MEM0RD_BIT];
    assign mem1rd_st_decode = rd_state[MEM1RD_BIT];
    assign rdwait_st_decode = rd_state[RDWAIT_BIT];

    // ======================================================================
    // State Machines

    always_ff @( posedge clk )
        if ( !rst_n )
            rd_state <= RDWAIT;

        else
            case (1'b1)
                rd_state[MEM0RD_BIT]:
                    if ( mem0_empty && mem1_lock )
                        rd_state <= MEM1RD;

                    else if ( mem0_empty )
                        rd_state <= RDWAIT;

                rd_state[MEM1RD_BIT]:
                    if ( mem1_empty && mem0_lock )
                        rd_state <= MEM0RD;

                    else if ( mem1_empty )
                        rd_state <= RDWAIT;

                rd_state[RDWAIT_BIT]:
                    if ( mem0_lock )
                        rd_state <= MEM0RD;

                    else if ( mem1_lock )
                        rd_state <= MEM1RD;

                default:  // unreachable
                    rd_state <= RDWAIT;
            endcase

endmodule : rd_fsm
