# Double-Buffered, Reorder FIFO

## The Problem

A packet of data is made up of a parameterized (default, 16) number of words.  Using a valid/rdy-type interface (both
the test bench and the DUT may initiate stall cycles), a packet enters the DUT through interface 1 with its data
words out of order.  The DUT reorders the data words for the given packet and makes them available through interface 2,
which also uses a valid/rdy-type interface.

Each data word entering the DUT through interface 1 is accompanied by its offset within the packet (for a 16-word packet,
the offset values range from 0 to 15).  When the packet exits the DUT through interface 2, there is no offset information
since the packet words are in proper order.

## The Solution

A double-buffered approach allows good throughput.  Each of the two buffers is essentially a FIFO except the *push* side
of the FIFO places each data word into memory based on the accompanying offset.  The FIFO becomes available for
reading by interface 2 once all the words for the data packet have been received.

## The Test Bench

A simple System Verilog test bench includes transactors for each of the DUT interfaces as well as a high-level packet
generator and a score board.  These class objects are tied together in an SV program along with an SV interface with
an internal clocking block.  The flow control signals on each interface (**vld** on interface 1 and **rdy** on interface 2) may
randomly assert and de-assert.

Cadence simulator on EDA Playground and Xilinx Vivado simulator were both used to verify this design.

###### Note

A small tech company asked me to write the code for this problem on a white board during an interview.  Seriously.  A block
diagram and an architectural approach seem more appropriate to a white board.  I started with a cut-through approach,
which I believe also valid if one is concerned about latency as well as throughput.

