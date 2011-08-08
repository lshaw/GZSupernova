//
//  GZLoginViewController.m
//  GalaxyZoo
//
//  Created by Joe Zuntz on 15/01/2010.
//  Copyright 2010 Imperial College London. All rights reserved.
//

#import "GZLoginViewController.h"

@implementation GZLoginViewController


 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil message:(NSString*)message{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
    }
    return self;
}


/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

+(void) showLoginWithMessage:(NSString*)message parent:(UIViewController*)parent session:(GZSession*)session
{
    NSLog(@"Showing Login screen.");
    GZLoginViewController * controller = [[GZLoginViewController alloc] initWithNibName:@"GZLoginViewController" bundle:[NSBundle mainBundle]];

    float width = controller.view.bounds.size.width;
    CGRect frame = CGRectMake(width/8., 0.0, width*3./4., 100.0);
    UILabel *newLabel = [ [UILabel alloc ] initWithFrame:frame ];
    newLabel.textAlignment =  UITextAlignmentCenter;
    newLabel.textColor = [UIColor whiteColor];
    newLabel.backgroundColor = [UIColor blackColor];
    newLabel.text = message;
    [newLabel setAdjustsFontSizeToFitWidth:YES];

    newLabel.font = [UIFont systemFontOfSize:24.];
    [controller.view addSubview:newLabel];
    [newLabel release];
    
//    controller.titleString=message;
    controller.session=session;
    [parent presentModalViewController:controller animated:YES];
    controller.titleString=message;
    [controller release];
}
@synthesize titleLabel;

-(IBAction) login
{
    NSString * username = [usernameField text];
    NSString * password = [passwordField text];
    if ([username isEqualToString:@""]) return;
    if ([password isEqualToString:@""]) return;
    NSLog(@"start login %@",username);
    [self.session setUsername:username Password:password];
    [self dismissModalViewControllerAnimated:YES];
}
-(IBAction) noAccount
{
    NSLog(@"No account");
    [self.session setNoAccount];
    [self dismissModalViewControllerAnimated:YES];
}
-(IBAction) createAccount
{
    NSLog(@"set create account");
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: @"https://www.zooniverse.org/signup"]];
    [self dismissModalViewControllerAnimated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)field
{
    if (field==usernameField){
        if ([usernameField.text isEqualToString:@""]) return NO;
        [passwordField becomeFirstResponder];
        return YES;
    }
    else if (field==passwordField){
        if ([passwordField.text isEqualToString:@""]) return NO;
        else [self login];
        return YES;
        }
    else{
    NSLog(@"What?");
    return YES;
    }

}

-(IBAction)backgroundClick:(id)sender
{
    [usernameField resignFirstResponder];
    [passwordField resignFirstResponder];
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [titleString release];
    [super dealloc];
}

@synthesize session;
@synthesize titleString;
@end
