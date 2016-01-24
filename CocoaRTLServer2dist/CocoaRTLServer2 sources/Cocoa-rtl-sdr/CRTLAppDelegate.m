//
//  CRTLAppDelegate.m
//  Cocoa-rtl-sdr
//
//  Created by William Dillon on 4/29/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

//
// Heavily modified 2016 by Chris Smolinski
//

#import "CRTLAppDelegate.h"

@implementation CRTLAppDelegate

@synthesize window = _window;

@synthesize deviceComboBox;
@synthesize tunerTypeField;

@synthesize openButton;
@synthesize networkCheckBox;
@synthesize portNumberField;

@synthesize centerFreqField;
@synthesize sampleRateField;



int sdrPortNumber=0;
char iqDataSourceAddress[256];
int udpPort;
int iqDataSourcePort;
#define SDR_DATA_BUF_LEN 8*1024*1024
unsigned char *sdrDataInputBuf;
int sdrDataInputInPtr;
int sdrDataInputOutPtr;

int sdrSampleRate;
int sdrFrequency;
int newSdrFreq;
int newSdrRate;
int totalSamplesRead=0;

BOOL rtl_tcp_connected;

BOOL isRunning=YES;
- (void)startNetworkServer
{

sdrDataInputBuf=malloc(SDR_DATA_BUF_LEN);

NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];


sdrPortNumber=(int)[defaults integerForKey: @"sdrPortNumber"];
if (sdrPortNumber<=0) sdrPortNumber=50000;
[udpPortField setIntValue:sdrPortNumber];

NSNumberFormatter *formatter = [[[NSNumberFormatter alloc] init] autorelease];
[formatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
[udpPortField setFormatter:formatter];

NSString *str1=[defaults objectForKey: @"iqDataSourceAddress"];
if (str1)
	{
	strcpy(iqDataSourceAddress,[str1 UTF8String]);
	}
else 
	{
	strcpy(iqDataSourceAddress,"127.0.0.1");
	}


iqDataSourcePort=(int)[defaults integerForKey: @"iqDataSourcePort"];
if (iqDataSourcePort<=0) iqDataSourcePort=1234;

udpPort=(int)[defaults integerForKey: @"udpPort"];
if (udpPort<=0) udpPort=58083;



[self initTransmitUDP];

isRunning=YES;
//NSThread* thread1 = [[NSThread alloc] initWithTarget:self selector:@selector(DecodeThread:) object:@"test"];
//[thread1 start];




NSTimer *tenSecondTimer = [NSTimer scheduledTimerWithTimeInterval:	10.0		// seconds
															target:		self
															selector:	@selector (TenSecTimer:)
															userInfo:	0		// makes the currently-active audio queue (record or playback) available to the updateBargraph method
															repeats:	YES];

[[NSRunLoop currentRunLoop] addTimer:tenSecondTimer forMode:NSRunLoopCommonModes];

NSTimer *ourTimer = [NSTimer scheduledTimerWithTimeInterval:	1.0		// seconds
															target:		self
															selector:	@selector (OneSecTimer:)
															userInfo:	0		// makes the currently-active audio queue (record or playback) available to the updateBargraph method
															repeats:	YES];

[[NSRunLoop currentRunLoop] addTimer:ourTimer forMode:NSRunLoopCommonModes];

NSTimer *ourTimer2 = [NSTimer scheduledTimerWithTimeInterval:	0.01		// seconds
															target:		self
															selector:	@selector (SdrTcpTimer:)
															userInfo:	0		// makes the currently-active audio queue (record or playback) available to the updateBargraph method
															repeats:	YES];

[[NSRunLoop currentRunLoop] addTimer:ourTimer2 forMode:NSRunLoopCommonModes];



listenSocket = [[AsyncSocket alloc] initWithDelegate:self ];

NSError *error = nil;

if (![listenSocket acceptOnPort:sdrPortNumber error:&error])
{
    NSLog(@"I goofed: %@", error);
}


NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
[center addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:NSApp];

if ([[NSProcessInfo processInfo] respondsToSelector:@selector(beginActivityWithOptions:reason:)]) {
        self.activity = [[NSProcessInfo processInfo] beginActivityWithOptions:0x00FFFFFF reason:@"receiving OSC messages"];
    NSLog(@"So long, app nap");
    }

}


- (void)applicationWillTerminate:(NSNotification *)application
{
isRunning=NO;
NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

[defaults setInteger:[udpPortField intValue] forKey:@"sdrPortNumber"];

[defaults synchronize];

}



AsyncSocket *ourSdrSocket;
- (void)setSocket:(AsyncSocket *)newSocket
{
ourSdrSocket=newSocket;
[ourSdrSocket retain];
}

- (void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket
{
    // The "sender" parameter is the listenSocket we created.
    // The "newSocket" is a new instance of GCDAsyncSocket.
    // It represents the accepted incoming client connection.

    // Do server stuff with newSocket...
    
    tcpReadPending=0;
    NSLog(@"didAcceptNewSocket %@",newSocket);
    [self setSocket:newSocket];
}

- (BOOL)onSocketWillConnect:(AsyncSocket *)sock
{
    NSLog(@"onSocketWillConnect %@",sock);
return YES;
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
    NSLog(@"willDisconnectWithError %@  %@",sock,err);

}


- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
    NSLog(@"onSocketDidDisconnect %@",sock);
if (sock==ourSdrSocket)
    {
    [ourSdrSocket release];
    ourSdrSocket=nil;
    tcpReadPending=0;
    }
}


- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
//    NSLog(@"didWriteDataWithTag %d",tag);

}


//04 20 01 00
//04 20 01 00
//04 20 02 00
//04 20 02 00
//05 20 04 00 00
//05 20 04 00 00
//05 20 04 00 01
//05 20 04 00 01
//04 20 05 00


- (void) sendStringToSdrDxType:(int)type ID:(int)ident String:(char *)str
{
if (!ourSdrSocket) return;

char s[1024];
int n=strlen(str)+4+1;
s[0]=n;
s[1]=type;
s[2]=ident&0xff;
s[3]=ident>>8;
strcpy(&s[4],str);
s[n]=0;

NSData *data=[NSData dataWithBytes:s length:n];
[ourSdrSocket writeData:(NSData *)data withTimeout:-1 tag:0];


}


- (void) sendVersionToSdrDxType:(int)type ID:(int)ident Parm:(int)parm Version:(int)ver
{
if (!ourSdrSocket) return;

char s[1024];
s[0]=7;
s[1]=type;
s[2]=ident&0xff;
s[3]=ident>>8;
s[4]=parm;
s[5]=ver&0xff;
s[6]=ver>>8;

NSData *data=[NSData dataWithBytes:s length:7];
[ourSdrSocket writeData:(NSData *)data withTimeout:-1 tag:0];
}


int sdrRunMode=0;
int sdrWriteTag=0;
int sdrFrequency=10000000;
int sdrSampleRate=200000*1.25;
int newSdrFreq=0;
int newSdrRate=1;

- (void) sendStatusToSdrDx
{
if (!ourSdrSocket) return;

int type=0x00;
int ident=5;
char s[1024];
s[0]=5;
s[1]=type;
s[2]=5;
s[3]=0;
//s[4]=sdrStatus;
if (sdrRunMode) s[4]=0x0c; else s[4]=0x0b;


sdrWriteTag++;
NSData *data=[NSData dataWithBytes:s length:5];
[ourSdrSocket writeData:(NSData *)data withTimeout:-1 tag:sdrWriteTag];
}


//[08][00] [18] [00] [80] [02] [00] [00]
- (void) sendRunModeResponseToSdrDx
{
if (!ourSdrSocket) return;

char s[1024];
s[0]=8;
s[1]=0;
s[2]=0x18;
s[3]=0;
s[4]=0x80;
if (sdrRunMode) s[5]=0x02; else s[4]=0x01;
s[6]=0;
s[7]=0;


sdrWriteTag++;
NSData *data=[NSData dataWithBytes:s length:8];
[ourSdrSocket writeData:(NSData *)data withTimeout:-1 tag:sdrWriteTag];
}



- (void) GotRequestPacketType:(int)type ID:(int)ident numParms:(int)numParm Parms:(int *)param
{
    char s[1024];
    char s1[256];

    s[0]=0;
    for (int i=0; i<numParmBytesRec; i++)
        {
        sprintf(s1,"%02X ",(unsigned char)paramBytes[i]);
        strcat(s,s1);
        }

if (type==1) // requesting something
    {
    switch (ident)
        {
        case 1:  // target name
        NSLog(@"request target name");
        [self sendStringToSdrDxType:0 ID:1 String:"RTLSVR"];
//        [self sendStringToSdrDxType:0 ID:1 String:"NetSDR"];
        break;
        
        
        
        case 2: // serial number
        NSLog(@"request serial number");
        [self sendStringToSdrDxType:0 ID:2 String:"012345678"];
        break;
        
        case 4: // hardware / firmware version
        NSLog(@"request hardware / firmware version %d",param[0]);
        [self sendVersionToSdrDxType:0 ID:4 Parm:param[0] Version:1234];
        break;
        
        case 5: // status
//        NSLog(@"request status ");
        [self sendStatusToSdrDx];
        break;
        
        default:
        NSLog(@"GotRequestPacketType:%d ID:%02x numParms:%d Parms:%s",type,(unsigned char)ident,numParm,s);
        break;
        }
    }


if (type==0) // setting something
    {
    switch ((unsigned char)ident)
        {
        case 0x18: // run mode     [08][00] [18] [00] [80] [02] [00] [00]
        NSLog(@"run mode %d %d",param[1],param[2]);
        if (param[1]==2)
            {
            sdrRunMode=1;
            }
        else
            {
            sdrRunMode=0;
            }
        [self sendRunModeResponseToSdrDx];
        break;
        
        case 0x20: // frequency
        sdrFrequency=(unsigned char)param[1]+(unsigned char)param[2]*256+(unsigned char)param[3]*256*256+(unsigned char)param[4]*256*256*256+(unsigned char)param[5]*256*256*256*256;
        newSdrFreq=1;
        [device setCenterFreq:sdrFrequency];
        NSLog(@"frequency %d",sdrFrequency);
        break;
        
        case 0x38: // rf gain
        NSLog(@"rf gain %d",param[1]);
        break;
        
        case 0x44: // rf filter
        NSLog(@"rf filter");
        break;
        
        case 0x8a: // a/d mode
        NSLog(@"a/d mode %d",param[1]);
        break;
        
        case 0xb4: // UNID mode
        NSLog(@"B4 UNID mode %d",param[1]);
        
        case 0xb6: // pulse mode
        NSLog(@"pulse mode %d",param[1]);
        break;
        
        case 0xb8: // sampleRate
        sdrSampleRate=(unsigned char)param[1]+(unsigned char)param[2]*256+(unsigned char)param[3]*256*256+(unsigned char)param[4]*256*256*256;
        newSdrRate=1;
        [device setSampleRate:sdrSampleRate];
        NSLog(@"sampleRate %d",sdrSampleRate);
        break;
        
         default:
        NSLog(@"GotRequestPacketType:%d ID:%02x numParms:%d Parms:%s",type,(unsigned char)ident,numParm,s);
        break;
        }

    }
    
}



int tcpState=0;
int tcpLength=0;
int tcpMsgType=0;
int controlItemID=0;
int numParmsToGet=0;
int paramBytes[256];
int numParmBytesRec=0;
- (void)TcpReceiveStateMachineByte:(int)byte
{
int canProcesss=0;

// NSLog(@"%d %d",tcpState,byte);
 
switch (tcpState)
    {
    case 0:
    tcpLength=byte;
    tcpState++;
    break;
    
    case 1:
    tcpMsgType=(byte&0xe0)>>5;
    tcpLength+=(byte&0x1f)<<3;
    tcpState++;
    break;
    
    case 2:
    controlItemID=byte;
    tcpState++;
    break;
    
    case 3:
    controlItemID+=byte<<8;
    numParmsToGet=tcpLength-4;
    numParmBytesRec=0;
    if (numParmsToGet>0)
        {
        tcpState++;
        }
    else
        {
        tcpState=0;
        canProcesss=1;
        }
    break;

    case 4:
    paramBytes[numParmBytesRec]=byte;
    numParmBytesRec++;
    if (numParmBytesRec==numParmsToGet)
        {
        tcpState=0;
        canProcesss=1;
        }
    break;

    
    }


if (canProcesss)
    {
    char s[1024];
    char s1[256];

    s[0]=0;
    for (int i=0; i<numParmBytesRec; i++)
        {
        sprintf(s1,"%02X ",paramBytes[i]);
        strcat(s,s1);
        }

//    NSLog(@"Rec Packet Len: %d  Type: %d    ID: %02X   Parms: %d '%s'",tcpLength,tcpMsgType,(unsigned char)controlItemID,numParmsToGet,s);
    [self GotRequestPacketType:tcpMsgType ID:controlItemID numParms:numParmBytesRec Parms:paramBytes];
    tcpState=0;
    }

    
}


- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
char *dat=[data bytes];
int n=[data length];

char s[1024];
char s1[256];

s[0]=0;
for (int i=0; i<n; i++)
    {
    sprintf(s1,"%02X ",dat[i]);
    strcat(s,s1);
    [self TcpReceiveStateMachineByte:dat[i]];
    }
    
//    NSLog(@"didReadData tag=%d len=%d  '%s'",(int)tag,n,s);
tcpReadPending=0;


}

int tcpReadTag=0;
int tcpReadPending=0;
- (void) SdrTcpTimer: (NSTimer *) timer
{

static BOOL oldRunMode=NO;
if (sdrRunMode!=oldRunMode)
    {
    oldRunMode=sdrRunMode;
//    [self networkToggle:networkCheckBox];
    }
    


if (!ourSdrSocket) return;
if (tcpReadPending) return;

tcpReadTag++;
[ourSdrSocket readDataWithTimeout:-1 tag:tcpReadTag];
tcpReadPending=1;

        if (sdrRunMode) [self doSdrUdp]; else sdrDataInputOutPtr=sdrDataInputInPtr;

}



#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>


-(void) SdrNetworkThread: (NSString *) arg {
//[NSThread setThreadPriority:1.0];
//	[self performSelectorOnMainThread:@selector(displayNoConnectAlert:)  withObject:nil waitUntilDone:NO];





// Open a socket
int sdudp = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
if (sdudp<=0)
    {
    puts("Error: Could not open socket");
    return ;
    }

// Set socket options
// Enable broadcast
int broadcastEnable=1;
broadcastEnable=0;
int ret=setsockopt(sdudp, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, sizeof(broadcastEnable));
if (ret)
    {
    puts("Error: Could not open set socket to broadcast mode");
    close(sdudp);
    return ;
    }

// Since we don't call bind() here, the system decides on the port for us, which is what we want.    


// Configure the port and ip we want to send to
struct sockaddr_in broadcastAddr; // Make an endpoint
memset(&broadcastAddr, 0, sizeof broadcastAddr);
    broadcastAddr.sin_family = AF_INET;
inet_pton(AF_INET, "127.0.0.1", &broadcastAddr.sin_addr); // Set the broadcast IP address
    broadcastAddr.sin_port = htons(sdrPortNumber); // Set port 50000

char dataPacket[1028];
int i=0;


 // Set buffer size
int sendbuff;
 sendbuff = 98304;

 printf("sets the send buffer to %d\n", sendbuff);
 int res = setsockopt(sdudp, SOL_SOCKET, SO_SNDBUF, &sendbuff, sizeof(sendbuff));


// Get buffer size
 int optlen = sizeof(sendbuff);
  res = getsockopt(sdudp, SOL_SOCKET, SO_SNDBUF, &sendbuff, &optlen);

 if(res == -1)
     printf("Error getsockopt one");
 else
     printf("send buffer size = %d\n", sendbuff);



while (1)
    {
int dataToSend;
dataToSend=sdrDataInputInPtr-sdrDataInputOutPtr;
if (dataToSend<0) dataToSend=dataToSend+SDR_DATA_BUF_LEN;
i=0;
if (!sdrRunMode)
    {
    dataToSend=0;
    sdrDataInputOutPtr=sdrDataInputInPtr;
    }

while (dataToSend>=512)
    {
    dataPacket[0]=0x04;
    dataPacket[1]=0x84;
    dataPacket[2]=sdrSeqNum&0xff;
    dataPacket[3]=(sdrSeqNum>>8)&0xff;
    short *buf2;
    buf2=(short *)&dataPacket[4];

    for (int j=0; j<256; j++)
        {
        int ii = sdrDataInputBuf[sdrDataInputOutPtr];
        sdrDataInputOutPtr++;
        if (sdrDataInputOutPtr>=SDR_DATA_BUF_LEN) sdrDataInputOutPtr=0;
        int qq = sdrDataInputBuf[sdrDataInputOutPtr];
        sdrDataInputOutPtr++;
        if (sdrDataInputOutPtr>=SDR_DATA_BUF_LEN) sdrDataInputOutPtr=0;
        ii=ii-128;
        qq=qq-128;
        buf2[j*2]=ii*2;
        buf2[j*2+1]=qq*2;
        }
    
    int ret = sendto(sdudp, dataPacket, 1028, 0, (struct sockaddr*)&broadcastAddr, sizeof broadcastAddr);
    if (ret<0)
        {
        puts("Error: Could not open send broadcast");
        }

    sdrSeqNum++;
    dataToSend=sdrDataInputInPtr-sdrDataInputOutPtr;
    if (dataToSend<0) dataToSend=dataToSend+SDR_DATA_BUF_LEN;
    i++;
    }
    
    if (i) printf("packets sent: %d \r\n",i);
//	usleep(100);  // 0.01 sec
    }
}


-(void)_workerLoop {
return;

[self SdrNetworkThread:@"dummy"];
return;

while (1)
{
        if (sdrRunMode) [self doSdrUdp]; else sdrDataInputOutPtr=sdrDataInputInPtr;
	usleep(10000);  // 0.01 sec
}

}



int sdrSeqNum=0;
// 0x04 0x84 16 bit sequence 1024 data bytes 256 16 bit i/q samples
- (void) doSdrUdp
{
//NSLog(@"sendUdp ");
unsigned char buf[1028];
int max=-9999, min=9999;

int i=0;
int dataToSend;
dataToSend=sdrDataInputInPtr-sdrDataInputOutPtr;
if (dataToSend<0) dataToSend=dataToSend+SDR_DATA_BUF_LEN;
while (dataToSend>=512)
{
buf[0]=0x04;
buf[1]=0x84;
buf[2]=sdrSeqNum&0xff;
buf[3]=(sdrSeqNum>>8)&0xff;
short *buf2;
buf2=(short *)&buf[4];

for (int j=0; j<256; j++)
    {
        int ii = sdrDataInputBuf[sdrDataInputOutPtr];
//        if (ii>max) max=ii;
//        if (ii<min) min=ii;
    sdrDataInputOutPtr++;
    if (sdrDataInputOutPtr>=SDR_DATA_BUF_LEN) sdrDataInputOutPtr=0;
        int qq = sdrDataInputBuf[sdrDataInputOutPtr];
    sdrDataInputOutPtr++;
    if (sdrDataInputOutPtr>=SDR_DATA_BUF_LEN) sdrDataInputOutPtr=0;
    ii=ii-128;
    qq=qq-128;
    buf2[j*2]=ii*16;
    buf2[j*2+1]=qq*16;
    }
sdrSeqNum++;
NSData *data=[NSData dataWithBytes:buf length:1028];
//	NSData *data22=[[NSData alloc] initWithBytes:&packet length:sizeof(packet)];
//	[self performSelectorOnMainThread:@selector(sendPacket:)  withObject:data waitUntilDone:NO];
	BOOL rt=[socket2 sendData:data toHost:@"127.0.0.1" port:sdrPortNumber withTimeout:-1 tag:0];
//	NSLog(@"sendData %d",(int)rt);

dataToSend=sdrDataInputInPtr-sdrDataInputOutPtr;
if (dataToSend<0) dataToSend=dataToSend+SDR_DATA_BUF_LEN;
i++;
}

if (i) NSLog(@"doSdrUdp %d %d %d",i,min,max);


}

- (void)sendPacket:(id)data
{
	BOOL rt=[socket2 sendData:data toHost:@"127.0.0.1" port:sdrPortNumber withTimeout:-1 tag:0];
}




- (void) TenSecTimer: (NSTimer *) timer
{
float samplesPerSecond=totalSamplesRead;
samplesPerSecond=samplesPerSecond/10.0/2.0;
NSLog(@"samplesPerSecond %f",samplesPerSecond);
totalSamplesRead=0;
[actualRateLabel setIntValue:samplesPerSecond];
}

- (void) OneSecTimer: (NSTimer *) timer
{

if (sdrRunMode) [statusLabel setStringValue:@"Running"]; else [statusLabel setStringValue:@"Idle"]; 
[sampleRateLabel setFloatValue:(float)sdrSampleRate/1000.0];
[centerFreqLabel setFloatValue:(float)sdrFrequency/1000.0];

if (ourSdrSocket) [connectedLabel setStringValue:@"Yes"]; else [connectedLabel setStringValue:@"No"];
if (rtl_tcp_connected) [rtlConnectedLabel setStringValue:@"Yes"]; else [rtlConnectedLabel setStringValue:@"No"];

}


int lastTag=0;









- (void) initTransmitUDP
{

socket2 = [[AsyncUdpSocket alloc] initWithDelegate:self];
BOOL bcErr=[socket2 enableBroadcast:YES error:nil]; 
NSLog(@"enableBroadcast %d",(int)bcErr);
//NSData *data22=[[NSData alloc] initWithBytes:"testing" length:5];
//BOOL rt=[socket2 sendData:data22 toHost:@"255.255.255.255" port:RXPORT withTimeout:2 tag:0];
//NSLog(@"sendData %d",(int)rt);


/*
BOOL rt=[socket2 bindToPort:RXPORT error:nil]; //returns YES


if (rt) NSLog(@"bindToPort OK"); else NSLog(@"bindToPort fail");
[socket2 receiveWithTimeout:-1 tag:1];  

NSData *data22=[[NSData alloc] initWithBytes:"testing" length:5];
rt=[socket2 sendData:data22 toHost:@"255.255.255.255" port:RXPORT withTimeout:2 tag:0];
if (rt) NSLog(@"sendData OK"); else NSLog(@"sendData fail");*/

}

- (void) sendUdp:(id)theId
{
//NSLog(@"sendUdp %@",theId);

//	NSData *data22=[[NSData alloc] initWithBytes:&packet length:sizeof(packet)];
	BOOL rt=[socket2 sendData:theId toHost:@"255.255.255.255" port:udpPort withTimeout:2 tag:0];
//	NSLog(@"sendData %d",(int)rt);
[theId release];

}


-(void) displayNoConnectAlert:(id)dummy
{
	NSAlert *alert = [NSAlert alertWithMessageText: @"Could not connect to I/Q data source."
                                 defaultButton:@"OK"
                               alternateButton:nil
                                   otherButton:nil
                     informativeTextWithFormat:@"Make sure rtl_tcp is running and that you have the correct port set."];

NSInteger button = [alert runModal];
}



-(void) DecodeThread: (NSString *) arg {
[NSThread setThreadPriority:1.0];







}



















- (void)dealloc
{
    [super dealloc];
}

- (NSArray *)deviceList
{
    return deviceList;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
/*
    // Disable signals for broken pipe (they're handled during the send call)
	struct sigaction act;		
	if( sigaction(SIGPIPE, NULL, &act) == -1)
		perror("Couldn't find the old handler for SIGPIPE");
	else {
        if (act.sa_handler == SIG_DFL) {
            act.sa_handler = SIG_IGN;
            if( sigaction(SIGPIPE, &act, NULL) == -1)
                perror("Could not ignore SIGPIPE");
            else
                NSLog(@"Ignoring SIGPIPE");
        }
    }
*/

    NSArray *tempDeviceList = [RTLSDRDevice deviceList];
    
    deviceList = [[NSMutableArray alloc] initWithCapacity:[tempDeviceList count]];
    for (NSDictionary *dict in tempDeviceList) {
        NSString *name = [dict objectForKey:@"deviceName"];
        if (name == nil) {
            NSLog(@"Nil name received from device list...  this is bad.");
        } else {
            [deviceList addObject:name];
        }
    }
    
    [deviceComboBox bind:NSContentBinding
                toObject:self
             withKeyPath:@"self.deviceList"
                 options:nil];
    
    if ([deviceComboBox numberOfItems]>0) [deviceComboBox selectItemAtIndex:0];
    
    sessions = [[NSMutableArray alloc] init];
    
    [self startNetworkServer];
}

- (IBAction)openDevice:(id)sender
{
    NSInteger index = [deviceComboBox indexOfSelectedItem];
    device = [[RTLSDRDevice alloc] initWithDeviceIndex:index];
    
    if (device == nil) {
        NSLog(@"Unable to open device");
    } else {
        if ([device tuner] != nil) {
            [tunerTypeField setStringValue:[[device tuner] tunerType]];

            // Set the initial frequencies from the text fields
            [device setCenterFreq:[[self centerFreqField] intValue]];
            [device setSampleRate:[[self sampleRateField] intValue]];
        }
    }
        
//    [networkCheckBox setEnabled:YES];
    [networkCheckBox setState:1];
    [openButton setEnabled:NO];
    [self networkToggle:networkCheckBox];
    [deviceComboBox setEnabled:NO];
}

#define SAMPLES_PER_READ 4096

//#define FIFO_LEN 8*1024*1024
//FIFO_STRUCT fifoStruct;

- (IBAction)networkToggle:(id)sender
{

    // Network start enabled
    if ([networkCheckBox state] == NSOnState)
{

        // If the server hasn't been allocated, create it
        if (server == nil) {
            server = [[NetworkServer alloc] init];
            [server setDelegate:self];
        [server openWithPort:[portNumberField intValue]];
        [server acceptInBackground];
        }

//        if (fifoStruct.fifoBuf==nil) fifoStruct.fifoBuf=malloc(FIFO_LEN);
        

        // Start reading from the USB device
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
        dispatch_async(dispatch_queue_create("com.example.MyQueue", NULL),
        ^{

[device resetEndpoints];
running = YES;
            
static int testSocket=-1;
static struct sockaddr_in destAddr;
if (testSocket==-1)
{
NSLog(@"Create UDP socket ");
    destAddr.sin_family = AF_INET;
    destAddr.sin_port = htons(sdrPortNumber);
    destAddr.sin_addr.s_addr = inet_addr("127.0.0.1");
    testSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
}
          
// Create and assign the block
RTLSDRAsyncBlock block= ^void(NSData *resultData, float duration)
{

int n=(int)[resultData length];
if (n!=SAMPLES_PER_READ) NSLog(@"Only read %d samples!!",n);
totalSamplesRead += n;

uint8_t *inputSamples=[resultData bytes];

/*
n=4096;
for (int i=0; i<n; i++)
    {
    fifoStruct.fifoBuf[fifoStruct.fifoBufInPtr]=inputSamples[i];
    fifoStruct.fifoBufInPtr++;
    fifoStruct.fifoBufInPtrBak++;
    if(fifoStruct.fifoBufInPtr>=FIFO_LEN) fifoStruct.fifoBufInPtr=0;
    if(fifoStruct.fifoBufInPtrBak>=FIFO_LEN) fifoStruct.fifoBufInPtrBak=0;

    fifoStruct.fifoBufInPtrTest++;
    if(fifoStruct.fifoBufInPtrTest>=FIFO_LEN) fifoStruct.fifoBufInPtrTest=0;
    
    if (fifoStruct.fifoBufInPtr != fifoStruct.fifoBufInPtrBak) NSLog(@"Not the same!!  %d %d %d",fifoStruct.fifoBufInPtr,fifoStruct.fifoBufInPtrBak,fifoStruct.fifoBufInPtrTest);
    }

    if (fifoStruct.fifoBufInPtr&0x01 || fifoStruct.fifoBufInPtrBak&0x01) NSLog(@"One is odd!!  %d %d ",fifoStruct.fifoBufInPtr,fifoStruct.fifoBufInPtrBak);
*/

int jj=0;
for (int kk=0; kk<8; kk++)
{

    //NSLog(@"sendUdp ");
    unsigned char buf[1028];
    int max=-9999, min=9999;

    buf[0]=0x04;
    buf[1]=0x84;
    buf[2]=sdrSeqNum&0xff;
    buf[3]=(sdrSeqNum>>8)&0xff;
    short *buf2;
    buf2=(short *)&buf[4];

    for (int j=0; j<256; j++)
        {
        int ii = inputSamples[jj];
        jj++;
        int qq = inputSamples[jj];
        jj++;
//        if (ii>max) max=ii;
//        if (ii<min) min=ii;
//        ii=ii-128;
//        qq=qq-128;
        buf2[j*2]=ii*8-128*8;
        buf2[j*2+1]=qq*8-128*8;
        }

    if (sdrRunMode)
        {
        sdrSeqNum++;
        int errorCode = sendto(testSocket, buf, 1028, 0, &destAddr, sizeof(destAddr));
        if (errorCode<0) NSLog(@"sendData errorCode %d",(int)errorCode);
        }
}




                    // Get a stable copy of the sessions
                    NSArray *tempSessions;
                        tempSessions = [[NSArray alloc]initWithArray:sessions];
                    

                    // Send the data to every session (asynch)
                    for (NetworkSession *session in tempSessions) {

                    NSData *dat=[NSData dataWithBytes:inputSamples length:n];
                    [session sendData:dat];
                    }

                    
                    
                    [tempSessions release];




};
        

[device readAsynchLength:SAMPLES_PER_READ withBlock:block];
       


            // While the running variable remains YES, collect samples
            do {
                @autoreleasepool {
                usleep(10000);
                    // Perform the read 
//                    NSData *inputData = [device readSychronousLength:4096];
//                    const uint8_t *inputSamples = [inputData bytes];
                   
//                    int n=[device readSychronousLength:4096 buffer:inputSamples];

//totalSamplesRead += n;
    
/*
int n;

n=fifoStruct.fifoBufInPtr-fifoStruct.fifoBufOutPtr;
if (n<0) n=n+FIFO_LEN;
NSLog(@"%d   %d %d   %d %d    %d",n,fifoStruct.fifoBufInPtr,fifoStruct.fifoBufInPtrBak,fifoStruct.fifoBufOutPtr,totalSamplesRead,fifoStruct.fifoBufInPtrTest);

while (n>=512)
{

uint8_t theSamples[8192];
for (int i=0; i<512; i++)
    {
    theSamples[i]=fifoStruct.fifoBuf[fifoStruct.fifoBufOutPtr];
    fifoStruct.fifoBufOutPtr++;
    if(fifoStruct.fifoBufOutPtr>=FIFO_LEN) fifoStruct.fifoBufOutPtr=0;
    }

    //NSLog(@"sendUdp ");
    unsigned char buf[1028];
    int max=-9999, min=9999;

    int jj=0;
    buf[0]=0x04;
    buf[1]=0x84;
    buf[2]=sdrSeqNum&0xff;
    buf[3]=(sdrSeqNum>>8)&0xff;
    short *buf2;
    buf2=(short *)&buf[4];

    for (int j=0; j<256; j++)
        {
        int ii = theSamples[jj];
        jj++;
        int qq = theSamples[jj];
        jj++;
//        if (ii>max) max=ii;
//        if (ii<min) min=ii;
//        ii=ii-128;
//        qq=qq-128;
        buf2[j*2]=ii*8-128*8;
        buf2[j*2+1]=qq*8-128*8;
        }

    if (sdrRunMode)
        {
        sdrSeqNum++;
        int errorCode = sendto(testSocket, buf, 1028, 0, &destAddr, sizeof(destAddr));
        if (errorCode<0) NSLog(@"sendData errorCode %d",(int)errorCode);
        }
    

n=fifoStruct.fifoBufInPtr-fifoStruct.fifoBufOutPtr;
if (n<0) n=n+FIFO_LEN;


}

NSLog(@"%d   %d %d   %d %d     %d",n,fifoStruct.fifoBufInPtr,fifoStruct.fifoBufInPtrBak,fifoStruct.fifoBufOutPtr,totalSamplesRead,fifoStruct.fifoBufInPtrTest);

*/




/* */

                    // Get a stable copy of the sessions
                    NSArray *tempSessions;
                        tempSessions = [[NSArray alloc]initWithArray:sessions];
                    

                    // Send the data to every session (asynch)
                    for (NetworkSession *session in tempSessions) {


                    
                    int arg;
                    int c=[session readCommand:&arg];

                    if (c>-1)
                        {
                        if (c==1)
                            {
                            [device setCenterFreq: arg];
                            sdrFrequency=arg;
                            }
                        if (c==2)
                            {
                            [device setSampleRate: arg];
                            [sampleRateLabel setIntValue:arg];
                            sdrSampleRate=arg;
                            }
                        }
                    }
                    
                    [tempSessions release];

                    
                    
                    
 
//                NSLog(@"send data");

//                    NSMutableData *outputData = [[NSMutableData alloc] initWithLength:sizeof(float) * 4096];
//                    float *outputSamples = [outputData mutableBytes];
                    
                    // Convert the samples from bytes to floats between -1 and 1
//                    for (int i = 0; i < 4096; i++) {
//                        outputSamples[i] = (float)(inputSamples[i] - 127) / 128;
//                    }
                    
                    
//                    [outputData release];
//                    [tempSessions release];
//                        [inputData release];
//	usleep(1000);  // 0.01 sec

                }
            } while (running);
        });


    }


    
    // Network stop requested
    else {
        // Stop reading from the USB
        running = NO;
        [device stopReading];
        // Stop the sessions
        [sessions removeAllObjects];
        // Stop the server
        [server close];
    }    
}




-(IBAction)updateTuner:(id)sender
{
NSLog(@"UpdateTuner");
    [device setSampleRate:[[self sampleRateField] intValue]];
    [device setCenterFreq:[[self centerFreqField] intValue]];
}

#pragma mark -
#pragma mark Delegate Methods

#pragma mark -
#pragma mark NetworkServer Delegate Methods
- (void)NetworkServer:(NetworkServer *)theServer
           newSession:(NetworkSession *)newSession
{
	NSLog(@"Accepted new session.");
	
    rtl_tcp_connected=YES;
    [newSession retain];
    [newSession setDelegate:self];

    @synchronized(sessions) {
        [sessions addObject:newSession];
    }
}

#pragma mark -
#pragma mark NetworkSession Delegate Methods
- (void)sessionTerminated:(NetworkSession *)session
{
    NSLog(@"Removed a session.");
    rtl_tcp_connected=NO;
    @synchronized(sessions) {
        [sessions removeObject:session];
    }
}

@end
