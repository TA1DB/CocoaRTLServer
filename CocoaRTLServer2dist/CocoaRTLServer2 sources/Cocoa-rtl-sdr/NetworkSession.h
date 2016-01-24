//
//  NetworkSession.h
//  TCP-audio-OSX
//
//  Created by William Dillon on 11/3/11.
//  Copyright (c) 2011. All rights reserved.
//

//
// Mmodified 2016 by Chris Smolinski
//

#import <Cocoa/Cocoa.h>
#include <netdb.h>
#include <sys/types.h>
#include <sys/socket.h>

@protocol NetworkSessionDelegate <NSObject>
- (void)sessionTerminated:(id)sender;

@end

@interface NetworkSession : NSObject {
	bool connected;
	int	sock;
	int fileDescriptor;
	struct sockaddr_in server;
	struct hostent *hp;
    
	NSString *hostname;
	
	id <NetworkSessionDelegate> delegate;
	
	size_t written;
	int read;
}

- (id)initWithHost:(NSString*)hostName Port:(int)portNum;
- (id)initWithSocket:(int)socket andDescriptor:(int)fd;

- (bool)connect;
- (void)disconnect;

- (NSData*)getDataLength:(NSInteger)length;
- (int)readByte;
- (int)readCommand:(int *)arg;

- (bool)sendData:(NSData*)theData;
- (size_t)send:(int)length bytes:(void *)data;

- (void)setHostname:(NSString *)newHostname;
- (NSString *)hostname;

- (void)setDelegate:(id)del;

- (size_t)bytesWritten;
- (size_t)bytesRead;

@end
