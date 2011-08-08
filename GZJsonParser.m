//
//  ZooGalaxyParser.m
//  GalaxyZoo
//
//  Created by Joe Zuntz on 17/06/2009.
//  Copyright 2009 Joe Zuntz. All rights reserved.
//
// modified 10:50am 08/08/11, replacing XML with JSON - Liam


#import "GZJsonParser.h"


@implementation GZJsonSimpleElementFinder

-(id) initWithData:(NSData *)data
{
    self=[super init];
    if (self)
	{
        _data=[data retain];
    }
    return self;
	
}

-(void) dealloc
{
    [_data release];
    [super dealloc];
}


-(NSString*) findValueForKey:(NSString*)key
{
    if (!_data) return nil;
    //self.tagValue=nil;
    //self.targetTag=tag;
    //inTag=NO;
	
	//think this is the correct parsing method...
	
    SBJsonParser * parser = [[SBJsonParser alloc] initWithData:_data];
	NSDictionary * value_dictionary = [parser objectWithData:_data error:nil];
	[parser release];
	
	NSString * return_value = [NSString stringWithString:[value_dictionary objectForKey:key]]; 	
    return return_value;
}

/* ALL THIS IS (I BELIEVE) NO LONGER NECESSARY
 - (void)parser:(SBJsonParser *)parser didStartElement:(NSString *)elementName 
 namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName 
 attributes:(NSDictionary *)attributeDict 
 {
 if ( [elementName isEqualToString:targetTag]) 
 {
 inTag=YES;
 self.tagValue = [NSMutableString stringWithCapacity:50];
 }
 }
 
 - (void)parser:(SBJsonParser *)parser foundCharacters:(NSString *)string
 {
 if (!inTag) return;
 [self.tagValue appendString:string];
 
 }
 
 - (void)parser:(SBJsonParser *)parser didEndElement:(NSString *)elementName 
 namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
 {
 if (!inTag) return;
 [parser abortParsing];
 }
 
 //@synthesize targetTag;
 //@synthesize tagValue;
 */
@end





// We continue to parse XML here, despite the name of this file.
@implementation GZLoginParser

- (NSString*)getSessionID:(NSData*) data
{
	inSession=NO;
	//	NSString * xmlstring = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	//	NSLog(@"Parsing:\n\n%@\n\n",xmlstring);
    SBJsonParser *parser = [[SBJsonParser alloc] initWithData:data];
    // Set self as the delegate of the parser so that it will receive the parser delegate methods callbacks.
    [parser setDelegate:self];
    // Depending on the XML document you're parsing, you may want to enable these features of NSXMLParser.
    [parser setShouldProcessNamespaces:NO];
    [parser setShouldReportNamespacePrefixes:NO];
    [parser setShouldResolveExternalEntities:NO];
    [parser parse];
    [parser release];
	[sessionID autorelease];
	return sessionID;
}

- (void)parser:(SBJsonParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
	if (![elementName isEqualToString:@"input"]) return;
	NSString * name=[attributeDict objectForKey:@"name"];
	if (![name isEqualToString:@"lt"]) return;
	sessionID = [NSString stringWithString:[attributeDict objectForKey:@"value"]];
	[sessionID retain];
	[parser abortParsing];
	
}


@end

