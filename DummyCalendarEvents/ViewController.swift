//
//  ViewController.swift
//  DummyCalendarEvents
//
//  Created by Stanley Rost on 14.08.15.
//  Copyright © 2015 soryu2. All rights reserved.
//

import UIKit
import EventKit

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    @IBOutlet weak var calendarPickerView: UIPickerView!
    @IBOutlet weak var startDatePickerView: UIDatePicker!
    @IBOutlet weak var intervalSlider: UISlider!
    @IBOutlet weak var intervalValueLabel: UILabel!
    @IBOutlet weak var minStartTimeSlider: UISlider!
    @IBOutlet weak var minStartTimeValueLabel: UILabel!
    @IBOutlet weak var maxStartTimeSlider: UISlider!
    @IBOutlet weak var maxStartTimeValueLabel: UILabel!
    @IBOutlet weak var durationSlider: UISlider!
    @IBOutlet weak var durationValueLabel: UILabel!
    @IBOutlet weak var allDayProbabilitySlider: UISlider!
    @IBOutlet weak var allDayProbabilityValueLabel: UILabel!
    
    let eventStore = EKEventStore()
    var calendars:Array<EKCalendar> = []
    
    var isWorking = false {
        didSet {
            navigationItem.rightBarButtonItem?.enabled = !isWorking
        }
    }
    
    // TODO: Other calendar types besides Gregorian
    let timeCalendar = NSCalendar.init(calendarIdentifier: NSCalendarIdentifierGregorian)!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem?.enabled = false
        
        switch EKEventStore.authorizationStatusForEntityType(.Event) {
        case .NotDetermined:
            eventStore .requestAccessToEntityType(.Event, completion: { (granted, error) -> Void in
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.setupView()
                })
            })
            
        case .Authorized:
            setupView()
            
        default:
            break
        }
        
        intervalSlider.value          = 60
        minStartTimeSlider.value      = 8 * 4
        maxStartTimeSlider.value      = 17 * 4
        durationSlider.value          = 3 * 4
        allDayProbabilitySlider.value = 0.1
        
        updateIntervalLabel()
        updateMinStartTimeLabel()
        updateMaxStartTimeLabel()
        updateDurationLabel()
        updateAllDayProbabilityLabel()
    }

    func setupView() {
        calendars = eventStore.calendarsForEntityType(.Event)
            .filter({ !$0.immutable })
            .sort({ $0.title < $1.title })
        
        navigationItem.rightBarButtonItem?.enabled = calendars.count > 0
        calendarPickerView.reloadAllComponents()
    }
    
    
    // MARK: Work
    
    func createDummyEventsInCalendar(eventCalendar:EKCalendar, fromDate:NSDate, interval:Int, minStartQuarterHour:Int, maxStartQuarterHour:Int, maxDuration:Int, allDayProbability:Float) throws -> Int {
        
        var numberOfEventsCreated = 0
        let titles = ["Meeting", "Party", "BBQ", "Pick up kids", "Cleaning", "Dinner", "Lunch", "Buy presents", "Dance", "Reminder", "Call X"]
        
        // sanity, cannot have finish before start
        let sanitizedMaxStartQuarterHour = max(maxStartQuarterHour, minStartQuarterHour)
        
        var numberOfLoops = Int(Double(interval) * 1.5)
        while numberOfLoops-- > 0 {
            // TODO: clean up casting when using arc4random_uniform? how?
            let title = titles[Int(arc4random_uniform(UInt32(titles.count)))]
            let day = Int(arc4random_uniform(UInt32(interval)))
            let startQuarterHour = minStartQuarterHour + Int(arc4random_uniform(UInt32(sanitizedMaxStartQuarterHour - minStartQuarterHour)))
            let durationInQuarterHours = 1 + Int(arc4random_uniform(UInt32(maxDuration)))
            let allDay = Float(arc4random_uniform(1000)) / 1000 < allDayProbability
            
            var startDate = timeCalendar.dateBySettingHour(0, minute:0, second:0, ofDate:fromDate, options:[])!
            startDate = timeCalendar.dateByAddingUnit(.Day, value:day, toDate:startDate, options:[])!
            
            if !allDay {
                startDate = timeCalendar.dateBySettingHour(startQuarterHour / 4, minute:(startQuarterHour % 4) * 15, second:0, ofDate:startDate, options:[])!
            }
            
            let components = NSDateComponents() // confusing to use let, I change it
            components.hour = durationInQuarterHours / 4;
            components.minute = (durationInQuarterHours % 4) * 15;
            let endDate = timeCalendar.dateByAddingComponents(components, toDate:startDate, options:[])!
            
            let event = EKEvent.init(eventStore: eventStore) // confusing to use let, I change it
            event.calendar  = eventCalendar;
            event.title     = title;
            event.startDate = startDate;
            event.endDate   = endDate;
            event.allDay    = allDay;
            
            do {
                try eventStore.saveEvent(event, span: .ThisEvent)
                numberOfEventsCreated++
            }
            catch let error as NSError {
                NSLog("%@", error)
            }
            
        }
        
        try eventStore.commit()
        
        return numberOfEventsCreated;
    }
    
    
    // MARK: Actions
    
    @IBAction func goButtonPressed(sender: AnyObject) {
        isWorking = true
        
        let calendarRow = calendarPickerView.selectedRowInComponent(0)
        let calendar = calendars[calendarRow]
        
        let startDate           = startDatePickerView.date;
        let interval            = Int(floor(intervalSlider.value))
        let minStartQuarterHour = Int(floor(minStartTimeSlider.value))
        let maxStartQuarterHour = Int(floor(maxStartTimeSlider.value))
        let duration            = Int(floor(durationSlider.value))
        let allDayProbability   = floor(allDayProbabilitySlider.value * 1000) / 1000
        
        // TODO: work on bg thread and show progress
        let benchmarkStartDate = NSDate()
        let message:String
        
        do {
            let numberOfEventsCreated:Int
            try numberOfEventsCreated = createDummyEventsInCalendar(calendar, fromDate: startDate, interval:interval,
                minStartQuarterHour: minStartQuarterHour, maxStartQuarterHour:maxStartQuarterHour, maxDuration:duration,
                allDayProbability:allDayProbability)

            message = NSString(format: "%zd events created in %.1f seconds", numberOfEventsCreated, NSDate().timeIntervalSinceDate(benchmarkStartDate)) as String

        } catch let error as NSError {
            message = error.localizedDescription
        }
        
        let alert = UIAlertController(title: "Done", message: message, preferredStyle: .Alert) // confusing to use let, I change it
        alert.addAction(UIAlertAction(title: "Dismiss", style: .Default, handler: nil))
        presentViewController(alert, animated: true, completion: nil)
        
        isWorking = false
    }
    
    @IBAction func intervalSliderChanged(sender: AnyObject) {
        updateIntervalLabel()
    }
    
    @IBAction func minStartTimeSliderChanged(sender: AnyObject) {
        updateMinStartTimeLabel()
    }

    @IBAction func maxStartTimeSliderChanged(sender: AnyObject) {
        updateMaxStartTimeLabel()
    }
    
    @IBAction func durationSliderChanged(sender: AnyObject) {
        updateDurationLabel()
    }
    
    @IBAction func allDayProbabilitySliderChanged(sender: AnyObject) {
        updateAllDayProbabilityLabel()
    }
    
    
    // MARK: UIPickerViewDataSource
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return max(calendars.count, 1)
    }
    
    
    // MARK: UIPickerViewDelegate
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if calendars.count == 0 {
            return "<No calendars>"
        }
        
        return calendars[row].title
    }

    
    // MARK: Helpers
    
    func dateFromQuarterHours(numberOfQuarterHours:NSInteger) -> NSDate {
        let date = NSDate.init(timeIntervalSinceReferenceDate: 0)
        return timeCalendar.dateBySettingHour(numberOfQuarterHours / 4, minute: (numberOfQuarterHours % 4) * 15, second: 0, ofDate: date, options: [])!
    }

    // TODO: dateFormatter should be a property
    func dateFormatter() -> NSDateFormatter {
        let formatter = NSDateFormatter() // confusing to use let, I change it
        formatter.dateFormat = NSDateFormatter.dateFormatFromTemplate("jjmm", options: 0, locale: timeCalendar.locale)
        return formatter
    }
    

    // MARK: UI/ViewModel
    
    func updateIntervalLabel() {
        let interval = floor(intervalSlider.value)
        intervalValueLabel.text = "\(interval)"
    }
    
    func updateMinStartTimeLabel() {
        let numberOfQuarterHours = Int(floor(minStartTimeSlider.value))
        let date = dateFromQuarterHours(numberOfQuarterHours)
        minStartTimeValueLabel.text = dateFormatter().stringFromDate(date)
    }
    
    func updateMaxStartTimeLabel() {
        let numberOfQuarterHours = Int(floor(maxStartTimeSlider.value))
        let date = dateFromQuarterHours(numberOfQuarterHours)
        maxStartTimeValueLabel.text = dateFormatter().stringFromDate(date)
    }
    
    func updateDurationLabel() {
        let numberOfQuarterHours = Int(floor(durationSlider.value))
        let components = NSDateComponents()
        components.hour = numberOfQuarterHours / 4
        components.minute = (numberOfQuarterHours % 4) * 15
    
        let formatter = NSDateComponentsFormatter()
        formatter.allowedUnits = [.Hour, .Minute]
        formatter.unitsStyle = .Full
    
        durationValueLabel.text = formatter.stringFromDateComponents(components)
    }
    
    func updateAllDayProbabilityLabel() {
        let value = floor(self.allDayProbabilitySlider.value * 1000) / 1000
        allDayProbabilityValueLabel.text = NSString(format:"%.1lf %%", value * 100) as String
    }

}

