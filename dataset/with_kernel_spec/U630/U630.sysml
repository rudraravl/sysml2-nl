package RadianceInstrument {
    private import SI::*;
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def RadianceValue :> Real;
    attribute def UncertaintyValue :> Real;
    attribute def EfficiencyValue :> Real;

    item def Scene;
    item def Light;
    item def OpticalImage;
    item def RawSignal;
    item def CleanSignal;
    item def MeasurementResult {
        attribute radiance : RadianceValue;
        attribute timestamp : Real;
        attribute uncertainty : UncertaintyValue;
    }
    item def ControlCommand;
    item def CalibrateCommand :> ControlCommand;
    item def AcquireCommand :> ControlCommand;
    item def ResetCommand :> ControlCommand;
    item def FaultNotification;
    item def CalibrationDone;
    item def AcquisitionDone;
    item def ProcessingDone;

    part def CatadioptricSensor {
        attribute primaryDiameter : Real = 0.25 [m];
        in ref item scene : Scene;
        out item image : OpticalImage;

        part primaryMirror {
            in ref item scene : Scene = CatadioptricSensor::scene;
            out item reflectedLight : Light;
        }
        part secondaryMirror {
            in item incomingLight : Light;
            out item directedLight : Light;
        }
        part corrector {
            attribute numLenses : Integer = 4;
            in item incomingLight : Light;
            out item image : OpticalImage = CatadioptricSensor::image;
        }
        flow primaryMirror.reflectedLight to secondaryMirror.incomingLight;
        flow secondaryMirror.directedLight to corrector.incomingLight;
    }

    part def FocalPlaneArray {
        attribute pixelCount : Integer = 4096;
        attribute quantumEfficiency : EfficiencyValue = 0.9;
        attribute noiseLevel : Real = 0.001 [V];
        in item image : OpticalImage;
        out item rawSignal : RawSignal;
    }

    part def SignalConditioner {
        attribute gain : Real = 100.0;
        in item rawSignal : RawSignal;
        out item cleanSignal : CleanSignal;
    }

    part def DataProcessor {
        attribute calibrationCoefficients : Real[*];
        in item cleanSignal : CleanSignal;
        out item result : MeasurementResult;
    }

    port def OpticalInputPort {
        in item scene : Scene;
    }
    port def ControlPort {
        in item command : ControlCommand;
    }
    port def DataOutputPort {
        out item result : MeasurementResult;
    }

    part def OpticalInstrument {
        port opticalInput : OpticalInputPort;
        port controlPort : ControlPort;
        port dataPort : DataOutputPort;

        part catadioptricSensor : CatadioptricSensor;
        flow opticalInput.scene to catadioptricSensor.scene;

        part focalPlaneArray : FocalPlaneArray;
        flow catadioptricSensor.image to focalPlaneArray.image;

        part signalConditioner : SignalConditioner;
        flow focalPlaneArray.rawSignal to signalConditioner.rawSignal;

        part dataProcessor : DataProcessor;
        flow signalConditioner.cleanSignal to dataProcessor.cleanSignal;
        flow dataProcessor.result to dataPort.result;

        state def InstrumentLifecycle {
            then standby;
            state standby {
                accept CalibrateCommand via controlPort then calibrating;
                accept AcquireCommand via controlPort then acquiring;
            }
            state calibrating {
                accept CalibrationDone then standby;
                accept FaultNotification then fault;
            }
            state acquiring {
                accept AcquisitionDone then processing;
                accept FaultNotification then fault;
            }
            state processing {
                accept ProcessingDone then standby;
                accept FaultNotification then fault;
            }
            state fault {
                accept ResetCommand via controlPort then standby;
            }
        }

        state lifecycle : InstrumentLifecycle;
    }

    requirement def HighPrecisionMeasurement {
        doc /* The instrument shall measure radiance with high precision using a catadioptric optical assembly, focal plane array, signal conditioning, and onboard processing. */
    }
    requirement def OpticalAssemblyRequirement {
        doc /* The optical assembly shall combine a 250 mm primary mirror, secondary mirror, and multi-element refractive corrector. */
    }
    requirement def DetectorRequirement {
        doc /* The focal plane array shall have 4096 pixels with high quantum efficiency and low read noise. */
    }
    requirement def ProcessingRequirement {
        doc /* The onboard processor shall compute radiance value, timestamp, and uncertainty using calibration coefficients. */
    }
}
