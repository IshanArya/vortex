`include "VX_cache_config.vh"

module VX_cache_bypass #(
    // parameters

    // parameter CACHE_ID                      = 0,

    // Number of Word requests per cycle
    parameter NUM_REQS                      = 4,

    // Size of cache in bytes
    // parameter CACHE_SIZE                    = 16384, 
    // Size of line inside a bank in bytes
    parameter CACHE_LINE_SIZE               = 64, 
    // Number of banks
    // parameter NUM_BANKS                     = NUM_REQS,
    // // Number of ports per banks
    // parameter NUM_PORTS                     = 1,
    // Size of a word in bytes
    parameter WORD_SIZE                     = 4, 

    // // Core Request Queue Size
    // parameter CREQ_SIZE                     = 4, 
    // Miss Reserv Queue Knob
    parameter MSHR_SIZE                     = 8, 
    // // DRAM Response Queue Size
    // parameter DRSQ_SIZE                     = 4,
    // // DRAM Request Queue Size
    // parameter DREQ_SIZE                     = 4,

    // // Enable cache writeable
    // parameter WRITE_ENABLE                  = 1,

    // core request tag size
    parameter CORE_TAG_WIDTH                = $clog2(MSHR_SIZE),
    
    // size of tag id in core request tag
    parameter CORE_TAG_ID_BITS              = CORE_TAG_WIDTH,

    // dram request tag size
    parameter DRAM_TAG_WIDTH                = (32 - $clog2(CACHE_LINE_SIZE))

    // // bank offset from beginning of index range
    // parameter BANK_ADDR_OFFSET              = 0,

    // difference in core_addr and dram_addr width
    // parameter DIFF_TAG_WIDTH               = DRAM_TAG_WIDTH - CORE_TAG_WIDTH

    // // in-order DRAN
    // parameter IN_ORDER_DRAM                 = 0
    // parameter BYPASS_BASE_ADDR              = DIRECT_MEM_BASE_ADDR

) (
    // inputs and outputs

    // flush_ctrl
    input wire  clk,
    input wire  reset,

    // Core request
    output wire [NUM_REQS-1:0]                           bypass_core_req_valid,
    output wire [NUM_REQS-1:0]                           bypass_core_req_rw,
    output wire [NUM_REQS-1:0][`WORD_ADDR_WIDTH-1:0]     bypass_core_req_addr,
    output wire [NUM_REQS-1:0][WORD_SIZE-1:0]            bypass_core_req_byteen,
    output wire [NUM_REQS-1:0][`WORD_WIDTH-1:0]          bypass_core_req_data,
    output wire [NUM_REQS-1:0][CORE_TAG_WIDTH-1:0]       bypass_core_req_tag,
    input wire [NUM_REQS-1:0]                            bypass_core_req_ready,

    input wire [NUM_REQS-1:0]                           core_req_valid,
    input wire [NUM_REQS-1:0]                           core_req_rw,
    input wire [NUM_REQS-1:0][`WORD_ADDR_WIDTH-1:0]     core_req_addr,
    input wire [NUM_REQS-1:0][WORD_SIZE-1:0]            core_req_byteen,
    input wire [NUM_REQS-1:0][`WORD_WIDTH-1:0]          core_req_data,
    input wire [NUM_REQS-1:0][CORE_TAG_WIDTH-1:0]       core_req_tag,
    output wire [NUM_REQS-1:0]                          core_req_ready,


    // Core response
    input wire [NUM_REQS-1:0]                          bypass_core_rsp_valid,
    input wire [NUM_REQS-1:0][`WORD_WIDTH-1:0]         bypass_core_rsp_data,
    input wire [`CORE_REQ_TAG_COUNT-1:0][CORE_TAG_WIDTH-1:0] bypass_core_rsp_tag,
    output  wire [`CORE_REQ_TAG_COUNT-1:0]               bypass_core_rsp_ready,

    output wire [NUM_REQS-1:0]                          core_rsp_valid,
    output wire [NUM_REQS-1:0][`WORD_WIDTH-1:0]         core_rsp_data,
    output wire [`CORE_REQ_TAG_COUNT-1:0][CORE_TAG_WIDTH-1:0] core_rsp_tag,
    input  wire [`CORE_REQ_TAG_COUNT-1:0]               core_rsp_ready,


    // DRAM request
    input wire                             bypass_dram_req_rw,
    input wire                             bypass_dram_req_valid,
    input wire [CACHE_LINE_SIZE-1:0]       bypass_dram_req_byteen,
    input wire [`DRAM_ADDR_WIDTH-1:0]      bypass_dram_req_addr,
    input wire [`CACHE_LINE_WIDTH-1:0]     bypass_dram_req_data,
    input wire [DRAM_TAG_WIDTH-1:0]        bypass_dram_req_tag,
    output wire                            bypass_dram_req_ready,

    output wire                             dram_req_valid,
    output wire                             dram_req_rw,
    output wire [CACHE_LINE_SIZE-1:0]       dram_req_byteen,
    output wire [`DRAM_ADDR_WIDTH-1:0]      dram_req_addr,
    output wire [`CACHE_LINE_WIDTH-1:0]     dram_req_data,
    output wire [DRAM_TAG_WIDTH-1:0]        dram_req_tag,
    input  wire                             dram_req_ready,


    //DRAM Response
    // output  wire                             bypass_dram_rsp_valid,    
    // output  wire [`CACHE_LINE_WIDTH-1:0]     bypass_dram_rsp_data,
    // output  wire [DRAM_TAG_WIDTH-1:0]        bypass_dram_rsp_tag,
    // input   wire                             bypass_dram_rsp_ready,

    // input  wire                             dram_rsp_valid,    
    // input  wire [`CACHE_LINE_WIDTH-1:0]     dram_rsp_data,
    // input  wire [DRAM_TAG_WIDTH-1:0]        dram_rsp_tag,
    // output wire                             dram_rsp_ready

    output wire [`CACHE_LINE_WIDTH-1:0]               bypass_dram_rsp_data_qual,
    output wire [DRAM_TAG_WIDTH-1:0]                  bypass_dram_rsp_tag_qual,
    output wire                                       bypass_drsq_empty,

    input wire [`CACHE_LINE_WIDTH-1:0]                dram_rsp_data_qual,
    input wire [DRAM_TAG_WIDTH-1:0]                   dram_rsp_tag_qual,
    input wire                                        drsq_empty

);
    // localparam REQS_NUM_SIZE = $clog2(NUM_REQS) + 1;
    localparam DIFF_ADDR_WIDTH = `WORD_ADDR_WIDTH - `DRAM_ADDR_WIDTH;
    localparam DIFF_TAG_WIDTH = DRAM_TAG_WIDTH - CORE_TAG_ID_BITS;
    // assigns here

    reg in_bypass_state = 0;
    wire [NUM_REQS-1:0][31:0]      extended_core_req_addr;
    reg  [NUM_REQS-1:0]            filtered_core_req_valid;
    
    wire dram_req_line_free = ~(in_bypass_state) && dram_req_ready;
    wire dram_req_is_read = dram_req_ready && dram_req_valid;

    integer bypass_req_num = -1;
    reg  [NUM_REQS-1:0]            is_bypass_request;
    reg                            bypass_dram_req_is_ready = 1;

    wire [NUM_REQS-1:0][`DRAM_ADDR_WIDTH-1:0]       aligned_core_req_addr;
    wire [NUM_REQS-1:0][DRAM_TAG_WIDTH-1:0]         aligned_core_req_tag;
    wire [NUM_REQS-1:0][`CACHE_LINE_WIDTH-1:0]      aligned_core_req_data;
    wire [NUM_REQS-1:0][CACHE_LINE_SIZE-1:0]        aligned_core_req_byteen;

    reg[`DRAM_ADDR_WIDTH-1:0]      filtered_dram_req_addr;
    reg                            filtered_dram_req_valid;
    reg                            filtered_dram_req_rw;
    reg[DRAM_TAG_WIDTH-1:0]        filtered_dram_req_tag;
    reg[`CACHE_LINE_WIDTH-1:0]     filtered_dram_req_data;
    reg[CACHE_LINE_SIZE-1:0]       filtered_dram_req_byteen;
    

    assign filtered_dram_req_addr = in_bypass_state ? aligned_core_req_addr[bypass_req_num] : bypass_dram_req_addr;
    assign filtered_dram_req_valid = in_bypass_state ? bypass_dram_req_is_ready : bypass_dram_req_valid;
    assign filtered_dram_req_rw = in_bypass_state ? core_req_rw[bypass_req_num] : bypass_dram_req_rw;
    assign filtered_dram_req_tag = in_bypass_state ? aligned_core_req_tag[bypass_req_num] : bypass_dram_req_tag;
    assign filtered_dram_req_data = in_bypass_state ? aligned_core_req_data[bypass_req_num] : bypass_dram_req_data;
    assign filtered_dram_req_byteen = in_bypass_state ? aligned_core_req_byteen[bypass_req_num] : bypass_dram_req_byteen;

    assign bypass_core_req_valid = filtered_core_req_valid;
    assign bypass_core_req_rw = core_req_rw;
    assign bypass_core_req_addr = core_req_addr;
    assign bypass_core_req_byteen = core_req_byteen;
    assign bypass_core_req_data = core_req_data;
    assign bypass_core_req_tag = core_req_tag;
    assign core_req_ready = bypass_core_req_ready;

    assign core_rsp_valid = bypass_core_rsp_valid;
    assign core_rsp_data = bypass_core_rsp_data;
    assign core_rsp_tag = bypass_core_rsp_tag;
    assign bypass_core_rsp_ready = core_rsp_ready;

    assign dram_req_valid = filtered_dram_req_valid;
    assign dram_req_rw = filtered_dram_req_rw;
    assign dram_req_byteen = filtered_dram_req_byteen;
    assign dram_req_addr = filtered_dram_req_addr;
    assign dram_req_data = filtered_dram_req_data;
    assign dram_req_tag = filtered_dram_req_tag;
    assign bypass_dram_req_ready = dram_req_line_free;

    assign bypass_dram_rsp_data_qual = dram_rsp_data_qual;
    assign bypass_dram_rsp_tag_qual = dram_rsp_tag_qual;
    assign bypass_drsq_empty = drsq_empty;

    for(genvar i = 0; i < NUM_REQS; i++) begin
        assign extended_core_req_addr[i] = {core_req_addr[i], {(32 - `WORD_ADDR_WIDTH){1'b0}}};
        assign is_bypass_request[i] = extended_core_req_addr[i] > `DIRECT_MEM_BASE_ADDR;
        assign filtered_core_req_valid[i] = is_bypass_request[i] ? 1'b0 : core_req_valid[i];
        assign aligned_core_req_addr[i] = core_req_addr[i][`WORD_ADDR_WIDTH - 1:DIFF_ADDR_WIDTH];
        assign aligned_core_req_tag[i] = {{DIFF_TAG_WIDTH{1'b0}}, core_req_tag[i][CORE_TAG_ID_BITS - 1:0]};//{core_req_tag[i], {(DRAM_TAG_WIDTH - CORE_TAG_WIDTH){1'b0}}};
        if(DIFF_ADDR_WIDTH == 0) begin
            assign aligned_core_req_data[i] = core_req_data[i];
        end else begin
            assign aligned_core_req_data[i] = {{(`CACHE_LINE_WIDTH - `WORD_WIDTH){1'b0}}, core_req_data[i]};
        end
        assign aligned_core_req_byteen[i] = {CACHE_LINE_SIZE{1'b0}};
    end
    

    always @(posedge clk) begin
        if (reset) begin
            in_bypass_state <= 0;
        end else begin
            if(~in_bypass_state)
                in_bypass_state <= (|is_bypass_request) && dram_req_ready;
            else
                in_bypass_state <= ~dram_req_is_read;
        end
    end

    always @(*) begin
        $display("%t: Is Bypass Request OR'd: %d", $time, |is_bypass_request);
        $display("%t: Bypass State: %d", $time, in_bypass_state);
        $display("%t: Dram Req Valid: %d", $time, dram_req_valid);
        $display("%t: Dram Req Ready: %d", $time, dram_req_ready);
        $display("%t: Dram Req Tag: %d", $time, dram_req_tag);
        $display("%t: Dram Rsp Tag: %d", $time, dram_rsp_tag_qual);
        
    end
    

    always @(*) begin
        bypass_req_num = -1;
        for(integer i = 0; i < NUM_REQS; i++) begin
            if(is_bypass_request[i] == 1) begin
                bypass_req_num = i;
                $display("%t: Found Bypass Number: %d", $time, i);
                break;
            end
        end
    end

    // assign addr_out  = flush_ctr;
    // assign valid_out = flush_enable;

endmodule