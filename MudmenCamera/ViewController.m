//
//  ViewController.m
//  MudmenCamera
//
//  Created by TimTiger on 14-8-6.
//  Copyright (c) 2014年 Mudmen. All rights reserved.
//

#import "ViewController.h"
#import "MudCameraViewController.h"

@interface ViewController ()

@end

@implementation ViewController

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

- (IBAction)cameraAction:(id)sender {
    
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    MudCameraViewController *cameraVC = [storyBoard instantiateViewControllerWithIdentifier:@"MudCameraViewController"];
    [self presentViewController:cameraVC animated:YES completion:^{
        
    }];
}
@end
