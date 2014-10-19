----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Steffen Mauch [steffen.mauch (at) gmail.com]
-- 
-- Create Date:    08:42:49 12/03/2013 
-- Design Name: 
-- Module Name:    tb_si5338 - testbench 
-- Project Name:   si5338-vhdl testbench
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

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY tb_si5338 IS
END tb_si5338;
 
ARCHITECTURE behavior OF tb_si5338 IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
	component si5338 is
		generic(
		input_clk 		: INTEGER := 50_000_000; --input clock speed from user logic in Hz
		i2c_address		: std_logic_vector(6 downto 0) := "111" & "0000";
		bus_clk   		: INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz
	port(
		clk     		: in std_logic;
		reset			: in std_logic;
			
		done			: out std_logic;
			
		error 		: out std_logic;
			
		SCL 			: inout std_logic;
		SDA 			: inout std_logic
	);
	end component si5338;
	
component I2C_slave is
	generic (
		SLAVE_ADDR : std_logic_vector(6 downto 0));
	port (
		scl : inout std_logic;
		sda : inout std_logic;
		clk : in std_logic;
		rst : in std_logic;
		-- User interface
		read_req : out std_logic;
		data_to_master : in std_logic_vector(7 downto 0);
		data_valid : out std_logic;
		data_from_master : out std_logic_vector(7 downto 0)
	);
end component I2C_slave;
	
	
	constant INPUT_CLK 		: integer := 25_000_000;
	constant i2c_address 	: std_logic_vector( 6 downto 0) := "111" & "0000";
	constant bus_clk	 		: integer := 400_000;


   --Inputs
   signal clk : std_logic := '0';
   signal reset : std_logic := '0';

	--BiDirs
   signal SCL : std_logic := 'H';
   signal SDA : std_logic := 'H';

 	--Outputs
   signal done : std_logic;
   signal error : std_logic;

   -- Clock period definitions
   constant clk_period : time := 40 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: si5338 
		GENERIC MAP(
			INPUT_CLK 	=> INPUT_CLK,
			i2c_address => i2c_address,
			bus_clk		=> bus_clk
		)
		PORT MAP (
          clk => clk,
          reset => reset,
          done => done,
          error => error,
          SCL => SCL,
          SDA => SDA
        );

	uut_slave : I2C_slave
	generic map(
		SLAVE_ADDR => i2c_address
		)
	port map(
		scl 	=> SCL,
		sda 	=> SDA,
		clk 	=> clk,
		rst 	=> reset,
		-- User interface
		--read_req : out std_logic;
		data_to_master 	=> (others => '0')
		--data_valid : out std_logic;
		--data_from_master : out std_logic_vector(7 downto 0)
	);
	

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

SCL <= 'H';
SDA <= 'H';

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
		reset <= '1';
      wait for 10 us;
		reset <= '0';
		

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
