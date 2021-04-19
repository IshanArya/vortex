`include "VX_cache_config.vh"

module VX_cache_bypass #(
    // parameters

    // parameter CACHE_ID                      = 0,

    // Number of Word requests per cycle
    parameter NUM_REQS                      = 4,

    // Size of cache in bytes
    parameter CACHE_SIZE                    = 16384, 
    // Size of line inside a bank in bytes
    parameter CACHE_LINE_SIZE               = 64, 
    // Number of banks
    parameter NUM_BANKS                     = NUM_REQS,
    // // Number of ports per banks
    // parameter NUM_PORTS                     = 1,
    // // Size of a word in bytes
    // parameter WORD_SIZE                     = 4, 

    // // Core Request Queue Size
    // parameter CREQ_SIZE                     = 4, 
    // // Miss Reserv Queue Knob
    // parameter MSHR_SIZE                     = 8, 
    // // DRAM Response Queue Size
    // parameter DRSQ_SIZE                     = 4,
    // // DRAM Request Queue Size
    // parameter DREQ_SIZE                     = 4,

    // // Enable cache writeable
    // parameter WRITE_ENABLE                  = 1,

    // // core request tag size
    // parameter CORE_TAG_WIDTH                = $clog2(MSHR_SIZE),
    
    // // size of tag id in core request tag
    // parameter CORE_TAG_ID_BITS              = CORE_TAG_WIDTH,

    // dram request tag size
    parameter DRAM_TAG_WIDTH                = (32 - $clog2(CACHE_LINE_SIZE))

    // // bank offset from beginning of index range
    // parameter BANK_ADDR_OFFSET              = 0,

    // // in-order DRAN
    // parameter IN_ORDER_DRAM                 = 0

) (
    // inputs and outputs

    // flush_ctrl
    input wire  clk,
    input wire  reset,
    input wire  flush,

    input wire                             bypass_dram_req_rw,
    input wire                             bypass_dram_req_valid,
    input wire [CACHE_LINE_SIZE-1:0]       bypass_dram_req_byteen, 
    input wire [`DRAM_ADDR_WIDTH-1:0]      bypass_dram_req_addr,
    input wire [`CACHE_LINE_WIDTH-1:0]     bypass_dram_req_data,
    input wire [DRAM_TAG_WIDTH-1:0]        bypass_dram_req_tag,

    output wire                             dram_req_valid,
    output wire                             dram_req_rw,
    output wire [CACHE_LINE_SIZE-1:0]       dram_req_byteen,
    output wire [`DRAM_ADDR_WIDTH-1:0]      dram_req_addr,
    output wire [`CACHE_LINE_WIDTH-1:0]     dram_req_data,
    output wire [DRAM_TAG_WIDTH-1:0]        dram_req_tag

);
    // assigns here
    // example flush_ctrl
    reg flush_enable;
    reg [`LINE_SELECT_BITS-1:0] flush_ctr;

    assign dram_req_valid = bypass_dram_req_valid;
    assign dram_req_rw = bypass_dram_req_rw;
    assign dram_req_byteen = bypass_dram_req_byteen;
    assign dram_req_addr = bypass_dram_req_addr;
    assign dram_req_data = bypass_dram_req_data;
    assign dram_req_tag = bypass_dram_req_tag;

    always @(posedge clk) begin
        if (reset || flush) begin
            flush_enable <= 1;
            flush_ctr    <= 0;
        end else begin
            if (flush_enable) begin
                if (flush_ctr == ((2 ** `LINE_SELECT_BITS)-1)) begin
                    flush_enable <= 0;
                end
                flush_ctr <= flush_ctr + 1;            
            end
        end
    end

    // assign addr_out  = flush_ctr;
    // assign valid_out = flush_enable;

endmodule