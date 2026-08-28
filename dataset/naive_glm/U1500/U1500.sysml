package SlugFlowControlSystem {
    import ISQ::*;
    import ScalarValues::*;
    
    // ===== Value Types =====
    value def Pressure :> Real { unit "Pa"; }
    value def PressureDiff :> Real { unit "Pa"; }
    value def VoidFraction :> Real { unit "1"; min 0.0; max 1.0; }
    value def VolumeFlowRate :> Real { unit "m3/s"; }
    value def MassFlowRate :> Real { unit "kg/s"; }
    value def Temperature :> Real { unit "K"; }
    value def ValveOpening :> Real { unit "%"; min 0.0; max 100.0; }
    value def Frequency :> Real { unit "Hz"; }
    value def SeverityIndex :> Real { unit "1"; min 0.0; max 10.0; }
    value def Length :> Real { unit "m"; }
    value def Diameter :> Real { unit "m"; }
    value def Volume :> Real { unit "m3"; }
    value def Duration :> Real { unit "s"; }
    value def Velocity :> Real { unit "m/s"; }
    value def Density :> Real { unit "kg/m3"; }
    value def Angle :> Real { unit "deg"; }
    
    // ===== Enumerations =====
    enum def FlowRegime {
        NORMAL = 0,
        BUBBLY = 1,
        SLUG = 2,
        ANNULAR = 3,
        STRATIFIED = 4,
        CHURN = 5
    }
    
    enum def AlarmLevel {
        NONE = 0,
        LOW = 1,
        MEDIUM = 2,
        HIGH = 3,
        CRITICAL = 4
    }
    
    enum def SystemMode {
        STARTUP = 0,
        NORMAL_OPERATION = 1,
        MONITORING = 2,
        SLUG_MITIGATION = 3,
        ALARM_ACTIVE = 4,
        EMERGENCY_SHUTDOWN = 5,
        MAINTENANCE = 6
    }
    
    // ===== Item Types =====
    item def GasLiquidMixture {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute voidFraction : VoidFraction;
        attribute massFlowRate : MassFlowRate;
        attribute density : Density;
    }
    
    item def Gas {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute massFlowRate : MassFlowRate;
    }
    
    item def Liquid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute massFlowRate : MassFlowRate;
    }
    
    item def SensorReading {
        attribute sensorId : String;
        attribute timestamp : Duration;
        attribute pressure : Pressure;
        attribute voidFraction : VoidFraction;
        attribute temperature : Temperature;
        attribute massFlowRate : MassFlowRate;
    }
    
    item def SlugEvent {
        attribute slugId : String;
        attribute timestamp : Duration;
        attribute severity : SeverityIndex;
        attribute frequency : Frequency;
        attribute velocity : Velocity;
        attribute length : Length;
    }
    
    item def ValveCommand {
        attribute commandId : String;
        attribute timestamp : Duration;
        attribute targetOpening : ValveOpening;
        attribute reason : String;
    }
    
    item def ControlAction {
        attribute actionId : String;
        attribute timestamp : Duration;
        attribute description : String;
        attribute priority : Integer;
    }
    
    // ===== Port Definitions =====
    port def FlowPort {
        out item mixture : GasLiquidMixture;
    }
    
    port def GasPort {
        out item gas : Gas;
    }
    
    port def LiquidPort {
        out item liquid : Liquid;
    }
    
    port def PressureSignalPort {
        out attribute pressure : Pressure;
    }
    
    port def VoidFractionSignalPort {
        out attribute voidFraction : VoidFraction;
    }
    
    port def TemperatureSignalPort {
        out attribute temperature : Temperature;
    }
    
    port def DataOutputPort {
        out item reading : SensorReading;
    }
    
    port def DataInputPort {
        in item reading : SensorReading;
    }
    
    port def ControlOutputPort {
        out item command : ValveCommand;
    }
    
    port def ControlInputPort {
        in item command : ValveCommand;
    }
    
    port def AlarmOutputPort {
        out attribute level : AlarmLevel;
    }
    
    port def AlarmInputPort {
        in attribute level : AlarmLevel;
    }
    
    port def SlugEventPort {
        out item event : SlugEvent;
    }
    
    // ===== Part Definitions =====
    
    part def PressureTransducer {
        attribute sensorId : String;
        attribute samplingRate : Frequency = 1000.0 [Hz];
        attribute measurementRange : Pressure = 10000000.0 [Pa];
        attribute accuracy : Pressure = 1000.0 [Pa];
        attribute responseTime : Duration = 0.001 [s];
        attribute isOperational : Boolean = true;
        
        port pressureOut : PressureSignalPort;
        port dataOut : DataOutputPort;
        
        action def MeasurePressure {
            in physicalPressure : Pressure;
            out reading : SensorReading;
            
            private action calibrate {
                out calibrationValue : Pressure;
            }
            
            then action convert {
                in calibrationValue : Pressure;
                out digitalValue : Pressure;
            }
            
            then action transmit {
                in digitalValue : Pressure;
                out reading : SensorReading;
            }
        }
        
        action def SelfDiagnostic {
            out status : Boolean;
            out errorCodes : String[0..*];
        }
    }
    
    part def VoidFractionMeter {
        attribute sensorId : String;
        attribute samplingRate : Frequency = 100.0 [Hz];
        attribute measurementTechnique : String = "Gamma-ray densitometry";
        attribute sourceStrength : Real = 100.0;
        attribute sourceType : String = "Cs-137";
        attribute detectorType : String = "Scintillation";
        attribute accuracy : VoidFraction = 0.02;
        attribute isOperational : Boolean = true;
        
        port voidFractionOut : VoidFractionSignalPort;
        port dataOut : DataOutputPort;
        
        action def MeasureVoidFraction {
            in mixture : GasLiquidMixture;
            out voidFraction : VoidFraction;
            out reading : SensorReading;
            
            private action emitGammaRays {
                out radiationIntensity : Real;
            }
            
            then action detectAttenuation {
                in radiationIntensity : Real;
                out attenuatedIntensity : Real;
            }
            
            then action calculateVoidFraction {
                in attenuatedIntensity : Real;
                out voidFraction : VoidFraction;
            }
            
            then action transmit {
                in voidFraction : VoidFraction;
                out reading : SensorReading;
            }
        }
        
        action def SelfDiagnostic {
            out status : Boolean;
            out errorCodes : String[0..*];
        }
    }
    
    part def ThrottleValve {
        attribute valveId : String;
        attribute valveType : String = "Butterfly";
        attribute maxOpening : ValveOpening = 100.0 [%];
        attribute minOpening : ValveOpening = 0.0 [%];
        attribute currentOpening : ValveOpening = 50.0 [%];
        attribute responseTime : Duration = 0.5 [s];
        attribute diameter : Diameter = 0.5 [m];
        attribute actuatorType : String = "Electric";
        attribute isOperational : Boolean = true;
        
        port controlIn : ControlInputPort;
        port flowIn : FlowPort;
        port flowOut : FlowPort;
        
        action def AdjustOpening {
            in command : ValveCommand;
            out newOpening : ValveOpening;
            
            private action validateCommand {
                in command : ValveCommand;
                out isValid : Boolean;
            }
            
            then action moveActuator {
                in targetOpening : ValveOpening;
                out actualOpening : ValveOpening;
            }
            
            then action confirmPosition {
                in actualOpening : ValveOpening;
                out newOpening : ValveOpening;
            }
        }
        
        action def RegulateFlow {
            in opening : ValveOpening;
            in mixture : GasLiquidMixture;
            out regulatedMixture : GasLiquidMixture;
            
            private action calculateBackPressure {
                in opening : ValveOpening;
                in mixture : GasLiquidMixture;
                out backPressure : Pressure;
            }
            
            then action applyBackPressure {
                in backPressure : Pressure;
                in mixture : GasLiquidMixture;
                out regulatedMixture : GasLiquidMixture;
            }
        }
    }
    
    part def FlowRegimeAnalyzer {
        attribute analyzerId : String;
        attribute analysisWindow : Duration = 5.0 [s];
        attribute slugFrequencyThreshold : Frequency = 0.5 [Hz];
        attribute severityThreshold : SeverityIndex = 5.0;
        attribute voidFractionThreshold : VoidFraction = 0.7;
        attribute pressureFluctuationThreshold : Pressure = 500000.0 [Pa];
        
        action def AnalyzeRegime {
            in readings : SensorReading[0..*];
            out regime : FlowRegime;
            out slugFrequency : Frequency;
            out severity : SeverityIndex;
            out slugEvents : SlugEvent[0..*];
            
            private action preprocessData {
                in readings : SensorReading[0..*];
                out filteredReadings : SensorReading[0..*];
            }
            
            then action detectPressureFluctuations {
                in filteredReadings : SensorReading[0..*];
                out fluctuations : PressureDiff[0..*];
            }
            
            then action detectVoidFractionChanges {
                in filteredReadings : SensorReading[0..*];
                out voidFractionChanges : VoidFraction[0..*];
            }
            
            then action classifyRegime {
                in fluctuations : PressureDiff[0..*];
                in voidFractionChanges : VoidFraction[0..*];
                out regime : FlowRegime;
            }
            
            then action calculateSlugParameters {
                in regime : FlowRegime;
                in filteredReadings : SensorReading[0..*];
                out slugFrequency : Frequency;
                out severity : SeverityIndex;
                out slugEvents : SlugEvent[0..*];
            }
        }
    }
    
    part def SystemController {
        attribute controllerId : String;
        attribute maxOperatingPressure : Pressure = 8000000.0 [Pa];
        attribute alarmPressureThreshold : Pressure = 9000000.0 [Pa];
        attribute emergencyPressureThreshold : Pressure = 9500000.0 [Pa];
        attribute maxSlugFrequency : Frequency = 2.0 [Hz];
        attribute controlLoopTime : Duration = 0.1 [s];
        attribute isOperational : Boolean = true;
        
        part regimeAnalyzer : FlowRegimeAnalyzer {
            attribute analyzerId = "FRA-001";
        }
        
        port sensorDataIn : DataInputPort[0..*];
        port valveControlOut : ControlOutputPort;
        port alarmOut : AlarmOutputPort;
        port slugEventOut : SlugEventPort;
        
        // State Machine Definition
        state def ControllerStateMachine {
            entry action initializeController {
                log "Controller initialized";
            }
            
            state StartUp {
                entry action performStartupSequence {
                    log "Starting up controller";
                }
                do action runDiagnostics {
                    out diagnosticResult : Boolean;
                }
                exit action logStartupComplete;
            }
            
            state NormalMonitoring {
                entry action enterNormalMode {
                    log "Entering normal monitoring mode";
                }
                do action continuouslyMonitorSensors {
                    in readings : SensorReading[0..*];
                    out analysisResult : FlowRegime;
                }
                exit action logNormalExit;
            }
            
            state SlugDetection {
                entry action enterDetectionMode {
                    log "Slug detection mode activated";
                }
                do action analyzeSlugCharacteristics {
                    in readings : SensorReading[0..*];
                    out slugFrequency : Frequency;
                    out severity : SeverityIndex;
                }
                exit action logDetectionResults;
            }
            
            state ActiveMitigation {
                entry action activateMitigation {
                    log "Activating slug mitigation";
                }
                do action continuouslyAdjustValve {
                    in slugFrequency : Frequency;
                    in severity : SeverityIndex;
                    out valveCommand : ValveCommand;
                }
                exit action logMitigationResults;
            }
            
            state AlarmState {
                entry action triggerAlarmSequence {
                    out alarmLevel : AlarmLevel = AlarmLevel::HIGH;
                }
                do action maintainAlarmStatus {
                    out alarmLevel : AlarmLevel;
                }
                exit action logAlarmEvent;
            }
            
            state EmergencyShutdown {
                entry action initiateEmergencyShutdown {
                    log "Emergency shutdown initiated";
                }
                do action executeShutdownSequence {
                    out shutdownComplete : Boolean;
                }
                exit action logShutdownComplete;
            }
            
            state Maintenance {
                entry action enterMaintenanceMode {
                    log "Entering maintenance mode";
                }
                do action runMaintenanceProcedures;
                exit action logMaintenanceComplete;
            }
            
            // Transitions
            transition StartUp_to_NormalMonitoring
                from StartUp to NormalMonitoring
                when (diagnosticResult == true) {
                    action transitionToNormal;
                }
            
            transition NormalMonitoring_to_SlugDetection
                from NormalMonitoring to SlugDetection
                when (analysisResult == FlowRegime::SLUG) {
                    action escalateToDetection;
                }
            
            transition NormalMonitoring_to_AlarmState
                from NormalMonitoring to AlarmState
                when (readings.pressure > alarmPressureThreshold) {
                    action escalateToAlarm;
                }
            
            transition SlugDetection_to_ActiveMitigation
                from SlugDetection to ActiveMitigation
                when (slugFrequency > regimeAnalyzer.slugFrequencyThreshold) {
                    action activateMitigation;
                }
            
            transition SlugDetection_to_NormalMonitoring
                from SlugDetection to NormalMonitoring
                when (slugFrequency < regimeAnalyzer.slugFrequencyThreshold) {
                    action returnToNormal;
                }
            
            transition ActiveMitigation_to_AlarmState
                from ActiveMitigation to AlarmState
                when (readings.pressure > alarmPressureThreshold) {
                    action escalateToAlarm;
                }
            
            transition ActiveMitigation_to_NormalMonitoring
                from ActiveMitigation to NormalMonitoring
                when (slugFrequency < regimeAnalyzer.slugFrequencyThreshold 
                      and readings.pressure < maxOperatingPressure) {
                    action returnToNormal;
                }
            
            transition AlarmState_to_EmergencyShutdown
                from AlarmState to EmergencyShutdown
                when (readings.pressure > emergencyPressureThreshold) {
                    action triggerEmergency;
                }
            
            transition AlarmState_to_ActiveMitigation
                from AlarmState to ActiveMitigation
                when (readings.pressure < maxOperatingPressure 
                      and slugFrequency > regimeAnalyzer.slugFrequencyThreshold) {
                    action resumeMitigation;
                }
            
            transition AlarmState_to_NormalMonitoring
                from AlarmState to NormalMonitoring
                when (readings.pressure < maxOperatingPressure 
                      and slugFrequency < regimeAnalyzer.slugFrequencyThreshold) {
                    action returnToNormal;
                }
            
            transition any_to_Maintenance
                from * to Maintenance
                when (maintenanceRequested == true) {
                    action enterMaintenance;
                }
            
            transition Maintenance_to_StartUp
                from Maintenance to StartUp
                when (maintenanceComplete == true) {
                    action restartSystem;
                }
        }
        
        state machine controllerState : ControllerStateMachine;
        
        action def ProcessSensorData {
            in readings : SensorReading[0..*];
            out regime : FlowRegime;
            out slugFrequency : Frequency;
            out severity : SeverityIndex;
            out slugEvents : SlugEvent[0..*];
        }
        
        action def GenerateValveCommand {
            in regime : FlowRegime;
            in slugFrequency : Frequency;
            in severity : SeverityIndex;
            in currentPressure : Pressure;
            out command : ValveCommand;
            
            private action calculateTargetOpening {
                in slugFrequency : Frequency;
                in severity : SeverityIndex;
                in currentPressure : Pressure;
                out targetOpening : ValveOpening;
            }
            
            then action createCommand {
                in targetOpening : ValveOpening;
                out command : ValveCommand;
            }
        }
        
        action def EvaluateAlarmCondition {
            in pressure : Pressure;
            in slugFrequency : Frequency;
            in severity : SeverityIndex;
            out alarmLevel : AlarmLevel;
        }
    }
    
    part def PipelineSegment {
        attribute segmentId : String;
        attribute length : Length;
        attribute diameter : Diameter = 0.5 [m];
        attribute wallThickness : Real = 0.02 [m];
        attribute material : String = "Carbon Steel";
        attribute inclination : Angle = 0.0 [deg];
        attribute maxPressure : Pressure = 10000000.0 [Pa];
        
        port flowIn : FlowPort;
        port flowOut : FlowPort;
        
        action def TransportMixture {
            in mixture : GasLiquidMixture;
            out transportedMixture : GasLiquidMixture;
            
            private action calculatePressureDrop {
                in mixture : GasLiquidMixture;
                in length : Length;
                in diameter : Diameter;
                out pressureDrop : PressureDiff;
            }
            
            then action applyPressureDrop {
                in mixture : GasLiquidMixture;
                in pressureDrop : PressureDiff;
                out transportedMixture : GasLiquidMixture;
            }
        }
        
        action def DetectFlowConditions {
            out flowRegime : FlowRegime;
            out pressure : Pressure;
            out voidFraction : VoidFraction;
        }
    }
    
    part def SlugCatcher {
        attribute vesselId : String;
        attribute vesselType : String = "Horizontal Multi-phase Separator";
        attribute volume : Volume = 50.0 [m3];
        attribute length : Length = 20.0 [m];
        attribute diameter : Diameter = 3.0 [m];
        attribute maxOperatingPressure : Pressure = 15000000.0 [Pa];
        attribute designPressure : Pressure = 20000000.0 [Pa];
        attribute testPressure : Pressure = 25000000.0 [Pa];
        attribute liquidCapacity : Volume = 30.0 [m3];
        attribute gasCapacity : Volume = 20.0 [m3];
        attribute isOperational : Boolean = true;
        
        port flowIn : FlowPort;
        port gasOut : GasPort;
        port liquidOut : LiquidPort;
        
        action def AbsorbSlugMomentum {
            in incomingMixture : GasLiquidMixture;
            out absorbedMixture : GasLiquidMixture;
            
            private action decelerateSlug {
                in incomingMixture : GasLiquidMixture;
                out deceleratedMixture : GasLiquidMixture;
            }
            
            then action distributeEnergy {
                in deceleratedMixture : GasLiquidMixture;
                out absorbedMixture : GasLiquidMixture;
            }
        }
        
        action def SeparatePhases {
            in mixture : GasLiquidMixture;
            out gas : Gas;
            out liquid : Liquid;
            
            private action gravitySeparation {
                in mixture : GasLiquidMixture;
                out partiallySeparated : GasLiquidMixture;
            }
            
            then action extractGas {
                in partiallySeparated : GasLiquidMixture;
                out gas : Gas;
                out remainingMixture : GasLiquidMixture;
            }
            
            then action extractLiquid {
                in remainingMixture : GasLiquidMixture;
                out liquid : Liquid;
            }
        }
        
        action def BufferFlow {
            in mixture : GasLiquidMixture;
            out bufferedMixture : GasLiquidMixture;
            
            private action accumulate {
                in mixture : GasLiquidMixture;
                out storedMixture : GasLiquidMixture;
            }
            
            then action release {
                in storedMixture : GasLiquidMixture;
                out bufferedMixture : GasLiquidMixture;
            }
        }
        
        action def MonitorLevels {
            out liquidLevel : Real;
            out gasLevel : Real;
            out pressure : Pressure;
        }
    }
    
    part def AlarmSystem {
        attribute alarmId : String;
        attribute currentLevel : AlarmLevel = AlarmLevel::NONE;
        attribute isActivated : Boolean = false;
        attribute alarmHistory : String[0..*];
        
        port alarmIn : AlarmInputPort;
        
        action def TriggerAlarm {
            in level : AlarmLevel;
            out alarmActive : Boolean;
            
            private action updateLevel {
                in level : AlarmLevel;
                out newLevel : AlarmLevel;
            }
            
            then action activateIndicators {
                in newLevel : AlarmLevel;
                out alarmActive : Boolean;
            }
            
            then action logEvent {
                in newLevel : AlarmLevel;
                out logEntry : String;
            }
        }
        
        action def ResetAlarm {
            out alarmActive : Boolean = false;
            
            private action clearIndicators {
                out cleared : Boolean;
            }
            
            then action updateLevel {
                out newLevel : AlarmLevel = AlarmLevel::NONE;
            }
        }
    }
    
    part def EmergencyShutdownSystem {
        attribute systemId : String;
        attribute shutdownTime : Duration = 2.0 [s];
        attribute isShutdown : Boolean = false;
        attribute isArmed : Boolean = true;
        attribute shutdownSequence : String[0..*];
        
        port shutdownSignal : AlarmInputPort;
        
        action def InitiateShutdown {
            out shutdownCommand : Boolean;
            
            private action verifyEmergency {
                in signal : AlarmLevel;
                out isEmergency : Boolean;
            }
            
            then action activateShutdown {
                in isEmergency : Boolean;
                out shutdownCommand : Boolean;
            }
        }
        
        action def ExecuteShutdownSequence {
            in shutdownCommand : Boolean;
            out shutdownComplete : Boolean;
            
            private action closeMainValve {
                out valveClosed : Boolean;
            }
            
            then action isolatePipeline {
                out isolationComplete : Boolean;
            }
            
            then action ventPressure {
                out ventingComplete : Boolean;
            }
            
            then action confirmShutdown {
                in valveClosed : Boolean;
                in isolationComplete : Boolean;
                in ventingComplete : Boolean;
                out shutdownComplete : Boolean;
            }
        }
        
        action def ResetSystem {
            out resetComplete : Boolean;
        }
    }
    
    // ===== Main System Assembly =====
    part def SlugFlowControlSystem {
        attribute systemId : String = "SFCS-001";
        attribute installationDate : String;
        attribute location : String;
        attribute designCapacity : MassFlowRate = 100.0 [kg/s];
        attribute maxOperatingPressure : Pressure = 8000000.0 [Pa];
        
        // Pipeline segments
        part upstreamPipeline : PipelineSegment {
            attribute segmentId = "PL-001";
            attribute length = 500.0 [m];
        }
        
        part midstreamPipeline : PipelineSegment {
            attribute segmentId = "PL-002";
            attribute length = 1000.0 [m];
        }
        
        part downstreamPipeline : PipelineSegment {
            attribute segmentId = "PL-003";
            attribute length = 300.0 [m];
        }
        
        // Sensors - Pressure Transducers
        part pressureTransducer1 : PressureTransducer {
            attribute sensorId = "PT-001";
        }
        
        part pressureTransducer2 : PressureTransducer {
            attribute sensorId = "PT-002";
        }
        
        part pressureTransducer3 : PressureTransducer {
            attribute sensorId = "PT-003";
        }
        
        // Sensors - Void Fraction Meters
        part voidFractionMeter1 : VoidFractionMeter {
            attribute sensorId = "VFM-001";
        }
        
        part voidFractionMeter2 : VoidFractionMeter {
            attribute sensorId = "VFM-002";
        }
        
        // Control system
        part controller : SystemController {
            attribute controllerId = "SC-001";
        }
        
        // Throttle valve
        part throttleValve : ThrottleValve {
            attribute valveId = "TV-001";
        }
        
        // Slug catcher
        part slugCatcher : SlugCatcher {
            attribute vesselId = "SC-001";
        }
        
        // Safety systems
        part alarmSystem : AlarmSystem {
            attribute alarmId = "AS-001";
        }
        
        part emergencyShutdown : EmergencyShutdownSystem {
            attribute systemId = "ESD-001";
        }
        
        // ===== Connections =====
        
        // Pipeline flow connections
        connection upstreamToMidstream
            from upstreamPipeline.flowOut to midstreamPipeline.flowIn;
        
        connection midstreamToDownstream
            from midstreamPipeline.flowOut to downstreamPipeline.flowIn;
        
        connection downstreamToValve
            from downstreamPipeline.flowOut to throttleValve.flowIn;
        
        connection valveToSlugCatcher
            from throttleValve.flowOut to slugCatcher.flowIn;
        
        // Sensor data connections to controller
        connection pt1DataToController
            from pressureTransducer1.dataOut to controller.sensorDataIn;
        
        connection pt2DataToController
            from pressureTransducer2.dataOut to controller.sensorDataIn;
        
        connection pt3DataToController
            from pressureTransducer3.dataOut to controller.sensorDataIn;
        
        connection vfm1DataToController
            from voidFractionMeter1.dataOut to controller.sensorDataIn;
        
        connection vfm2DataToController
            from voidFractionMeter2.dataOut to controller.sensorDataIn;
        
        // Control signal connection
        connection controllerToValveControl
            from controller.valveControlOut to throttleValve.controlIn;
        
        // Alarm connections
        connection controllerToAlarm
            from controller.alarmOut to alarmSystem.alarmIn;
        
        connection controllerToEmergencyShutdown
            from controller.alarmOut to emergencyShutdown.shutdownSignal;
        
        // ===== System-level Actions =====
        action def SystemStartup {
            out systemReady : Boolean;
            
            private action initializeSensors {
                out sensorsReady : Boolean;
            }
            
            then action initializeController {
                out controllerReady : Boolean;
            }
            
            then action initializeValve {
                out valveReady : Boolean;
            }
            
            then action verifySafetySystems {
                out safetyReady : Boolean;
            }
            
            then action confirmSystemReady {
                in sensorsReady : Boolean;
                in controllerReady : Boolean;
                in valveReady : Boolean;
                in safetyReady : Boolean;
                out systemReady : Boolean;
            }
        }
        
        action def SystemShutdown {
            out shutdownComplete : Boolean;
            
            private action closeValve {
                out valveClosed : Boolean;
            }
            
            then action stopSensors {
                out sensorsStopped : Boolean;
            }
            
            then action deenergizeController {
                out controllerOff : Boolean;
            }
            
            then action confirmShutdown {
                in valveClosed : Boolean;
                in sensorsStopped : Boolean;
                in controllerOff : Boolean;
                out shutdownComplete : Boolean;
            }
        }
        
        action def ContinuousOperation {
            in operationMode : SystemMode;
            
            private action acquireSensorData {
                out readings : SensorReading[0..*];
            }
            
            then action processData {
                in readings : SensorReading[0..*];
                out regime : FlowRegime;
                out slugFrequency : Frequency;
                out severity : SeverityIndex;
            }
            
            then action evaluateControlAction {
                in regime : FlowRegime;
                in slugFrequency : Frequency;
                in severity : SeverityIndex;
                out controlAction : ControlAction;
            }
            
            then action executeControlAction {
                in controlAction : ControlAction;
                out actionComplete : Boolean;
            }
            
            then action logOperation {
                in actionComplete : Boolean;
                out logEntry : String;
            }
        }
    }
    
    // ===== Requirements =====
    
    requirement def PressureMonitoringRequirement {
        attribute requirementId : String = "REQ-001";
        attribute description : String = "System shall monitor pipeline pressure at minimum 3 locations";
        attribute minSensorCount : Integer = 3;
        attribute samplingRate : Frequency = 1000.0 [Hz];
        attribute accuracy : Pressure = 1000.0 [Pa];
        
        subject pressureTransducers : PressureTransducer[1..*];
        
        objective {
            assert pressureTransducers.size >= minSensorCount
            assert pressureTransducers.samplingRate >= samplingRate
            assert pressureTransducers.accuracy <= accuracy
        }
    }
    
    requirement def VoidFractionMonitoringRequirement {
        attribute requirementId : String = "REQ-002";
        attribute description : String = "System shall monitor void fraction using gamma-ray densitometry";
        attribute minSensorCount : Integer = 2;
        attribute samplingRate : Frequency = 100.0 [Hz];
        attribute accuracy : VoidFraction = 0.02;
        attribute technique : String = "Gamma-ray densitometry";
        
        subject voidFractionMeters : VoidFractionMeter[1..*];
        
        objective {
            assert voidFractionMeters.size >= minSensorCount
            assert voidFractionMeters.samplingRate >= samplingRate
            assert voidFractionMeters.accuracy <= accuracy
            assert voidFractionMeters.measurementTechnique == technique
        }
    }
    
    requirement def SlugDetectionRequirement {
        attribute requirementId : String = "REQ-003";
        attribute description : String = "System shall detect slug flow within 2 seconds";
        attribute maxDetectionTime : Duration = 2.0 [s];
        attribute slugFrequencyThreshold : Frequency = 0.5 [Hz];
        attribute voidFractionThreshold : VoidFraction = 0.7;
        
        subject controller : SystemController;
        
        objective {
            assert controller.regimeAnalyzer.analysisWindow <= maxDetectionTime
            assert controller.regimeAnalyzer.slugFrequencyThreshold == slugFrequencyThreshold
            assert controller.regimeAnalyzer.voidFractionThreshold == voidFractionThreshold
        }
    }
    
    requirement def ValveControlResponseRequirement {
        attribute requirementId : String = "REQ-004";
        attribute description : String = "Throttle valve shall respond within 1 second";
        attribute maxResponseTime : Duration = 1.0 [s];
        attribute minOpeningRange : ValveOpening = 0.0 [%];
        attribute maxOpeningRange : ValveOpening = 100.0 [%];
        
        subject valve : ThrottleValve;
        
        objective {
            assert valve.responseTime <= maxResponseTime
            assert valve.minOpening == minOpeningRange
            assert valve.maxOpening == maxOpeningRange
        }
    }
    
    requirement def SlugCatcherCapacityRequirement {
        attribute requirementId : String = "REQ-005";
        attribute description : String = "Slug catcher shall have minimum 50 m3 volume";
        attribute minVolume : Volume = 50.0 [m3];
        attribute minDesignPressure : Pressure = 20000000.0 [Pa];
        
        subject slugCatcher : SlugCatcher;
        
        objective {
            assert slugCatcher.volume >= minVolume
            assert slugCatcher.designPressure >= minDesignPressure
        }
    }
    
    requirement def EmergencyShutdownRequirement {
        attribute requirementId : String = "REQ-006";
        attribute description : String = "System shall initiate emergency shutdown at 9.5 MPa";
        attribute emergencyPressureThreshold : Pressure = 9500000.0 [Pa];
        attribute maxShutdownTime : Duration = 2.0 [s];
        
        subject system : SlugFlowControlSystem;
        
        objective {
            assert system.controller.emergencyPressureThreshold == emergencyPressureThreshold
            assert system.emergencyShutdown.shutdownTime <= maxShutdownTime
        }
    }
    
    requirement def FlowRegimeAnalysisRequirement {
        attribute requirementId : String = "REQ-007";
        attribute description : String = "Controller shall classify flow regime as normal, bubbly, or slug";
        attribute supportedRegimes : FlowRegime[3] = {FlowRegime::NORMAL, FlowRegime::BUBBLY, FlowRegime::SLUG};
        
        subject analyzer : FlowRegimeAnalyzer;
        
        objective {
            assert analyzer.slugFrequencyThreshold == 0.5 [Hz]
            assert analyzer.severityThreshold == 5.0
        }
    }
    
    requirement def SystemReliabilityRequirement {
        attribute requirementId : String = "REQ-008";
        attribute description : String = "System shall maintain 99.9% uptime";
        attribute minUptime : Real = 0.999;
        attribute mtbf : Duration = 8760.0 [s];
        
        subject system : SlugFlowControlSystem;
        
        objective {
            assert system.controller.isOperational == true
            assert system.throttleValve.isOperational == true
            assert system.slugCatcher.isOperational == true
        }
    }
    
    // ===== Requirement Satisfaction =====
    
    requirement pressureMonitoring : PressureMonitoringRequirement {
        subject pressureTransducers = {SlugFlowControlSystem.pressureTransducer1, 
                                       SlugFlowControlSystem.pressureTransducer2, 
                                       SlugFlowControlSystem.pressureTransducer3};
    }
    
    requirement voidFractionMonitoring : VoidFractionMonitoringRequirement {
        subject voidFractionMeters = {SlugFlowControlSystem.voidFractionMeter1, 
                                      SlugFlowControlSystem.voidFractionMeter2};
    }
    
    requirement slugDetection : SlugDetectionRequirement {
        subject controller = SlugFlowControlSystem.controller;
    }
    
    requirement valveControlResponse : ValveControlResponseRequirement {
        subject valve = SlugFlowControlSystem.throttleValve;
    }
    
    requirement slugCatcherCapacity : SlugCatcherCapacityRequirement {
        subject slugCatcher = SlugFlowControlSystem.slugCatcher;
    }
    
    requirement emergencyShutdown : EmergencyShutdownRequirement {
        subject system = SlugFlowControlSystem;
    }
    
    requirement flowRegimeAnalysis : FlowRegimeAnalysisRequirement {
        subject analyzer = SlugFlowControlSystem.controller.regimeAnalyzer;
    }
    
    requirement systemReliability : SystemReliabilityRequirement {
        subject system = SlugFlowControlSystem;
    }
}
