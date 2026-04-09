//
//  MPAboutWindowController.h
//  MacDown
//
//  Custom About window for the treehousetim fork. Replaces the standard
//  About panel so we can show full third-party license texts in a
//  resizable scrollable area and make the fork attribution explicit.
//

#import <Cocoa/Cocoa.h>

@interface MPAboutWindowController : NSWindowController

+ (instancetype)sharedController;

@end
