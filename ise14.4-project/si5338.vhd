----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    08:42:49 09/11/2013 
-- Design Name: 
-- Module Name:    tca9535 - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity si5338 is
	GENERIC(
    input_clk 		: INTEGER := 50_000_000; --input clock speed from user logic in Hz
	 i2c_address	: std_logic_vector(6 downto 0) := "111" & "0000";
    bus_clk   		: INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz
	port
		(
			clk     		: in std_logic;
			reset			: in std_logic;
			
			done			: out std_logic;
			
			error 		: out std_logic;
			
			SCL 			: inout std_logic;
			SDA 			: inout std_logic
		);
end si5338;

architecture Behavioral of si5338 is

component i2c_master IS
  GENERIC(
    input_clk : INTEGER := 50_000_000; --input clock speed from user logic in Hz
    bus_clk   : INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz
  PORT(
    clk       : IN     STD_LOGIC;                    --system clock
    reset_n   : IN     STD_LOGIC;                    --active low reset
    ena       : IN     STD_LOGIC;                    --latch in command
    addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
    rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
    data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
    busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
    data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    ack_error : INOUT  STD_LOGIC;                    --flag if improper acknowledge from slave
    sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
    scl       : INOUT  STD_LOGIC);                   --serial clock output of i2c bus
END component;

COMPONENT mem_si5338
  PORT (
    clka : IN STD_LOGIC;
    addra : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
  );
END COMPONENT;

signal mem_clk 		: std_logic;
signal mem_addr		: std_logic_vector( 8 downto 0 );
signal mem_data		: std_logic_vector( 23 downto 0 );

signal send_enable 	: std_logic;
signal i2c_rw 			: std_logic;

signal i2c_data_wr   : std_logic_vector(7 downto 0); 
signal i2c_busy      : std_logic;
signal i2c_data_rd   : std_logic_vector(7 downto 0);
signal i2c_ack_error	: std_logic;

attribute S: string;

type state_type is (idle, initial_state, config_state, 
	check_LOS_alarm_state, next_config_state, copy_state, done_state, error_state);  --type of state machine.
signal FSM_si5338 : state_type;
signal FSM_si5338_prev : state_type;
signal error_fsm_last_state : std_logic_vector( 4 downto 0);
attribute S of error_fsm_last_state : signal is "TRUE";

signal wait_counter : integer range 0 to 2**26-1;
signal timeout : integer range 0 to input_clk-1;

signal internal_reset : std_logic;
signal i2c_reset_internal : std_logic;
signal i2c_reset_n : std_logic;

signal busy_prev : std_logic;
signal busy_cnt_global : integer range 0 to 255;

constant WIDTH_BRAM 				: integer := 9;
signal done_sig 					: std_logic;
signal read_data				   : std_logic_vector(7 downto 0);
signal read_data2				   : std_logic_vector(7 downto 0);
signal maximum_entries_bram 	: integer range 0 to 2**WIDTH_BRAM-1; 
signal bram_counter 				: integer range 0 to 2**WIDTH_BRAM-1;

begin

--error <= i2c_ack_error;
--internal_reset <= reset OR i2c_ack_error;
internal_reset <= reset;
i2c_reset_n <= not (internal_reset OR i2c_reset_internal);
done <= done_sig;

mem_clk <= clk;

mem_si5338_inst : mem_si5338
  PORT MAP (
    clka => mem_clk,
    addra => mem_addr,
    douta => mem_data
  );

si5338_proc : process (clk)
    variable busy_cnt : integer range 0 to 255;
	 variable reg_addr : std_logic_vector(7 downto 0);
	 variable reg_val  : std_logic_vector(7 downto 0);
	 variable reg_mask : std_logic_vector(7 downto 0);
	begin    	
		if( rising_edge(clk) ) then
			if( internal_reset = '1' ) then
            send_enable <= '0';
            i2c_data_wr <= (others => '0');
            i2c_rw <= '0';
            done_sig <= '0';
            busy_prev <= '0';
            timeout <= 0;
            busy_cnt_global <= 0;
				FSM_si5338 <= idle;
				
				error <= '1';
				
				read_data <= (others => '0');
				read_data2 <= (others => '0');
				maximum_entries_bram <= 0;
				mem_addr <= (others => '1');
			else
				busy_prev <= i2c_busy;
				busy_cnt := busy_cnt_global;
				
				FSM_si5338_prev <= FSM_si5338;
				
--				timeout <= timeout + 1;
--				if( timeout = input_clk-1 ) then
--				    --FSM_tca9535 <= idle;
--				end if;
				
				if( busy_prev = '0' AND i2c_busy = '1' ) then  --i2c busy just went high
					busy_cnt := busy_cnt + 1;                   --counts the times busy has gone from low to high during transaction
					timeout <= 0;
				end if;
				
				done_sig <= '0';
				
				reg_addr 	:= mem_data(23 downto 16);
				reg_val 		:= mem_data(15 downto 8);
				reg_mask 	:= mem_data(7 downto 0);
				
				case FSM_si5338 is
				
					when idle =>
						FSM_si5338 <= initial_state;
						busy_cnt := 0;
						busy_prev <= '0';
						send_enable <= '0';
						maximum_entries_bram <= 350;--to_integer( unsigned( mem_data(9 downto 0) ) );
						mem_addr <= (others => '0');
						bram_counter <= 0;
						
						error <= '1';
					
					when initial_state =>
						FSM_si5338 <= initial_state;
						case busy_cnt is
							when 0 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"e6"; -- 230! //OEB_ALL = 1
							
							when 1 =>
								i2c_data_wr <= x"10";
							
							when 2 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
						
							when 3 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"F1"; -- 241! //DIS_LOL = 1
							
							when 4 =>
								i2c_data_wr <= x"e5";
							
							when 5 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									FSM_si5338 <= config_state;
									busy_cnt := 0;
									mem_addr <= std_logic_vector( to_unsigned( bram_counter,WIDTH_BRAM ));
								end if;
							
							when others => NULL;
						end case;					
						
					when config_state =>
						FSM_si5338 <= config_state;
						
						if( bram_counter < maximum_entries_bram ) then
							
							if( reg_mask /= x"ff" ) then
								case busy_cnt is
									when 0 =>
										send_enable <= '1';
										i2c_rw <= '0';
										i2c_data_wr <= reg_addr;
										
									when 1 =>
										send_enable <= '0';
										if( i2c_busy = '0' ) then
											busy_cnt := busy_cnt + 1;
										end if;
									
									when 2 =>
										send_enable <= '1';
										i2c_rw <= '1';
										
									when 3 =>
										send_enable <= '0';
										if( i2c_busy = '0' ) then
											busy_cnt := busy_cnt + 1;
											read_data <= i2c_data_rd;
										end if;
										
									when 4 =>
										send_enable <= '1';
										i2c_rw <= '0';
										i2c_data_wr <= reg_addr;
							
									when 5 =>
										i2c_data_wr <= (reg_val AND reg_mask) OR (read_data AND not reg_mask);
									
									when 6 =>
										send_enable <= '0';
										if( i2c_busy = '0' ) then
											busy_cnt := 0;
											bram_counter <= bram_counter + 1;
											mem_addr <= std_logic_vector( to_unsigned( bram_counter+1,WIDTH_BRAM ));
										end if;										
									
									when others => NULL;
								end case;
							
							else
								case busy_cnt is
									when 0 =>
										send_enable <= '1';
										i2c_rw <= '0';
										i2c_data_wr <= reg_addr;
															
									when 1 =>
										i2c_data_wr <= reg_val;
															
									when 2 =>
										send_enable <= '0';
										if( i2c_busy = '0' ) then
											busy_cnt := 0;
											bram_counter <= bram_counter + 1;
											mem_addr <= std_logic_vector( to_unsigned( bram_counter+1,WIDTH_BRAM ));
										end if;
															
									when others => NULL;
								end case;
							
							end if;
						else
							FSM_si5338 <= check_LOS_alarm_state;
							busy_cnt := 0;
						end if;


					when check_LOS_alarm_state =>
						FSM_si5338 <= check_LOS_alarm_state;
						
						case busy_cnt is
							when 0 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"DA"; -- 218!
									
							when 1 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
								
							when 2 =>
								send_enable <= '1';
								i2c_rw <= '1';
							
							when 3 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data <= i2c_data_rd;
								end if;
								
							when 4 =>
								busy_cnt := 0;
								if( ( read_data AND x"04" ) /= x"00" ) then
									FSM_si5338 <= check_LOS_alarm_state;
								else
									FSM_si5338 <= next_config_state;
								end if;
							
							when others => NULL;
						end case;
						
					when next_config_state =>
						FSM_si5338 <= next_config_state;
						
						case busy_cnt is
							when 0 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"31"; -- 49!
									
							when 1 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
							
							when 2 =>
								send_enable <= '1';
								i2c_rw <= '1';
									
							when 3 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data <= i2c_data_rd;
								end if;
								
							when 4 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"31"; -- 49!
								
							when 5 =>
								i2c_data_wr <= read_data AND x"7f"; --//FCAL_OVRD_EN = 0
							
							when 6 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
							
							when 7 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"F6"; -- 246!
								
							when 8 =>
								i2c_data_wr <= x"02"; --//soft reset
--								wait_counter <= 0;
								
							when 9 =>
--								send_enable <= '0';
--								wait_counter <= wait_counter + 1;
--								if( i2c_busy = '0' ) then
--									if( wait_counter = (input_clk/30) ) then
--										busy_cnt := busy_cnt + 1;
--									end if;
--								end if;
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
								
							when 10 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"F1"; -- 241!
								
							when 11 =>
								i2c_data_wr <= x"65"; --//DIS_LOL = 0
								wait_counter <= 0;
								
							when 12 =>
--								send_enable <= '0';
--								if( i2c_busy = '0' ) then
--									busy_cnt := busy_cnt + 1;
--								end if;
								send_enable <= '0';
								wait_counter <= wait_counter + 1;
								if( i2c_busy = '0' ) then
									if( wait_counter = (input_clk/30) ) then
										busy_cnt := busy_cnt + 1;
									end if;
								end if;
							
							when 13 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"DA"; -- 218!
								
							when 14 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
								
							when 15 =>
								send_enable <= '1';
								i2c_rw <= '1';
								
							when 16 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data <= i2c_data_rd;
								end if;
								
							when 17 =>
								if( (read_data AND x"15") = x"00" ) then
									busy_cnt := 0;
									FSM_si5338 <= copy_state;
								else
									busy_cnt := 13;
								end if;
								
							when others => NULL;
						end case;
					
					when copy_state =>
						FSM_si5338 <= copy_state;
						error <= '0';
						
						case busy_cnt is
							when 0 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"EB"; -- 235!
									
							when 1 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
								
							when 2 =>
								send_enable <= '1';
								i2c_rw <= '1';
									
							when 3 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data <= i2c_data_rd;
								end if;
								
							when 4 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"2D"; -- 45!
								
							when 5 =>
								i2c_data_wr <= read_data;
							
							when 6 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
								
							when 7 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"EC"; -- 236!
									
							when 8 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
								
							when 9 =>
								send_enable <= '1';
								i2c_rw <= '1';
									
							when 10 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data <= i2c_data_rd;
								end if;
								
							when 11 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"2E"; -- 46!
								
							when 12 =>
								i2c_data_wr <= read_data;
								
							when 13 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
								
							when 14 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"2F"; -- 47!
								
							when 15 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
								
							when 16 =>
								send_enable <= '1';
								i2c_rw <= '1';
								
							when 17 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data <= i2c_data_rd;
								end if;
								
							when 18 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"ED"; -- 237!
								
							when 19 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
								
							when 20 =>
								send_enable <= '1';
								i2c_rw <= '1';
								
							when 21 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data2 <= i2c_data_rd;
								end if;
								
							when 22 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"2F"; -- 47!
							
							when 23 =>
								i2c_data_wr <= (read_data AND x"FC" ) OR ( read_data2 AND x"03");
								
							when 24 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
								
							when 25 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"31"; -- 49!
							
							when 26 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
								
							when 27 =>
								send_enable <= '1';
								i2c_rw <= '1';
							
							when 28 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data <= i2c_data_rd;
								end if;
								
							when 29 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"31"; -- 49!
								
							when 30 =>
								i2c_data_wr <= read_data OR x"80"; --// FCAL_OVRD_EN = 1
								
							when 31 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data <= i2c_data_rd;
								end if;
								
							when 32 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"E6"; -- 230!
								
							when 33 =>
								i2c_data_wr <= x"00"; --// OEB_ALL = 0
								
							when 34 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									FSM_si5338 <= done_state;
									busy_cnt := 0;
								end if;
								
							when others => NULL;
						end case;

					when done_state =>
						FSM_si5338 <= done_state;
						done_sig <= '1';
					
					when error_state =>
						FSM_si5338 <= error_state;
						if( FSM_si5338_prev /= error_state ) then
							error_fsm_last_state <= std_logic_vector( to_unsigned(FSM_si5338'pos(FSM_si5338_prev),5) );
						end if;
						
				end case;
				
				if(  i2c_ack_error = '1' ) then
					FSM_si5338 <= error_state;
					send_enable <= '0';
				end if;
				
				busy_cnt_global <= busy_cnt; 
			end if;
		end if;				

end process;

i2c_master_inst : i2c_master
	generic map(
		input_clk 	=> input_clk,
		bus_clk		=> bus_clk
	)
	port map(
		clk 			=> clk,
		reset_n 		=> i2c_reset_n,
		ena			=> send_enable,
		addr			=> i2c_address,
		rw				=> i2c_rw,
		data_wr		=> i2c_data_wr,
		busy			=> i2c_busy,
		data_rd		=> i2c_data_rd,
		ack_error	=> i2c_ack_error,
		
		sda			=> SDA,
		scl			=> SCL
		
	);

end Behavioral;
