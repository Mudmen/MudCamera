//
//  UIImage+CTBExtension.h
//  autopia
//
//  Created by sun on 13-6-9.
//  Copyright (c) 2013年 www.chetuobang.com . All rights reserved.
//

#define ROUNDEDRECT_PERCENTAGE 10

@interface UIImage (Extension)

- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees;

@end

// https://github.com/mustangostang/UIImage-Resize
@interface UIImage (Resize)

- (UIImage *) resizedImageWithMaximumSize: (CGSize) size;
- (UIImage *) resizedImageWithMinimumSize: (CGSize) size;

@end

