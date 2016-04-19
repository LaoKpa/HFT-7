/*
 * Seven-segment LED emulator
 *
 * Stephen A. Edwards, Columbia University
 */

module Frame(input logic clk, reset,
             input logic [5:0] x, y,
             input logic [4:0] char,
             input logic [23:0] color,
             output logic [7:0] VGA_R, VGA_G, VGA_B,
             output logic VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_n, VGA_SYNC_n);

/*
 * 640 X 480 VGA timing for a 50 MHz clock: one pixel every other cycle
 *
 * HCOUNT 1599 0             1279       1599 0
 *             _______________              ________
 * ___________|    Video      |____________|  Video
 *
 *
 * |SYNC| BP |<-- HACTIVE -->|FP|SYNC| BP |<-- HACTIVE
 *       _______________________      _____________
 * |____|       VGA_HS          |____|
 */
   // Parameters for hcount
   parameter HACTIVE      = 11'd 1280,
             HFRONT_PORCH = 11'd 32,
             HSYNC        = 11'd 192,
             HBACK_PORCH  = 11'd 96,
             HTOTAL       = HACTIVE + HFRONT_PORCH + HSYNC + HBACK_PORCH; // 1600

   // Parameters for vcount
   parameter VACTIVE      = 10'd 480,
             VFRONT_PORCH = 10'd 10,
             VSYNC        = 10'd 2,
             VBACK_PORCH  = 10'd 33,
             VTOTAL       = VACTIVE + VFRONT_PORCH + VSYNC + VBACK_PORCH; // 525

   logic [10:0] hcount; // Horizontal counter
                        // Hcount[10:1] indicates pixel column (0-639)
   logic endOfLine;

   always_ff @(posedge clk or posedge reset)
     if (reset) hcount <= 0;
     else if (endOfLine) hcount <= 0;
     else hcount <= hcount + 11'd 1;

   assign endOfLine = hcount == HTOTAL - 1;

   // Vertical counter
   logic [9:0] vcount;
   logic endOfField;

   always_ff @(posedge clk or posedge reset)
     if (reset) vcount <= 0;
     else if (endOfLine)
       if (endOfField) vcount <= 0;
       else vcount <= vcount + 10'd 1;

   assign endOfField = vcount == VTOTAL - 1;

   // Horizontal sync: from 0x520 to 0x5DF (0x57F)
   // 101 0010 0000 to 101 1101 1111
   assign VGA_HS = !( (hcount[10:8] == 3'b101) & !(hcount[7:5] == 3'b111));
   assign VGA_VS = !( vcount[9:1] == (VACTIVE + VFRONT_PORCH) / 2);

   assign VGA_SYNC_n = 1; // For adding sync to video signals; not used for VGA

   // Horizontal active: 0 to 1279     Vertical active: 0 to 479
   // 101 0000 0000  1280	       01 1110 0000  480
   // 110 0011 1111  1599	       10 0000 1100  524
   assign VGA_BLANK_n = !( hcount[10] & (hcount[9] | hcount[8]) ) &
			!( vcount[9] | (vcount[8:5] == 4'b1111) );

   /* VGA_CLK is 25 MHz
    *             __    __    __
    * clk    __|  |__|  |__|
    *
    *             _____       __
    * hcount[0]__|     |_____|
    */
    assign VGA_CLK = hcount[0]; // 25 MHz clock: pixel latched on rising edge

    /* Logic required for drawing characters*/
    logic [10:0] write_p;
    logic [10:0] read_p;
    logic [4:0] frame_buffer[1199:0]; //40 accross by 30 down

    logic [13:0] char_addr;
    logic char_show;

    Character character(.addr(char_addr), .q(char_show), .*);

    assign write_p = 40 * y + x;
    assign read_p = 40 * vcount[9:4] + hcount[10:5];
    assign {VGA_R, VGA_G, VGA_B} = char_show ? color : 24'd0;
    assign char_addr = 0;

    always_ff @(posedge x or posedge y or posedge char) begin
      frame_buffer[x, y] <= char;
    end

endmodule // VGA_LED_Emulator
