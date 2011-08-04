//
//  GZDownloader.h
//  GalaxyZoo
//
//  Created by Joe Zuntz on 27/07/2009.
//  Copyright 2009 Imperial College London. All rights reserved.
//
// modified 12pm 03/08/11, replacing XML with Json - Liam


#import <Foundation/Foundation.h>
#import "GZGalaxy.h"

typedef enum {
    DOWNLOADER_STATUS_OK,
    DOWNLOADER_STATUS_CLIENT_ERROR,
    DOWNLOADER_STATUS_SERVER_ERROR,
} downloader_status_t;

typedef enum{
    GZ_CONNECTION_UPLOAD,
    GZ_CONNECTION_IMAGE,
    GZ_CONNECTION_JSON
} connection_type_t;


@protocol GZDownloaderUser <NSObject>
-(void) addToQueue:(GZGalaxy*)galaxy;
-(BOOL) needsMoreGalaxies;
-(void) setDownloadStatus:(downloader_status_t)s;
@end



@interface GZDownloader : NSObject {
	NSArray * connectionData;
	BOOL downloadingJson, downloadingImage;
    id<GZDownloaderUser> delegate;
    int nextGalaxyID;
    NSString * nextAssetURL;
    BOOL downloadPaused;
    NSURLConnection * connection;
    downloader_status_t status;
    connection_type_t connectionType;

}
@property (assign) downloader_status_t status;
@property (assign) BOOL downloadPaused;
//@property (retain) NSString * nextAssetURL;
@property (retain) id delegate;
-(id) initWithDelegate:(id<GZDownloaderUser>)delegate_;
- (void) handleImageDownload:(NSData*) receivedData;
- (void) handleJsonDownload:(NSData*) receivedData;
-(void) cancelCurrentDownloads;
- (void) startDownload;
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;

-(void) startAsyncDownload:(NSString*)urlstring Json:(BOOL) isJson;
//-(void) casRequestComplete:(NSDictionary*) response;

//Delegate method

@end
