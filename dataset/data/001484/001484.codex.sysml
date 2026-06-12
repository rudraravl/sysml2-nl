package LaboratoryAutomationSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def SampleId :> String;
    attribute def TestOrderId :> String;
    attribute def ProtocolId :> String;
    attribute def ResultStatus :> String;

    enum def SampleCondition {
        enum normal;
        enum insufficientVolume;
        enum clotDetected;
        enum barcodeUnreadable;
        enum contaminated;
        enum expired;
    }

    enum def AutomationMode {
        enum standby;
        enum continuousProcessing;
        enum maintenance;
        enum emergencyStop;
    }

    enum def AssayPhase {
        enum accessioned;
        enum queued;
        enum prepared;
        enum analyzed;
        enum validated;
        enum archived;
        enum rejected;
    }

    item def BiologicalSample {
        attribute sampleId : SampleId;
        attribute orderId : TestOrderId;
        attribute condition : SampleCondition;
        attribute volume : VolumeValue;
        attribute temperature : TemperatureValue;
        attribute priority : Integer;
    }

    item def PreparedAliquot {
        attribute parentSampleId : SampleId;
        attribute aliquotVolume : VolumeValue;
        attribute reagentLot : String;
        attribute protocolId : ProtocolId;
    }

    item def Reagent {
        attribute lotNumber : String;
        attribute remainingVolume : VolumeValue;
        attribute expirationTime : TimeValue;
        attribute storageTemperature : TemperatureValue;
    }

    item def AssayResult {
        attribute sampleId : SampleId;
        attribute orderId : TestOrderId;
        attribute analyteName : String;
        attribute numericValue : Real;
        attribute unitText : String;
        attribute status : ResultStatus;
        attribute validationTime : TimeValue;
    }

    item def WasteMaterial {
        attribute sourceSampleId : SampleId;
        attribute liquidVolume : VolumeValue;
        attribute biohazardClass : String;
    }

    item def ControlCommand {
        attribute commandName : String;
        attribute targetModule : String;
        attribute issuedAt : TimeValue;
    }

    item def DiagnosticEvent {
        attribute eventCode : String;
        attribute severity : Integer;
        attribute message : String;
        attribute detectedAt : TimeValue;
    }

    attribute def VolumeValue :> ISQ::volume {
        unit = SI::millilitre;
    }

    attribute def TemperatureValue :> ISQ::thermodynamicTemperature {
        unit = SI::degreeCelsius;
    }

    attribute def TimeValue :> ISQ::time {
        unit = SI::second;
    }

    attribute def ThroughputValue {
        unit = 1 / SI::hour;
    }

    attribute def AccuracyValue {
        unit = SI::percent;
    }

    port def SampleInputPort {
        in item sample : BiologicalSample;
    }

    port def SampleOutputPort {
        out item sample : BiologicalSample;
    }

    port def AliquotPort {
        inout item aliquot : PreparedAliquot;
    }

    port def ReagentPort {
        in item reagent : Reagent;
    }

    port def ResultPort {
        out item result : AssayResult;
    }

    port def WastePort {
        out item waste : WasteMaterial;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def EventPort {
        out item event : DiagnosticEvent;
    }

    part def LaboratoryAutomationSystem {
        attribute primaryFunction : String = "Receive clinical laboratory samples, identify and route them, prepare aliquots with appropriate reagents, execute analytical assays, validate generated results, and report verified results to the laboratory information system with traceable handling and safe waste management.";
        attribute operatingMode : AutomationMode;
        attribute targetThroughput : ThroughputValue = 240 [1 / SI::hour];
        attribute minimumSampleVolume : VolumeValue = 0.5 [SI::millilitre];
        attribute nominalIncubatorTemperature : TemperatureValue = 37 [SI::degreeCelsius];
        attribute maximumResultLatency : TimeValue = 1800 [SI::second];

        port sampleEntry : SampleInputPort;
        port verifiedResultExit : ResultPort;
        port laboratoryCommandIn : CommandPort;
        port diagnosticEventOut : EventPort;
        port regulatedWasteOut : WastePort;

        part accessionStation : SampleAccessionStation;
        part roboticTransport : RoboticTransport;
        part centrifugeModule : CentrifugeModule;
        part liquidHandler : LiquidHandlingModule;
        part reagentManager : ReagentStorageModule;
        part analyzer : AnalyticalInstrument;
        part resultValidator : ResultValidationModule;
        part archiveStore : SampleArchiveStore;
        part wasteManager : WasteManagementModule;
        part supervisoryController : SupervisoryController;

        connection sampleEntry.sample to accessionStation.sampleIn.sample;
        connection accessionStation.identifiedSampleOut.sample to roboticTransport.sampleIn.sample;
        connection roboticTransport.sampleOut.sample to centrifugeModule.sampleIn.sample;
        connection centrifugeModule.processedSampleOut.sample to liquidHandler.sampleIn.sample;
        connection reagentManager.reagentOut.reagent to liquidHandler.reagentIn.reagent;
        connection liquidHandler.aliquotOut.aliquot to analyzer.aliquotIn.aliquot;
        connection analyzer.rawResultOut.result to resultValidator.rawResultIn.result;
        connection resultValidator.verifiedResultOut.result to verifiedResultExit.result;
        connection liquidHandler.remainingSampleOut.sample to archiveStore.sampleIn.sample;
        connection liquidHandler.wasteOut.waste to wasteManager.wasteIn.waste;
        connection analyzer.wasteOut.waste to wasteManager.wasteIn.waste;
        connection wasteManager.regulatedWasteOut.waste to regulatedWasteOut.waste;
        connection laboratoryCommandIn.command to supervisoryController.commandIn.command;
        connection accessionStation.eventOut.event to diagnosticEventOut.event;
        connection roboticTransport.eventOut.event to diagnosticEventOut.event;
        connection analyzer.eventOut.event to diagnosticEventOut.event;
        connection supervisoryController.eventOut.event to diagnosticEventOut.event;

        perform action processLaboratoryWorklist : ProcessLaboratoryWorklist;
        exhibit state automationState : LaboratoryAutomationStateMachine;
    }

    part def SampleAccessionStation {
        attribute scanAccuracy : AccuracyValue = 99.9 [SI::percent];
        attribute maxQueueDepth : Integer = 120;

        port sampleIn : SampleInputPort;
        port identifiedSampleOut : SampleOutputPort;
        port eventOut : EventPort;

        action scanBarcode {
            in item incoming : BiologicalSample;
            out item identified : BiologicalSample;
            out item event : DiagnosticEvent;
        }

        action checkAcceptability {
            in item identified : BiologicalSample;
            out item accepted : BiologicalSample;
            out item rejectionEvent : DiagnosticEvent;
        }
    }

    part def RoboticTransport {
        attribute payloadCapacity : Integer = 24;
        attribute positioningTolerance : LengthValue = 0.5 [SI::millimetre];

        port sampleIn : SampleInputPort;
        port sampleOut : SampleOutputPort;
        port commandIn : CommandPort;
        port eventOut : EventPort;

        action routeSample {
            in item sample : BiologicalSample;
            out item routedSample : BiologicalSample;
        }

        action recoverJam {
            out item event : DiagnosticEvent;
        }
    }

    part def CentrifugeModule {
        attribute maximumSpeed : FrequencyValue = 80 [SI::hertz];
        attribute nominalSpinTime : TimeValue = 600 [SI::second];
        attribute balanceTolerance : MassValue = 2 [SI::gram];

        port sampleIn : SampleInputPort;
        port processedSampleOut : SampleOutputPort;
        port eventOut : EventPort;

        action centrifugeSample {
            in item sample : BiologicalSample;
            out item separatedSample : BiologicalSample;
        }

        action verifyBalance {
            in item sample : BiologicalSample;
            out attribute balanced : Boolean;
        }
    }

    part def LiquidHandlingModule {
        attribute pipettingPrecision : VolumeValue = 0.002 [SI::millilitre];
        attribute deckCapacity : Integer = 96;
        attribute carryoverLimit : AccuracyValue = 0.1 [SI::percent];

        port sampleIn : SampleInputPort;
        port reagentIn : ReagentPort;
        port aliquotOut : AliquotPort;
        port remainingSampleOut : SampleOutputPort;
        port wasteOut : WastePort;
        port eventOut : EventPort;

        action aspirateSample {
            in item sample : BiologicalSample;
            out item meteredSample : BiologicalSample;
        }

        action dispenseAliquot {
            in item meteredSample : BiologicalSample;
            in item reagent : Reagent;
            out item aliquot : PreparedAliquot;
            out item waste : WasteMaterial;
        }

        action washProbe {
            out item waste : WasteMaterial;
        }
    }

    part def ReagentStorageModule {
        attribute storageSetpoint : TemperatureValue = 4 [SI::degreeCelsius];
        attribute capacity : Integer = 48;
        attribute minimumRemainingVolume : VolumeValue = 5 [SI::millilitre];

        port reagentOut : ReagentPort;
        port eventOut : EventPort;

        action selectReagent {
            in attribute protocolId : ProtocolId;
            out item reagent : Reagent;
        }

        action monitorInventory {
            out item event : DiagnosticEvent;
        }
    }

    part def AnalyticalInstrument {
        attribute assayTemperature : TemperatureValue = 37 [SI::degreeCelsius];
        attribute opticalReadInterval : TimeValue = 5 [SI::second];
        attribute analyticalPrecision : AccuracyValue = 98.5 [SI::percent];

        port aliquotIn : AliquotPort;
        port rawResultOut : ResultPort;
        port wasteOut : WastePort;
        port eventOut : EventPort;

        action incubateReaction {
            in item aliquot : PreparedAliquot;
            out item incubatedAliquot : PreparedAliquot;
        }

        action measureAssaySignal {
            in item incubatedAliquot : PreparedAliquot;
            out item rawResult : AssayResult;
            out item waste : WasteMaterial;
        }

        action performCalibrationCheck {
            out attribute calibrationValid : Boolean;
            out item event : DiagnosticEvent;
        }
    }

    part def ResultValidationModule {
        attribute autoReleaseThreshold : AccuracyValue = 95 [SI::percent];
        attribute maxValidationTime : TimeValue = 120 [SI::second];

        port rawResultIn : ResultPort;
        port verifiedResultOut : ResultPort;
        port eventOut : EventPort;

        action applyQualityRules {
            in item rawResult : AssayResult;
            out attribute passesRules : Boolean;
        }

        action releaseResult {
            in item rawResult : AssayResult;
            out item verifiedResult : AssayResult;
        }

        action holdForReview {
            in item rawResult : AssayResult;
            out item event : DiagnosticEvent;
        }
    }

    part def SampleArchiveStore {
        attribute refrigeratedSetpoint : TemperatureValue = 4 [SI::degreeCelsius];
        attribute retentionTime : TimeValue = 604800 [SI::second];
        attribute storagePositions : Integer = 5000;

        port sampleIn : SampleInputPort;
        port commandIn : CommandPort;

        action storeSample {
            in item sample : BiologicalSample;
        }

        action retrieveSample {
            in attribute sampleId : SampleId;
            out item sample : BiologicalSample;
        }
    }

    part def WasteManagementModule {
        attribute liquidWasteCapacity : VolumeValue = 10000 [SI::millilitre];
        attribute decontaminationTime : TimeValue = 900 [SI::second];

        port wasteIn : WastePort;
        port regulatedWasteOut : WastePort;
        port eventOut : EventPort;

        action collectWaste {
            in item waste : WasteMaterial;
            out item containedWaste : WasteMaterial;
        }

        action decontaminateWaste {
            in item containedWaste : WasteMaterial;
            out item regulatedWaste : WasteMaterial;
        }
    }

    part def SupervisoryController {
        attribute activeWorklistSize : Integer;
        attribute currentMode : AutomationMode;
        attribute emergencyStopActive : Boolean;

        port commandIn : CommandPort;
        port eventOut : EventPort;

        action scheduleWork {
            in item sample : BiologicalSample;
            out attribute protocolId : ProtocolId;
        }

        action pauseAutomation {
            out item event : DiagnosticEvent;
        }

        action resumeAutomation {
            out item event : DiagnosticEvent;
        }

        action initiateEmergencyStop {
            out item event : DiagnosticEvent;
        }
    }

    action def ProcessLaboratoryWorklist {
        in item receivedSample : BiologicalSample;
        out item verifiedResult : AssayResult;
        out item regulatedWaste : WasteMaterial;

        first start;
        then scan;
        then evaluate;
        if evaluate.accepted then route;
        then separate;
        then selectReagent;
        then prepareAliquot;
        then analyze;
        then validate;
        if validate.passesRules then release;
        then archive;
        then dispose;
        then done;

        action scan {
            in item receivedSample : BiologicalSample;
            out item identifiedSample : BiologicalSample;
        }

        action evaluate {
            in item identifiedSample : BiologicalSample;
            out attribute accepted : Boolean;
        }

        action route {
            in item identifiedSample : BiologicalSample;
            out item routedSample : BiologicalSample;
        }

        action separate {
            in item routedSample : BiologicalSample;
            out item separatedSample : BiologicalSample;
        }

        action selectReagent {
            in attribute protocolId : ProtocolId;
            out item selectedReagent : Reagent;
        }

        action prepareAliquot {
            in item separatedSample : BiologicalSample;
            in item selectedReagent : Reagent;
            out item aliquot : PreparedAliquot;
            out item preparationWaste : WasteMaterial;
        }

        action analyze {
            in item aliquot : PreparedAliquot;
            out item rawResult : AssayResult;
            out item analyticalWaste : WasteMaterial;
        }

        action validate {
            in item rawResult : AssayResult;
            out attribute passesRules : Boolean;
        }

        action release {
            in item rawResult : AssayResult;
            out item verifiedResult : AssayResult;
        }

        action archive {
            in item separatedSample : BiologicalSample;
        }

        action dispose {
            in item preparationWaste : WasteMaterial;
            in item analyticalWaste : WasteMaterial;
            out item regulatedWaste : WasteMaterial;
        }
    }

    state def LaboratoryAutomationStateMachine {
        entry action initializeSystem;
        exit action shutdownSystem;

        state Off;
        state Initializing;
        state Ready;
        state Processing;
        state Paused;
        state Maintenance;
        state Faulted;
        state EmergencyStopped;

        transition first Off;
        transition Off_to_Initializing
            first Off
            then Initializing
            accept ControlCommand
            if commandName == "POWER_ON";

        transition Initializing_to_Ready
            first Initializing
            then Ready
            if selfTestPassed == true;

        transition Ready_to_Processing
            first Ready
            then Processing
            accept BiologicalSample;

        transition Processing_to_Paused
            first Processing
            then Paused
            accept ControlCommand
            if commandName == "PAUSE";

        transition Paused_to_Processing
            first Paused
            then Processing
            accept ControlCommand
            if commandName == "RESUME";

        transition Ready_to_Maintenance
            first Ready
            then Maintenance
            accept ControlCommand
            if commandName == "MAINTENANCE";

        transition Maintenance_to_Ready
            first Maintenance
            then Ready
            accept ControlCommand
            if commandName == "RETURN_TO_SERVICE";

        transition Processing_to_Faulted
            first Processing
            then Faulted
            accept DiagnosticEvent
            if severity >= 2;

        transition Faulted_to_Ready
            first Faulted
            then Ready
            accept ControlCommand
            if commandName == "CLEAR_FAULT";

        transition Ready_to_EmergencyStopped
            first Ready
            then EmergencyStopped
            accept ControlCommand
            if commandName == "EMERGENCY_STOP";

        transition Processing_to_EmergencyStopped
            first Processing
            then EmergencyStopped
            accept ControlCommand
            if commandName == "EMERGENCY_STOP";

        transition EmergencyStopped_to_Initializing
            first EmergencyStopped
            then Initializing
            accept ControlCommand
            if commandName == "RESET";
    }

    requirement def LaboratoryAutomationPrimaryFunctionRequirement {
        subject system : LaboratoryAutomationSystem;
        doc /* The laboratory automation system shall provide integrated, traceable, and safe processing of accessioned laboratory samples from receipt through validated result reporting. */
        require constraint {
            system.targetThroughput >= 200 [1 / SI::hour]
        }
    }

    requirement def SampleIdentificationRequirement {
        subject accession : SampleAccessionStation;
        doc /* The accession station shall identify each accepted sample by barcode before any transport or preparation operation. */
        require constraint {
            accession.scanAccuracy >= 99.5 [SI::percent]
        }
    }

    requirement def MinimumVolumeRequirement {
        subject system : LaboratoryAutomationSystem;
        doc /* The system shall reject samples whose available volume is below the minimum required assay preparation volume. */
        require constraint {
            system.minimumSampleVolume >= 0.5 [SI::millilitre]
        }
    }

    requirement def TemperatureControlledReagentRequirement {
        subject reagentManager : ReagentStorageModule;
        doc /* Reagents shall be stored under refrigerated control to preserve analytical validity. */
        require constraint {
            reagentManager.storageSetpoint >= 2 [SI::degreeCelsius] and
            reagentManager.storageSetpoint <= 8 [SI::degreeCelsius]
        }
    }

    requirement def ResultLatencyRequirement {
        subject system : LaboratoryAutomationSystem;
        doc /* The system shall release automatically validated results within the maximum result latency under nominal throughput. */
        require constraint {
            system.maximumResultLatency <= 1800 [SI::second]
        }
    }

    requirement def WasteContainmentRequirement {
        subject wasteManager : WasteManagementModule;
        doc /* Liquid biological waste generated by sample preparation and analysis shall be collected and decontaminated before regulated waste output. */
        require constraint {
            wasteManager.liquidWasteCapacity >= 5000 [SI::millilitre]
        }
    }

    requirement def EmergencyStopRequirement {
        subject controller : SupervisoryController;
        doc /* The supervisory controller shall support emergency stop behavior that halts transport, pipetting, centrifugation, and analysis commands. */
        require constraint {
            controller.emergencyStopActive implies controller.currentMode == AutomationMode::emergencyStop
        }
    }

    satisfy LaboratoryAutomationPrimaryFunctionRequirement by LaboratoryAutomationSystem;
    satisfy SampleIdentificationRequirement by SampleAccessionStation;
    satisfy MinimumVolumeRequirement by LaboratoryAutomationSystem;
    satisfy TemperatureControlledReagentRequirement by ReagentStorageModule;
    satisfy ResultLatencyRequirement by LaboratoryAutomationSystem;
    satisfy WasteContainmentRequirement by WasteManagementModule;
    satisfy EmergencyStopRequirement by SupervisoryController;
}