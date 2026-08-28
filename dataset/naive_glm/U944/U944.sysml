package WavefrontSensingUnit {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;

    // ---- Value types with units ----
    value type Wavelength :> Real { unit "nm"; }
    value type FocalLength :> Length;
    value type LensletPitch :> Length;
    value type PixelPitch :> Length;
    value type SpotShift :> Length;
    value type WavefrontSlope :> Real { unit "mrad"; }
    value type WavefrontHeight :> Length;
    value type RmsError :> Length;
    value type PeakToValleyError :> Length;
    value type StrehlRatio :> Real { unit "1"; }
    value type ZernikeCoefficient :> Length;
    value type FrameRate :> Frequency;
    value type ExposureTime :> TimeValue;
    value type PixelIntensity :> Real { unit "DN"; }
    value type SpotPositionX :> Length;
    value type SpotPositionY :> Length;
    value type GridIndex :> Integer;
    value type ModeIndex :> Integer;

    // ---- Item types ----
    item def LightBeam {
        attribute wavelength : Wavelength;
        attribute beamDiameter : Length;
        attribute meanIntensity : Real;
    }

    item def Wavefront {
        attribute heightMap : WavefrontHeight[2..*];
        attribute rms : RmsError;
        attribute peakToValley : PeakToValleyError;
    }

    item def SpotImage {
        attribute pixelData : PixelIntensity[0..*];
        attribute width : Integer;
        attribute height : Integer;
        attribute exposure : ExposureTime;
        attribute timestamp : TimeValue;
    }

    item def SpotPosition {
        attribute x : SpotPositionX;
        attribute y : SpotPositionY;
        attribute intensity : PixelIntensity;
    }

    item def SpotGrid {
        attribute spots : SpotPosition[0..*];
        attribute rows : Integer;
        attribute cols : Integer;
    }

    item def ReferenceGrid {
        attribute idealSpots : SpotPosition[0..*];
        attribute rows : Integer;
        attribute cols : Integer;
        attribute calibrationTimestamp : TimeValue;
    }

    item def SlopeField {
        attribute slopeX : WavefrontSlope[0..*];
        attribute slopeY : WavefrontSlope[0..*];
        attribute rows : Integer;
        attribute cols : Integer;
    }

    item def ZernikeCoefficients {
        attribute coefficients : ZernikeCoefficient[0..*];
        attribute modeLabels : String[0..*];
    }

    item def WavefrontMetrics {
        attribute rms : RmsError;
        attribute peakToValley : PeakToValleyError;
        attribute strehl : StrehlRatio;
        attribute zernike : ZernikeCoefficients;
    }

    // ---- Port definitions ----
    port def OpticalPort {
        out item beam : LightBeam;
    }

    port def ImagePort {
        out item image : SpotImage;
    }

    port def SpotDataPort {
        out item grid : SpotGrid;
    }

    port def SlopeDataPort {
        out item slopes : SlopeField;
    }

    port def WavefrontDataPort {
        out item wavefront : Wavefront;
        out item metrics : WavefrontMetrics;
    }

    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
    }

    // ---- Requirements ----
    requirement def ShallMeasureWavefront {
        subject wfs : WavefrontSensingUnit;
        objective {
            doc /* The Wavefront Sensing Unit shall measure distortions in an incoming beam of light using a Shack-Hartmann configuration. */
        }
    }

    requirement def ShallOperateAtHighSpeed {
        subject wfs : WavefrontSensingUnit;
        attribute minFrameRate : FrameRate = 100 [Hz];
        objective {
            doc /* The unit shall acquire and process measurements at a rate of at least 100 Hz. */
        }
        require wfs.measurementRate >= minFrameRate;
    }

    requirement def ShallProvideMetrics {
        subject wfs : WavefrontSensingUnit;
        objective {
            doc /* The unit shall compute RMS error, peak-to-valley error, Strehl ratio, and Zernike mode coefficients. */
        }
    }

    requirement def ShallSupportOperatingModes {
        subject wfs : WavefrontSensingUnit;
        objective {
            doc /* The unit shall support Standby, Calibration, and Active Measurement operating modes. */
        }
    }

    requirement def ShallReconstructWavefront {
        subject proc : SignalProcessor;
        objective {
            doc /* The Signal Processor shall reconstruct the 2D wavefront shape from measured local slopes. */
        }
    }

    // ---- Parts ----
    part def LensletArray {
        attribute pitch : LensletPitch = 150 [um];
        attribute focalLength : FocalLength = 5 [mm];
        attribute rows : Integer = 32;
        attribute cols : Integer = 32;
        port in opticalIn : OpticalPort;
        port out opticalOut : OpticalPort;
        action focusBeam : LightBeam -> LightBeam {
            in incomingBeam;
            out focusedSubapertureBeam;
        }
    }

    part def DetectorArray {
        attribute pixelPitch : PixelPitch = 10 [um];
        attribute width : Integer = 1024;
        attribute height : Integer = 1024;
        attribute bitDepth : Integer = 16;
        attribute maxFrameRate : FrameRate = 200 [Hz];
        port in opticalIn : OpticalPort;
        port out imageOut : ImagePort;
        action captureImage : LightBeam -> SpotImage {
            in incomingBeam;
            in exposure : ExposureTime = 1 [ms];
            out capturedImage;
        }
    }

    part def SignalProcessor {
        attribute processingRate : FrameRate = 120 [Hz];
        port in imageIn : ImagePort;
        port in referenceIn : ReferenceGrid;
        port out spotOut : SpotDataPort;
        port out slopeOut : SlopeDataPort;
        port out wavefrontOut : WavefrontDataPort;

        action locateSpotCentroids : SpotImage -> SpotGrid {
            in image;
            out spotGrid;
        }

        action computeSlopes : SpotGrid -> SlopeField {
            in measuredGrid;
            in referenceGrid : ReferenceGrid;
            out slopeField;
        }

        action reconstructWavefront : SlopeField -> Wavefront {
            in slopes;
            out wavefront;
        }

        action characterizeWavefront : Wavefront -> WavefrontMetrics {
            in wavefront;
            out metrics;
        }

        perform locateSpotCentroids then computeSlopes then reconstructWavefront then characterizeWavefront;
    }

    part def WavefrontAnalyzer {
        port in wavefrontIn : WavefrontDataPort;
        port out metricsOut : WavefrontDataPort;
        action computeZernikeDecomposition : Wavefront -> ZernikeCoefficients {
            in wavefront;
            out coefficients;
        }
        action computeStrehl : Wavefront -> StrehlRatio {
            in wavefront;
            out strehl;
        }
    }

    part def WavefrontSensingUnit {
        attribute measurementRate : FrameRate = 120 [Hz];
        port in opticalInput : OpticalPort;
        port in control : ControlPort;
        port out telemetry : WavefrontDataPort;

        part lensletArray : LensletArray {
            redef pitch = 150 [um];
            redef focalLength = 4 [mm];
        }
        part detectorArray : DetectorArray {
            redef pixelPitch = 9 [um];
            redef width = 1024;
            redef height = 1024;
        }
        part signalProcessor : SignalProcessor;
        part wavefrontAnalyzer : WavefrontAnalyzer;

        // Stored calibration reference
        item referenceGrid : ReferenceGrid;

        // Connections
        connect opticalInput to lensletArray.opticalIn;
        connect lensletArray.opticalOut to detectorArray.opticalIn;
        connect detectorArray.imageOut to signalProcessor.imageIn;
        connect signalProcessor.wavefrontOut to wavefrontAnalyzer.wavefrontIn;
        connect wavefrontAnalyzer.metricsOut to telemetry;

        // Behavior: state machine
        state machine OperatingMode {
            entry action { /* initialize hardware */ }
            state Standby {
                entry action { /* power optics and detector to low-power standby */ }
                on control.command == "calibrate" transition to Calibrating;
                on control.command == "measure" transition to ActiveMeasurement;
            }
            state Calibrating {
                entry action {
                    /* Acquire reference image with ideal flat wavefront */
                    /* Store ideal spot positions into referenceGrid */
                }
                on control.command == "standby" transition to Standby;
                on control.command == "measure" transition to ActiveMeasurement;
            }
            state ActiveMeasurement {
                entry action { /* begin continuous acquisition and processing loop */ }
                do action measurementLoop {
                    loop {
                        detectorArray.captureImage();
                        signalProcessor.locateSpotCentroids();
                        signalProcessor.computeSlopes();
                        signalProcessor.reconstructWavefront();
                        signalProcessor.characterizeWavefront();
                    }
                }
                on control.command == "standby" transition to Standby;
                on control.command == "calibrate" transition to Calibrating;
            }
        }

        satisfy ShallMeasureWavefront { subject = Self; }
        satisfy ShallOperateAtHighSpeed { subject = Self; }
        satisfy ShallProvideMetrics { subject = Self; }
        satisfy ShallSupportOperatingModes { subject = Self; }
    }
}
