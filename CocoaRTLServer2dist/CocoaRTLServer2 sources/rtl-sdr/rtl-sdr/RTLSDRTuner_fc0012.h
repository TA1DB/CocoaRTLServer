//
//  RTLSDRTuner_fc0012.h
//  rtl-sdr
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved. Licensed under the GPL v.2
//

#import "RTLSDRTuner.h"

#define FC0012_OK	0
#define FC0012_ERROR	1

#define FC0012_I2C_ADDR		0xc6
#define FC0012_CHECK_ADDR	0x00
#define FC0012_CHECK_VAL	0xa1

#define FC0012_BANDWIDTH_6MHZ	6
#define FC0012_BANDWIDTH_7MHZ	7
#define FC0012_BANDWIDTH_8MHZ	8

#define FC0012_LNA_GAIN_LOW	0x00
#define FC0012_LNA_GAIN_MID	0x08
#define FC0012_LNA_GAIN_HI	0x17
#define FC0012_LNA_GAIN_MAX	0x10

int FC0012_Open(void *pTuner);
int FC0012_Read(void *pTuner, unsigned char RegAddr, unsigned char *pByte);
int FC0012_Write(void *pTuner, unsigned char RegAddr, unsigned char Byte);
int FC0012_SetFrequency(void *pTuner, unsigned long Frequency, unsigned short Bandwidth);

@interface RTLSDRTuner_fc0012 : RTLSDRTuner

@end
