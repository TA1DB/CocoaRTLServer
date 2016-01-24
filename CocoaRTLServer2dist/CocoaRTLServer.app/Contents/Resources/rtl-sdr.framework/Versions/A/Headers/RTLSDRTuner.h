//
//  RTLSDRTuner.h
//  rtl-sdr
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved. Licensed under the GPL v.2
//

//
// Mmodified 2016 by Chris Smolinski
//

#import <Foundation/Foundation.h>

@class RTLSDRDevice;

@interface RTLSDRTuner : NSObject
{
    RTLSDRDevice *device;
    
    double freq;
    double xtal;
    
    NSUInteger gain;
    NSUInteger bandWidth;
}

+ (RTLSDRTuner *)createTunerForDevice:(RTLSDRDevice *)device;

- (id)initWithDevice:(RTLSDRDevice *)dev;
- (NSString *)tunerType;

- (double)freq;
- (double)setFreq:(double)freq;

@property (readwrite) double xtal;
@property (readwrite) NSUInteger gain;
@property (readwrite) int gainMode;
@property (readwrite) NSUInteger bandWidth;

// This is used for devices like the R820t that use a non-zero IF
// this value is the offset to be added to the desired tuning freq.
@property (readonly) float tuningOffset;

@end
