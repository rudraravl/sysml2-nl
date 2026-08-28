package PushBroomScanner {
    private import ScalarValues::*;

    item def Light;
    item def FocusedLight;
    item def RawSignal;
    item def CorrectedLine;
    item def Swath;
    item def CalibrationData;
    item def PlatformTelemetry {
        attribute speed : Real;
        attribute altitude : Real;
    }

    attribute def StartCalibration;
    attribute def CalibrationComplete;
    attribute def BufferFull;
    attribute def StopScan;
    attribute def StorageComplete;
    attribute def FaultDetected;
    attribute def Reset;

    part def OpticalAssembly {
        in item incomingLight : Light;
        out item focusedLight : FocusedLight;
        attribute focalLength : Real;
    }

    part def LinearDetectorArray {
        in item focusedLight : FocusedLight;
        out item rawSignal : RawSignal;
        attribute pixelCount : Integer;
        attribute pixelPitch : Real;
    }

    part def CalibrationUnit {
        out item calibrationData : CalibrationData;
    }

    part def SignalProcessingUnit {
        in item rawSignal : RawSignal;
        in item calibrationData : CalibrationData;
        in item telemetry : PlatformTelemetry;
        out item correctedLine : CorrectedLine;
    }

    part def DataStorageUnit {
        in item correctedLine : CorrectedLine;
        out item swath : Swath;
        attribute bufferCapacity : Integer;
    }

    part def PlatformInterface {
        out item telemetry : PlatformTelemetry;
    }

    part def PushBroomScanner {
        attribute groundResolution : Real = 10.0;
        attribute coverageWidth : Real = 100.0;
    }

    action def PerformCalibration {
        out item calibrationData : CalibrationData;
    }
    action def CaptureLine {
        in item focusedLight : FocusedLight;
        out item rawSignal : RawSignal;
    }
    action def ProcessLine {
        in item rawSignal : RawSignal;
        in item calibrationData : CalibrationData;
        in item telemetry : PlatformTelemetry;
        out item correctedLine : CorrectedLine;
    }
    action def AccumulateLine {
        in item correctedLine : CorrectedLine;
    }
    action def FlushBuffer {
        out item swath : Swath;
    }

    state def ScannerStates {
        entry; then idle;
        state idle {
            accept StartCalibration then calibrating;
        }
        state calibrating {
            do action PerformCalibration;
            accept CalibrationComplete then scanning;
            accept FaultDetected then fault;
        }
        state scanning {
            do action CaptureLine;
            state capturing;
            state processing;
            state accumulating;
            transition first capturing then processing;
            transition first processing then accumulating;
            transition first accumulating then capturing;
            accept BufferFull then storing;
            accept StopScan then idle;
            accept FaultDetected then fault;
        }
        state storing {
            do action FlushBuffer;
            accept StorageComplete then scanning;
            accept FaultDetected then fault;
        }
        state fault {
            accept Reset then idle;
        }
    }

    part scanner : PushBroomScanner {
        ref item incomingLight : Light;
        part swaths : Swath[*];

        part opticalAssembly : OpticalAssembly {
            in item incomingLight : Light = scanner::incomingLight;
        }
        part detectorArray : LinearDetectorArray;
        part calibrationUnit : CalibrationUnit;
        part signalProcessor : SignalProcessingUnit;
        part dataStorage : DataStorageUnit {
            out item swath : Swath :> scanner::swaths;
        }
        part platformInterface : PlatformInterface;

        flow opticalAssembly.focusedLight to detectorArray.focusedLight;
        flow detectorArray.rawSignal to signalProcessor.rawSignal;
        flow calibrationUnit.calibrationData to signalProcessor.calibrationData;
        flow platformInterface.telemetry to signalProcessor.telemetry;
        flow signalProcessor.correctedLine to dataStorage.correctedLine;

        state scannerBehavior : ScannerStates;
    }

    requirement def ScannerRequirements {
        subject scanner : PushBroomScanner;
        requirement groundResolutionReq {
            doc /* The scanner shall achieve a ground resolution of 10 meters per pixel. */
            attribute value : Real = 10.0;
        }
        requirement coverageWidthReq {
            doc /* The scanner shall provide a coverage width of 100 kilometers. */
            attribute value : Real = 100.0;
        }
    }
}
