//
//  UIImage+CTBExtension.m
//  autopia
//
//  Created by sun on 13-6-9.
//  Copyright (c) 2013年 www.chetuobang.com . All rights reserved.
//

#import "UIImage+Extension.h"

@implementation UIImage (Extension)

CGFloat CTBDegreesToRadians(CGFloat degrees);

CGFloat CTBRadiansToDegrees(CGFloat radians);


CGFloat CTBDegreesToRadians(CGFloat degrees) {
    return degrees * M_PI / 180;
};

CGFloat CTBRadiansToDegrees(CGFloat radians) {
    return radians * 180 / M_PI;
};


- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees {
    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.size.width, self.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(CTBDegreesToRadians(degrees));
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    //    [rotatedViewBox release];

    // Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();

    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width / 2, rotatedSize.height / 2);

    //   // Rotate the image context
    CGContextRotateCTM(bitmap, CTBDegreesToRadians(degrees));

    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-self.size.width / 2, -self.size.height / 2, self.size.width, self.size.height), [self CGImage]);

    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return newImage;
}

@end

@implementation UIImage (Resize)

- (CGImageRef)CGImageWithCorrectOrientation {
//    if (self.imageOrientation == UIImageOrientationDown) {
//        return [self CGImage];
//    }
    UIGraphicsBeginImageContext(self.size);

    CGContextRef context = UIGraphicsGetCurrentContext();

    if (self.imageOrientation == UIImageOrientationRight) {
        CGContextRotateCTM(context, 90 * M_PI/ 180);
    } else if (self.imageOrientation == UIImageOrientationLeft) {
        CGContextRotateCTM(context, -90 * M_PI/ 180);
    } else if (self.imageOrientation == UIImageOrientationUp) {
        CGContextRotateCTM(context, 180 * M_PI/ 180);
    }

    [self drawAtPoint:CGPointMake(0, 0)];

    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIGraphicsEndImageContext();

    return cgImage;
}

- (UIImage *)resizedImageWithMinimumSize:(CGSize)size {
    CGImageRef imgRef = [self CGImageWithCorrectOrientation];
    CGFloat original_width = CGImageGetWidth(imgRef);
    CGFloat original_height = CGImageGetHeight(imgRef);
    CGFloat width_ratio = size.width / original_width;
    CGFloat height_ratio = size.height / original_height;
    CGFloat scale_ratio = width_ratio > height_ratio ? width_ratio : height_ratio;
    CGImageRelease(imgRef);
    return [self drawImageInBounds:CGRectMake(0, 0, round(original_width * scale_ratio), round(original_height * scale_ratio))];
}

- (UIImage *)resizedImageWithMaximumSize:(CGSize)size {
    CGImageRef imgRef = [self CGImageWithCorrectOrientation];
    CGFloat original_width = CGImageGetWidth(imgRef);
    CGFloat original_height = CGImageGetHeight(imgRef);
    CGFloat width_ratio = size.width / original_width;
    CGFloat height_ratio = size.height / original_height;
    CGFloat scale_ratio = width_ratio < height_ratio ? width_ratio : height_ratio;
    CGImageRelease(imgRef);
    return [self drawImageInBounds:CGRectMake(0, 0, round(original_width * scale_ratio), round(original_height * scale_ratio))];
}

- (UIImage *)drawImageInBounds:(CGRect)bounds {
    UIGraphicsBeginImageContext(bounds.size);
    [self drawInRect:bounds];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resizedImage;
}

- (UIImage *)croppedImageWithRect:(CGRect)rect {

    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect drawRect = CGRectMake(-rect.origin.x, -rect.origin.y, self.size.width, self.size.height);
    CGContextClipToRect(context, CGRectMake(0, 0, rect.size.width, rect.size.height));
    [self drawInRect:drawRect];
    UIImage *subImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return subImage;
}

@end

