`include "VX_define.vh"

module VX_pipeline #( 
    parameter CORE_ID = 0
) (        
    `SCOPE_IO_VX_pipeline
    
    // Clock
    input wire                              clk,
    input wire                              reset,

    // Dcache core request
    output wire [`NUM_THREADS-1:0]          dcache_req_valid,
    output wire [`NUM_THREADS-1:0]          dcache_req_rw,
    output wire [`NUM_THREADS-1:0][3:0]     dcache_req_byteen,
    output wire [`NUM_THREADS-1:0][29:0]    dcache_req_addr,
    output wire [`NUM_THREADS-1:0][31:0]    dcache_req_data,
    output wire [`NUM_THREADS-1:0][`DCORE_TAG_WIDTH-1:0] dcache_req_tag,    
    input wire [`NUM_THREADS-1:0]           dcache_req_ready,

    // Dcache core reponse    
    input wire                              dcache_rsp_valid,
    input wire [`NUM_THREADS-1:0]           dcache_rsp_tmask,
    input wire [`NUM_THREADS-1:0][31:0]     dcache_rsp_data,
    input wire [`DCORE_TAG_WIDTH-1:0]       dcache_rsp_tag,    
    output wire                             dcache_rsp_ready,      

    // Icache core request
    output wire                             icache_req_valid,
    output wire [29:0]                      icache_req_addr,
    output wire [`ICORE_TAG_WIDTH-1:0]      icache_req_tag,
    input wire                              icache_req_ready,

    // Icache core response    
    input wire                              icache_rsp_valid,
    input wire [31:0]                       icache_rsp_data,
    input wire [`ICORE_TAG_WIDTH-1:0]       icache_rsp_tag,    
    output wire                             icache_rsp_ready,   

`ifdef PERF_ENABLE
    VX_perf_memsys_if                       perf_memsys_if,
`endif

    // Status
    output wire                             busy
);
    //
    // Dcache request
    //

    VX_dcache_core_req_if #(
        .NUM_REQS(`NUM_THREADS), 
        .WORD_SIZE(4), 
        .CORE_TAG_WIDTH(`DCORE_TAG_WIDTH)
    ) dcache_core_req_if();

    assign dcache_req_valid  = dcache_core_req_if.valid;
    assign dcache_req_rw     = dcache_core_req_if.rw;
    assign dcache_req_byteen = dcache_core_req_if.byteen;
    assign dcache_req_addr   = dcache_core_req_if.addr;
    assign dcache_req_data   = dcache_core_req_if.data;
    assign dcache_req_tag    = dcache_core_req_if.tag;
    assign dcache_core_req_if.ready = dcache_req_ready;
 
    //
    // Dcache response
    //

    VX_dcache_core_rsp_if #(
        .NUM_REQS(`NUM_THREADS), 
        .WORD_SIZE(4), 
        .CORE_TAG_WIDTH(`DCORE_TAG_WIDTH)
    ) dcache_core_rsp_if();

    assign dcache_core_rsp_if.valid = dcache_rsp_valid;
    assign dcache_core_rsp_if.tmask = dcache_rsp_tmask;
    assign dcache_core_rsp_if.data  = dcache_rsp_data;
    assign dcache_core_rsp_if.tag   = dcache_rsp_tag;
    assign dcache_rsp_ready = dcache_core_rsp_if.ready;

    //
    // Icache request
    //

    VX_icache_core_req_if #(
        .WORD_SIZE(4), 
        .CORE_TAG_WIDTH(`ICORE_TAG_WIDTH)
    ) icache_core_req_if();       

    assign icache_req_valid  = icache_core_req_if.valid;
    assign icache_req_addr   = icache_core_req_if.addr;
    assign icache_req_tag    = icache_core_req_if.tag;
    assign icache_core_req_if.ready = icache_req_ready;

    //
    // Icache response
    //

    VX_icache_core_rsp_if #(
        .WORD_SIZE(4), 
        .CORE_TAG_WIDTH(`ICORE_TAG_WIDTH)
    ) icache_core_rsp_if();    

    assign icache_core_rsp_if.valid = icache_rsp_valid;
    assign icache_core_rsp_if.data  = icache_rsp_data;
    assign icache_core_rsp_if.tag   = icache_rsp_tag;
    assign icache_rsp_ready = icache_core_rsp_if.ready;

    ///////////////////////////////////////////////////////////////////////////

    VX_cmt_to_csr_if    cmt_to_csr_if();
    VX_decode_if        decode_if();
    VX_branch_ctl_if    branch_ctl_if();
    VX_warp_ctl_if      warp_ctl_if();
    VX_ifetch_rsp_if    ifetch_rsp_if();
    VX_alu_req_if       alu_req_if();
    VX_lsu_req_if       lsu_req_if();
    VX_csr_req_if       csr_req_if(); 
    VX_fpu_req_if       fpu_req_if(); 
    VX_gpu_req_if       gpu_req_if();
    VX_writeback_if     writeback_if();     
    VX_wstall_if        wstall_if();
    VX_join_if          join_if();
    VX_commit_if        alu_commit_if();
    VX_commit_if        ld_commit_if();
    VX_commit_if        st_commit_if();
    VX_commit_if        csr_commit_if();  
    VX_commit_if        fpu_commit_if();     
    VX_commit_if        gpu_commit_if();     

`ifdef PERF_ENABLE
    VX_perf_pipeline_if perf_pipeline_if();
`endif

    `RESET_RELAY (fetch_reset);
    `RESET_RELAY (decode_reset);
    `RESET_RELAY (issue_reset);
    `RESET_RELAY (execute_reset);
    `RESET_RELAY (commit_reset);

    VX_fetch #(
        .CORE_ID(CORE_ID)
    ) fetch (
        `SCOPE_BIND_VX_pipeline_fetch
        .clk            (clk),
        .reset          (fetch_reset),
        .icache_req_if  (icache_core_req_if),
        .icache_rsp_if  (icache_core_rsp_if), 
        .wstall_if      (wstall_if),
        .join_if        (join_if),        
        .warp_ctl_if    (warp_ctl_if),
        .branch_ctl_if  (branch_ctl_if),
        .ifetch_rsp_if  (ifetch_rsp_if),
        .busy           (busy)
    );

    VX_decode #(
        .CORE_ID(CORE_ID)
    ) decode (
        .clk            (clk),
        .reset          (decode_reset),        
        .ifetch_rsp_if  (ifetch_rsp_if),
        .decode_if      (decode_if),
        .wstall_if      (wstall_if),
        .join_if        (join_if)
    );

    VX_issue #(
        .CORE_ID(CORE_ID)
    ) issue (
        `SCOPE_BIND_VX_pipeline_issue

        .clk            (clk),
        .reset          (issue_reset),

    `ifdef PERF_ENABLE
        .perf_pipeline_if (perf_pipeline_if),
    `endif

        .decode_if      (decode_if),
        .writeback_if   (writeback_if),

        .alu_req_if     (alu_req_if),
        .lsu_req_if     (lsu_req_if),        
        .csr_req_if     (csr_req_if),
        .fpu_req_if     (fpu_req_if),
        .gpu_req_if     (gpu_req_if)
    );

    VX_execute #(
        .CORE_ID(CORE_ID)
    ) execute (
        `SCOPE_BIND_VX_pipeline_execute
        
        .clk            (clk),
        .reset          (execute_reset),

    `ifdef PERF_ENABLE
        .perf_memsys_if (perf_memsys_if),
        .perf_pipeline_if (perf_pipeline_if),
    `endif 

        .dcache_req_if  (dcache_core_req_if),
        .dcache_rsp_if  (dcache_core_rsp_if),

        .cmt_to_csr_if  (cmt_to_csr_if),                 
        
        .alu_req_if     (alu_req_if),
        .lsu_req_if     (lsu_req_if),        
        .csr_req_if     (csr_req_if),
        .fpu_req_if     (fpu_req_if),
        .gpu_req_if     (gpu_req_if),

        .warp_ctl_if    (warp_ctl_if),
        .branch_ctl_if  (branch_ctl_if),        
        .alu_commit_if  (alu_commit_if),
        .ld_commit_if   (ld_commit_if),        
        .st_commit_if   (st_commit_if),       
        .csr_commit_if  (csr_commit_if),
        .fpu_commit_if  (fpu_commit_if),
        .gpu_commit_if  (gpu_commit_if),        
        
        .busy           (busy)
    );    

    VX_commit #(
        .CORE_ID(CORE_ID)
    ) commit (
        .clk            (clk),
        .reset          (commit_reset),

        .alu_commit_if  (alu_commit_if),
        .ld_commit_if   (ld_commit_if),        
        .st_commit_if   (st_commit_if),
        .csr_commit_if  (csr_commit_if),
        .fpu_commit_if  (fpu_commit_if),
        .gpu_commit_if  (gpu_commit_if),
        
        .writeback_if   (writeback_if),
        .cmt_to_csr_if  (cmt_to_csr_if)
    );
    
endmodule
