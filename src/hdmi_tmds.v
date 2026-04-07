module hdmi_tmds(
    input clk,
    input reset, //Active high
    input [1:0] ctrl,
    input de,
    input [7:0] d,

    output reg [9:0] q_out
);

//Stage 1: Transition Minimalizing 
wire [4:0] N1_d = d[0] + d[1] + d[2] + d[3] + d[4] + d[5] + d[6] + d[7]; //Number of 1s in d, function N1
wire use_xnor = (N1_d > 4) || (N1_d == 4 && d[0] == 1'b0); //Use XNOR or XOR for transition minimalizing  

wire [8:0] q_m = {(use_xnor ? 1'b0 : 1'b1), 
                (use_xnor ? q_m[6] ~^ d[7] : q_m[6] ^ d[7]),
                (use_xnor ? q_m[5] ~^ d[6] : q_m[5] ^ d[6]),
                (use_xnor ? q_m[4] ~^ d[5] : q_m[4] ^ d[5]),
                (use_xnor ? q_m[3] ~^ d[4] : q_m[3] ^ d[4]),     //Perform transition minimalizing and assign to q_m
                (use_xnor ? q_m[2] ~^ d[3] : q_m[2] ^ d[3]),
                (use_xnor ? q_m[1] ~^ d[2] : q_m[1] ^ d[2]),
                (use_xnor ? q_m[0] ~^ d[1] : q_m[0] ^ d[1]),
                d[0]};

//Stage 2: dC Balancing 
reg signed [4:0] prev_disparity; //Store the previous disparity, Cnt(t-1)

//Values (Signed as the disparity ranges from -8 to +8)
wire signed [4:0] N1_q_m = q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7]; //Mumber of 1s in q_m, function N1
wire signed [4:0] N0_q_m = 8 - N1_q_m; //Number of 0s in q_m, functio N0 (Equivalant to 8 - N1 as its a byte)
wire signed [4:0] current_disparity = N1_q_m - N0_q_m; //Note this value is used frequently (although not obviously in the flowchart) so its assigned a name


always @(posedge clk, posedge reset) begin
    if(reset) begin // Reset disparity and set the default output (C1==0, C2==0)
         prev_disparity <= 5'b00000; 
         q_out <= 10'b1101010100;
    end
    else begin
            if(~de) begin //If not sending data (Control Period)
                case(ctrl)
                    2'b11 : q_out <= 10'b1010101011; 
                    2'b10 : q_out <= 10'b0101010100; 
                    2'b01 : q_out <= 10'b0010101011; 
                    default: q_out <= 10'b1101010100;
                endcase
                prev_disparity <= 5'b00000; //Reset disparity
            end
            else begin //Start dC balancing
                if(prev_disparity == 0 ||  current_disparity  == 0) begin  //If there is no disparity in the currently encoded q_m and the previous output
                    q_out <= {~q_m[8],q_m[8] ,(q_m[8] ? q_m[7:0] : ~(q_m[7:0]))};
                    if(q_m[8] == 1'b0) prev_disparity <= prev_disparity - current_disparity;
                    else prev_disparity <= prev_disparity + current_disparity;
                end
                else begin
                    if((prev_disparity > 0 && (N1_q_m > N0_q_m)) || (prev_disparity < 0 && (N1_q_m < N0_q_m))) begin //If disparity for the previous and currently encoded q_m are the same (eg. Both have more than 4 set bits)
                        q_out <= {1'b1,q_m[8],~(q_m[7:0])};
                        prev_disparity <= prev_disparity + {q_m[8], 1'b0} -  current_disparity; // {q_m[8], 1'b0} equivalant to q_m[8]*2
                    end
                    else begin
                        q_out <= {1'b0,q_m[8],q_m[7:0]};
                        prev_disparity <= prev_disparity - {~q_m[8], 1'b0} +  current_disparity; // {~q_m[8], 1'b0} equivalant to ~q_m[8]*2
                    end
                end
            end
    end
end

endmodule