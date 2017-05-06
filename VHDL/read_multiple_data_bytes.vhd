----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:35:08 01/25/2017 
-- Design Name: 
-- Module Name:    read_multiple_data_bytes - Behavioral 
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
use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity read_multiple_data_bytes is
	port (
			clk : in  STD_LOGIC;
			reset : in  STD_LOGIC;
			data_in : in  STD_LOGIC_VECTOR (7 downto 0);
			next_data : in  STD_LOGIC;
			data_read : out  STD_LOGIC_VECTOR (63 downto 0));
end read_multiple_data_bytes;

architecture Behavioral of read_multiple_data_bytes is
signal sig_read_data : STD_LOGIC_VECTOR(63 downto 0) := (others=>'0');
signal counter : STD_LOGIC_VECTOR(2 downto 0) := (others=>'0');
signal state : STD_LOGIC := '0';

begin
		process (clk,next_data,reset)
		begin
			if(rising_edge(clk)) then 
				if (reset = '1') then 
					sig_read_data <= (others=>'0');
					counter <= (others=>'0');
					state <= '0';
				else
					if(next_data = '1' and state = '0') then
						sig_read_data((7+8*(to_integer(unsigned(counter)))) downto 8*(to_integer(unsigned(counter))) ) <= data_in;
						counter <= counter+1;
						state <= '1';
					elsif(next_data = '0') then
						state <= '0';
					end if;
				end if;
			end if;
		end process;
		data_read <= sig_read_data;
end Behavioral;
