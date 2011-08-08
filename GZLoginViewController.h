//
//  GZLoginViewController.h
//  GalaxyZoo
//
//  Created by Joe Zuntz on 15/01/2010.
//  Copyright 2010 Imperial College London. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GZSession.h"

//@protocol GZLoginViewControllerDelegate;

@interface GZLoginViewController : UIViewController {
//	id <GZLoginViewControllerDelegate> delegate;
    GZSession * session;
	IBOutlet UITextField * usernameField;
	IBOutlet UITextField * passwordField;
    IBOutlet UILabel * titleLabel;
    NSString * titleString;
    
}
-(IBAction)backgroundClick:(id)sender;
@property (retain) GZSession * session;
//@property (retain) id <GZLoginViewControllerDelegate> delegate;
//@property (retain) UITextField * usernameField;
@property (retain) NSString * titleString;
//@property (retain) UITextField * passwordField;
@property (readonly) UILabel * titleLabel;
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil message:(NSString*)message;
-(IBAction) login;
-(IBAction) noAccount;
-(IBAction) createAccount;
+(void) showLoginWithMessage:(NSString*)message parent:(UIViewController*)parent session:(GZSession*)session;

@end
/*
@protocol GZLoginViewControllerDelegate
-(void)loginViewControllerDidLogin:(GZLoginViewController *)controller withUserName:(NSString*) username password:(NSString*)password;
-(void)loginViewControllerDidSetNoAccount:(GZLoginViewController *)controller;
-(void)loginViewControllerDidCreateAccount:(GZLoginViewController *)controller;
@end


*/