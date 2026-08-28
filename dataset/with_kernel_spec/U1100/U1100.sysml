package IndoorPositioningSystem {
    private import ScalarValues::String;
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;

    item def BeaconSignal {
        attribute beaconID : String;
        attribute transmitPower : Real;
    }

    item def SignalMeasurement {
        attribute deviceID : String;
        attribute beaconID : String;
        attribute rssi : Real;
    }

    item def LocationEstimate {
        attribute deviceID : String;
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
        attribute accuracy : LengthValue;
    }

    item def BeaconRegistration {
        attribute beaconID : String;
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }

    item def DeviceRegistration {
        attribute deviceID : String;
    }

    port def BeaconBroadcastPort {
        out signal : BeaconSignal;
    }

    port def BeaconReceivePort {
        in signal : BeaconSignal;
    }

    port def MeasurementOutputPort {
        out measurement : SignalMeasurement;
    }

    port def MeasurementInputPort {
        in measurement : SignalMeasurement;
    }

    port def LocationOutputPort {
        out location : LocationEstimate;
    }

    port def LocationInputPort {
        in location : LocationEstimate;
    }

    port def ConfigOutputPort {
        out config : BeaconRegistration;
    }

    port def ConfigInputPort {
        in config : BeaconRegistration;
    }

    interface def BeaconInterface {
        end broadcaster : ~BeaconBroadcastPort;
        end receiver : BeaconReceivePort;
    }

    interface def MeasurementInterface {
        end source : ~MeasurementOutputPort;
        end target : MeasurementInputPort;
    }

    interface def LocationInterface {
        end source : ~LocationOutputPort;
        end target : LocationInputPort;
    }

    interface def ConfigInterface {
        end source : ~ConfigOutputPort;
        end target : ConfigInputPort;
    }

    action def CalculateDistance {
        in rssi : Real;
        in transmitPower : Real;
        in pathLossExponent : Real;
        out distance : LengthValue;
    }

    action def Trilateration {
        in distances : LengthValue[3];
        in beaconPositions : BeaconRegistration[3];
        out x : LengthValue;
        out y : LengthValue;
        out z : LengthValue;
        out accuracy : LengthValue;
    }

    part def FixedBeacon {
        attribute beaconID : String;
        attribute positionX : LengthValue;
        attribute positionY : LengthValue;
        attribute positionZ : LengthValue;
        attribute transmitPower : Real;
        port broadcastPort : BeaconBroadcastPort;

        perform action broadcastBehavior {
            action broadcast {
                out ref signal : BeaconSignal = new BeaconSignal(beaconID, transmitPower);
            }
        }

        flow signalFlow from broadcastBehavior.broadcast.signal to broadcastPort.signal;
    }

    part def MobileDevice {
        attribute deviceID : String;
        port receivePort : BeaconReceivePort;
        port measurementPort : MeasurementOutputPort;

        perform action deviceBehavior {
            action receiveSignal {
                in ref signal : BeaconSignal;
            }
            then action createMeasurement {
                in ref signal : BeaconSignal = receiveSignal.signal;
                out ref measurement : SignalMeasurement = new SignalMeasurement(deviceID, signal.beaconID, -50.0);
            }
            then action sendMeasurement {
                in ref measurement : SignalMeasurement = createMeasurement.measurement;
                out ref outMeasurement : SignalMeasurement = measurement;
            }
        }

        flow receiveFlow from receivePort.signal to deviceBehavior.receiveSignal.signal;
        flow sendFlow from deviceBehavior.sendMeasurement.outMeasurement to measurementPort.measurement;
    }

    part def LocalizationProcessor {
        port measurementInputPort : MeasurementInputPort;
        port locationOutputPort : LocationOutputPort;
        port configInputPort : ConfigInputPort;
        ref item beaconRegistry : BeaconRegistration[*];
        attribute pathLossExponent : Real;

        perform action processingBehavior {
            action receiveMeasurement {
                in ref measurement : SignalMeasurement;
            }
            then action calcDistance : CalculateDistance {
                in rssi = receiveMeasurement.measurement.rssi;
                in transmitPower = 0.0;
                in pathLossExponent = pathLossExponent;
                out distance;
            }
            then action trilaterate : Trilateration {
                in distances = (calcDistance.distance, calcDistance.distance, calcDistance.distance);
                in beaconPositions = (beaconRegistry[1], beaconRegistry[2], beaconRegistry[3]);
                out x;
                out y;
                out z;
                out accuracy;
            }
            then action sendLocation {
                in x : LengthValue = trilaterate.x;
                in y : LengthValue = trilaterate.y;
                in z : LengthValue = trilaterate.z;
                in accuracy : LengthValue = trilaterate.accuracy;
                out ref location : LocationEstimate = new LocationEstimate(receiveMeasurement.measurement.deviceID, x, y, z, accuracy);
            }
        }

        flow measurementFlow from measurementInputPort.measurement to processingBehavior.receiveMeasurement.measurement;
        flow locationFlow from processingBehavior.sendLocation.location to locationOutputPort.location;
    }

    part def CentralCoordinator {
        port locationInputPort : LocationInputPort;
        port configOutputPort : ConfigOutputPort;
        ref item beaconRegistry : BeaconRegistration[*];
        ref item deviceRegistry : DeviceRegistration[*];
        ref item locationHistory : LocationEstimate[*] := ( );

        perform action coordinatorBehavior {
            action receiveLocation {
                in ref location : LocationEstimate;
            }
            then action validateLocation {
                in ref location : LocationEstimate = receiveLocation.location;
                out isValid : Boolean;
            }
            then action storeLocation {
                in ref location : LocationEstimate = receiveLocation.location;
            }
            then assign locationHistory := locationHistory->including(receiveLocation.location);
        }

        perform action configureBeacons {
            action sendConfig {
                out ref config : BeaconRegistration;
            }
        }

        flow locationFlow from locationInputPort.location to coordinatorBehavior.receiveLocation.location;
        flow configFlow from configureBeacons.sendConfig.config to configOutputPort.config;
    }

    part def IndoorPositioningSystem {
        attribute coverageArea : AreaValue;
        attribute updateRate : FrequencyValue;

        part beacons : FixedBeacon[3..*];
        part devices : MobileDevice[1..*];
        part processor : LocalizationProcessor;
        part coordinator : CentralCoordinator;

        interface beaconLinks : BeaconInterface connect beacons.broadcastPort to devices.receivePort;
        interface measurementLinks : MeasurementInterface connect devices.measurementPort to processor.measurementInputPort;
        interface locationLinks : LocationInterface connect processor.locationOutputPort to coordinator.locationInputPort;
        interface configLinks : ConfigInterface connect coordinator.configOutputPort to processor.configInputPort;
    }

    requirement def PositioningAccuracyRequirement {
        doc /* The system shall determine a device's position with an accuracy of at least 1.5 meters. */
        attribute requiredAccuracy : LengthValue = 1.5 [m];
        subject positioningSystem : IndoorPositioningSystem;
        constraint { positioningSystem.processor.processingBehavior.trilaterate.accuracy <= requiredAccuracy }
    }

    requirement def CoverageAreaRequirement {
        doc /* The system shall provide positioning coverage over a minimum area of 500 square meters. */
        attribute requiredCoverage : AreaValue = 500 [m^2];
        subject positioningSystem : IndoorPositioningSystem;
        constraint { positioningSystem.coverageArea >= requiredCoverage }
    }

    requirement def UpdateRateRequirement {
        doc /* The system shall deliver location updates at least once per second. */
        attribute requiredUpdateRate : FrequencyValue = 1.0 [Hz];
        subject positioningSystem : IndoorPositioningSystem;
        constraint { positioningSystem.updateRate >= requiredUpdateRate }
    }

    part indoorPositioningSystemInstance : IndoorPositioningSystem {
        attribute coverageArea : AreaValue = 500 [m^2];
        attribute updateRate : FrequencyValue = 1.0 [Hz];
    }

    requirement positioningAccuracyReq : PositioningAccuracyRequirement;
    requirement coverageAreaReq : CoverageAreaRequirement;
    requirement updateRateReq : UpdateRateRequirement;

    satisfy positioningAccuracyReq by indoorPositioningSystemInstance;
    satisfy coverageAreaReq by indoorPositioningSystemInstance;
    satisfy updateRateReq by indoorPositioningSystemInstance;
}
