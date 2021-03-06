module TOP(
    	Clk,
    	Rst_n,   
   	Rx,    
		RxData,
		R_N,
		R_P,
		L_N,
		L_P,
		Sleep);

/****************************************************************************/

	input           Clk; 					// Тактовый сигнал с платы
	input           Rst_n; 					// Reset
	input           Rx; 						// вход UART RX.
	output [7:0]    RxData; 				// Полученные данные
	output R_N, R_P, L_N, L_P, Sleep; 	// Выходы управления H-мостом моторов
	reg RN_r, RP_r,LN_r,LP_r;				// Регистры для хранения состояни моторов

/****************************************************************************/

	wire          	RxDone; 					// Информация принята корректно.
	wire           tick; 					// Тактовый сигнал для UART приемника
	wire 				RxEn;						// Разрешающий сигнал для приема данных
	wire [3:0]     NBits;					// Количество бит в UART слове
	wire [15:0]    BaudRate; 				// (Отношение частоты тактового сигнала платы к частоте тактового сигнала UART)/16; 
													// Требуется для опредения времени для очередного считывания бита данных из передачи

/****************************************************************************/

	assign 		RxEn = 1'b1	;				// Установка разрешающего сигнала на считывание в 1
	assign 		BaudRate = 16'd325; 		// Тактовая частота платы A-Cute Car 50МГц, стандартная частота используемая для UART в модуле Bluetooth HC-06 = 9600
													// (50 * 10^6)/(16 * 9600) прмерно равно 325
	assign 		NBits = 4'b1000	;		//Используем размер слова 8бит

/****************************************************************************/

// Подключаем модуль приема данных UART
	UART_rs232_rx I_RS232RX(
    	.Clk(Clk),
   	.Rst_n(Rst_n),
    	.RxEn(RxEn),
    	.RxData(RxData),
    	.RxDone(RxDone),
    	.Rx(Rx),
    	.Tick(tick),
    	.NBits(NBits));

// Подключаем модуль генерации импульсов для UART на основании тактовой частоты платы. 
// Представляет из себя простой делитель частоты
	UART_BaudRate_generator I_BAUDGEN(
    	.Clk(Clk),
    	.Rst_n(Rst_n),
    	.Tick(tick),
    	.BaudRate(BaudRate));

	
	// Установка состояния моторов (движение вперед, назад, остановка, поворот вокруг своей оси в одну и другую сторону)
	// В качестве переключения состояний используются двоичные коды символов таблицы ASCII.
	always @(RxData)
	begin

	case (RxData)
	8'b00110000: // 0 (HEX ASCII = 30) -- вперед
	begin
		RP_r = PWM;
		LP_r = 0;
		RN_r = 0;
		LN_r = PWM;
	end
	8'b00110001: // 1 (HEX ASCII = 31) -- остановка
	begin
		RP_r = 1;
		LP_r = 1;
		RN_r = 1;
		LN_r = 1;
	end
	8'b00110010: // 2 (HEX ASCII = 32) -- назад
	begin
		RP_r = 0;
		LP_r = PWM;
		RN_r = PWM;
		LN_r = 0;
	end
	8'b00110011: // 3 (HEX ASCII = 33) -- поворот вокруг своей оси в одну сторону
	begin
		RP_r = 0;
		LP_r = 0;
		RN_r = PWM;
		LN_r = PWM;
	end
	8'b00110100: // 4 (HEX ASCII = 34) -- поворот вокруг своей оси в другую сторону
	begin
		RP_r = PWM;
		LP_r = PWM;
		RN_r = 0;
		LN_r = 0;
	end
	endcase
	end
	 
	assign R_P = RP_r;
	assign L_P = LP_r;
	assign R_N = RN_r;
	assign L_N = LN_r;
	assign Sleep = 1; // Установка флагом режима сниженного энергопотребления в 1 
							// (1 - включение моторов, 0 - режим энергосбережения) 
	 
/****************************************************************************/
	
	//Управление скоростью вращения моторов при помощи ШИМ сигнала.
	
	reg 					PWM; 					//Регистр ШИМ сигнала
	reg	[31:0]		tick1; 				// счетчик отвечающий за генерацию ШИМ с нужным коэффициентом заполнения
	
	
	parameter [31:0]	total_dur = 1000; // Параметр, отвечающий за полной количество тактовых импульсов в одном периоде ШИМ
	parameter [31:0]	high_dur = 400;	// Параметр, отвечающий за коэффициент заполнения.
													// Отношение второго параметра к первому равняется коэффициенту заполнения. 
													// Чем больше это отношение, тем быстрее вращение моторов
													// Второй параметр не может быть больше первого
	
	always @ (posedge Clk)					// Делитель частоты
	begin
		if (tick1 >= total_dur)
		begin
			tick1 <= 1;
		end
		else
		begin
			tick1 <= tick1 + 1;
		end
	end
	
	always @ (posedge Clk)					// Генерация ШИМ
	begin
			PWM <= (tick1 <= high_dur)?1'b1:1'b0;
	end

endmodule
