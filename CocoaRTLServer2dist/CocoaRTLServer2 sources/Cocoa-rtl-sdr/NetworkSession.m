//
//  NetworkSession.m
//  TCP-audio-OSX
//
//  Created by William Dillon on 11/3/11.
//  Copyright (c) 2011. All rights reserved.
//

//
// Mmodified 2016 by Chris Smolinski
//

#import "NetworkSession.h"

@implementation NetworkSession

- (id)initWithHost:(NSString*)inHostName Port:(int)inPort
{
	self = [super init];
	
    NSLog(@"Attempting to connect to: %@:%d", inHostName, inPort);
    
	if( self != nil ) {		
		hp = gethostbyname( [inHostName UTF8String] );
		if( hp == nil ) {
			perror( "Looking up host address" );
			goto error;
		}
		
		sock = socket( AF_INET, SOCK_STREAM, 0 );
		if( sock == -1 ) {
			perror( "Opening Socket" );
			goto error;
		}
		
		memcpy((char *)&server.sin_addr, hp->h_addr_list[0], hp->h_length);
		server.sin_port = htons((short)inPort);
		server.sin_family = AF_INET;
        
		written = read =  0;
		fileDescriptor = -1;
        
        hostname = [inHostName retain];
	} 
    
	return self;
	
error:
	perror("Creating socket for Network Session");
	self = nil;
	return self;
}

- (id)initWithSocket:(int)socket andDescriptor:(int)fd
{
	self = [super init];
	
	if( self != nil ) {
    
		written = read =  0;
		sock = socket;
		fileDescriptor = fd;
		connected = true;
        hostname = nil;
	}
	
	return self;
	
error:
	perror("Creating socket for Network Session");
	self = nil;
	return self;	
}

- (bool)connect
{
		NSLog(@" connect()");
	int retval;
	
	while( ((retval = connect( sock, (struct sockaddr *)&server, sizeof(server))) == -1)
          && (errno == EINTR) )
		;
	
	if( retval == -1 ) {
		perror("Unable to connect");
		connected = NO;
	} else {
		
		// When the remote connection is closed, we DO NOT want a SIGPIPE: ask for a EPIPE instead.
		int opt_yes = 1;
		setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &opt_yes, sizeof(opt_yes));
		NSLog(@" set SO_NOSIGPIPE");
		connected = YES;
		fileDescriptor = sock;
	}
    
	return connected;
}

- (void)disconnect
{
NSLog(@"disconnect");
	close(fileDescriptor);
	sock = -1;
	fileDescriptor = -1;
	connected = NO;
}

- (bool)sendData:(NSData*)theData
{
	ssize_t retval;
	NSInteger localWritten = 0;
	NSInteger dataLength;
    
    [theData retain];
    const void *bytes = [theData bytes];
    dataLength  = [theData length];
	
	if( !connected ) {
		if( ![self connect] ) {
			perror("Unable to send, not connected and unable to connect");
            [theData release];
			return NO;
		}
	}
	
    
	do {
        // Send the remaining data
        // We send the data plus the offest of data alread sent (starting at 0)
        // And the length of the remaining data to be sent (starting with total)


		retval = send(fileDescriptor,
                      bytes + localWritten,
                      dataLength - localWritten, 0);

   if (retval<0) NSLog(@"retval %d",(int)retval);

		// Evaluate recoverable errors
        if (retval < 0) {
            if (errno != EINTR  &&
                errno != EAGAIN &&
                errno != ENOBUFS) {
                NSLog(@"Unrecoverable error sending data to session %s", strerror(errno));
                [theData release];
                [delegate sessionTerminated:self];
                return NO;
            }
            
            // This error indicates a transient condition, so let's wait
            // for some small period instead of thrashing. (.001 seconds)
            if (errno == ENOBUFS) {
                NSLog(@"Network send ran out of buffers, retrying.");
                usleep(1000);
            }
        }
		
		localWritten += retval;
		
	} while( localWritten < dataLength );

	[theData release];
	return YES;
}

- (size_t)send:(int)length bytes:(void *)data
{
	if( !connected ) {
		if( ![self connect] ) {
			perror("Unable to send, not connected and unable to connect");
			return NO;
		}
	}
	

	ssize_t retval;
    retval = send( fileDescriptor, data, length, 0 );
    if( retval < 0 ) {
		perror("Writing data");
		if( errno == EPIPE ) {
			[delegate sessionTerminated:self];
		}
	}
	
	return retval;
}

- (NSData*)getDataLength:(NSInteger)length
{
	if( !connected ) {
		if( ![self connect] ) {
			perror("Unable to receive, not connected and unable to connect");
			return nil;
		}
	}
    
    NSMutableData *tempData = [[NSMutableData alloc] initWithLength:length];
    void *bytes = [tempData mutableBytes];
    ssize_t retval = recv(fileDescriptor, bytes, length, MSG_WAITALL);
	
    if (retval != length) {
        NSLog(@"Unable to complete read.");
        [tempData release];
        return nil;
    }
    
	return [tempData autorelease];
}


- (int)readByte
{
	if( !connected ) {
		if( ![self connect] ) {
			perror("Unable to receive, not connected and unable to connect");
			return nil;
		}
	}
    
    char bytes[256];
    ssize_t retval = recv(fileDescriptor, bytes, 1, 0);
	
    if (retval<1) return -1;
    return bytes[0];
    
}

int numRcdBytes=0;
unsigned char rcvBytes[256];

- (int)readCommand:(int *)arg
{
	if( !connected ) {
		if( ![self connect] ) {
			perror("Unable to receive, not connected and unable to connect");
			return nil;
		}
	}
    
    char bytes[256];
    ssize_t retval=1;
    while (retval>=1)
        {
        retval = recv(fileDescriptor, bytes, 1, MSG_DONTWAIT);
        
        if (retval==1)
            {
            rcvBytes[numRcdBytes]=bytes[0];
            numRcdBytes++;
            
            if (numRcdBytes==5)
                {
                int cmd=rcvBytes[0];
                int *valuePtr=(int *)&rcvBytes[1];
                int value=CFSwapInt32(*valuePtr);
                NSLog(@"readCommand %d %d",cmd,value);
                numRcdBytes=0;
                *arg=value;
                return cmd;
                }
            }
        }
//     NSLog(@"readCommand none");
    return -1;
    
}


- (size_t)bytesWritten
{
	return written;
}

- (size_t)bytesRead
{
	return read;
}

- (NSString *)hostname
{
	NSString *retval = [hostname copy];
    [retval autorelease];
    
    return retval;
}

- (void)setHostname:(NSString *)newHostname
{
    if (hostname != nil) {
        [hostname release];
    }
    
	hostname = newHostname;
    [hostname retain];
}

- (void)setDelegate:(id)del
{
	delegate = del;
}

@end
