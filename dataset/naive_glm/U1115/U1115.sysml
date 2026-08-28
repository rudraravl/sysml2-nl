package LaboratoryAutomationSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value def TemperatureUnit :> Unit {
        ref dimension : Temperature;
    }
    value def TemperatureValue :> Real {
        unit TemperatureUnit;
    }
    value def VolumeUnit :> Unit {
        ref dimension : Volume;
    }
    value def VolumeValue :> Real {
        unit VolumeUnit;
    }
    value def DurationUnit :> Unit {
        ref dimension : Time;
    }
    value def DurationValue :> Real {
        unit DurationUnit;
    }
    value def MassUnit :> Unit {
        ref dimension : Mass;
    }
    value def MassValue :> Real {
        unit MassUnit;
    }
    value def ConcentrationValue :> Real {
        unit VolumeUnit "per" VolumeUnit;
    }
    value def ProbabilityValue :> Real;
    value def CountValue :> Integer;

    // ===== Item Definitions =====
    item def SampleVial {
        attribute sampleId : String;
        attribute sampleType : SampleType;
        attribute volume : VolumeValue;
        attribute mass : MassValue;
        attribute state : SampleState;
    }
    enum def SampleType { blood; urine; tissue; chemical; water; }
    enum def SampleState { pending; queued; pickedUp; inPreparation; incubating; analyzing; completed; rejected; }

    item def Reagent {
        attribute reagentId : String;
        attribute name : String;
        attribute volume : VolumeValue;
        attribute concentration : ConcentrationValue;
        attribute storageTemp : TemperatureValue;
    }

    item def TestRequest {
        attribute requestId : String;
        attribute sampleId : String;
        attribute testType : TestType;
        attribute priority : PriorityLevel;
        attribute submittedAt : DateTime;
        attribute requiredReagents : Reagent[0..*];
        attribute incubationTemp : TemperatureValue;
        attribute incubationDuration : DurationValue;
        attribute requiredVolume : VolumeValue;
    }
    enum def TestType { assay; titration; culture; spectrometry; pcr; }
    enum def PriorityLevel { low; normal; high; urgent; }

    item def RawResult {
        attribute requestId : String;
        attribute sampleId : String;
        attribute measurementData : String;
        attribute timestamp : DateTime;
        attribute instrumentId : String;
    }

    item def AnalysisReport {
        attribute reportId : String;
        attribute requestId : String;
        attribute sampleId : String;
        attribute summary : String;
        attribute detailedResults : String;
        attribute generatedAt : DateTime;
        attribute reviewed : Boolean;
    }

    item def StatusMessage {
        attribute source : String;
        attribute message : String;
        attribute timestamp : DateTime;
        attribute severity : SeverityLevel;
    }
    enum def SeverityLevel { info; warning; error; critical; }

    // ===== Port Definitions =====
    port def CommandPort {
        out item commands : TestRequest;
        in item acknowledgments : StatusMessage;
    }
    port def StatusPort {
        out item status : StatusMessage;
        in item commands : StatusMessage;
    }
    port def SampleTransportPort {
        in item incomingSample : SampleVial;
        out item outgoingSample : SampleVial;
    }
    port def DataPort {
        in item rawResults : RawResult;
        out item reports : AnalysisReport;
    }
    port def ReagentPort {
        out item dispensedReagent : Reagent;
    }

    // ===== Requirements =====
    requirement def AutomatedProcessingRequirement {
        doc "The system shall process biological or chemical samples with minimal human intervention."
        attribute maxHumanInterventionsPerRun : CountValue = 0;
        subject system : LaboratorySystem;
        objective {
            satisfy system.automationLevel == 'fullyAutomated'
        }
    }

    requirement def ThroughputRequirement {
        doc "The system shall support high throughput concurrent test processing."
        attribute minConcurrentTests : CountValue = 4;
        attribute minTestsPerHour : CountValue = 60;
        subject system : LaboratorySystem;
    }

    requirement def AccuracyRequirement {
        doc "The liquid handler shall aspirate and dispense reagents with high accuracy."
        attribute maxVolumeErrorPercent : Real = 1.0;
        subject liquidHandler : LiquidHandler;
    }

    requirement def TemperatureStabilityRequirement {
        doc "The incubator shall maintain set temperature with high stability."
        attribute maxTemperatureDeviation : TemperatureValue = 0.5 [K];
        subject incubator : Incubator;
    }

    requirement def TraceabilityRequirement {
        doc "All results shall be associated with the original sample ID for complete traceability."
        subject dataSystem : DataManagementSystem;
        objective {
            satisfy dataSystem.traceabilityEnabled == true
        }
    }

    requirement def ReliabilityRequirement {
        doc "The system shall ensure consistent and reliable laboratory results."
        attribute minUptimePercent : Real = 99.0;
        subject system : LaboratorySystem;
    }

    // ===== Part Definitions =====

    part def LaboratorySystem {
        exhibit state AutomatedOperation;

        port commandBus : CommandPort;
        port statusBus : StatusPort;
        port dataInterface : DataPort;

        part schedulerController : SchedulerController {
            port commandOut : CommandPort;
            port statusIn : StatusPort;
            port dataOut : DataPort;
        }
        part sampleHandler : SampleHandler {
            port commandIn : CommandPort;
            port statusOut : StatusPort;
            port transportA : SampleTransportPort;
            port transportB : SampleTransportPort;
            port transportC : SampleTransportPort;
            part gripper : Gripper;
        }
        part liquidHandler : LiquidHandler {
            port commandIn : CommandPort;
            port statusOut : StatusPort;
            port samplePort : SampleTransportPort;
            port reagentPort : ReagentPort;
            part pipette : Pipette;
        }
        part incubator : Incubator {
            port commandIn : CommandPort;
            port statusOut : StatusPort;
            port samplePort : SampleTransportPort;
        }
        part analyzer : Analyzer {
            port commandIn : CommandPort;
            port statusOut : StatusPort;
            port samplePort : SampleTransportPort;
            port dataOut : DataPort;
        }
        part dataManagement : DataManagementSystem {
            port commandIn : CommandPort;
            port statusOut : StatusPort;
            port dataIn : DataPort;
            part database : Database;
        }

        satisfy AutomatedProcessingRequirement {
            subject system = LaboratorySystem::this;
        }
        satisfy ThroughputRequirement {
            subject system = LaboratorySystem::this;
        }
        satisfy ReliabilityRequirement {
            subject system = LaboratorySystem::this;
        }

        connection schedulerToSampleHandler connect schedulerController.commandOut to sampleHandler.commandIn;
        connection schedulerToLiquidHandler connect schedulerController.commandOut to liquidHandler.commandIn;
        connection schedulerToIncubator connect schedulerController.commandOut to incubator.commandIn;
        connection schedulerToAnalyzer connect schedulerController.commandOut to analyzer.commandIn;
        connection schedulerToData connect schedulerController.commandOut to dataManagement.commandIn;

        connection sampleHandlerStatus connect sampleHandler.statusOut to schedulerController.statusIn;
        connection liquidHandlerStatus connect liquidHandler.statusOut to schedulerController.statusIn;
        connection incubatorStatus connect incubator.statusOut to schedulerController.statusIn;
        connection analyzerStatus connect analyzer.statusOut to schedulerController.statusIn;
        connection dataStatus connect dataManagement.statusOut to schedulerController.statusIn;

        connection sampleToLiquidHandler connect sampleHandler.transportA to liquidHandler.samplePort;
        connection liquidToIncubator connect liquidHandler.samplePort to incubator.samplePort;
        connection incubatorToAnalyzer connect incubator.samplePort to analyzer.samplePort;
        connection analyzerToData connect analyzer.dataOut to dataManagement.dataIn;

        connection sampleHandlerReturn connect sampleHandler.transportB to liquidHandler.samplePort;
        connection sampleHandlerToIncubator connect sampleHandler.transportC to incubator.samplePort;
    }

    part def SchedulerController {
        attribute automationLevel : String = 'fullyAutomated';
        attribute maxConcurrentTests : CountValue = 8;
        attribute requestQueue : TestRequest[0..*] ordered;
        attribute activeTests : TestRequest[0..*];

        port commandOut : CommandPort;
        port statusIn : StatusPort;
        port dataOut : DataPort;

        exhibit state ControllerStateMachine {
            entry { sendStatus("Scheduler initialized"); }
            state Idle {
                entry { sendStatus("Scheduler idle, waiting for requests"); }
            }
            state Receiving {
                entry { acceptRequest(); }
            }
            state Prioritizing {
                entry { prioritizeQueue(); }
            }
            state Dispatching {
                entry { dispatchCommands(); }
            }
            state Monitoring {
                entry { monitorProgress(); }
            }
            state ErrorHandling {
                entry { handleError(); }
            }
            transition idleToReceiving first Idle to Receiving when requestQueue->size() > 0;
            transition receivingToPrioritizing Receiving to Prioritizing;
            transition prioritizingToDispatching Prioritizing to Dispatching;
            transition dispatchingToMonitoring Dispatching to Monitoring;
            transition monitoringToDispatching Monitoring to Dispatching when activeTests->size() > 0 and requestQueue->size() > 0;
            transition monitoringToIdle Monitoring to Idle when requestQueue->size() == 0 and activeTests->size() == 0;
            transition anyToErrorHandling Idle|Receiving|Prioritizing|Dispatching|Monitoring to ErrorHandling when statusIn.status.severity == SeverityLevel::critical;
            transition errorToIdle ErrorHandling to Idle;
        }

        action acceptRequest {
            in newRequest : TestRequest;
            then { requestQueue.append(newRequest); }
        }
        action prioritizeQueue {
            then { requestQueue.sortBy(p => p.priority); }
        }
        action dispatchCommands {
            then {
                if activeTests->size() < maxConcurrentTests and requestQueue->size() > 0 {
                    var next : TestRequest = requestQueue.first();
                    requestQueue.removeFirst();
                    activeTests.append(next);
                    commandOut.commands.send(next);
                }
            }
        }
        action monitorProgress {
            then {
                for test in activeTests {
                    if testIsComplete(test) {
                        activeTests.remove(test);
                    }
                }
            }
        }
        action handleError {
            then { sendStatus("Critical error detected, entering safe state"); }
        }
        action sendStatus {
            in msg : String;
        }
        action testIsComplete {
            in test : TestRequest;
            return Boolean;
        }
    }

    part def SampleHandler {
        attribute handlerId : String;
        attribute currentPosition : String;
        attribute payloadCapacity : MassValue;
        attribute isBusy : Boolean = false;

        port commandIn : CommandPort;
        port statusOut : StatusPort;
        port transportA : SampleTransportPort;
        port transportB : SampleTransportPort;
        port transportC : SampleTransportPort;

        part gripper : Gripper {
            attribute gripForce : Real;
            attribute isEngaged : Boolean = false;
            action grip {
                in vial : SampleVial;
                then { isEngaged = true; }
            }
            action release {
                then { isEngaged = false; }
            }
        }

        exhibit state HandlerStateMachine {
            state Idle;
            state PickingUp {
                entry { gripper.grip(currentVial); }
            }
            state Validating {
                entry { validateSample(); }
            }
            state Transporting {
                entry { transportSample(); }
            }
            state Placing {
                entry { gripper.release(); }
            }
            state Returning {
                entry { returnToHome(); }
            }
            transition idleToPickingUp Idle to PickingUp when commandIn.commands->isReceived();
            transition pickingToValidating PickingUp to Validating;
            transition validatingToTransporting Validating to Transporting when validationPassed == true;
            transition validatingToIdle Validating to Idle when validationPassed == false;
            transition transportingToPlacing Transporting to Placing;
            transition placingToReturning Placing to Returning;
            transition returningToIdle Returning to Idle;
        }

        attribute currentVial : SampleVial;
        attribute validationPassed : Boolean;

        action validateSample {
            then {
            if currentVial.volume > 0 [mL] and currentVial.sampleId != "" {
                validationPassed = true;
                statusOut.status.send(StatusMessage{source=handlerId, message="Sample validated", severity=SeverityLevel::info});
            } else {
                validationPassed = false;
                statusOut.status.send(StatusMessage{source=handlerId, message="Sample rejected", severity=SeverityLevel::warning});
            }
            }
        }
        action transportSample {
            then {
            transportA.outgoingSample.send(currentVial);
            statusOut.status.send(StatusMessage{source=handlerId, message="Sample transported", severity=SeverityLevel::info});
            }
        }
        action returnToHome {
            then { currentPosition = "home"; }
        }
    }

    part def Gripper {
        attribute gripForce : Real;
        attribute isEngaged : Boolean = false;
        action grip {
            in vial : SampleVial;
            then { isEngaged = true; }
        }
        action release {
            then { isEngaged = false; }
        }
    }

    part def LiquidHandler {
        attribute handlerId : String;
        attribute accuracyClass : String = 'high';
        attribute maxVolume : VolumeValue = 1000 [uL];
        attribute minVolume : VolumeValue = 1 [uL];
        attribute currentSample : SampleVial;

        port commandIn : CommandPort;
        port statusOut : StatusPort;
        port samplePort : SampleTransportPort;
        port reagentPort : ReagentPort;

        satisfy AccuracyRequirement {
            subject liquidHandler = LiquidHandler::this;
        }

        part pipette : Pipette {
            attribute tipVolume : VolumeValue = 200 [uL];
            attribute aspirationRate : VolumeValue = 50 [uL/s];
            attribute dispenseRate : VolumeValue = 50 [uL/s];
            attribute currentVolume : VolumeValue = 0 [uL];
            action aspirate {
                in volume : VolumeValue;
                in reagent : Reagent;
                then {
                    if volume <= tipVolume {
                        currentVolume = volume;
                    }
                }
            }
            action dispense {
                in volume : VolumeValue;
                then {
                    if volume <= currentVolume {
                        currentVolume = currentVolume - volume;
                    }
                }
            }
        }

        exhibit state LiquidHandlerStateMachine {
            state Idle;
            state ReceivingSample {
                entry { currentSample = samplePort.incomingSample.recv(); }
            }
            state Aspirating {
                entry { pipette.aspirate(requiredVolume, currentReagent); }
            }
            state Dispensing {
                entry { pipette.dispense(requiredVolume); }
            }
            state Mixing {
                entry { mixSample(); }
            }
            state ReleasingSample {
                entry { samplePort.outgoingSample.send(currentSample); }
            }
            transition idleToReceiving Idle to ReceivingSample when commandIn.commands->isReceived();
            transition receivingToAspirating ReceivingSample to Aspirating;
            transition aspiratingToDispensing Aspirating to Dispensing;
            transition dispensingToMixing Dispensing to Mixing;
            transition mixingToReleasing Mixing to ReleasingSample;
            transition releasingToIdle ReleasingSample to Idle;
        }

        attribute requiredVolume : VolumeValue;
        attribute currentReagent : Reagent;

        action mixSample {
            then {
            statusOut.status.send(StatusMessage{source=handlerId, message="Sample mixed", severity=SeverityLevel::info});
            }
        }
    }

    part def Pipette {
        attribute tipVolume : VolumeValue = 200 [uL];
        attribute aspirationRate : VolumeValue = 50 [uL/s];
        attribute dispenseRate : VolumeValue = 50 [uL/s];
        attribute currentVolume : VolumeValue = 0 [uL];
        action aspirate {
            in volume : VolumeValue;
            in reagent : Reagent;
            then {
                if volume <= tipVolume {
                    currentVolume = volume;
                }
            }
        }
        action dispense {
            in volume : VolumeValue;
            then {
                if volume <= currentVolume {
                    currentVolume = currentVolume - volume;
                }
            }
        }
    }

    part def Incubator {
        attribute incubatorId : String;
        attribute setTemperature : TemperatureValue = 37 [degC];
        attribute currentTemperature : TemperatureValue;
        attribute stabilityTolerance : TemperatureValue = 0.5 [K];
        attribute heatingRate : TemperatureValue = 2 [K/min];
        attribute coolingRate : TemperatureValue = 1 [K/min];
        attribute capacity : CountValue = 16;
        attribute occupiedSlots : CountValue = 0;
        attribute currentSample : SampleVial;
        attribute remainingTime : DurationValue;

        port commandIn : CommandPort;
        port statusOut : StatusPort;
        port samplePort : SampleTransportPort;

        satisfy TemperatureStabilityRequirement {
            subject incubator = Incubator::this;
        }

        exhibit state IncubatorStateMachine {
            state Idle {
                entry { currentTemperature = 22 [degC]; }
            }
            state Loading {
                entry { currentSample = samplePort.incomingSample.recv(); }
            }
            state Heating {
                entry { heatToSetpoint(); }
            }
            state Stabilizing {
                entry { stabilizeTemperature(); }
            }
            state Incubating {
                entry { maintainTemperature(); }
            }
            state Cooling {
                entry { coolDown(); }
            }
            state Unloading {
                entry { samplePort.outgoingSample.send(currentSample); }
            }
            transition idleToLoading Idle to Loading when commandIn.commands->isReceived();
            transition loadingToHeating Loading to Heating;
            transition heatingToStabilizing Heating to Stabilizing when currentTemperature >= setTemperature - stabilityTolerance;
            transition stabilizingToIncubating Stabilizing to Incubating when isStable == true;
            transition incubatingToCooling Incubating to Cooling when remainingTime <= 0 [s];
            transition coolingToUnloading Cooling to Unloading when currentTemperature <= 25 [degC];
            transition unloadingToIdle Unloading to Idle;
        }

        attribute isStable : Boolean;

        action heatToSetpoint {
            then {
            currentTemperature = currentTemperature + heatingRate;
            statusOut.status.send(StatusMessage{source=incubatorId, message="Heating", severity=SeverityLevel::info});
            }
        }
        action stabilizeTemperature {
            then {
            if abs(currentTemperature - setTemperature) <= stabilityTolerance {
                isStable = true;
            }
            }
        }
        action maintainTemperature {
            then {
            currentTemperature = setTemperature;
            remainingTime = remainingTime - 1 [s];
            }
        }
        action coolDown {
            then {
            currentTemperature = currentTemperature - coolingRate;
            }
        }
    }

    part def Analyzer {
        attribute analyzerId : String;
        attribute instrumentType : String;
        attribute measurementRange : Real;
        attribute calibrationStatus : CalibrationStatus;
        attribute currentSample : SampleVial;
        attribute currentRequest : TestRequest;

        port commandIn : CommandPort;
        port statusOut : StatusPort;
        port samplePort : SampleTransportPort;
        port dataOut : DataPort;

        exhibit state AnalyzerStateMachine {
            state Idle;
            state Calibrating {
                entry { performCalibration(); }
            }
            state ReceivingSample {
                entry { currentSample = samplePort.incomingSample.recv(); }
            }
            state Measuring {
                entry { performMeasurement(); }
            }
            state Processing {
                entry { processData(); }
            }
            state Transmitting {
                entry { transmitResults(); }
            }
            transition idleToCalibrating Idle to Calibrating when calibrationStatus == CalibrationStatus::required;
            transition idleToReceiving Idle to ReceivingSample when commandIn.commands->isReceived();
            transition calibratingToIdle Calibrating to Idle when calibrationStatus == CalibrationStatus::ok;
            transition receivingToMeasuring ReceivingSample to Measuring;
            transition measuringToProcessing Measuring to Processing;
            transition processingToTransmitting Processing to Transmitting;
            transition transmittingToIdle Transmitting to Idle;
        }

        action performCalibration {
            then { calibrationStatus = CalibrationStatus::ok; }
        }
        action performMeasurement {
            then {
            statusOut.status.send(StatusMessage{source=analyzerId, message="Measurement in progress", severity=SeverityLevel::info});
            }
        }
        action processData {
            then {
            var raw : RawResult = RawResult{requestId=currentRequest.requestId, sampleId=currentSample.sampleId, measurementData="processed", instrumentId=analyzerId};
            }
        }
        action transmitResults {
            then {
            dataOut.rawResults.send(RawResult{requestId=currentRequest.requestId, sampleId=currentSample.sampleId, measurementData="processed", instrumentId=analyzerId});
            }
        }
    }
    enum def CalibrationStatus { ok; required; failed; }

    part def DataManagementSystem {
        attribute systemId : String;
        attribute traceabilityEnabled : Boolean = true;
        attribute storedReports : AnalysisReport[0..*];
        attribute storedResults : RawResult[0..*];

        port commandIn : CommandPort;
        port statusOut : StatusPort;
        port dataIn : DataPort;

        satisfy TraceabilityRequirement {
            subject dataSystem = DataManagementSystem::this;
        }

        part database : Database {
            attribute connectionStatus : String = 'connected';
            attribute capacity : CountValue = 1000000;
            attribute recordCount : CountValue = 0;
            action store {
                in record : RawResult;
                then { recordCount = recordCount + 1; }
            }
            action retrieve {
                in sampleId : String;
                return AnalysisReport;
            }
        }

        exhibit state DataSystemStateMachine {
            state Idle;
            state Receiving {
                entry { receiveResult(); }
            }
            state Logging {
                entry { logData(); }
            }
            state Associating {
                entry { associateWithSample(); }
            }
            state Storing {
                entry { database.store(currentResult); }
            }
            state GeneratingReport {
                entry { generateReport(); }
            }
            state Transmitting {
                entry { transmitReport(); }
            }
            transition idleToReceiving Idle to Receiving when dataIn.rawResults->isReceived();
            transition receivingToLogging Receiving to Logging;
            transition loggingToAssociating Logging to Associating;
            transition associatingToStoring Associating to Storing;
            transition storingToGenerating Storing to GeneratingReport;
            transition generatingToTransmitting GeneratingReport to Transmitting;
            transition transmittingToIdle Transmitting to Idle;
        }

        attribute currentResult : RawResult;
        attribute currentReport : AnalysisReport;

        action receiveResult {
            then { currentResult = dataIn.rawResults.recv(); }
        }
        action logData {
            then {
            storedResults.append(currentResult);
            statusOut.status.send(StatusMessage{source=systemId, message="Data logged", severity=SeverityLevel::info});
            }
        }
        action associateWithSample {
            then {
            if currentResult.sampleId != "" {
                statusOut.status.send(StatusMessage{source=systemId, message="Sample associated", severity=SeverityLevel::info});
            }
            }
        }
        action generateReport {
            then {
            currentReport = AnalysisReport{reportId="RPT-" + currentResult.requestId, requestId=currentResult.requestId, sampleId=currentResult.sampleId, summary="Analysis complete", detailedResults=currentResult.measurementData, generatedAt=now(), reviewed=false};
            storedReports.append(currentReport);
            }
        }
        action transmitReport {
            then { dataIn.reports.send(currentReport); }
        }
    }

    part def Database {
        attribute connectionStatus : String = 'connected';
        attribute capacity : CountValue = 1000000;
        attribute recordCount : CountValue = 0;
        action store {
            in record : RawResult;
            then { recordCount = recordCount + 1; }
        }
        action retrieve {
            in sampleId : String;
            return AnalysisReport;
        }
    }
}
