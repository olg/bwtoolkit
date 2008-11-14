//
//  BWAddMiniBottomBar.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWAddMiniBottomBar.h"

@interface NSWindow (BWBBPrivate)
- (void)setBottomCornerRounded:(BOOL)flag;
@end

@implementation BWAddMiniBottomBar

- (id)initWithCoder:(NSCoder *)decoder;
{
    if ((self = [super initWithCoder:decoder]) != nil)
	{
		if ([self respondsToSelector:@selector(ibDidAddToDesignableDocument:)])
			[self performSelector:@selector(addBottomBar) withObject:nil afterDelay:0];			
	}
	return self;
}

- (void)awakeFromNib
{
	[[self window] setContentBorderThickness:16	forEdge:NSMinYEdge];
	
	// Private method
	if ([[self window] respondsToSelector:@selector(setBottomCornerRounded:)])
		[[self window] setBottomCornerRounded:NO];
}

- (NSRect)bounds
{
	return NSMakeRect(-10000,-10000,0,0);
}

@end