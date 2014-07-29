# MDHeartRateMonitor
A class for connecting to and working with BLE heart rate monitors.  Abstracts away the details of working with Core Bluetooth. 

Writen in Swift, works in Swift and Objective-C, on iOS and OS X.

### Usage
	//Swift:
	
	MDHeartRateMonitor.watchForHeartRateMonitors {
            heartRateMonitor, connectionStatus in
            
            self.detectedHRMs.append(heartRateMonitor)
            // Update selection UI
        }
        
    ...
    
    let theHrm = detectedHRMs[selectedHRMIndex]
        
    theHrm.connect({
            // Inspect characteristics of HRM
        },
        {e in
            // Handle HRM error
        })
        
    theHrm.watchHeartRate {
        hr in
        self.labelHeartRate!.text = "\(hr)"
    }

### Project Status
In active development, builds with Xcode6-Beta4. Works, but not production-hardened.

Feedback and contributions welcomed, particularly regarding API design, Swift best practices, and BLE development.

Backlog:

* Mac OS X example project
* Unit Tests
* Test against more devices
* HRM simulator class (device advertises as central with HRM service)

Draws heavily from Apple's HeartRateMonitor example code.