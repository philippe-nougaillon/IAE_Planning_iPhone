//
//  EventsViewController.m
//  IAE
//
//  Created by Philippe Nougaillon on 05/11/2013.
//  Copyright (c) 2013 Philippe Nougaillon. All rights reserved.
//

#import "EventsViewController.h"
#import "EventsCell.h"
#import "EventDetailsViewController.h"
#import "AppDelegate.h"
#import "Event.h"
#import "NSArray+arrayWithContentsOfJSONFile.h"
#import "NSString+stringWithDateUSContent.h"

@interface EventsViewController ()
@property (strong, nonatomic) IBOutlet UITableView *eventsTableView;
@property (nonatomic,strong)NSArray *jsonArray;
@property (nonatomic,strong)NSArray *fetchedRecordsArray;
@end

@implementation EventsViewController
@synthesize jsonArray = _jsonArray;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    //self.clearsSelectionOnViewWillAppear = NO;

    //NSLog(@"[Events]viewDidLoad");
    [self loadEventsData];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    //NSLog(@"[Events]viewDidAppear");

    // register to refresh UI when ApplicationDidBecomeActive
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(refreshEventsList)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
}

-(void)loadEventsData
{
    // load data from local items or stored items
    //
    
    //NSLog(@"[Events]LoadEventsData");
    
    // setup database context
    AppDelegate* appDelegate = [UIApplication sharedApplication].delegate;
    self.managedObjectContext = appDelegate.managedObjectContext;
    
    // check if database exist
    if ([appDelegate isDatabaseExist:@"Event"]) {
        
        //NSLog(@"[Events]LoadEventsData->Database exist");
        
        // refresh tableview with local data
        _fetchedRecordsArray = [self getAllEvents];
        [self.tableView reloadData];
        
    } else {
        
        //Start an activity indicator here
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        
        UIActivityIndicatorView *activityView =[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityView.center = self.view.center;
        [activityView startAnimating];
        [self.view addSubview:activityView];
        
        Reachability *reachability = [Reachability reachabilityWithHostName:@"google.com"];
        NetworkStatus remoteHostStatus = [reachability currentReachabilityStatus];
        
        // check if network is up
        if(remoteHostStatus != NotReachable) {
            
            // reload data from json and store items
            //NSLog(@"[Events]LoadEventsData->Database don't exist");
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                // get all items
                _fetchedRecordsArray = [self addAllRemoteEventsToLocalDatabase];

                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    // refresh tableview with local data
                    [self.tableView reloadData];
                    // hide activity monitor
                    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                    [activityView removeFromSuperview];

                });
            });
        } else {
            //NSLog(@"[Events]LoadEventsData->NOT Connected !");
            UIAlertView *alertView1 = [[UIAlertView alloc] initWithTitle:@"" message:@"Pas de connection" delegate:self cancelButtonTitle:nil otherButtonTitles:@"Ok", nil];
            alertView1.alertViewStyle = UIAlertViewStyleDefault;
            [alertView1 show];
        }
        // hide activity monitor
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    }
}

- (IBAction)refreshButtonPressed:(id)sender {
    
    [self refreshEventsList];
    
}

-(void)refreshEventsList {

    
    Reachability *reachability = [Reachability reachabilityWithHostName:@"google.com"];
    NetworkStatus remoteHostStatus = [reachability currentReachabilityStatus];
    
    // check if network is up
    if(remoteHostStatus != NotReachable) {
        
        //NSLog(@"[Events]refreshEventsListView");
        
        // remove notification
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        
        //Start an activity indicator here
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        
        //NSLog(@"[Events]refreshArticlesList");
        
        // Check if remote data are more recent
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            // Check if remote data are more recent
            BOOL refresh = [self refreshLocalData];
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                
                if (refresh) {
                    // refresh tableview with local data
                    _fetchedRecordsArray = [self getAllEvents];
                    [self.tableView reloadData];
                    //NSLog(@"[Events]refreshEventsList->tableView reloadData");
                    
                }
                // stop activity indicator
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                // register to refresh UI when ApplicationDidBecomeActive
                [[NSNotificationCenter defaultCenter]addObserver:self
                                                        selector:@selector(refreshEventsList)
                                                            name:UIApplicationDidBecomeActiveNotification
                                                          object:nil];
            });
        });
    }
    
}

-(BOOL)refreshLocalData {
    
    //
    // check if json is more recent than local items
    //
    BOOL refreshLocalData = NO;
    
    //NSLog(@"[Events]refreshLocalData");
    
    // read json remote source
    NSArray *jsonArray = [NSArray arrayWithContentsOfJSONFile:[@PRODSERVER stringByAppendingString:@"rest/evenements"]];
    
    //get first article nid
    NSDictionary *obj = [jsonArray firstObject];
    int remoteEventNid = [[obj objectForKey:@"nid"] intValue];
    
    // get last article in local storage
    Event *localFirstEvent = [_fetchedRecordsArray firstObject];
    int localNid = [localFirstEvent.nid intValue];
    
    // if remote is greater than local id
    if (remoteEventNid > localNid) {
    
        // add each new remote item
        for (int index=0; index < jsonArray.count; index++) {
            
            //get Article title and date
            NSDictionary *obj = [jsonArray objectAtIndex:index];
            int remoteNid = [[obj objectForKey:@"nid"] intValue];
            
            // if remote item id is lower then last item id, add it
            if (remoteNid > localNid) {
                //NSLog(@"[Events]refreshLocalData-> adding item id:%@", remoteEventNid);
                
                // save Item to database
                [self addEventToLocalDatabase:obj];
                
                refreshLocalData = YES;
            }
        }
    }
    return refreshLocalData;

}

-(NSArray*)addAllRemoteEventsToLocalDatabase {
    
    //NSLog(@"[Events]refreshLocalData-> store events data from json items");
    
    // read json remote source
    NSArray* jsonArray = [NSArray arrayWithContentsOfJSONFile:[@PRODSERVER stringByAppendingString:@"rest/evenements"]];
    NSMutableArray* temp = [NSMutableArray arrayWithCapacity:jsonArray.count];
        
    // for each array item
    for (int index=0; index < jsonArray.count; index++) {
        
        //get Article title and date
        NSDictionary *obj = [jsonArray objectAtIndex:index];
        
        // save Item to database
        Event* myEvent =[self addEventToLocalDatabase:obj];
        [temp addObject:myEvent];
    }
    
    return temp;
}

-(Event*)addEventToLocalDatabase:(NSDictionary*)obj {
    
    // save an item to database
    //
    //NSLog(@"[Events]addEventToLocalDatabase");
        
    NSString *titre = [obj objectForKey:@"titre"];
    NSString *nid = [obj objectForKey:@"nid"];
    NSString *soustitre = [obj objectForKey:@"chapo"];
    NSString *dateEvent = [[obj objectForKey:@"when"] objectAtIndex:0];
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy-MM-dd hh:mm:ss"];

    // Add Entry to Article Database
    Event *newEntry = [NSEntityDescription insertNewObjectForEntityForName:@"Event"
                                                      inManagedObjectContext:self.managedObjectContext];
    newEntry.title = titre;
    newEntry.nid = nid;
    newEntry.subtitle = soustitre;
    newEntry.when = [df dateFromString:dateEvent];
    newEntry.read =[NSNumber numberWithInt:0];
    
    NSError *error;
    if (![self.managedObjectContext save:&error]) {
        //NSLog(@"[Events]addEventToLocalDatabase->Whoops, couldn't new item save: %@", [error localizedDescription]);
    }
    
    return newEntry;
}

-(NSArray*)getAllEvents
{
    //NSLog(@"[Events]getAllEvents");
    
    // initializing NSFetchRequest
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    
    //Setting Entity to be Queried
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Event"
                                              inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc]
                                        initWithKey:@"when" ascending:YES];
    
    [fetchRequest setSortDescriptors:@[sortDescriptor]];
    
    // Query on managedObjectContext With Generated fetchRequest
    NSError* error;
    NSArray* fetchedRecords = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    // Returning Fetched Records
    return fetchedRecords;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return _fetchedRecordsArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"EventCell";
    EventsCell *cell = (EventsCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    // update cell with article content
    Event *event = [_fetchedRecordsArray objectAtIndex:indexPath.row];
    [cell.titleEvent setText:event.title];
    [cell.subTitleEvent setText:event.subtitle];
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setLocale:[NSLocale currentLocale]];
    [df setTimeStyle:NSDateFormatterFullStyle];
    [df setDateFormat:@"dd MMM"];
    [cell.dateEvent setText:[df stringFromDate:event.when]];

    // change title color if item already marked as read
    if ([event.read intValue] == 1)
        [cell.titleEvent setTextColor:[UIColor grayColor]];
    else
        [cell.titleEvent setTextColor:[UIColor colorWithRed:0/255.0 green:0/255.0 blue:128/255.0 alpha:1]];

    // show calendar if event was added to user calendar
    if ([event.addedToCalendar intValue] == 1) {
        [cell.eventIsIntoCalendar setHidden:NO];
        [cell.labelEventAddedToCalendar setHidden:NO];
    }
    
    return cell;
}

// This will get called too before the view appears
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"openEventDetails"]) {
        // get the index of select item
        EventsCell *cell = (EventsCell*)sender;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];

        // which article to open ?
        Event *event = [_fetchedRecordsArray objectAtIndex:indexPath.row];
        
        //mark event as read
        event.read = [NSNumber numberWithInt:1];
        [cell.titleEvent setTextColor:[UIColor grayColor]];
        
        // update the database
        NSError *error;
        if (![self.managedObjectContext save:&error]) {
            //NSLog(@"Whoops, couldn't save: %@", [error localizedDescription]);
        }
        
        // Get destination view
        EventDetailsViewController *vc = [segue destinationViewController];
        
        // Pass the information to your destination view
        vc.indexOfEvent = event.nid;
        vc.eventTitre = event.title;
        
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setLocale:[NSLocale currentLocale]];
        [df setDateFormat:@"dd MMM"];

        vc.eventDate = [df stringFromDate:event.when];
        vc.eventDateUS = event.when;
        vc.eventAddedToCalendar = event.addedToCalendar;
    }
}


@end
