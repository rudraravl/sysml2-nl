package ShackHartmannWavefrontSensingSystem {
    private import SI::m;
    private import SI::rad;
    private import SI::s;
    private import ScalarValues::Real;
    private import ScalarValues::Integer;
    private import ScalarValues::Boolean;

    item def LightBeam {
        attribute wavelength : Real [m];
        attribute beamDiameter : Real [m];
    }

    item def SpotPattern {
        attribute spotCount : Integer;
        attribute gridRows : Integer;
        attribute gridCols : Integer;
    }

    item def CCDImage {
        attribute pixelRows : Integer;
        attribute pixelCols : Integer;
        attribute exposureTime : Real [s];
        attribute spotPattern : SpotPattern;
    }

    item def ReferencePattern {
        attribute spotPattern : SpotPattern;
        attribute calibrated : Boolean;
    }

    item def SlopeData {
        attribute localTiltX : Real [rad];
        attribute localTiltY : Real [rad];
        attribute gridRows : Integer;
        attribute gridCols : Integer;
    }

    item def ZernikeCoefficients {
        attribute defocus : Real;
        attribute astigmatism : Real;
        attribute coma : Real;
        attribute spherical : Real;
    }

    item def WavefrontMap {
        attribute phaseMap : Real [rad];
        attribute zernike : ZernikeCoefficients;
        attribute resolution : Integer;
    }

    item def MeasurementCommand {
        attribute trigger : Boolean;
        attribute calibrationRequested : Boolean;
    }

    port def OpticalPort {
        out item beam : LightBeam;
    }

    port def ImagePort {
        out item image : CCDImage;
    }

    port def DataPort {
        out item map : WavefrontMap;
    }

    port def ControlPort {
        in item command : MeasurementCommand;
    }

    part def RelayOptics {
        port opticalIn : OpticalPort;
        port opticalOut : OpticalPort;
        attribute focalLength : Real [m];
        attribute magnification : Real;

        action def Condition {
            in item inputBeam : LightBeam;
            out item outputBeam : LightBeam;
        }
        action condition : Condition {
            in item inputBeam = opticalIn.beam;
            out item outputBeam;
        }
        flow from opticalIn.beam to condition.inputBeam;
        flow from condition.outputBeam to opticalOut.beam;
    }

    part def LensletArray {
        port opticalIn : OpticalPort;
        port opticalOut : OpticalPort;
        attribute lensletPitch : Real [m];
        attribute arrayRows : Integer;
        attribute arrayCols : Integer;
        attribute focalLength : Real [m];

        action def Subdivide {
            in item inputBeam : LightBeam;
            out item subBeams : LightBeam;
        }
        action subdivide : Subdivide {
            in item inputBeam = opticalIn.beam;
            out item subBeams;
        }
        flow from opticalIn.beam to subdivide.inputBeam;
        flow from subdivide.subBeams to opticalOut.beam;
    }

    part def CCDDetector {
        port opticalIn : OpticalPort;
        port imageOut : ImagePort;
        attribute pixelSize : Real [m];
        attribute pixelRows : Integer;
        attribute pixelCols : Integer;
        attribute quantumEfficiency : Real;

        action def Capture {
            in item light : LightBeam;
            out item image : CCDImage;
        }
        action capture : Capture {
            in item light = opticalIn.beam;
            out item image;
        }
        flow from opticalIn.beam to capture.light;
        flow from capture.image to imageOut.image;
    }

    part def WavefrontReconstructionProcessor {
        port imageIn : ImagePort;
        port dataOut : DataPort;
        port controlIn : ControlPort;
        attribute referencePattern : ReferencePattern;
        attribute slopeData : SlopeData;
        attribute wavefrontMap : WavefrontMap;
        attribute isCalibrated : Boolean;

        action def StoreReference {
            in item image : CCDImage;
            out item reference : ReferencePattern;
        }
        action def ComputeSlopes {
            in item image : CCDImage;
            in item reference : ReferencePattern;
            out item slopes : SlopeData;
        }
        action def Reconstruct {
            in item slopes : SlopeData;
            out item map : WavefrontMap;
        }
        action def OutputMap {
            in item map : WavefrontMap;
            out item outputMap : WavefrontMap;
        }

        action storeReference : StoreReference {
            in item image = imageIn.image;
            out item reference;
        }
        action computeSlopes : ComputeSlopes {
            in item image = imageIn.image;
            in item reference = referencePattern;
            out item slopes;
        }
        action reconstruct : Reconstruct {
            in item slopes = slopeData;
            out item map;
        }
        action outputMap : OutputMap {
            in item map = wavefrontMap;
            out item outputMap;
        }

        flow from imageIn.image to storeReference.image;
        flow from imageIn.image to computeSlopes.image;
        flow from computeSlopes.slopes to reconstruct.slopes;
        flow from reconstruct.map to outputMap.map;
        flow from outputMap.outputMap to dataOut.map;

        state def ProcessorStates {
            initial state initializing;
            state calibrating {
                entry action {
                    assign isCalibrated := false;
                }
                do storeReference;
            }
            state ready {
                entry action {
                    assign isCalibrated := true;
                }
            }
            state acquiring;
            state processing {
                do computeSlopes;
                do reconstruct;
            }
            state outputting {
                do outputMap;
            }
            state error {
                entry action {
                    assign isCalibrated := false;
                }
            }
            transition from initializing to calibrating;
            transition from calibrating to ready;
            transition from ready to acquiring;
            transition from acquiring to processing;
            transition from processing to outputting;
            transition from outputting to ready;
            transition from acquiring to error;
            transition from processing to error;
            transition from error to initializing;
        }

        state processorStateMachine : ProcessorStates;
    }

    part def ShackHartmannSensor {
        port opticalInput : OpticalPort;
        port dataOutput : DataPort;
        port commandInput : ControlPort;

        part relayOptics : RelayOptics;
        part lensletArray : LensletArray;
        part ccdDetector : CCDDetector;
        part processor : WavefrontReconstructionProcessor;

        connect opticalInput to relayOptics.opticalIn;
        connect relayOptics.opticalOut to lensletArray.opticalIn;
        connect lensletArray.opticalOut to ccdDetector.opticalIn;
        connect ccdDetector.imageOut to processor.imageIn;
        connect commandInput to processor.controlIn;
        connect processor.dataOut to dataOutput;

        state def SystemStates {
            initial state initializing;
            state calibrating;
            state ready;
            state measuring;
            state error;
            transition from initializing to calibrating;
            transition from calibrating to ready;
            transition from ready to measuring;
            transition from measuring to ready;
            transition from initializing to error;
            transition from calibrating to error;
            transition from ready to error;
            transition from measuring to error;
            transition from error to initializing;
        }

        state systemStateMachine : SystemStates;
    }

    requirement def SensorRequirements {
        requirement MeasureWavefront {
            doc "The system shall measure the shape and distortions of an incoming light wavefront.";
        }
        requirement ProduceWavefrontMap {
            doc "The system shall produce a high-resolution wavefront map from local slope measurements.";
        }
        requirement CalibrateWithReference {
            doc "The system shall calibrate using a flat reference wavefront and store the reference spot pattern.";
        }
        requirement DetectSpotDisplacement {
            doc "The system shall detect displacement of spots from the reference pattern to compute local wavefront slopes.";
        }
        requirement ExpressZernikeErrors {
            doc "The system shall express optical errors such as defocus, astigmatism, and coma in terms of Zernike polynomials.";
        }
        requirement HandleErrors {
            doc "The system shall enter an error state upon operational faults and return to initialization.";
        }
    }

    requirement sensorSpec : SensorRequirements {
        subject sensor : ShackHartmannSensor;
        satisfy MeasureWavefront by sensor.processor.reconstruct;
        satisfy ProduceWavefrontMap by sensor.processor.outputMap;
        satisfy CalibrateWithReference by sensor.processor.storeReference;
        satisfy DetectSpotDisplacement by sensor.processor.computeSlopes;
        satisfy ExpressZernikeErrors by sensor.processor.reconstruct;
        satisfy HandleErrors by sensor.systemStateMachine;
    }
}
