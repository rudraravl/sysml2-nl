package AspirationTherapySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def TherapySessionParameters {
        attribute targetAspirationVolume : VolumeValue;
        attribute maxSessionDuration : TimeValue;
        attribute vacuumPressureSetpoint : PressureValue;
        attribute cycleInterval : TimeValue;
    }
    
    attribute def SystemStatus {
        attribute sessionActive : Boolean;
        attribute totalVolumeAspired : VolumeValue;
        attribute currentCycleNumber : Integer;
        attribute elapsedSessionTime : TimeValue;
        attribute systemState : String;
    }
    
    attribute def SafetyParameters {
        attribute maxVacuumPressure : PressureValue;
        attribute minVacuumPressure : PressureValue;
        attribute maxReservoirCapacity : VolumeValue;
        attribute maxContinuousOperationTime : TimeValue;
    }
    
    item def GastricContents {
        attribute volume : VolumeValue;
        attribute temperature : TemperatureValue;
    }
    
    port def VacuumInterfacePort {
        attribute vacuumPressure : PressureValue;
        attribute flowRate : VolumeFlowRateValue;
    }
    
    port def FluidTransferPort {
        attribute transferRate : VolumeFlowRateValue;
    }
    
    port def ControlSignalPort {
        attribute commandSignal : String;
        attribute statusFeedback : SystemStatus;
    }
    
    port def PatientInterfacePort {
        attribute interfaceSealed : Boolean;
    }
    
    part def VacuumGenerationUnit {
        port vacuumOutput : VacuumInterfacePort;
        attribute operatingPressure : PressureValue;
        attribute pumpSpeed : FrequencyValue;
        attribute powerConsumption : PowerValue;
        
        action def GenerateVacuum {
            in targetPressure : PressureValue;
            in currentPressure : PressureValue;
            out achievedPressure : PressureValue;
        }
        
        action def AdjustVacuumLevel {
            in desiredPressure : PressureValue;
            in measuredPressure : PressureValue;
            out correctedPressure : PressureValue;
        }
    }
    
    part def AspirationCatheterAssembly {
        port patientConnection : PatientInterfacePort;
        port systemConnection : VacuumInterfacePort;
        port fluidOutput : FluidTransferPort;
        attribute catheterDiameter : LengthValue;
        attribute catheterLength : LengthValue;
        attribute insertionDepth : LengthValue;
        
        action def EstablishPatientAccess {
            in insertionParameters : LengthValue;
            out accessConfirmed : Boolean;
            out sealIntegrity : Boolean;
        }
        
        action def TransferGastricContents {
            in appliedVacuum : PressureValue;
            out aspiratedVolume : VolumeValue;
            out transferDuration : TimeValue;
        }
    }
    
    part def CollectionReservoirUnit {
        port fluidInlet : FluidTransferPort;
        attribute totalCapacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        attribute contentTemperature : TemperatureValue;
        
        action def AccumulateAspirate {
            in incomingVolume : VolumeValue;
            in currentVolume : VolumeValue;
            out updatedVolume : VolumeValue;
        }
        
        action def MonitorReservoirLevel {
            in currentLevel : VolumeValue;
            in capacity : VolumeValue;
            out fillPercentage : Real;
            out capacityWarning : Boolean;
        }
    }
    
    part def PressureMonitoringSubsystem {
        attribute measuredPressure : PressureValue;
        attribute measurementAccuracy : PressureValue;
        attribute samplingRate : FrequencyValue;
        
        action def MeasureVacuumPressure {
            out pressureReading : PressureValue;
            out measurementTimestamp : TimeValue;
        }
        
        action def ValidatePressureRange {
            in currentPressure : PressureValue;
            in minLimit : PressureValue;
            in maxLimit : PressureValue;
            out withinRange : Boolean;
        }
    }
    
    part def TherapyControlUnit {
        port controlInterface : ControlSignalPort;
        attribute sessionParameters : TherapySessionParameters;
        attribute safetyParameters : SafetyParameters;
        attribute currentStatus : SystemStatus;
        
        action def InitiateTherapySession {
            in sessionConfig : TherapySessionParameters;
            in safetyConfig : SafetyParameters;
            out sessionStarted : Boolean;
        }
        
        action def MonitorSessionProgress {
            in currentVolume : VolumeValue;
            in elapsedTime : TimeValue;
            in cycleCount : Integer;
            out continueSession : Boolean;
            out sessionComplete : Boolean;
        }
        
        action def ExecuteSafetyCheck {
            in currentPressure : PressureValue;
            in reservoirLevel : VolumeValue;
            in operationTime : TimeValue;
            out safetyStatus : Boolean;
            out alarmCondition : String;
        }
        
        action def TerminateSession {
            in terminationReason : String;
            out shutdownComplete : Boolean;
        }
    }
    
    part def UserInterfaceModule {
        attribute displayStatus : String;
        attribute userInputEnabled : Boolean;
        
        action def DisplaySessionInfo {
            in status : SystemStatus;
            out displayUpdated : Boolean;
        }
        
        action def ProcessUserCommand {
            in userInput : String;
            out commandIssued : String;
        }
    }
    
    part aspirationTherapyDevice {
        attribute deviceIdentifier : String;
        attribute operatingMode : String;
        attribute deviceSerialNumber : String;
        
        part vacuumUnit : VacuumGenerationUnit {
            attribute operatingPressure : PressureValue = -50000.0[ISQ::Pa];
            attribute pumpSpeed : FrequencyValue = 60.0[ISQ::Hz];
            attribute powerConsumption : PowerValue = 150.0[ISQ::W];
        }
        
        part catheter : AspirationCatheterAssembly {
            attribute catheterDiameter : LengthValue = 0.016[ISQ::m];
            attribute catheterLength : LengthValue = 0.50[ISQ::m];
            attribute insertionDepth : LengthValue = 0.40[ISQ::m];
        }
        
        part reservoir : CollectionReservoirUnit {
            attribute totalCapacity : VolumeValue = 0.0015[ISQ::m³];
            attribute currentLevel : VolumeValue = 0.0[ISQ::m³];
            attribute contentTemperature : TemperatureValue = 310.0[ISQ::K];
        }
        
        part pressureMonitor : PressureMonitoringSubsystem {
            attribute measurementAccuracy : PressureValue = 500.0[ISQ::Pa];
            attribute samplingRate : FrequencyValue = 10.0[ISQ::Hz];
        }
        
        part controller : TherapyControlUnit {
            attribute sessionParameters : TherapySessionParameters {
                attribute targetAspirationVolume : VolumeValue = 0.0005[ISQ::m³];
                attribute maxSessionDuration : TimeValue = 1500.0[ISQ::s];
                attribute vacuumPressureSetpoint : PressureValue = -45000.0[ISQ::Pa];
                attribute cycleInterval : TimeValue = 120.0[ISQ::s];
            }
            attribute safetyParameters : SafetyParameters {
                attribute maxVacuumPressure : PressureValue = -70000.0[ISQ::Pa];
                attribute minVacuumPressure : PressureValue = -20000.0[ISQ::Pa];
                attribute maxReservoirCapacity : VolumeValue = 0.0015[ISQ::m³];
                attribute maxContinuousOperationTime : TimeValue = 1800.0[ISQ::s];
            }
        }
        
        part userInterface : UserInterfaceModule {
            attribute displayStatus : String = "Ready";
            attribute userInputEnabled : Boolean = true;
        }
        
        connection vacuumToCatheter connect 
            vacuumUnit.vacuumOutput to catheter.systemConnection;
        
        connection catheterToReservoir connect 
            catheter.fluidOutput to reservoir.fluidInlet;
        
        connection controlToVacuum connect 
            controller.controlInterface to vacuumUnit.vacuumOutput;
        
        connection controlToUI connect 
            controller.controlInterface to userInterface;
        
        perform action therapyOperation : executeAspirationTherapy;
    }
    
    attribute def SessionStartSignal;
    attribute def SystemReadySignal;
    attribute def CycleCompleteSignal;
    attribute def IntervalElapsedSignal;
    attribute def TargetReachedSignal;
    attribute def SafetyViolationSignal;
    attribute def ConditionClearedSignal;
    
    state def AspirationTherapyStates {
        entry action initializeSystem;
        
        state Standby {
            entry action displayReady;
        }
        
        state PreparationPhase {
            entry action verifyConnections;
            do action primeSystem;
        }
        
        state ActiveAspiration {
            entry action startVacuum;
            do action aspirateContents;
            exit action recordCycleData;
        }
        
        state InterCycleWait {
            do action monitorPatient;
        }
        
        state SessionComplete {
            entry action deactivateVacuum;
            do action finalizeRecords;
        }
        
        state SafetyHold {
            entry action activateAlarm;
            do action assessCondition;
        }
        
        state SystemShutdown {
            entry action secureDevice;
            do action cleanupResources;
        }
        
        transition standbyToPrep 
            first Standby 
            accept sessionStart : SessionStartSignal
            then PreparationPhase;
        
        transition prepToActive 
            first PreparationPhase 
            accept systemReady : SystemReadySignal
            then ActiveAspiration;
        
        transition activeToWait 
            first ActiveAspiration 
            accept cycleComplete : CycleCompleteSignal
            then InterCycleWait;
        
        transition waitToActive 
            first InterCycleWait 
            accept intervalElapsed : IntervalElapsedSignal
            then ActiveAspiration;
        
        transition activeToComplete 
            first ActiveAspiration 
            accept targetReached : TargetReachedSignal
            then SessionComplete;
        
        transition activeToSafety 
            first ActiveAspiration 
            accept safetyViolation : SafetyViolationSignal
            then SafetyHold;
        
        transition waitToSafety 
            first InterCycleWait 
            accept safetyViolation : SafetyViolationSignal
            then SafetyHold;
        
        transition safetyToStandby 
            first SafetyHold 
            accept conditionCleared : ConditionClearedSignal
            then Standby;
        
        transition completeToShutdown 
            first SessionComplete 
            then SystemShutdown;
    }
    
    action def VerifyPatientReadiness {
        in patientStatus : String;
        in catheterPlacement : Boolean;
        out readyForTherapy : Boolean;
    }
    
    action def ActivateVacuumSystem {
        in targetPressure : PressureValue;
        in safetyLimits : SafetyParameters;
        out vacuumEstablished : Boolean;
        out actualPressure : PressureValue;
    }
    
    action def PerformAspirationCycle {
        in vacuumPressure : PressureValue;
        in cycleDuration : TimeValue;
        out volumeAspired : VolumeValue;
        out cycleSuccessful : Boolean;
    }
    
    action def AccumulateAspiratedMaterial {
        in cycleVolume : VolumeValue;
        in previousTotal : VolumeValue;
        out newTotal : VolumeValue;
    }
    
    action def EvaluateSessionProgress {
        in totalVolume : VolumeValue;
        in targetVolume : VolumeValue;
        in elapsedTime : TimeValue;
        in maxDuration : TimeValue;
        in cycleCount : Integer;
        out continueTherapy : Boolean;
        out targetAchieved : Boolean;
    }
    
    action def PerformSafetyValidation {
        in currentPressure : PressureValue;
        in reservoirLevel : VolumeValue;
        in operatingTime : TimeValue;
        in safetyLimits : SafetyParameters;
        out safeToOperate : Boolean;
        out alarmCode : String;
    }
    
    action def DeactivateTherapySystem {
        in finalVolume : VolumeValue;
        in sessionDuration : TimeValue;
        out systemSecured : Boolean;
    }
    
    action executeAspirationTherapy {
        doc /* 
            Primary function: Remove gastric contents from the stomach following 
            meal consumption through controlled vacuum aspiration to reduce caloric 
            absorption and support weight management in obesity treatment. The system 
            performs multiple aspiration cycles within a therapy session, continuously 
            monitoring safety parameters and accumulating aspirated volume until the 
            target is reached or session limits are met.
        */
        
        first start;
        
        then action verifyReadiness : VerifyPatientReadiness {
            in patientStatus : String;
            in catheterPlacement : Boolean;
            out readyForTherapy : Boolean;
        }
        
        then decide;
            if verifyReadiness.readyForTherapy then activateVacuum;
            if not verifyReadiness.readyForTherapy then abortSession;
        
        action activateVacuum : ActivateVacuumSystem {
            in targetPressure : PressureValue = -45000.0[ISQ::Pa];
            in safetyLimits : SafetyParameters;
            out vacuumEstablished : Boolean;
            out actualPressure : PressureValue;
        }
        
        then merge beginAspirationCycle;
        
        then action performCycle : PerformAspirationCycle {
            in vacuumPressure : PressureValue = activateVacuum.actualPressure;
            in cycleDuration : TimeValue = 30.0[ISQ::s];
            out volumeAspired : VolumeValue;
            out cycleSuccessful : Boolean;
        }
        
        then action accumulate : AccumulateAspiratedMaterial {
            in cycleVolume : VolumeValue = performCycle.volumeAspired;
            in previousTotal : VolumeValue;
            out newTotal : VolumeValue;
        }
        
        then action safetyCheck : PerformSafetyValidation {
            in currentPressure : PressureValue = activateVacuum.actualPressure;
            in reservoirLevel : VolumeValue = accumulate.newTotal;
            in operatingTime : TimeValue;
            in safetyLimits : SafetyParameters;
            out safeToOperate : Boolean;
            out alarmCode : String;
        }
        
        then decide;
            if not safetyCheck.safeToOperate then emergencyShutdown;
        
        then action evaluateProgress : EvaluateSessionProgress {
            in totalVolume : VolumeValue = accumulate.newTotal;
            in targetVolume : VolumeValue = 0.0005[ISQ::m³];
            in elapsedTime : TimeValue;
            in maxDuration : TimeValue = 1500.0[ISQ::s];
            in cycleCount : Integer;
            out continueTherapy : Boolean;
            out targetAchieved : Boolean;
        }
        
        then decide;
            if evaluateProgress.continueTherapy then waitInterval;
            if not evaluateProgress.continueTherapy then completeSession;
        
        action waitInterval {
            doc /* Inter-cycle waiting period */
        }
        then beginAspirationCycle;
        
        action completeSession : DeactivateTherapySystem {
            in finalVolume : VolumeValue = accumulate.newTotal;
            in sessionDuration : TimeValue;
            out systemSecured : Boolean;
        }
        then done;
        
        action emergencyShutdown : DeactivateTherapySystem {
            in finalVolume : VolumeValue = accumulate.newTotal;
            in sessionDuration : TimeValue;
            out systemSecured : Boolean;
        }
        then done;
        
        action abortSession : DeactivateTherapySystem {
            in finalVolume : VolumeValue = 0.0[ISQ::m³];
            in sessionDuration : TimeValue = 0.0[ISQ::s];
            out systemSecured : Boolean;
        }
        then done;
    }
    
    requirement def TherapyEffectivenessRequirement {
        doc /* 
            The aspiration therapy system shall remove a clinically significant 
            volume of gastric contents within the therapeutic window following 
            meal consumption to achieve the intended caloric reduction.
        */
        
        subject device : aspirationTherapyDevice;
        
        require constraint volumeTarget {
            device.reservoir.currentLevel >= 0.0003[ISQ::m³] and
            device.reservoir.currentLevel <= device.controller.sessionParameters.targetAspirationVolume
        }
    }
    
    requirement def VacuumSafetyRequirement {
        doc /* 
            The system shall maintain vacuum pressure within physiologically 
            safe limits to prevent tissue trauma, mucosal damage, or adverse 
            events during aspiration therapy.
        */
        
        subject device : aspirationTherapyDevice;
        
        require constraint pressureLimits {
            device.vacuumUnit.operatingPressure >= device.controller.safetyParameters.maxVacuumPressure and
            device.vacuumUnit.operatingPressure <= device.controller.safetyParameters.minVacuumPressure
        }
    }
    
    requirement def SessionDurationRequirement {
        doc /* 
            Therapy sessions shall complete within a maximum time limit to 
            ensure patient comfort and minimize procedural burden.
        */
        
        subject device : aspirationTherapyDevice;
        
        require constraint timeLimits {
            device.controller.currentStatus.elapsedSessionTime <= 
            device.controller.sessionParameters.maxSessionDuration
        }
    }
    
    requirement def ReservoirCapacityRequirement {
        doc /* 
            The collection reservoir shall have sufficient capacity to 
            accommodate the maximum expected aspirated volume without overflow.
        */
        
        subject device : aspirationTherapyDevice;
        
        require constraint capacityLimit {
            device.reservoir.currentLevel <= device.reservoir.totalCapacity
        }
    }
    
    requirement def CatheterPlacementRequirement {
        doc /* 
            The aspiration catheter shall be properly positioned in the stomach 
            with verified seal integrity before therapy initiation.
        */
        
        subject device : aspirationTherapyDevice;
        
        require constraint placementVerification {
            device.catheter.patientConnection.interfaceSealed == true
        }
    }
    
    requirement primaryAspirationTherapyRequirement {
        doc /* 
            The aspiration therapy system shall safely and effectively remove 
            gastric contents following meals to reduce caloric absorption as 
            part of a comprehensive obesity treatment program, while maintaining 
            patient safety and comfort throughout the procedure.
        */
        
        subject device : aspirationTherapyDevice;
        
        assume constraint patientEligibility {
            doc /* 
                Patient has been medically evaluated and cleared for aspiration 
                therapy with appropriate training on device use and post-meal timing.
            */
        }
        
        assume constraint mealTiming {
            doc /* 
                Therapy is initiated within the recommended time window following 
                meal consumption (typically 20-30 minutes post-meal).
            */
        }
        
        require TherapyEffectivenessRequirement;
        require VacuumSafetyRequirement;
        require SessionDurationRequirement;
        require ReservoirCapacityRequirement;
        require CatheterPlacementRequirement;
    }
}
