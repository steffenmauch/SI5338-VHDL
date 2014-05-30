----------------------------------------------------------------------------------
-- Company: 
-- Engineer: --
-- 
-- Create Date:    08:50:49 12/03/2013 
-- Design Name: 
-- Module Name:    i2c_slave_si5338 
-- Project Name:   i2c_slave_si5338 testbench model
-- Target Devices: Xilinx Kintex-7
-- Tool versions: 
-- Description: 		LICENSE: BSD!
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
--
-- Copyright (c) <2014, Steffen Mauch
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

entity i2c_slave_si5338 is
	port (
		clk			: in    std_logic;
		reset_n		: in    std_logic;
		data_o		: out   std_logic_vector(7 downto 0);
		data_valid	: out   std_logic;
		SCL			: in    std_logic;
		SDA			: inout std_logic
	);
end entity i2c_slave_si5338;

------------------------------------------------------------------------ 

architecture behav of i2c_slave_si5338 is

	type   states is (s_idle, s_start, s_read_a, s_ack);
	signal state, next_state : states;

	signal oSCL, oSDA						: std_logic := '0';
	signal SDAt, SCLb						: std_logic;
	signal rx_reg							: std_logic_vector(7 downto 0);
	signal rx_done							: std_logic;
	signal int_reg							: std_logic_vector(7 downto 0);
	signal stop_sy							: std_logic := '0';
	signal count							: std_logic_vector(2 downto 0) := (others => '0');

------------------------------------------------------------------------ 
begin

	SDAt      <= '0' when (SDA = '0') else '1';
	SCLb      <= '0' when (SCL = '0') else '1';

------------------------------------------------------------------------ 
-- statemachine for i2c slave
------------------------------------------------------------------------ 
	process (reset_n, clk)--, state, SDA, stop_sy, count)
		begin
			if reset_n = '0' then
				rx_done       <= '0';
				data_valid    <= '0';
				next_state    <= s_idle;
				int_reg       <= (others => 'Z');
				data_o          <= (others => 'Z');
		elsif clk'event and clk='1' then
		
			case state is
				when s_idle =>
					data_valid <= '0';
					rx_done <= '0';

					if SDA = '0' then
						next_state <= s_start;
					else
						next_state <= s_idle;
					end if;

				when s_start =>
					data_valid <= '0';
					rx_done <= '0';

					if stop_sy = '0' then
						next_state <= s_read_a;
					else
						next_state <= s_idle;
					end if;

				when s_read_a =>    -- save SDA and shift
					data_valid <= '0';
					rx_done  <= '0';

					if (count = "000" and stop_sy='0') then
						next_state <= s_ack;
					else
						next_state <= s_read_a;
					end if;

				when s_ack => -- send acknowledge (SDA = '0')
					data_valid <= '1';
					rx_done <= '1';

					int_reg <= rx_reg;
					data_o <= rx_reg;
					next_state <= s_start;  -- idle
				end case;
		end if;
end process;

------------------------------------------------------------------------ 
-- detect stop
------------------------------------------------------------------------ 
process (reset_n, clk)--, SCLb, SDAt, state, oSDA)
	begin
		if reset_n = '0' then
			stop_sy <= '0';
			oSDA    <= '1';
		elsif clk'event and clk='1' then
			if state = s_idle then
				stop_sy <= '0';
			end if;
				
			if (oSDA = '0' and SDAt = '1') then  -- rising edge
				oSDA <= '1';
				if SCLb = '1' then  -- SCL high assert stop signal
					stop_sy <= '1';
				else
					stop_sy <= '0';
				end if;
			elsif (oSDA = '1' and SDAt = '0') then 
				oSDA <= '0';
			end if;
		end if;
end process;

------------------------------------------------------------------------ 
-- switch states
------------------------------------------------------------------------ 
process (clk, reset_n, state, stop_sy, oSCL, SCLb, rx_done)
	begin
		if reset_n = '0' then
			state <= s_idle;
			oSCL <= '1';
			count <= (others => '0');
			rx_reg <= (others => 'Z');
		elsif (clk'event and clk = '1') then  -- Register
			if stop_sy = '1' then
				state <= s_idle;
			end if;

			if state = s_idle then
				count <= (others => '0');
			end if;

			if (oSCL = '1' and SCLb = '0' ) then  -- rising_edge? -- and stop_sy='0'
				state <= next_state;                -- next state
				oSCL <= '0';       -- save actual value
			elsif (oSCL = '0' and SCLb = '1') then  -- rising?
				if (state = s_idle) or (state = s_ack) then  -- reset counter
					count <= (others => '0');
				else
					if rx_done = '0' then
						rx_reg <= rx_reg(6 downto 0) & SDAt;  -- shift
						count <= count+"001";      -- count eight bits
					end if;
				end if;
				oSCL <= '1';
			end if;
		end if;
end process;
 
end architecture behav;
