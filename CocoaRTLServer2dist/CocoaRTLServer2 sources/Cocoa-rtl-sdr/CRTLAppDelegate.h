//
//  CRTLAppDelegate.h
//  Cocoa-rtl-sdr
//
//  Created by William Dillon on 4/29/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

//
// Heavily modified 2016 by Chris Smolinski
//

#import <Cocoa/Cocoa.h>
#import <rtl-sdr/RTLSDRDevice.h>

#import "NetworkServer.h"
#import "NetworkSession.h"
#import "AsyncUdpSocket.h"
#import "AsyncSocket.h"

typedef struct
{
__block int fifoBufInPtrTest;
__block int fifoBufInPtr;
__block int fifoBufOutPtr;
__block int fifoBufOutPtr2;
__block int fifoBufInPtrBak;
__block uint8_t *fifoBuf;
} FIFO_STRUCT;

@interface CRTLAppDelegate : NSObject <NSApplicationDelegate, NetworkServerDelegate>
{
    RTLSDRDevice *device;

    NetworkServer *server;
    NSMutableArray *sessions;
    
    NSMutableArray *deviceList;
    
    bool running;
    
    IBOutlet NSTextField *udpPortField;
    IBOutlet NSTextField *statusLabel;
    IBOutlet NSTextField *sampleRateLabel;
    IBOutlet NSTextField *centerFreqLabel;
    IBOutlet NSTextField *connectedLabel;
    IBOutlet NSTextField *rtlConnectedLabel;
    IBOutlet NSTextField *actualRateLabel;
AsyncSocket *listenSocket;
AsyncUdpSocket *socket2;


}

@property (retain) IBOutlet NSComboBox *deviceComboBox;
@property (retain) IBOutlet NSTextField *tunerTypeField;

@property (retain) IBOutlet NSTextField *portNumberField;
@property (retain) IBOutlet NSButton *networkCheckBox;
@property (retain) IBOutlet NSButton *openButton;

@property (retain) IBOutlet NSTextField *centerFreqField;
@property (retain) IBOutlet NSTextField *sampleRateField;

@property (assign) IBOutlet NSWindow *window;
@property (strong) id activity;

- (IBAction)openDevice:(id)sender;
- (IBAction)networkToggle:(id)sender;
- (IBAction)updateTuner:(id)sender;

- (NSArray *)deviceList;

@end
