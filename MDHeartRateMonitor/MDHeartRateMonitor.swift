//
//  MDHeartRateMonitor.swift
//  SwiftHeartRateMonitor
//
//  Created by James Jennings on 7/15/14.
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

import Foundation
import CoreBluetooth

//TODO: this should be part of the MDHeartRateMonitor class, causes error in hrmCallback line below
enum ConnectionStatus: Int, Printable {
    case Unknown = 0, Resetting, Unsupported, Unauthorized, PoweredOff, PoweredOn
    var description: String {
        switch (self) {
        case .Unknown:
            return "Unknown"
        case .Resetting:
            return "Resetting"
        case .Unsupported:
            return "Unsupported"
        case .Unauthorized:
            return "Unauthorized"
        case .PoweredOff:
            return "PoweredOff"
        case .PoweredOn:
            return "PoweredOn"
        }
    }
}

//TODO: these should be private class variables
private var hrmCallback:(MDHeartRateMonitor, ConnectionStatus)->() = {nothing in}
private var btManager:CBCentralManager? = nil //TODO: Assumption - we can only have one active HRM monitored at a time
private var dummyHRM:MDHeartRateMonitor? = nil

// Bluetooth assigned numbers for services and characteristics we're interested in querying
private let HeartRateServiceUUID = CBUUID.UUIDWithString("180D")
private let DeviceInformationServiceUUID = CBUUID.UUIDWithString("180A")
private let GenericAccessProfileUUID = CBUUID.UUIDWithString("1800")
private let HeartRateMeasurementCharacteristicUUID = CBUUID.UUIDWithString("2A37")
private let BodySensorLocationCharacteristicUUID = CBUUID.UUIDWithString("2A38")
private let HeartRateControlPointUUID = CBUUID.UUIDWithString("2A39")
private let DeviceNameCharacteristicUUID = CBUUID.UUIDWithString("2A00")
private let ManufacturerNameCharacteristicUUID = CBUUID.UUIDWithString("2A29")

@objc(MDHeartRateMonitor)
class MDHeartRateMonitor: NSObject, Printable, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    enum SensorLocation: Int, Printable {
        case Other = 0, Chest, Wrist, Finger, Hand, EarLobe, Foot // > 7 is "Reserved", using SensorLocation.fromRaw(x) will retrun nil
        
        var description: String {
            switch (self) {
            case .Other:
                return "Other"
            case .Chest:
                return "Chest"
            case .Wrist:
                return "Wrist"
            case .Finger:
                return "Finger"
            case .Hand:
                return "Hand"
            case .EarLobe:
                return "EarLobe"
            case .Foot:
                return "Foot"
            }
        }
    }
    
    var loggingEnabled = false
    var name:String?
    var manufacturerName:String? = nil
    var location:SensorLocation?
    var connectionState:ConnectionStatus
    
    override var description: String {
    return "Name: \(name), Sensor Location: \(location), Connection State: \(connectionState), Manufacturer Name: \(manufacturerName)\n"
    }
    
    private var peripheral: CBPeripheral?
    private var hrCallback:((Int)->())? = nil
    private var propertiesDiscoveredCallback:(()->())? = nil
    private var disconnectedCallback:((error:NSError?)->())? = nil
    
    init() {
        name = nil
        location = nil;
        connectionState = .Unknown;
        super.init()
        
        if !btManager {
            btManager = CBCentralManager(delegate: self, queue: nil)
        }
    }
    
    class func watchForHeartRateMonitors (callback:(MDHeartRateMonitor, ConnectionStatus)->()) {
        hrmCallback = callback;

        if !dummyHRM {
            dummyHRM = MDHeartRateMonitor()
        }
        
        btManager!.scanForPeripheralsWithServices([HeartRateServiceUUID], options: nil)
    }
    
    class func stopWatchingForHeartRateMonitors () {
        btManager!.stopScan()
    }
    
    func connect(propertiesDiscoveredCallback:()->(), disconnectedCallback:(error:NSError?)->()) {
        
        if(dummyHRM) {
            dummyHRM = nil
        }
        self.propertiesDiscoveredCallback = propertiesDiscoveredCallback
        self.disconnectedCallback = disconnectedCallback
        
        btManager!.delegate = self
        btManager!.connectPeripheral(self.peripheral!, options: nil)
    }
    
    func disconnect() {
        btManager!.cancelPeripheralConnection(peripheral)
        
    }
    
    func watchHeartRate (callback:((Int)->())) {
        self.hrCallback = callback
    }
    
    private func isLECapableHardware() -> Bool {
        
        var state = "";
        
        switch (btManager!.state)
            {
        case .Unsupported:
            state = "The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case .Unauthorized:
            state = "The app is not authorized to use Bluetooth Low Energy.";
            break;
        case .PoweredOff:
            state = "Bluetooth is currently powered off.";
            break;
        case .PoweredOn:
            return true;
        case .Unknown:
            return false
        default:
            return false
        }
        
        return false;
    }
    
    private func getIntFromHRMData (data:NSData)->UInt8 {
        var reportData = [UInt8](count:data.length, repeatedValue:0)
        data.getBytes(&reportData, length:data.length)
        var bpm:UInt8 = 0
        
        if (reportData[0] & 0x01) == 0 {
            bpm = reportData[1]
        } else {
            bpm = UInt8(CFSwapInt16LittleToHost(UInt16(reportData[1])))
        }
        
        return bpm
        
    }
    
    private func getLocationFromSensorData (data:NSData)->SensorLocation? {
        var reportData = [UInt8](count:data.length, repeatedValue:0)
        data.getBytes(&reportData, length:data.length)
        var rawLocation:UInt8 = 0
        rawLocation = reportData[0]
        print ("raw location:\(rawLocation)\n")
        
        return SensorLocation.fromRaw(Int(rawLocation));
    }
    
    
    //MARK: CBCentralManagerDelegate methods
    
    
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        self.connectionState = ConnectionStatus.fromRaw(central.state.toRaw())!
    }
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
        
        if loggingEnabled {println("detected peripheral: \(peripheral)")}
        var monitor = MDHeartRateMonitor()
        monitor.peripheral = peripheral
        monitor.name = peripheral.name
        hrmCallback(monitor, monitor.connectionState)
    }
    
    func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        
        if self.peripheral
        {
            self.peripheral!.delegate = nil
            self.peripheral = nil
        }
        
        if let reallyCallback = disconnectedCallback {
            reallyCallback(error:error)
        }
    }
    
    func centralManager(central: CBCentralManager!, didRetrievePeripherals peripherals: [AnyObject]!) {
    }
    
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        if loggingEnabled {println("connected to peripheral: \(peripheral)")}
        
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    func centralManager(central: CBCentralManager!, didFailToConnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        
        if let reallyCallback = disconnectedCallback {
            reallyCallback(error:error)
        }
    }
    
    
    //MARK: CBPeripheralDelegate methods
    
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        
        for aService in peripheral.services {
            if loggingEnabled {print("Full service details: \(aService)")}
            
            let cbService = aService as CBService
            /* Heart Rate Service */
            if aService.UUID == HeartRateServiceUUID {
                peripheral.discoverCharacteristics(nil, forService: cbService)
            }
            
            /* Device Information Service */
            if aService.UUID == DeviceInformationServiceUUID {
                peripheral.discoverCharacteristics(nil, forService: cbService)
            }
            
            /* GAP (Generic Access Profile) for Device Name */
            if aService.UUID == GenericAccessProfileUUID{
                peripheral.discoverCharacteristics(nil, forService: cbService)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        switch service.UUID {
        case HeartRateServiceUUID:
            for aChar in service.characteristics {
                if loggingEnabled {print("Full characteristic details: \(aChar)")}
                
                let cbChar = aChar as CBCharacteristic
                // Set notification on heart rate measurement
                if cbChar.UUID  == HeartRateMeasurementCharacteristicUUID {
                    peripheral.setNotifyValue(true, forCharacteristic: cbChar)
                    if loggingEnabled {print("Found a Heart Rate Measurement Characteristic")}
                }
                
                // Read body sensor location
                if cbChar.UUID  == BodySensorLocationCharacteristicUUID {
                    peripheral.readValueForCharacteristic(cbChar)
                    if loggingEnabled {print("Found a Body Sensor Location Characteristic")}
                }
                
                // Write heart rate control point
                if cbChar.UUID  == HeartRateControlPointUUID {
                    var val:UInt8 = 1;
                    var valData = NSData(bytes:&val, length: sizeofValue(val))
                    peripheral.writeValue(valData, forCharacteristic: cbChar, type:CBCharacteristicWriteType.WithResponse)
                }
            }
        case GenericAccessProfileUUID:
            for aChar in service.characteristics {
                let cbChar = aChar as CBCharacteristic
                
                if aChar.UUID == DeviceNameCharacteristicUUID {
                    peripheral.readValueForCharacteristic(cbChar)
                    if loggingEnabled {print("Found a Device Name Characteristic")}
                }
            }
            
        case DeviceInformationServiceUUID:
            for aChar in service.characteristics {
                let cbChar = aChar as CBCharacteristic
                
                if aChar.UUID == ManufacturerNameCharacteristicUUID {
                    peripheral.readValueForCharacteristic(cbChar)
                    if loggingEnabled {print("Found a Device Manufacturer Name Characteristic")}
                }
            }
            
        default:
            if loggingEnabled {print("Nothing to see here")}
        }
    
    }
    
    func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        
        if loggingEnabled {println("Value updated for characteristic: \(characteristic), with error \(error)")}
        
        switch (characteristic.UUID) {
        case HeartRateMeasurementCharacteristicUUID:
            var hr = self.getIntFromHRMData(characteristic.value)
            if let reallyCallback = hrCallback {
                reallyCallback(Int(hr))
            }
        case BodySensorLocationCharacteristicUUID:
            self.location = self.getLocationFromSensorData(characteristic.value)
        case DeviceNameCharacteristicUUID:
            self.name = NSString(data: characteristic.value, encoding: NSUTF8StringEncoding)
        case ManufacturerNameCharacteristicUUID:
            self.manufacturerName = NSString(data: characteristic.value, encoding: NSUTF8StringEncoding)
        default:
            break;
        }
        
        if let reallyCallback = propertiesDiscoveredCallback {
            reallyCallback()
        }
    }
}