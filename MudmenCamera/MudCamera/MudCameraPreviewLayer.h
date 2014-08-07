//
//  MudCameraPreviewLayer.h
//  MudmenCamera
//
//  Created by TimTiger on 14-8-6.
//  Copyright (c) 2014年 Mudmen. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface MudCameraPreviewLayer : UIView

@property (nonatomic) AVCaptureSession *session;

@end
