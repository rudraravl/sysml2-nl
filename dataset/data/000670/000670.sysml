package 'Lung Counter System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def ActivityConcentration :> Real {
        doc /* Activity per unit volume in Becquerels per cubic meter */
    }

    attribute def ActivityValue :> Real {
        doc /* Activity in Becquerels */
    }

    attribute def CountRate :> Real {
        doc /* Count rate in counts per second */
    }

    item def GammaPhoton {
        attribute energy : ISQ::EnergyValue;
        attribute timestamp : ISQ::TimeValue;
    }

    item def EnergySpectrum {
        attribute channelCount : Integer;
        attribute countsPerChannel : Integer[*];
        attribute energyCalibration : ISQ::EnergyValue[*];
    }

    item def MeasurementResult {
        attribute totalCounts : Integer;
        attribute countRate : CountRate;
        attribute measuredActivity : ActivityValue;
        attribute backgroundSubtracted : Boolean;
        attribute acquisitionTime : ISQ::TimeValue;
        attribute detectedNuclides : String[*];
    }

    item def Subject {
        attribute identifier : String;
        attribute height : ISQ::LengthValue;
        attribute weight : ISQ::MassValue;
        attribute chestThickness : ISQ::LengthValue;
    }

    port def GammaDetectionPort {
        in photon : GammaPhoton;
        out pulseSignal : Real;
    }

    port def DataPort {
        in spectrum : EnergySpectrum;
        out result : MeasurementResult;
    }

    port def ControlPort {
        in startCommand : Boolean;
        in stopCommand : Boolean;
        out systemStatus : String;
    }

    part def DetectorArray {
        doc /* Array of scintillation detectors positioned around subject's thorax */
        attribute detectorCount : Integer = 4;
        attribute detectorMaterial : String = "NaI(Tl)";
        attribute crystalDimension : ISQ::LengthValue;
        port detectionPorts : GammaDetectionPort[4];
        port dataOut : ~DataPort;
    }

    part def LeadShielding {
        doc /* Lead shield to reduce environmental background radiation */
        attribute thickness : ISQ::LengthValue;
        attribute innerDimension : ISQ::LengthValue;
        port gammaAttenuation;
    }

    part def PositioningChair {
        doc /* Adjustable chair for reproducible subject positioning */
        attribute heightAdjustment : ISQ::LengthValue;
        attribute backrestAngle : Real;
        port subjectSupport;
    }

    part def MultiChannelAnalyzer {
        doc /* Digitizes and bins detector pulses by energy */
        attribute channelCount : Integer = 1024;
        attribute energyRange : ISQ::EnergyValue;
        port pulseIn : ~GammaDetectionPort;
        port spectrumOut : DataPort;
    }

    part def AnalysisComputer {
        doc /* Processes spectrum and calculates activity */
        attribute calibrationFactor : Real;
        attribute backgroundSpectrum : EnergySpectrum;
        port spectrumIn : ~DataPort;
        port resultOut : DataPort;
        port control : ControlPort;
    }

    part def DisplayConsole {
        doc /* Operator interface for control and result display */
        port resultIn : ~DataPort;
        port controlOut : ~ControlPort;
    }

    action def PositionSubject {
        in subject : Subject;
        in chairHeight : ISQ::LengthValue;
        out positioned : Boolean;
    }

    action def AcquireBackground {
        in duration : ISQ::TimeValue;
        out backgroundSpectrum : EnergySpectrum;
    }

    action def AcquireSubjectSpectrum {
        in subject : Subject;
        in duration : ISQ::TimeValue;
        out rawSpectrum : EnergySpectrum;
    }

    action def SubtractBackground {
        in rawSpectrum : EnergySpectrum;
        in backgroundSpectrum : EnergySpectrum;
        out netSpectrum : EnergySpectrum;
    }

    action def IdentifyPeaks {
        in netSpectrum : EnergySpectrum;
        out peakEnergies : ISQ::EnergyValue[*];
        out peakAreas : Integer[*];
    }

    action def CalculateActivity {
        in peakAreas : Integer[*];
        in peakEnergies : ISQ::EnergyValue[*];
        in calibrationFactor : Real;
        in subject : Subject;
        out measuredActivity : ActivityValue;
        out nuclides : String[*];
    }

    action def PerformLungCount {
        doc /* Complete measurement workflow from positioning to result */
        in subject : Subject;
        in measurementDuration : ISQ::TimeValue;
        in backgroundDuration : ISQ::TimeValue;
        out result : MeasurementResult;

        first start;
        then action position : PositionSubject {
            in subject = PerformLungCount::subject;
            out positioned;
        }
        then action acquireBackground : AcquireBackground {
            in duration = PerformLungCount::backgroundDuration;
            out backgroundSpectrum;
        }
        then action acquireSubject : AcquireSubjectSpectrum {
            in subject = PerformLungCount::subject;
            in duration = PerformLungCount::measurementDuration;
            out rawSpectrum;
        }
        then action subtract : SubtractBackground {
            in rawSpectrum = acquireSubject.rawSpectrum;
            in backgroundSpectrum = acquireBackground.backgroundSpectrum;
            out netSpectrum;
        }
        then action identifyPeaks : IdentifyPeaks {
            in netSpectrum = subtract.netSpectrum;
            out peakEnergies;
            out peakAreas;
        }
        then action calculate : CalculateActivity {
            in peakAreas = identifyPeaks.peakAreas;
            in peakEnergies = identifyPeaks.peakEnergies;
            in subject = PerformLungCount::subject;
            out measuredActivity;
            out nuclides;
        }
        then done;
    }

    state machine def LungCounterOperation {
        initial state Idle;
        state Positioning;
        state BackgroundAcquisition;
        state SubjectAcquisition;
        state Analysis;
        state ReportingResults;

        transition from Idle to Positioning
            accept startCommand;
        transition from Positioning to BackgroundAcquisition
            when positioned;
        transition from BackgroundAcquisition to SubjectAcquisition
            when backgroundComplete;
        transition from SubjectAcquisition to Analysis
            when acquisitionComplete;
        transition from Analysis to ReportingResults
            when analysisComplete;
        transition from ReportingResults to Idle
            when resultDisplayed;
    }

    part def LungCounter {
        doc /* Whole-body counter specialized for thoracic region measurement */
        port operatorInterface;
        port measurementOutput : DataPort;
    }

    part lungCounterSystem : LungCounter {
        doc /* Complete lung counter system for internal contamination assessment */
        
        part shielding : LeadShielding {
            attribute thickness = 100.0;
        }
        
        part chair : PositioningChair;
        
        part detectors : DetectorArray {
            attribute detectorCount = 4;
        }
        
        part mca : MultiChannelAnalyzer {
            attribute channelCount = 1024;
        }
        
        part computer : AnalysisComputer;
        
        part console : DisplayConsole;

        connect detectors.dataOut to mca.pulseIn;
        connect mca.spectrumOut to computer.spectrumIn;
        connect computer.resultOut to console.resultIn;
        connect console.controlOut to computer.control;

        perform action measurement : PerformLungCount;
        behavior operation : LungCounterOperation;
    }

    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;

    requirement <'REQ-001'> primaryFunction : FunctionalRequirement {
        doc /* The lung counter system shall detect and quantify gamma-emitting 
             radionuclides deposited in the thoracic region of a subject to assess 
             internal contamination from occupational or accidental exposure. */
        subject lungCounterSystem;
    }

    requirement <'REQ-002'> minimumDetectableActivity : PerformanceRequirement {
        doc /* The system shall achieve a minimum detectable activity of 50 Bq 
             for Cs-137 in a standard adult thorax with 20-minute count time. */
        subject lungCounterSystem;
    }

    requirement <'REQ-003'> backgroundReduction : PerformanceRequirement {
        doc /* The lead shielding shall reduce environmental background radiation 
             by at least a factor of 100 for energies between 100 keV and 2 MeV. */
        subject lungCounterSystem.shielding;
    }

    requirement <'REQ-004'> reproducibility : PerformanceRequirement {
        doc /* Repeated measurements of the same subject shall yield results 
             within ±10% coefficient of variation. */
        subject lungCounterSystem;
    }

    requirement <'REQ-005'> safetyCompliance : SafetyRequirement {
        doc /* The system shall comply with radiation safety standards for 
             occupational monitoring and maintain ALARA principles. */
        subject lungCounterSystem;
    }

    satisfy primaryFunction by lungCounterSystem;
    satisfy minimumDetectableActivity by lungCounterSystem;
    satisfy backgroundReduction by lungCounterSystem.shielding;
    satisfy reproducibility by lungCounterSystem;
    satisfy safetyCompliance by lungCounterSystem;
}
