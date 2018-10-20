#include <CSWeather/CSWeatherInformationProvider.h>
#include "lockweather.h"

//TODO Change today to use the cases in descriptions
//TODO Fix Blur on lockscreen vs just pulling down notification center
//TODO Try to mimic apples way of dynamically changing text depending on time and weather conditions
//TODO Customization, move portion of view around
//TODO Scroll with notifications, hide during notifications etc
//TODO add dismiss button
//TODO make only appear during set times
//TODO Make sure to add the camera fix from nine to this tweak (thats casle problem)


NSBundle *tweakBundle = [NSBundle bundleWithPath:@"/Library/Application Support/lockWeather.bundle"];
//NSString *alertTitle = [tweakBundle localizedStringForKey:@"ALERT_TITLE" value:@"" table:nil];


// Data required for the isOnLockscreen() function --------------------------------------------------------------------------------------
BOOL isUILocked() {
    long count = [[[%c(SBFPasscodeLockTrackerForPreventLockAssertions) sharedInstance] valueForKey:@"_assertions"] count];
    if (count == 0) return YES; // array is empty
    if (count == 1) {
        if ([[[[[[%c(SBFPasscodeLockTrackerForPreventLockAssertions) sharedInstance] valueForKey:@"_assertions"] allObjects] objectAtIndex:0] identifier] isEqualToString:@"UI unlocked"]) return NO; // either device is unlocked or an app is opened (from the ones allowed on lockscreen). Luckily system gives us enough info so we can tell what happened
        else return YES; // if there are more than one should be safe enough to assume device is unlocked
    }
    else return NO;
}
 
static BOOL isOnCoverSheet; // the data that needs to be analyzed
 
BOOL isOnLockscreen() {
    //NSLog(@"nine_TWEAK | %d", isOnCoverSheet);
    if(isUILocked()){
        isOnCoverSheet = YES; // This is used to catch an exception where it was locked, but the isOnCoverSheet didnt update to reflect.
        return YES;
        }
        else if(!isUILocked() && isOnCoverSheet == YES) return YES;
        else if(!isUILocked() && isOnCoverSheet == NO) return NO;
        else return NO;
}
 
 static id _instance;
 
%hook SBFPasscodeLockTrackerForPreventLockAssertions
- (id) init {
    if (_instance == nil) _instance = %orig;
    else %orig; // just in case it needs more than one instance
    return _instance;
}
%new
 // add a shared instance so we can use it later
+ (id) sharedInstance {
    if (!_instance) return [[%c(SBFPasscodeLockTrackerForPreventLockAssertions) alloc] init];
    return _instance;
}
%end
 
 // Setting isOnCoverSheet properly, actually works perfectly
 %hook SBCoverSheetSlidingViewController
 - (void)_finishTransitionToPresented:(_Bool)arg1 animated:(_Bool)arg2 withCompletion:(id)arg3 {
     if((arg1 == 0) && ([self dismissalSlidingMode] == 1)){
         if(!isUILocked()) isOnCoverSheet = NO;
         } 
         else if ((arg1 == 1) && ([self dismissalSlidingMode] == 1)){
             if(isUILocked()) isOnCoverSheet = YES;
             }
             %orig;
    }
 %end
 // end of data required for the isOnLockscreen() function --------------------------------------------------------------------------------------


// weather data ------------------------------------------------------------------------------------------
WALockscreenWidgetViewController * weatherController(){
    WALockscreenWidgetViewController *weatherCont;
    weatherCont = [%c(WALockscreenWidgetViewController) sharedInstanceIfExists] ? [%c(WALockscreenWidgetViewController) sharedInstanceIfExists] : [[%c(WALockscreenWidgetViewController) alloc] init];
    [weatherCont updateWeather];
    return weatherCont;
}

int todayHigh(){
    return ((int)[((WADayForecast *)weatherController().currentForecastModel.dailyForecasts[0]).high temperatureForUnit:1]);
}

// This works, just not needed
/*
int todayLow(){
    return ((int)[((WADayForecast *)weatherController().currentForecastModel.dailyForecasts[0]).low temperatureForUnit:1]);
}
*/
NSString * todayCondition(){
    return weatherController().todayView.conditionsLine;
}
// end of weather data -------------------------------------------------------------------------


static BOOL numberOfNotifcations;

%hook SBDashBoardMainPageView
%property (nonatomic, retain) UIView *weather;
%property (nonatomic, retain) UIImageView *logo;
%property (nonatomic, retain) UILabel *greetingLabel;
%property (nonatomic, retain) UILabel *description;
%property (nonatomic, retain) UILabel *currentTemp;
%property (retain, nonatomic) UIVisualEffectView *blurView;
%property (retain, nonatomic) WALockscreenWidgetViewController *weatherCont;

- (void)layoutSubviews {
    %orig;
    //NSLog(@"lock_TWEAK | testing it before");
    //UIImage *icon;
    if(!self.weather){
        self.weather=[[UIView alloc]initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        [self.weather setBackgroundColor:[UIColor clearColor]];
        [self addSubview:self.weather];
        [self.weather setUserInteractionEnabled:NO];
        
        // setting up weatherCont
        if([%c(WALockscreenWidgetViewController) sharedInstanceIfExists]){
            self.weatherCont = [%c(WALockscreenWidgetViewController) sharedInstanceIfExists];
            [self.weatherCont updateWeather];
            [self.weather addSubview: self.weatherCont.view];
            self.weatherCont.view.frame = CGRectMake(0, self.frame.size.height/2.7, self.frame.size.width, self.frame.size.height/8.6);
        } else {
            self.weatherCont = [[%c(WALockscreenWidgetViewController) alloc] init];
            [self.weatherCont updateWeather];
            [self.weather addSubview: self.weatherCont.view];
            self.weatherCont.view.frame = CGRectMake(0, self.frame.size.height/2.7, self.frame.size.width, self.frame.size.height/8.6);
            
        }
    }
    
    
    if(!self.description){
        //CGRect screenRect = [[UIScreen mainScreen] bounds];
        //CGFloat screenWidth = screenRect.size.width;
        //CGFloat screenHeight = screenRect.size.height;
        
        self.description = [[UILabel alloc] initWithFrame:CGRectMake(0, self.frame.size.height/2.1, self.frame.size.width, self.frame.size.height/8.6)];
        
        self.description.textAlignment = NSTextAlignmentCenter;
        
        //self.currentTemp.font = [UIFont systemFontOfSize: 50 weight: UIFontWeightLight];//UIFont.systemFont(ofSize: 34, weight: UIFontWeightThin);//[UIFont UIFontWeightSemibold:50];
        self.description.textColor = [UIColor whiteColor];
        [self.weather addSubview: self.description];
        //[self.currentTemp sizeToFit];
    }
    if([prefs boolForKey:@"customFont"]){
        self.description.font = [UIFont fontWithName:[prefs stringForKey:@"availableFonts"] size:[prefs intForKey:@"descriptionSize"]];
    }else{
        self.description.font = [UIFont systemFontOfSize: [prefs intForKey:@"descriptionSize"] weight: UIFontWeightLight];
    }
    self.description.text = [NSString stringWithFormat:@"Today is %@ with a high of %i°", todayCondition(), todayHigh()];
    
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"HH"];
    dateFormat.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    NSDate *currentTime;
    currentTime = [NSDate date];
    //[dateFormat stringFromDate:currentTime];
    if(!self.greetingLabel){
        self.greetingLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, self.frame.size.height/2.5, self.frame.size.width, self.frame.size.height/8.6)];
        self.greetingLabel.textAlignment = NSTextAlignmentCenter;
        self.greetingLabel.textColor = [UIColor whiteColor];
        [self.weather addSubview:self.greetingLabel];
    }
    
    switch ([[dateFormat stringFromDate:currentTime] intValue]){
        case 0 ... 4:
            self.greetingLabel.text = [tweakBundle localizedStringForKey:@"Good_Evening" value:@"" table:nil];//NSLocalizedString(@"Good_Evening", @"Good Evening equivalent"); //@"Good Evening";
            break;
            
        case 5 ... 11:
            self.greetingLabel.text = [tweakBundle localizedStringForKey:@"Good_Morning" value:@"" table:nil];
            break;
            
        case 12 ... 17:
            self.greetingLabel.text = [tweakBundle localizedStringForKey:@"Good_Afternoon" value:@"" table:nil];
            break;
            
        case 18 ... 24:
            self.greetingLabel.text = [tweakBundle localizedStringForKey:@"Good_Evening" value:@"" table:nil];//NSLocalizedString(@"Good_Evening", @"Good Evening equivalent");//@"Good Evening";
            break;
    }
    if([prefs boolForKey:@"customFont"]){
        self.greetingLabel.font = [UIFont fontWithName:[prefs stringForKey:@"availableFonts"] size:[prefs intForKey:@"greetingSize"]];
    }else{
        self.greetingLabel.font = [UIFont systemFontOfSize:[prefs intForKey:@"greetingSize"] weight: UIFontWeightLight];
    }
    
    // old weather
    [[CSWeatherInformationProvider sharedProvider] updatedWeatherWithCompletion:^(NSDictionary *weather) {
         //NSLog(@"lock_TWEAK | on completion");
        //NSString *condition = weather[@"kCurrentFeelsLikefahrenheit"];
        //NSString *temp = weather[@"kCurrentTemperatureForLocale"];
        UIImage *icon = weather[@"kCurrentConditionImage_nc-variant"];
        
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        CGFloat screenHeight = screenRect.size.height;
        
        //NSLog(@"lock_TWEAK | testing it run");
        
        //CleanUp
        if(self.logo){
            [self.logo removeFromSuperview];
        }
        if(self.greetingLabel){
            [self.greetingLabel removeFromSuperview];
        }
        if(self.description){
            [self.description removeFromSuperview];
        }
        if(self.currentTemp){
            [self.currentTemp removeFromSuperview];
        }
        
        self.logo = [[UIImageView alloc] initWithFrame:CGRectMake(screenWidth/3.6, screenHeight/2.1, 100, 225)];
        self.logo.image = icon;
        self.logo.contentMode = UIViewContentModeScaleAspectFit;
        [self.weather addSubview:self.logo];
        //NSLog(@"YEET %@", self.logo);
        
        //Current Temperature Localized
        self.currentTemp = [[UILabel alloc] initWithFrame:CGRectMake(screenWidth/2.1, screenHeight/2.1, 100, 225)];
        if(weather[@"kCurrentTemperatureFahrenheit"] != nil){
            self.currentTemp.text = weather[@"kCurrentTemperatureForLocale"];
        }else{
            self.currentTemp.text = @"Error";
        }
        
        self.currentTemp.textAlignment = NSTextAlignmentCenter;
        if([prefs boolForKey:@"customFont"]){
            self.currentTemp.font = [UIFont fontWithName:[prefs stringForKey:@"availableFonts"] size:[prefs intForKey:@"tempSize"]];
        }else{
            self.currentTemp.font = [UIFont systemFontOfSize: [prefs intForKey:@"tempSize"] weight: UIFontWeightLight];
        }
        //self.currentTemp.font = [UIFont systemFontOfSize: 50 weight: UIFontWeightLight];//UIFont.systemFont(ofSize: 34, weight: UIFontWeightThin);//[UIFont UIFontWeightSemibold:50];
        self.currentTemp.textColor = [UIColor whiteColor];
        [self.weather addSubview: self.currentTemp];
        
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        [dateFormat setDateFormat:@"HH"];
        dateFormat.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        NSDate *currentTime;
        currentTime = [NSDate date];
        //[dateFormat stringFromDate:currentTime];
        
        self.greetingLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, self.frame.size.height/2.5, self.frame.size.width, self.frame.size.height/8.6)];
        
        switch ([[dateFormat stringFromDate:currentTime] intValue]){
            case 0 ... 4:
                self.greetingLabel.text = [tweakBundle localizedStringForKey:@"Good_Evening" value:@"" table:nil];//NSLocalizedString(@"Good_Evening", @"Good Evening equivalent"); //@"Good Evening";
                break;
                
            case 5 ... 11:
                self.greetingLabel.text = [tweakBundle localizedStringForKey:@"Good_Morning" value:@"" table:nil];
                break;
                
            case 12 ... 17:
                self.greetingLabel.text = [tweakBundle localizedStringForKey:@"Good_Afternoon" value:@"" table:nil];
                break;
                
            case 18 ... 24:
                self.greetingLabel.text = [tweakBundle localizedStringForKey:@"Good_Evening" value:@"" table:nil];//NSLocalizedString(@"Good_Evening", @"Good Evening equivalent");//@"Good Evening";
                break;
        }
        
        self.greetingLabel.textAlignment = NSTextAlignmentCenter;
        if([prefs boolForKey:@"customFont"]){
            self.greetingLabel.font = [UIFont fontWithName:[prefs stringForKey:@"availableFonts"] size:[prefs intForKey:@"greetingSize"]];
        }else{
            self.greetingLabel.font = [UIFont systemFontOfSize:[prefs intForKey:@"greetingSize"] weight: UIFontWeightLight];
        }
        ////[UIFont boldSystemFontOfSize:40];
        self.greetingLabel.textColor = [UIColor whiteColor];
        [self.weather addSubview:self.greetingLabel];
        
        //[[UILabel alloc] initWithFrame:CGRectMake(self.frame.size.width/21, self.frame.size.height/2, self.frame.size.width/1.1, self.frame.size.height/10)];
        
        self.description = [[UILabel alloc] initWithFrame:CGRectMake(self.frame.size.width/21, self.frame.size.height/2, self.frame.size.width/1.12, self.frame.size.height/2)];
        self.description.text = weather[@"kCurrentDescription"];
        self.description.textAlignment = NSTextAlignmentCenter;
        self.description.lineBreakMode = NSLineBreakByWordWrapping;
        self.description.numberOfLines = 0;
        self.description.textColor = [UIColor whiteColor];
        self.description.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.description setUserInteractionEnabled:NO];


        if([prefs boolForKey:@"customFont"]){
            self.description.font = [UIFont fontWithName:[prefs stringForKey:@"availableFonts"] size:[prefs intForKey:@"descriptionSize"]];
        }else{
            self.description.font = [UIFont systemFontOfSize:[prefs intForKey:@"descriptionSize"]];
        }
        //self.description.font = [UIFont systemFontOfSize:20];
        self.description.preferredMaxLayoutWidth = self.frame.size.width;
        [self.description sizeToFit];

        //CGPoint center = self.weather.center;
        //center.y = self.weather.frame.size.height / 1.85;
        //[self.description setCenter:center];


        [self.weather addSubview:self.description];
    }];
    
}

%end

// Checking content
%hook NCNotificationCombinedListViewController
-(BOOL)hasContent{
    BOOL content = %orig;
    if(content != numberOfNotifcations){
        // send a notification with user info for content. Dont forget to check ((!isOnLockscreen()) ? YES : self.isShowingNotificationsHistory)
        
    }
    // Sending values to the background controller
    //[[TCBackgroundViewController sharedInstance] updateSceenShot: content isRevealed: ((!isOnLockscreen()) ? YES : self.isShowingNotificationsHistory)]; // NC is never set to lock
    numberOfNotifcations = content;
    return content;
    
}
%end

//Blur 
%hook SBDashBoardViewController
%property (nonatomic, retain) UIVisualEffectView *notifEffectView;
%property (nonatomic, retain) UIVisualEffectView *blurEffectView;

-(void)loadView{
    %orig;
    
    //NSLog(@"lock_TWEAK | blur");
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithBlurRadius:[prefs intForKey:@"blurAmount"]];
    self.blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    //always fill the view
    self.blurEffectView.frame = self.view.bounds;
    self.blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    //[self.view addSubview:blurEffectView];
    //[self.view sendSubviewToBack: blurEffectView];
    [((SBDashBoardView *)self.view).backgroundView addSubview: self.blurEffectView];
    
    // Notification called when the lockscreen / nc is revealed (this is posted by the system)
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(enableOrDisableBlur:) 
        name:@"WALockscreenWidgetWillAppearNotification"
        object:nil];
}

%new 
-(void)enableOrDisableBlur:(NSNotification *) notification{
    if ([[notification name] isEqualToString:@"WALockscreenWidgetWillAppearNotification"]){
        self.blurEffectView.hidden = isOnLockscreen() ? NO : YES;
    }
}
%end 

%ctor{
    if([prefs boolForKey:@"kLWPEnabled"]){
        %init(_ungrouped);
    }
}
