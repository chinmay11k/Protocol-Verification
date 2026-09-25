// APB Master
module APB_master (
    input  logic        clk,
    input  logic        resetn,
    input  logic        start,
    input  logic        write,
    input  logic [31:0] addr,
    input  logic [7:0]  wdata,

    input  logic        pready,
    input  logic        pslverr,
    input  logic [7:0]  prdata,

    output logic        psel,
    output logic        penable,
    output logic        pwrite,
    output logic [31:0] paddr,
    output logic [7:0]  pwdata,

    output logic [7:0]  rdata,
    output logic        done,
    output logic        error
);

    typedef enum logic [1:0] {IDLE, SETUP, ACCESS} state_t;
    state_t state;

    logic        write_reg;
    logic [31:0] addr_reg;
    logic [7:0]  wdata_reg;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state     <= IDLE;
            write_reg <= 1'b0;
            addr_reg  <= 32'b0;
            wdata_reg <= 8'b0;
            rdata     <= 8'b0;
            done      <= 1'b0;
            error     <= 1'b0;
        end
        else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        write_reg <= write;
                        addr_reg  <= addr;
                        wdata_reg <= wdata;
                        error     <= 1'b0;
                        state     <= SETUP;
                    end
                end

                SETUP: begin
                    state <= ACCESS;
                end

                ACCESS: begin
                    if (pready) begin
                        if (!write_reg)
                            rdata <= prdata;

                        error <= pslverr;
                        done  <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    always_comb begin
        psel    = 1'b0;
        penable = 1'b0;
        pwrite  = write_reg;
        paddr   = addr_reg;
        pwdata  = wdata_reg;

        case (state)
            SETUP: begin
                psel    = 1'b1;
                penable = 1'b0;
            end

            ACCESS: begin
                psel    = 1'b1;
                penable = 1'b1;
            end

            default: begin
            end
        endcase
    end

endmodule