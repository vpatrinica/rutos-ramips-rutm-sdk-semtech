/*
 / _____)             _              | |
( (____  _____ ____ _| |_ _____  ____| |__
 \____ \| ___ |    (_   _) ___ |/ ___)  _ \
 _____) ) ____| | | || |_| ____( (___| | | |
(______/|_____)_|_|_| \__)_____)\____)_| |_|
  (C)2019 Semtech

Description:
    Basic driver for ST ts751 temperature sensor

License: Revised BSD License, see LICENSE.TXT file include in the project
*/


/* -------------------------------------------------------------------------- */
/* --- DEPENDANCIES --------------------------------------------------------- */

#include <stdint.h>     /* C99 types */
#include <stdbool.h>    /* bool type */
#include <stdio.h>      /* printf fprintf */

#include "loragw_i2c.h"
#include "loragw_stts751.h"

/* -------------------------------------------------------------------------- */
/* --- PRIVATE MACROS ------------------------------------------------------- */

#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#if DEBUG_I2C == 1
    #define DEBUG_MSG(str)              fprintf(stdout, str)
    #define DEBUG_PRINTF(fmt, args...)  fprintf(stdout,"%s:%d: "fmt, __FUNCTION__, __LINE__, args)
    #define CHECK_NULL(a)               if(a==NULL){fprintf(stderr,"%s:%d: ERROR: NULL POINTER AS ARGUMENT\n", __FUNCTION__, __LINE__);return LGW_REG_ERROR;}
#else
    #define DEBUG_MSG(str)
    #define DEBUG_PRINTF(fmt, args...)
    #define CHECK_NULL(a)               if(a==NULL){return LGW_REG_ERROR;}
#endif



/* -------------------------------------------------------------------------- */
/* --- PUBLIC FUNCTIONS DEFINITION ------------------------------------------ */

int stts751_configure(int i2c_fd, uint8_t i2c_addr) {

	i2c_fd = 0;
	i2c_addr = 0;
    return LGW_I2C_SUCCESS;
}

/* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */

int stts751_get_temperature(int i2c_fd, uint8_t i2c_addr, float * temperature) {
    
    i2c_fd = 0;
	i2c_addr = 0;
    *temperature = 0.0;

    DEBUG_PRINTF("Temperature: %f C (h:0x%02X l:0x%02X)\n", *temperature, high_byte, low_byte);

    return LGW_I2C_SUCCESS;
}

/* --- EOF ------------------------------------------------------------------ */
