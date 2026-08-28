package 'Fisheries Acoustic System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def StartCalibration;
    item def CalibrationComplete;
    item def SurveyComplete;
    item def AnalysisComplete;
    item def EmergencyStop;

    item def AcousticPulse {
        attribute frequency : ISQ::FrequencyValue;
        attribute power : ISQ::PowerValue;
        attribute duration : ISQ::TimeValue;
    }

    item def EchoData {
        attribute amplitude : Real;
        attribute timeOfFlight : ISQ::TimeValue;
        attribute rawSamples : Real[*];
    }

    item def TargetDetection {
        attribute targetId : String;
        attribute range : ISQ::LengthValue;
        attribute echoStrength : Real;
        attribute targetDepth : ISQ::LengthValue;
    }

    item def BiomassEstimate {
        attribute fishDensity : Real;
        attribute averageFishMass : ISQ::MassValue;
        attribute totalBiomass : ISQ::MassValue;
        attribute confidence : Real;
    }

    item def GPSData {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute speed : ISQ::SpeedValue;
        attribute timestamp : String;
    }

    item def SurveyRecord {
        attribute biomass : BiomassEstimate;
        attribute gps : GPSData;
        attribute timestamp : String;
    }

    part def SplitBeamTransducer {
        port pulseOut : AcousticPulse;
        port echoOut : EchoData;
        attribute operatingFrequency : ISQ::FrequencyValue = 38000.0 [SI::Hz];
        attribute beamWidth : Real = 7.0;

        action transmitPulse { out pulse : AcousticPulse; }
        action receiveEcho { out echo : EchoData; }
    }

    part def EchosounderProcessor {
        port echoIn : EchoData;
        port targetOut : TargetDetection[*];

        action filterNoise { in echo : EchoData; out filtered : EchoData; }
        action detectTargets { in echo : EchoData; out targets : TargetDetection[*]; }
    }

    part def BiomassAnalyzer {
        port targetIn : TargetDetection[*];
        port biomassOut : BiomassEstimate;

        action computeBiomass { in targets : TargetDetection[*]; out estimate : BiomassEstimate; }
    }

    part def GPSNavigationSystem {
        port gpsOut : GPSData;

        action trackPosition { out data : GPSData; }
    }

    part def DataRecorder {
        port biomassIn : BiomassEstimate;
        port gpsIn : GPSData;
        attribute storedRecords : SurveyRecord[*] := ( );

        action recordSurveyData { in biomass : BiomassEstimate; in gps : GPSData; out record : SurveyRecord; }
        action generateMap { in records : SurveyRecord[*]; }
    }

    requirement def QuantitativeAssessmentRequirement {
        doc /* The system shall provide quantitative assessment of fish populations using active sonar echo strength analysis. */
    }

    requirement def GeographicAccuracyRequirement {
        doc /* The system shall georeference all acoustic detections with vessel position and speed data. */
    }

    requirement def BiomassAccuracyRequirement {
        doc /* The system shall estimate fish biomass within 10 percent of actual values to support sustainable fisheries management. */
    }

    requirement def DataManagementRequirement {
        doc /* The system shall store and manage all processed survey data including maps of fish school locations and estimated biomass. */
    }

    part def FisheriesAcousticSystem {
        part transducer : SplitBeamTransducer;
        part processor : EchosounderProcessor;
        part analyzer : BiomassAnalyzer;
        part gps : GPSNavigationSystem;
        part recorder : DataRecorder;

        connect transducer.echoOut to processor.echoIn;
        connect processor.targetOut to analyzer.targetIn;
        connect analyzer.biomassOut to recorder.biomassIn;
        connect gps.gpsOut to recorder.gpsIn;

        state def SystemStates;
        state systemStates : SystemStates {
            entry; then standby;

            state standby;
            accept StartCalibration then calibration;

            state calibration;
            accept CalibrationComplete then surveying;

            state surveying;
            accept SurveyComplete then analysis;

            state analysis;
            accept AnalysisComplete then standby;
            accept EmergencyStop then standby;
        }
    }

    requirement quantitativeAssessment :> QuantitativeAssessmentRequirement {
        subject part : FisheriesAcousticSystem::transducer;
        subject part : FisheriesAcousticSystem::processor;
        subject part : FisheriesAcousticSystem::analyzer;
    }

    requirement geographicAccuracy :> GeographicAccuracyRequirement {
        subject part : FisheriesAcousticSystem::gps;
        subject part : FisheriesAcousticSystem::recorder;
    }

    requirement biomassAccuracy :> BiomassAccuracyRequirement {
        subject part : FisheriesAcousticSystem::analyzer;
    }

    requirement dataManagement :> DataManagementRequirement {
        subject part : FisheriesAcousticSystem::recorder;
    }

    part fisheriesSystem : FisheriesAcousticSystem;
}
