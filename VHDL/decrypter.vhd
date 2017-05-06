----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:54:07 01/28/2017 
-- Design Name: 
-- Module Name:    decrypter - Behavioral 
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

entity decrypter is
	port (clk: in STD_LOGIC;
				reset : in  STD_LOGIC;
				ciphertext: in STD_LOGIC_VECTOR (63 downto 0);
				start: in STD_LOGIC;
				plaintext: out STD_LOGIC_VECTOR (63 downto 0);
				done: out STD_LOGIC := '1');
end decrypter;

architecture Behavioral of decrypter is
signal v0 : STD_LOGIC_VECTOR(31 downto 0);
signal v1 : STD_LOGIC_VECTOR(31 downto 0);
signal sum : STD_LOGIC_VECTOR(31 downto 0); --0xC6EF3720 in binary
signal counter : STD_LOGIC_VECTOR(5 downto 0) := (others=>'0');
signal isit_done : STD_LOGIC := '0';
begin
		process (clk, start,reset)
			variable var_v1 : STD_LOGIC_VECTOR(31 downto 0);
			constant delta : STD_LOGIC_VECTOR(31 downto 0) := x"9e3779b9"; --0x9e3779b9 in binary
			constant k0 : STD_LOGIC_VECTOR(31 downto 0) := x"00000000"; --generated random online
			constant k1 : STD_LOGIC_VECTOR(31 downto 0) := x"00000000";
			constant k2 : STD_LOGIC_VECTOR(31 downto 0) := x"00000000";
			constant k3 : STD_LOGIC_VECTOR(31 downto 0) := x"00000000";
		begin
			if(rising_edge(clk)) then 
				if (reset = '1') then 
					v0 <= (others=>'0');
					v1 <= (others=>'0');
					counter <= (others=>'0');
					sum <= x"c6ef3720";
					isit_done <= '0';
				elsif(start = '1' and isit_done = '0') then
					v1 <= ciphertext(63 downto 32);
					v0 <= ciphertext(31 downto 0);
					done <= '0';
					isit_done <= '1';
					sum <= x"c6ef3720";
				elsif (isit_done = '1') then
					if(counter<"100000") then
						var_v1 := v1;
						var_v1 := var_v1-(((v0(27 downto 0)&"0000")+k2)xor(v0+sum)xor(("00000" & v0(31 downto 5))+k3));
						v0 <= v0-(((var_v1(27 downto 0)&"0000")+k0)xor(var_v1+sum)xor(("00000" & var_v1(31 downto 5))+k1));
						v1 <= var_v1;
						sum <= sum - delta;
						counter <= counter+1;
					else
						done <= '1';
					end if;
				end if;
			end if;	
		end process;
		plaintext(63 downto 32) <= v1;
		plaintext(31 downto 0) <= v0;
end Behavioral;

