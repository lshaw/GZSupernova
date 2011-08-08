//
//  ZooGalaxyParser.h
//  GalaxyZoo
//
//  Created by Joe Zuntz on 17/06/2009.
//  Copyright 2009 Joe Zuntz. All rights reserved.
//
// modified 10:50am 08/08/11, replacing XML with Json - Liam

#import <Foundation/Foundation.h>
#import "SBJson.h"


@interface GZJsonSimpleElementFinder  : NSObject //<NSXMLParserDelegate>
{
	// NSString * targetTag;
    NSData * _data;
    //NSMutableString * tagValue;
	//    NSXMLParser * parser;
    //BOOL inTag;
    
    
}
//@property (retain) NSString * targetTag;
//@property (retain) NSMutableString * tagValue;

- (id) initWithData:(NSData*) data;
- (NSString*) findValueForKey:(NSString*)key;
//- (void)parser:(SBJsonParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict;
//- (void)parser:(SBJsonParser *)parser foundCharacters:(NSString *)string;
//- (void)parser:(SBJsonParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName;
@end




@interface GZLoginParser : NSObject  //<NSXMLParserDelegate>
{
	BOOL inSession;
	NSString * sessionID;
}
-(NSString*) getSessionID:(NSData*) data;

@end



