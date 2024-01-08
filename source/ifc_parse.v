module ifc_parse #(
    parameter p1 = 0
) (
    input    clk,
    input    rst_n,
    input    [15:0] hs_cmd,
    input    [15:0] sample_scope,           //scope专用的采样周期
    input    flag_get_cmd,
    input    flag_get_data,
    input    flag_out_data,
   
    output   reg            period_data_en,
    output   reg            frf_data_en,
    output   reg            scope_data_en,
    output   reg            para_data_en,
    output   reg [15:0]     data_out
);
    //prepare period data
    /*
        0         1         2   ||||||      3        4        5       6        7        8       9        10       11       12       13      14
0    16'h0003,16'h1122,16'h3344,||||||16'h0004,16'h1122,16'h3344,16'h0005,16'h1122,16'h3344,16'h0006,16'h1122,16'h3344,16'h0007,16'h1122,16'h3344
1    16'h1003,16'h1122,16'h3344,||||||16'h1004,16'h1122,16'h3344,16'h1005,16'h1122,16'h3344,16'h1006,16'h1122,16'h3344,16'h1007,16'h1122,16'h3344
2    16'h2003,16'h1122,16'h3344,||||||16'h2004,16'h1122,16'h3344,16'h2005,16'h1122,16'h3344,16'h2006,16'h1122,16'h3344,16'h2007,16'h1122,16'h3344
3    16'h3003,16'h1122,16'h3344,||||||16'h3004,16'h1122,16'h3344,16'h3005,16'h1122,16'h3344,16'h3006,16'h1122,16'h3344,16'h3007,16'h1122,16'h3344 
    */
    localparam st_idle           = 3'b000;
    localparam st_parse_cmd      = 3'b001;
    localparam st_pre_data_out   = 3'b010;      //准备要发送的数据
    localparam st_pre_data_in    = 3'b011;      //准备要接收数据
    localparam st_data_out       = 3'b100;      //更新发送数据
    localparam st_reset          = 3'b101;      //复位标志位

    reg [7:0] cmd;
    reg [7:0] i,j;
    reg [15:0] period_data, para_data, frf_data, scope_data;
    reg [2:0] cs,ns;
    reg pre_data_out, pre_data_in,data_out_flag, reset_flag;
    reg toIdle;

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            cs <= st_idle;
        end
        else begin
            cs <= ns;
        end
    end

    always @(*) begin
        case(cs)
            st_idle: begin
                if(pre_data_out)
                    ns = st_pre_data_out;
                else if(pre_data_in)
                    ns = st_pre_data_in;
                else
                    ns = st_idle; 
            end
            st_pre_data_out: begin
                if(data_out_flag) 
                    ns = st_data_out;
                else
                    ns = st_pre_data_out;
            end
            st_data_out: begin
                if(reset_flag) 
                    ns = st_reset;
                else 
                    ns = st_data_out;
            end
            st_reset: begin
                if(toIdle)
                    ns = st_idle; 
                else
                    ns = st_reset;
            end
        endcase
    end

    task parse_cmd;
    begin
        cmd <= hs_cmd[15:8];
        if(hs_cmd[15:8] == 8'h01)begin
            period_data_en <= 1;
        end else if (hs_cmd[15:8] == 8'h02 ) begin
            frf_data_en <= (hs_cmd[5] == 1) ? 1 : 0;
        end else if (hs_cmd[15:8] == 8'h03 ) begin
            scope_data_en <= (hs_cmd[5] == 1) ? 1 : 0;
        end else if (hs_cmd[15:8] == 8'h04) begin
            para_data_en <= 1;
        end else begin
            $display("FPGA_HANDSHAKE_CHANNEL0's cmd code error. \n");
        end
    end
    endtask

    task parse_out_data;
    begin
        $display("parse_out_data, cmd is %h. \n", cmd);
        case (cmd)
            8'h01: begin
                data_out <= period_data;
            end
            8'h02: begin
                data_out <= frf_data;
            end
            8'h03: begin
                data_out <= scope_data;
            end
            8'h04: begin
                data_out <= para_data;
            end                                    
            default: begin
                data_out <= 0;
            end
        endcase
    end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            period_data_en    <= 0;  
            frf_data_en       <= 0;
            scope_data_en     <= 0;
            para_data_en      <= 0;
            cmd               <= 0;
            data_out          <= 0;
            i                 <= 0;
            j                 <= 0;
       end else begin
            if(flag_get_cmd) begin
                parse_cmd;
            end else if (flag_out_data) begin
                parse_out_data;
            end
        end
    end

    //make some period data
    always @(posedge clk or negedge rst_n ) begin
        if(~rst_n) begin
            period_data       <= 16'h0000;
        end else begin
            case (i)
                0 : begin
                    case (j)
                        0 :  period_data <= 16'h0003;
                        1 :  period_data <= 16'h1122;
                        2 :  period_data <= 16'h3344;
                        default:   period_data <= 16'h0000;
                    endcase
                end
                1 : begin
                    case (j)
                        0 :  period_data <= 16'h1003;
                        1 :  period_data <= 16'h1122;
                        2 :  period_data <= 16'h3344;
                        default:   period_data <= 16'h0000;
                    endcase
                end
                2 : begin
                    case (j)
                        0 :  period_data <= 16'h2003;
                        1 :  period_data <= 16'h1122;
                        2 :  period_data <= 16'h3344;
                        default:   period_data <= 16'h0000;
                    endcase
                end
                3 : begin
                    case (j)
                        0 :  period_data <= 16'h3003;
                        1 :  period_data <= 16'h1122;
                        2 :  period_data <= 16'h3344;
                        default:   period_data <= 16'h0000;
                    endcase
                end
                default: period_data <= 16'h0000;
            endcase
        end
    end


endmodule