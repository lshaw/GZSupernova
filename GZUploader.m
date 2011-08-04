//
//  GZUploader.m
//  GalaxyZoo
//
//  Created by Joe Zuntz on 23/07/2009.
//  Copyright 2009 Imperial College London. All rights reserved.
//

#import "GZUploader.h"
#import "GZGalaxy.h"
#import "GZDataWrapper.h"
#import "GZUtils.h"
extern NSData *    exampleGalaxyImage;





const char * sekritMessage = "encryption,RSA,AES,encoding: If you are reading this you are trying to disassemble this Galaxy Zoo app.  I'd like to ask you very sincerely not to use the results if you succeed.  Galaxy Zoo is a scientific project that does not make any money and relies on your goodwill. I do know the thrill and sense of intellectual victory that you'd get from outwitting me and cracking the app, and then submitting your own cheat classifications, but I would urge you to not use it if you succeed and instead email me at jaz@astro.ox.ac.uk and gloat over your win directly. Thanks for reading this.";

extern NSData * exampleGalaxyImage;
extern NSData * exampleDataSet;
GZDataWrapper * wrapper=nil;


@implementation GZClassification
@synthesize idnum;
@synthesize payload;
-(id)initWithGalaxy:(GZGalaxy*)galaxy userID:(NSString*)userID apiKey:(NSString*) apiKey
{
	self = [super init];
	if (self){
        self.idnum = galaxy.idnum;
        self.payload = [GZClassification buildClassificationForGalaxy:galaxy userID:userID apiKey:apiKey];
    }
    return self;

}


+(NSData*) buildClassificationForGalaxy:(GZGalaxy*) galaxy userID:(NSString*) userID apiKey:(NSString*)apiKey
{

    BOOL ipad = [GZUtils isIpad];
    NSString * application_identifier;
    if (ipad){
        application_identifier = @"iPad v1.0";
    }
    else{
        application_identifier = @"iPhone/iPod Touch v1.0";
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-d HH:mm:ss"];
    NSString *start_string = [formatter stringFromDate:galaxy.startDate];
    NSString *end_string = [formatter stringFromDate:galaxy.endDate];
    [formatter release];

    
    //I am a bad person.
	NSString* xmlBase = @"<?xml version='1.0' encoding='UTF-8'?><classification><zooniverse_user_id type='integer'>%@</zooniverse_user_id><project_id type='integer'>1</project_id><workflow_id type='integer'>1</workflow_id><application_identifier>%@</application_identifier><assets type='array'><asset><id type='integer'>%d</id></asset></assets><annotations type='array'>%@</annotations><started>%@</started><ended>%@</ended></classification>";	
	NSString* annotationBase = @"<annotation><task_id>%d</task_id><answer_id>%d</answer_id></annotation>";

	NSMutableString* annotations = [[NSMutableString alloc] initWithCapacity:100];
    exampleDataSet=exampleGalaxyImage;
	int n = [galaxy numberOfAnswers];
	for(int i=0;i<n;i++){
        GZQuestion * question = [[galaxy answeredQuestions] objectAtIndex:i];
        GZAnswer * answer = [galaxy.givenAnswers objectAtIndex:i];
		NSString * annotation = [NSString stringWithFormat:annotationBase,question.task_id,answer.answer_id];
		[annotations appendString:annotation];
	}
	
	NSString *xml = [NSString stringWithFormat:xmlBase,userID,application_identifier,galaxy.idnum,annotations,start_string,end_string];
    [annotations release];
    return [wrapper wrap:xml];


}

-(void) dealloc
{
    [payload release];
    [super dealloc];

}

@end


@implementation GZUploader
@synthesize batchSize;
@synthesize queue;

-(id) init{
    NSString * filename = [[NSBundle mainBundle] pathForResource:@"exampleGalaxy" ofType:@"jpg"];

    exampleGalaxyImage = [[NSData alloc] initWithContentsOfFile:filename];

	self = [super init];
        exampleDataSet=exampleGalaxyImage;
        if (wrapper==nil) wrapper = [[GZDataWrapper alloc] init];    
	if (self){
        queue = [[[Queue alloc] init] retain];
        shouldUpload=YES;
        batchSize=10;
        successiveFailures=0;
        self.username=nil;
        self.password=nil;
        self.apiKey=nil;
        self.userID=nil;
        temporaryQueue=nil;


        //This is an obfuscation of 
        uploadURL = @"https://www.galaxyzoo.org/public/users/%@/classifications?api_key=%@";

        activeUpload=nil;
        uploading=NO;
        uploadPaused=NO;
	}
	return self;
	
}

-(void)addGalaxyToQueue:(GZGalaxy*)galaxy
{
    if (self.apiKey && self.userID){
        if (temporaryQueue){
            for (GZGalaxy* oldGalaxy in temporaryQueue){
                GZClassification * classification = [[GZClassification alloc] initWithGalaxy:oldGalaxy userID:self.userID apiKey:self.apiKey];
                [self.queue enqueue:classification];
                [classification release];
                NSLog(@"Added classification for (old) %ld. Queue size %d",oldGalaxy.idnum,[self.queue count]);
            }
            [temporaryQueue removeAllObjects];
            [temporaryQueue release];
            temporaryQueue=nil;
        }
        GZClassification * classification = [[GZClassification alloc] initWithGalaxy:galaxy userID:self.userID apiKey:self.apiKey];
        [self.queue enqueue:classification];
        [classification release];
        NSLog(@"Added classification for %ld. Queue size %d",galaxy.idnum,[self.queue count]);
    }
    else {
        if (!temporaryQueue){
            temporaryQueue = [[NSMutableArray alloc] initWithCapacity:1];
        }
        [temporaryQueue addObject:galaxy];
    }

}


-(int) queueCount
{
    return [queue count] + [temporaryQueue count];
}

-(void)startUploading
{
    if (!(apiKey&&userID) ){
        NSLog(@"Tried to start upload without keys - aborting");
        return;
    }


    NSLog(@"Considering upload");
    // If we have been waiting for a timer to launch this function then invalidate it.
    //Otherwise it should be nil.
    [self.timer invalidate];

    if (uploading) {
        NSLog(@"Already uploading");
        return;
    }
    if (uploadPaused){
        NSLog(@"Upload is paused");
        return;
    }
    int n;
    @synchronized(queue){
        n = [queue count];
    }
    if (n>=self.batchSize){
//    if (1){
        NSLog(@"Have %d galaxies: starting upload",n);
        [self launchUpload];
    }
    else{
        NSLog(@"Have %d galaxies: not enough to upload",n);
        [self restartUploadAfterWait];
    }
}



-(void) launchUpload
{        
    exampleDataSet=exampleGalaxyImage;

    if (uploadPaused){
        NSLog(@"Upload paused - not continuing");
        return;
    }
    int n;
    @synchronized(queue){
        n=[queue count];
    }
    if (n==0){
        uploading=NO;
        NSLog(@"No classifications to upload");
        [self restartUploadAfterWait];
        return;
    }
    uploading=YES;
    @synchronized(queue){
        self.activeUpload = [queue dequeue];
    }

    NSString * urlstring = [NSString stringWithFormat:uploadURL,self.userID,self.apiKey];
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlstring ]
															cachePolicy:NSURLRequestReloadIgnoringCacheData
														timeoutInterval:60.0];
	[request setHTTPMethod:@"POST"];
	[request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
	[request setValue:@"application/xml" forHTTPHeaderField:@"Accept"];

    char * header = "<?xml version='1.0' encoding='UTF-8'?><data>";
    NSMutableData * data = [NSMutableData dataWithBytes:header length:strlen(header)];

    NSString * payload_string = [GZDataWrapper wrap64bit:self.activeUpload.payload];
    NSData * payload_data = [payload_string dataUsingEncoding:NSASCIIStringEncoding];
    [data appendData:payload_data];
    char * footer = "</data>";
    [data appendBytes:footer length:strlen(footer)];
    
	[request setHTTPBody:data];
    
    
    //NSLog(@"%@",[[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease]);
	NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:request delegate:self];
    
    if (!theConnection){
        NSLog(@"Could not start connection");
        [self abortUpload];
    }
}


    
-(void) timerFinished
{
    self.timer=nil;
    [self startUploading];
}




-(void) abortUpload
{
    NSLog(@"Upload aborted");
    uploading=NO;
    successiveFailures++;
    @synchronized(queue){
        if (self.activeUpload) [queue enqueue:self.activeUpload];
        self.activeUpload=nil;
    }
    //If the upload fails, try again in [self waitTime] seconds.
    //Another event can trigger the upload before this time
    //If that happens the timer is invalidated
    [self restartUploadAfterWait];
}

-(void) restartUploadAfterWait
{
    double t = [self waitTime];
    NSLog(@"pausing upload for %lf seconds",t);
    self.timer = [NSTimer scheduledTimerWithTimeInterval:t target:self selector:@selector(timerFinished) userInfo:nil repeats:NO];

}


-(double) waitTime
{
    if (successiveFailures<6)
        return 20.0;
    else
        return 180.0;
}




-(void) loadClassificationsFrom:(NSString*)filename xmlDir:(NSString*) xmlDir
{
    NSLog(@"Loading cached queue from %@",filename);
    NSData * data = [NSData dataWithContentsOfFile:filename];
    if (!([data length]>=sizeof(int))){
        NSLog(@"File very corrupt");
        return;
    }
    int n = *(int*)[data bytes];
    NSLog(@"Loading %d galaxies from file",n);
    NSAssert([data length]==sizeof(int)+n*sizeof(long int),@"File corrupt");
    if (!([data length]==sizeof(int)+n*sizeof(long int))){
        NSLog(@"File  corrupt");
        return;
    }
    long int * ptr = (long int*)(((int*)[data bytes])+1);
    for(int i=0;i<n;i++){
        GZClassification * classification = [[GZClassification alloc] init];
        classification.idnum = *(long int*) ptr++;
        classification.payload = [self loadClassificationFor:classification.idnum fromDir:xmlDir];
        if (classification.payload) //Queue if we loaded successfully, else skip.
            [queue enqueue:classification];
        [classification release];
    }
}

-(NSData*) loadClassificationFor:(long int)idnum fromDir:(NSString*)xmlDir
{
    NSString * stringID = [NSString stringWithFormat:@"%ld.xml",idnum];
    NSString * filename = [NSString pathWithComponents:[NSArray arrayWithObjects:xmlDir,stringID,nil]];
    NSData * data = [NSData dataWithContentsOfFile:filename];
    if (!data){
        NSLog(@"Could not load classification filename %@",filename);
    }
    NSLog(@"Loaded %@",stringID);
    return data;
}

-(void) clearQueue
{
    NSLog(@"Uploader clearing queue");
    [self.timer invalidate];
    [queue clear];
}

-(void) saveClassificationsTo:(NSString*) filename xmlDir:(NSString*) xmlDir
{
    int n;
    @synchronized(queue){
        n  = [queue count];
    }
    if (n==0) return;
//    [self pauseUpload];
    self.uploadPaused=YES;
    NSFileManager * os = [NSFileManager defaultManager];
    NSMutableData * data = [[NSMutableData alloc] init];
    [data appendBytes:&n length:sizeof(n)];
    @synchronized(queue){
    for(int i=0;i<n;i++){
        GZClassification * classification = [queue dequeue];
        long int idnum = classification.idnum;
        [data appendBytes:&idnum length:sizeof(idnum)];
        [self saveClassification:classification xmlDir:xmlDir];
//        [classification release];
    }
    NSLog(@"Creating file: %@ of size %d bytes",filename,[data length]);
    BOOL success = [os createFileAtPath:filename contents:data attributes:nil];
    NSAssert(success,@"Could not save classification file");
    
    }
    [data release];
    uploadPaused=NO;

}

-(void) saveClassification:(GZClassification*)classification xmlDir:(NSString*)xmlDir
{
    NSFileManager * os = [NSFileManager defaultManager];
    NSString * stringID = [NSString stringWithFormat:@"%ld.xml",classification.idnum];
    NSString * filename = [NSString pathWithComponents:[NSArray arrayWithObjects:xmlDir,stringID,nil]];
    NSError * error=nil;
    if ([os fileExistsAtPath:filename]){
        [os removeItemAtPath:filename error:&error];
        if(error) NSLog(@"Could not remove old classification xml file");
    }
    BOOL success = [os createFileAtPath:filename contents:classification.payload attributes:nil];
    if (!success)NSLog(@"Could not save classification file");
    
}



- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse*)response;
    NSUInteger status = [httpResponse statusCode];
    NSLog(@"Upload response received: %d",status);
    
    if (status==422){
        self.activeUpload=nil;  //Drop the classification - it is bad.
    }

    if (status/100 != 2){
        NSLog(@"Upload failed with status:%d",status);
        NSLog(@"Headers were:\n%@",[httpResponse allHeaderFields]);
        [self abortUpload];
    }
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    //We do not care about the data
    // I did not make it so I do not have to release it.  Joe is learning.
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"Upload failed with error");
	NSLog(@"%@",error);
    [connection release];
    [self abortUpload];
    
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"Upload complete");
    successiveFailures=0;
    [connection release];
    [self launchUpload];    
}

@synthesize activeUpload;
@synthesize timer;
@synthesize uploadPaused;
@synthesize username;
@synthesize password;
@synthesize userID;
@synthesize apiKey;
@end
