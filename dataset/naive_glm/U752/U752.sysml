package LASH {

    public import ISQ::*;
    public import ScalarValues::*;
    public import ControlFunctions::*;

    package ValueTypes {

        attribute def Wavelength :> ISQ::Length;
        unit nm of Wavelength = 1e-9 * ISQ::Length::m;
        unit um of Wavelength = 1e-6 * ISQ::Length::m;

        attribute def SpectralBandwidth :> ISQ::Length;
        unit nm_bw of SpectralBandwidth = nm;

        attribute def Irradiance :> Real;
        unit W_per_m2 of Irradiance;

        attribute def DetectorVoltage :> ISQ::ElectricPotential;
        unit mV of DetectorVoltage = 1e-3 * ISQ::ElectricPotential::V;

        attribute def OperatingTemperature :> ISQ::ThermodynamicTemperature;
        unit K of OperatingTemperature = ISQ::ThermodynamicTemperature::K;

        attribute def FrameRate :> Real;
        unit fps of FrameRate;

        attribute def DataRate :> Real;
        unit Mbps of DataRate;

        attribute def SpatialResolution :> ISQ::Length;
        unit m_res of SpatialResolution = ISQ::Length::m;

        attribute def AngularFieldOfView :> Real;
        unit deg of AngularFieldOfView;

        attribute def PixelCount :> Integer;
        attribute def BandCount :> Integer;
        attribute def ExposureTime :> ISQ::Time;
        unit ms of ExposureTime = 1e-3 * ISQ::Time::s;
    }

    package ItemDefinitions {

        item def IncidentLight {
            attribute wavelengthRange : Wavelength[2];
            attribute irradiance : Irradiance;
            attribute sceneReflectance : Real;
        }

        item def FocusedLight {
            attribute wavelengthRange : Wavelength[2];
            attribute focusedIrradiance : Irradiance;
            attribute spatialPoint : Integer[2];
        }

        item def DispersedSpectrum {
            attribute wavelength : Wavelength;
            attribute intensity : Real;
            attribute spatialLineIndex : Integer;
        }

        item def RawDetectorFrame {
            attribute lineIndex : Integer;
            attribute pixelValues : Real[*];
            attribute integrationTime : ExposureTime;
            attribute frameTimestamp : ISQ::Time;
        }

        item def CalibrationReference {
            attribute referenceType : String;
            attribute knownReflectance : Real;
            attribute wavelengthCalibration : Wavelength[*];
            attribute radiometricGain : Real[*];
        }

        item def CalibrationData {
            attribute darkFrame : Real[*];
            attribute flatField : Real[*];
            attribute wavelengthMapping : Wavelength[*];
            attribute radiometricCoefficients : Real[*];
            attribute timestamp : ISQ::Time;
        }

        item def HyperspectralDataCube {
            attribute spatialLines : Integer;
            attribute spatialSamples : Integer;
            attribute spectralBands : Integer;
            attribute wavelengthAxis : Wavelength[*];
            attribute radianceValues : Real[*];
            attribute georeference : String;
            attribute acquisitionTime : ISQ::Time;
        }

        item def Command {
            attribute commandId : String;
            attribute targetArea : String;
            attribute requestedBands : BandCount;
            attribute priority : Integer;
        }

        item def Telemetry {
            attribute instrumentState : String;
            attribute detectorTemperature : OperatingTemperature;
            attribute frameRate : FrameRate;
            attribute dataRate : DataRate;
            attribute healthStatus : String;
        }
    }

    package PortDefinitions {

        port def OpticalPort {
            in item incoming : IncidentLight;
            out item outgoing : FocusedLight;
        }

        port def SpectrumPort {
            in item focused : FocusedLight;
            out item dispersed : DispersedSpectrum;
        }

        port def DetectorPort {
            in item spectrum : DispersedSpectrum;
            out item rawFrame : RawDetectorFrame;
        }

        port def CalibrationPort {
            out item reference : CalibrationReference;
            out item calibrationData : CalibrationData;
        }

        port def SignalDataPort {
            in item rawFrame : RawDetectorFrame;
            in item calibrationData : CalibrationData;
            out item dataCube : HyperspectralDataCube;
        }

        port def CommandPort {
            in item command : Command;
            out item telemetry : Telemetry;
        }

        port def PowerPort {
            attribute voltage : DetectorVoltage;
            attribute current : Real;
        }
    }

    package Subsystems {

        part def OpticalSubsystem {
            attribute apertureDiameter : SpatialResolution = 0.15 [m_res];
            attribute focalLength : SpatialResolution = 0.45 [m_res];
            attribute fieldOfView : AngularFieldOfView = 30 [deg];
            attribute opticalThroughput : Real;

            port opticalIn : OpticalPort;
            port opticalOut : OpticalPort;

            action def CollectAndFocus {
                in item sceneLight : IncidentLight;
                out item focusedBeam : FocusedLight;
            }

            perform action collect : CollectAndFocus {
                in item sceneLight = opticalIn.incoming;
                out item focusedBeam = opticalOut.outgoing;
            }
        }

        part def SpectrographicDispersiveElement {
            attribute spectralRangeMin : Wavelength = 400 [nm];
            attribute spectralRangeMax : Wavelength = 2500 [nm];
            attribute spectralResolution : SpectralBandwidth = 5 [nm_bw];
            attribute dispersionEfficiency : Real;
            attribute prismGratingType : String = "hybrid prism-grating";

            port spectrumIn : SpectrumPort;
            port spectrumOut : SpectrumPort;

            action def Disperse {
                in item focused : FocusedLight;
                out item dispersed : DispersedSpectrum;
            }

            perform action disperse : Disperse {
                in item focused = spectrumIn.focused;
                out item dispersed = spectrumOut.dispersed;
            }
        }

        part def FocalPlaneArray {
            attribute detectorMaterial : String = "HgCdTe";
            attribute spatialPixels : PixelCount = 1024;
            attribute spectralBands : BandCount = 256;
            attribute operatingTemperature : OperatingTemperature = 77 [K];
            attribute frameRate : FrameRate = 100 [fps];
            attribute dynamicRange : Real;
            attribute noiseEquivalentPower : Real;

            port detectorIn : DetectorPort;
            port powerIn : PowerPort;

            action def Detect {
                in item spectrum : DispersedSpectrum;
                out item rawFrame : RawDetectorFrame;
            }

            perform action detect : Detect {
                in item spectrum = detectorIn.spectrum;
                out item rawFrame = detectorIn.rawFrame;
            }
        }

        part def ScanMechanism {
            attribute scanTechnique : String = "pushbroom";
            attribute swathWidth : SpatialResolution = 500 [m_res];
            attribute groundResolution : SpatialResolution = 2 [m_res];
            attribute aircraftVelocity : Real;
            attribute scanLineRate : FrameRate = 100 [fps];

            action def AdvanceScanLine {
                in item currentLine : Integer;
                out item nextLine : Integer;
            }

            perform action advance : AdvanceScanLine;
        }

        part def CalibrationSubsystem {
            attribute referenceStandards : String[*] = {"tungsten lamp", "diffuser panel", "mercury arc"};
            attribute calibrationInterval : ISQ::Time = 300 [s];
            attribute lastCalibrationTime : ISQ::Time;

            port calibrationOut : CalibrationPort;

            action def PerformSelfCalibration {
                out item reference : CalibrationReference;
                out item calibrationData : CalibrationData;
            }

            perform action selfCalibrate : PerformSelfCalibration {
                out item reference = calibrationOut.reference;
                out item calibrationData = calibrationOut.calibrationData;
            }
        }

        part def SignalProcessingUnit {
            attribute processingRate : DataRate = 200 [Mbps];
            attribute atmosphericCorrectionModel : String = "MODTRAN-derived";
            attribute radiometricCorrectionEnabled : Boolean = true;
            attribute georeferenceEnabled : Boolean = true;

            port signalIn : SignalDataPort;
            port commandIn : CommandPort;

            action def ProcessFrame {
                in item rawFrame : RawDetectorFrame;
                in item calibrationData : CalibrationData;
                out item partialCube : HyperspectralDataCube;
            }

            action def AssembleDataCube {
                in item partialCubes : HyperspectralDataCube[*];
                out item finalCube : HyperspectralDataCube;
            }

            perform action process : ProcessFrame {
                in item rawFrame = signalIn.rawFrame;
                in item calibrationData = signalIn.calibrationData;
                out item partialCube;
            }

            perform action assemble : AssembleDataCube {
                in item partialCubes;
                out item finalCube = signalIn.dataCube;
            }
        }
    }

    package Lifecycle {

        state machine def LASHLifecycle {

            state Initializing {
                entry action {
                    perform Subsystems::CalibrationSubsystem::selfCalibrate;
                }
                transition Initializing to SelfCalibrating
                    when (initializationComplete);
            }

            state SelfCalibrating {
                entry action {
                    perform Subsystems::CalibrationSubsystem::selfCalibrate;
                }
                transition SelfCalibrating to Ready
                    when (calibrationValid);
            }

            state Ready {
                transition Ready to Scanning
                    when (scanCommandReceived);
                transition Ready to SelfCalibrating
                    when (recalibrationRequested);
                transition Ready to Shutdown
                    when (shutdownCommandReceived);
            }

            state Scanning {
                entry action {
                    perform Subsystems::ScanMechanism::advance;
                    perform Subsystems::FocalPlaneArray::detect;
                }
                transition Scanning to Processing
                    when (scanAreaComplete);
            }

            state Processing {
                entry action {
                    perform Subsystems::SignalProcessingUnit::process;
                    perform Subsystems::SignalProcessingUnit::assemble;
                }
                transition Processing to Ready
                    when (dataCubeOutput);
            }

            state Shutdown {
                entry action {
                    perform powerOffSequence;
                }
            }
        }
    }

    package Requirements {

        requirement def HyperspectralCoverageRequirement {
            attribute spectralRangeMin : Wavelength = 400 [nm];
            attribute spectralRangeMax : Wavelength = 2500 [nm];
            attribute minBands : BandCount = 200;
            doc "The instrument shall capture light across the visible to shortwave infrared spectrum with at least 200 spectral bands."
        }

        requirement def SpatialResolutionRequirement {
            attribute groundSampleDistance : SpatialResolution = 2 [m_res];
            attribute swathWidth : SpatialResolution = 500 [m_res];
            doc "The instrument shall achieve a ground sample distance of 2 m or better across a 500 m swath."
        }

        requirement def RadiometricAccuracyRequirement {
            attribute radiometricUncertainty : Real = 0.05;
            doc "The instrument shall maintain radiometric accuracy within 5% using onboard calibration references."
        }

        requirement def DataCubeOutputRequirement {
            attribute maxLatency : ISQ::Time = 5 [s];
            doc "The signal processing unit shall output a corrected hyperspectral data cube within 5 seconds of scan completion."
        }

        requirement def LifecycleRequirement {
            doc "The instrument shall initialize, self-calibrate, enter a ready state, scan on command, process data, and return to ready."
        }

        requirement def DetectorCoolingRequirement {
            attribute maxOperatingTemperature : OperatingTemperature = 80 [K];
            doc "The HgCdTe focal plane array shall be cooled to 80 K or below during operation."
        }
    }

    part def LASHInstrument {

        attribute instrumentName : String = "Littoral Airborne Sensor Hyperspectral";
        attribute aircraftMountType : String = "belly-mounted gyro-stabilized";

        part optical : Subsystems::OpticalSubsystem {
            attribute apertureDiameter = 0.15 [m_res];
            attribute focalLength = 0.45 [m_res];
        }

        part disperser : Subsystems::SpectrographicDispersiveElement {
            attribute spectralRangeMin = 400 [nm];
            attribute spectralRangeMax = 2500 [nm];
            attribute spectralResolution = 5 [nm_bw];
        }

        part focalPlane : Subsystems::FocalPlaneArray {
            attribute detectorMaterial = "HgCdTe";
            attribute spatialPixels = 1024;
            attribute spectralBands = 256;
            attribute operatingTemperature = 77 [K];
        }

        part scanner : Subsystems::ScanMechanism {
            attribute scanTechnique = "pushbroom";
            attribute swathWidth = 500 [m_res];
            attribute groundResolution = 2 [m_res];
        }

        part calibration : Subsystems::CalibrationSubsystem {
            attribute calibrationInterval = 300 [s];
        }

        part processor : Subsystems::SignalProcessingUnit {
            attribute processingRate = 200 [Mbps];
            attribute atmosphericCorrectionModel = "MODTRAN-derived";
        }

        part powerSupply {
            attribute inputVoltage : DetectorVoltage = 28 [mV];
            attribute powerConsumption : Real;
            port powerOut : PortDefinitions::PowerPort;
        }

        port commandInterface : PortDefinitions::CommandPort;
        port dataOutput : PortDefinitions::SignalDataPort;

        connection opticalPath1 connect optical.opticalOut to disperser.spectrumIn;
        connection opticalPath2 connect disperser.spectrumOut to focalPlane.detectorIn;
        connection signalPath connect focalPlane.detectorIn.rawFrame to processor.signalIn.rawFrame;
        connection calibrationPath connect calibration.calibrationOut.calibrationData to processor.signalIn.calibrationData;
        connection powerDistribution connect powerSupply.powerOut to focalPlane.powerIn;
        connection commandLink connect commandInterface.command to processor.commandIn.command;
        connection telemetryLink connect processor.commandIn.telemetry to commandInterface.telemetry;
        connection dataLink connect processor.signalIn.dataCube to dataOutput.dataCube;

        satisfy Requirements::HyperspectralCoverageRequirement {
            attribute spectralRangeMin = disperser.spectralRangeMin;
            attribute spectralRangeMax = disperser.spectralRangeMax;
            attribute minBands = focalPlane.spectralBands;
        }

        satisfy Requirements::SpatialResolutionRequirement {
            attribute groundSampleDistance = scanner.groundResolution;
            attribute swathWidth = scanner.swathWidth;
        }

        satisfy Requirements::RadiometricAccuracyRequirement {
            attribute calibrationSubsystem = calibration.referenceStandards;
        }

        satisfy Requirements::DataCubeOutputRequirement {
            attribute processingUnit = processor;
        }

        satisfy Requirements::DetectorCoolingRequirement {
            attribute operatingTemperature = focalPlane.operatingTemperature;
        }

        satisfy Requirements::LifecycleRequirement {
            attribute lifecycle = Lifecycle::LASHLifecycle;
        }

        exhibit state machine lifecycle : Lifecycle::LASHLifecycle;
    }

    part def Aircraft {
        attribute designation : String;
        attribute cruiseVelocity : Real;
        attribute operatingAltitude : SpatialResolution;

        part lashPayload : LASHInstrument;

        connection mountInterface connect lashPayload.commandInterface to aircraftCommandBus;
        port aircraftCommandBus : PortDefinitions::CommandPort;
    }
}
