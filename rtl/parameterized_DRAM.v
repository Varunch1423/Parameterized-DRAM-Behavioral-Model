module parameterized_DRAM #(parameter WORD_SIZE=16,
                            parameter ROWS=32,
                            parameter COLUMNS=32)
                            (input  [$clog2((ROWS>COLUMNS)?ROWS:COLUMNS)-1:0]MA,
                             input                            RAS_N,
                             input                            CAS_N,
                             input                            LWE_N,
                             input                            UWE_N,
                             input                            OE_N,
                             inout   [WORD_SIZE-1:0]DATA);

reg [WORD_SIZE-1:0]mem[0:(ROWS*COLUMNS)-1];
reg [$clog2(ROWS)-1:0]row_address;
reg [$clog2(COLUMNS)-1:0]column_address;
reg [$clog2(ROWS)-1:0]refresh_row;
reg [$clog2(ROWS*COLUMNS)-1:0]linear_address;
reg last_ras;
reg last_cas;
reg CBR_refresh_pending;

initial
begin
    last_ras=1;
    last_cas=1;
    CBR_refresh_pending=0;
    refresh_row=0;
    row_address=0;
    column_address=0;
    linear_address=0;
end

assign DATA=(!OE_N && LWE_N==1 && UWE_N==1)? mem[linear_address]:{WORD_SIZE{1'bz}};

always@(CAS_N or RAS_N)
begin
    if(!RAS_N && last_ras)
    begin
        row_address=MA;
    end
    if(!CAS_N && last_cas)
    begin
        column_address=MA;
    end
    if(!CAS_N && last_cas && RAS_N)
    begin
        CBR_refresh_pending=1;
    end
    if(!RAS_N && last_ras && CBR_refresh_pending)
    begin
        CBR_refresh_pending=0;
        if(refresh_row==ROWS-1)
        begin
            refresh_row=0;
        end
        else
        begin
            refresh_row=refresh_row+1;
        end
    end
    last_ras=RAS_N;
    last_cas=CAS_N;
    linear_address=((row_address)*(COLUMNS))+(column_address);
    if(!LWE_N && UWE_N)
    begin
        mem[linear_address][(WORD_SIZE/2)-1:0]=DATA[(WORD_SIZE/2)-1:0];
    end
    if(LWE_N && !UWE_N)
    begin
        mem[linear_address][WORD_SIZE-1:(WORD_SIZE/2)]=DATA[WORD_SIZE-1:(WORD_SIZE/2)];
    end
    if(!LWE_N && !UWE_N)
    begin
        mem[linear_address]=DATA;
    end
end
endmodule
