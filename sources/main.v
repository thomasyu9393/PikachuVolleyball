`timescale 1ns / 1ps
module main(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    input  [3:0] usr_sw,
    output [3:0] usr_led,
   
    // VGA specific I/O ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE
);
 
localparam [3:0] S_MAIN_INIT    = 0,
                 S_MAIN_START   = 1,
                 S_MAIN_WAIT    = 2,
                 S_MAIN_JIZZ    = 3,
                 S_MAIN_DISPLAY = 4,
                 S_MAIN_SPEED   = 5,
                 S_MAIN_NXT_POS = 6,
                 S_MAIN_ADJUST  = 7,
                 S_MAIN_TOUCHED = 8,
                 S_MAIN_CAL     = 9,
                 S_MAIN_FIN     = 10;
 
// Declare system variables
wire [3:0]  btn_pressed;
reg  [3:0]  P, P_next;
reg is_smashing = 0;

 
reg  [31:0] clk_wait, clk_ball, clk_gravity;
reg  [31:0] speed_up;
reg  [9:0] jumping;
reg  [1:0] jumps;
reg  [31:0] clk_pika, clk_pika_bot;
reg  [31:0] clk_cloud1, clk_cloud2;
wire [9:0]  pos_cloud1, pos_cloud2;
wire        regn_ball, regn_pika, regn_pika_bot;
wire        regn_cloud1, regn_cloud2, regn_score, regn_score2, regn_gameover, regn_youwin, regn_p_start;
 
// declare SRAM control signals
wire [16:0] sram_addr_bg, sram_addr_cloud1, sram_addr_cloud2, sram_addr_score;
wire [16:0] sram_addr_pika, sram_addr_pika_bot, sram_addr_ball, sram_addr_score2, sram_addr_gameover, sram_addr_youwin, sram_addr_p_start;
wire [11:0] data_in;
wire [11:0] data_out_bg, data_out_cloud1, data_out_cloud2, data_out_score;
wire [11:0] data_out_pika, data_out_pika_bot, data_out_ball, data_out_score2, data_out_gameover, data_out_youwin, data_out_p_start;
wire        sram_we, sram_en;
 
// General VGA control signals
wire vga_clk;         // 50MHz clock for VGA control
wire video_on;        // when video_on is 0, the VGA controller is sending
                      // synchronization signals to the display device.
 
wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
                      // based for the new coordinate (pixel_x, pixel_y)
 
wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639)
wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)
 
reg  [11:0] rgb_reg;  // RGB value for the current pixel
reg  [11:0] rgb_next; // RGB value for the next pixel
reg  [3:0] now_s1, now_s2;
assign usr_led = now_s1;
// Application-specific VGA signals
reg  [17:0] pixel_addr_bg, pixel_addr_cloud1, pixel_addr_cloud2, pixel_addr_score;
reg  [17:0] pixel_addr_pika, pixel_addr_pika_bot, pixel_addr_ball, pixel_addr_score2, pixel_addr_gameover, pixel_addr_youwin, pixel_addr_p_start;
 
// Declare the video buffer size
localparam VBUF_W = 320; // video buffer width
localparam VBUF_H = 240; // video buffer height
 
// Set parameters for the images
localparam PIKA_W = 41;
localparam PIKA_H = 42;
localparam BALL_W = 30;
localparam SCORE_H = 30;
localparam SCORE_W = 24;
localparam BALL_H = 30;
localparam CLOUD_W = 45;
localparam CLOUD_H = 20;
localparam gameover_W = 141;
localparam gameover_H = 15;
localparam youwin_W = 85;
localparam youwin_H = 15;
localparam p_start_W = 189;
localparam p_start_H = 15;

localparam PIKA_VPOS = 173; // Vertical location of the pika.
reg [31:0] PIKA_HPOS_R = 319;
reg [31:0] PIKA_BOT_VPOS = 173;
reg [31:0] PIKA_BOT_HPOS_R = 40;
localparam CLOUD1_VPOS = 27;
localparam CLOUD2_VPOS = 38;

localparam SCORE_VPOS = 25;
localparam SCORE_L = 40;//320-40=280-24=256
localparam SCORE2_VPOS = 25;
localparam SCORE2_L = 256;

localparam gameover_VPOS = 120;
localparam gameover_L = 90;
localparam youwin_VPOS = 120;
localparam youwin_L = 118;
localparam p_start_VPOS = 120;
localparam p_start_L = 66;

reg signed [31:0] BALL_VPOS_TOP = 5;
reg signed [31:0] BALL_HPOS_L = 278;
reg signed [31:0] BALL_HPOS_R = 11;
reg signed [31:0] BALL_VPOS_TOP_NXT, BALL_VPOS_TOP_CAL;
reg signed [31:0] BALL_HPOS_L_NXT, BALL_HPOS_L_CAL;
reg signed [31:0] BALL_HPOS_R_NXT, BALL_HPOS_R_CAL;
reg last_win = 0; // Begin with the player.
reg signed [31:0] speed_x, speed_y;
reg        [31:0] gravity = 1;
reg               g_en = 0;
 
reg [17:0] addr_pika[0:4]; // Address array for images.
reg [17:0] addr_pika_bot[0:4];
reg [17:0] addr_ball[0:4];
reg [17:0] addr_score[0:7];

initial begin
  addr_pika[0] = 0;               /* Addr for pika image #1 */
  addr_pika[1] = PIKA_W*PIKA_H;   /* Addr for pika image #2 */
  addr_pika[2] = PIKA_W*PIKA_H*2;
  addr_pika[3] = PIKA_W*PIKA_H*3;
  addr_pika[4] = PIKA_W*PIKA_H*4;
 
  addr_pika_bot[0] = 0;
  addr_pika_bot[1] = PIKA_W*PIKA_H;
  addr_pika_bot[2] = PIKA_W*PIKA_H*2;
  addr_pika_bot[3] = PIKA_W*PIKA_H*3;
  addr_pika_bot[4] = PIKA_W*PIKA_H*4;
 
  addr_ball[0] = 0;
  addr_ball[1] = BALL_W*BALL_H;
  addr_ball[2] = BALL_W*BALL_H*2;
  addr_ball[3] = BALL_W*BALL_H*3;
  addr_ball[4] = BALL_W*BALL_H*4;

  addr_score[0] = 0;
  addr_score[1] = SCORE_H*SCORE_W;
  addr_score[2] = SCORE_H*SCORE_W*2;
  addr_score[3] = SCORE_H*SCORE_W*3;
  addr_score[4] = SCORE_H*SCORE_W*4;
  addr_score[5] = SCORE_H*SCORE_W*5;
  addr_score[6] = SCORE_H*SCORE_W*6;
  addr_score[7] = SCORE_H*SCORE_W*7;
end
 
// Instiantiate the VGA sync signal generator
vga_sync vs0(
  .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
  .visible(video_on), .p_tick(pixel_tick),
  .pixel_x(pixel_x), .pixel_y(pixel_y)
);
 
clk_divider#(2) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(vga_clk)
);

wire btn1_moveup, btn3_movedown;

btn_move btn_db0(.clk(clk), .btn_input(usr_btn[0]), .btn_output(btn_pressed[0]));
debounce btn_db1(.clk(clk), .btn_input(usr_btn[1]), .btn_output(btn_pressed[1]));
btn_move btn_db2(.clk(clk), .btn_input(usr_btn[2]), .btn_output(btn_pressed[2]));
debounce btn_db3(.clk(clk), .btn_input(usr_btn[3]), .btn_output(btn_pressed[3]));
debounce_ericyu btn1_move(.pb_1(usr_btn[1]), .clk(clk), .pb_out(btn1_moveup));
debounce_ericyu btn3_move(.pb_1(usr_btn[3]), .clk(clk), .pb_out(btn3_movedown));

//debounce_ericyu(input pb_1, clk, output pb_out);
// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block.
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W*VBUF_H), .FILE("background.mem"))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_bg), .data_i(data_in), .data_o(data_out_bg));
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(PIKA_W*PIKA_H*5), .FILE("pika.mem"))
  ram1 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_pika), .data_i(data_in), .data_o(data_out_pika));
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(PIKA_W*PIKA_H*5), .FILE("pika.mem"))
  ram2 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_pika_bot), .data_i(data_in), .data_o(data_out_pika_bot));
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(BALL_W*BALL_H*5), .FILE("ball.mem"))
  ram3 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_ball), .data_i(data_in), .data_o(data_out_ball));
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(CLOUD_W*CLOUD_H), .FILE("cloud.mem"))
  ram4 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_cloud1), .data_i(data_in), .data_o(data_out_cloud1));
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(CLOUD_W*CLOUD_H), .FILE("cloud.mem"))
  ram5 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_cloud2), .data_i(data_in), .data_o(data_out_cloud2));

sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(SCORE_H*SCORE_W*8), .FILE("nums.mem"))
  ram6 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_score), .data_i(data_in), .data_o(data_out_score));

sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(SCORE_H*SCORE_W*8), .FILE("nums.mem"))
  ram7 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_score2), .data_i(data_in), .data_o(data_out_score2));
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(gameover_H*gameover_W), .FILE("game_over.mem"))
  ram8 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_gameover), .data_i(data_in), .data_o(data_out_gameover));
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(youwin_H*youwin_W), .FILE("you win.mem"))
  ram9 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_youwin), .data_i(data_in), .data_o(data_out_youwin));
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(p_start_H*p_start_W), .FILE("p_start.mem"))
  ram10 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_p_start), .data_i(data_in), .data_o(data_out_p_start));

assign sram_we = usr_sw[3]; // In this demo, we do not write the SRAM. However, if
                            // you set 'sram_we' to 0, Vivado fails to synthesize
                            // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;         // Here, we always enable the SRAM block.
assign sram_addr_bg = pixel_addr_bg;
assign sram_addr_pika = pixel_addr_pika;
assign sram_addr_pika_bot = pixel_addr_pika_bot;
assign sram_addr_ball = pixel_addr_ball;
assign sram_addr_cloud1 = pixel_addr_cloud1;
assign sram_addr_cloud2 = pixel_addr_cloud2;
assign sram_addr_score = pixel_addr_score;
assign sram_addr_score2 = pixel_addr_score2;
assign sram_addr_gameover = pixel_addr_gameover;
assign sram_addr_youwin = pixel_addr_youwin;
assign sram_addr_p_start = pixel_addr_p_start;

assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------
 
// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;
 
// ------------------------------------------------------------------------
// Finite State Machine
always @(posedge clk) begin
  if (~reset_n)
    P <= S_MAIN_INIT;
  else
    P <= P_next;
end
 
always @(*) begin
  case(P)
    S_MAIN_INIT:
      P_next = S_MAIN_START;
    S_MAIN_START:
      if (btn_pressed)
        P_next = S_MAIN_WAIT;
      else
        P_next = S_MAIN_START;
    S_MAIN_WAIT:
      if(now_s1 == 7 || now_s2 == 7) P_next = S_MAIN_FIN;
      else if (clk_wait == 200_000_000)
        P_next = S_MAIN_JIZZ;
      else
        P_next = S_MAIN_WAIT;
    S_MAIN_JIZZ:
      P_next = S_MAIN_DISPLAY;
    S_MAIN_DISPLAY:
      if (BALL_VPOS_TOP >= 185)
        P_next = S_MAIN_TOUCHED;
      else if (clk_wait == 3_000_000)
        P_next = S_MAIN_SPEED;
      else
        P_next = S_MAIN_DISPLAY;
    S_MAIN_SPEED:
      P_next = S_MAIN_NXT_POS;
    S_MAIN_NXT_POS:
      P_next = S_MAIN_ADJUST;
    S_MAIN_ADJUST:
      P_next = S_MAIN_DISPLAY;
    S_MAIN_TOUCHED:
      P_next = S_MAIN_CAL;
    S_MAIN_CAL:
      P_next = S_MAIN_WAIT;
    S_MAIN_FIN:
      if(btn_pressed) P_next = S_MAIN_WAIT;
      else P_next = S_MAIN_FIN;
    default:
      P_next = S_MAIN_INIT;
  endcase
end
 
always @(posedge clk) begin
  if (~reset_n || (P != S_MAIN_WAIT && P != S_MAIN_DISPLAY)) begin
    clk_wait <= 0;
  end else begin
    clk_wait <= clk_wait + 1;
  end
end
//-------------------------------------------------------------------------
assign regn_p_start =
          pixel_y >= (p_start_VPOS<<1) && pixel_y < (p_start_VPOS + p_start_H)<<1 &&
          (pixel_x + (p_start_W<<1) - 1) >= ((p_start_L+p_start_W-1)<<1) && pixel_x <= ((p_start_L+p_start_W-1)<<1);
          
always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr_p_start <= 0;
  end else begin
    if (regn_p_start)
      pixel_addr_p_start <= ((pixel_y>>1) - p_start_VPOS)*p_start_W +
                        ((pixel_x + (p_start_W<<1) - 1 - ((p_start_L+p_start_W-1)<<1)) >> 1);
    else
      pixel_addr_p_start <= 0;
  end
end

//-------------------------------------------------------------------------
// SCORE START

always@(posedge clk) begin
  if(~reset_n || (P == S_MAIN_FIN && P_next == S_MAIN_WAIT)) begin
    now_s1 <= 0;
    now_s2 <= 0;
  end
  else if(P == S_MAIN_CAL) begin
    if(last_win == 0) now_s1 <= now_s1 + 1;
    else if(last_win == 1) now_s2 <= now_s2 + 1;
  end
end

assign regn_score =
          pixel_y >= (SCORE_VPOS<<1) && pixel_y < (SCORE_VPOS + SCORE_H)<<1 &&
          (pixel_x + (SCORE_W<<1) - 1) >= ((SCORE_L+SCORE_W-1)<<1) && pixel_x <= ((SCORE_L+SCORE_W-1)<<1);
assign regn_score2 =
          pixel_y >= (SCORE2_VPOS<<1) && pixel_y < (SCORE2_VPOS + SCORE_H)<<1 &&
          (pixel_x + (SCORE_W<<1) - 1) >= ((SCORE2_L+SCORE_W-1)<<1) && pixel_x <= ((SCORE2_L+SCORE_W-1)<<1);
          
assign regn_gameover =
          pixel_y >= (gameover_VPOS<<1) && pixel_y < (gameover_VPOS + gameover_H)<<1 &&
          (pixel_x + (gameover_W<<1) - 1) >= ((gameover_L+gameover_W-1)<<1) && pixel_x <= ((gameover_L+gameover_W-1)<<1);
assign regn_youwin =
          pixel_y >= (youwin_VPOS<<1) && pixel_y < (youwin_VPOS + youwin_H)<<1 &&
          (pixel_x + (youwin_W<<1) - 1) >= ((youwin_L+youwin_W-1)<<1) && pixel_x <= ((youwin_L+youwin_W-1)<<1);
          
          
always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr_score <= 0;
  end else begin
    if (regn_score)
      pixel_addr_score <= addr_score[now_s1] +
                        ((pixel_y>>1) - SCORE_VPOS)*SCORE_W +
                        ((pixel_x + (SCORE_W<<1) - 1 - ((SCORE_L+SCORE_W-1)<<1)) >> 1);
    else
      pixel_addr_score <= 0;
  end
end

always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr_score2 <= 0;
  end else begin
    if (regn_score2)
      pixel_addr_score2 <= addr_score[now_s2] +
                        ((pixel_y>>1) - SCORE2_VPOS)*SCORE_W +
                        ((pixel_x + (SCORE_W<<1) - 1 - ((SCORE2_L+SCORE_W-1)<<1)) >> 1);
    else
      pixel_addr_score2 <= 0;
  end
end

always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr_gameover <= 0;
  end else begin
    if (regn_gameover)
      pixel_addr_gameover <= ((pixel_y>>1) - gameover_VPOS)*gameover_W +
                        ((pixel_x + (gameover_W<<1) - 1 - ((gameover_L+gameover_W-1)<<1)) >> 1);
    else
      pixel_addr_gameover <= 0;
  end
end
always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr_youwin <= 0;
  end else begin
    if (regn_youwin)
      pixel_addr_youwin <= ((pixel_y>>1) - youwin_VPOS)*youwin_W +
                        ((pixel_x + (youwin_W<<1) - 1 - ((youwin_L+youwin_W-1)<<1)) >> 1);
    else
      pixel_addr_youwin <= 0;
  end
end

// ------------------------------------------------------------------------
// BALL
reg [31:0] smash_cnt_down = 0; // smashing for 0.5sec
always @(posedge clk) begin
  if (~reset_n || smash_cnt_down == 10000000) smash_cnt_down <= 0;
  else if (is_smashing) smash_cnt_down <= smash_cnt_down + 1;
end
always @(posedge clk) begin
  if (~reset_n || smash_cnt_down == 10000000) is_smashing <= 0;
  else if (btn_pressed[3] && usr_sw[0] == 0) is_smashing <= 1;
end

always @(posedge clk) begin
  if (~reset_n) begin
    last_win <= 0;
  end else if (P == S_MAIN_TOUCHED) begin
    last_win <= (BALL_HPOS_L < 160 ? 1 : 0);
  end
end
 
always @(posedge clk) begin
  if (~reset_n || P == S_MAIN_JIZZ) begin
    clk_ball <= 0;
  end else if (P == S_MAIN_DISPLAY && speed_x > 0) begin
    if (clk_ball[25:23] == 3'b100 && (&clk_ball[22:0]) == 1)
      clk_ball <= 0;
    else
      clk_ball <= clk_ball + 1;
  end else if (P == S_MAIN_DISPLAY && speed_x < 0) begin
    if (clk_ball == 0)
      clk_ball[25:0] <= 26'b100_11111_11111_11111_11111_111;
    else
      clk_ball <= clk_ball - 1;
  end
end
 
always @(posedge clk) begin
  if (~reset_n || P == S_MAIN_JIZZ) begin
    clk_gravity <= 0;
  end else if (P == S_MAIN_SPEED) begin
    clk_gravity <= (clk_gravity == 1 ? 0 : 1);
  end
end
 
assign regn_ball =
          pixel_y >= (BALL_VPOS_TOP<<1) && pixel_y < (BALL_VPOS_TOP + BALL_H)<<1 &&
          (pixel_x + (BALL_W<<1) - 1) >= ((BALL_HPOS_L+BALL_W-1)<<1) && pixel_x <= ((BALL_HPOS_L+BALL_W-1)<<1);
 
reg [3:0] last_touched;
 
always @(posedge clk) begin //speed
  if (~reset_n || P == S_MAIN_JIZZ) begin
    speed_x <= 0;
    speed_y <= -10;
  end else if (P == S_MAIN_SPEED) begin
    if (BALL_VPOS_TOP <= 0) begin
      speed_y <= (-1) * speed_y;
    end else if (BALL_VPOS_TOP <= (PIKA_VPOS+32-jumping) && (PIKA_VPOS - BALL_VPOS_TOP <= 30+jumping) &&
                 BALL_HPOS_L >= (PIKA_HPOS_R - 21) && BALL_HPOS_L <= PIKA_HPOS_R) begin
      //speed_x <= (speed_x > 0 ? speed_x : (-1) * speed_x); //right of pika
      speed_x <= 8;
      speed_y <= 10;
    end else if (BALL_VPOS_TOP <= (PIKA_VPOS+32-jumping) && (PIKA_VPOS - BALL_VPOS_TOP <= 30+jumping) &&
                 BALL_HPOS_L >= (PIKA_HPOS_R - 41 - 20) && BALL_HPOS_L <= PIKA_HPOS_R) begin // ============================
        if(is_smashing && PIKA_VPOS - jumping < 173)begin
            if(PIKA_HPOS_R < 240)begin
                speed_x <= -25;
                speed_y <= -10;
            end else begin
                speed_x <= -25;
                speed_y <= -5;
            end
        end else begin
            speed_x <= -8;//?t????t??
            speed_y <= 10;
        end
    end else if (BALL_VPOS_TOP <= PIKA_BOT_VPOS && PIKA_BOT_VPOS - BALL_VPOS_TOP <= 30 &&
                 BALL_HPOS_L + 30 <= PIKA_BOT_HPOS_R - 20 && BALL_HPOS_L + 30 >= PIKA_BOT_HPOS_R - 40) begin
      //speed_x <= (speed_x < 0 ? speed_x : (-1) * speed_x);
      speed_x <= -8;
      speed_y <= 10;
    end else if (BALL_VPOS_TOP <= PIKA_BOT_VPOS && PIKA_BOT_VPOS - BALL_VPOS_TOP <= 30 &&
                 BALL_HPOS_L >= PIKA_BOT_HPOS_R - 40 && BALL_HPOS_L <= PIKA_BOT_HPOS_R) begin
      //speed_x <= (speed_x >= 0 ? (speed_x == 0 ? 8 : speed_x) : (-1) * speed_x);
      speed_x <= 8;  
      speed_y <= 10;
    end else if (BALL_HPOS_L <= 0 || BALL_HPOS_R <= 0) begin //boundary
      speed_x <= (speed_x >= 0)? -8:8;
    end else if (BALL_HPOS_L <= 160 && BALL_HPOS_L + 29 >= 160 && BALL_VPOS_TOP >= 110) begin
      speed_y <= (-1) * speed_y;
    end else if (last_touched) begin
      speed_x <= (-1) * speed_x;
    /*end else if (BALL_HPOS_L <= 163 && BALL_HPOS_L + 29 >= 160 && BALL_VPOS_TOP >= 140) begin
      speed_x <= (-1) * speed_x;
    end else if (BALL_HPOS_L <= 160 && BALL_HPOS_L + 29 >= 157 && BALL_VPOS_TOP >= 140) begin
      speed_x <= (-1) * speed_x;*/
    end else if (clk_gravity == 1) begin
      speed_y <= speed_y - (speed_x != 0 ? gravity : 0);
    end
  end
end
 
always @(posedge clk) begin //bouncing
  if (~reset_n || (P == S_MAIN_WAIT && clk_wait == 100_000_000)) begin
    BALL_VPOS_TOP <= 5;
    BALL_VPOS_TOP_NXT <= 5;
    if (last_win == 0) begin
      BALL_HPOS_L <= 278;
      BALL_HPOS_R <= 11;
      BALL_HPOS_L_NXT <= 278;
      BALL_HPOS_R_NXT <= 11;
    end else begin
      BALL_HPOS_L <= 11;
      BALL_HPOS_R <= 278;
      BALL_HPOS_L_NXT <= 11;
      BALL_HPOS_R_NXT <= 278;
    end
    last_touched <= 0;
  end else if (P == S_MAIN_DISPLAY) begin
    BALL_VPOS_TOP <= BALL_VPOS_TOP_NXT;
    BALL_HPOS_L <= BALL_HPOS_L_NXT;
    BALL_HPOS_R <= BALL_HPOS_R_NXT;
  end else if (P == S_MAIN_NXT_POS) begin
    BALL_VPOS_TOP_CAL <= BALL_VPOS_TOP - speed_y;
    BALL_HPOS_L_CAL <= BALL_HPOS_L + speed_x;
    BALL_HPOS_R_CAL <= BALL_HPOS_R - speed_x;
  end else if (P == S_MAIN_ADJUST) begin
    if (BALL_VPOS_TOP_CAL < 0) begin
      BALL_VPOS_TOP_NXT <= 0;
    end else if (BALL_VPOS_TOP_CAL >= 185) begin
      BALL_VPOS_TOP_NXT <= 185;
    end else begin
      BALL_VPOS_TOP_NXT <= BALL_VPOS_TOP_CAL;
    end
    if (BALL_HPOS_L_CAL < 0) begin
      BALL_HPOS_L_NXT <= 0;
      BALL_HPOS_R_NXT <= 289;
      last_touched <= 0;
    end else if (BALL_HPOS_R_CAL < 0) begin
      BALL_HPOS_L_NXT <= 289;
      BALL_HPOS_R_NXT <= 0;
      last_touched <= 0;
    end else if (speed_x > 0) begin 
    
    
      if (BALL_HPOS_L + 30 <= PIKA_BOT_HPOS_R - 40 &&
          BALL_HPOS_L_CAL + 30 >= PIKA_BOT_HPOS_R - 40 &&
          BALL_VPOS_TOP_CAL + 30 >= PIKA_BOT_VPOS) begin // BOT
        BALL_HPOS_L_NXT <= PIKA_BOT_HPOS_R - 40 - 30;
        BALL_HPOS_R_NXT <= 289 - PIKA_BOT_HPOS_R + 40 + 30;
        last_touched <= 1;
      end else if (BALL_HPOS_L + 30 <= 160 &&
                   BALL_HPOS_L_CAL + 30 >= 160 &&
                   BALL_VPOS_TOP_CAL >= 110) begin
        BALL_HPOS_L_NXT <= 127;
        BALL_HPOS_R_NXT <= 289 - 127;
        last_touched <= 5;
      end else if (BALL_HPOS_L + 30 <= PIKA_HPOS_R - 40 &&
                   BALL_HPOS_L_CAL + 30 >= PIKA_HPOS_R - 40 &&
                   BALL_VPOS_TOP_CAL + 30 >= (PIKA_VPOS - jumping)) begin // player
        BALL_HPOS_L_NXT <= PIKA_HPOS_R - 40 - 30;
        BALL_HPOS_R_NXT <= 289 - PIKA_HPOS_R + 40 + 30;
        last_touched <= 2;
      end else begin
        BALL_HPOS_L_NXT <= BALL_HPOS_L_CAL;
        BALL_HPOS_R_NXT <= BALL_HPOS_R_CAL;
        last_touched <= 0;
      end
      
      
    end else if (speed_x < 0) begin
      if (BALL_HPOS_L >= PIKA_HPOS_R &&
          BALL_HPOS_L_CAL <= PIKA_HPOS_R &&
          BALL_VPOS_TOP_CAL + 30 >= (PIKA_VPOS - jumping)) begin
        BALL_HPOS_L_NXT <= PIKA_HPOS_R;
        BALL_HPOS_R_NXT <= 289 - PIKA_HPOS_R;
        last_touched <= 3;
      end else if (BALL_HPOS_L >= 163 &&
                   BALL_HPOS_L_CAL <= 163 &&
                   BALL_VPOS_TOP_CAL >= 110) begin
        BALL_HPOS_L_NXT <= 163;
        BALL_HPOS_R_NXT <= 289 - 163;
        last_touched <= 6;
      end else if (BALL_HPOS_L >= PIKA_BOT_HPOS_R &&
                   BALL_HPOS_L_CAL <= PIKA_BOT_HPOS_R &&
                   BALL_VPOS_TOP_CAL + 30 >= PIKA_BOT_VPOS) begin
        BALL_HPOS_L_NXT <= PIKA_BOT_HPOS_R;
        BALL_HPOS_R_NXT <= 289 - PIKA_BOT_HPOS_R;
        last_touched <= 4;
      end else begin
        BALL_HPOS_L_NXT <= BALL_HPOS_L_CAL;
        BALL_HPOS_R_NXT <= BALL_HPOS_R_CAL;
        last_touched <= 0;
      end
    end else begin
      BALL_HPOS_L_NXT <= BALL_HPOS_L_CAL;
      BALL_HPOS_R_NXT <= BALL_HPOS_R_CAL;
      last_touched <= 0;
    end
  end
end
 
always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr_ball <= 0;
  end else begin
    if (regn_ball)
      pixel_addr_ball <= addr_ball[clk_ball[25:23]] +
                        ((pixel_y>>1) - BALL_VPOS_TOP)*BALL_W +
                        ((pixel_x + (BALL_W<<1) - 1 - ((BALL_HPOS_L+BALL_W-1)<<1)) >> 1);
    else
      pixel_addr_ball <= 0;
  end
end
 
// ------------------------------------------------------------------------
// PIKA PLAYER

//JUMP START 
reg pika20;
always@(posedge clk) begin
    if(~reset_n) pika20 <= 0;
    else pika20 <= clk_pika[18];
end

always@(posedge clk) begin
    if(~reset_n || P == S_MAIN_WAIT) begin
        jumps <= 0;
        jumping <= 0;
    end
    else if(usr_sw[0] == 1)begin
        jumps <= 2;
        if(pika20 == 0 && clk_pika[18] == 1)begin
            if(usr_btn[1])begin
                if(jumping < 95)jumping <= jumping + 1;
            end
            if(usr_btn[3])begin
                if(jumping > 0)jumping <= jumping - 1;
            end
        end
        
    end
    else if(jumps != 0) begin     
        /*case(jumping)
            10'd95: jumps <= 2;
            10'd0: jumps <= 0;
            default: jumps <= jumps;
        endcase*/
        if(jumping >= 100)begin // when jumping=1, 1-2=-1, leads to a large number
            jumps <= 0;
            jumping <= 0;
        end
        else if(jumping >= 95)jumps <= 2;
        else if(jumping <= 0)begin
            jumps <= 0;
            jumping <= 0;
        end
        
        
        if(pika20 == 0 && clk_pika[18] == 1) begin
            case(jumps)
            2'd1: begin
                if(jumping > 80) jumping <= jumping + 1;
                else jumping <= jumping + 2;
              end
            2'd2: begin
                if(jumping > 80) jumping <= jumping - 1;
                else jumping <= jumping - 2;
            end
            default: jumping <= 0;
            endcase
        end
    end
    else begin
        if(btn_pressed[1] && P != S_MAIN_WAIT && P != S_MAIN_TOUCHED) begin
            jumps <= 1;
            jumping <= 1;
        end
    end
end

//JUMP END

always @(posedge clk) begin
  if (~reset_n || (P == S_MAIN_WAIT && clk_wait == 100_000_000)) begin
    PIKA_HPOS_R <= 319;
  end else if (btn_pressed[0] && P != S_MAIN_WAIT && P != S_MAIN_TOUCHED) begin
    PIKA_HPOS_R <= (PIKA_HPOS_R < 319 ? PIKA_HPOS_R + 1 : PIKA_HPOS_R);
  end else if (btn_pressed[2] && P != S_MAIN_WAIT && P != S_MAIN_TOUCHED) begin
    PIKA_HPOS_R <= (PIKA_HPOS_R > 203 ? PIKA_HPOS_R - 1 : PIKA_HPOS_R);
  end
end


always @(posedge clk) begin
  if (~reset_n || P == S_MAIN_JIZZ) begin
    clk_pika <= 0;
  end else begin
    if (clk_pika[25:23] == 3'b100 && (&clk_pika[22:0]) == 1)
      clk_pika <= 0;
    else
      clk_pika <= clk_pika + 1;
  end
end
 
assign regn_pika =
          pixel_y >= ((PIKA_VPOS-jumping)<<1) && pixel_y < (PIKA_VPOS - jumping + PIKA_H)<<1 &&
          (pixel_x + (PIKA_W<<1) - 1) >= (PIKA_HPOS_R<<1) && pixel_x <= (PIKA_HPOS_R<<1);
 
always @(posedge clk) begin
  if (~reset_n || (P == S_MAIN_WAIT && clk_wait == 100_000_000)) begin
    PIKA_HPOS_R <= 319;
  end else if (btn_pressed[0] && P != S_MAIN_WAIT && P != S_MAIN_TOUCHED) begin
    PIKA_HPOS_R <= (PIKA_HPOS_R < 319 ? PIKA_HPOS_R + 1 : PIKA_HPOS_R);
  end else if (btn_pressed[2] && P != S_MAIN_WAIT && P != S_MAIN_TOUCHED) begin
    PIKA_HPOS_R <= (PIKA_HPOS_R > 203 ? PIKA_HPOS_R - 1 : PIKA_HPOS_R);
  end
end
 
always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr_pika <= 0;
  end else begin
    if (regn_pika)
        pixel_addr_pika <= addr_pika[clk_pika[25:23]] +
                        ((pixel_y>>1) - PIKA_VPOS + jumping)*PIKA_W +
                        PIKA_W - ((pixel_x + (PIKA_W<<1) - 1 - (PIKA_HPOS_R<<1)) >> 1) - 1;
  end
end
 
// ------------------------------------------------------------------------
// PIKA BOT
always @(posedge clk) begin
  if (~reset_n || P == S_MAIN_JIZZ) begin
    clk_pika_bot <= 0;
  end else begin
    if (clk_pika_bot[25:23] == 3'b100 && (&clk_pika_bot[22:0]) == 1)
      clk_pika_bot <= 0;
    else
      clk_pika_bot <= clk_pika_bot + 1;
  end
end
 
assign regn_pika_bot =
          pixel_y >= (PIKA_BOT_VPOS<<1) && pixel_y < (PIKA_BOT_VPOS + PIKA_H)<<1 &&
          (pixel_x + (PIKA_W<<1) - 1) >= (PIKA_BOT_HPOS_R<<1) && pixel_x <= (PIKA_BOT_HPOS_R<<1);
 
always @(posedge clk) begin
  if (~reset_n || (P == S_MAIN_WAIT && clk_wait == 100_000_000)) begin
    PIKA_BOT_HPOS_R <= 40;
  end else if ((&clk_pika_bot[18:0]) == 1 && usr_sw[1] == 0 && BALL_HPOS_L < 145 && P != S_MAIN_TOUCHED) begin
    if (BALL_HPOS_L + 15 < PIKA_BOT_HPOS_R - 20)
      PIKA_BOT_HPOS_R <= (PIKA_BOT_HPOS_R > 40 ? PIKA_BOT_HPOS_R - 1 : PIKA_BOT_HPOS_R);
    else
      PIKA_BOT_HPOS_R <= (PIKA_BOT_HPOS_R < 159 ? PIKA_BOT_HPOS_R + 1 : PIKA_BOT_HPOS_R);
  end
end
 
always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr_pika_bot <= 0;
  end begin
    if (regn_pika_bot)
        pixel_addr_pika_bot <= addr_pika_bot[clk_pika_bot[25:23]] +
                          ((pixel_y>>1) - PIKA_BOT_VPOS)*PIKA_W +
                          ((pixel_x + (PIKA_W<<1) - 1 - (PIKA_BOT_HPOS_R<<1)) >> 1);
  end
end
 
// ------------------------------------------------------------------------
// CLOUD
assign pos_cloud1 = clk_cloud1[29:20]; // the x position of the right edge of the cloud image
                                       // in the 640x480 VGA screen
assign pos_cloud2 = clk_cloud2[27:18];
 
always @(posedge clk) begin
  if (~reset_n) begin
    clk_cloud1 <= 0;
    clk_cloud2 <= 0;
  end else begin
    if (clk_cloud1[31:21] > VBUF_W + CLOUD_W)
      clk_cloud1 <= 0;
    else
      clk_cloud1 <= clk_cloud1 + 1;
    if (clk_cloud2[29:19] > VBUF_W + CLOUD_W)
      clk_cloud2 <= 0;
    else
      clk_cloud2 <= clk_cloud2 + 1;
  end
end
 
assign regn_cloud1 =
          pixel_y >= (CLOUD1_VPOS<<1) && pixel_y < (CLOUD1_VPOS + CLOUD_H)<<1 &&
          (pixel_x + (CLOUD_W<<1) - 1) >= pos_cloud1 && pixel_x <= pos_cloud1;
assign regn_cloud2 =
          pixel_y >= (CLOUD2_VPOS<<1) && pixel_y < (CLOUD2_VPOS + CLOUD_H)<<1 &&
          (pixel_x + (CLOUD_W<<1) - 1) >= pos_cloud2 && pixel_x <= pos_cloud2;
 
always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr_bg <= 0;
    pixel_addr_cloud1 <= 0;
    pixel_addr_cloud2 <= 0;
  end begin
    // Scale up a 320x240 image for the 640x480 display.
    // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
    pixel_addr_bg <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
 
    if (regn_cloud1)
        pixel_addr_cloud1 <= ((pixel_y>>1) - CLOUD1_VPOS)*CLOUD_W +
                             ((pixel_x + (CLOUD_W*2-1) - pos_cloud1)>>1);
 
    if (regn_cloud2)
        pixel_addr_cloud2 <= ((pixel_y>>1) - CLOUD2_VPOS)*CLOUD_W +
                             ((pixel_x + (CLOUD_W*2-1) - pos_cloud2)>>1);
  end
end
// End of the CLOUD.
// ------------------------------------------------------------------------
 
// ------------------------------------------------------------------------
// Send the video data in the sram to the VGA controller
always @(posedge clk) begin
  if (pixel_tick) rgb_reg <= rgb_next;
end
 
always @(*) begin
  if (~video_on)
    rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
 // RGB value at (pixel_x, pixel_y)
  else if (regn_p_start && P == S_MAIN_START && data_out_p_start != 12'h0f0)
    rgb_next = data_out_p_start; // RGB value at (pixel_x, pixel_y)
  else if (data_out_ball != 12'h0f0 && P != S_MAIN_INIT && P != S_MAIN_START)
    rgb_next = data_out_ball; // RGB value at (pixel_x, pixel_y)
  else if (regn_pika && data_out_pika != 12'h0f0)
    rgb_next = data_out_pika;
  else if (regn_pika_bot && data_out_pika_bot != 12'h0f0)
    rgb_next = data_out_pika_bot;
  else if (regn_score && data_out_score != 12'h0f0)
    rgb_next = data_out_score;
  else if (regn_score2 && data_out_score2 != 12'h0f0)
    rgb_next = data_out_score2;
  else if (regn_cloud1 && data_out_cloud1 != 12'h0f0)
    rgb_next = data_out_cloud1;
  else if (regn_cloud2 && data_out_cloud2 != 12'h0f0)
    rgb_next = data_out_cloud2;
  else if (regn_gameover && data_out_gameover != 12'h0f0 && now_s1 == 7 )
    rgb_next = data_out_gameover;
  else if (regn_youwin && data_out_youwin != 12'h0f0 && now_s2 == 7 )
    rgb_next = data_out_youwin;
  else 
    rgb_next = data_out_bg;
end
// End of the video data display code.
// ------------------------------------------------------------------------
 
endmodule
 