package 'Indoor Positioning System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SignalStrength :> Real;
    
    item def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    
    item def BeaconIdentifier {
        attribute id : String;
    }
    
    item def DeviceIdentifier {
        attribute id : String;
    }
    
    attribute def Timestamp :> TimeValue;
    
    attribute def PositionAccuracy :> LengthValue;
    
    item def BeaconSignal {
        attribute beaconID : BeaconIdentifier;
        attribute transmitTime : Timestamp;
        attribute signalPower : PowerValue;
    }
    
    item def SignalMeasurement {
        attribute beaconID : BeaconIdentifier;
        attribute receivedStrength : SignalStrength;
        attribute receiveTime : Timestamp;
    }
    
    item def LocationEstimate {
        attribute deviceID : DeviceIdentifier;
        attribute position : Position3D;
        attribute accuracy : PositionAccuracy;
        attribute timestamp : Timestamp;
    }
    
    port def BeaconTransmitPort {
        out item signal : BeaconSignal;
    }
    
    port def DeviceReceivePort {
        in item measurement : SignalMeasurement;
    }
    
    port def LocationOutputPort {
        out item location : LocationEstimate;
    }
    
    port def PowerSupplyPort {
        in attribute voltage : ElectricPotentialValue;
        in attribute current : ElectricCurrentValue;
    }
    
    part def FixedBeacon {
        attribute beaconID : BeaconIdentifier;
        attribute knownPosition : Position3D;
        attribute transmitPower : PowerValue;
        attribute broadcastInterval : TimeValue;
        
        port powerIn : PowerSupplyPort;
        port signalOut : BeaconTransmitPort;
    }
    
    part def MobileDevice {
        attribute deviceID : DeviceIdentifier;
        
        port powerIn : PowerSupplyPort;
        port signalIn : DeviceReceivePort[*];
        port locationOut : LocationOutputPort;
        
        perform action collectSignals {
            out measurements : SignalMeasurement[*];
        }
    }
    
    part def LocalizationProcessor {
        perform action computeLocation {
            in measurements : SignalMeasurement[3..*];
            in beaconPositions : Position3D[3..*];
            out estimatedLocation : LocationEstimate;
            
            first start;
            then action validateMeasurements {
                in rawMeasurements = measurements;
                out validMeasurements : SignalMeasurement[3..*];
            }
            then action calculateDistances {
                in signalMeasurements = validateMeasurements.validMeasurements;
                out distances : LengthValue[3..*];
            }
            then action performTrilateration {
                in measuredDistances = calculateDistances.distances;
                in anchorPositions = beaconPositions;
                out computedPosition : Position3D;
                out computedAccuracy : PositionAccuracy;
            }
            then action generateEstimate {
                in position = performTrilateration.computedPosition;
                in accuracy = performTrilateration.computedAccuracy;
                out estimate : LocationEstimate;
            }
            then assign estimatedLocation := generateEstimate.estimate;
            then done;
        }
    }
    
    part def CentralCoordinator {
        attribute registeredBeacons : Position3D[*];
        attribute registeredDevices : DeviceIdentifier[*];
        
        port locationDataIn : LocationOutputPort[*];
        
        perform action manageLocations {
            in locationUpdates : LocationEstimate[*];
            
            loop {
                action receiveLocationUpdate {
                    in update : LocationEstimate;
                }
                then action validateLocation {
                    in locationData = receiveLocationUpdate.update;
                    out isValid : Boolean;
                }
                then decide;
                    if validateLocation.isValid then storeLocation;
                    if !validateLocation.isValid then rejectLocation;
                action storeLocation {
                    in validLocation = receiveLocationUpdate.update;
                }
                then merge continueProcessing;
                action rejectLocation;
                then continueProcessing;
            }
        }
    }
    
    requirement def AccuracyRequirement {
        doc /* The system shall determine device position with specified accuracy. */
        
        attribute requiredAccuracy : PositionAccuracy;
        
        require constraint accuracyConstraint {
            doc /* Computed position accuracy must meet or exceed required accuracy. */
        }
    }
    
    requirement def CoverageRequirement {
        doc /* The system shall provide positioning coverage throughout the indoor area. */
        
        attribute minimumBeaconCount : Integer;
        attribute coverageArea : AreaValue;
        
        require constraint coverageConstraint {
            doc /* Minimum number of beacons must be visible from any location. */
        }
    }
    
    requirement def UpdateRateRequirement {
        doc /* The system shall provide position updates at specified frequency. */
        
        attribute minimumUpdateRate : FrequencyValue;
        
        require constraint updateRateConstraint {
            doc /* Position updates must occur at or above minimum rate. */
        }
    }
    
    requirement <'IPS-REQ-001'> systemRequirements {
        doc /* The indoor positioning system shall provide continuous real-time location tracking of mobile devices within indoor environments. */
        
        require accuracyReq : AccuracyRequirement {
            attribute requiredAccuracy = 1.5;
        }
        
        require coverageReq : CoverageRequirement {
            attribute minimumBeaconCount = 3;
            attribute coverageArea = 500.0;
        }
        
        require updateRateReq : UpdateRateRequirement {
            attribute minimumUpdateRate = 1.0;
        }
    }
    
    part def IndoorPositioningSystem;
    
    part indoorPositioningSystem : IndoorPositioningSystem {
        doc /* 
            The indoor positioning system provides real-time location tracking of mobile devices
            within enclosed spaces where GPS signals are unavailable or unreliable.
            
            The system operates through continuous signal exchange and position calculation.
            Multiple fixed beacons at known locations broadcast identification signals at regular
            intervals. Mobile devices receive these signals and measure their strength and timing.
            A localization processor uses trilateration algorithms to calculate device position
            based on signal measurements and known beacon locations. The computed positions are
            reported to a central coordinator for tracking, storage, and distribution to
            applications requiring location information.
            
            This enables indoor navigation, asset tracking, personnel monitoring, proximity-based
            services, and emergency response in buildings, warehouses, hospitals, and other
            enclosed facilities.
        */
        
        part beacon1 : FixedBeacon {
            attribute beaconID : BeaconIdentifier {
                attribute id = "BEACON-A1";
            }
            attribute knownPosition : Position3D {
                attribute x = 0.0;
                attribute y = 0.0;
                attribute z = 2.5;
            }
            attribute transmitPower = 0.1;
            attribute broadcastInterval = 1.0;
        }
        
        part beacon2 : FixedBeacon {
            attribute beaconID : BeaconIdentifier {
                attribute id = "BEACON-A2";
            }
            attribute knownPosition : Position3D {
                attribute x = 20.0;
                attribute y = 0.0;
                attribute z = 2.5;
            }
            attribute transmitPower = 0.1;
            attribute broadcastInterval = 1.0;
        }
        
        part beacon3 : FixedBeacon {
            attribute beaconID : BeaconIdentifier {
                attribute id = "BEACON-A3";
            }
            attribute knownPosition : Position3D {
                attribute x = 20.0;
                attribute y = 15.0;
                attribute z = 2.5;
            }
            attribute transmitPower = 0.1;
            attribute broadcastInterval = 1.0;
        }
        
        part beacon4 : FixedBeacon {
            attribute beaconID : BeaconIdentifier {
                attribute id = "BEACON-A4";
            }
            attribute knownPosition : Position3D {
                attribute x = 0.0;
                attribute y = 15.0;
                attribute z = 2.5;
            }
            attribute transmitPower = 0.1;
            attribute broadcastInterval = 1.0;
        }
        
        part mobileDevice : MobileDevice {
            attribute deviceID : DeviceIdentifier {
                attribute id = "DEVICE-M001";
            }
            
            perform action trackLocation {
                first start;
                then loop {
                    action collectMeasurements : collectSignals {
                        out measurements : SignalMeasurement[*];
                    }
                    then action computePosition : LocalizationProcessor::computeLocation {
                        in measurements = collectMeasurements.measurements;
                        in beaconPositions : Position3D[*];
                        out estimatedLocation : LocationEstimate;
                    }
                    then action transmitLocation {
                        in locationData = computePosition.estimatedLocation;
                    }
                    then action waitForNextCycle {
                        in interval = 1.0;
                    }
                }
            }
        }
        
        part processor : LocalizationProcessor;
        
        part coordinator : CentralCoordinator {
            attribute registeredBeacons : Position3D[4];
            attribute registeredDevices : DeviceIdentifier[1];
        }
        
        connection beacon1ToDevice connect beacon1.signalOut to mobileDevice.signalIn;
        connection beacon2ToDevice connect beacon2.signalOut to mobileDevice.signalIn;
        connection beacon3ToDevice connect beacon3.signalOut to mobileDevice.signalIn;
        connection beacon4ToDevice connect beacon4.signalOut to mobileDevice.signalIn;
        
        connection deviceToCoordinator connect mobileDevice.locationOut to coordinator.locationDataIn;
        
        satisfy systemRequirements;
    }
    
    action def DetermineDeviceLocation {
        in beaconSignals : SignalMeasurement[3..*];
        in beaconLocations : Position3D[3..*];
        out deviceLocation : LocationEstimate;
        
        first start;
        then merge gatherMore;
        then action filterSignals {
            in allSignals = beaconSignals;
            out strongestSignals : SignalMeasurement[3..*];
        }
        then action estimateDistances {
            in signals = filterSignals.strongestSignals;
            out estimatedDistances : LengthValue[3..*];
        }
        then action trilaterateLocation {
            in distances = estimateDistances.estimatedDistances;
            in anchors = beaconLocations;
            out calculatedPosition : Position3D;
            out calculatedAccuracy : PositionAccuracy;
        }
        then action buildLocationEstimate {
            in position = trilaterateLocation.calculatedPosition;
            in accuracy = trilaterateLocation.calculatedAccuracy;
            out result : LocationEstimate;
        }
        then assign deviceLocation := buildLocationEstimate.result;
        then decide;
            if trilaterateLocation.calculatedAccuracy <= 1.5 then done;
            if trilaterateLocation.calculatedAccuracy > 1.5 then gatherMore;
    }
}
