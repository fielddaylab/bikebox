//
//  AppModel.m
//  ARIS
//
//  Created by Ben Longoria on 2/17/09.
//  Copyright 2009 University of Wisconsin. All rights reserved.
//

#import "AppModel.h"
#import "ARISAppDelegate.h"
#import "Media.h"
#import "NodeOption.h"
#import "JSONConnection.h"
#import "JSONResult.h"
#import "JSON.h"
#import "ASIFormDataRequest.h"
#import "NearbyObjectProtocol.h"


static NSString *const nearbyLock = @"nearbyLock";
static NSString *const locationsLock = @"locationsLock";
static const int kDefaultCapacity = 10;
static const int kEmptyValue = -1;

@interface AppModel()

- (NSInteger) validIntForKey:(NSString *const)aKey inDictionary:(NSDictionary *const)aDictionary;
- (id) validObjectForKey:(NSString *const)aKey inDictionary:(NSDictionary *const)aDictionary;

@end


@implementation AppModel
@synthesize serverName, baseAppURL, jsonServerBaseURL, loggedIn;
@synthesize username, password, playerId, currentModule;
@synthesize site, gameId, gamePcMediaId, gameList, locationList, playerList;
@synthesize playerLocation, inventory, questList, networkAlert, mediaList;

@synthesize nearbyLocationsList;

#pragma mark Init/dealloc
-(id)init {
    if (self = [super init]) {
		//Init USerDefaults
		defaults = [NSUserDefaults standardUserDefaults];
		mediaList = [[NSMutableDictionary alloc] initWithCapacity:kDefaultCapacity];
	}
			 
    return self;
}

- (void)dealloc {
	[mediaList release];
	[gameList release];
	[baseAppURL release];
	[username release];
	[password release];
	[currentModule release];
	[site release];
    [super dealloc];
}


#pragma mark Communication with Server
- (BOOL)login {
	NSLog(@"AppModel: Login Requested");
	NSArray *arguments = [NSArray arrayWithObjects:self.username, self.password, nil];
	JSONConnection *jsonConnection = [[JSONConnection alloc] initWithArisJSONServer:jsonServerBaseURL 
																	andServiceName: @"players" 
																	andMethodName:@"login"
																	andArguments:arguments]; 

	JSONResult *jsonResult = [jsonConnection performSynchronousRequest];
	[jsonConnection release];
	
	if (!jsonResult) {
		self.loggedIn = NO;
		return NO;
	}
	
	//handle login response
	int returnCode = jsonResult.returnCode;
	NSLog(@"AppModel: Login Result Code: %d", returnCode);
	if(returnCode == 0) {
		self.loggedIn = YES;
		loggedIn = YES;
		playerId = [((NSDecimalNumber*)jsonResult.data) intValue];
	}
	else {
		self.loggedIn = NO;	
	}

	return self.loggedIn;
}

- (BOOL)registerNewUser:(NSString*)userName password:(NSString*)pass 
			  firstName:(NSString*)firstName lastName:(NSString*)lastName email:(NSString*)email {
	NSLog(@"AppModel: New User Registration Requested");
	//createPlayer($strNewUserName, $strPassword, $strFirstName, $strLastName, $strEmail)
	NSArray *arguments = [NSArray arrayWithObjects:userName, pass, firstName, lastName, email, nil];
	JSONConnection *jsonConnection = [[JSONConnection alloc] initWithArisJSONServer:jsonServerBaseURL 
																	 andServiceName: @"players" 
																	  andMethodName:@"createPlayer"
																	   andArguments:arguments]; 
	
	JSONResult *jsonResult = [jsonConnection performSynchronousRequest];
	[jsonConnection release];

	
	if (!jsonResult) {
		NSLog(@"AppModel registerNewUser: No result Data, return");
		return NO;
	}
	
    BOOL success;
	
	int returnCode = jsonResult.returnCode;
	if (returnCode == 0) {
		NSLog(@"AppModel: Result from new user request successfull");
		success = YES;
	}
	else { 
		NSLog(@"AppModel: Result from new user request unsuccessfull");
		success = NO;
	}
	return success;
	
}

- (void)updateServerNodeViewed: (int)nodeId {
	NSLog(@"Model: Node %d Viewed, update server", nodeId);
	
	//Call server service
	NSArray *arguments = [NSArray arrayWithObjects: [NSString stringWithFormat:@"%d",self.gameId],
						  [NSString stringWithFormat:@"%d",playerId],
						  [NSString stringWithFormat:@"%d",nodeId],
						  nil];
	JSONConnection *jsonConnection = [[JSONConnection alloc]initWithArisJSONServer:self.jsonServerBaseURL 
																	andServiceName:@"players" 
																	 andMethodName:@"nodeViewed" 
																	  andArguments:arguments];
	[jsonConnection performAsynchronousRequestWithParser:@selector(fetchAllLists)]; 
	[jsonConnection release];
}

- (void)updateServerItemViewed: (int)itemId {
	NSLog(@"Model: Item %d Viewed, update server", itemId);
	
	//Call server service
	NSArray *arguments = [NSArray arrayWithObjects:
						  [NSString stringWithFormat:@"%d",self.gameId],
						  [NSString stringWithFormat:@"%d",playerId],
						  [NSString stringWithFormat:@"%d",itemId],
						  nil];
	JSONConnection *jsonConnection = [[JSONConnection alloc]initWithArisJSONServer:self.jsonServerBaseURL 
																	andServiceName:@"players" 
																	 andMethodName:@"itemViewed" 
																	  andArguments:arguments];
	[jsonConnection performAsynchronousRequestWithParser:@selector(fetchAllLists)]; 
	[jsonConnection release];
}

- (void)updateServerNpcViewed: (int)npcId {
	NSLog(@"Model: Npc %d Viewed, update server", npcId);
	
	//Call server service
	NSArray *arguments = [NSArray arrayWithObjects: [NSString stringWithFormat:@"%d",self.gameId],
						  [NSString stringWithFormat:@"%d",playerId],
						  [NSString stringWithFormat:@"%d",npcId],
						  nil];
	JSONConnection *jsonConnection = [[JSONConnection alloc]initWithArisJSONServer:self.jsonServerBaseURL 
																	andServiceName:@"players" 
																	 andMethodName:@"npcViewed" 
																	  andArguments:arguments];
	[jsonConnection performAsynchronousRequestWithParser:@selector(fetchAllLists)]; 
	[jsonConnection release];
}


- (void)updateServerGameSelected{
	NSLog(@"Model: Game %d Selected, update server", gameId);
	
	//Call server service
	NSArray *arguments = [NSArray arrayWithObjects: 
						  [NSString stringWithFormat:@"%d",self.playerId],
						  [NSString stringWithFormat:@"%d",gameId],
						  nil];
	JSONConnection *jsonConnection = [[JSONConnection alloc]initWithArisJSONServer:self.jsonServerBaseURL 
																	andServiceName:@"players" 
																	 andMethodName:@"updatePlayerLastGame" 
																	  andArguments:arguments];
	[jsonConnection performAsynchronousRequestWithParser:nil]; 
	[jsonConnection release];

}

- (void)updateServerMapViewed{
	NSLog(@"Model: Map Viewed, update server");
	
	//Call server service
	NSArray *arguments = [NSArray arrayWithObjects:
						  [NSString stringWithFormat:@"%d",self.gameId],
						  [NSString stringWithFormat:@"%d",playerId],
						  nil];
	JSONConnection *jsonConnection = [[JSONConnection alloc]initWithArisJSONServer:self.jsonServerBaseURL 
																	andServiceName:@"players" 
																	 andMethodName:@"mapViewed" 
																	  andArguments:arguments];
	[jsonConnection performAsynchronousRequestWithParser:nil]; 
	[jsonConnection release];
}

- (void)updateServerQuestsViewed{
	NSLog(@"Model: Quests Viewed, update server");
	
	//Call server service
	NSArray *arguments = [NSArray arrayWithObjects:
						  [NSString stringWithFormat:@"%d",self.gameId],
						  [NSString stringWithFormat:@"%d",playerId],
						  nil];
	JSONConnection *jsonConnection = [[JSONConnection alloc]initWithArisJSONServer:self.jsonServerBaseURL 
																	andServiceName:@"players" 
																	 andMethodName:@"questsViewed" 
																	  andArguments:arguments];
	[jsonConnection performAsynchronousRequestWithParser:nil]; 
	[jsonConnection release];

}

- (void)updateServerInventoryViewed{
	NSLog(@"Model: Inventory Viewed, update server");
	
	//Call server service
	NSArray *arguments = [NSArray arrayWithObjects:
						  [NSString stringWithFormat:@"%d",self.gameId],
						  [NSString stringWithFormat:@"%d",playerId],
						  nil];
	JSONConnection *jsonConnection = [[JSONConnection alloc]initWithArisJSONServer:self.jsonServerBaseURL 
																	andServiceName:@"players" 
																	 andMethodName:@"inventoryViewed" 
																	  andArguments:arguments];
	[jsonConnection performAsynchronousRequestWithParser:nil]; 
	[jsonConnection release];

}

- (void)startOverGame{
	NSLog(@"Model: Start Over");
	
	//Call server service
	NSArray *arguments = [NSArray arrayWithObjects:
						  [NSString stringWithFormat:@"%d",self.gameId],
						  [NSString stringWithFormat:@"%d",playerId],
						  nil];
	JSONConnection *jsonConnection = [[JSONConnection alloc]initWithArisJSONServer:self.jsonServerBaseURL 
																	andServiceName:@"players" 
																	 andMethodName:@"startOverGameForPlayer" 
																	  andArguments:arguments];
	[jsonConnection performAsynchronousRequestWithParser:@selector(parseStartOverFromJSON:)]; 
	[jsonConnection release];

}


- (void)updateServerPickupItem: (int)itemId fromLocation: (int)locationId {
	NSLog(@"Model: Informing the Server the player picked up item");
	
	//Call server service
	NSArray *arguments = [NSArray arrayWithObjects: [NSString stringWithFormat:@"%d",self.gameId],
						  [NSString stringWithFormat:@"%d",playerId],
						  [NSString stringWithFormat:@"%d",itemId],
						  [NSString stringWithFormat:@"%d",locationId],
						  nil];
	JSONConnection *jsonConnection = [[JSONConnection alloc]initWithArisJSONServer:self.jsonServerBaseURL 
																	andServiceName:@"players" 
																	 andMethodName:@"pickupItemFromLocation" 
																	  andArguments:arguments];
	[jsonConnection performAsynchronousRequestWithParser:@selector(fetchAllLists)]; 
	[jsonConnection release];

}

- (void)updateServerDropItemHere: (int)itemId {
	NSLog(@"Model: Informing the Server the player dropped an item");
	
	//Call server service
	NSArray *arguments = [NSArray arrayWithObjects: [NSString stringWithFormat:@"%d",self.gameId],
						  [NSString stringWithFormat:@"%d",playerId],
						  [NSString stringWithFormat:@"%d",itemId],
						  [NSString stringWithFormat:@"%f",playerLocation.coordinate.latitude],
						  [NSString stringWithFormat:@"%f",playerLocation.coordinate.longitude],
						  nil];
	JSONConnection *jsonConnection = [[JSONConnection alloc]initWithArisJSONServer:self.jsonServerBaseURL 
																	andServiceName:@"players" 
																	 andMethodName:@"dropItem" 
																	  andArguments:arguments];
	[jsonConnection performAsynchronousRequestWithParser:@selector(fetchAllLists)]; 
	[jsonConnection release];

}

- (void)updateServerDestroyItem: (int)itemId {
	NSLog(@"Model: Informing the Server the player destroyed an item");
	
	//Call server service
	NSArray *arguments = [NSArray arrayWithObjects: [NSString stringWithFormat:@"%d",self.gameId],
						  [NSString stringWithFormat:@"%d",playerId],
						  [NSString stringWithFormat:@"%d",itemId],
						  nil];
	JSONConnection *jsonConnection = [[JSONConnection alloc]initWithArisJSONServer:self.jsonServerBaseURL 
																	andServiceName:@"players" 
																	 andMethodName:@"destroyItem" 
																	  andArguments:arguments];
	[jsonConnection performAsynchronousRequestWithParser:@selector(fetchAllLists)]; 
	[jsonConnection release];

}

- (void)createItemAndGiveToPlayerFromFileData:(NSData *)fileData fileName:(NSString *)fileName 
										title:(NSString *)title description:(NSString*)description {

	// setting up the request object now
	NSString *urlString = [NSString stringWithFormat:@"%@services/aris/uploadHandler.php",self.baseAppURL];
	NSURL *url = [NSURL URLWithString:urlString];
	ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
	request.timeOutSeconds = 60;
	
	NSString *gameID = [NSString stringWithFormat:@"%d", self.gameId];
 	[request setPostValue:gameID forKey:@"gameID"];	 
	[request setPostValue:fileName forKey:@"fileName"];
	[request setData:fileData forKey:@"file"];
	[request setPostValue:title forKey:@"title"];
	[request setPostValue:description forKey:@"description"];
	[request setDidFinishSelector:@selector(uploadItemRequestFinished:)];
	[request setDidFailSelector:@selector(uploadItemRequestFailed:)];
	[request setDelegate:self];
	
	NSLog(@"Model: Uploading File. gameID:%@ fileName:%@ title:%@ description:%@",gameID,fileName,title,description );
	
	ARISAppDelegate* appDelegate = (ARISAppDelegate *)[[UIApplication sharedApplication] delegate];
	[appDelegate showWaitingIndicator:@"Uploading" displayProgressBar:YES];
	[request setUploadProgressDelegate:appDelegate.waitingIndicator.progressView];
	[request startAsynchronous];
}

- (void)uploadItemRequestFinished:(ASIFormDataRequest *)request
{
	ARISAppDelegate* appDelegate = (ARISAppDelegate *)[[UIApplication sharedApplication] delegate];
	[appDelegate removeWaitingIndicator];
	
	NSString *response = [request responseString];

	NSLog(@"Model: Upload Media Request Finished. Response: %@", response);
	
	NSDictionary *postDict = request.postData;
	NSString *title = [postDict objectForKey:@"title"];
	NSString *description = [postDict objectForKey:@"description"];
	
	if (description == NULL) description = @""; 
	
	NSString *newFileName = [request responseString];

	NSLog(@"AppModel: Creating Item for Title:%@ Desc:%@ File:%@",title,description,newFileName);
	
	//Call server service
	NSArray *arguments = [NSArray arrayWithObjects:
						  [NSString stringWithFormat:@"%d",self.gameId],
						  [NSString stringWithFormat:@"%d",self.playerId],
						  [title stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding],
						  [description stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding],
						  newFileName,
						  @"1", //dropable
						  @"1", //destroyable
						  [NSString stringWithFormat:@"%f",playerLocation.coordinate.latitude],
						  [NSString stringWithFormat:@"%f",playerLocation.coordinate.longitude],
						  nil];
	JSONConnection *jsonConnection = [[JSONConnection alloc]initWithArisJSONServer:self.jsonServerBaseURL 
																	andServiceName:@"items" 
																	 andMethodName:@"createItemAndPlaceOnMap" 
																	  andArguments:arguments];
	[jsonConnection performAsynchronousRequestWithParser:@selector(fetchAllLists)]; 
	[jsonConnection release];

}

- (void)uploadItemRequestFailed:(ASIHTTPRequest *)request
{
	ARISAppDelegate* appDelegate = (ARISAppDelegate *)[[UIApplication sharedApplication] delegate];
	[appDelegate removeWaitingIndicator];
	NSError *error = [request error];
	NSLog(@"Model: uploadItemRequestFailed: %@",[error localizedDescription]);
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Upload Failed" message: @"An network error occured while uploading the file" delegate: self cancelButtonTitle: @"Ok" otherButtonTitles: nil];
	
	[alert show];
	[alert release];
}



- (void)updateServerLocationAndfetchNearbyLocationList {
	NSLog(@"Model: updating player position on server and determining nearby Locations");
	
	if (!loggedIn) {
		NSLog(@"Model: Player Not logged in yet, skip the location update");	
		return;
	}
	
	//init a fresh nearby location list array
	if(nearbyLocationsList != nil) {
		[nearbyLocationsList release];
	}
	nearbyLocationsList = [[NSMutableArray alloc] initWithCapacity:5];
	
	//Update the server with the new Player Location
	NSArray *arguments = [NSArray arrayWithObjects: [NSString stringWithFormat:@"%d",self.playerId],
						  [NSString stringWithFormat:@"%f",self.gameId],
						  [NSString stringWithFormat:@"%f",playerLocation.coordinate.latitude],
						  [NSString stringWithFormat:@"%f",playerLocation.coordinate.longitude],
						  nil];
	JSONConnection *jsonConnection = [[JSONConnection alloc] initWithArisJSONServer:self.jsonServerBaseURL 
																	 andServiceName:@"players" 
																	  andMethodName:@"updatePlayerLocation" 
																	   andArguments:arguments];
	[jsonConnection performAsynchronousRequestWithParser:nil]; 
	[jsonConnection release];

	
	//Rebuild nearbyLocationList
	//We could just do this in the getter
	NSEnumerator *locationsListEnumerator = [locationList objectEnumerator];
	Location *location;
	while (location = [locationsListEnumerator nextObject]) {
		//check if the location is close to the player
		if ([playerLocation getDistanceFrom:location.location] < location.error)
			[nearbyLocationsList addObject:location];
	}
	
	//Tell the rest of the app that the nearbyLocationList is fresh
	NSNotification *nearbyLocationListNotification = 
	[NSNotification notificationWithName:@"ReceivedNearbyLocationList" object:nearbyLocationsList];
	[[NSNotificationCenter defaultCenter] postNotification:nearbyLocationListNotification];
	
}

- (void) silenceNextServerUpdate {
	NSLog(@"AppModel: silenceNextServerUpdate");
	
	NSNotification *notification = [NSNotification notificationWithName:@"SilentNextUpdate" object:nil];
	[[NSNotificationCenter defaultCenter] postNotification:notification];
}

#pragma mark Sync Fetch selectors
- (id) fetchFromService:(NSString *)aService usingMethod:(NSString *)aMethod 
			   withArgs:(NSArray *)arguments usingParser:(SEL)aSelector 
{
	NSLog(@"JSON://%@/%@/%@", aService, aMethod, arguments);
	
	JSONConnection *jsonConnection = [[JSONConnection alloc]initWithArisJSONServer:self.jsonServerBaseURL 
																	andServiceName:aService
																	 andMethodName:aMethod
																	  andArguments:arguments];
	JSONResult *jsonResult = [jsonConnection performSynchronousRequest]; 
	[jsonConnection release];

	if (!jsonResult) {
		NSLog(@"\tFailed.");
		return nil;
	}
	
	return [self performSelector:aSelector withObject:jsonResult.data];
}


-(Item *)fetchItem:(int)itemId{
	NSLog(@"Model: Fetch Requested for Item %d", itemId);
	NSArray *arguments = [NSArray arrayWithObjects: [NSString stringWithFormat:@"%d",self.gameId],
						  [NSString stringWithFormat:@"%d",itemId],
						  nil];

	return [self fetchFromService:@"items" usingMethod:@"getItem" withArgs:arguments 
					  usingParser:@selector(parseItemFromDictionary:)];
}

-(Node *)fetchNode:(int)nodeId{
	NSLog(@"Model: Fetch Requested for Node %d", nodeId);
	NSArray *arguments = [NSArray arrayWithObjects: [NSString stringWithFormat:@"%d",self.gameId],
						  [NSString stringWithFormat:@"%d",nodeId],
						  nil];
	
	return [self fetchFromService:@"nodes" usingMethod:@"getNode" withArgs:arguments
					  usingParser:@selector(parseNodeFromDictionary:)];
}


- (void)fetchGameList {
	NSLog(@"AppModel: Fetching Game List.");
	
	self.gameList = [self fetchFromService:@"games" usingMethod:@"getGamesWithDetails"
						 withArgs:nil usingParser:@selector(parseGameListFromArray:)];
	
	//Tell everyone
	NSLog(@"AppModel: Finished Building the Game List");
	NSNotification *notification = [NSNotification notificationWithName:@"ReceivedGameList" object:self userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotification:notification];
}


-(Media *)mediaForMediaId: (int)mId {
	Media *media = [self.mediaList objectForKey:[NSNumber numberWithInt:mId]];
	
	if (!media) {
		//Let's pause everything and do a lookup
		NSLog(@"AppModel: Media not found in cached media List, refresh");
		[self fetchMediaList];
		
		media = [self.mediaList objectForKey:[NSNumber numberWithInt:mId]];
		if (media) NSLog(@"AppModel: Media found after refresh");
		else NSLog(@"AppModel: Media still NOT found after refresh");
	}
	return media;
}

- (void)fetchMediaList {
	NSLog(@"AppModel: Fetching Media List");
	
	NSArray *arguments = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%d",self.gameId], nil];
	
	self.mediaList = [self fetchFromService:@"media" usingMethod:@"getMedia"
								   withArgs:arguments usingParser:@selector(parseMediaListFromArray:)];
	
}


-(NSObject<QRCodeProtocol> *)fetchQRCode:(NSString*)code{
	NSLog(@"Model: Fetch Requested for QRCode Code: %@", code);
	
	//Call server service
	NSArray *arguments = [NSArray arrayWithObjects: [NSString stringWithFormat:@"%d",self.gameId],
						  [NSString stringWithFormat:@"%@",code],
						  [NSString stringWithFormat:@"%d",self.playerId],
						  nil];
	
	return [self fetchFromService:@"qrcodes" usingMethod:@"getQRCodeObjectForPlayer"
						 withArgs:arguments usingParser:@selector(parseQRCodeObjectFromDictionary:)];
	
}	

#pragma mark ASync Fetch selectors

- (void)fetchAllLists{
	[self fetchLocationList];
	[self fetchInventory];	
}


- (void)fetchLocationList {
	NSLog(@"AppModel: Fetching Locations from Server");	
	
	if (!loggedIn) {
		NSLog(@"AppModel: Player Not logged in yet, skip the location fetch");	
		return;
	}
			
	NSArray *arguments = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%d", self.gameId],
						  [NSString stringWithFormat:@"%d",self.playerId], 
						  nil];
	
	JSONConnection *jsonConnection = [[JSONConnection alloc]initWithArisJSONServer:self.jsonServerBaseURL 
																	andServiceName:@"locations"
																	 andMethodName:@"getLocationsForPlayer"
																	  andArguments:arguments];
	[jsonConnection performAsynchronousRequestWithParser:@selector(parseLocationListFromJSON:)]; 
	[jsonConnection release];
	
}

- (void)forceUpdateOnNextLocationListFetch {
	locationListHash = 0;
}

- (void)fetchInventory {
	NSLog(@"Model: Inventory Fetch Requested");
	
	NSArray *arguments = [NSArray arrayWithObjects: [NSString stringWithFormat:@"%d",self.gameId],
						  [NSString stringWithFormat:@"%d",self.playerId],
						  nil];
	
	JSONConnection *jsonConnection = [[JSONConnection alloc]initWithArisJSONServer:self.jsonServerBaseURL 
																	andServiceName:@"items"
																	 andMethodName:@"getItemsForPlayer"
																	  andArguments:arguments];
	[jsonConnection performAsynchronousRequestWithParser:@selector(parseInventoryFromJSON:)]; 
	[jsonConnection release];

}



#pragma mark Parsers
- (NSInteger) validIntForKey:(NSString *const)aKey inDictionary:(NSDictionary *const)aDictionary {
	id theObject = [aDictionary valueForKey:aKey];
	return [theObject respondsToSelector:@selector(intValue)]
		? [theObject intValue] : kEmptyValue;
}

- (id) validObjectForKey:(NSString *const)aKey inDictionary:(NSDictionary *const)aDictionary {
	id theObject = [aDictionary valueForKey:aKey];
	return theObject == [NSNull null] ? nil : theObject;
}

-(Item *)parseItemFromDictionary: (NSDictionary *)itemDictionary{	
	Item *item = [[[Item alloc] init] autorelease];
	item.itemId = [[itemDictionary valueForKey:@"item_id"] intValue];
	item.name = [itemDictionary valueForKey:@"name"];
	item.description = [itemDictionary valueForKey:@"description"];
	item.mediaId = [[itemDictionary valueForKey:@"media_id"] intValue];
	item.iconMediaId = [[itemDictionary valueForKey:@"icon_media_id"] intValue];
	item.dropable = [[itemDictionary valueForKey:@"dropable"] boolValue];
	item.destroyable = [[itemDictionary valueForKey:@"destroyable"] boolValue];
	NSLog(@"\tadded item %@", item.name);
	
	return item;	
}

-(Node *)parseNodeFromDictionary: (NSDictionary *)nodeDictionary{
	//Build the node
	NSLog(@"%@", nodeDictionary);
	Node *node = [[[Node alloc] init] autorelease];
	node.nodeId = [[nodeDictionary valueForKey:@"node_id"] intValue];
	node.name = [nodeDictionary valueForKey:@"title"];
	node.text = [nodeDictionary valueForKey:@"text"];
	NSLog(@"%@", [nodeDictionary valueForKey:@"media_id"]);
	node.mediaId = [self validIntForKey:@"media_id" inDictionary:nodeDictionary];
	node.answerString = [self validObjectForKey:@"require_answer_string" inDictionary:nodeDictionary];
	node.nodeIfCorrect = [self validIntForKey:@"require_answer_correct_node_id" inDictionary:nodeDictionary];
	node.nodeIfIncorrect = [self validIntForKey:@"require_answer_incorrect_node_id" inDictionary:nodeDictionary];
	
	//Add options here
	int optionNodeId;
	NSString *text;
	NodeOption *option;
	
	if ([nodeDictionary valueForKey:@"opt1_node_id"] != [NSNull null] && [[nodeDictionary valueForKey:@"opt1_node_id"] intValue] > 0) {
		optionNodeId= [[nodeDictionary valueForKey:@"opt1_node_id"] intValue];
		text = [nodeDictionary valueForKey:@"opt1_text"]; 
		option = [[NodeOption alloc] initWithText:text andNodeId: optionNodeId];
		[node addOption:option];
		[option release];
	}
	if ([nodeDictionary valueForKey:@"opt2_node_id"] != [NSNull null] && [[nodeDictionary valueForKey:@"opt2_node_id"] intValue] > 0) {
		optionNodeId = [[nodeDictionary valueForKey:@"opt2_node_id"] intValue];
		text = [nodeDictionary valueForKey:@"opt2_text"]; 
		option = [[NodeOption alloc] initWithText:text andNodeId: optionNodeId];
		[node addOption:option];
		[option release];
	}
	if ([nodeDictionary valueForKey:@"opt3_node_id"] != [NSNull null] && [[nodeDictionary valueForKey:@"opt3_node_id"] intValue] > 0) {
		optionNodeId = [[nodeDictionary valueForKey:@"opt3_node_id"] intValue];
		text = [nodeDictionary valueForKey:@"opt3_text"]; 
		option = [[NodeOption alloc] initWithText:text andNodeId: optionNodeId];
		[node addOption:option];
		[option release];

	}
	
	return node;	
}

-(NSArray *)parseGameListFromArray: (NSArray *)gameListArray{
	NSMutableArray *tempGameList = [[[NSMutableArray alloc] init] autorelease];
	
	NSEnumerator *gameListEnumerator = [gameListArray objectEnumerator];	
	NSDictionary *gameDictionary;
	while (gameDictionary = [gameListEnumerator nextObject]) {
		//create a new game
		Game *game = [[Game alloc] init];
	
		game.gameId = [[gameDictionary valueForKey:@"game_id"] intValue];
		NSLog(@"AppModel: Parsing Game: %d", game.gameId);		
		game.name = [gameDictionary valueForKey:@"name"];
		game.description = [gameDictionary valueForKey:@"description"];

		//parse out the trailing _ in the prefix
		NSString *prefix = [gameDictionary valueForKey:@"prefix"];
		game.site = [prefix substringToIndex:[prefix length] - 1];
		
		NSString *pc_media_id = [gameDictionary valueForKey:@"pc_media_id"];
		if (pc_media_id) game.pcMediaId = [pc_media_id intValue];
		else game.pcMediaId = 0;
		
		game.location = [[CLLocation alloc] initWithLatitude:[[gameDictionary valueForKey:@"latitude"] doubleValue]
												   longitude:[[gameDictionary valueForKey:@"longitude"] doubleValue]];
		
		
		game.authors = [gameDictionary valueForKey:@"editors"];
		game.numPlayers = [[gameDictionary valueForKey:@"numPlayers"] intValue];
		game.iconMediaId = [[gameDictionary valueForKey:@"icon_media_id"] intValue];
		
		
		NSLog(@"Model: Adding Game: %@", game.name);
		[tempGameList addObject:game]; 
		[game release];
	}

	
	return tempGameList;

}

-(void)parseLocationListFromJSON: (JSONResult *)jsonResult{

	NSLog(@"AppModel: Parsing Location List");
	
	//Check for an error
	//Compare this hash to the last one. If the same, stop hee

	if (jsonResult.hash == locationListHash) {
		NSLog(@"AppModel: Hash is same as last location list update, continue");
		return;
	}
	 
	//Save this hash for later comparisions
	locationListHash = jsonResult.hash;
	
	//Continue parsing
	NSArray *locationsArray = (NSArray *)jsonResult.data;
	
	
	//Build the location list
	NSMutableArray *tempLocationsList = [[NSMutableArray alloc] init];
	NSEnumerator *locationsEnumerator = [locationsArray objectEnumerator];	
	NSDictionary *locationDictionary;
	while (locationDictionary = [locationsEnumerator nextObject]) {
		//create a new location
		Location *location = [[Location alloc] init];
		location.locationId = [[locationDictionary valueForKey:@"location_id"] intValue];
		location.name = [locationDictionary valueForKey:@"name"];
		location.iconMediaId = [[locationDictionary valueForKey:@"icon_media_id"] intValue];
		location.location = [[CLLocation alloc] initWithLatitude:[[locationDictionary valueForKey:@"latitude"] doubleValue]
													   longitude:[[locationDictionary valueForKey:@"longitude"] doubleValue]];
		location.error = [[locationDictionary valueForKey:@"error"] doubleValue];
		location.objectType = [locationDictionary valueForKey:@"type"];
		location.objectId = [[locationDictionary valueForKey:@"type_id"] intValue];
		location.hidden = [[locationDictionary valueForKey:@"hidden"] boolValue];
		location.forcedDisplay = [[locationDictionary valueForKey:@"force_view"] boolValue];
		location.qty = [[locationDictionary valueForKey:@"item_qty"] intValue];
		
		NSLog(@"Model: Adding Location: %@", location.name);
		[tempLocationsList addObject:location];
		[location release];
	}
	
	if (self.locationList) [self.locationList release];
	self.locationList = tempLocationsList;
	[self.locationList retain];
	[tempLocationsList release];
	
	//Tell everyone
	NSLog(@"AppModel: Finished fetching locations from server, model updated");
	NSNotification *notification = 
	[NSNotification notificationWithName:@"ReceivedLocationList" object:nil];
	[[NSNotificationCenter defaultCenter] postNotification:notification];
	
	//Force a location update
	ARISAppDelegate *appDelegate = (ARISAppDelegate *) [[UIApplication sharedApplication] delegate];
	[appDelegate.myCLController.locationManager stopUpdatingLocation];
	[appDelegate.myCLController.locationManager startUpdatingLocation];
	
}


-(NSMutableDictionary *)parseMediaListFromArray: (NSArray *)mediaListArray{
	NSMutableDictionary *tempMediaList = [[[NSMutableDictionary alloc] init] autorelease];
	NSEnumerator *enumerator = [((NSArray *)mediaListArray) objectEnumerator];
	NSDictionary *dict;
	while (dict = [enumerator nextObject]) {
		NSInteger uid = [[dict valueForKey:@"media_id"] intValue];
		NSString *fileName = [dict valueForKey:@"file_name"];
		NSString *urlPath = [dict valueForKey:@"url_path"];

		NSString *type = [dict valueForKey:@"type"];
		
		if (uid < 1) {
			NSLog(@"AppModel fetchMediaList: Invalid media id: %d", uid);
			continue;
		}
		if ([fileName length] < 1) {
			NSLog(@"AppModel fetchMediaList: Empty fileName string for media #%d.", uid);
			continue;
		}
		if ([type length] < 1) {
			NSLog(@"AppModel fetchMediaList: Empty type for media #%d", uid);
            type = NearbyObjectItem;
			continue;
		}
		
		
		NSString *fullUrl = [NSString stringWithFormat:@"%@%@", urlPath, fileName];
		NSLog(@"AppModel fetchMediaList: Full URL: %@", fullUrl);
		
		Media *media = [[Media alloc] initWithId:uid andUrlString:fullUrl ofType:type];
		[tempMediaList setObject:media forKey:[NSNumber numberWithInt:uid]];
		[media release];
	}
	
	return tempMediaList;
}


-(void)parseInventoryFromJSON: (JSONResult *)jsonResult{
	NSLog(@"AppModel: Parsing Inventory");
	
	//Check for an error
	
	//Compare this hash to the last one. If the same, stop hee
	
	if (jsonResult.hash == inventoryHash) {
		NSLog(@"AppModel: Hash is same as last inventory listy update, continue");
		return;
	}

	
	//Save this hash for later comparisions
	inventoryHash = jsonResult.hash;
	
	//Continue parsing
	NSArray *inventoryArray = (NSArray *)jsonResult.data;
	
	NSMutableArray *tempInventory = [[NSMutableArray alloc] init];
	NSEnumerator *inventoryEnumerator = [((NSArray *)inventoryArray) objectEnumerator];	
	NSDictionary *itemDictionary;
	while (itemDictionary = [inventoryEnumerator nextObject]) {
		Item *item = [[Item alloc] init];
		item.itemId = [[itemDictionary valueForKey:@"item_id"] intValue];
		item.name = [itemDictionary valueForKey:@"name"];
		item.description = [itemDictionary valueForKey:@"description"];
		item.mediaId = [[itemDictionary valueForKey:@"media_id"] intValue];
		item.iconMediaId = [[itemDictionary valueForKey:@"icon_media_id"] intValue];
		item.dropable = [[itemDictionary valueForKey:@"dropable"] boolValue];
		item.destroyable = [[itemDictionary valueForKey:@"destroyable"] boolValue];
		NSLog(@"Model: Adding Item: %@", item.name);
		[tempInventory addObject:item]; 
		[item release];
	}

	self.inventory = tempInventory;
	
	NSLog(@"AppModel: Finished fetching inventory from server, model updated");
	NSNotification *notification = [NSNotification notificationWithName:@"ReceivedInventory" object:nil];
	[[NSNotificationCenter defaultCenter] postNotification:notification];
	
	//Note: The inventory list VC listener will add the badge now that it knows something is different
	
}


-(NSObject<QRCodeProtocol> *)parseQRCodeObjectFromDictionary: (NSDictionary *)qrCodeObjectDictionary {

	NSString *latitude = [qrCodeObjectDictionary valueForKey:@"latitude"];
	NSString *longitude = [qrCodeObjectDictionary valueForKey:@"longitude"];
	NSLog(@"AppModel-parseQRCodeObjectFromDictionary: Lat:%@ Lng:%@",latitude,longitude);

	CLLocation *location = [[CLLocation alloc] initWithLatitude:[latitude doubleValue]
												   longitude:[longitude doubleValue]];
	
	self.playerLocation = [location copy];
	[location release];
	//[appModel updateServerLocationAndfetchNearbyLocationList];
	
	NSString *type = [qrCodeObjectDictionary valueForKey:@"type"];
	NSLog(@"AppModel-parseQRCodeObjectFromDictionary: QRCode type is: %@",type);

	if ([type isEqualToString:@"Node"]) return [self parseNodeFromDictionary:qrCodeObjectDictionary];
	if ([type isEqualToString:@"Item"]) return [self parseItemFromDictionary:qrCodeObjectDictionary];

	return nil;
}


-(void)parseStartOverFromJSON:(JSONResult *)jsonResult{
	NSLog(@"AppModel: Parsing start over result and firing off fetches");
	[self fetchInventory];
	[self fetchLocationList];
}



@end
