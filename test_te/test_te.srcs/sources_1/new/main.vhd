----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2024/05/04 15:11:12
-- Design Name: 
-- Module Name: main - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
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
use IEEE.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity main is
--  Port ( );
port(
clk: in std_logic;
scl:inout std_logic;
sda: inout std_logic;
led: out std_logic_vector(7 downto 0) := "00000000")
;
end main;

architecture Behavioral of main is
signal clk_50Mhz: std_logic;
component te_sensor is
    generic (
    sys_clk_freq : INTEGER := 50_000_000
    );
    
    port(
    clk         : IN    STD_LOGIC;                       --system clock
    reset_n     : IN    STD_LOGIC;                       --asynchronous active-low reset
    scl         : INOUT STD_LOGIC;                       --I2C serial clock
    sda         : INOUT STD_LOGIC;                       --I2C serial data
    i2c_ack_err : OUT   STD_LOGIC;                       --I2C slave acknowledge error flag
    relative_humidity : OUT   STD_LOGIC_VECTOR(15 DOWNTO 0)     --relative humidity data obtained
    );
    end component;
    
    signal tmp_clk: std_logic := '0';
    signal i2c_ack_err : STD_LOGIC;                       --I2C slave acknowledge error flag
    signal relative_humidity : STD_LOGIC_VECTOR(15 DOWNTO 0):="0000000000000000";     --relative humidity data obtained
    signal relative_humidity_int : integer := 0;
    
begin
    process (clk)
        begin
        if rising_edge(clk) then
            tmp_clk <= not tmp_clk;
        end if;
     end process;
     
     te : te_sensor generic map(sys_clk_freq => 50_000_000) 
     port map(clk => tmp_clk, reset_n => '1', scl => scl, sda => sda,relative_humidity => relative_humidity, i2c_ack_err => i2c_ack_err
     );
     
     process (clk, relative_humidity)
     begin
        if rising_edge(clk) then
            if (125 * TO_INTEGER(unsigned(relative_humidity)) / 65536) > 100 then
                relative_humidity_int <= 100;
            elsif (125 * TO_INTEGER(unsigned(relative_humidity)) / 65536) < 0 then
                relative_humidity_int <= 0;
            else
                relative_humidity_int <= 125 * TO_INTEGER(unsigned(relative_humidity)) / 65536 - 6;
            end if;
        end if;
     end process;
     

     led  <= std_logic_vector(TO_UNSIGNED(relative_humidity_int, 8));
     --led <= relative_humidity(7 downto 0);

end Behavioral;
