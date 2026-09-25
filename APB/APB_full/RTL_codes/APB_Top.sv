// APB Top
module APB_top (
    input  logic        clk,
    input  logic        resetn,
    input  logic        start,
    input  logic        write,
    input  logic [31:0] addr,
    input  logic [7:0]  wdata,

    output logic [7:0]  rdata,
    output logic        done,
    output logic        error
);

    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] paddr;
    logic [7:0]  pwdata;

    logic        pready;
    logic        pslverr;
    logic [7:0]  prdata;

    APB_master master (
        .clk     (clk),
        .resetn  (resetn),
        .start   (start),
        .write   (write),
        .addr    (addr),
        .wdata   (wdata),
        .pready  (pready),
        .pslverr (pslverr),
        .prdata  (prdata),
        .psel    (psel),
        .penable (penable),
        .pwrite  (pwrite),
        .paddr   (paddr),
        .pwdata  (pwdata),
        .rdata   (rdata),
        .done    (done),
        .error   (error)
    );

    APB_slave slave (
        .pclk    (clk),
        .presetn (resetn),
        .psel    (psel),
        .penable (penable),
        .pwrite  (pwrite),
        .paddr   (paddr),
        .pwdata  (pwdata),
        .prdata  (prdata),
        .pready  (pready),
        .pslverr (pslverr)
    );

endmodule