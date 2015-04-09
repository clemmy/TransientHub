//
//  TWBaseViewController.m
//  TransientHub
//
//  Created by Kevin Hunt on 2015-04-03.
//  Copyright (c)  2015 Prophet Studios. All rights reserved.
//

#import "TWBaseViewController.h"

NSString * const kUnwindToSidePanelMenuSegueIdentifier = @"unwindToSidePanelMenuSegue";

@interface TWBaseViewController ()

@end

@implementation TWBaseViewController

- (NSString *) getSegueID{
    return nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark - Navigation
/*
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */
- (IBAction)topLeftNavigationButtonTapped:(id)sender {
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        if (self.slidingViewController.currentTopViewPosition == ECSlidingViewControllerTopViewPositionCentered) {
            [self performSegueWithIdentifier:kUnwindToSidePanelMenuSegueIdentifier sender:sender];
        } else {
            [self.slidingViewController.underLeftViewController performSegueWithIdentifier:[self getSegueID] sender:sender];
        }
    }
}


@end
