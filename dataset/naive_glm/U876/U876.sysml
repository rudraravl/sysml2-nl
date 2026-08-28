package ShackHartmannWavefrontSensor {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value type Wavelength :> Real { unit "nm"; }
    value type Phase :> Real { unit "rad"; }
    value type Slope :> Real { unit "rad/m"; }
    value type FocalLength :> LengthValue;
    value type PixelSize :> LengthValue;
    value type SpotDisplacement :> LengthValue;
    value type Intensity :> Real { unit "adu"; }
    value type ExposureTime :> DurationValue;
    value type ZernikeCoefficient :> Real { unit "µm"; }
    value type LensletPitch :> LengthValue;
    value type NumericalAperture :> Real;

    // ===== Item Definitions =====
    item def Wavefront {
        attribute wavelength : Wavelength;
        attribute phaseMap : Real[*, *] ; // phase values over aperture
        attribute isReference : Boolean;
    }

    item def LightBeam {
        attribute wavelength : Wavelength;
        attribute intensity : Intensity;
        attribute beamDiameter : LengthValue;
    }

    item def SpotPattern {
        attribute spotPositions : LengthValue[*, 2]; // x,y positions per lenslet
        attribute spotIntensities : Intensity[*];
        attribute timestamp : DateTime;
    }

    item def ReferencePattern :> SpotPattern {
        attribute calibrated : Boolean default false;
    }

    item def WavefrontMap {
        attribute slopeMap : Slope[*, 2]; // x and y slopes per subaperture
        attribute phaseMap : Phase[*, *];
        attribute zernikeCoefficients : ZernikeCoefficient[*];
        attribute zernikeModes : String[*]; // e.g., "defocus", "astigmatism", "coma"
        attribute rmsError : LengthValue;
        attribute peakToValley : LengthValue;
    }

    item def ImageFrame {
        attribute pixelData : Intensity[*, *];
        attribute exposureTime : ExposureTime;
        attribute timestamp : DateTime;
    }

    item def CalibrationParameters {
        attribute referenceSpotPattern : ReferencePattern;
        attribute lensletPitch : LensletPitch;
        attribute focalLength : FocalLength;
        attribute pixelSize : PixelSize;
    }

    item def DiagnosticReport {
        attribute status : String;
        attribute errorCode : Integer;
        attribute message : String;
    }

    // ===== Port Definitions =====
    port def OpticalPort {
        in item beam : LightBeam;
    }

    port def WavefrontInputPort {
        in item wavefront : Wavefront;
    }

    port def ImageOutputPort {
        out item frame : ImageFrame;
    }

    port def ImageInputPort {
        in item frame : ImageFrame;
    }

    port def SpotPatternPort {
        out item pattern : SpotPattern;
    }

    port def WavefrontMapPort {
        out item map : WavefrontMap;
    }

    port def CommandPort {
        in item command : String;
    }

    port def DiagnosticPort {
        out item report : DiagnosticReport;
    }

    // ===== Part Definitions =====

    part def RelayOptics {
        attribute focalLength : FocalLength = 100[mm];
        attribute apertureDiameter : LengthValue = 25[mm];
        attribute transmissionEfficiency : Real = 0.95;

        port opticalIn : OpticalPort;
        port opticalOut : OpticalPort;

        action def ConditionBeam :> Action {
            in item inputBeam : LightBeam;
            out item conditionedBeam : LightBeam;
        }

        action condition : ConditionBeam {
            in beam = opticalIn.beam;
            out conditionedBeam = opticalOut.beam;
        }
    }

    part def LensletArray {
        attribute pitch : LensletPitch = 150[µm];
        attribute focalLength : FocalLength = 5[mm];
        attribute gridRows : Integer = 32;
        attribute gridCols : Integer = 32;
        attribute numericalAperture : NumericalAperture = 0.015;

        port opticalIn : OpticalPort;
        port opticalOut : OpticalPort;

        action def SubdivideWavefront :> Action {
            in item inputBeam : LightBeam;
            out item subBeams : LightBeam[*];
        }

        action subdivide : SubdivideWavefront {
            in inputBeam = opticalIn.beam;
            out subBeams -> opticalOut.beam;
        }
    }

    part def CCDDetector {
        attribute pixelSize : PixelSize = 9[µm];
        attribute pixelRows : Integer = 1024;
        attribute pixelCols : Integer = 1024;
        attribute quantumEfficiency : Real = 0.85;
        attribute readNoise : Real = 5.0 { unit "e-"; }
        attribute dynamicRange : Real = 65535;
        attribute exposureTime : ExposureTime = 10[ms];
        attribute temperature : TemperatureValue = -20['°C'];

        port opticalIn : OpticalPort;
        port imageOut : ImageOutputPort;

        action def CaptureImage :> Action {
            in item incomingLight : LightBeam;
            in attribute exposure : ExposureTime;
            out item frame : ImageFrame;
        }

        action capture : CaptureImage {
            in incomingLight = opticalIn.beam;
            in exposure = exposureTime;
            out frame = imageOut.frame;
        }
    }

    part def WavefrontReconstructionProcessor {
        attribute calibrationParameters : CalibrationParameters;
        attribute maxIterations : Integer = 100;
        attribute convergenceThreshold : Real = 1e-6;
        attribute zernikeModes : String[*] = ("piston", "tip", "tilt", "defocus", "astigmatism", "coma", "spherical");

        port imageIn : ImageInputPort;
        port mapOut : WavefrontMapPort;
        port commandIn : CommandPort;
        port diagOut : DiagnosticPort;

        action def StoreReference :> Action {
            in item frame : ImageFrame;
            out item reference : ReferencePattern;
        }

        action def DetectSpots :> Action {
            in item frame : ImageFrame;
            in item reference : ReferencePattern;
            out item pattern : SpotPattern;
        }

        action def ComputeSlopes :> Action {
            in item pattern : SpotPattern;
            in item reference : ReferencePattern;
            in attribute pitch : LensletPitch;
            in attribute focalLength : FocalLength;
            out item slopes : Slope[*, 2];
        }

        action def ReconstructWavefront :> Action {
            in item slopes : Slope[*, 2];
            in attribute modes : String[*];
            out item map : WavefrontMap;
        }

        action def ComputeZernike :> Action {
            in item map : WavefrontMap;
            in attribute modes : String[*];
            out item updatedMap : WavefrontMap;
        }

        action storeReference : StoreReference;
        action detectSpots : DetectSpots;
        action computeSlopes : ComputeSlopes;
        action reconstruct : ReconstructWavefront;
        action computeZernike : ComputeZernike;

        flow storeReference.reference -> detectSpots.reference;
        flow detectSpots.pattern -> computeSlopes.pattern;
        flow storeReference.reference -> computeSlopes.reference;
        flow computeSlopes.slopes -> reconstruct.slopes;
        flow reconstruct.map -> computeZernike.map;
        flow computeZernike.updatedMap -> mapOut.map;
    }

    // ===== System Definition =====
    part def ShackHartmannSensorSystem {
        attribute systemId : String;
        attribute systemStatus : String;
        attribute operationalTemperature : TemperatureValue = 20['°C'];

        port wavefrontIn : WavefrontInputPort;
        port commandIn : CommandPort;
        port mapOut : WavefrontMapPort;
        port diagOut : DiagnosticPort;

        part relayOptics : RelayOptics {
            attribute focalLength = 100[mm];
        }

        part lensletArray : LensletArray {
            attribute pitch = 150[µm];
            attribute focalLength = 5[mm];
            attribute gridRows = 32;
            attribute gridCols = 32;
        }

        part ccdDetector : CCDDetector {
            attribute pixelSize = 9[µm];
            attribute pixelRows = 1024;
            attribute pixelCols = 1024;
            attribute exposureTime = 10[ms];
        }

        part processor : WavefrontReconstructionProcessor {
            attribute maxIterations = 100;
        }

        // Internal connections
        connection opticalLink1 connect relayOptics.opticalOut to lensletArray.opticalIn {
            item beam : LightBeam;
        }

        connection opticalLink2 connect lensletArray.opticalOut to ccdDetector.opticalIn {
            item beam : LightBeam;
        }

        connection imageLink connect ccdDetector.imageOut to processor.imageIn {
            item frame : ImageFrame;
        }

        connection commandLink connect commandIn to processor.commandIn {
            item command : String;
        }

        connection mapLink connect processor.mapOut to mapOut {
            item map : WavefrontMap;
        }

        connection diagLink connect processor.diagOut to diagOut {
            item report : DiagnosticReport;
        }

        // ===== State Machine =====
        state def SensorStateMachine {
            entry action {
                SysML::Helpers::log("System initializing");
            }

            state Initializing {
                entry action {
                    SysML::Helpers::log("Initializing subsystems");
                    relayOptics.condition();
                }
                transition Initializing to Calibrating
                    when (commandIn.command == "calibrate");
            }

            state Calibrating {
                entry action {
                    SysML::Helpers::log("Calibration mode: capturing reference wavefront");
                    ccdDetector.capture();
                    processor.storeReference();
                }
                transition Calibrating to Ready
                    when (processor.calibrationParameters.referenceSpotPattern.calibrated == true);
                transition Calibrating to ErrorState
                    when (processor.diagOut.report.errorCode != 0);
            }

            state Ready {
                entry action {
                    SysML::Helpers::log("System ready, awaiting trigger");
                }
                transition Ready to Acquiring
                    when (commandIn.command == "measure");
                transition Ready to ErrorState
                    when (processor.diagOut.report.errorCode != 0);
            }

            state Acquiring {
                entry action {
                    SysML::Helpers::log("Acquiring image from CCD");
                    ccdDetector.capture();
                }
                transition Acquiring to Processing
                    when (ccdDetector.imageOut.frame != null);
                transition Acquiring to ErrorState
                    when (processor.diagOut.report.errorCode != 0);
            }

            state Processing {
                entry action {
                    SysML::Helpers::log("Processing: detecting spots, computing slopes, reconstructing wavefront");
                    processor.detectSpots();
                    processor.computeSlopes();
                    processor.reconstruct();
                    processor.computeZernike();
                }
                transition Processing to Outputting
                    when (processor.mapOut.map != null);
                transition Processing to ErrorState
                    when (processor.diagOut.report.errorCode != 0);
            }

            state Outputting {
                entry action {
                    SysML::Helpers::log("Outputting wavefront map");
                }
                transition Outputting to Ready
                    when (mapOut.map != null);
            }

            state ErrorState {
                entry action {
                    SysML::Helpers::log("Error state: operational fault detected");
                }
                transition ErrorState to Initializing
                    when (commandIn.command == "reset");
            }

            transition initial to Initializing;
        }

        part stateMachine : SensorStateMachine;

        // ===== Requirements =====
        requirement def ShallMeasureWavefront {
            doc /* The system shall measure the shape and phase distortions of an incoming light wavefront. */
            subject sensor : ShackHartmannSensorSystem;
            objective {
                doc /* Produce a high-resolution wavefront map from an incoming beam. */
            }
        }

        requirement def ShallCalibrateWithReference {
            doc /* The system shall be calibrated using a known reference wavefront to establish a reference spot pattern. */
            subject sensor : ShackHartmannSensorSystem;
            objective {
                doc /* Store a reference pattern of perfectly spaced spots in the processor. */
            }
        }

        requirement def ShallDetectSpotDisplacements {
            doc /* The system shall detect spot displacements on the CCD relative to the reference pattern. */
            subject sensor : ShackHartmannSensorSystem;
            objective {
                doc /* Measure displacement of each spot to determine local wavefront slope. */
            }
        }

        requirement def ShallReconstructWavefront {
            doc /* The system shall reconstruct the wavefront shape by integrating local slope measurements. */
            subject sensor : ShackHartmannSensorSystem;
            objective {
                doc /* Produce a phase map and Zernike polynomial coefficients. */
            }
        }

        requirement def ShallQuantifyOpticalErrors {
            doc /* The system shall quantify optical errors such as defocus, astigmatism, and coma. */
            subject sensor : ShackHartmannSensorSystem;
            objective {
                doc /* Express errors as Zernike polynomial coefficients in micrometers. */
            }
        }

        requirement def ShallHandleErrors {
            doc /* The system shall enter an error state upon detecting operational faults and allow reset. */
            subject sensor : ShackHartmannSensorSystem;
            objective {
                doc /* Report diagnostic information and transition to Initializing on reset command. */
            }
        }

        requirement def ShallMeetMeasurementPrecision {
            doc /* The system shall achieve wavefront measurement precision better than λ/50 RMS. */
            subject sensor : ShackHartmannSensorSystem;
            attribute maxRmsError : LengthValue = 13[nm]; // assuming λ=633nm
            objective {
                doc /* RMS wavefront error shall not exceed maxRmsError. */
            }
        }

        requirement measureWavefrontReq : ShallMeasureWavefront {
            subject sensor = ShackHartmannSensorSystem::this;
        }

        requirement calibrateReq : ShallCalibrateWithReference {
            subject sensor = ShackHartmannSensorSystem::this;
        }

        requirement detectDisplacementsReq : ShallDetectSpotDisplacements {
            subject sensor = ShackHartmannSensorSystem::this;
        }

        requirement reconstructReq : ShallReconstructWavefront {
            subject sensor = ShackHartmannSensorSystem::this;
        }

        requirement quantifyErrorsReq : ShallQuantifyOpticalErrors {
            subject sensor = ShackHartmannSensorSystem::this;
        }

        requirement handleErrorsReq : ShallHandleErrors {
            subject sensor = ShackHartmannSensorSystem::this;
        }

        requirement precisionReq : ShallMeetMeasurementPrecision {
            subject sensor = ShackHartmannSensorSystem::this;
        }

        // Requirement satisfaction
        satisfy measureWavefrontReq by relayOptics;
        satisfy measureWavefrontReq by lensletArray;
        satisfy measureWavefrontReq by ccdDetector;
        satisfy measureWavefrontReq by processor;
        satisfy calibrateReq by processor;
        satisfy detectDisplacementsReq by processor;
        satisfy reconstructReq by processor;
        satisfy quantifyErrorsReq by processor;
        satisfy handleErrorsReq by stateMachine;
        satisfy precisionReq by ccdDetector;
        satisfy precisionReq by lensletArray;
    }

    // ===== Example Usage =====
    part def WavefrontSensorTestRig {
        part sensor : ShackHartmannSensorSystem {
            attribute systemId = "SHWFS-001";
        }

        part referenceSource {
            port beamOut : OpticalPort;
            attribute wavelength : Wavelength = 633[nm];
        }

        part testSource {
            port beamOut : OpticalPort;
            attribute wavelength : Wavelength = 633[nm];
        }

        connection refBeam connect referenceSource.beamOut to sensor.relayOptics.opticalIn;
        connection testBeam connect testSource.beamOut to sensor.relayOptics.opticalIn;
    }
}
