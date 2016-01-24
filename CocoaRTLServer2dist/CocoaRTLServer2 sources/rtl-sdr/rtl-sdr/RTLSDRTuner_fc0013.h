//
//  RTLSDRTuner_fc0013.h
//  rtl-sdr
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved. Licensed under the GPL v.2
//

#import "RTLSDRTuner.h"

#define FC0013_I2C_ADDR		0xc6
#define FC0013_CHECK_ADDR	0x00
#define FC0013_CHECK_VAL	0xa3

@interface RTLSDRTuner_fc0013 : RTLSDRTuner

@end
