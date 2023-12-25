module get_signal_edge ( input clk,
                         input rst_n,
                         input signal,
                         output pos_edge,
                         output neg_edge);
    
    reg [1:0] sig_reg;

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            sig_reg <= 2'b00;
            // sync_pe  <= 0;
        end else begin
            sig_reg[0] <= signal;
            sig_reg[1] <= sig_reg[0];
        end
    end

    assign pos_edge = sig_reg[0] == 1 && sig_reg[1] == 0;    
    assign neg_edge = sig_reg[0] == 0 && sig_reg[1] == 1;

endmodule