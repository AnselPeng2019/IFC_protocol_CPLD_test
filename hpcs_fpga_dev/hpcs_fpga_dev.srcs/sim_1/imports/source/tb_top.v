
`timescale  1ns / 10ps

module tb_top;

    // src3cpld Parameters
    parameter PERIOD      = 5    ;
    parameter idle        = 3'b000;
    parameter pwr_on      = 3'b001;
    parameter system_up   = 3'b010;
    parameter swr_assert  = 3'b100;

    parameter ip_clk  = 2.85; //350Mhz
    parameter ifc_clk = 10;  //100MHz
    parameter trad   = 18*ip_clk;
    parameter taco   = 1*ip_clk;
    parameter tcs    = 1*ip_clk;
    parameter twp    = 6*ip_clk;
    parameter teadc  = 2*ip_clk;
    parameter tacse  = 3*ip_clk;
    parameter teahc  = 5*ip_clk;
    parameter tch    = 0*ip_clk;

    // src3cpld Inputs
    reg   ifc_cs                               = 1 ;
    reg   ifc_we_b                             = 1 ;
    reg   ifc_oe_b                             = 1 ;
    reg   ifc_avd                              = 0 ;
    reg   clock_200M_p                         = 0 ;
    reg   clock_200M_n                         = 1 ;


    // src3cpld Bidirs
    wire  [15:0]  ifc_ad                     ;
    reg   [15:0]  ifc_ad_r = 0                     ;
    reg   [15:0]  ifc_add_lt = 0;

    wire uart_tx;
    wire uart_rx;

    reg [15:0] addr   = 16'hxxxx;
    reg [15:0] dataT = 0;
    reg [15:0] dataR = 0;
    reg [15:0] data_len = 0;
    reg [15:0] data_checksum = 0;

    reg [15:0] data_period    [0:119];
    task reset_data_period;
        begin
            data_period[ 0] <= 16'h0001;data_period[ 1] <= 16'h5566;data_period[ 2] <= 16'h7788;data_period[ 3] <= 16'h0001;data_period[ 4] <= 16'h5566;data_period[ 5] <= 16'h7788;data_period[ 6] <= 16'h0001; data_period[ 7] <= 16'h5566; data_period[ 8] <= 16'h7788; data_period[ 9] <= 16'h0001;data_period[10] <= 16'h5566;data_period[11] <= 16'h7788;data_period[12] <= 16'h0001; data_period[13] <= 16'h5566; data_period[14] <= 16'h7788;
            data_period[15] <= 16'h1001;data_period[16] <= 16'h5566;data_period[17] <= 16'h7788;data_period[18] <= 16'h1001;data_period[19] <= 16'h5566;data_period[20] <= 16'h7788;data_period[21] <= 16'h1001; data_period[22] <= 16'h5566; data_period[23] <= 16'h7788; data_period[24] <= 16'h1001;data_period[25] <= 16'h5566;data_period[26] <= 16'h7788;data_period[27] <= 16'h1001; data_period[28] <= 16'h5566; data_period[29] <= 16'h7788;
            data_period[30] <= 16'h2001;data_period[31] <= 16'h5566;data_period[32] <= 16'h7788;data_period[33] <= 16'h2001;data_period[34] <= 16'h5566;data_period[35] <= 16'h7788;data_period[36] <= 16'h2001; data_period[37] <= 16'h5566; data_period[38] <= 16'h7788; data_period[39] <= 16'h2001;data_period[40] <= 16'h5566;data_period[41] <= 16'h7788;data_period[42] <= 16'h2001; data_period[43] <= 16'h5566; data_period[44] <= 16'h7788;
            data_period[45] <= 16'h3001;data_period[46] <= 16'h5566;data_period[47] <= 16'h7788;data_period[48] <= 16'h3001;data_period[49] <= 16'h5566;data_period[50] <= 16'h7788;data_period[51] <= 16'h3001; data_period[52] <= 16'h5566; data_period[53] <= 16'h7788; data_period[54] <= 16'h3001;data_period[55] <= 16'h5566;data_period[56] <= 16'h7788;data_period[57] <= 16'h3001; data_period[58] <= 16'h5566; data_period[59] <= 16'h7788;
            data_period[60] <= 16'h0002;data_period[61] <= 16'h5566;data_period[62] <= 16'h7788;data_period[63] <= 16'h0002;data_period[64] <= 16'h5566;data_period[65] <= 16'h7788;data_period[66] <= 16'h0002; data_period[67] <= 16'h5566; data_period[68] <= 16'h7788; data_period[69] <= 16'h0002;data_period[70] <= 16'h5566;data_period[71] <= 16'h7788;data_period[72] <= 16'h0002; data_period[73] <= 16'h5566; data_period[74] <= 16'h7788;
            data_period[75] <= 16'h1002;data_period[76] <= 16'h5566;data_period[77] <= 16'h7788;data_period[78] <= 16'h1002;data_period[79] <= 16'h5566;data_period[80] <= 16'h7788;data_period[81] <= 16'h1002; data_period[82] <= 16'h5566; data_period[83] <= 16'h7788; data_period[84] <= 16'h1002;data_period[85] <= 16'h5566;data_period[86] <= 16'h7788;data_period[87] <= 16'h1002; data_period[88] <= 16'h5566; data_period[89] <= 16'h7788;
            data_period[90] <= 16'h2002;data_period[91] <= 16'h5566;data_period[92] <= 16'h7788;data_period[93] <= 16'h2002;data_period[94] <= 16'h5566;data_period[95] <= 16'h7788;data_period[96] <= 16'h2002; data_period[97] <= 16'h5566; data_period[98] <= 16'h7788; data_period[99] <= 16'h2002;data_period[100]<= 16'h5566;data_period[101]<= 16'h7788;data_period[102]<= 16'h2002; data_period[103]<= 16'h5566; data_period[104]<= 16'h7788;
            data_period[105]<= 16'h3002;data_period[106]<= 16'h5566;data_period[107]<= 16'h7788;data_period[108]<= 16'h3002;data_period[109]<= 16'h5566;data_period[110]<= 16'h7788;data_period[111]<= 16'h3002; data_period[112]<= 16'h5566; data_period[113]<= 16'h7788; data_period[114]<= 16'h3002;data_period[115]<= 16'h5566;data_period[116]<= 16'h7788;data_period[117]<= 16'h3002; data_period[118]<= 16'h5566; data_period[119]<= 16'h7788;
        end
    endtask

    reg [15:0] data_para    [0:119];
    task reset_data_para;
        begin
            data_para[ 0] <= 16'h0001;data_para[ 1] <= 16'h5566;data_para[ 2] <= 16'h7788;data_para[ 3] <= 16'h0001;data_para[ 4] <= 16'h5566;data_para[ 5] <= 16'h7788;data_para[ 6] <= 16'h0001; data_para[ 7] <= 16'h5566; data_para[ 8] <= 16'h7788; data_para[ 9] <= 16'h0001;data_para[10] <= 16'h5566;data_para[11] <= 16'h7788;data_para[12] <= 16'h0001; data_para[13] <= 16'h5566; data_para[14] <= 16'h7788;
            data_para[15] <= 16'h1001;data_para[16] <= 16'h5566;data_para[17] <= 16'h7788;data_para[18] <= 16'h1001;data_para[19] <= 16'h5566;data_para[20] <= 16'h7788;data_para[21] <= 16'h1001; data_para[22] <= 16'h5566; data_para[23] <= 16'h7788; data_para[24] <= 16'h1001;data_para[25] <= 16'h5566;data_para[26] <= 16'h7788;data_para[27] <= 16'h1001; data_para[28] <= 16'h5566; data_para[29] <= 16'h7788;
            data_para[30] <= 16'h2001;data_para[31] <= 16'h5566;data_para[32] <= 16'h7788;data_para[33] <= 16'h2001;data_para[34] <= 16'h5566;data_para[35] <= 16'h7788;data_para[36] <= 16'h2001; data_para[37] <= 16'h5566; data_para[38] <= 16'h7788; data_para[39] <= 16'h2001;data_para[40] <= 16'h5566;data_para[41] <= 16'h7788;data_para[42] <= 16'h2001; data_para[43] <= 16'h5566; data_para[44] <= 16'h7788;
            data_para[45] <= 16'h3001;data_para[46] <= 16'h5566;data_para[47] <= 16'h7788;data_para[48] <= 16'h3001;data_para[49] <= 16'h5566;data_para[50] <= 16'h7788;data_para[51] <= 16'h3001; data_para[52] <= 16'h5566; data_para[53] <= 16'h7788; data_para[54] <= 16'h3001;data_para[55] <= 16'h5566;data_para[56] <= 16'h7788;data_para[57] <= 16'h3001; data_para[58] <= 16'h5566; data_para[59] <= 16'h7788;
            data_para[60] <= 16'h0002;data_para[61] <= 16'h5566;data_para[62] <= 16'h7788;data_para[63] <= 16'h0002;data_para[64] <= 16'h5566;data_para[65] <= 16'h7788;data_para[66] <= 16'h0002; data_para[67] <= 16'h5566; data_para[68] <= 16'h7788; data_para[69] <= 16'h0002;data_para[70] <= 16'h5566;data_para[71] <= 16'h7788;data_para[72] <= 16'h0002; data_para[73] <= 16'h5566; data_para[74] <= 16'h7788;
            data_para[75] <= 16'h1002;data_para[76] <= 16'h5566;data_para[77] <= 16'h7788;data_para[78] <= 16'h1002;data_para[79] <= 16'h5566;data_para[80] <= 16'h7788;data_para[81] <= 16'h1002; data_para[82] <= 16'h5566; data_para[83] <= 16'h7788; data_para[84] <= 16'h1002;data_para[85] <= 16'h5566;data_para[86] <= 16'h7788;data_para[87] <= 16'h1002; data_para[88] <= 16'h5566; data_para[89] <= 16'h7788;
            data_para[90] <= 16'h2002;data_para[91] <= 16'h5566;data_para[92] <= 16'h7788;data_para[93] <= 16'h2002;data_para[94] <= 16'h5566;data_para[95] <= 16'h7788;data_para[96] <= 16'h2002; data_para[97] <= 16'h5566; data_para[98] <= 16'h7788; data_para[99] <= 16'h2002;data_para[100]<= 16'h5566;data_para[101]<= 16'h7788;data_para[102]<= 16'h2002; data_para[103]<= 16'h5566; data_para[104]<= 16'h7788;
            data_para[105]<= 16'h3002;data_para[106]<= 16'h5566;data_para[107]<= 16'h7788;data_para[108]<= 16'h3002;data_para[109]<= 16'h5566;data_para[110]<= 16'h7788;data_para[111]<= 16'h3002; data_para[112]<= 16'h5566; data_para[113]<= 16'h7788; data_para[114]<= 16'h3002;data_para[115]<= 16'h5566;data_para[116]<= 16'h7788;data_para[117]<= 16'h3002; data_para[118]<= 16'h5566; data_para[119]<= 16'h7788;
        end
    endtask


    //char testdata[12] = {0x01,0x12, 0x33,0x44,0x55,0x66,  0x02,0x23, 0x77,0x88,0x99,0xaa};
    reg [15:0] data_write [0:5];
    initial begin
        data_write[0] = 16'h0112;
        data_write[1] = 16'h3344;
        data_write[2] = 16'h5566;
        data_write[3] = 16'h0223;
        data_write[4] = 16'h7788;
        data_write[5] = 16'h99aa;
    end
    //模拟AC掉电检测
    // initial begin
    //     #100 voltage_drop <= 1;
    //     #40  voltage_drop <= 0;
    // end

    task read_operation;
        input [15:0] address;
        // input data;
        output reg [15:0] data;
        begin
            #150              addr[15:0]     = address;
                              ifc_ad_r[15:0] = {addr[0],addr[1],addr[2],addr[3],addr[4],addr[5],addr[6],addr[7],
                                                addr[8],addr[9],addr[10],addr[11],addr[12],addr[13],addr[14],addr[15]};
                              ifc_avd = 1;
                              ifc_add_lt[15:0] = ifc_ad_r[15:0];
            #teadc            ifc_avd = 0;
            #(teahc+tacse)    ifc_cs  = 0;
            #taco             ifc_oe_b = 0;
            #trad             data[15:0] = {ifc_ad[0],ifc_ad[1],ifc_ad[2], ifc_ad[3], ifc_ad[4], ifc_ad[5], ifc_ad[6], ifc_ad[7],
                                      ifc_ad[8],ifc_ad[9],ifc_ad[10],ifc_ad[11],ifc_ad[12],ifc_ad[13],ifc_ad[14],ifc_ad[15]};
                              ifc_oe_b  = 1;
                              ifc_cs    = 1;
            // #50             ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;
        end
    endtask
    
    task read_operation_set_1;
        reg [7:0] i;
        begin
            //读状态
            data_checksum = 0;
            read_operation(8'h10,dataR);
            #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;    
            //写操作,准备连续读大块数据
            write_operation(8'h40, 16'b0000_0001_0000_0011);    
            //读操作,确认是否ready
            read_operation(8'h40,dataR);
            #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;
            
            //读操作,读数据长度
            read_operation(8'h52,data_len);
            #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;    
            //确认ready后连续读6次操作
            
            if (dataR[3] == 1) begin
                for ( i = 0; i<(data_len/2); i=i+1) begin
                //读操作,读出6个16bit数据
                read_operation(8'h54,dataR);
                data_checksum = data_checksum ^ dataR;
                #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;
                end
            end
            //read checksum 
            read_operation(8'h50,data_checksum);
            //写操作,读大块数据操作结束
            write_operation(8'h40, 16'b0000_0001_0000_0000);
        end
    endtask
    
    task write_operation;
        input [15:0] address;
        // input data;
        input [15:0] data;
        begin
            #150    addr[15:0]     = address;
                        ifc_ad_r[15:0] = {addr[0],addr[1],addr[2],addr[3],addr[4],addr[5],addr[6],addr[7],
                                          addr[8],addr[9],addr[10],addr[11],addr[12],addr[13],addr[14],addr[15]};
                        ifc_avd = 1;
                        ifc_add_lt[15:0] = ifc_ad_r[15:0];
            #teadc  ifc_avd = 0;
            #teahc  ifc_ad_r[15:0] = {data[0],data[1],data[2], data[3], data[4], data[5], data[6], data[7],
                                        data[8],data[9],data[10],data[11],data[12],data[13],data[14],data[15]};
            #tacse  ifc_cs  = 0;
            #tcs    ifc_we_b = 0;
            #twp    ifc_we_b = 1;
            #tch    ifc_cs = 1;
            #50     ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;
            end
    endtask
    
    task write_operation_set_1;
        reg [7:0] i;
        begin
            data_checksum = 0;
            //预先计算checksum值
            for (i = 0;i<(data_len/2); i=i+1) begin
                data_checksum = data_checksum ^ data_write[i];
            end
            //写操作,准备连续写大块数据
            write_operation(8'h40, 16'b0000_0001_0000_0101);
            //是否ready？
            read_operation(8'h40,dataR);
            #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;
            //写checksum
            write_operation(8'h50, data_checksum);
            //写操作,写数据长度
            write_operation(8'h52, data_len);
            for ( i = 0; i<(data_len/2); i=i+1) begin
                //写操作,连续写6个16bit数据
                write_operation(8'h54,data_write[i]);
            end
            //读，write OK？
            read_operation(8'h40,dataR);
            //写操作,连续写大块数据操作结束
            write_operation(8'h40, 16'b0000_0001_0000_0000);
        end
    endtask

    task write_operation_period_data;
        reg [7:0] i;
        // reg [15:0] data_len = 0;
        begin
            reset_data_period();
            # 50 data_checksum = 0;
            data_len = 120;
            //预先计算checksum值
            for (i = 0;i<(120/2); i=i+1) begin
                data_checksum = data_checksum ^ data_period[i];
            end
            //写操作,准备连续写大块数据
            write_operation(8'h40, 16'b0000_0001_0000_0101);
            //是否ready？
            read_operation(8'h40,dataR);
            #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;
            //写checksum
            write_operation(8'h50, data_checksum);
            //写操作,写数据长度
            write_operation(8'h52, data_len);
            for ( i = 0; i<(120/2); i=i+1) begin
                //写操作,连续写6个16bit数据
                write_operation(8'h54,data_period[i]);
            end
            //读，write OK？
            read_operation(8'h40,dataR);
            if(dataR[4] == 1) begin
                $display("Write OK....\n");
            end else begin
                $display("Write Fail....\n");
            end
            //写操作,连续写大块数据操作结束
            write_operation(8'h40, {8'h01, 8'b0000_0000});
        end
    endtask

    task read_operation_period_data;
        reg [7:0] i;
        begin
            //读状态
            data_checksum = 0;
            data_len = 120;
            read_operation(8'h10,dataR);
            #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;    
            //写操作,准备连续读大块数据
            write_operation(8'h40, 16'b0000_0001_0000_0011);    
            //读操作,确认是否ready
            read_operation(8'h40,dataR);
            #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;
            
            //读操作,读数据长度
            read_operation(8'h52,data_len);
            #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;    
            //确认ready后连续读6次操作
            
            if (dataR[3] == 1) begin
                for ( i = 0; i<(data_len/2); i=i+1) begin
                //读操作,读出6个16bit数据
                read_operation(8'h54,dataR);
                data_checksum = data_checksum ^ dataR;
                #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;
                end
            end
            //read checksum 
            read_operation(8'h50,data_checksum);
            //写操作,读大块数据操作结束
            write_operation(8'h40, {8'h01, 8'b0000_0000});
        end
    endtask

    task write_operation_para_data;
        reg [7:0] i;
        // reg [15:0] data_len = 0;
        begin
            reset_data_para();
            # 50 
            data_checksum = 0;
            data_len = 120;
            //预先计算checksum值
            for (i = 0;i<(data_len/2); i=i+1) begin
                data_checksum = data_checksum ^ data_para[i];
            end
            //写操作,准备连续写大块数据
            write_operation(8'h40, {8'h04,8'b0000_0101});
            //是否ready？
            read_operation(8'h40,dataR);
            #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;
            //写checksum
            write_operation(8'h50, data_checksum);
            //写操作,写数据长度
            write_operation(8'h52, data_len);
            for ( i = 0; i<(data_len/2); i=i+1) begin
                //写操作,连续写16bit数据
                write_operation(8'h54,data_para[i]);
            end
            //读，write OK？
            read_operation(8'h40,dataR);
            if(dataR[4] == 1) begin
                $display("***** Para Write OK  *****\n");
            end else begin
                $display("***** Para Write Fail*****\n");
            end
            //写操作,连续写大块数据操作结束
            write_operation(8'h40, {8'h04, 8'b0000_0000});
        end
    endtask

    task write_operation_frf_data;
        reg [7:0] i;
        // reg [15:0] data_len = 0;
        begin
            reset_data_period();
            # 50 
            data_checksum = 0;
            data_len = 60;
            //预先计算checksum值
            for (i = 0;i<(data_len/2); i=i+1) begin
                data_checksum = data_checksum ^ data_period[i];
            end
            //写操作,准备连续写大块数据
            write_operation(8'h40, {8'h02,8'b0000_0101});

            #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;
            //写checksum
            write_operation(8'h50, data_checksum);
            //写操作,写数据长度
            write_operation(8'h52, data_len);
            for ( i = 0; i<(data_len/2); i=i+1) begin
                //写操作,连续写16bit数据
                write_operation(8'h54,data_period[i]);
            end
            //读，write OK？
            read_operation(8'h40,dataR);
            if(dataR[4] == 1) begin
                $display("*****Write OK*****\n");
                // write_operation(8'h56,{4'b0, 2'b00, 10'd10});//write scope sampling period
                write_operation(8'h42,{14'b0, 2'b10});//write frf sample enable
            end else begin
                $display("*****Write Fail*****\n");
            end
            //写操作,连续写大块数据操作结束
            write_operation(8'h40, {8'h02, 8'b0000_0000});
        end
    endtask

    task read_operation_frf_data;
        reg [7:0] i;
        begin
            //读状态
            data_checksum = 0;
            data_len = 12;
            read_operation(8'h10,dataR);
            #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;    
            //写操作,准备连续读大块数据
            write_operation(8'h40, {8'h02, 8'b0000_0011});    
            //读操作,确认是否ready
            read_operation(8'h40,dataR);
            #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;
            if(dataR[3] == 1) begin
                $display("*****#%0t Is ready, start frf read operation*****\n",$time);
                //读操作,读数据长度
                read_operation(8'h52,data_len);
                #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;    
                //确认ready后连续操作
                if (dataR[3] == 1) begin
                    for ( i = 0; i<(data_len/2); i=i+1) begin
                    //读操作,读出6个16bit数据
                    read_operation(8'h54,dataR);
                    data_checksum = data_checksum ^ dataR;
                    #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;
                    end
                end
                //read checksum 
                read_operation(8'h50,dataR);
                if(dataR == data_checksum) begin//check ok..
                    $display("*****#%0t checksum ok*****\n",$time);
                end
            end else begin
                $display("*****#%0t Not ready, cancel frf read operation*****\n",$time);
            end
            //写操作,读大块数据操作结束
            write_operation(8'h40, {8'h02, 8'b0000_0000});
        end
    endtask

    task write_operation_scope_data;
        reg [7:0] i;
        // reg [15:0] data_len = 0;
        begin
            reset_data_period();
            # 50 data_checksum = 0;
            data_len = 60;
            //预先计算checksum值
            for (i = 0;i<(data_len/2); i=i+1) begin
                data_checksum = data_checksum ^ data_period[i];
            end
            //写操作,准备连续写大块数据
            write_operation(8'h40, {8'h03,8'b0000_0101});

            #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;
            //写checksum
            write_operation(8'h50, data_checksum);
            //写操作,写数据长度
            write_operation(8'h52, data_len);
            for ( i = 0; i<(data_len/2); i=i+1) begin
                //写操作,连续写6个16bit数据
                write_operation(8'h54,data_period[i]);
            end
            //读，write OK？
            dataR = 0;
            read_operation(8'h40,dataR);
            write_operation(8'h40, {8'h03, 8'b0000_0000});
            if(dataR[4] == 1) begin
                $display("*****scope Write OK  *****\n");
                write_operation(8'h56,{4'b0, 2'b01, 10'h2});//write scope sampling period
                write_operation(8'h42,{14'b0, 2'b11});//write scope sample enable
            end else begin
                $display("*****scope Write Fail*****\n");
            end
            //写操作,连续写大块数据操作结束
        end
    endtask

    task read_operation_scope_data;
        reg [7:0] i;
        begin
            //读状态
            data_checksum = 0;
            data_len = 12;
            read_operation(8'h10,dataR);
            #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;    
            //写操作,准备连续读大块数据
            write_operation(8'h40, {8'h03, 8'b0000_0011});    
            //读操作,确认是否ready
            read_operation(8'h40,dataR);
            #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;
            if(dataR[3] == 1) begin     //确认ready后连续操作
                $display("*****#%0t Is ready, start scope read operation*****\n",$time);
                //读操作,读数据长度
                read_operation(8'h52,data_len);
                #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;    

                for ( i = 0; i<(data_len/2); i=i+1) begin
                //读操作,读出6个16bit数据
                read_operation(8'h54,dataR);
                data_checksum = data_checksum ^ dataR;
                #50    ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;
                end
                //read checksum 
                read_operation(8'h50,data_checksum);
            end else begin
                $display("*****#%0t Not ready, cancel scope read operation*****\n",$time);
            end
            //写操作,读大块数据操作结束
            write_operation(8'h40, {8'h03, 8'b0000_0000});
        end
    endtask

    //模拟200MHz时钟输入
  always #2.5 clock_200M_n = ~clock_200M_n;
  always #2.5 clock_200M_p = ~clock_200M_p;

    //模拟100MHz时钟PLL输出
    // initial begin
    //     forever
    //         #(PERIOD/4)  pll_100M = ~pll_100M;
    // end

    //模拟16bit IFC总线写操作

//     reg [7:0] i = 0;
    initial begin
        
        #500
            write_operation_period_data;
            // write_operation_frf_data;
            // write_operation_scope_data;
        #500
            read_operation_period_data;
            // write_operation_para_data;

        // #100000
            // read_operation_frf_data;
            // read_operation_scope_data;
        // #600000
        //     write_operation_period_data;
        //     read_operation_frf_data;
            // read_operation_scope_data;

        // #200 $finish;
    end


    assign ifc_ad[15:0] = ifc_oe_b ? ifc_ad_r[15:0] : 16'bzzzz_zzzz_zzzz_zzzz;

    //probe
    // wire [15:0] cpld_data;
    // wire [2:0] current_state;
    // assign cpld_data = u_top.cpld_data;
    // wire [15:0] cpld_addr;
    // assign cpld_addr = u_top.cpld_addr;
    // wire [15:0] FPGA_HANDSHAKE_CHANNEL0;
    // assign FPGA_HANDSHAKE_CHANNEL0 = u_top.FPGA_HANDSHAKE_CHANNEL0;
    // wire [15:0] FPGA_COMM_DATA;
    // assign FPGA_COMM_DATA = u_top.FPGA_COMM_DATA;
    // wire [15:0] checksum_out;
    // assign checksum_out[15:0] = u_top.checksum_out[15:0];
    // assign checksum_en_r = u_top.checksum_en_r;
    // assign checksum_en_w = u_top.checksum_en_w;
    // assign write_status = u_top.write_status;
    // assign read_status  = u_top.read_status;
    // assign high_cpld_clk = u_top.high_cpld_clk;
    // assign current_state = u_top.current_state;
    // assign get_in_write_st = u_top.get_in_write_st;
    // assign get_in_read_st  = u_top.get_in_read_st;
    // assign checksum_clear  = u_top.checksum_clear;
    // // wire [15:0] data_block[0:5];
    // // assign data_block[0]  = u_top.data_block[0];
    // // assign data_block[1]  = u_top.data_block[1];
    // // assign data_block[2]  = u_top.data_block[2];
    // // assign data_block[3]  = u_top.data_block[3];
    // // assign data_block[4]  = u_top.data_block[4];
    // // assign data_block[5]  = u_top.data_block[5];
    // wire [7:0]  pi;
    // assign pi  = u_top.pi;
    // assign oe_ne_1cy = u_top.oe_ne_1cy;
    // wire [15:0] checksum_datain;
    // assign checksum_datain  = u_top.checksum_datain;
    // assign checksum_en_w_2cy = u_top.checksum_en_w_2cy;
    // wire [7:0] hs_cmd;
    // assign hs_cmd = u_top.hs_cmd;


top  u_top (
    .ifc_addr_lat            ( ifc_add_lt   ),
    .ifc_cs                  ( ifc_cs         ),
    .ifc_we_b                ( ifc_we_b       ),
    .ifc_oe_b                ( ifc_oe_b       ),
    .ifc_avd                 ( ifc_avd        ),
    .sys_clk_p               ( clock_200M_p      ),
    .sys_clk_n               ( clock_200M_n      ),

    .irq                     ( irq            ),

    .ifc_ad_bus              ( ifc_ad     )
);

endmodule
