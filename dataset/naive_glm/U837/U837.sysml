package PushBroomScanner {
    import ScalarValues::*;
    
    // Value Types
    type Length :> Real { unit "m"; }
    type Velocity :> Real { unit "m/s"; }
    type Time :> Real { unit "s"; }
    type DataRate :> Real { unit "Mbps"; }
    type Frequency :> Real { unit "Hz"; }
    type Power :> Real { unit "W"; }
    type Temperature :> Real { unit "K"; }
    
    // Items
    item def Light;
    item def RawSignal;
    item def ImageLine;
    item def SwathData;
    item def CalibrationData;
    item def PlatformTelemetry;
    
    // Ports
    port def LightInPort { in light : Light; }
    port def LightOutPort { out light : Light; }
    port def SignalInPort { in signal : RawSignal; }
    port def SignalOutPort { out signal : RawSignal; }
    port def DataInPort { in data : ImageLine; }
    port def DataOutPort { out data : ImageLine; }
    port def CalibInPort { in data : CalibrationData; }
    port def CalibOutPort { out data : CalibrationData; }
    port def TelemetryInPort { in data : PlatformTelemetry; }
    port def TelemetryOutPort { out data : PlatformTelemetry; }
    port def SwathOutPort { out data : SwathData; }
    
    // Parts
    part def OpticalAssembly {
        attribute focalLength : Length = 1000 [m];
        attribute aperture : Length = 0.5 [m];
        port lightIn : LightInPort;
        port lightOut : LightOutPort;
    }
    
    part def LinearDetectorArray {
        attribute numPixels : Integer = 10000;
        attribute pixelPitch : Length = 0.000007 [m];
        port lightIn : LightInPort;
        port signalOut : SignalOutPort;
    }
    
    part def CalibrationUnit {
        port calibOut : CalibOutPort;
    }
    
    part def SignalProcessingUnit {
        port signalIn : SignalInPort;
        port calibIn : CalibInPort;
        port telemetryIn : TelemetryInPort;
        port dataOut : DataOutPort;
    }
    
    part def DataStorageUnit {
        attribute bufferCapacity : Integer = 1000;
        port dataIn : DataInPort;
        port swathOut : SwathOutPort;
    }
    
    part def PlatformInterface {
        port telemetryOut : TelemetryOutPort;
    }
    
    // System
    part def PushBroomScannerSystem {
        attribute groundResolution : Length = 10 [m];
        attribute coverageWidth : Length = 100000 [m];
        
        part opticalAssembly : OpticalAssembly;
        part detectorArray : LinearDetectorArray;
        part signalProcessor : SignalProcessingUnit;
        part calibrationUnit : CalibrationUnit;
        part dataStorage : DataStorageUnit;
        part platformInterface : PlatformInterface;
        
        connect opticalAssembly.lightOut to detectorArray.lightIn;
        connect detectorArray.signalOut to signalProcessor.signalIn;
        connect calibrationUnit.calibOut to signalProcessor.calibIn;
        connect platformInterface.telemetryOut to signalProcessor.telemetryIn;
        connect signalProcessor.dataOut to dataStorage.dataIn;
        
        state machine behavior {
            state idle;
            state calibrating;
            state scanning;
            state storing;
            state fault;
            
            transition initial to idle;
            transition idle to calibrating accept triggerCalibration;
            transition calibrating to idle accept calibrationComplete;
            transition idle to scanning accept startScan;
            transition scanning to storing accept bufferFull;
            transition storing to scanning accept bufferCleared;
            transition scanning to idle accept stopScan;
            transition any to fault accept errorDetected;
            transition fault to idle accept reset;
        }
    }
    
    // Requirements
    requirement def GroundResolutionRequirement {
        subject scanner : PushBroomScannerSystem;
        requirement {
            constraint scanner.groundResolution <= 10 [m];
        }
    }
    
    requirement def CoverageWidthRequirement {
        subject scanner : PushBroomScannerSystem;
        requirement {
            constraint scanner.coverageWidth >= 100000 [m];
        }
    }
}
