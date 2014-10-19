----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Steffen Mauch [steffen.mauch (at) gmail.com]
-- 
-- Create Date:    08:42:49 09/11/2013 
-- Design Name: 
-- Module Name:    si5338 - Behavioral 
-- Project Name:   si5338-vhdl implementation
-- Target Devices: Xilinx Kintex-7
-- Tool versions: 
-- Description: 		LICENSE: BSD!
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
--
-- Copyright (c) 2013/2014, Steffen Mauch
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice, this
--    list of conditions and the following disclaimer. 
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
-- ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- The views and conclusions contained in the software and documentation are those
-- of the authors and should not be interpreted as representing official policies, 
-- either expressed or implied, of the FreeBSD Project.
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
    ack_error : OUT    STD_LOGIC;                    --flag if improper acknowledge from slave
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
signal error_int		: std_logic;

signal i2c_data_wr   : std_logic_vector(7 downto 0); 
signal i2c_busy      : std_logic;
signal i2c_data_rd   : std_logic_vector(7 downto 0);
signal i2c_ack_error	: std_logic;

attribute S: string;

type state_type is (idle, reset_state, initial_state, config_state, 
	check_LOS_alarm_state, next_config_state, copy_state, done_state, error_state);  --type of state machine.
signal FSM_si5338 : state_type;
signal FSM_si5338_prev : state_type;

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

error <= i2c_ack_error;
--error <= error_int;
internal_reset <= reset;

i2c_reset_internal <= '0' ;--OR i2c_ack_error;

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
				
				error_int <= '1';
				
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
--				    FSM_si5338 <= idle;
--				end if;
				
				if( busy_prev = '0' AND i2c_busy = '1' AND FSM_si5338_prev /= idle ) then  --i2c busy just went high
					busy_cnt := busy_cnt + 1;                   --counts the times busy has gone from low to high during transaction
					timeout <= 0;
				end if;
				
				done_sig <= '0';
				
				reg_addr 	:= mem_data(23 downto 16);
				reg_val 		:= mem_data(15 downto 8);
				reg_mask 	:= mem_data(7 downto 0);
				
				case FSM_si5338 is
				
					when idle =>
						FSM_si5338 <= reset_state;
						busy_cnt := 0;
						busy_prev <= '0';
						send_enable <= '0';
						
						mem_addr <= (others => '1');
						bram_counter <= 0;
						
						error_int <= '1';
					
					when reset_state =>
						FSM_si5338 <= reset_state;
						
						case busy_cnt is	-- this is not required but when restarting after error it is advantageous
							when 0 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"f6"; -- 246
								
							when 1 =>
								i2c_data_wr <= x"02";
														
							when 2 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := 0;
									FSM_si5338 <= initial_state;
								end if;
								
							when others =>
								busy_cnt := 0;
						end case;
					
					when initial_state =>
						FSM_si5338 <= initial_state;
						case busy_cnt is
							when 0 =>
								maximum_entries_bram <= to_integer( unsigned( mem_data(9 downto 0) ) ); -- default ist 350
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"e6"; -- 230! //OEB_ALL = 1
							
							when 1 =>
								mem_addr <= (others => '0');
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
									bram_counter <= 0;
									busy_cnt := 0;
									mem_addr <= std_logic_vector( to_unsigned( 0, WIDTH_BRAM ));
								end if;
							
							when others => busy_cnt := 0;
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
										i2c_rw <= '1';
										
									when 2 =>
										send_enable <= '0';
										if( i2c_busy = '0' ) then
											busy_cnt := busy_cnt + 1;
											read_data <= i2c_data_rd;
										end if;
										
									when 3 =>
										send_enable <= '1';
										i2c_rw <= '0';
										i2c_data_wr <= reg_addr;
							
									when 4 =>
										i2c_data_wr <= (reg_val AND reg_mask) OR (read_data AND not reg_mask);
									
									when 5 =>
										send_enable <= '0';
										if( i2c_busy = '0' ) then
											busy_cnt := 0;
											bram_counter <= bram_counter + 1;
											mem_addr <= std_logic_vector( to_unsigned( bram_counter+1, WIDTH_BRAM ));
										end if;

									
									when others => busy_cnt := 0;
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
											mem_addr <= std_logic_vector( to_unsigned( bram_counter+1, WIDTH_BRAM ));
										end if;
															
									when others => busy_cnt := 0;
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
								i2c_rw <= '1';
							
							when 2 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data <= i2c_data_rd;
								end if;
								
							when 3 =>
								busy_cnt := 0;
								if( ( read_data AND x"04" ) /= x"00" ) then
									FSM_si5338 <= check_LOS_alarm_state;
								else
									FSM_si5338 <= next_config_state;
								end if;
							
							when others => busy_cnt := 0;
						end case;
						
					when next_config_state =>
						FSM_si5338 <= next_config_state;
						
						case busy_cnt is
							when 0 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"31"; -- 49!
							
							when 1 =>
								i2c_rw <= '1';
									
							when 2 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data <= i2c_data_rd;
								end if;
								
							when 3 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"31"; -- 49!
								
							when 4 =>
								i2c_data_wr <= read_data AND x"7f"; --//FCAL_OVRD_EN = 0
							
							when 5 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
							
							when 6 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"F6"; -- 246!
								
							when 7 =>
								i2c_data_wr <= x"02"; --//soft reset
								
							when 8 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
								
							when 9 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"F1"; -- 241!
								
							when 10 =>
								i2c_data_wr <= x"65"; --//DIS_LOL = 0
								wait_counter <= 0;
								
							when 11 =>
								send_enable <= '0';
								wait_counter <= wait_counter + 1;
								if( i2c_busy = '0' ) then
									if( wait_counter = (input_clk/30) ) then
										busy_cnt := busy_cnt + 1;
									end if;
								end if;
							
							when 12 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"DA"; -- 218!
								
							when 13 =>
								i2c_rw <= '1';
								
							when 14 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data <= i2c_data_rd;
								end if;
								
							when 15 =>
								if( (read_data AND x"15") = x"00" ) then
									busy_cnt := 0;
									FSM_si5338 <= copy_state;
								else
									busy_cnt := 12;
								end if;
								
							when others => busy_cnt := 0;
						end case;
					
					when copy_state =>
						FSM_si5338 <= copy_state;
						error_int <= '0';
						
						case busy_cnt is
							when 0 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"EB"; -- 235!
								
							when 1 =>
								i2c_rw <= '1';
									
							when 2 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data <= i2c_data_rd;
								end if;
								
							when 3 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"2D"; -- 45!
								
							when 4 =>
								i2c_data_wr <= read_data;
							
							when 5 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
								
							when 6 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"EC"; -- 236!

							when 7 =>
								i2c_rw <= '1';
									
							when 8 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data <= i2c_data_rd;
								end if;
								
							when 9 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"2E"; -- 46!
								
							when 10 =>
								i2c_data_wr <= read_data;
								
							when 11 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
								
							when 12 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"2F"; -- 47!
								
							when 13 =>
								i2c_rw <= '1';
								
							when 14 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data <= i2c_data_rd;
								end if;
								
							when 15 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"ED"; -- 237!
								
							when 16 =>
								i2c_rw <= '1';
								
							when 17 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data2 <= i2c_data_rd;
								end if;
								
							when 18 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"2F"; -- 47!
							
							when 19 =>
								i2c_data_wr <= (read_data AND x"FC" ) OR ( read_data2 AND x"03");
								
							when 20 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
								end if;
								
							when 21 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"31"; -- 49!
								
							when 22 =>
								i2c_rw <= '1';
							
							when 23 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data <= i2c_data_rd;
								end if;
								
							when 24 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"31"; -- 49!
								
							when 25 =>
								i2c_data_wr <= read_data OR x"80"; --// FCAL_OVRD_EN = 1
								
							when 26 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									busy_cnt := busy_cnt + 1;
									read_data <= i2c_data_rd;
								end if;
								
							when 27 =>
								send_enable <= '1';
								i2c_rw <= '0';
								i2c_data_wr <= x"E6"; -- 230!
								
							when 28 =>
								i2c_data_wr <= x"00"; --// OEB_ALL = 0
								
							when 29 =>
								send_enable <= '0';
								if( i2c_busy = '0' ) then
									FSM_si5338 <= done_state;
									busy_cnt := 0;
								end if;
								
							when others => busy_cnt := 0;
						end case;

					when done_state =>
						FSM_si5338 <= done_state;
						done_sig <= '1';
					
					when error_state =>
						FSM_si5338 <= error_state;
						
					 when others =>
					 
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
