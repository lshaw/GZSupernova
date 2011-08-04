//
//  GZSession2.h
//  GalaxyZoo
//
//  Created by Joe Zuntz on 08/09/2009.
//  Copyright 2009 Imperial College London. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Queue.h"
#import "GZUploader.h"
#import "GZDownloader.h"
#import "GZGalaxy.h"

//#define EMERGENCY_GALAXY //Uncomment this line to enable offline galaxy for testing.

typedef enum {
    SESSION_STATUS_OK,
    SESSION_STATUS_MISC_ERROR,
    SESSION_STATUS_NO_CONNECTION,
    SESSION_STATUS_BAD_PASSWORD,
} session_status_t;



typedef enum  {
    noLoginPhase, 
    gettingLoginTicket,
    postingDetails,
    ensuringRegistered,
    gettingSessionTicket,
    gettingUserID,
    gettingAPIKey,
    loginFailed
} loginPhase_t;


@interface GZSession : NSObject<GZDownloaderUser> {
    BOOL haveUsername;  //Having a username indicates that we can load, save and display galaxies.
    BOOL loggedIn;      //Logging in means we can download new galaxies.  We can log in anonymously
    BOOL noAccountMode; //Selected "no account" option - needed if eg offline mode
    /*
        haveUsername  loggedIn   Behaviour
        YES             YES         Display galaxies from queue and download new ones.
                                    Upload classifications.
        YES             NO          Display galaxies from queue till empty.
                                    Try to log in periodically unless in offline mode.
        NO              YES         No account.  Download and display from a default queue.
                                    Periodically remind users that their work is pointless?
        NO              NO          Display the login screen.
    

        Triggers
        login complete  -   start downloading galaxies
        logout          -   stop downloading.  save to queue.  unset username/password.
        login failed    -   depends on reason.  wrong name/password: redisplay login
                                                no connection: continue
        get username    -   load from queue.  start login
    */
    
    session_status_t status;
    NSTimer * loginTimer;
    

    NSString * username;
    NSString * password;
	NSString * loginTicket;
	NSString * sessionTicket;
    NSString * userID;
    loginPhase_t loginPhase;

    GZUploader * uploader;
    GZDownloader * downloader;
    downloader_status_t downloadStatus;
//    NSString * loginURL;
//    NSString * ensureRegisterURL;
//    NSString * getAPIKeyURL;
//    NSString * logoutURL;
//    NSString * requestTicketURL;
//    NSString * validateTicketURL;
    NSMutableData * GETdata;
    
    NSString * userAPIKey;
    
	Queue * galaxyQueue;
    int queueSize;

    GZGalaxy * activeGalaxy;
    int stockpileTarget;
    int minStockSize;
    int classificationsThisSession;
    NSURLConnection * CASLogoutConnection;
}

@property session_status_t status;
@property BOOL haveUsername;
@property BOOL noAccountMode;
@property BOOL loggedIn;
@property (copy) NSString * password;
@property (copy) NSString * userAPIKey;
@property (copy) NSString * userID;
@property (copy) NSString * username;
@property (copy) NSString * sessionTicket;
@property (retain) GZGalaxy * activeGalaxy;
@property (retain) NSTimer * loginTimer;
@property (assign) int queueSize;
@property (assign) int classificationsThisSession;
@property (assign) int stockpileTarget;
@property (assign) downloader_status_t downloadStatus;
-(BOOL) loginInProgress;
-(void) setUsername:(NSString*) uname Password:(NSString*) pass;
-(void) setNoAccount;
-(void) getLoginTicket:(NSData*) data;
-(void) sendCredentials;
-(void) startLogin;
-(void) logout;
-(void) rescheduleLogin;
-(void) requestSessionTicket;
-(void) requestUserID;
-(void) requestAPIKey;
-(void) getUserID:(NSData*)data;
-(void) getAPIKey:(NSData*)data;

-(void) logoutCAS;
-(int) uploadQueueCount;

-(void) saveLoginDetails;
-(void) clearUploadQueue;
-(void) clearDownloadQueue;
-(void) cancelCurrentDownloads;
//- (void) authenticationDidFinishWithStatusCode:(NSInteger)statusCode;
- (GZGalaxy*) nextGalaxy;
+(void) printCookiesForURL:(NSString*)url;
-(void) uploadClassification:(GZGalaxy*)galaxy;
-(void) addToQueue:(GZGalaxy*) galaxy;
-(BOOL) needsMoreGalaxies;
-(GZGalaxy*) getFromQueueDownload:(BOOL) download;
-(GZGalaxy*) getFromQueue;

#pragma mark -
#pragma mark Saving and Loading
-(void) removeUserDirectoryForName:(NSString*)user;
-(void) saveGalaxies;
-(void) loadGalaxies;
-(void) loadQueueFrom:(NSString*)filename imageDirectory:(NSString*) imageDir;
-(void) saveQueueTo:(NSString*)filename imageDirectory:(NSString*) imageDir;
-(NSData*) loadImageForGalaxy:(long int)idnum fromDir:(NSString*)imaegDir;
-(void) saveGalaxyImage:(GZGalaxy*)galaxy InDir:(NSString*)imageDir;

-(void) testQuery;

#ifdef EMERGENCY_GALAXY
#warning Enabling emergency galaxies when offline.
- (GZGalaxy*) emergencyGalaxy;
#endif

/*
    Delegate Methods
    
    SessionDidCompleteLogin
    SessionLoginDidFail
    SessionDidDownloadGalaxy
    

*/

@end
