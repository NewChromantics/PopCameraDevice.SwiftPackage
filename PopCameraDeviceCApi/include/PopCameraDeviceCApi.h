/*
	Any symbols included from this file end up being exposed to swift
 
	- No need for a module map
	- C only (not c++)
*/
#define __export	//	C doesn't need extern"C"

#include <TargetConditionals.h>	//	#if TARGET_OS_IPHONE etc

//	todo: get PopCameraDevice to have one name!

#if TARGET_OS_IPHONE==1
#include "PopCameraDevice_Ios/PopCameraDevice.h"
#elif TARGET_OS_MAC==1
#include "PopCameraDevice_Osx/PopCameraDevice.h"
#else
#error unknown target
#endif
