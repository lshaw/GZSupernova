//
//  ZooGalaxyParser.m
//  GalaxyZoo
//
//  Created by Joe Zuntz on 17/06/2009.
//  Copyright 2009 Joe Zuntz. All rights reserved.
//
// modified 11:51am 03/08/11, replacing XML with Json - Liam


#import "GZJsonParser.h"


@implementation GZJsonSimpleElementFinder

@synthesize targetTag;
@synthesize tagValue;

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


-(NSString*) findContentsOfTag:(NSString*)tag
{
	// Changed to parse JSON instead - hope it works. Liam
    if (!_data) return nil;
    //self.tagValue=nil;
    self.targetTag=tag;
    inTag=NO; // not sure what's going on with these bits
	
	//think this is the correct parsing method using SBJsonParser

    SBJsonParser * parser = [[SBJsonParser alloc] initWithData:_data];
	NSError *error = nil;
	NSString * return_value = [NSString stringWithString:[parser objectWithString:self.targetTag] error:&error]; 
	[parser release];
	
    return return_value;
}

// for starting to parse
- (void) parser:(SBJsonParser *)parser 
didStartElement:(NSString *)elementName 
   namespaceURI:(NSString *)namespaceURI 
  qualifiedName:(NSString *)qName 
	 attributes:(NSDictionary *)attributeDict 
{
	// Check if the element is equal to the targetTag, and if it is create a mutable string
	// for storing the tagValue
	if ([elementName isEqualToString:targetTag]) 
	{
        inTag=YES;
        self.tagValue = [NSMutableString stringWithCapacity:50]; 
    }
}

- (void)parser:(SBJsonParser *)parser foundCharacters:(NSString *)string
{
    if (!inTag) return; // if the flag is NO, then character value is not appending to tagValue
    [self.tagValue appendString:string]; // otherwise, append the character to the tagValue
    
}

// for ending parsing
- (void)parser:(SBJsonParser *)parser 
 didEndElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI 
 qualifiedName:(NSString *)qName
{
    if (!inTag) return; // if not inTag, then return
    [parser abortParsing];  // if inTag, then stop parsing - this is only necessary when using XML - because we're
							// using JSON instead, I don't think we need this bit?
}


@end


// Also contained here is the loginParser implementation - will this still be using XML?
// If so, then don't need to change anything. If it will be using JSON instead, then just use
// same parsing method from above in findContentsOfTag method
@implementation GZLoginParser

- (NSString*)getSessionID:(NSData*) data
{
	inSession=NO;
//	NSString * xmlstring = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//	NSLog(@"Parsing:\n\n%@\n\n",xmlstring);
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
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

- (void) parser:(NSXMLParser *)parser 
didStartElement:(NSString *)elementName 
   namespaceURI:(NSString *)namespaceURI 
  qualifiedName:(NSString *)qName 
	 attributes:(NSDictionary *)attributeDict 
{
	if (![elementName isEqualToString:@"input"]) return;
	NSString * name=[attributeDict objectForKey:@"name"];
	if (![name isEqualToString:@"lt"]) return;
	sessionID = [NSString stringWithString:[attributeDict objectForKey:@"value"]];
	[sessionID retain];
	[parser abortParsing]; 
	
}


@end

