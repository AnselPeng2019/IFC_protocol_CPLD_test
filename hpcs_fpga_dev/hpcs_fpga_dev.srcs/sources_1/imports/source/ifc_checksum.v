module ifc_checksum (
    input clk,
    input rst_n,
    input en,
    input clear,
    input r_or_w,                       //read:0;write:1
    input [15:0] datain,
    output reg [15:0] checksum
);

    always @ (posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            checksum <= 0;
        end else begin
            if(en) begin
                checksum <= checksum ^ datain;
            end else if (clear) begin
                checksum <= 0;
            end
        end
    end
endmodule