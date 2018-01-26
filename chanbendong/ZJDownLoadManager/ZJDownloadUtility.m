//
//  ZJDownloadUtility.m
//  chanbendong
//
//  Created by 吴孜健 on 2018/1/22.
//  Copyright © 2018年 吴孜健. All rights reserved.
//

#import "ZJDownloadUtility.h"

@implementation ZJDownloadUtility

+ (float)calculateFileSizeInUnit:(unsigned long long)contentLength
{
    if (contentLength>=pow(1024, 3)) {
        return (float) (contentLength/(float)pow(1024, 3));
    }else if (contentLength>=pow(1024, 2)){
        return (float) (contentLength/(float)pow(1024, 2));
    }else if (contentLength>=1024){
        return (float) (contentLength/(float)1024);
    }else{
        return (float)contentLength;
    }
}

+ (NSString *)calculateUnit:(unsigned long long)contentLength
{
    if (contentLength>=pow(1024, 3)) {
        return @"GB";
    }else if (contentLength>=pow(1024, 2)){
        return @"MB";
    }else if (contentLength>=1024){
        return @"KB";
    }else{
        return @"Bytes";
    }
}

@end
