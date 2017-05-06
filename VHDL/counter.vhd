----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:23:51 03/25/2017 
-- Design Name: 
-- Module Name:    blink - Behavioral 
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

entity counter is
    Generic(N : natural := 100000000);
    Port ( 
			 clk : in STD_LOGIC;
			 output_pulse_two : out STD_LOGIC;
			 output_pulse : out  STD_LOGIC;
			 done : out STD_LOGIC);
end counter;

architecture Behavioral of counter is
signal output : STD_LOGIC := '0';
signal output_two : STD_LOGIC := '0';
signal state : STD_LOGIC := '0';
signal counter : STD_LOGIC_VECTOR(24 downto 0) := (others => '0');
signal output_done : STD_LOGIC := '0';
begin
		process(clk)
		begin
			if(rising_edge(clk)) then
				if(counter < N) then
					output <= output;
					counter <= counter + 1;
					if(state = '0') then
						output_two <= '0';
					else 
						output_two <= '1';
					end if;
					if(output_done = '1') then
						output_done <= '0';
					end if;
				else
					if(output = '1' and state = '0') then
						state <= '1';
						output <= '0';
						output_two <= '1';
						output_done <= '1';
						counter <= "0000000000000000000000000";
					elsif(output = '1' and state = '1') then
						state  <= '0';
						output <= '0';
						output_two <= '0';
						counter <= "0000000000000000000000000";
					else 
						output <= not(output);
						counter <= "0000000000000000000000000";
					end if;
				end if;
			end if;
		end process;
		output_pulse <= output;
		output_pulse_two <= output_two;
		done <= output_done;
end Behavioral;

