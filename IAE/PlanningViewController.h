//
//  FirstViewController.h
//  IAE
//
//  Created by Philippe Nougaillon on 02/10/13.
//  Copyright (c) 2013 Philippe Nougaillon. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PlanningViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UITextFieldDelegate>
-(BOOL)loadData;
@end
