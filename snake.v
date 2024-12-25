module snake(
    output reg [0:7] LedR, LedG, LedB,
    output reg [2:0] comm,
    output reg       enable,
    output reg [7:0] point,
    input            SYS_CLK,
    input            RST,
    input            PAUSE,
    input            UP, DOWN, LEFT, RIGHT,
	 input [3:0] BCD,     // 4-bit BCD input
    output reg [6:0] seg
);

    reg [1:0] state;            // 01 is gaming, 10 is end
    reg       game_clk;
    reg       led_clk;  
    
    reg [7:0] map [7:0];        // LED map 8*8, map[x][~y]
    
    reg [2:0] X, Y;             // snake head pos
    reg [2:0] body_mem_x[63:0]; // pos of X *64
    reg [2:0] body_mem_y[63:0]; // pos of Y *64
    reg [5:0] length;           // include head
    
    reg [2:0] item_x, item_y;
    reg       pass;
    reg [7:0] pass_pic [7:0];
    
    reg [6:0] i;
    reg [5:0] j;
    
    reg [24:0] led_counter;
    reg [24:0] move_counter;
    reg [1:0]  move_dir;
    
    integer led_count_to = 50000;   // led clk  1 kHz display
    integer count_to     = 4500000; // game_clk 0.5 Hz
    
	 always @(point) begin
    case (point[3:0])
        4'b0000: seg = 7'b1000000; // 0
        4'b0001: seg = 7'b1111001; // 1
        4'b0010: seg = 7'b0100100; // 2
        4'b0011: seg = 7'b0110000; // 3
        4'b0100: seg = 7'b0011001; // 4
        4'b0101: seg = 7'b0010010; // 5
        4'b0110: seg = 7'b0000010; // 6
        4'b0111: seg = 7'b1111000; // 7
        4'b1000: seg = 7'b0000000; // 8
        4'b1001: seg = 7'b0010000; // 9
        default: seg = 7'b1111111; // blank for invalid BCD (1010 to 1111)
    endcase
	end
	 
	 
	 
    initial begin
        LedR   = 8'b11111111;
        LedG   = 8'b11111111;
        LedB   = 8'b11111111;
        enable = 1'b1;
        comm   = 3'b000;
        
        pass   = 1'b0;
        
        pass_pic[3'b000] = 8'b00000000;
        pass_pic[3'b001] = 8'b11110110;
        pass_pic[3'b010] = 8'b11110110;
        pass_pic[3'b011] = 8'b11110110;
        pass_pic[3'b100] = 8'b11110110;
        pass_pic[3'b101] = 8'b11110110;
        pass_pic[3'b110] = 8'b11110110;
        pass_pic[3'b111] = 8'b11110000;
        
        // 蛇頭 (X=2, Y=2)
        map[3'b010][~3'b010] = 1'b1; // head
        // 蛇的第一節身體 (X=1, Y=2)
        map[3'b001][~3'b010] = 1'b1; // body1
        
        // (不使用第三節身體)
        // map[3'b000][~3'b010] = 1'b1; // body2 <--- 已註解
        
        item_x = 3'b110;
        item_y = 3'b110;
        

        point  = 8'b00000000;
        
        X = 3'b010;
        Y = 3'b010;
        body_mem_x[0] = 3'b010;
        body_mem_y[0] = 3'b010;  // head
        
        // 設定蛇的第一節身體
        body_mem_x[1] = 3'b010;
        body_mem_y[1] = 3'b001;  // body1
        
        // (拿掉原本的第二節身體)
        // body_mem_x[2] = 3'b010;
        // body_mem_y[2] = 3'b000; // body2 <--- 已註解
        
        // 初始化蛇的長度改為 2
        length = 2;
        
        // 狀態：遊戲進行中
        state   = 2'b01;
        // 初始移動方向：向上 (move_dir = 2'b00)
        move_dir = 2'b00;
    end
    
    always @(posedge SYS_CLK) begin
        // 如果按下暫停，則不更新 move_counter
        if (PAUSE == 1'b1) begin
            // do nothing
        end
        else if (move_counter < count_to) begin
            move_counter <= move_counter + 1;
        end
        else begin
            game_clk     <= ~game_clk;
            move_counter <= 25'b0;
        end
        
        // led 週期計數，更新 led_clk
        if (led_counter < led_count_to) begin
            led_counter <= led_counter + 1;
        end
        else begin
            led_counter <= 25'b0;
            led_clk     <= ~led_clk;
        end
    end
    
    // (2) 8*8 LED 顯示掃描：comm 遞增，配合 map → Led?
    always @(posedge led_clk) begin
        if (comm == 3'b111) 
            comm <= 3'b000;
        else
            comm <= comm + 1'b1;
    end
    
    // 依分數顯示不同顏色
    always @(comm) begin
        if (state == 2'b10) begin
            // Game end 狀態 (pass_pic)
            LedG = pass_pic[comm];
            LedB = 8'b11111111;
            LedR = 8'b11111111;
        end
        else begin
            // 分數 >= 2 時，用「綠色」顯示蛇
            if (point >= 8'd2) begin
                LedG = ~map[comm];
                LedB = 8'b11111111;
                LedR = 8'b11111111;
            end
            // 分數 < 2 時，用「藍色」顯示蛇
            else begin
                LedB = ~map[comm];
                LedG = 8'b11111111;
                LedR = 8'b11111111;
            end
        end
        
        // item 用紅色顯示 (comm == item_x → 紅燈打開)
        if (comm == item_x) begin
            LedR[item_y] = 1'b0;
        end
    end
    
    // (3) 根據按鍵狀態，更新蛇的移動方向
    always @(UP or DOWN or LEFT or RIGHT) begin
        if (UP    == 1'b1 && move_dir != 2'b01) move_dir = 2'b00; 
        else if (DOWN  == 1'b1 && move_dir != 2'b00) move_dir = 2'b01; 
        else if (LEFT  == 1'b1 && move_dir != 2'b11) move_dir = 2'b10; 
        else if (RIGHT == 1'b1 && move_dir != 2'b10) move_dir = 2'b11; 
        else ;
    end
    
    // (4) 每逢 game_clk，根據 move_dir 移動蛇頭，並更新蛇身

    always @(posedge game_clk) begin
        // 依照方向改變蛇頭的 X 或 Y
        case(move_dir)
            2'b00 : Y <= Y + 1;  // UP
            2'b01 : Y <= Y - 1;  // DOWN
            2'b10 : X <= X - 1;  // LEFT
            2'b11 : X <= X + 1;  // RIGHT
        endcase
        
        // 在新的頭座標上亮燈
        map[X][~Y] <= 1'b1;
        
        // 若吃到 item，分數+1 並重新放置 item
        if (X == item_x && Y == item_y) begin
            // 簡單檢查是否已達最大分數
            if (point > 8'b11111110) 
                state = 2'b10;   // 達到某條件 → 遊戲結束/通關
            
            // 分數加一
            point = point + 1;  // 或用 shift-left 的方式
            
            // 重設 item 位置 (只是範例)
            if (move_dir == 2'b00 || move_dir == 2'b01) begin
                item_x <= X + 3'b011 + game_clk * 2;
                item_y <= Y - 3'b011 + game_clk;
            end
            else begin
                item_x <= X - 3'b011 - game_clk;
                item_y <= Y + 3'b011 - game_clk * 2;
            end
        end
        
        // 移動蛇尾 → 將原本最後一節在 map 上關燈
        map[body_mem_x[length-1]][~body_mem_y[length-1]] = 1'b0;
        
        // 蛇身座標往前推
        for (i = 1; i < length; i = i + 1) begin
            body_mem_x[length - i] <= body_mem_x[length - i - 1];
            body_mem_y[length - i] <= body_mem_y[length - i - 1];
        end
        
        // 最新蛇頭更新到 body_mem[0]
        body_mem_x[0] = X;
        body_mem_y[0] = Y;
    end
    
endmodule

