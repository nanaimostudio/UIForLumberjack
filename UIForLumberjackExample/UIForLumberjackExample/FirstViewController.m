//
//  FirstViewController.m
//  UIForLumberjackExample
//
//  Created by Kamil Burczyk on 15.01.2014.
//  Copyright (c) 2014 Sigmapoint. All rights reserved.
//

#import "FirstViewController.h"
#import "UIForLumberjack.h"

@interface FirstViewController ()

@end

@implementation FirstViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)infoButtonPushed:(UIButton *)sender {
    [[UIForLumberjack sharedInstance] showLogInView:self.view];
}

@end
