package FisheriesAcousticSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types with Units =====
    
    value def Frequency :> Real { unit 'kHz'; }
    value def AcousticPower :> Real { unit 'W'; }
    value def PulseDuration :> Real { unit 'ms'; }
    value def Depth :> Real { unit 'm'; }
    value def SoundSpeed :> Real { unit 'm/s'; }
    value def TargetStrength :> Real { unit 'dB'; }
    value def VesselSpeed :> Real { unit 'knot'; }
    value def Latitude :> Real { unit 'deg'; }
    value def Longitude :> Real { unit 'deg'; }
    value def Biomass :> Real { unit 'kg'; }
    value def FishDensity :> Real { unit 'fish/m3'; }
    value def FishLength :> Real { unit 'cm'; }
    value def VolumeBackscatter :> Real { unit 'm-1'; }
    value def SignalAmplitude :> Real { unit 'V'; }
    value def TimeStamp :> Real { unit 's'; }
    value def BeamAngle :> Real { unit 'deg'; }
    
    // ===== Item Definitions =====
    
    item def AcousticPulse {
        attribute frequency : Frequency;
        attribute power : AcousticPower;
        attribute duration : PulseDuration;
        attribute beamAngle : BeamAngle;
    }
    
    item def RawEchoData {
        attribute amplitude : SignalAmplitude;
        attribute timeOfFlight : TimeStamp;
        attribute depth : Depth;
        attribute pingNumber : Integer;
    }
    
    item def ProcessedEchoData {
        attribute targetStrength : TargetStrength;
        attribute depth : Depth;
        attribute volumeBackscatter : VolumeBackscatter;
        attribute pingNumber : Integer;
        attribute timestamp : TimeStamp;
        attribute noiseFloor : SignalAmplitude;
    }
    
    item def TargetDetection {
        attribute targetStrength : TargetStrength;
        attribute depth : Depth;
        attribute pingNumber : Integer;
        attribute isSchool : Boolean;
        attribute targetCount : Integer;
    }
    
    item def BiomassEstimate {
        attribute totalBiomass : Biomass;
        attribute fishDensity : FishDensity;
        attribute meanFishLength : FishLength;
        attribute schoolVolume : Volume;
        attribute pingNumber : Integer;
    }
    
    item def GeoReference {
        attribute latitude : Latitude;
        attribute longitude : Longitude;
        attribute vesselSpeed : VesselSpeed;
        attribute timestamp : TimeStamp;
    }
    
    item def SurveyRecord {
        attribute geoRef : GeoReference;
        attribute biomassEstimate : BiomassEstimate;
        attribute targetDetection : TargetDetection;
        attribute surveyId : String;
    }
    
    item def CalibrationParameters {
        attribute soundSpeed : SoundSpeed;
        attribute transducerGain : TargetStrength;
        attribute absorptionCoefficient : Real;
        attribute calibrationTime : TimeStamp;
    }
    
    // ===== Port Definitions =====
    
    port def AcousticPort {
        out item pulse : AcousticPulse;
        in item echo : RawEchoData;
    }
    
    port def RawDataPort {
        in item rawEcho : RawEchoData;
    }
    
    port def ProcessedDataPort {
        out item processed : ProcessedEchoData;
        out item target : TargetDetection;
    }
    
    port def GeoDataPort {
        out item geoRef : GeoReference;
    }
    
    port def BiomassDataPort {
        out item estimate : BiomassEstimate;
    }
    
    port def RecordPort {
        in item record : SurveyRecord;
    }
    
    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
    }
    
    // ===== Requirements =====
    
    requirement def SystemRequirement {
        doc "Scientific fisheries acoustic system for quantitative assessment and mapping of fish populations."
        attribute systemId : String;
    }
    
    requirement def ActiveSonarRequirement :> SystemRequirement {
        doc "System shall operate using active sonar to transmit controlled acoustic pulses and receive echoes."
        attribute operatingFrequency : Frequency = 38.0;
        attribute maxDepth : Depth = 1000.0;
    }
    
    requirement def TransducerRequirement :> SystemRequirement {
        doc "Split-beam transducer shall transmit pings and capture returning echoes as raw data."
        attribute beamAngle : BeamAngle = 7.0;
        attribute maxPower : AcousticPower = 2000.0;
    }
    
    requirement def ProcessorRequirement :> SystemRequirement {
        doc "Echosounder processor shall filter noise and detect targets from raw echo data."
        attribute minTargetStrength : TargetStrength = -60.0;
    }
    
    requirement def BiomassAnalyzerRequirement :> SystemRequirement {
        doc "Biomass analyzer shall estimate fish density, individual fish size, and total biomass."
        attribute biomassAccuracy : Real = 0.05; // 5% relative error
    }
    
    requirement def GPSRequirement :> SystemRequirement {
        doc "GPS navigation system shall track vessel position and speed for georeferencing."
        attribute positionAccuracy : Real = 2.0; // meters
        attribute maxSpeed : VesselSpeed = 15.0;
    }
    
    requirement def DataRecorderRequirement :> SystemRequirement {
        doc "Data recorder shall manage and store all final processed survey data."
        attribute storageCapacity : Volume;
        attribute recordFormat : String = "netCDF4";
    }
    
    requirement def OperationalPhaseRequirement :> SystemRequirement {
        doc "System shall operate through standby, calibration, active surveying, and analysis phases."
    }
    
    // ===== Parts =====
    
    part def SplitBeamTransducer {
        port acousticOut : AcousticPort;
        port control : ControlPort;
        
        attribute frequency : Frequency = 38.0;
        attribute power : AcousticPower = 1000.0;
        attribute pulseDuration : PulseDuration = 1.0;
        attribute beamAngle : BeamAngle = 7.0;
        attribute isTransmitting : Boolean = false;
        
        action transmitPing {
            out pulse : AcousticPulse = AcousticPulse{frequency = frequency, power = power, duration = pulseDuration, beamAngle = beamAngle};
        }
        
        action receiveEcho {
            in echo : RawEchoData;
        }
        
        action generateRawData : RawEchoData[0..*];
    }
    
    part def EchosounderProcessor {
        port rawInput : RawDataPort;
        port processedOutput : ProcessedDataPort;
        port control : ControlPort;
        
        attribute noiseThreshold : SignalAmplitude = 0.01;
        attribute minTargetStrength : TargetStrength = -60.0;
        attribute filterBandwidth : Frequency = 2.0;
        
        action filterNoise {
            in raw : RawEchoData;
            out filtered : RawEchoData;
        }
        
        action detectTargets {
            in filtered : RawEchoData;
            out processed : ProcessedEchoData;
            out target : TargetDetection;
        }
        
        action analyzeSignal {
            in raw : RawEchoData;
            out result : ProcessedEchoData;
        }
        
        perform action processEchoes {
            in raw : RawEchoData;
            out processed : ProcessedEchoData;
            out target : TargetDetection;
            
            first filterNoise(in raw = raw, out filtered);
            then detectTargets(in filtered = filtered, out processed = processed, out target = target);
        }
    }
    
    part def BiomassAnalyzer {
        port processedInput : ProcessedDataPort;
        port biomassOutput : BiomassDataPort;
        port control : ControlPort;
        
        attribute targetStrengthToLengthCoeff : Real = 20.0;
        attribute lengthToWeightCoeff : Real = 0.01;
        attribute biomassAccuracy : Real = 0.05;
        
        action estimateDensity {
            in processed : ProcessedEchoData;
            out density : FishDensity;
        }
        
        action estimateFishSize {
            in target : TargetDetection;
            out meanLength : FishLength;
        }
        
        action calculateBiomass {
            in density : FishDensity;
            in meanLength : FishLength;
            in schoolVolume : Volume;
            out estimate : BiomassEstimate;
        }
        
        perform action analyzeBiomass {
            in processed : ProcessedEchoData;
            in target : TargetDetection;
            out estimate : BiomassEstimate;
            
            first estimateDensity(in processed = processed, out density);
            then estimateFishSize(in target = target, out meanLength);
            then calculateBiomass(in density = density, in meanLength = meanLength, in schoolVolume = Volume{value = 1000.0}, out estimate = estimate);
        }
    }
    
    part def GPSNavigationSystem {
        port geoOutput : GeoDataPort;
        port control : ControlPort;
        
        attribute latitude : Latitude = 0.0;
        attribute longitude : Longitude = 0.0;
        attribute vesselSpeed : VesselSpeed = 0.0;
        attribute positionAccuracy : Real = 2.0;
        attribute isTracking : Boolean = false;
        
        action trackPosition {
            out geoRef : GeoReference;
        }
        
        action updatePosition {
            in lat : Latitude;
            in lon : Longitude;
            in speed : VesselSpeed;
        }
    }
    
    part def DataRecorder {
        port recordInput : RecordPort;
        port control : ControlPort;
        
        attribute storageCapacity : Volume = Volume{value = 1000000000000.0};
        attribute recordFormat : String = "netCDF4";
        attribute recordCount : Integer = 0;
        attribute surveyId : String;
        
        action storeRecord {
            in record : SurveyRecord;
        }
        
        action generateSurveyMap {
            in records : SurveyRecord[0..*];
            out map : String;
        }
        
        action exportData {
            in records : SurveyRecord[0..*];
            out exportedFile : String;
        }
    }
    
    part def SystemController {
        port control : ControlPort;
        
        attribute currentPhase : String = "standby";
        attribute surveyActive : Boolean = false;
        
        state def ControllerStates {
            state standby;
            state calibration;
            state activeSurveying;
            state analysis;
            
            transition standby_to_calibration
                from standby to calibration
                when (control.command == "calibrate");
            
            transition calibration_to_activeSurveying
                from calibration to activeSurveying
                when (control.command == "start_survey")
                if (calibrationComplete);
            
            transition activeSurveying_to_analysis
                from activeSurveying to analysis
                when (control.command == "stop_survey");
            
            transition analysis_to_standby
                from analysis to standby
                when (control.command == "complete");
            
            entry standby { control.status = "standby"; }
            entry calibration { control.status = "calibrating"; }
            entry activeSurveying { control.status = "surveying"; }
            entry analysis { control.status = "analyzing"; }
        }
        
        attribute calibrationComplete : Boolean = false;
        
        action performCalibration {
            out params : CalibrationParameters;
        }
    }
    
    // ===== Top-level System =====
    
    part FisheriesAcousticSurveySystem {
        satisfy SystemRequirement {
            systemId = "FAS-2024-001";
        }
        
        satisfy ActiveSonarRequirement {
            systemId = "FAS-2024-001";
            operatingFrequency = 38.0;
            maxDepth = Depth{value = 1000.0};
        }
        
        satisfy OperationalPhaseRequirement {
            systemId = "FAS-2024-001";
        }
        
        part transducer : SplitBeamTransducer {
            satisfy TransducerRequirement {
                systemId = "FAS-2024-001";
                beamAngle = 7.0;
                maxPower = AcousticPower{value = 2000.0};
            }
        }
        
        part processor : EchosounderProcessor {
            satisfy ProcessorRequirement {
                systemId = "FAS-2024-001";
                minTargetStrength = TargetStrength{value = -60.0};
            }
        }
        
        part biomassAnalyzer : BiomassAnalyzer {
            satisfy BiomassAnalyzerRequirement {
                systemId = "FAS-2024-001";
                biomassAccuracy = 0.05;
            }
        }
        
        part gps : GPSNavigationSystem {
            satisfy GPSRequirement {
                systemId = "FAS-2024-001";
                positionAccuracy = 2.0;
                maxSpeed = VesselSpeed{value = 15.0};
            }
        }
        
        part recorder : DataRecorder {
            satisfy DataRecorderRequirement {
                systemId = "FAS-2024-001";
                storageCapacity = Volume{value = 1000000000000.0};
                recordFormat = "netCDF4";
            }
        }
        
        part controller : SystemController;
        
        // Connections
        connection transducerToProcessor connect transducer.acousticOut to processor.rawInput {
            item flow rawEcho : RawEchoData from transducer.acousticOut.echo to processor.rawInput.rawEcho;
        }
        
        connection processorToBiomass connect processor.processedOutput to biomassAnalyzer.processedInput {
            item flow processed : ProcessedEchoData from processor.processedOutput.processed to biomassAnalyzer.processedInput.processed;
            item flow target : TargetDetection from processor.processedOutput.target to biomassAnalyzer.processedInput.target;
        }
        
        connection gpsToRecorder connect gps.geoOutput to recorder.recordInput {
            item flow geoRef : GeoReference from gps.geoOutput.geoRef to recorder.recordInput.record.geoRef;
        }
        
        connection biomassToRecorder connect biomassAnalyzer.biomassOutput to recorder.recordInput {
            item flow estimate : BiomassEstimate from biomassAnalyzer.biomassOutput.estimate to recorder.recordInput.record.biomassEstimate;
        }
        
        connection controllerToTransducer connect controller.control to transducer.control;
        connection controllerToProcessor connect controller.control to processor.control;
        connection controllerToBiomass connect controller.control to biomassAnalyzer.control;
        connection controllerToGPS connect controller.control to gps.control;
        connection controllerToRecorder connect controller.control to recorder.control;
        
        // System-level state machine
        state def SystemOperationalStates {
            state standby {
                entry { controller.control.command = "standby"; }
                do action idle;
            }
            
            state calibration {
                entry { controller.control.command = "calibrate"; }
                do action performCalibration {
                    out params : CalibrationParameters;
                }
            }
            
            state activeSurveying {
                entry { controller.control.command = "start_survey"; }
                do action conductSurvey {
                    // Transducer transmits pings and receives echoes
                    // Processor filters and detects targets
                    // GPS tracks position
                    // Biomass analyzer computes estimates
                }
            }
            
            state analysis {
                entry { controller.control.command = "stop_survey"; }
                do action analyzeData {
                    // Recorder generates survey maps
                    // Export final data
                }
            }
            
            transition standbyToCalibration
                from standby to calibration
                when (controller.control.command == "calibrate");
            
            transition calibrationToSurveying
                from calibration to activeSurveying
                when (controller.control.command == "start_survey")
                if (controller.calibrationComplete == true);
            
            transition surveyingToAnalysis
                from activeSurveying to analysis
                when (controller.control.command == "stop_survey");
            
            transition analysisToStandby
                from analysis to standby
                when (controller.control.command == "complete");
        }
        
        // System-level actions
        action conductSurvey {
            in surveyArea : String;
            out records : SurveyRecord[0..*];
            
            first transducer.transmitPing;
            then transducer.receiveEcho;
            then processor.processEchoes;
            then biomassAnalyzer.analyzeBiomass;
            then gps.trackPosition;
            then recorder.storeRecord;
        }
        
        action performSystemCalibration {
            out params : CalibrationParameters;
            
            first controller.performCalibration;
            then transducer.transmitPing;
            then processor.processEchoes;
        }
        
        action generateFinalReport {
            in records : SurveyRecord[0..*];
            out report : String;
            
            first recorder.generateSurveyMap;
            then recorder.exportData;
        }
    }
}
