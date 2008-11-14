//
//  BWSelectableToolbar.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWSelectableToolbar.h"
#import "NSWindow+BWAdditions.h"

static BWSelectableToolbar *documentToolbar;
static NSToolbar *editableToolbar;

@interface NSToolbar (BWSTPrivate)
- (id)_defaultItemIdentifiers;
- (id)_window;
- (id)initWithCoder:(NSCoder *)decoder;
- (void)encodeWithCoder:(NSCoder*)coder;
@end

@interface BWSelectableToolbar (BWSTPrivate)
- (NSArray *)selectableItemIdentifiers;
- (void)setItemSelectors;
- (void)initialSetup;
- (void)toggleActiveView:(id)sender;
- (NSString *)identifierAtIndex:(int)index;
- (void)switchToItemAtIndex:(int)anIndex animate:(BOOL)flag;
- (int)toolbarIndexFromSelectableIndex:(int)selectableIndex;
- (void)selectInitialItem;
// IBDocument methods
- (void)addObject:(id)object toParent:(id)parent;
- (void)moveObject:(id)object toParent:(id)parent;
- (void)removeObject:(id)object;
- (id)parentOfObject:(id)anObj;
- (NSArray *)objectsforDocumentObject:(id)anObj;
- (NSArray *)childrenOfObject:(id)object;
@end

@implementation BWSelectableToolbar

@synthesize helper;
@synthesize labels;
@synthesize isPreferencesToolbar;

- (BWSelectableToolbar *)documentToolbar
{
	return [[documentToolbar retain] autorelease];
}

- (void)setDocumentToolbar:(BWSelectableToolbar *)obj
{
	[documentToolbar release];
	documentToolbar = [obj retain];
}

- (NSToolbar *)editableToolbar
{
	if ([self respondsToSelector:@selector(ibDidAddToDesignableDocument:)] == NO)
		return self;
	
	return [[editableToolbar retain] autorelease];
}

- (void)setEditableToolbar:(NSToolbar *)obj
{
	if ([self respondsToSelector:@selector(ibDidAddToDesignableDocument:)])
	{
//		NSLog(@"--self: %@",self);
//		NSLog(@"--editable toolbar is: %@",editableToolbar);
//		NSLog(@"--setting editable toolbar to: %@",obj);

		[editableToolbar release];
		editableToolbar = [obj retain];
	}

}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super initWithCoder:decoder]) != nil)
	{
		[self setDocumentToolbar:[decoder decodeObjectForKey:@"BWSTDocumentToolbar"]];
		[self setHelper:[decoder decodeObjectForKey:@"BWSTHelper"]];
		isPreferencesToolbar = [decoder decodeBoolForKey:@"BWSTIsPreferencesToolbar"];
		
//		NSLog(@"init with coder. helper decoded: %@", helper);
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [super encodeWithCoder:coder];
	
	[coder encodeObject:[self documentToolbar] forKey:@"BWSTDocumentToolbar"];
	[coder encodeObject:[self helper] forKey:@"BWSTHelper"];
	[coder encodeBool:isPreferencesToolbar forKey:@"BWSTIsPreferencesToolbar"];
	
//	NSLog(@"encode with coder. helper encoded: %@",helper);
}

// When the user drags the toolbar on the canvas, we want the default toolbar items to be a specific set that's more appropriate for a selectable toolbar (in particular,
// for a preferences window). Generally, you would supply these items in your -toolbarDefaultItemIdentifiers: delegate method. However, since Interface Builder stores 
// its default item identifiers in user defaults, the delegate method never gets called. To force the toolbar to have a different set of default items, we supply the
// identifiers in this private method.
- (id)_defaultItemIdentifiers
{
	NSArray *defaultItemIdentfiers = [super _defaultItemIdentifiers];
	NSArray *defaultIBItemIdentifiers = [NSArray arrayWithObjects:@"NSToolbarSeparatorItem",@"NSToolbarSpaceItem",@"NSToolbarFlexibleSpaceItem",nil];
	
	NSArray *idealDefaultItemIdentifiers = [NSArray arrayWithObjects:@"0D5950D1-D4A8-44C6-9DBC-251CFEF852E2",@"BWToolbarShowColorsItem",
											@"BWToolbarShowFontsItem",@"7E6A9228-C9F3-4F21-8054-E4BF3F2F6BA8",nil];
	
	if ([defaultItemIdentfiers isEqualToArray:defaultIBItemIdentifiers])
	{
		return idealDefaultItemIdentifiers;
	}

	return defaultItemIdentfiers;
}

- (id)initWithIdentifier:(NSString *)identifier
{
	if (self = [super initWithIdentifier:identifier])
	{		
		itemIdentifiers = [[NSMutableArray alloc] init];
        itemsByIdentifier = [[NSMutableDictionary alloc] init];  
		labels = [NSMutableArray array];
		
		selectedIndex = 0;
		inIB = YES;
		[self setEditableToolbar:self];
		
		[self performSelector:@selector(initialSetup) withObject:nil afterDelay:0];
	}
	return self;
}

- (void)awakeFromNib
{
	if ([self respondsToSelector:@selector(ibDidAddToDesignableDocument:)] == NO)
	{
		inIB = NO;

		window = [self _window];
		
		if ([helper isPreferencesToolbar])
		{
			[window setShowsToolbarButton:NO];
			[self setAllowsUserCustomization:NO];		
		}
		
		[self performSelector:@selector(selectInitialItem) withObject:nil afterDelay:0];
	}
}

- (void)selectFirstItem
{
	int toolbarIndex = [self toolbarIndexFromSelectableIndex:0];
	[self switchToItemAtIndex:toolbarIndex animate:NO];
}

- (void)selectInitialItem
{
	// When the window launches, we want to select the toolbar item that was previously selected.
	// So we have to find the toolbar index for our saved selected identifier.
	int toolbarIndex;
	
	if ([helper selectedIdentifier] != nil)
		toolbarIndex = [itemIdentifiers indexOfObject:[helper selectedIdentifier]];
	else
		toolbarIndex = [self toolbarIndexFromSelectableIndex:0];

	[self switchToItemAtIndex:toolbarIndex animate:NO];
}

- (void)initialSetup
{
	// Get a reference to the helper object in the document if we don't have one already
	if (helper == nil && inIB)
	{
		NSArray *windowChildren = [self childrenOfObject:[self parentOfObject:documentToolbar]];
		
		for (id anObj in windowChildren)
		{
			if ([anObj isMemberOfClass:NSClassFromString(@"BWSelectableToolbarHelper")])
			{
				helper = anObj;
//				NSLog(@"Got a reference to helper: %@",helper);
			}
				
		}
	}
	
//	if (helper == nil && inIB)
//		NSLog(@"Helper is nil");
	
	// Get reference to the editable toolbar in IB
	if ([self isMemberOfClass:NSClassFromString(@"IBEditableBWSelectableToolbar")])
	{
		[self setEditableToolbar:self];
		// realEditableToolbar = self;
		window = [[self editableToolbar] _window];
		
		if ([helper contentViewsByIdentifier].count == 0)
			[helper setInitialIBWindowSize:[window frame].size];
			
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(windowDidResize:)
													 name:NSWindowDidResizeNotification 
												   object:window];

	}
	
	window = [[self editableToolbar] _window];
	
	NSToolbarItem *currentItem;
	for (currentItem in [self items]) 
	{
		[itemIdentifiers addObject:[currentItem itemIdentifier]];
		[itemsByIdentifier setObject:currentItem forKey:[currentItem itemIdentifier]];
	}
	
	[self setDelegate:self];
	[self setItemSelectors];
	
	if ([helper selectedIdentifier] != nil && [helper contentViewsByIdentifier].count != 0)
	{
		// When the actual app is ran or an item is added or removed from the toolbar in IB, we need to select the previously stored identifier
		[self selectItemAtIndex:[itemIdentifiers indexOfObject:[helper selectedIdentifier]]];
	}
	else
	{
		// If we don't have a stored identifier, we select the first item in the toolbar
		[self selectItemAtIndex:[self toolbarIndexFromSelectableIndex:0]];
	}
	
	if ([self isMemberOfClass:NSClassFromString(@"IBEditableBWSelectableToolbar")])
	{
		// When the toolbar is initially dragged onto the canvas, record the content view and size of the window		
		NSMutableDictionary *tempCVBI = [[helper contentViewsByIdentifier] mutableCopy];
		[tempCVBI setObject:[window contentView] forKey:[helper selectedIdentifier]];
		[helper setContentViewsByIdentifier:tempCVBI];
		
		NSMutableDictionary *tempWSBI = [[helper windowSizesByIdentifier] mutableCopy];	
		[tempWSBI setObject:[NSValue valueWithSize:[window frame].size] forKey:[helper selectedIdentifier]];
		[helper setWindowSizesByIdentifier:tempWSBI];
	}
}

- (int)toolbarIndexFromSelectableIndex:(int)selectableIndex
{
	NSMutableArray *selectableItems = [[[NSMutableArray alloc] init] autorelease];
	
	for (NSToolbarItem *currentItem in [[self editableToolbar] items]) 
	{
		if (![[currentItem itemIdentifier] isEqualToString:@"NSToolbarSeparatorItem"] && 
			![[currentItem itemIdentifier] isEqualToString:@"NSToolbarSpaceItem"] &&
			![[currentItem itemIdentifier] isEqualToString:@"NSToolbarFlexibleSpaceItem"])
		{
			[selectableItems addObject:currentItem];
		}
	}
	
	if (selectableItems.count == 0)
		return 0;
	
	NSString *item = [selectableItems objectAtIndex:selectableIndex];
	
	int toolbarIndex = [[[self editableToolbar] items] indexOfObject:item];
	
	return toolbarIndex;
}

// Tells the toolbar to draw the selection behind the toolbar item and records the selected item identifier
- (void)selectItemAtIndex:(int)anIndex
{
	NSArray *toolbarItems = self.items;
	
	if (toolbarItems.count > 1)
	{
		NSToolbarItem *item = [toolbarItems objectAtIndex:anIndex];
		NSString *identifier = [item itemIdentifier];
		[self setSelectedItemIdentifier:identifier];
		
		[helper setSelectedIdentifier:identifier];
	}
}

// This is called when a selectable item is clicked. This is not called in IB (-setSelectedIndex: is used instead).
- (void)toggleActiveView:(id)sender
{
    NSString *identifier = [sender itemIdentifier];

	selectedIndex = [itemIdentifiers indexOfObject:identifier];

	[self switchToItemAtIndex:selectedIndex animate:YES];
}

- (void)setItemSelectors
{
	NSToolbarItem *currentItem;
	
	for (currentItem in [self items]) 
	{
		[currentItem setTarget:self];
		[currentItem setAction:@selector(toggleActiveView:)];
	}
}

- (NSString *)identifierAtIndex:(int)index
{
	NSToolbarItem *item;
	NSString *newIdentifier;
	if ([[self editableToolbar] items].count > 1)
	{
		item = [[[self editableToolbar] items] objectAtIndex:index];
		newIdentifier = [item itemIdentifier];
	}
	return newIdentifier;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSWindowDidResizeNotification
												  object:window];
	[itemIdentifiers release];
	[itemsByIdentifier release];
    [super dealloc];
}

#pragma mark NSWindow notifications

- (void)windowDidResize:(NSNotification *)notification
{
	NSSize size = [window frame].size;
	NSValue *sizeValue = [NSValue valueWithSize:size];
	NSString *key = [helper selectedIdentifier];
	
	if ([helper selectedIdentifier])
	{
		NSMutableDictionary *tempWSBI = [[helper windowSizesByIdentifier] mutableCopy];	
		[tempWSBI setObject:sizeValue forKey:key];
		[helper setWindowSizesByIdentifier:tempWSBI];
	}
}

#pragma mark NSToolbar delegate methods

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
	return itemIdentifiers;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar 
{
	return itemIdentifiers;
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInserted 
{
	return [itemsByIdentifier objectForKey:identifier];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [self selectableItemIdentifiers];
}

#pragma mark Support methods for delegate methods

- (NSArray *)selectableItemIdentifiers
{
	NSMutableArray *selectableItemIdentifiers = [[[NSMutableArray alloc] init] autorelease];
	
	if ([self editableToolbar] != nil)
	{
		for (NSToolbarItem *currentItem in [[self editableToolbar] items]) 
		{
			if (![[currentItem itemIdentifier] isEqualToString:@"NSToolbarSeparatorItem"] && 
				![[currentItem itemIdentifier] isEqualToString:@"NSToolbarSpaceItem"] &&
				![[currentItem itemIdentifier] isEqualToString:@"NSToolbarFlexibleSpaceItem"])
			{
				[selectableItemIdentifiers addObject:[currentItem itemIdentifier]];
			}
		}
	}
	else
	{
		for (NSToolbarItem *currentItem in [self items]) 
		{
			if (![[currentItem itemIdentifier] isEqualToString:@"NSToolbarSeparatorItem"] && 
				![[currentItem itemIdentifier] isEqualToString:@"NSToolbarSpaceItem"] &&
				![[currentItem itemIdentifier] isEqualToString:@"NSToolbarFlexibleSpaceItem"])
			{
				[selectableItemIdentifiers addObject:[currentItem itemIdentifier]];
			}
		}
	}
	
	return selectableItemIdentifiers;
}

#pragma mark IB Inspector support methods

- (void)setIsPreferencesToolbar:(BOOL)flag
{
	[helper setIsPreferencesToolbar:flag];
	isPreferencesToolbar = flag;
	
	if (flag)
	{
		// Record the current window title
		[helper setOldWindowTitle:[[self parentOfObject:self] title]];
		
		// Change the window title to the name of the active tab
		NSToolbarItem *selectedItem;
		for (NSToolbarItem *item in [[self editableToolbar] items])
		{
			if ([[item itemIdentifier] isEqualToString:[[self editableToolbar] selectedItemIdentifier]])
				selectedItem = item;
		}
		[[self parentOfObject:self] setTitle:[selectedItem label]];
		
		// Remove the toolbar button
		[[self parentOfObject:self] setShowsToolbarButton:NO];	
	}
	else
	{
		// Restore the old window title
		[[self parentOfObject:self] setTitle:[helper oldWindowTitle]];
		
		// Add the toolbar button
		[[self parentOfObject:self] setShowsToolbarButton:YES];
	}
}

- (NSMutableArray *)labels
{	
	NSMutableArray *labelArray = [[NSMutableArray alloc] init];
	
	for (NSToolbarItem *currentItem in [[self editableToolbar] items]) 
	{
		if (![[currentItem itemIdentifier] isEqualToString:@"NSToolbarSeparatorItem"] && 
			![[currentItem itemIdentifier] isEqualToString:@"NSToolbarSpaceItem"] &&
			![[currentItem itemIdentifier] isEqualToString:@"NSToolbarFlexibleSpaceItem"])
		{
			[labelArray addObject:[currentItem label]];
		}
	}
	
	return [[labelArray retain] autorelease];
}

- (int)selectedIndex
{
	// The actual selected index can change on us (for instance, when the user re-orders toolbar items). So we need to figure it out dynamically, based on the selected identifier.
	if ([[helper selectedIdentifier] isEqualToString:@""])
		selectedIndex = 0;
	else
		selectedIndex = [[self selectableItemIdentifiers] indexOfObject:[helper selectedIdentifier]];

	return selectedIndex;
}

- (void)setSelectedIndex:(int)anIndex
{
	selectedIndex = anIndex;
	[self switchToItemAtIndex:[self toolbarIndexFromSelectableIndex:anIndex] animate:YES];
}

#pragma mark Selection Switching

- (void)switchToItemAtIndex:(int)anIndex animate:(BOOL)shouldAnimate
{	
	NSString *oldIdentifier = [helper selectedIdentifier];
	
	// Put the selection highlight on the toolbar item
	[(BWSelectableToolbar *)[self editableToolbar] selectItemAtIndex:anIndex];

	// Make a new container view and add it to the IB document
	NSView *containerView = [[NSView alloc] initWithFrame:[[window contentView] frame]];
	if (inIB)
		[self addObject:containerView toParent:[self parentOfObject:self]];
	
	// Move the subviews from the content view to the container view
	NSArray *oldSubviews = [[[[window contentView] subviews] copy] autorelease];
	for (NSView *view in oldSubviews)
	{
		if (inIB)
			[self moveObject:view toParent:containerView];
		[containerView addSubview:view];
	}
	
	// Store the container view and window size in the dictionaries
	NSMutableDictionary *tempCVBI = [[helper contentViewsByIdentifier] mutableCopy];
	[tempCVBI setObject:containerView forKey:oldIdentifier];
	[helper setContentViewsByIdentifier:tempCVBI];
	
	NSSize oldWindowSize = [window frame].size;
	NSMutableDictionary *tempWSBI = [[helper windowSizesByIdentifier] mutableCopy];
	[tempWSBI setObject:[NSValue valueWithSize:oldWindowSize] forKey:oldIdentifier];
	[helper setWindowSizesByIdentifier:tempWSBI];

	
	NSString *newIdentifier = [self identifierAtIndex:anIndex];
	
	if ([[helper contentViewsByIdentifier] objectForKey:newIdentifier] == nil) // If we haven't stored the content view in our dictionary. i.e. this is a new tab
	{
		// Resize the window
		[window resizeToSize:[helper initialIBWindowSize] animate:shouldAnimate];	
		
		// Record the new tab content view and window size
		if (inIB)
		{
			NSMutableDictionary *tempCVBI = [[helper contentViewsByIdentifier] mutableCopy];
			[tempCVBI setObject:[window contentView] forKey:newIdentifier];
			[helper setContentViewsByIdentifier:tempCVBI];
			
			NSMutableDictionary *tempWSBI = [[helper windowSizesByIdentifier] mutableCopy];	
			[tempWSBI setObject:[NSValue valueWithSize:[window frame].size] forKey:newIdentifier];
			[helper setWindowSizesByIdentifier:tempWSBI];
		}
	}
	else // If we have the content view in our dictionary, set the window's content view to be the saved view
	{
		// Resize the window
		NSSize windowSize = [[[helper windowSizesByIdentifier] objectForKey:newIdentifier] sizeValue];
		[window resizeToSize:windowSize animate:shouldAnimate];

		NSArray *newSubviews = [[[[[helper contentViewsByIdentifier] objectForKey:newIdentifier] subviews] copy] autorelease];
		
		if (newSubviews.count > 0 && newSubviews != nil)
		{
			for (NSView *view in newSubviews)
			{
				if (inIB)
				{
					[self moveObject:view toParent:[window contentView]];
				}
				
				[[window contentView] addSubview:view];
			}
		}
					
		// Remove the container view for the selected tab from the document since those items are now in the window's content view.			
		if (inIB)
			[self removeObject:[[helper contentViewsByIdentifier] objectForKey:newIdentifier]];
					
	}
	
	// After the new content view is swapped in, change the window title to be the selected item label
	if ([helper isPreferencesToolbar])
	{
		for (NSToolbarItem *item in [[self editableToolbar] items])
		{
			if ([[item itemIdentifier] isEqualToString:newIdentifier])
			{
				[window setTitle:[item label]];
				
				if (inIB)
					[[self parentOfObject:self] setTitle:[item label]];
			}
		}		
	}

}

@end