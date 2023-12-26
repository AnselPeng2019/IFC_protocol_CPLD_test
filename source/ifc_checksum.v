module ifc_checksum (
    input clk,
    input rst_n,
    input en,
    input clear,
    input [15:0] datain,
    output reg [15:0] checksum,
    output reg check_end
);


    always @ (posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            checksum <= 0;
            check_end <= 0;
        end else begin
            if(en) begin
                checksum <= checksum ^ datain;
                check_end <= 1;
            end else if (clear) begin
                checksum <= 0;
                check_end <= 0;
            end
            else begin
                check_end <= 0;
            end
        end
    end
endmodule