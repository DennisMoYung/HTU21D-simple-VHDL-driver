--------------------------------------------------------------------------------
--
--   FileName:         pmod_hygrometer.vhd
--   Dependencies:     i2c_master.vhd (Version 2.2)
--   Design Software:  Quartus Prime Version 17.0.0 Build 595 SJ Lite Edition
--
--   HDL CODE IS PROVIDED "AS IS."  DIGI-KEY EXPRESSLY DISCLAIMS ANY
--   WARRANTY OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT
--   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
--   PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL DIGI-KEY
--   BE LIABLE FOR ANY INCIDENTAL, SPECIAL, INDIRECT OR CONSEQUENTIAL
--   DAMAGES, LOST PROFITS OR LOST DATA, HARM TO YOUR EQUIPMENT, COST OF
--   PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY OR SERVICES, ANY CLAIMS
--   BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY DEFENSE THEREOF),
--   ANY CLAIMS FOR INDEMNITY OR CONTRIBUTION, OR OTHER SIMILAR COSTS.
--
--   Version History
--   Version 1.0 05/04/2020 Scott Larson
--     Initial Public Release
-- 
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY te_sensor IS
  GENERIC(
    sys_clk_freq            : INTEGER := 50_000_000        --input clock speed from user logic in Hz
    );
  PORT(
    clk               : IN    STD_LOGIC;                                            --system clock
    reset_n           : IN    STD_LOGIC;                                            --asynchronous active-low reset
    scl               : INOUT STD_LOGIC;                                            --I2C serial clock
    sda               : INOUT STD_LOGIC;                                            --I2C serial data
    i2c_ack_err       : OUT   STD_LOGIC;                                            --I2C slave acknowledge error flag
    temperature        : OUT   STD_LOGIC_VECTOR(15 DOWNTO 0);
    relative_humidity : OUT   STD_LOGIC_VECTOR(15 DOWNTO 0)     --relative humidity data obtained
    ); 
END te_sensor;

ARCHITECTURE behavior OF te_sensor IS
  CONSTANT sensor_addr : STD_LOGIC_VECTOR(6 DOWNTO 0) := "1000000";         --I2C address of the hygrometer pmod
  TYPE machine IS(start, configure, reset_pause, initiate_hr, pause_hr, read_data_hr, initiate_tmp, pause_tmp, read_data_tmp, output_result); --needed states
  SIGNAL state            : machine;                       --state machine
  SIGNAL i2c_ena          : STD_LOGIC;                     --i2c enable signal
  SIGNAL i2c_addr         : STD_LOGIC_VECTOR(6 DOWNTO 0);  --i2c address signal
  SIGNAL i2c_rw           : STD_LOGIC;                     --i2c read/write command signal
  SIGNAL i2c_data_wr      : STD_LOGIC_VECTOR(7 DOWNTO 0);  --i2c write data
  SIGNAL i2c_data_rd      : STD_LOGIC_VECTOR(7 DOWNTO 0);  --i2c read data
  SIGNAL i2c_busy         : STD_LOGIC;                     --i2c busy signal
  SIGNAL busy_prev        : STD_LOGIC;                     --previous value of i2c busy signal
  SIGNAL rh_time          : INTEGER;                       --clock cycles needed for humidity measurement
  SIGNAL humidity_data    : STD_LOGIC_VECTOR(15 DOWNTO 0); --humidity data buffer
  SIGNAL temperature_data    : STD_LOGIC_VECTOR(15 DOWNTO 0); --humidity data buffer

  COMPONENT i2c_master IS
    GENERIC(
      input_clk : INTEGER;  --input clock speed from user logic in Hz
      bus_clk   : INTEGER); --speed the i2c bus (scl) will run at in Hz
    PORT(
      clk       : IN     STD_LOGIC;                    --system clock
      reset_n   : IN     STD_LOGIC;                    --active low reset
      ena       : IN     STD_LOGIC;                    --latch in command
      addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
      rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
      data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
      busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
      data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
      ack_error : BUFFER STD_LOGIC;                    --flag if improper acknowledge from slave
      sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
      scl       : INOUT  STD_LOGIC);                   --serial clock output of i2c bus
  END COMPONENT;

BEGIN

  --instantiate the i2c master
  i2c_master_0:  i2c_master
    GENERIC MAP(input_clk => sys_clk_freq, bus_clk => 400_000)
    PORT MAP(clk => clk, reset_n => reset_n, ena => i2c_ena, addr => i2c_addr,
             rw => i2c_rw, data_wr => i2c_data_wr, busy => i2c_busy,
             data_rd => i2c_data_rd, ack_error => i2c_ack_err, sda => sda,
             scl => scl);
               
          

    rh_time <= sys_clk_freq/400 ;
        
             
  PROCESS(clk, reset_n)
    VARIABLE busy_cnt   : INTEGER RANGE 0 TO 4 := 0;               --counts the I2C busy signal transistions
    VARIABLE pwr_up_cnt : INTEGER RANGE 0 TO sys_clk_freq/10 := 0; --counts 100ms to wait before communicating
    VARIABLE pause_cnt  : INTEGER;                                 --counter to wait for measurements to complete
  BEGIN
  
    IF(reset_n = '0') THEN                --reset activated
      pwr_up_cnt := 0;                      --clear power up counter
      i2c_ena <= '0';                       --clear I2C enable
      busy_cnt := 0;                        --clear busy counter
      pause_cnt := 0;                       --clear pause counter
      relative_humidity <= (OTHERS => '0'); --clear the relative humidity result output
      state <= start;                       --return to start state

    ELSIF(clk'EVENT AND clk = '1') THEN   --rising edge of system clock
      CASE state IS                         --state machine
      
        --give hygrometer 100ms to power up before communicating
        WHEN start =>
          IF(pwr_up_cnt < sys_clk_freq/10) THEN  --100ms not yet reached
            pwr_up_cnt := pwr_up_cnt + 1;          --increment power up counter
          ELSE                                   --100ms reached
            pwr_up_cnt := 0;                       --clear power up counter
            state <= configure;                    --advance to configure the hygrometer
          END IF;
          
          WHEN configure =>
          busy_prev <= i2c_busy;                        --capture the value of the previous i2c busy signal
          IF(busy_prev = '0' AND i2c_busy = '1') THEN   --i2c busy just went high
            busy_cnt := busy_cnt + 1;                     --counts the times busy has gone from low to high during transaction
          END IF;
          CASE busy_cnt IS                              --busy_cnt keeps track of which command we are on
            WHEN 0 =>                                     --no command latched in yet
              i2c_ena <= '1';                               --initiate the transaction
              i2c_addr <= sensor_addr;                  --set the address of the hygrometer
              i2c_rw <= '0';                                --command 1 is a write
              i2c_data_wr <= "11111110";   
            when 2 =>
              i2c_ena <= '0';                               --deassert enable to stop transaction after command 3
              IF(i2c_busy = '0') THEN                       --transaction complete
                busy_cnt := 0;                                --reset busy_cnt for next transaction
                state <= reset_pause;                            --advance to the initiate state
              END IF;
            WHEN OTHERS => NULL;
          END CASE;
          
          when reset_pause =>
          IF(pause_cnt < sys_clk_freq / 10 ) THEN  --measurement times not met
            pause_cnt := pause_cnt + 1;               --increment pause counter
          ELSE                                      --measurement times met
            pause_cnt := 0;                           --reset pause counter
            state <= initiate_hr;                       --advance to reading data results
          END IF;
        
               
        --initiate the measurements
        WHEN initiate_hr =>
          busy_prev <= i2c_busy;                        --capture the value of the previous i2c busy signal
          IF(busy_prev = '0' AND i2c_busy = '1') THEN   --i2c busy just went high
            busy_cnt := busy_cnt + 1;                     --counts the times busy has gone from low to high during transaction
          END IF;
          CASE busy_cnt IS                              --busy_cnt keeps track of which command we are on
            WHEN 0 =>                                     --no command latched in yet
              i2c_ena <= '1';                               --initiate the transaction
              i2c_addr <= sensor_addr;                  --set the address of the hygrometer
              i2c_rw <= '0';
              i2c_data_wr <= "11110101";                      
            WHEN 1 =>                                     --1st busy high: command 1 latched
              i2c_ena <= '0';                               --deassert enable to stop transaction after command 1
              IF(i2c_busy = '0') THEN                       --transaction complete
                busy_cnt := 0;                                --reset busy_cnt for next transaction
                state <= pause_hr;                               --advance to the pause state
              END IF;
            WHEN OTHERS => NULL;
          END CASE;   
      
        --wait for humidity and temperature measurements to complete
        WHEN pause_hr =>
          IF(pause_cnt < sys_clk_freq / 10 ) THEN  --measurement times not met
            pause_cnt := pause_cnt + 1;               --increment pause counter
          ELSE                                      --measurement times met
            pause_cnt := 0;                           --reset pause counter
            state <= read_data_hr;                       --advance to reading data results
          END IF;
       
        --retreive the relative humidity and temperature measurement results 
        WHEN read_data_hr =>
          busy_prev <= i2c_busy;                          --capture the value of the previous i2c busy signal
          IF(busy_prev = '0' AND i2c_busy = '1') THEN     --i2c busy just went high
            busy_cnt := busy_cnt + 1;                       --counts the times busy has gone from low to high during transaction
          END IF;
          CASE busy_cnt IS                                --busy_cnt keeps track of which command we are on
            WHEN 0 =>                                       --no command latched in yet
              i2c_ena <= '1';                                 --initiate the transaction
              i2c_addr <= sensor_addr;                    --set the address of the hygrometer
              i2c_rw <= '1';                                  --command 1 is a read
            WHEN 1 =>                                       --1st busy high: command 1 latched
              IF(i2c_busy = '0') THEN                         --indicates data read in command 2 is ready
                 humidity_data(15 DOWNTO 8) <= i2c_data_rd;      --retrieve humidity high-byte data from command 3
              END IF;
            WHEN 2 =>                                       --3rd busy high: command 3 latched
              IF(i2c_busy = '0') THEN                         --indicates data read in command 3 is ready
                humidity_data(7 DOWNTO 0) <= i2c_data_rd;      --retrieve humidity high-byte data from command 3
              END IF;
            WHEN 3 =>                                       --4th busy high: command 4 latched
              i2c_ena <= '0';                                 --deassert enable to stop transaction after command 4
              IF(i2c_busy = '0') THEN                         --indicates data read in command 4 is ready
                busy_cnt := 0;                                  --reset busy_cnt for next transaction
                state <= output_result;                         --advance to output the result
              END IF;
            WHEN OTHERS => NULL;
          END CASE;
          
          --initiate the measurements
        WHEN initiate_tmp =>
          busy_prev <= i2c_busy;                        --capture the value of the previous i2c busy signal
          IF(busy_prev = '0' AND i2c_busy = '1') THEN   --i2c busy just went high
            busy_cnt := busy_cnt + 1;                     --counts the times busy has gone from low to high during transaction
          END IF;
          CASE busy_cnt IS                              --busy_cnt keeps track of which command we are on
            WHEN 0 =>                                     --no command latched in yet
              i2c_ena <= '1';                               --initiate the transaction
              i2c_addr <= sensor_addr;                  --set the address of the hygrometer
              i2c_rw <= '0';
              i2c_data_wr <= "11110011";                      
            WHEN 1 =>                                     --1st busy high: command 1 latched
              i2c_ena <= '0';                               --deassert enable to stop transaction after command 1
              IF(i2c_busy = '0') THEN                       --transaction complete
                busy_cnt := 0;                                --reset busy_cnt for next transaction
                state <= pause_tmp;                               --advance to the pause state
              END IF;
            WHEN OTHERS => NULL;
          END CASE;   
      
        --wait for humidity and temperature measurements to complete
        WHEN pause_tmp =>
          IF(pause_cnt < sys_clk_freq / 10 ) THEN  --measurement times not met
            pause_cnt := pause_cnt + 1;               --increment pause counter
          ELSE                                      --measurement times met
            pause_cnt := 0;                           --reset pause counter
            state <= read_data_tmp;                       --advance to reading data results
          END IF;
       
        --retreive the relative humidity and temperature measurement results 
        WHEN read_data_tmp =>
          busy_prev <= i2c_busy;                          --capture the value of the previous i2c busy signal
          IF(busy_prev = '0' AND i2c_busy = '1') THEN     --i2c busy just went high
            busy_cnt := busy_cnt + 1;                       --counts the times busy has gone from low to high during transaction
          END IF;
          CASE busy_cnt IS                                --busy_cnt keeps track of which command we are on
            WHEN 0 =>                                       --no command latched in yet
              i2c_ena <= '1';                                 --initiate the transaction
              i2c_addr <= sensor_addr;                    --set the address of the hygrometer
              i2c_rw <= '1';                                  --command 1 is a read
            WHEN 1 =>                                       --1st busy high: command 1 latched
              IF(i2c_busy = '0') THEN                         --indicates data read in command 2 is ready
                 temperature_data(15 DOWNTO 8) <= i2c_data_rd;      --retrieve humidity high-byte data from command 3
              END IF;
            WHEN 2 =>                                       --3rd busy high: command 3 latched
              IF(i2c_busy = '0') THEN                         --indicates data read in command 3 is ready
                temperature_data(7 DOWNTO 0) <= i2c_data_rd;      --retrieve humidity high-byte data from command 3
              END IF;
            WHEN 3 =>                                       --4th busy high: command 4 latched
              i2c_ena <= '0';                                 --deassert enable to stop transaction after command 4
              IF(i2c_busy = '0') THEN                         --indicates data read in command 4 is ready
                busy_cnt := 0;                                  --reset busy_cnt for next transaction
                state <= output_result;                         --advance to output the result
              END IF;
            WHEN OTHERS => NULL;
          END CASE;
  
        --output the relative humidity and temperature data
        WHEN output_result =>
          relative_humidity <= humidity_data(15 DOWNTO 0);  --write relative humidity data to output
          temperature <= temperature_data(15 downto 0);
          state <= initiate_hr;                                                     --initiate next measurement

        --default to start state
        WHEN OTHERS =>
          state <= start;

      END CASE;
    END IF;
  END PROCESS;  
END behavior;
