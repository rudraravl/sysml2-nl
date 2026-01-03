package FisheriesAcousticsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;
    
    attribute def AcousticFrequency :> ISQ::FrequencyValue {
        doc /* Operating frequency for fisheries acoustic systems, typically 18-710 kHz */
    }
    
    attribute def BackscatterStrength :> Real {
        doc /* Volume backscattering strength in dB re 1 m^-1 */
    }
    
    attribute def TargetStrength :> Real {
        doc /* Target strength in dB re 1 m^2 */
    }
    
    attribute def BiomassValue :> ISQ::MassValue {
        doc /* Estimated fish biomass */
    }
    
    attribute def FishDensity :> Real {
        doc /* Number of fish per cubic meter */
    }
    
    item def AcousticPing {
        attribute frequency : AcousticFrequency;
        attribute transmitPower : ISQ::PowerValue;
        attribute pulseLength : ISQ::TimeValue;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def EchoData {
        attribute backscatter : BackscatterStrength;
        attribute range : ISQ::LengthValue;
        attribute travelTime : ISQ::TimeValue;
        attribute targetStrength : TargetStrength;
    }
    
    item def FishSchool {
        attribute depth : ISQ::LengthValue;
        attribute horizontalExtent : ISQ::LengthValue;
        attribute verticalExtent : ISQ::LengthValue;
        attribute estimatedBiomass : BiomassValue;
        attribute density : FishDensity;
        attribute species : String;
    }
    
    item def SurveyData {
        attribute position : Real[3];
        attribute detectedSchools : FishSchool[*];
        attribute totalBiomass : BiomassValue;
        attribute surveyTime : ISQ::TimeValue;
    }
    
    port def TransducerPort {
        out transmittedPing : AcousticPing;
        in receivedEcho : EchoData;
    }
    
    port def ProcessingPort {
        in rawEcho : EchoData;
        out processedData : FishSchool;
    }
    
    port def DataPort {
        out surveyResults : SurveyData;
    }
    
    port def NavigationPort {
        out vesselPosition : Real[3];
        out vesselSpeed : ISQ::SpeedValue;
    }
    
    part def SplitBeamTransducer {
        doc /* Multi-beam acoustic transducer for fish detection and sizing */
        
        attribute nominalFrequency : AcousticFrequency;
        attribute beamWidth : Real;
        attribute maxDepth : ISQ::LengthValue;
        
        port transducerPort : TransducerPort;
        
        perform action transmitPing {
            in frequency : AcousticFrequency;
            in power : ISQ::PowerValue;
            out ping : AcousticPing;
        }
        
        perform action receiveEcho {
            in ping : AcousticPing;
            out echo : EchoData;
        }
    }
    
    part def EchosounderProcessor {
        doc /* Digital signal processor for echo analysis and target detection */
        
        port processingInput : ProcessingPort;
        
        perform action filterNoise {
            in rawSignal : EchoData;
            out filteredSignal : EchoData;
        }
        
        perform action detectTargets {
            in filteredData : EchoData[*];
            out targets : FishSchool[*];
        }
        
        perform action classifyTargets {
            in targets : FishSchool[*];
            out classifiedTargets : FishSchool[*];
        }
    }
    
    part def BiomassAnalyzer {
        doc /* Calculates fish abundance and biomass from acoustic data */
        
        perform action calculateDensity {
            in backscatter : BackscatterStrength;
            in targetStrength : TargetStrength;
            out density : FishDensity;
        }
        
        perform action estimateBiomass {
            in schools : FishSchool[*];
            in surveyArea : ISQ::AreaValue;
            out totalBiomass : BiomassValue;
        }
        
        perform action integrateSurvey {
            in schools : FishSchool[*];
            out surveyData : SurveyData;
        }
    }
    
    part def GPSNavigationSystem {
        doc /* Provides vessel position and track for georeferencing acoustic data */
        
        attribute currentPosition : Real[3];
        attribute currentSpeed : ISQ::SpeedValue;
        
        port navPort : NavigationPort;
        
        perform action updatePosition;
    }
    
    part def DataRecorder {
        doc /* Stores and manages acoustic survey data */
        
        attribute storedSurveys : SurveyData[*];
        
        port dataInput : DataPort;
        
        perform action recordData {
            in survey : SurveyData;
        }
        
        perform action exportData {
            out surveys : SurveyData[*];
        }
    }
    
    action def TransmitAcousticPulse {
        in operatingFrequency : AcousticFrequency;
        in transmitPower : ISQ::PowerValue;
        in pulseWidth : ISQ::TimeValue;
        out ping : AcousticPing;
    }
    
    action def ReceiveBackscatter {
        in transmittedPing : AcousticPing;
        in waterDepth : ISQ::LengthValue;
        out echoData : EchoData;
    }
    
    action def ProcessEcho {
        in echo : EchoData;
        in soundSpeed : ISQ::SpeedValue;
        out range : ISQ::LengthValue;
        out strength : TargetStrength;
    }
    
    action def DetectFishSchool {
        in echoData : EchoData[*];
        in threshold : TargetStrength;
        out school : FishSchool;
    }
    
    action def ConductAcousticSurvey {
        in surveyFrequency : AcousticFrequency;
        in pingRate : ISQ::FrequencyValue;
        in surveyDuration : ISQ::TimeValue;
        in depthRange : ISQ::LengthValue;
        out surveyResults : SurveyData;
        
        private attribute elapsedTime : ISQ::TimeValue := 0.0 [SI::s];
        private attribute detectedSchools : FishSchool[*] := ();
        private attribute currentPosition : Real[3] := (0.0, 0.0, 0.0);
        
        first start;
        then merge continueSurvey;
        
        then action initializeSurvey {
            in frequency = surveyFrequency;
            in depth = depthRange;
        }
        
        then action transmit : TransmitAcousticPulse {
            in operatingFrequency = surveyFrequency;
            in transmitPower = 2000.0 [SI::W];
            in pulseWidth = 0.001 [SI::s];
            out ping : AcousticPing;
        }
        
        then action receive : ReceiveBackscatter {
            in transmittedPing = transmit.ping;
            in waterDepth = depthRange;
            out echoData : EchoData;
        }
        
        then action process : ProcessEcho {
            in echo = receive.echoData;
            in soundSpeed = 1500.0 [SI::m/SI::s];
            out range : ISQ::LengthValue;
            out strength : TargetStrength;
        }
        
        then decide;
            if process.strength > -60.0 then detectSchool;
            else continueSurvey;
        
        action detectSchool : DetectFishSchool {
            in echoData[1] = receive.echoData;
            in threshold = -60.0;
            out school : FishSchool;
        }
        
        then action recordSchool {
            in school = detectSchool.school;
        }
        then assign detectedSchools := detectedSchools->including(detectSchool.school);
        
        then continueSurvey;
        
        then action updateTime {
            assign elapsedTime := elapsedTime + (1.0 / pingRate);
        }
        
        then decide;
            if elapsedTime < surveyDuration then continueSurvey;
            else finalizeSurvey;
        
        action finalizeSurvey {
            in schools = detectedSchools;
            out results : SurveyData;
        }
        
        then done;
    }
    
    state def SurveyOperationStates {
        entry; then standby;
        
        state standby {
            doc /* System ready but not actively surveying */
        }
        
        transition standby_to_calibrating
            first standby
            accept calibrateCommand
            then calibrating;
        
        state calibrating {
            doc /* Calibrating transducer and processing parameters */
        }
        
        transition calibrating_to_surveying
            first calibrating
            accept calibrationComplete
            then surveying;
        
        state surveying {
            doc /* Actively transmitting pings and collecting data */
        }
        
        transition surveying_to_analyzing
            first surveying
            accept surveyComplete
            then analyzing;
        
        state analyzing {
            doc /* Processing collected data and generating biomass estimates */
        }
        
        transition analyzing_to_standby
            first analyzing
            accept analysisComplete
            then standby;
        
        transition surveying_to_standby
            first surveying
            accept abortSurvey
            then standby;
    }
    
    part def FisheriesAcousticSystem;
    
    part fisheriesAcousticSystem : FisheriesAcousticSystem {
        doc /* 
            Scientific fisheries acoustic system for quantitative assessment of fish stocks.
            Uses active sonar to detect, classify, and estimate abundance of fish populations
            in marine and freshwater environments for sustainable fisheries management.
        */
        
        attribute operatingFrequency : AcousticFrequency = 38000.0 [SI::Hz];
        attribute soundSpeed : ISQ::SpeedValue = 1500.0 [SI::m/SI::s];
        attribute maxOperatingDepth : ISQ::LengthValue = 1000.0 [SI::m];
        
        part transducer : SplitBeamTransducer {
            attribute nominalFrequency = 38000.0 [SI::Hz];
            attribute beamWidth = 7.0;
            attribute maxDepth = 1000.0 [SI::m];
        }
        
        part processor : EchosounderProcessor;
        
        part analyzer : BiomassAnalyzer;
        
        part navigation : GPSNavigationSystem {
            attribute currentPosition = (0.0, 0.0, 0.0);
            attribute currentSpeed = 5.0 [SI::m/SI::s];
        }
        
        part recorder : DataRecorder;
        
        port systemDataOutput : DataPort;
        
        connect transducer.transducerPort to processor.processingInput;
        
        perform action surveyOperation : ConductAcousticSurvey {
            in surveyFrequency = operatingFrequency;
            in pingRate = 1.0 [SI::Hz];
            in surveyDuration = 3600.0 [SI::s];
            in depthRange = maxOperatingDepth;
            out surveyResults : SurveyData;
        }
        
        exhibit state operationStates : SurveyOperationStates;
    }
    
    requirement def SystemPerformanceRequirement {
        doc /* Performance requirements for fisheries acoustic system */
    }
    
    requirement def DetectionCapabilityRequirement :> SystemPerformanceRequirement {
        doc /* System shall detect fish targets across specified depth range */
        subject system : FisheriesAcousticSystem;
        require constraint {
            system.maxOperatingDepth >= 500.0 [SI::m] and
            system.operatingFrequency >= 18000.0 [SI::Hz] and
            system.operatingFrequency <= 200000.0 [SI::Hz]
        }
    }
    
    requirement def BiomassEstimationRequirement :> SystemPerformanceRequirement {
        doc /* Biomass estimates shall meet scientific accuracy standards */
        subject analyzer : BiomassAnalyzer;
        require constraint {
            doc /* Biomass estimation coefficient of variation < 20% */
        }
    }
    
    requirement def SpatialResolutionRequirement :> SystemPerformanceRequirement {
        doc /* System shall provide adequate spatial resolution for stock assessment */
        subject transducer : SplitBeamTransducer;
        require constraint {
            transducer.beamWidth <= 10.0
        }
    }
    
    requirement def DataQualityRequirement :> SystemPerformanceRequirement {
        doc /* Acoustic data shall meet quality standards for scientific analysis */
        subject system : FisheriesAcousticSystem;
        require constraint {
            doc /* Signal-to-noise ratio > 20 dB for valid detections */
        }
    }
    
    requirement fisheriesAcousticMission {
        doc /* 
            Primary Mission: Conduct quantitative acoustic surveys of fish populations
            to provide scientific data for sustainable fisheries management and marine
            ecosystem assessment. The system transmits acoustic pulses, receives echoes
            from fish and aggregations, processes signals to identify and classify targets,
            and generates accurate estimates of fish abundance and biomass distribution.
        */
        
        requirement detectTargets : DetectionCapabilityRequirement;
        requirement estimateStock : BiomassEstimationRequirement;
        requirement spatialAccuracy : SpatialResolutionRequirement;
        requirement dataIntegrity : DataQualityRequirement;
        
        require constraint missionSuccess {
            doc /* 
                System shall successfully transmit acoustic signals, detect fish echoes,
                process backscatter data, classify targets by species and size, and
                generate scientifically valid biomass estimates for fisheries stock
                assessment and ecosystem-based management decisions.
            */
        }
    }
}
