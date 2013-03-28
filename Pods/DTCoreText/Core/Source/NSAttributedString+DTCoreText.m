//
//  NSAttributedString+DTCoreText.m
//  DTCoreText
//
//  Created by Oliver Drobnik on 2/1/12.
//  Copyright (c) 2012 Drobnik.com. All rights reserved.
//

#import "DTCoreText.h"
#import "NSAttributedString+DTCoreText.h"
#import "DTHTMLWriter.h"

@implementation NSAttributedString (DTCoreText)

#pragma mark Text Attachments
- (NSArray *)textAttachmentsWithPredicate:(NSPredicate *)predicate
{
	NSMutableArray *tmpArray = [NSMutableArray array];
	
	NSUInteger index = 0;
	
	while (index<[self length]) 
	{
		NSRange range;
		NSDictionary *attributes = [self attributesAtIndex:index effectiveRange:&range];
		
		DTTextAttachment *attachment = [attributes objectForKey:NSAttachmentAttributeName];
		
		if (attachment)
		{
			if ([predicate evaluateWithObject:attachment])
			{
				[tmpArray addObject:attachment];
			}
		}
		
		index += range.length;
	}
	
	if ([tmpArray count])
	{
		return tmpArray;
	}
	
	return nil;
}


#pragma mark Calculating Ranges

- (NSInteger)itemNumberInTextList:(DTCSSListStyle *)list atIndex:(NSUInteger)location
{
	NSRange effectiveRange;
	NSArray *textListsAtIndex = [self attribute:DTTextListsAttribute atIndex:location effectiveRange:&effectiveRange];
	
	if (!textListsAtIndex)
	{
		return 0;
	}
	
	// get outermost list
	DTCSSListStyle *outermostList = [textListsAtIndex objectAtIndex:0];
	
	// get the range of all lists
	NSRange totalRange = [self rangeOfTextList:outermostList atIndex:location];
	
	// get naked NSString
    NSString *string = [[self string] substringWithRange:totalRange];
	
    // entire string
    NSRange range = NSMakeRange(0, [string length]);
	
	NSMutableDictionary *countersPerList = [NSMutableDictionary dictionary];
	
	// enumerating through the paragraphs in the plain text string
    [string enumerateSubstringsInRange:range options:NSStringEnumerationByParagraphs usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop)
     {
		 NSRange paragraphListRange;
		 NSArray *textLists = [self attribute:DTTextListsAttribute atIndex:substringRange.location + totalRange.location effectiveRange:&paragraphListRange];
		 
		 DTCSSListStyle *currentEffectiveList = [textLists lastObject];
		 
		 NSNumber *key = [NSNumber numberWithInteger:[currentEffectiveList hash]]; // hash defaults to address
		 NSNumber *currentCounterNum = [countersPerList objectForKey:key];
		 
		 NSInteger currentCounter=0;
		 
		 if (!currentCounterNum)
		 {
			 currentCounter = currentEffectiveList.startingItemNumber;
		 }
		 else
		 {
			 currentCounter = [currentCounterNum integerValue]+1;
		 }
		 
		 currentCounterNum = [NSNumber numberWithInteger:currentCounter];
		 [countersPerList setObject:currentCounterNum forKey:key];
		 
		 // calculate the actual range
		 NSRange actualRange = enclosingRange;  // includes a potential \n
		 actualRange.location += totalRange.location;

		 if (NSLocationInRange(location, actualRange))
		 {
			 *stop = YES;
		 }
     }
     ];
	
	NSNumber *key = [NSNumber numberWithInteger:[list hash]]; // hash defaults to address
	NSNumber *currentCounterNum = [countersPerList objectForKey:key];
	
	return [currentCounterNum integerValue];
}


- (NSRange)_rangeOfObject:(id)object inArrayBehindAttribute:(NSString *)attribute atIndex:(NSUInteger)location
{
	NSUInteger searchIndex = location;
	
	NSArray *arrayAtIndex;
	NSUInteger minFoundIndex = NSUIntegerMax;
	NSUInteger maxFoundIndex = 0;
	
	BOOL foundList = NO;
	
	do 
	{
		NSRange effectiveRange;
		arrayAtIndex = [self attribute:attribute atIndex:searchIndex effectiveRange:&effectiveRange];
		
		if([arrayAtIndex containsObject:object])
		{
			foundList = YES;
			
			searchIndex = effectiveRange.location;
			
			minFoundIndex = MIN(minFoundIndex, searchIndex);
			maxFoundIndex = MAX(maxFoundIndex, NSMaxRange(effectiveRange));
		}
		
		if (!searchIndex || !foundList)
		{
			// reached beginning of string
			break;
		}
		
		searchIndex--;
	} 
	while (foundList && searchIndex>0);
	
	// if we didn't find the list at all, return 
	if (!foundList)
	{
		return NSMakeRange(0, NSNotFound);
	}
	
	// now search forward
	
	searchIndex = maxFoundIndex;
	
	while (searchIndex < [self length])
	{
		NSRange effectiveRange;
		arrayAtIndex = [self attribute:attribute atIndex:searchIndex effectiveRange:&effectiveRange];
		
		foundList = [arrayAtIndex containsObject:object];
		
		if (!foundList)
		{
			break;
		}
		
		searchIndex = NSMaxRange(effectiveRange);
		
		minFoundIndex = MIN(minFoundIndex, effectiveRange.location);
		maxFoundIndex = MAX(maxFoundIndex, NSMaxRange(effectiveRange));
	}
	
	return NSMakeRange(minFoundIndex, maxFoundIndex-minFoundIndex);
}

- (NSRange)rangeOfTextList:(DTCSSListStyle *)list atIndex:(NSUInteger)location
{
	return [self _rangeOfObject:list inArrayBehindAttribute:DTTextListsAttribute atIndex:location];
}

- (NSRange)rangeOfTextBlock:(DTTextBlock *)textBlock atIndex:(NSUInteger)location
{
	return [self _rangeOfObject:textBlock inArrayBehindAttribute:DTTextBlocksAttribute atIndex:location];
}

- (NSRange)rangeOfAnchorNamed:(NSString *)anchorName
{
	__block NSRange foundRange = NSMakeRange(0, NSNotFound);
	
	[self enumerateAttribute:DTAnchorAttribute inRange:NSMakeRange(0, [self length]) options:0 usingBlock:^(NSString *value, NSRange range, BOOL *stop) {
		if ([value isEqualToString:anchorName])
		{
			*stop = YES;
			foundRange = range;
		}
	}];
	
	return foundRange;
}

#pragma mark HTML Encoding

- (NSString *)htmlString
{
	// create a writer
	DTHTMLWriter *writer = [[DTHTMLWriter alloc] initWithAttributedString:self];
	
	// return it's output
	return [writer HTMLString];
}

- (NSString *)htmlFragment
{
	// create a writer
	DTHTMLWriter *writer = [[DTHTMLWriter alloc] initWithAttributedString:self];
	
	// return it's output
	return [writer HTMLFragment];
}

- (NSString *)plainTextString
{
	NSString *tmpString = [self string];
	
	return [tmpString stringByReplacingOccurrencesOfString:UNICODE_OBJECT_PLACEHOLDER withString:@""];
}

#pragma mark Generating Special Attributed Strings
+ (NSAttributedString *)prefixForListItemWithCounter:(NSUInteger)listCounter listStyle:(DTCSSListStyle *)listStyle listIndent:(CGFloat)listIndent attributes:(NSDictionary *)attributes
{
	// get existing values from attributes
	CTParagraphStyleRef paraStyle = (__bridge CTParagraphStyleRef)[attributes objectForKey:(id)kCTParagraphStyleAttributeName];
	CTFontRef font = (__bridge CTFontRef)[attributes objectForKey:(id)kCTFontAttributeName];
	
	DTCoreTextFontDescriptor *fontDescriptor = nil;
	DTCoreTextParagraphStyle *paragraphStyle = nil;
	
	if (paraStyle)
	{
		paragraphStyle = [DTCoreTextParagraphStyle paragraphStyleWithCTParagraphStyle:paraStyle];
		
		paragraphStyle.tabStops = nil;
		
		paragraphStyle.headIndent = listIndent;
		paragraphStyle.paragraphSpacing = 0;
		
		if (listStyle.type != DTCSSListStyleTypeNone)
		{
			// first tab is to right-align bullet, numbering against
			CGFloat tabOffset = paragraphStyle.headIndent - 5.0f*1.0; // TODO: change with font size
			[paragraphStyle addTabStopAtPosition:tabOffset alignment:kCTRightTextAlignment];
		}
		
		// second tab is for the beginning of first line after bullet
		[paragraphStyle addTabStopAtPosition:paragraphStyle.headIndent alignment:	kCTLeftTextAlignment];	
	}
	
	if (font)
	{
		fontDescriptor = [DTCoreTextFontDescriptor fontDescriptorForCTFont:font];
	}
	
	NSMutableDictionary *newAttributes = [NSMutableDictionary dictionary];
	
	if (fontDescriptor)
	{
		// make a font without italic or bold
		DTCoreTextFontDescriptor *fontDesc = [fontDescriptor copy];
		
		fontDesc.boldTrait = NO;
		fontDesc.italicTrait = NO;
		
		font = [fontDesc newMatchingFont];
		
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_5_1
		if (___useiOS6Attributes)
		{
			UIFont *uiFont = [UIFont fontWithCTFont:font];
			[newAttributes setObject:uiFont forKey:NSFontAttributeName];
			
			CFRelease(font);
		}
		else
#endif
		{
			[newAttributes setObject:CFBridgingRelease(font) forKey:(id)kCTFontAttributeName];
		}
	}
	
	CGColorRef textColor = (__bridge CGColorRef)[attributes objectForKey:(id)kCTForegroundColorAttributeName];
	
	if (textColor)
	{
		[newAttributes setObject:(__bridge id)textColor forKey:(id)kCTForegroundColorAttributeName];
	}
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_5_1
	else if (___useiOS6Attributes)
	{
		UIColor *uiColor = [attributes objectForKey:NSForegroundColorAttributeName];
		
		if (uiColor)
		{
			[newAttributes setObject:uiColor forKey:NSForegroundColorAttributeName];
		}
	}
#endif
	
	// add paragraph style (this has the tabs)
	if (paragraphStyle)
	{
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_5_1
		if (___useiOS6Attributes)
		{
			NSParagraphStyle *style = [paragraphStyle NSParagraphStyle];
			[newAttributes setObject:style forKey:NSParagraphStyleAttributeName];
		}
		else
#endif
		{
			CTParagraphStyleRef newParagraphStyle = [paragraphStyle createCTParagraphStyle];
			[newAttributes setObject:CFBridgingRelease(newParagraphStyle) forKey:(id)kCTParagraphStyleAttributeName];
		}
	}
	
	// add textBlock if there's one (this has padding and background color)
	NSArray *textBlocks = [attributes objectForKey:DTTextBlocksAttribute];
	if (textBlocks)
	{
		[newAttributes setObject:textBlocks forKey:DTTextBlocksAttribute];
	}
	
	// transfer all lists so that
	NSArray *lists = [attributes objectForKey:DTTextListsAttribute];
	if (lists)
	{
		[newAttributes setObject:lists forKey:DTTextListsAttribute];
	}
	
	// add a marker so that we know that this is a field/prefix
	[newAttributes setObject:@"{listprefix}" forKey:DTFieldAttribute];
	
	NSString *prefix = [listStyle prefixWithCounter:listCounter];
	
	if (prefix)
	{
		DTImage *image = nil;
		
		if (listStyle.imageName)
		{
			image = [DTImage imageNamed:listStyle.imageName];
			
			if (!image)
			{
				// image invalid
				listStyle.imageName = nil;
				
				prefix = [listStyle prefixWithCounter:listCounter];
			}
		}
		
		NSMutableAttributedString *tmpStr = [[NSMutableAttributedString alloc] initWithString:prefix attributes:newAttributes];
		
		if (image)
		{
			// make an attachment for the image
			DTTextAttachment *attachment = [[DTTextAttachment alloc] init];
			attachment.contents = image;
			attachment.contentType = DTTextAttachmentTypeImage;
			attachment.displaySize = image.size;
			
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_5_1
			// need run delegate for sizing
			CTRunDelegateRef embeddedObjectRunDelegate = createEmbeddedObjectRunDelegate(attachment);
			[newAttributes setObject:CFBridgingRelease(embeddedObjectRunDelegate) forKey:(id)kCTRunDelegateAttributeName];
#endif
			
			// add attachment
			[newAttributes setObject:attachment forKey:NSAttachmentAttributeName];				
			
			if (listStyle.position == DTCSSListStylePositionInside)
			{
				[tmpStr setAttributes:newAttributes range:NSMakeRange(2, 1)];
			}
			else
			{
				[tmpStr setAttributes:newAttributes range:NSMakeRange(1, 1)];
			}
		}
		
		return tmpStr;
	}
	
	return nil;
}

@end