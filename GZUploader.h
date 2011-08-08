//
//  GZUploader.h
//  GalaxyZoo
//
//  Created by Joe Zuntz on 23/07/2009.
//  Copyright 2009 Imperial College London. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Queue.h"
#import "GZGalaxy.h"




@interface GZClassification : NSObject
{
    long int idnum;
    NSData * payload;
}

@property (assign) long int idnum;
@property (copy) NSData * payload;

-(id)initWithGalaxy:(GZGalaxy*)galaxy 
			 userID:(NSString*)userID 
			 apiKey:(NSString*) apiKey;

+(NSData*) buildClassificationForGalaxy:(GZGalaxy*) galaxy 
								 userID:(NSString*) userID 
								 apiKey:(NSString*)apiKey;

@end


//This class should:
//	* have a queue which it periodically tries to upload from when the queue reaches a certain length.
//	* it needs to do this in a separate thread.
//	* have a thread safe add-to-queue method.

@interface GZUploader : NSObject 
{
    Queue * queue;
    BOOL shouldUpload;
    int batchSize;
    int successiveFailures;
    Queue * galaxiesToUpload;
    NSString * uploadURL;
    NSString * username;
    NSString * userID;
    NSString * apiKey;
    NSString * password;
    NSMutableArray * temporaryQueue; //For use until the API key is ready.
    
    NSTimer * timer;
    GZClassification * activeUpload;
    BOOL uploading;
    BOOL uploadPaused;
}

@property (assign) BOOL uploadPaused;
@property (retain) GZClassification * activeUpload;

@property (retain) NSString * username;
@property (retain) NSString * userID;
@property (retain) NSString * apiKey;
@property (retain) NSString * password;

@property (retain) NSTimer * timer;
@property (assign) int batchSize;
@property (retain) Queue * queue;
-(double) waitTime;
-(int) queueCount;
-(void) clearQueue;
-(void) timerFinished;
-(void) launchUpload;
-(void) abortUpload;
-(void) saveClassification:(GZClassification*)classification jsonDir:(NSString*)jsonDir;
-(void) saveClassificationsTo:(NSString*) filename jsonDir:(NSString*) jsonDir;
-(NSData *) loadClassificationFor:(long int)idnum fromDir:(NSString*)jsonDir;
-(void) loadClassificationsFrom:(NSString*)filename jsonDir:(NSString*) jsonDir;
-(void) restartUploadAfterWait;
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;

-(void) addGalaxyToQueue:(GZGalaxy*) galaxy;
-(void) startUploading;
//-(void) stopUploading;
@end
