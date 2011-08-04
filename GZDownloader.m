//
//  GZDownloader.m
//  GalaxyZoo
//
//  Created by Joe Zuntz on 27/07/2009.
//  Copyright 2009 Imperial College London. All rights reserved.
//
// modified 12pm 03/08/11, replacing XML with Json - Liam


#import "GZDownloader.h"
#import "GZJsonParser.h"
//#import "CAS.h"

@implementation GZDownloader
@synthesize delegate;
//@synthesize nextAssetURL;


-(id) initWithDelegate:(id) delegate_
{
	self = [super init];
	if (self){

        self.delegate = delegate_;

		connectionData = [NSArray arrayWithObjects:[NSMutableData data], [NSMutableData data], [NSMutableData data], nil];
		[connectionData retain];
		
		// initial settings for flags
        downloadingJson=NO;
        downloadingImage=NO;
        downloadPaused=NO;
        self.status = DOWNLOADER_STATUS_OK;
        connection=nil;
		
		// NEED TO CHANGE THIS URL
        nextAssetURL = @"http://www.galaxyzoo.org/api/assets/next_asset_for_project";
        NSLog(@"Using new nextAssetURL - may not work.");
    }
    return self;
}

#pragma mark -
#pragma mark Asynchronous Downloads



-(void) startDownload
{
    if (downloadingJson || downloadingImage || downloadPaused) return; // don't do anything if already downloading
	downloadingJson=YES;    
	NSLog(@"Async Download Begun");
    NSString * urlstring = [NSString stringWithString:nextAssetURL];
	[self startAsyncDownload:urlstring Json:YES];
}



-(void) startAsyncDownload:(NSString*)urlstring Json:(BOOL) isJson
{
    [urlstring retain];
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlstring ]
											  cachePolicy:NSURLRequestReloadIgnoringCacheData
										  timeoutInterval:60.0];
	// NOT SURE ABOUT THIS REQUEST PART
	if (isJson)
	{
		[request setValue:@"application/json; charset=utf8" forHTTPHeaderField:@"Content-Type"];
		[request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
	}

	connection=[[NSURLConnection alloc] initWithRequest:request delegate:self];

//	[[CAS sharedCasClient] sendAsyncRequest:request callbackObj:self callbackSelector:@selector(casRequestComplete:)];


	if (connection) 
	{
		if (isJson)
		{
			connectionType=GZ_CONNECTION_JSON;
		}
		else
		{
			connectionType=GZ_CONNECTION_IMAGE;			
		}

	} 
	else 
	{
		NSLog(@"Download connection failed.");
        [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(startDownload) userInfo:nil repeats:NO];
	}
    
	NSLog(@"Download launched");
  //  [urlstring release];
	
	
}

- (void) handleImageDownload:(NSData*) receivedData
{
	NSLog(@"Handling Image Download");
	GZGalaxy * galaxy = [[GZGalaxy alloc] init];
	galaxy.imageData = [NSData dataWithData:receivedData];
	galaxy.idnum = nextGalaxyID;

    if ([self.delegate respondsToSelector:@selector(addToQueue:)])
        [self.delegate addToQueue:galaxy];
    [galaxy release];
	downloadingImage=NO;
    [connection release];
    connection=nil;

    if ([self.delegate needsMoreGalaxies])
        [self startDownload];

}

- (void) handleJsonDownload:(NSData*) receivedData
{

	NSLog(@"Handling Json Download");
    GZJsonSimpleElementFinder * finder = [[GZJsonSimpleElementFinder alloc] initWithData:receivedData];
	nextGalaxyID=[[finder findContentsOfTag:@"id"] intValue];
    NSLog(@"Next galaxy ID = %d",nextGalaxyID);
	downloadingImage=YES;
	downloadingJson=NO;
    NSString * urlstring = [finder findContentsOfTag:@"location"];
    [finder release];
    [connection release];
    connection=nil;
	
	[self startAsyncDownload:urlstring Json:NO];
}


-(void) cancelCurrentDownloads
{
    NSLog(@"Cancelling download");
    [connection cancel];
	[[connectionData objectAtIndex: GZ_CONNECTION_JSON] setLength:0];        
	[[connectionData objectAtIndex: GZ_CONNECTION_UPLOAD] setLength:0];        
	[[connectionData objectAtIndex: GZ_CONNECTION_IMAGE] setLength:0];
    [connection autorelease];
    connection=nil;
    downloadingJson=NO;
    downloadingImage=NO;
}

#pragma mark -
#pragma mark NSURLConnection Delegates
- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection
{
	
switch (connectionType) {
	case GZ_CONNECTION_JSON:
		[self handleJsonDownload: [connectionData objectAtIndex:connectionType] ];
		break;
	case GZ_CONNECTION_IMAGE:
		[self handleImageDownload: [connectionData objectAtIndex:connectionType] ];
		break;
	default:
        [aConnection release]; //Broken connection
		break;
    }
}

- (void)connection:(NSURLConnection *)aConnection didFailWithError:(NSError *)error{
	NSLog(@"ERROR DELEGATE");
	NSLog(@"%@",error);
        [self cancelCurrentDownloads];
        self.status = DOWNLOADER_STATUS_CLIENT_ERROR;
        float pause_time = 10.0;
        NSLog(@"Download failed.  Pausing for %f seconds.", pause_time);
        [NSTimer scheduledTimerWithTimeInterval:pause_time target:self selector:@selector(startDownload) userInfo:nil repeats:NO];
}

- (void)connection:(NSURLConnection *)aConnection didReceiveResponse:(NSURLResponse *)response
{
	[[connectionData objectAtIndex:connectionType] setLength:0];
	NSHTTPURLResponse * HTTPresponse = (NSHTTPURLResponse*)response;
    NSUInteger statusCode = [HTTPresponse statusCode];
	NSLog(@"Response Code %d :%@",statusCode,[NSHTTPURLResponse localizedStringForStatusCode:statusCode] );
    if (statusCode/100 != 2){
        [self cancelCurrentDownloads];
//        NSLog(@"Headers were:\n%@",[HTTPresponse allHeaderFields]);
        self.status = DOWNLOADER_STATUS_SERVER_ERROR;
        [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(startDownload) userInfo:nil repeats:NO];
    }
    else {
        self.status = DOWNLOADER_STATUS_OK;
    }
}



- (void)connection:(NSURLConnection *)aConnection didReceiveData:(NSData *)data
{
	[[connectionData objectAtIndex: connectionType] appendData:data];
}




-(void) setDownloadPaused:(BOOL) paused // warnings are because properties are atomic - making them nonatomic fixes this - Liam
{
    downloadPaused=paused;
    
    if (paused) [self cancelCurrentDownloads];
}

-(void) setStatus:(downloader_status_t)s{
    status = s;
    [delegate setDownloadStatus:s];
}

@synthesize downloadPaused;
@synthesize status;
@end
