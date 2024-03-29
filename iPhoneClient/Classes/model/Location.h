//
//  Location.h
//  ARIS
//
//  Created by David Gagnon on 2/26/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "NearbyObjectProtocol.h"

@interface Location : NSObject <NearbyObjectProtocol> {
	int locationId;
	int iconMediaId;
	NSString *name;
	CLLocation *location;
	double error;
	NSString *objectType;
	nearbyObjectKind kind; //for the protocol
	int objectId;
	bool hidden;
	bool forcedDisplay;
	int qty;
}

@property(readwrite, assign) int locationId;
@property(nonatomic, retain) NSString *name;
@property(readwrite, assign) int iconMediaId;

@property(nonatomic, retain) CLLocation *location;
@property(readwrite) double error;
@property(nonatomic, retain) NSString *objectType;
@property(readonly) nearbyObjectKind kind;
- (nearbyObjectKind) kind;
@property(readwrite) int objectId;
@property(readwrite) bool hidden;
@property(readwrite) bool forcedDisplay;
@property(readwrite) int qty;

- (void) display;

@end
