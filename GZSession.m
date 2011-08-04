//
//  GZSession2.m
//  GalaxyZoo
//
//  Created by Joe Zuntz on 08/09/2009.
//  Copyright 2009 Imperial College London. All rights reserved.
//

#import "GZSession.h"
#import "GZJsonParser.h"
//#import "CAS.h"
#import "GZPathManager.h"
//#import "KeychainItemWrapper.h"
#import "SFHFKeychainUtils.h"

#import "MyConnection.h"


@implementation GZSession
@synthesize userAPIKey;

-(id) init{
    NSLog(@"Init session");
	self = [super init];
	if (self){
        self.queueSize=0;
		galaxyQueue = [[Queue alloc] init];
		[galaxyQueue retain];

        uploader = [[GZUploader alloc]init];
        [uploader retain];
        
        downloader = [[GZDownloader alloc] initWithDelegate:self];
        downloader.downloadPaused=YES; //Start paused by default, until we finish log in, or decide not to.
        [downloader retain];
        
//        loginURL = @"https://login.zooniverse.org/login?service=http%3A%2F%2Fgalaxyzoo.org";
//        validateTicketURL = @"https://login.zooniverse.org/serviceValidate?ticket=%@&service=%@";
//        getAPIKeyURL = @"https://%@:%@zooniverse.org/public/users/%@.xml";
//        logoutURL=@"https://login.zooniverse.org/logout";
//        ensureRegisterURL=@"http://www.galaxyzoo.org/remote_identify";
        haveUsername=NO;
        loggedIn=NO;
        noAccountMode=NO;

		loginTicket=nil;
		srand(time(NULL));
        
        status=SESSION_STATUS_OK;
        self.loginTimer=nil;

        self.classificationsThisSession=0;

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        self.stockpileTarget = [defaults integerForKey:@"stockpileSize_preference"];
        if (self.stockpileTarget==0) self.stockpileTarget=20;
        minStockSize = (int) (self.stockpileTarget * [defaults floatForKey:@"minStockpileSize_preference"]);
        if (minStockSize==0) minStockSize=4;
        NSLog(@"Session Complete");
        
        loginPhase=noLoginPhase;
        CASLogoutConnection=nil;

		
	}
	return self;
	
}



-(void) setStockpileTarget:(int)n
{
    stockpileTarget=n;
    if (queueSize < stockpileTarget)
        [downloader startDownload];
}


-(int) stockpileTarget
{
    return stockpileTarget;

}
#ifdef EMERGENCY_GALAXY
- (GZGalaxy*) emergencyGalaxy
{
	NSLog(@"Adding emergency galaxy");
	GZGalaxy * galaxy = [[GZGalaxy alloc] init];
    
	NSString * imagePath = [[NSBundle mainBundle] pathForResource:@"testGalaxy" ofType:@"jpg"];    
	galaxy.imageData = [NSData dataWithContentsOfFile:imagePath];
	galaxy.idnum = 57;

    return [galaxy autorelease];
}
#endif


-(int) uploadQueueCount
{
    return [uploader queueCount];
}

-(GZGalaxy*) nextGalaxy{

    int n;
    @synchronized(galaxyQueue){
        n=[galaxyQueue count];
    }

    if (n<minStockSize){
        [downloader startDownload];
    }
    
     if (n==0) {
#ifdef EMERGENCY_GALAXY    
        self.activeGalaxy = [self emergencyGalaxy];
        self.activeGalaxy.startDate = [NSDate date];
#else
        self.activeGalaxy = nil;

#endif     
    }
    else {
        self.activeGalaxy = [self getFromQueue];
        self.activeGalaxy.startDate = [NSDate date];        
    }
	return self.activeGalaxy;
}

-(void) addToQueue:(GZGalaxy*) galaxy
{
    int n;
    [galaxyQueue enqueue:galaxy];
    n = [galaxyQueue count];
    self.queueSize = n;
    NSLog(@"Added galaxy %ld to queue.",galaxy.idnum);
}

-(BOOL)needsMoreGalaxies;
{
    NSLog(@"Current queue size = %d.  Target = %d.",self.queueSize,self.stockpileTarget);
    if (self.queueSize < self.stockpileTarget)
        return YES;
    else
        return NO;
}

-(GZGalaxy*) getFromQueueDownload:(BOOL) download
{
    GZGalaxy * galaxy;
    galaxy = [galaxyQueue dequeue];
    self.queueSize=[galaxyQueue count];
    if (self.queueSize<=minStockSize && download)
        [downloader startDownload];
    return galaxy;

}

-(GZGalaxy*) getFromQueue
{
    return [self getFromQueueDownload:YES];
}

+(void) printCookiesForURL:(NSString*)url
{
    NSArray * cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:url]];
    NSLog(@"Cookies: for %@\n%@",url,cookies);
}



-(void) uploadClassification:(GZGalaxy*) galaxy{
    galaxy.endDate = [NSDate date];

    if (!haveUsername){
        NSLog(@"Ignoring classification - no username");
        return;
    }
    self.classificationsThisSession=self.classificationsThisSession+1;
    NSLog(@"Adding classification for galaxy %ld.  Session Count = %d",galaxy.idnum,self.classificationsThisSession);
    [uploader addGalaxyToQueue:galaxy];

}

-(void) clearUploadQueue
{
    [uploader clearQueue];
    self.classificationsThisSession=0;
}
-(void) clearDownloadQueue
{
    [downloader cancelCurrentDownloads];
    [galaxyQueue clear];
    self.queueSize = [galaxyQueue count];
    NSLog(@"Reset download queue to %d",self.queueSize);
}

-(void) cancelCurrentDownloads
{
    [downloader cancelCurrentDownloads];

}


#pragma mark -
#pragma mark Logging in and out

-(void) setUsername:(NSString*) uname Password:(NSString*) pass
{
    self.noAccountMode=NO;
    self.username=uname;
    self.password=pass;
    self.haveUsername=YES;
    [self saveLoginDetails];
    uploader.username=uname;
    uploader.password=pass;
    
    [self loadGalaxies];
    [self startLogin];
}

-(void) setNoAccount
{
    self.username=@"";
    self.password=@"";
    uploader.username=nil; //This should not matter
    uploader.username=nil;    //This should not matter
    self.haveUsername=NO;
    self.noAccountMode=YES;
    [self loadGalaxies];
    [self startLogin];

}


-(void) saveLoginDetails
{

    NSError * error=nil;
    [SFHFKeychainUtils storeUsername:@"GZ_USERNAME" andPassword:self.username forServiceName:@"GalaxyZoo" updateExisting:YES error:&error];
    if (error){
        NSLog(@"Error storing username: %@",error);
    }
    error=nil;
    [SFHFKeychainUtils storeUsername:@"GZ_PASSWORD" andPassword:self.password forServiceName:@"GalaxyZoo" updateExisting:YES error:&error];
    if (error){
        NSLog(@"Error storing password: %@",error);
    }

}

-(void) forgetLoginDetails
{
    NSLog(@"Forgetting username and password");
    NSError * error=nil;
    [SFHFKeychainUtils  deleteItemForUsername: @"GZ_USERNAME" andServiceName: @"GalaxyZoo" error: &error];
    if (error){
        NSLog(@"Error forgetting username: %@",error);
    }
    error=nil;
    [SFHFKeychainUtils  deleteItemForUsername: @"GZ_PASSWORD" andServiceName: @"GalaxyZoo" error: &error];
    if (error){
        NSLog(@"Error forgetting password: %@",error);
    }

//+ (void) deleteItemForUsername: (NSString *) username andServiceName: (NSString *) serviceName error: (NSError **) error;

}

-(void) startLogin
{
    if (self.loginTimer){
        [self.loginTimer invalidate];
        self.loginTimer=nil;
    }
    /*
    [[CAS sharedCasClient] initWithCasServer:@"https://login.galaxyzoo.org"
                             restletPath:@"/"
                                username:self.username
                                password:self.password
                         authCallbackObj:self
                    authCallbackSelector:@selector(authenticationDidFinishWithStatusCode:)];

    self.status=SESSION_STATUS_OK;
*/



NSLog(@"Starting login");
NSString * loginURL = [GZPathManager loginURL];
NSMutableURLRequest * GETrequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: loginURL]
														cachePolicy:NSURLRequestReloadIgnoringCacheData
													timeoutInterval:60.0];
[GETrequest addValue:@"300" forHTTPHeaderField:@"Keep-Alive"];
[GETrequest addValue:@"en-us,en;q=0.5" forHTTPHeaderField:@"Accept-Language"];
[GETrequest addValue:@"gzip,deflate" forHTTPHeaderField:@"Accept-Encoding"];
[GETrequest addValue:@"ISO-8859-1,utf-8;q=0.7,*;q=0.7" forHTTPHeaderField:@"Accept-Charset"];
[GETrequest addValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
[GETrequest addValue:@"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1) Gecko/20090624 Firefox/3.5" forHTTPHeaderField:@"User-Agent"];
// NOT SURE ABOUT NEXT LINE - JUST CHANGED 'xml' TO 'json' - Liam
[GETrequest addValue:@"text/html,application/xhtml+json,application/json;q=0.9,*/*;q=0.8" forHTTPHeaderField:@"Accept"];
[GETrequest addValue:@"max-age=0" forHTTPHeaderField:@"Cache-Control"];

  NSURLConnection * connection = [[NSURLConnection alloc] initWithRequest:GETrequest delegate:self];

  if (!connection){
      NSLog(@"Could not create connection");
  self.status=SESSION_STATUS_MISC_ERROR;
    [self rescheduleLogin];
    return;
}

loginPhase=gettingLoginTicket;
    

}

-(BOOL) loginInProgress
{
    return loginPhase!=noLoginPhase;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSLog(@"Response received.");
    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse*) response;
    int return_code = [httpResponse statusCode];
/*
    if (connection==CASLogoutConnection){
        //This is the CAS logout connection.  We don't have to do anything
        //Just carry on.
        NSLog(@"Received logout acknowledgement:%d",return_code);
        [connection cancel];
        [connection release];
        CASLogoutConnection=nil;
        return;

    }
*/

    if (return_code/100!=2){
        NSLog(@"Login failed at stage %d with status %d",loginPhase,return_code);
        if (return_code==401){
            [connection cancel];
            [connection release];
            loginPhase = noLoginPhase;
            self.status=SESSION_STATUS_BAD_PASSWORD;
            return;
        }
        else{
            self.status=SESSION_STATUS_MISC_ERROR;
            [self rescheduleLogin];
        }
        [connection cancel];
        [connection release];
        loginPhase = noLoginPhase;
        return;
    }
    
    switch (loginPhase) {
        case noLoginPhase:
            break;
        case gettingSessionTicket:
            GETdata = [[NSMutableData alloc] init];        
            self.sessionTicket = [[[response URL] query] substringFromIndex:7];
            NSLog(@"SESSION TICKET DATA: --%@--", self.sessionTicket);
            break;
        case ensuringRegistered:
        case gettingLoginTicket:
        case postingDetails:
        case gettingUserID:
        case gettingAPIKey:
            GETdata = [[NSMutableData alloc] init];
            break;
        default:
            NSLog(@"Login phase was %d",loginPhase);
            NSAssert(NO,@"Unknown login phase");
            break;
    }
    
    

    
}

-(void) testQuery
{
    NSLog(@"Running Test Query.");
    NSURL * url = [NSURL  URLWithString:@"http://www.galaxyzoo.org/classify"];
    NSMutableURLRequest * request = [[NSMutableURLRequest alloc] initWithURL:url];
    NSHTTPURLResponse * response;
    NSError * error;
    NSData * data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSLog(@"Sync request returned.");
    NSString * s = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    NSLog(@"test return = %@", s);
    [s release];
    exit(0);
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [GETdata appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSInteger code = [error code];
    if (code==NSURLErrorNotConnectedToInternet||code==NSURLErrorTimedOut)
        self.status=SESSION_STATUS_NO_CONNECTION;
    else
        self.status=SESSION_STATUS_MISC_ERROR;
    loginPhase=noLoginPhase;
    if(GETdata) [GETdata release];
    NSLog(@"%@",[error localizedDescription]);
    NSLog(@"%@",[error localizedRecoverySuggestion]);
    NSLog(@"%@",[error localizedFailureReason]);
    NSLog(@"%d",[error code]==NSURLErrorNotConnectedToInternet);
    [connection release];
    [self rescheduleLogin];

}

-(void) rescheduleLogin
{
    if (self.loginTimer) [self.loginTimer invalidate];
    double waitTime; 
    switch (self.status) {
        case SESSION_STATUS_NO_CONNECTION:
            waitTime=20.0;
            break;
        default:
            waitTime=15.0;
            break;
    }
    self.loginTimer = [NSTimer scheduledTimerWithTimeInterval:waitTime target:self selector:@selector(startLogin) userInfo:nil repeats:NO];

}

-(void) setStatus:(session_status_t) s
{
    NSLog(@"Set session status to %d", s);
    status=s;
}


-(void) ensureRegistered
{
    NSString * ensureRegisterURL = [GZPathManager ensureRegisterURL];
    NSLog(@"Ensuring Registered.");
    NSURL * url = [NSURL URLWithString:ensureRegisterURL];
    NSURLRequest * request = [NSURLRequest requestWithURL:url];
    NSURLConnection * connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];

    if (!connection){
        NSLog(@"Could not create connection");
        self.status=SESSION_STATUS_MISC_ERROR;
        [self rescheduleLogin];
        return;
    }
    loginPhase=ensuringRegistered;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"Connection finished loading.");
    switch (loginPhase) {
        case noLoginPhase:
            {
            break;
            }
        case gettingLoginTicket:
            {
            [self getLoginTicket:GETdata];
            [GETdata release];
            GETdata=nil;
            [connection release];
            if (self.haveUsername)
                [self sendCredentials];
            else
                self.loggedIn=YES; //We are logged in as no one.
            }
            break;
        case postingDetails:
            {
                [GETdata release];
                GETdata=nil;
                [connection release];
                loginPhase=noLoginPhase;
                self.loggedIn=YES;
                [self ensureRegistered];
            }
            break;
        case ensuringRegistered:
            {
                [GETdata release];
                GETdata=nil;
                [connection release];
                loginPhase=noLoginPhase;
                [self requestSessionTicket];            
            }
            break;
        case gettingSessionTicket:
            {   
                [GETdata release];
                GETdata=nil;
                [connection release];
                [self requestUserID];
            }
            break;
        case gettingUserID:
            {
                [self getUserID:GETdata];
                [GETdata release];
                GETdata=nil;
                [connection release];        
//                NSLog(@"ALERT - FAKING API KEY");
//                NSData * apiKey = [@"<user><name>Joe</name> <age>27</age> <api_key>123456</api_key> </user>" dataUsingEncoding:NSASCIIStringEncoding];
//                [self getAPIKey:apiKey];
                loginPhase=noLoginPhase;
            }
            break;
        case gettingAPIKey:
            {
                [self getAPIKey:GETdata];
                [GETdata release];
                GETdata=nil;
                [connection release];
                loginPhase=noLoginPhase;
            }
            break;
        default:
            NSAssert(NO,@"Unknown connection type.");
            break;
        }

    
}

-(void) requestSessionTicket
{
    NSString * loginURL = [GZPathManager loginURL];
    NSLog(@"Requesting Session Ticket from %@",loginURL);
    NSMutableURLRequest * GETrequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: loginURL]
                                                            cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                        timeoutInterval:60.0];
    [GETrequest addValue:@"300" forHTTPHeaderField:@"Keep-Alive"];
 //   [GETrequest addValue:@"en-us,en;q=0.5" forHTTPHeaderField:@"Accept-Language"];
 //   [GETrequest addValue:@"gzip,deflate" forHTTPHeaderField:@"Accept-Encoding"];
 //   [GETrequest addValue:@"ISO-8859-1,utf-8;q=0.7,*;q=0.7" forHTTPHeaderField:@"Accept-Charset"];
    [GETrequest addValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
 //   [GETrequest addValue:@"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1) Gecko/20090624 Firefox/3.5" forHTTPHeaderField:@"User-Agent"];
    [GETrequest addValue:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" forHTTPHeaderField:@"Accept"];
    [GETrequest addValue:@"max-age=0" forHTTPHeaderField:@"Cache-Control"];

      NSURLConnection * connection = [[NSURLConnection alloc] initWithRequest:GETrequest delegate:self];

    if (!connection){
        NSLog(@"Could not create connection");
        loginPhase=noLoginPhase;
        self.status=SESSION_STATUS_MISC_ERROR;
        [self rescheduleLogin];
        return;
    }

    loginPhase=gettingSessionTicket;
}


-(void) requestUserID
{
    NSString * validateTicketURL = [GZPathManager validateTicketURL];
    NSString * urlstring = [NSString stringWithFormat:validateTicketURL, self.sessionTicket,@"http%3A%2F%2Fgalaxyzoo.org"];
    NSLog(@"Requesting User ID from %@",urlstring);
    NSMutableURLRequest * GETrequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: urlstring]
                                                            cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                        timeoutInterval:60.0];
    [GETrequest addValue:@"300" forHTTPHeaderField:@"Keep-Alive"];
    [GETrequest addValue:@"en-us,en;q=0.5" forHTTPHeaderField:@"Accept-Language"];
    [GETrequest addValue:@"gzip,deflate" forHTTPHeaderField:@"Accept-Encoding"];
    [GETrequest addValue:@"ISO-8859-1,utf-8;q=0.7,*;q=0.7" forHTTPHeaderField:@"Accept-Charset"];
    [GETrequest addValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
    [GETrequest addValue:@"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1) Gecko/20090624 Firefox/3.5" forHTTPHeaderField:@"User-Agent"];
    // NOT SURE ABOUT THE LINE BELOW - JUST CHANGED 'xml' to 'json' - Liam
	[GETrequest addValue:@"text/html,application/xhtml+json,application/json;q=0.9,*/*;q=0.8" forHTTPHeaderField:@"Accept"];
    [GETrequest addValue:@"max-age=0" forHTTPHeaderField:@"Cache-Control"];

      NSURLConnection * connection = [[NSURLConnection alloc] initWithRequest:GETrequest delegate:self];

    if (!connection){
        NSLog(@"Could not create connection");
        self.status=SESSION_STATUS_MISC_ERROR;
        loginPhase=noLoginPhase;
        [self rescheduleLogin];
        return;
    }

    loginPhase=gettingUserID;
}

-(void) requestAPIKey
{
    NSString * getAPIKeyURL = [GZPathManager getAPIKeyURL];
    NSString * urlstring = [NSString stringWithFormat:getAPIKeyURL,self.username,self.password,self.userID];
    NSLog(@"Requesting API Key from %@",urlstring);
    NSMutableURLRequest * GETrequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: urlstring]
                                                            cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                        timeoutInterval:60.0];
    [GETrequest addValue:@"300" forHTTPHeaderField:@"Keep-Alive"];
    [GETrequest addValue:@"en-us,en;q=0.5" forHTTPHeaderField:@"Accept-Language"];
    [GETrequest addValue:@"gzip,deflate" forHTTPHeaderField:@"Accept-Encoding"];
    [GETrequest addValue:@"ISO-8859-1,utf-8;q=0.7,*;q=0.7" forHTTPHeaderField:@"Accept-Charset"];
    [GETrequest addValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
    [GETrequest addValue:@"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1) Gecko/20090624 Firefox/3.5" forHTTPHeaderField:@"User-Agent"];
//    [GETrequest addValue:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" forHTTPHeaderField:@"Accept"];
    [GETrequest addValue:@"max-age=0" forHTTPHeaderField:@"Cache-Control"];

      NSURLConnection * connection = [[NSURLConnection alloc] initWithRequest:GETrequest delegate:self];

    if (!connection){
        NSLog(@"Could not create connection");
        self.status=SESSION_STATUS_MISC_ERROR;
        [self rescheduleLogin];
        return;
    }

    loginPhase=gettingAPIKey;

}

-(void) getUserID:(NSData*)data
{
    GZJsonSimpleElementFinder * finder = [[GZJsonSimpleElementFinder alloc] initWithData:data];
    self.userID = [finder findContentsOfTag:@"id"];
    self.userAPIKey = [finder findContentsOfTag:@"api_key"];
    [finder release];
    NSLog(@"Set user ID to %@",self.userID);        
    NSLog(@"Set API Key to %@",self.userAPIKey);        
    uploader.userID = self.userID;
    uploader.apiKey = self.userAPIKey;
    uploader.uploadPaused=NO;
    [uploader startUploading];

}

-(void) getAPIKey:(NSData*)data
{
    GZJsonSimpleElementFinder * finder = [[GZJsonSimpleElementFinder alloc] initWithData:data];
    self.userAPIKey = [finder findContentsOfTag:@"api_key"];
    [finder release];
    NSLog(@"Set API key to %@",self.userAPIKey);
    uploader.apiKey = self.userAPIKey;

}


-(void) setLoggedIn:(BOOL)b
{   
    NSLog(@"Set logged in %d",b);
    if (loggedIn){ //currently logged in
        if (!b){ //setting to not logged in
            downloader.downloadPaused=YES;
            uploader.uploadPaused=YES;
            [self logoutCAS];
            [self saveGalaxies];
            self.username=@"";
            self.password=@"";
            self.classificationsThisSession=0;
            self.noAccountMode=NO;
            [self forgetLoginDetails];
        }
    }
    else{ //currently not logged in 
//        if (!b) if (haveUsername) [self saveGalaxies];
        if (b){ //now logged in
            downloader.downloadPaused=NO;
            if ([self needsMoreGalaxies]) [downloader startDownload];
        }
        else {
            [self forgetLoginDetails];
        }

    }
    loggedIn=b;

}

-(void) logoutCAS
{
NSString * logoutURL = [GZPathManager logoutURL];
NSMutableURLRequest * GETrequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: logoutURL]
														cachePolicy:NSURLRequestReloadIgnoringCacheData
													timeoutInterval:60.0];
[GETrequest addValue:@"300" forHTTPHeaderField:@"Keep-Alive"];
[GETrequest addValue:@"en-us,en;q=0.5" forHTTPHeaderField:@"Accept-Language"];
[GETrequest addValue:@"gzip,deflate" forHTTPHeaderField:@"Accept-Encoding"];
[GETrequest addValue:@"ISO-8859-1,utf-8;q=0.7,*;q=0.7" forHTTPHeaderField:@"Accept-Charset"];
[GETrequest addValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
[GETrequest addValue:@"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1) Gecko/20090624 Firefox/3.5" forHTTPHeaderField:@"User-Agent"];
[GETrequest addValue:@"text/html,application/xhtml+json,application/json;q=0.9,*/*;q=0.8" forHTTPHeaderField:@"Accept"];
[GETrequest addValue:@"max-age=0" forHTTPHeaderField:@"Cache-Control"];

  NSURLConnection * connection = [[NSURLConnection alloc] initWithRequest:GETrequest delegate:self];
 CASLogoutConnection = connection;
  if (!connection){
      NSLog(@"Could not log out");
      //try again in 7 seconds. keep trying
      [NSTimer scheduledTimerWithTimeInterval:7.0 target:self selector:@selector(logoutCAS) userInfo:nil repeats:NO];    return;
}


}


-(void) getLoginTicket:(NSData*) data
{
    GZLoginParser * loginParser = [[GZLoginParser alloc]init];
	loginTicket = [loginParser getSessionID:data];
    [loginParser release];
    NSLog(@"login-ticket = %@",loginTicket);
}

-(void) sendCredentials
{
    NSString * loginURL = [GZPathManager loginURL];
    NSLog(@"Logging in with username:%@, password:[REDACTED] at %@",self.username,loginURL);
    loginPhase = postingDetails;
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:loginURL ]
															cachePolicy:NSURLRequestReloadIgnoringCacheData
														timeoutInterval:60.0];

	
	[request setHTTPMethod:@"POST"];
	NSString *content = [NSString stringWithFormat:@"username=%@&password=%@&lt=%@",self.username,self.password,loginTicket];
	[request addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
//	[request addValue:@"login.galaxyzoo.org" forHTTPHeaderField:@"Referer"];
//	[request addValue:@"login.galaxyzoo.org" forHTTPHeaderField:@"Host"];
	[request addValue:@"300" forHTTPHeaderField:@"Keep-Alive"];
	[request addValue:@"en-us,en;q=0.5" forHTTPHeaderField:@"Accept-Language"];
	[request addValue:@"gzip,deflate" forHTTPHeaderField:@"Accept-Encoding"];
	[request addValue:@"ISO-8859-1,utf-8;q=0.7,*;q=0.7" forHTTPHeaderField:@"Accept-Charset"];
	[request addValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
	[request addValue:@"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1) Gecko/20090624 Firefox/3.5" forHTTPHeaderField:@"User-Agent"];
	[request addValue:@"max-age=0" forHTTPHeaderField:@"Cache-Control"];	
	[request addValue:[NSString stringWithFormat:@"%d",[content length]] forHTTPHeaderField:@"Content-Length"];
	NSData * contentData = [content dataUsingEncoding:NSUTF8StringEncoding];
	[request setHTTPBody:contentData];	
    MyConnection * connection = [[MyConnection alloc] initWithRequest:request delegate:self];
    if (!connection){
        NSLog(@"Connection Failed when sending credentials");
        loginPhase=noLoginPhase;
    }
    NSLog(@"Credentials sent, awaiting reply.");
//This is a comment - do you know when you can get my chips? I am hungreeeeeeeeeeeeeeeeey!!!!!

}




#pragma mark -
#pragma mark Saving And Loading

-(void) loadGalaxies{
    NSString * user;
    if (self.haveUsername) 
        user = self.username;
    else
        user = @"default";
    NSString * userDir = [GZPathManager userDirectoryForName:user];
    NSString * imageDir = [GZPathManager savedImageDirectoryForName:user];    
    NSString * classificationDir = [GZPathManager classificationDirectoryForName:user];
    NSString * zooFile = [NSString pathWithComponents:[NSArray arrayWithObjects:userDir,@"data.dat",nil]];
    NSString * classificationFile = [NSString pathWithComponents:[NSArray arrayWithObjects:userDir,@"upload.dat",nil]];

    NSFileManager * os = [NSFileManager defaultManager];
    if ([os fileExistsAtPath:zooFile]){
            [self loadQueueFrom:zooFile imageDirectory:imageDir];
    }
    else{
        NSLog(@"No cached galaxies found for user %@.",user);
    }

    if ([os fileExistsAtPath:classificationFile]){
		// WHAT ABOUT THIS BIT? WHAT'S THE EQUIVALENT FOR JSON? - Liam
        [uploader loadClassificationsFrom:classificationFile xmlDir:classificationDir];
    }
    else{
        NSLog(@"No cached classifications found for user %@.",user);    
    }
    [self removeUserDirectoryForName:user];    
}

-(void) saveGalaxies{
    NSString * user;
    if (self.haveUsername) 
        user = self.username;
    else
        user = @"default";

    NSLog(@"Saving galaxies for user %@",user);
    NSString * zooDir = [GZPathManager zooDirectory];
    NSString * userDir = [GZPathManager userDirectoryForName:user];
    NSString * imageDir = [GZPathManager savedImageDirectoryForName:user];
    NSString * classificationDir = [GZPathManager classificationDirectoryForName:user];
    [GZPathManager createDirectoryIfNeeded:zooDir];
    [GZPathManager createDirectoryIfNeeded:userDir];
    [GZPathManager createDirectoryIfNeeded:imageDir];
    [GZPathManager createDirectoryIfNeeded:classificationDir];
    
    
    NSString * classificationFile = [NSString pathWithComponents:[NSArray arrayWithObjects:userDir,@"upload.dat",nil]];
    NSString * zooFile = [NSString pathWithComponents:[NSArray arrayWithObjects:userDir,@"data.dat",nil]];
    //JZ This  ^^^^^^^ is a pun.

    [self saveQueueTo:zooFile imageDirectory:imageDir]; //We always save the downloads
    if (self.haveUsername) //We only save the uploads if we have a username.
		// WHAT ABOUT THIS BIT? WHAT'S THE EQUIVALENT FOR JSON? - Liam
    [uploader saveClassificationsTo:classificationFile xmlDir:classificationDir];
    NSLog(@"Galaxy Save Complete");
}

-(void) logout
{
    [self setLoggedIn:NO];
}






-(void) loadQueueFrom:(NSString*)filename imageDirectory:(NSString*) imageDir
{
    NSLog(@"Loading cached queue from %@",filename);
    NSData * data = [NSData dataWithContentsOfFile:filename];
    NSAssert([data length]>=sizeof(int),@"File very corrupt");
    if (!([data length]>=sizeof(int))){
        NSLog(@"Queue File very corrupt");
        return; //
     }
    int n = *(int*)[data bytes];
    NSAssert([data length]==sizeof(int)+n*sizeof(long int),@"File corrupt");
    if ([data length]!=sizeof(int)+n*sizeof(long int) ){
        NSLog(@"Queue File corrupt");
        return; //
     }

    long int * ptr = (long int*)(((int*)[data bytes])+1);
    for(int i=0;i<n;i++){
        GZGalaxy * galaxy = [[GZGalaxy alloc] init];
        galaxy.idnum = *(long int*) ptr++;
        galaxy.imageData = [self loadImageForGalaxy:galaxy.idnum fromDir:imageDir];
        if (galaxy.imageData==nil){
            NSLog(@"Could not get image for galaxy %ld - ignoring",galaxy.idnum);
        }
        else{
            [self addToQueue:galaxy];
        }
        [galaxy release];
    }
}

-(void) removeUserDirectoryForName:(NSString*)user
{
    NSFileManager * os = [NSFileManager defaultManager];
    NSError * error=nil;
    NSString * userDir = [GZPathManager userDirectoryForName:user];
    if ([os fileExistsAtPath:userDir])
        [os removeItemAtPath:userDir error:&error];
    if (error){
        NSLog(@"Error removing User Dir:%@",error);
    }
 
}

-(void) saveQueueTo:(NSString*)filename imageDirectory:(NSString*) imageDir
{
    if(self.activeGalaxy){
        [galaxyQueue queueJump:self.activeGalaxy];
        self.activeGalaxy=nil;
    }
    self.queueSize = [galaxyQueue count];
    int n=[galaxyQueue count];
    if (n==0) return;
    NSMutableData * data = [[NSMutableData alloc] init];
    [data appendBytes:&n length:sizeof(int)];
    for(int i=0;i<n;i++){
        GZGalaxy * galaxy = [self getFromQueueDownload:NO];
        int idnum = galaxy.idnum;
        [data appendBytes:&idnum length:sizeof(long int)];
        [self saveGalaxyImage:galaxy InDir:imageDir];
    }
    NSFileManager * os = [NSFileManager defaultManager];
    NSLog(@"Creating file: %@ of size %d bytes",filename,[data length]);
    BOOL success = [os createFileAtPath:filename contents:data attributes:nil];
    if (!success) NSLog(@"Could not save file");
    [data release];
}

-(NSData*) loadImageForGalaxy:(long int)idnum fromDir:(NSString*)imageDir
{
    NSString * stringID = [NSString stringWithFormat:@"%ld.jpg",idnum];
    NSString * filename = [NSString pathWithComponents:[NSArray arrayWithObjects:imageDir,stringID,nil]];
    return [NSData dataWithContentsOfFile:filename];
}
-(void) saveGalaxyImage:(GZGalaxy*)galaxy InDir:(NSString*)imageDir
{
    NSFileManager * os = [NSFileManager defaultManager];
    NSString * stringID = [NSString stringWithFormat:@"%ld.jpg",galaxy.idnum];
    NSString * filename = [NSString pathWithComponents:[NSArray arrayWithObjects:imageDir,stringID,nil]];
    NSError * error=nil;
    if ([os fileExistsAtPath:filename]){
        [os removeItemAtPath:filename error:&error];
        if(error) NSLog(@"Could not remove old Image file");
        return;
    }
    BOOL success = [os createFileAtPath:filename contents:galaxy.imageData attributes:nil];
    if (!success) NSLog(@"Could not save Image file");
    
}


-(downloader_status_t) downloadStatus{
    return downloader.status;

}

@synthesize downloadStatus;
@synthesize haveUsername;
@synthesize loggedIn;
@synthesize password;
@synthesize username;
@synthesize activeGalaxy;
@synthesize sessionTicket;
@synthesize queueSize;
@synthesize classificationsThisSession;
@synthesize status;
@synthesize userID;
@synthesize loginTimer;
@synthesize noAccountMode;
@end
