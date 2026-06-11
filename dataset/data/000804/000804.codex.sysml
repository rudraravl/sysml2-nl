package TruenatBasedMolecularDiagnosticSystem {

    import ScalarValues::*;
    import ISQ::*;

    attribute def Probability : Real {
        doc /* Unitless probability in the closed interval [0,1]. */
    }

    attribute def TemperatureC : Real {
        unit = "degC";
    }

    attribute def Time_min : Real {
        unit = "min";
    }

    attribute def Time_s : Real {
        unit = "s";
    }

    attribute def Volume_uL : Real {
        unit = "uL";
    }

    attribute def Mass_mg : Real {
        unit = "mg";
    }

    attribute def Speed_rpm : Real {
        unit = "rpm";
    }

    attribute def Voltage_V : Real {
        unit = "V";
    }

    attribute def Power_W : Real {
        unit = "W";
    }

    attribute def Cycles : Integer;

    enum def SampleKind {
        enum sputum;
        enum nasalSwab;
        enum blood;
        enum plasma;
        enum stool;
        enum extractedNucleicAcid;
        enum externalControl;
    }

    enum def AssayTarget {
        enum tuberculosisComplex;
        enum rifampicinResistanceMarker;
        enum sarsCov2;
        enum humanPapillomavirus;
        enum hepatitisB;
        enum malariaParasite;
        enum internalProcessControl;
    }

    enum def DiagnosticCall {
        enum detected;
        enum notDetected;
        enum invalid;
        enum inhibited;
        enum instrumentError;
    }

    enum def CartridgeStatus {
        enum sealed;
        enum loaded;
        enum running;
        enum complete;
        enum rejected;
        enum disposed;
    }

    enum def AnalyzerStateKind {
        enum off;
        enum idle;
        enum selfTest;
        enum ready;
        enum assayRunning;
        enum reporting;
        enum fault;
        enum shutdown;
    }

    item def ClinicalSample {
        attribute sampleId : String;
        attribute kind : SampleKind;
        attribute collectedAt : String;
        attribute volume : Volume_uL;
        attribute minimumRequiredVolume : Volume_uL = 500.0;
        attribute biohazardous : Boolean = true;
    }

    item def PreparedLysate {
        attribute sourceSampleId : String;
        attribute lysateVolume : Volume_uL;
        attribute nucleicAcidReleased : Boolean;
        attribute inhibitorRisk : Probability;
    }

    item def PurifiedNucleicAcid {
        attribute sourceSampleId : String;
        attribute elutionVolume : Volume_uL;
        attribute estimatedConcentration : Mass_mg;
        attribute purityIndex : Real;
    }

    item def ReagentPack {
        attribute lotId : String;
        attribute expiryDate : String;
        attribute target : AssayTarget;
        attribute hydrated : Boolean;
    }

    item def MicroPCRCartridge {
        attribute cartridgeId : String;
        attribute assayTarget : AssayTarget;
        attribute status : CartridgeStatus = CartridgeStatus::sealed;
        attribute reactionVolume : Volume_uL = 6.0;
        attribute sealedClosed : Boolean = true;
        attribute singleUse : Boolean = true;
    }

    item def AmplificationSignal {
        attribute target : AssayTarget;
        attribute cycleThreshold : Real;
        attribute fluorescenceEndpoint : Real;
        attribute baselineStable : Boolean;
        attribute internalControlPassed : Boolean;
    }

    item def DiagnosticResult {
        attribute sampleId : String;
        attribute assayTarget : AssayTarget;
        attribute call : DiagnosticCall;
        attribute cycleThreshold : Real;
        attribute confidence : Probability;
        attribute generatedAt : String;
        attribute operatorVisible : Boolean = true;
    }

    port def SampleInPort {
        in item sample : ClinicalSample;
    }

    port def LysatePort {
        out item lysate : PreparedLysate;
    }

    port def NucleicAcidPort {
        inout item extract : PurifiedNucleicAcid;
    }

    port def CartridgePort {
        inout item cartridge : MicroPCRCartridge;
    }

    port def SignalPort {
        out item signal : AmplificationSignal;
    }

    port def ResultPort {
        out item result : DiagnosticResult;
    }

    port def OperatorCommandPort {
        in item command : String;
        out item prompt : String;
    }

    port def PowerPort {
        in attribute supplyVoltage : Voltage_V;
        out attribute powerDraw : Power_W;
    }

    port def DataPort {
        out item result : DiagnosticResult;
        in item patientOrderId : String;
    }

    action def AcceptSample {
        in item sample : ClinicalSample;
        out item acceptedSample : ClinicalSample;
        assert constraint {
            sample.volume >= sample.minimumRequiredVolume
        }
    }

    action def LyseSample {
        in item sample : ClinicalSample;
        in item reagentPack : ReagentPack;
        out item lysate : PreparedLysate;

        attribute lysisTime : Time_min = 3.0;
        attribute lysisTemperature : TemperatureC = 25.0;
    }

    action def ExtractNucleicAcid {
        in item lysate : PreparedLysate;
        out item extract : PurifiedNucleicAcid;

        attribute extractionTime : Time_min = 12.0;
        attribute elutionVolume : Volume_uL = 50.0;
        attribute washCycles : Cycles = 2;
    }

    action def LoadCartridge {
        in item extract : PurifiedNucleicAcid;
        inout item cartridge : MicroPCRCartridge;
        out item loadedCartridge : MicroPCRCartridge;

        attribute loadedVolume : Volume_uL = 6.0;
    }

    action def RunMicroPCR {
        inout item cartridge : MicroPCRCartridge;
        out item signal : AmplificationSignal;

        attribute denaturationTemperature : TemperatureC = 95.0;
        attribute annealingTemperature : TemperatureC = 60.0;
        attribute extensionTemperature : TemperatureC = 72.0;
        attribute cycleCount : Cycles = 40;
        attribute maximumRunTime : Time_min = 35.0;
    }

    action def InterpretAmplification {
        in item signal : AmplificationSignal;
        out item result : DiagnosticResult;

        attribute detectionCtLimit : Real = 35.0;
        attribute invalidWhenInternalControlFails : Boolean = true;
    }

    action def ReportResult {
        in item result : DiagnosticResult;
        out item reportedResult : DiagnosticResult;

        attribute localDisplayEnabled : Boolean = true;
        attribute exportEnabled : Boolean = true;
    }

    state def AnalyzerLifecycle {
        entry; then Off;

        state Off;
        state Idle;
        state SelfTest;
        state Ready;
        state AssayRunning;
        state Reporting;
        state Fault;
        state Shutdown;

        transition PowerApplied
            first Off
            then SelfTest;

        transition SelfTestPassed
            first SelfTest
            then Ready;

        transition SelfTestFailed
            first SelfTest
            then Fault;

        transition OperatorStartsRun
            first Ready
            then AssayRunning;

        transition RunCompleted
            first AssayRunning
            then Reporting;

        transition ReportStored
            first Reporting
            then Ready;

        transition RecoverableError
            first AssayRunning
            then Fault;

        transition FaultCleared
            first Fault
            then SelfTest;

        transition PowerRemoved
            first Ready
            then Shutdown;

        transition ShutdownComplete
            first Shutdown
            then Off;
    }

    part def BatteryBackedPowerModule {
        port powerOut : PowerPort;

        attribute nominalVoltage : Voltage_V = 12.0;
        attribute maximumContinuousPower : Power_W = 65.0;
        attribute minimumRuntime : Time_min = 480.0;
        attribute mainsAdapterSupported : Boolean = true;
    }

    part def SamplePreparationModule {
        port sampleIn : SampleInPort;
        port lysateOut : LysatePort;
        port operatorInterface : OperatorCommandPort;

        part heater;
        part mixingMotor;

        item reagentPack : ReagentPack;

        attribute lysisTemperatureSetpoint : TemperatureC = 25.0;
        attribute preparationTime : Time_min = 5.0;
        attribute maximumHandsOnSteps : Integer = 3;

        perform action accept : AcceptSample;
        perform action lyse : LyseSample;
    }

    part def NucleicAcidExtractionModule {
        port lysateIn : LysatePort;
        port extractOut : NucleicAcidPort;
        port operatorInterface : OperatorCommandPort;

        part extractionChip;
        part washReservoir;
        part wasteChamber;

        attribute extractionTime : Time_min = 12.0;
        attribute elutionVolume : Volume_uL = 50.0;
        attribute centrifugeEquivalentSpeed : Speed_rpm = 0.0;
        attribute closedFluidPath : Boolean = true;

        perform action extract : ExtractNucleicAcid;
    }

    part def MicroPCRAnalyzerModule {
        port cartridgeInterface : CartridgePort;
        port signalOut : SignalPort;
        port operatorInterface : OperatorCommandPort;
        port powerIn : PowerPort;

        part thermalBlock;
        part fluorescenceDetector;
        part cartridgeLatch;
        part opticalCalibrationReference;

        attribute analyzerState : AnalyzerStateKind = AnalyzerStateKind::off;
        attribute temperatureAccuracy : TemperatureC = 0.5;
        attribute fluorescenceSamplingPeriod : Time_s = 1.0;
        attribute maximumPCRRunTime : Time_min = 35.0;
        attribute supportedCycleCount : Cycles = 40;

        perform state lifecycle : AnalyzerLifecycle;
        perform action load : LoadCartridge;
        perform action amplify : RunMicroPCR;
    }

    part def ResultProcessingModule {
        port signalIn : SignalPort;
        port resultOut : ResultPort;
        port dataExchange : DataPort;

        part rulesEngine;
        part resultStore;
        part displayController;

        attribute positiveCtThreshold : Real = 35.0;
        attribute borderlineCtThreshold : Real = 38.0;
        attribute minimumInternalControlConfidence : Probability = 0.95;
        attribute localStorageCapacityResults : Integer = 10000;

        perform action interpret : InterpretAmplification;
        perform action report : ReportResult;
    }

    part def OperatorInterface {
        port samplePrepCommands : OperatorCommandPort;
        port extractionCommands : OperatorCommandPort;
        port analyzerCommands : OperatorCommandPort;

        part touchDisplay;
        part barcodeScanner;
        part statusIndicators;
        part printerInterface;

        attribute displaySizeInches : Real = 7.0;
        attribute supportsGuidedWorkflow : Boolean = true;
        attribute supportsBarcodeEntry : Boolean = true;
    }

    part def TruenatBasedSystem {
        doc /* Portable cartridge-based molecular diagnostic system whose primary high-level function is to convert a patient sample into a clinically interpretable nucleic-acid amplification result near the point of care. */

        port sampleInput : SampleInPort;
        port diagnosticOutput : ResultPort;
        port powerInput : PowerPort;
        port dataOutput : DataPort;

        part power : BatteryBackedPowerModule;
        part preparation : SamplePreparationModule;
        part extraction : NucleicAcidExtractionModule;
        part analyzer : MicroPCRAnalyzerModule;
        part resultProcessing : ResultProcessingModule;
        part userInterface : OperatorInterface;

        item currentSample : ClinicalSample;
        item currentLysate : PreparedLysate;
        item currentExtract : PurifiedNucleicAcid;
        item currentCartridge : MicroPCRCartridge;
        item currentSignal : AmplificationSignal;
        item currentResult : DiagnosticResult;

        attribute portable : Boolean = true;
        attribute intendedUseEnvironment : String = "near-patient laboratory, primary health center, mobile clinic, or decentralized diagnostic site";
        attribute nominalSampleToResultTime : Time_min = 60.0;
        attribute maximumSampleToResultTime : Time_min = 90.0;
        attribute singleUseCartridgeRequired : Boolean = true;
        attribute closedAmplificationConsumable : Boolean = true;
        attribute biosafetyContainmentExpected : Boolean = true;

        connect sampleInput to preparation.sampleIn;
        connect preparation.lysateOut to extraction.lysateIn;
        connect extraction.extractOut to analyzer.cartridgeInterface;
        connect analyzer.signalOut to resultProcessing.signalIn;
        connect resultProcessing.resultOut to diagnosticOutput;
        connect resultProcessing.dataExchange to dataOutput;
        connect powerInput to power.powerOut;
        connect power.powerOut to analyzer.powerIn;
        connect userInterface.samplePrepCommands to preparation.operatorInterface;
        connect userInterface.extractionCommands to extraction.operatorInterface;
        connect userInterface.analyzerCommands to analyzer.operatorInterface;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall perform decentralized molecular testing by accepting a prepared clinical sample, releasing and purifying nucleic acid, amplifying target sequences in a sealed micro-PCR cartridge, detecting amplification, interpreting the signal, and reporting a diagnostic result. */

        subject system : TruenatBasedSystem;

        require constraint {
            system.nominalSampleToResultTime <= 60.0
        }

        require constraint {
            system.closedAmplificationConsumable == true
        }
    }

    requirement def PortabilityRequirement {
        doc /* The system shall support point-of-care deployment through compact construction and battery-backed operation. */

        subject system : TruenatBasedSystem;

        require constraint {
            system.portable == true
        }

        require constraint {
            system.power.minimumRuntime >= 480.0
        }
    }

    requirement def SampleContainmentRequirement {
        doc /* The system shall reduce operator exposure by maintaining a closed fluid path after sample preparation and using a sealed disposable amplification cartridge. */

        subject system : TruenatBasedSystem;

        require constraint {
            system.singleUseCartridgeRequired == true
        }

        require constraint {
            system.biosafetyContainmentExpected == true
        }
    }

    requirement def ResultQualityRequirement {
        doc /* The system shall report detected, not detected, invalid, inhibited, or instrument error results using target amplification and an internal process control. */

        subject processor : ResultProcessingModule;

        require constraint {
            processor.minimumInternalControlConfidence >= 0.95
        }

        require constraint {
            processor.positiveCtThreshold <= 35.0
        }
    }

    requirement def AssayWorkflowRequirement {
        doc /* The system shall guide the operator through sample acceptance, lysis, extraction, cartridge loading, amplification, interpretation, and reporting without requiring open-tube PCR handling. */

        subject system : TruenatBasedSystem;

        require constraint {
            system.preparation.maximumHandsOnSteps <= 3
        }

        require constraint {
            system.analyzer.maximumPCRRunTime <= 35.0
        }
    }

    satisfy PrimaryFunctionRequirement by TruenatBasedSystem;
    satisfy PortabilityRequirement by TruenatBasedSystem;
    satisfy SampleContainmentRequirement by TruenatBasedSystem;
    satisfy ResultQualityRequirement by ResultProcessingModule;
    satisfy AssayWorkflowRequirement by TruenatBasedSystem;

    part truenatBasedPointOfCareDiagnostic : TruenatBasedSystem {
        attribute nominalSampleToResultTime = 60.0;
        attribute maximumSampleToResultTime = 90.0;

        part preparation {
            item reagentPack {
                attribute lotId = "TN-MTB-RIF-LOT-2401";
                attribute expiryDate = "2027-12-31";
                attribute target = AssayTarget::tuberculosisComplex;
                attribute hydrated = false;
            }
        }

        item currentCartridge {
            attribute cartridgeId = "MTB-RIF-MICROPCR-0001";
            attribute assayTarget = AssayTarget::tuberculosisComplex;
            attribute reactionVolume = 6.0;
            attribute sealedClosed = true;
            attribute singleUse = true;
        }
    }
}