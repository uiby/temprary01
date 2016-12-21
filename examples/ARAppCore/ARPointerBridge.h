//
//  ARHandleBridge.h
//  ARToolKit5iOS
//
//  Created by 藤澤研学生ユーザ on 2016/10/12.
//
//

#include <AR/ar.h>
#include <AR/video.h>
//#include "ARView.h"
@interface ARPointerBridge : NSObject {
}
@property ARHandle *gARHandle;
-(void) setARHandle:(ARHandle *)gARHandle;
-(void)setARHandleByARParamLT:(ARParamLT *) arParamLT;
-(ARHandle *) getARHandle;
-(bool) hasARHandle;
-(int) getXSize;
-(int) getYSize;
@property AR2VideoParamT *gVid; // Video acquisition(映像の取得)
-(void) setAR2VideoParamT:(AR2VideoParamT *)gVid;
-(AR2VideoParamT *) getAR2VideoParamT;

@end
