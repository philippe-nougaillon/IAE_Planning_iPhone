//
//  FormationDetailsViewController.h
//  IAE
//
//  Created by admin on 06/01/2014.
//  Copyright (c) 2014 Philippe Nougaillon. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FormationDetailsViewController : UIViewController <UIWebViewDelegate>

@property (weak,nonatomic) NSString* link;
@property (weak,nonatomic) NSString* pdf;

@end
