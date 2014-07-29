//
//  ViewController.swift
//  SwiftHeartRateMonitor
//
//  Created by James Jennings on 7/10/14.
//  Copyright (c) 2014 Mobile Distortion
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import UIKit

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet var labelHeartRate: UILabel?
    @IBOutlet var tableDevices: UITableView?
    
    var detectedHRMs:[MDHeartRateMonitor] = []
    var selectedHRM:MDHeartRateMonitor?
        
    init(coder aDecoder: NSCoder!) {
        super.init(coder: aDecoder)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        MDHeartRateMonitor.watchForHeartRateMonitors {
            heartRateMonitor, connectionStatus in
            
            self.detectedHRMs.append(heartRateMonitor)
            self.tableDevices!.reloadData()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //
    // UITableView methods
    //
    
    func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell! {
        let thePeripheral = detectedHRMs[indexPath.row]
        
        var cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: nil);
        cell.textLabel.text = "Name: \(thePeripheral.name!)";
        
        return cell;
    }
    
    func numberOfSectionsInTableView(tableView: UITableView!) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        return detectedHRMs.count
    }
    
    func tableView(tableView: UITableView!, didSelectRowAtIndexPath indexPath: NSIndexPath!) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        let theHrm = detectedHRMs[indexPath.row]
        theHrm.loggingEnabled = true
        theHrm.connect({
                print ("New characteristic detected for device: \(theHrm)")
            },
            {e in
                print ("Disconnected, with potential error: \(e)")
            })
        
        theHrm.watchHeartRate {
            hr in
            self.labelHeartRate!.text = "\(hr)"
        }
        
        selectedHRM = theHrm
    }
}

