//
//  NetworkServer.m
//  TCP-audio-OSX
//
//  Created by William Dillon on 11/3/11.
//  Copyright (c) 2011. All rights reserved.
//

//
// Mmodified 2016 by Chris Smolinski
//

#import "NetworkServer.h"

#include <sys/types.h>
#include <sys/socket.h>
#include <errno.h>
#include <unistd.h>
#include <netdb.h>
#include <signal.h>
#include <stdio.h>

@implementation NetworkServer

- (id)init {
	if( init != 0xdeadbeef ) {
		return self;
	}
	
	self = [super init];
	
	if( self != nil ) {
		NSLog(@"Initializing NetworkServer.\n");
		
		init	= true;
        error   = false;
		started = false;
        
	} else {
		NSLog(@"Error initializing NetworkServer class.\n");
	}
    
    
	return self;
}

- (int)open
{
    if([self openWithPort:0]) {
        return [self port];
    } else {
        return -1;
    }
}

- (bool)openWithPort:(int)inPort {	
	struct sockaddr_in server;
    
	NSLog(@"Starting NetworkServer.\n");
    
	port = inPort;
    
	if( (sock = socket(AF_INET, SOCK_STREAM, 0)) < 0 ) {
		NSLog(@"Error creating socket");
		error = true;
		return false;
	}
	
    		int opt_yes = 1;
		setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &opt_yes, sizeof(opt_yes));
		NSLog(@" set SO_NOSIGPIPE %d" , sock);

	server.sin_family = AF_INET;
	server.sin_addr.s_addr = INADDR_ANY;
	server.sin_port = htons( (short)port );
	
    int retval = bind(sock,
                      (struct sockaddr *)&server,
                      (socklen_t)sizeof(server));

	if( retval < 0 ) {
		NSLog(@"Error binding to port");
		error = true;
		return false;
	}
	
    // If the port is zero, the OS chose one for us.
	if (port == 0) {
        socklen_t localLen = sizeof(server);
        retval = getsockname(sock,
                             (struct sockaddr *)&server,
                             &localLen);
        if (retval == -1) {
            NSLog(@"Unable to get TCP sock port number: %s",
                  strerror(errno));
            close(sock);
            return NO;
        } else {
            port = ntohs(server.sin_port);
        }	
	}
    
	if( listen(sock, SOMAXCONN) < 0 ) {
		NSLog(@"Error listening for connections.");
		error = true;
		return false;			
	}
	
	error	= false;
	started = true;
    
	NSLog(@"Started Network Server on port %d.\n", port);
	
	return true;	
}

- (void)acceptLoop
{
	NetworkSession *networkSession = nil;

	// Listen for an incoming connection indefinitely 
	while( true ) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		networkSession = [self accept];
		
		if( networkSession != nil ) {
			[delegate NetworkServer:self newSession:networkSession];
		} else {
			if (!started) {
				NSLog(@"Server shutdown, exiting loop.");
				return;
			}
			
			NSLog(@"Error listening, retrying.");
		}
		
		networkSession = nil;

		[pool drain];
	}
}

- (void)acceptInBackground
{
	NSLog(@"Starting network listener thread.\n");
	[self performSelectorInBackground:@selector(acceptLoop) withObject:nil];
}

- (NetworkSession *)accept
{
	NetworkSession *networkSession = nil;
	NSString *hostnameString;
	
	struct sockaddr_in net_client;
	socklen_t len = sizeof(struct sockaddr_in);
	net_client.sin_addr.s_addr = INADDR_ANY;	// Allow connection from any client
	NSLog(@"Listening for Connection.");	
    
	// Listen for a connection (loop if interrupted)
    do {
         int fileDescriptor = accept(sock,
                                     (struct sockaddr*)(&net_client), &len);
        
        // Catch errors and interruptions
        if (fileDescriptor == -1) {
            if (error == EINTR) {
                NSLog(@"Interrupted, resuming wait.");              
            } else {
                NSLog(@"Connection attempt failed.");
                error = true;
                return nil;
            }
        }
        
        else {
		int opt_yes = 1;
		setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &opt_yes, sizeof(opt_yes));
		NSLog(@" set SO_NOSIGPIPE %d" , sock);
            networkSession = [[NetworkSession alloc] initWithSocket:sock
                                                      andDescriptor:fileDescriptor];
            
            struct hostent *hostptr;
            hostptr = gethostbyaddr((char*)&(net_client.sin_addr.s_addr),
                                    len, AF_INET);

            if( hostptr != nil ) {
                hostnameString = [[NSString alloc] initWithCString:(*hostptr).h_name
                                                          encoding:NSUTF8StringEncoding];
            } else {
                hostnameString = [[NSString alloc] initWithString:@"Unknown Client."];
            }
            
            
            		// When the remote connection is closed, we DO NOT want a SIGPIPE: ask for a EPIPE instead.

            
            NSLog(@"New connection successful, to %@ (fd: %d).",
                  hostnameString, fileDescriptor);
            
            [networkSession setHostname:hostnameString];
            [hostnameString release];
            
            [networkSession autorelease];
            return networkSession;
        }
    } while (!error);
    
    // Should never get here
    return nil;
}

- (void)close
{
    started = NO;
    close(sock);
	sock = -1;
}

- (bool)started
{
	return started;
}

- (bool)error
{
	return error;
}

- (int)port
{
	return port;
}

- (id)delegate;
{
	return delegate;
}

- (void)setDelegate: (id)del
{
	delegate = del;
}

@end
