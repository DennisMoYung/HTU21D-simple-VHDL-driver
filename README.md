# htu21d Simple VHDL Driver Project

## description
This project is a simple VHDL driver for HTU21D within I2C interface.

## testing environment
 * Vivado 2022.1
 * Zedboard
 * 50Mhz clock

## content
This project provide a simple driver for HTU21D RH/T SENSOR IC which is under the default setting (12 bit for RH/ 14 bit for T). All the conversion for data can be found at [page15](https://www.te.com/commerce/DocumentDelivery/DDEController?Action=showdoc&DocId=Data+Sheet%7FHPC199_6%7FA6%7Fpdf%7FEnglish%7FENG_DS_HPC199_6_A6.pdf%7FHPP845E031R5) of datasheet (example: RH = -6 + 125 * S / (2^16)). If you are interested to use others setting for the IC, please follow the command provided on datasheet and create one more configure state after the "reset_pause" has been finished.

## reference
 * The detail for the I2C master can be found on [I2C Master (VHDL)](https://forum.digikey.com/t/i2c-master-vhdl/12797)
 * All the detail of HTU21D can be found on [Datasheet for HTU21D](https://www.te.com/commerce/DocumentDelivery/DDEController?Action=showdoc&DocId=Data+Sheet%7FHPC199_6%7FA6%7Fpdf%7FEnglish%7FENG_DS_HPC199_6_A6.pdf%7FHPP845E031R5)