//
//  ARHandleBridge.m
//  ARToolKit5iOS
//
//  Created by 藤澤研学生ユーザ on 2016/10/12.
//
//

#import <Foundation/Foundation.h>
#import "ARPointerBridge.h"

@implementation ARPointerBridge {
    
    //ARHandle   *gARHandle;
}
@synthesize gARHandle;
@synthesize gVid;

-(id) init {
    gARHandle = NULL;
    return 0;
}
-(void)setARHandle:(ARHandle *) handle {
    gARHandle = handle;
    if (gARHandle != NULL) NSLog(@"has arhandle./n");
    else NSLog(@"not has arhandle./n");
}
-(void)setARHandleByARParamLT:(ARParamLT *) arParamLT {
    gARHandle = arCreateHandle(arParamLT);
}

-(ARHandle *)getARHandle {
    return gARHandle;
}
-(bool)hasARHandle {
    //if (gARHandle == NULL) return false;
    return true;
}
-(int)getXSize {
    return gARHandle->xsize;//pointee.xsize;
}
-(int)getYSize {
    return gARHandle->ysize;//pointee.xsize;
}

//AR2VideoParamT
-(void)setAR2VideoParamT:(AR2VideoParamT *) obj {
    gVid = obj;
}
-(AR2VideoParamT *)getAR2VideoParamT {
    return gVid;
}

@end
