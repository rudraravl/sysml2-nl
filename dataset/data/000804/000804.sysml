package TruenatMolecularDiagnosticSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SampleIdentifier;
    attribute def PathogenType;
    attribute def TestResultStatus;
    
    enum def DiagnosticOutcome {
        detected;
        notDetected;
        invalid;
        inconclusive;
    }
    
    enum def SystemMode {
        standby;
        sampleLoading;
        processing;
        analyzing;
        reporting;
        error;
    }
    
    attribute def Temperature :> ISQ::TemperatureValue;
    attribute def Time :> ISQ::TimeValue;
    attribute def Volume :> ISQ::VolumeValue;
    attribute def Concentration :> Real;
    
    item def BiologicalSample {
        attribute sampleID : SampleIdentifier;
        attribute volume : Volume;
        attribute collectionTimestamp : Time;
        attribute patientID : String;
    }
    
    item def TruenatChip {
        attribute chipID : String;
        attribute targetPathogen : PathogenType;
        attribute lotNumber : String;
        attribute expiryDate : String;
    }
    
    item def LysisBuffer {
        attribute bufferType : String;
        attribute volume : Volume;
        attribute pH : Real;
    }
    
    item def DiagnosticReport {
        attribute reportID : String;
        attribute sampleID : SampleIdentifier;
        attribute outcome : DiagnosticOutcome;
        attribute cycleThreshold : Real;
        attribute testDuration : Time;
        attribute timestamp : String;
    }
    
    port def SampleInputPort {
        in item biologicalSample : BiologicalSample;
    }
    
    port def ChipInputPort {
        in item chip : TruenatChip;
    }
    
    port def ReportOutputPort {
        out item report : DiagnosticReport;
    }
    
    port def PowerSupplyPort {
        in attribute voltage : Real;
        in attribute current : Real;
        attribute power : Real;
    }
    
    port def DataCommunicationPort {
        out attribute testData : String;
        in attribute controlCommand : String;
    }
    
    part def SamplePreparationUnit {
        port sampleIn : SampleInputPort;
        port chipIn : ChipInputPort;
        
        attribute lysisComplete : Boolean;
        attribute extractionComplete : Boolean;
        
        action prepareBiologicalSample {
            in rawSample : BiologicalSample;
            in chip : TruenatChip;
            in buffer : LysisBuffer;
            out processedSample : BiologicalSample;
            
            first start;
            then action loadSample {
                in inputSample = rawSample;
                doc /* Transfer biological sample into preparation chamber */
            }
            then action addLysisBuffer {
                in lysisBuffer = buffer;
                doc /* Add lysis buffer to break down cellular structures */
            }
            then action performLysis {
                doc /* Lyse cells to release nucleic acids */
                attribute lysisTemperature : Temperature;
                attribute lysisDuration : Time;
            }
            then action extractNucleicAcid {
                doc /* Extract and purify RNA/DNA from lysed sample */
            }
            then action transferToChip {
                in targetChip = chip;
                doc /* Load purified nucleic acid onto Truenat chip */
            }
            then assign processedSample := rawSample;
            then done;
        }
    }
    
    part def AmplificationUnit {
        attribute currentCycle : Integer;
        attribute targetCycles : Integer;
        attribute currentTemperature : Temperature;
        
        action performRealTimePCR {
            in preparedSample : BiologicalSample;
            in cycleCount : Integer;
            out amplificationData : Real[*];
            out ctValue : Real;
            
            first start;
            then merge cycleLoop;
            then action denaturePhase {
                doc /* Heat to 95°C to denature double-stranded DNA */
                attribute denatureTemp : Temperature = 368.15[SI::K];
                attribute denaturationTime : Time = 15.0[SI::s];
            }
            then action annealPhase {
                doc /* Cool to 55-60°C for primer annealing */
                attribute annealTemp : Temperature = 328.15[SI::K];
                attribute annealingTime : Time = 20.0[SI::s];
            }
            then action extensionPhase {
                doc /* Heat to 72°C for DNA polymerase extension */
                attribute extensionTemp : Temperature = 345.15[SI::K];
                attribute extensionTime : Time = 30.0[SI::s];
            }
            then action measureFluorescence {
                doc /* Capture fluorescence signal at end of each cycle */
                out fluorescenceIntensity : Real;
            }
            then decide;
                if currentCycle < cycleCount then cycleLoop;
                if currentCycle >= cycleCount then calculateCt;
            action calculateCt {
                doc /* Calculate cycle threshold from fluorescence data */
                out thresholdCycle = ctValue;
            }
            then done;
        }
    }
    
    part def OpticalDetectionUnit {
        attribute fluorescenceThreshold : Real;
        attribute baselineNoise : Real;
        
        action detectAndAnalyze {
            in fluorescenceProfile : Real[*];
            in thresholdCycle : Real;
            out detectionOutcome : DiagnosticOutcome;
            
            first start;
            then action establishBaseline {
                doc /* Determine baseline fluorescence from early cycles */
            }
            then action identifyAmplification {
                doc /* Detect exponential amplification curve */
            }
            then action validateSignal {
                doc /* Validate signal against quality control criteria */
            }
            then decide;
                if thresholdCycle < 35.0 then positiveDetection;
                if thresholdCycle >= 35.0 and thresholdCycle < 40.0 then weakPositive;
                if thresholdCycle >= 40.0 then negativeDetection;
            action positiveDetection {
                then assign detectionOutcome := DiagnosticOutcome::detected;
            }
            action weakPositive {
                then assign detectionOutcome := DiagnosticOutcome::inconclusive;
            }
            action negativeDetection {
                then assign detectionOutcome := DiagnosticOutcome::notDetected;
            }
            then done;
        }
    }
    
    part def ControlAndProcessingUnit {
        attribute operatingMode : SystemMode;
        attribute errorCode : String;
        
        state machine def SystemControllerMachine {
            entry; then powerOn;
            
            state powerOn;
            
            state idle {
                entry action initializeSystem {
                    doc /* Initialize all subsystems and perform self-check */
                }
            }
            
            state sampleProcessing {
                entry action startProcessing;
                do action monitorProgress;
            }
            
            state amplificationInProgress {
                entry action beginAmplification;
                do action trackCycles;
            }
            
            state analysisComplete {
                entry action finalizeResults;
            }
            
            state errorState {
                entry action logError;
            }
            
            transition powerOn_to_idle first powerOn then idle;
            
            transition idle_to_processing first idle accept sampleLoaded then sampleProcessing;
            
            transition processing_to_amplification first sampleProcessing accept preparationComplete then amplificationInProgress;
            
            transition amplification_to_analysis first amplificationInProgress accept amplificationComplete then analysisComplete;
            
            transition analysis_to_idle first analysisComplete accept reportGenerated then idle;
            
            transition any_to_error accept systemError then errorState;
            
            transition error_to_idle first errorState accept errorCleared then idle;
        }
        
        state systemController : SystemControllerMachine;
        
        action coordinateTest {
            in sample : BiologicalSample;
            in chip : TruenatChip;
            out finalReport : DiagnosticReport;
            
            first start;
            then action validateInputs {
                doc /* Verify sample and chip compatibility and validity */
            }
            then action initiatePreparation;
            then action initiateAmplification;
            then action initiateDetection;
            then action compileReport {
                doc /* Generate comprehensive diagnostic report */
                out report = finalReport;
            }
            then done;
        }
    }
    
    part def UserInterfaceModule {
        attribute displayMessage : String;
        attribute userInput : String;
        
        action displayTestProgress {
            in currentStage : String;
            in percentComplete : Real;
            out displayUpdate : Boolean;
        }
        
        action presentResults {
            in report : DiagnosticReport;
            out displayComplete : Boolean;
            
            first start;
            then action formatReport {
                doc /* Format report for user-friendly display */
            }
            then action showOutcome {
                doc /* Display test outcome prominently */
            }
            then action showDetails {
                doc /* Display detailed test parameters and metrics */
            }
            then done;
        }
        
        action acceptUserCommand {
            out command : String;
            out testParameters : String;
        }
    }
    
    part def ThermalManagementUnit {
        attribute heaterTemperature : Temperature;
        attribute coolerTemperature : Temperature;
        
        action regulateTemperature {
            in targetTemp : Temperature;
            in duration : Time;
            out actualTemp : Temperature;
            
            first start;
            then merge controlLoop;
            then action measureTemp {
                out currentTemp : Temperature;
            }
            then decide;
                if currentTemp < targetTemp then heat;
                if currentTemp > targetTemp then cool;
                if currentTemp == targetTemp then maintain;
            action heat {
                doc /* Activate heating element */
            }
            action cool {
                doc /* Activate cooling system */
            }
            action maintain {
                doc /* Maintain current temperature */
            }
            then controlLoop;
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* 
            The Truenat molecular diagnostic system shall perform rapid, 
            portable, chip-based real-time PCR analysis to detect and identify 
            specific pathogens or genetic markers in biological samples at the 
            point of care, delivering accurate diagnostic results within 60 minutes.
        */
        
        require constraint rapidDiagnostics {
            doc /* Total test time from sample loading to result shall not exceed 60 minutes */
        }
        
        require constraint portableOperation {
            doc /* System shall be battery-operable and weigh less than 4 kg for field deployment */
        }
        
        require constraint chipBasedDetection {
            doc /* System shall utilize disposable microfluidic chips for contamination-free testing */
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* The system shall meet clinical performance standards */
        
        require constraint clinicalSensitivity {
            doc /* Analytical sensitivity shall detect target at concentrations below 100 copies/mL */
        }
        
        require constraint clinicalSpecificity {
            doc /* Specificity shall exceed 98% with minimal cross-reactivity */
        }
        
        require constraint reproducibility {
            doc /* Coefficient of variation for replicate tests shall be less than 5% */
        }
    }
    
    requirement def SafetyAndComplianceRequirement {
        doc /* The system shall comply with medical device safety standards */
        
        require constraint biocontainment {
            doc /* System shall prevent exposure to biological samples during operation */
        }
        
        require constraint electricalSafety {
            doc /* System shall meet IEC 60601-1 electrical safety standards */
        }
    }
    
    part def TruenatMolecularDiagnosticPlatform {
        doc /* 
            Complete Truenat molecular diagnostic platform integrating sample preparation, 
            real-time PCR amplification, optical detection, and automated result reporting 
            for rapid point-of-care pathogen detection.
        */
    }
    
    part truenatSystem : TruenatMolecularDiagnosticPlatform {
        doc /* 
            Truenat is a portable, battery-operated, chip-based real-time micro-PCR 
            platform designed for rapid molecular diagnostics at point-of-care settings. 
            The system integrates automated sample preparation, nucleic acid amplification, 
            and real-time fluorescence detection to identify specific pathogens or genetic 
            markers in biological samples. Its primary function is to enable accurate, 
            rapid diagnosis of infectious diseases in resource-limited settings, field 
            hospitals, and remote locations where traditional laboratory infrastructure 
            is unavailable.
        */
        
        port sampleInput : SampleInputPort;
        port chipInput : ChipInputPort;
        port reportOutput : ReportOutputPort;
        port powerSupply : PowerSupplyPort;
        port dataComm : DataCommunicationPort;
        
        part preparationModule : SamplePreparationUnit {
            port :>> sampleIn;
            port :>> chipIn;
        }
        
        part amplificationModule : AmplificationUnit;
        
        part detectionModule : OpticalDetectionUnit;
        
        part controlModule : ControlAndProcessingUnit;
        
        part userInterface : UserInterfaceModule;
        
        part thermalControl : ThermalManagementUnit;
        
        connect sampleInput to preparationModule.sampleIn;
        connect chipInput to preparationModule.chipIn;
        
        perform action executeMolecularDiagnostic {
            in patientSample : BiologicalSample;
            in diagnosticChip : TruenatChip;
            out diagnosticReport : DiagnosticReport;
            
            first start;
            then action preparation : preparationModule.prepareBiologicalSample {
                in rawSample = patientSample;
                in chip = diagnosticChip;
                in buffer;
                out processedSample;
            }
            then action amplification : amplificationModule.performRealTimePCR {
                in preparedSample = preparation.processedSample;
                in cycleCount = 40;
                out amplificationData;
                out ctValue;
            }
            then action detection : detectionModule.detectAndAnalyze {
                in fluorescenceProfile = amplification.amplificationData;
                in thresholdCycle = amplification.ctValue;
                out detectionOutcome;
            }
            then action reporting : userInterface.presentResults {
                in report;
                out displayComplete;
            }
            then assign diagnosticReport := report;
            then done;
        }
        
        satisfy primaryFunction : PrimaryFunctionRequirement;
        satisfy performance : PerformanceRequirement;
        satisfy safetyCompliance : SafetyAndComplianceRequirement;
    }
}
