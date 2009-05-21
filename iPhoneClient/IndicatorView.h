//
//  IndicatorView.h
//  fun with button bars
//
//  Created by Brian Deith on 5/20/09.
//  Copyright 2009 Brian Deith. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface IndicatorView : UIView {
	BOOL expanded;
	UIColor *fillColor;
}
@property(readwrite) BOOL expanded;
@property(readwrite,retain) UIColor *fillColor;

@end
