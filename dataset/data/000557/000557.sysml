package BronchialBlockerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CuffPressureValue :> ISQ::PressureValue;
    attribute def CuffVolumeValue :> ISQ::VolumeValue;
    attribute def InsertionDepthValue :> ISQ::LengthValue;
    attribute def OxygenSaturationValue :> Real;
    attribute def AirflowRateValue :> ISQ::VolumeFlowRateValue;
    
    enum def LungSelection {
        leftLung;
        rightLung;
    }
    
    enum def IsolationStatus {
        notIsolated;
        partiallyIsolated;
        fullyIsolated;
    }
    
    enum def ProcedureCommand {
        initiateIsolation;
        verifyPosition;
        inflateCuff;
        maintainIsolation;
        deflateCuff;
        removeBlocker;
    }
    
    item def Air {
        attribute flowRate : AirflowRateValue;
        attribute oxygenConcentration : Real;
    }
    
    item def VisualFeedback {
        attribute imageQuality : Real;
        attribute positionConfirmed : Boolean;
    }
    
    port def AirwayPort {
        in item airflowIn : Air;
        out item airflowOut : Air;
    }
    
    port def CuffControlPort {
        in attribute inflationCommand : CuffVolumeValue;
        out attribute currentPressure : CuffPressureValue;
    }
    
    port def VisualizationPort {
        out item visualFeedback : VisualFeedback;
    }
    
    port def MonitoringPort {
        out attribute oxygenSaturation : OxygenSaturationValue;
        out attribute isolationStatus : IsolationStatus;
    }
    
    part def InflatableCuff {
        attribute cuffPressure : CuffPressureValue;
        attribute cuffVolume : CuffVolumeValue;
        attribute maxSafePressure : CuffPressureValue;
        attribute isInflated : Boolean;
        
        port cuffControl : CuffControlPort;
    }
    
    part def BlockerCatheter {
        attribute insertionDepth : InsertionDepthValue;
        attribute outerDiameter : LengthValue;
        attribute innerLumenDiameter : LengthValue;
        
        port proximalAirway : AirwayPort;
        port distalAirway : AirwayPort;
    }
    
    part def FiberopticChannel {
        attribute channelDiameter : LengthValue;
        attribute opticalClarity : Real;
        
        port visualization : VisualizationPort;
    }
    
    part def PressureSensor {
        attribute measuredPressure : CuffPressureValue;
        attribute accuracy : Real;
    }
    
    part def OxygenSensor {
        attribute measuredSaturation : OxygenSaturationValue;
        attribute responseTime : TimeValue;
    }
    
    part def BronchialBlockerDevice {
        attribute targetLung : LungSelection;
        attribute nominalDepth : InsertionDepthValue;
        attribute deviceLength : LengthValue;
        
        port mainAirway : AirwayPort;
        port cuffInterface : CuffControlPort;
        port visualInterface : VisualizationPort;
        port monitorInterface : MonitoringPort;
        
        part cuff : InflatableCuff {
            attribute maxSafePressure = 4900.0[Pa];
        }
        
        part catheter : BlockerCatheter {
            attribute outerDiameter = 0.009[m];
            attribute innerLumenDiameter = 0.002[m];
        }
        
        part fiberopticChannel : FiberopticChannel {
            attribute channelDiameter = 0.0015[m];
        }
        
        part pressureSensor : PressureSensor;
        
        part oxygenSensor : OxygenSensor;
        
        connection cuffToCatheter connect cuff = catheter;
        connection sensorToCuff connect pressureSensor = cuff;
        connection fiberopticToCatheter connect fiberopticChannel = catheter;
        
        bind cuff.cuffControl = cuffInterface;
        bind fiberopticChannel.visualization = visualInterface;
    }
    
    action def InsertBlocker {
        in targetLung : LungSelection;
        in targetDepth : InsertionDepthValue;
        out insertionComplete : Boolean;
        out actualDepth : InsertionDepthValue;
    }
    
    action def VerifyPosition {
        in visualFeedback : VisualFeedback;
        in targetLung : LungSelection;
        out positionCorrect : Boolean;
    }
    
    action def InflateCuff {
        in targetVolume : CuffVolumeValue;
        in maxPressure : CuffPressureValue;
        out achievedPressure : CuffPressureValue;
        out inflationSuccess : Boolean;
    }
    
    action def MonitorIsolation {
        in cuffPressure : CuffPressureValue;
        in oxygenSaturation : OxygenSaturationValue;
        out isolationStatus : IsolationStatus;
        out pressureAlarm : Boolean;
    }
    
    action def DeflateCuff {
        out deflationComplete : Boolean;
    }
    
    action def AdjustPosition {
        in currentDepth : InsertionDepthValue;
        in targetDepth : InsertionDepthValue;
        out adjustmentComplete : Boolean;
    }
    
    action def IsolateLungForSurgery {
        doc /* Primary function: Selectively block ventilation to one lung while maintaining 
               ventilation to the other lung, enabling single-lung ventilation during thoracic 
               surgical procedures. The system achieves this by positioning an inflatable cuff 
               within the target bronchus and creating a seal that prevents gas exchange. */
        
        in attribute selectedLung : LungSelection;
        in attribute requiredDepth : InsertionDepthValue;
        in attribute targetCuffVolume : CuffVolumeValue;
        in attribute maxCuffPressure : CuffPressureValue;
        out attribute isolationAchieved : Boolean;
        out attribute finalIsolationStatus : IsolationStatus;
        
        first start;
        
        then action insertBlocker : InsertBlocker {
            in targetLung = selectedLung;
            in targetDepth = requiredDepth;
            out insertionComplete : Boolean;
            out actualDepth : InsertionDepthValue;
        }
        
        then merge verificationLoop;
        
        then action verifyPosition : VerifyPosition {
            in visualFeedback : VisualFeedback;
            in targetLung = selectedLung;
            out positionCorrect : Boolean;
        }
        
        then decide;
            if verifyPosition.positionCorrect then inflateCuff;
            if not verifyPosition.positionCorrect then adjustPosition;
        
        action adjustPosition : AdjustPosition {
            in currentDepth = insertBlocker.actualDepth;
            in targetDepth = requiredDepth;
            out adjustmentComplete : Boolean;
        }
        then verificationLoop;
        
        action inflateCuff : InflateCuff {
            in targetVolume = targetCuffVolume;
            in maxPressure = maxCuffPressure;
            out achievedPressure : CuffPressureValue;
            out inflationSuccess : Boolean;
        }
        
        then decide;
            if inflateCuff.inflationSuccess then monitoringPhase;
            if not inflateCuff.inflationSuccess then handleInflationFailure;
        
        action handleInflationFailure {
            then assign isolationAchieved := false;
            then done;
        }
        
        action monitoringPhase {
            loop {
                action monitorIsolation : MonitorIsolation {
                    in cuffPressure : CuffPressureValue;
                    in oxygenSaturation : OxygenSaturationValue;
                    out isolationStatus : IsolationStatus;
                    out pressureAlarm : Boolean;
                }
                
                then decide;
                    if monitorIsolation.pressureAlarm then emergencyDeflate;
                    if monitorIsolation.isolationStatus == IsolationStatus::fullyIsolated 
                       and not monitorIsolation.pressureAlarm then continueMonitoring;
                    if monitorIsolation.isolationStatus != IsolationStatus::fullyIsolated 
                       and not monitorIsolation.pressureAlarm then adjustCuff;
                
                action emergencyDeflate : DeflateCuff {
                    out deflationComplete : Boolean;
                }
                then assign isolationAchieved := false;
                then done;
                
                action adjustCuff : InflateCuff {
                    in targetVolume = targetCuffVolume;
                    in maxPressure = maxCuffPressure;
                    out achievedPressure : CuffPressureValue;
                    out inflationSuccess : Boolean;
                }
                then continueMonitoring;
                
                action continueMonitoring;
                then accept procedureComplete : ProcedureCommand;
            }
        }
        
        then action deflateCuff : DeflateCuff {
            out deflationComplete : Boolean;
        }
        
        then assign isolationAchieved := true;
        then assign finalIsolationStatus := IsolationStatus::fullyIsolated;
        then done;
    }
    
    state machine def BronchialBlockerLifecycle {
        entry action entryAction;
        then idle;
        
        state idle;
        
        transition idle_to_inserting
            first idle
            accept ProcedureCommand::initiateIsolation
            then inserting;
        
        state inserting {
            entry action performInsertion : InsertBlocker;
        }
        
        transition inserting_to_positioning
            first inserting
            if performInsertion.insertionComplete
            then positioning;
        
        state positioning {
            entry action verifyPlacement : VerifyPosition;
        }
        
        transition positioning_to_inflating
            first positioning
            if verifyPlacement.positionCorrect
            then inflating;
        
        transition positioning_to_adjusting
            first positioning
            if not verifyPlacement.positionCorrect
            then adjusting;
        
        state adjusting {
            do action adjust : AdjustPosition;
        }
        
        transition adjusting_to_positioning
            first adjusting
            if adjust.adjustmentComplete
            then positioning;
        
        state inflating {
            entry action performInflation : InflateCuff;
        }
        
        transition inflating_to_monitoring
            first inflating
            if performInflation.inflationSuccess
            then monitoring;
        
        transition inflating_to_alarm
            first inflating
            if not performInflation.inflationSuccess
            then alarm;
        
        state monitoring {
            do action continuousMonitor : MonitorIsolation;
        }
        
        transition monitoring_to_alarm
            first monitoring
            if continuousMonitor.pressureAlarm
            then alarm;
        
        transition monitoring_to_deflating
            first monitoring
            accept ProcedureCommand::deflateCuff
            then deflating;
        
        state alarm;
        
        transition alarm_to_deflating
            first alarm
            then deflating;
        
        state deflating {
            do action performDeflation : DeflateCuff;
        }
        
        transition deflating_to_idle
            first deflating
            if performDeflation.deflationComplete
            then idle;
    }
    
    part bronchialBlockerSystem : BronchialBlockerDevice {
        perform action isolateLung : IsolateLungForSurgery {
            in attribute selectedLung : LungSelection;
            in attribute requiredDepth : InsertionDepthValue;
            in attribute targetCuffVolume : CuffVolumeValue;
            in attribute maxCuffPressure : CuffPressureValue;
            out attribute isolationAchieved : Boolean;
            out attribute finalIsolationStatus : IsolationStatus;
        }
        
        part cuff : InflatableCuff {
            perform isolateLung.inflateCuff;
            perform isolateLung.monitoringPhase.adjustCuff;
        }
        
        part catheter : BlockerCatheter {
            perform isolateLung.insertBlocker;
        }
        
        part fiberopticChannel : FiberopticChannel {
            perform isolateLung.verifyPosition;
        }
        
        part pressureSensor : PressureSensor {
            perform isolateLung.monitoringPhase.monitorIsolation;
        }
        
        exhibit state lifecycle : BronchialBlockerLifecycle;
    }
    
    requirement def FunctionalRequirement;
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    
    requirement <'BB-REQ-001'> lungIsolationCapability : FunctionalRequirement {
        doc /* The bronchial blocker system shall provide selective lung isolation 
               to enable single-lung ventilation during thoracic surgical procedures. */
        
        subject bronchialBlockerSystem;
        
        require constraint {
            bronchialBlockerSystem.isolateLung.isolationAchieved == true
        }
    }
    
    requirement <'BB-REQ-002'> cuffPressureSafety : SafetyRequirement {
        doc /* The cuff inflation pressure shall not exceed 50 cmH2O (4900 Pa) 
               to prevent bronchial mucosal ischemia and tissue damage. */
        
        subject bronchialBlockerSystem.cuff;
        
        require constraint {
            bronchialBlockerSystem.cuff.cuffPressure <= 4900.0[Pa]
        }
    }
    
    requirement <'BB-REQ-003'> positionVerification : SafetyRequirement {
        doc /* The system shall provide fiberoptic visualization capability 
               to verify correct bronchial positioning before cuff inflation. */
        
        subject bronchialBlockerSystem.fiberopticChannel;
        
        require constraint {
            bronchialBlockerSystem.isolateLung.verifyPosition.positionCorrect == true
        }
    }
    
    requirement <'BB-REQ-004'> continuousMonitoring : PerformanceRequirement {
        doc /* The system shall continuously monitor cuff pressure and isolation 
               status throughout the surgical procedure. */
        
        subject bronchialBlockerSystem.pressureSensor;
        
        require constraint {
            bronchialBlockerSystem.isolateLung.finalIsolationStatus == IsolationStatus::fullyIsolated
        }
    }
    
    requirement <'BB-REQ-005'> insertionDepthAccuracy : PerformanceRequirement {
        doc /* The blocker shall be positionable within ±5mm of the target depth 
               to ensure proper bronchial seal without over-insertion. */
        
        subject bronchialBlockerSystem.catheter;
        
        require constraint {
            abs(bronchialBlockerSystem.isolateLung.insertBlocker.actualDepth - 
                bronchialBlockerSystem.isolateLung.requiredDepth) <= 0.005[m]
        }
    }
    
    requirement <'BB-REQ-006'> rapidDeflation : SafetyRequirement {
        doc /* The system shall be capable of rapid cuff deflation in emergency 
               situations to restore bilateral ventilation. */
        
        subject bronchialBlockerSystem;
        
        require constraint {
            bronchialBlockerSystem.isolateLung.deflateCuff.deflationComplete == true
        }
    }
    
    requirement <'BB-REQ-007'> primaryFunctionGoal : FunctionalRequirement {
        doc /* Primary system goal: Enable safe and effective single-lung ventilation 
               by selectively isolating one lung while maintaining ventilation to the 
               contralateral lung during thoracic surgery. */
        
        require lungIsolationCapability;
        require cuffPressureSafety;
        require positionVerification;
        require continuousMonitoring;
    }
}
