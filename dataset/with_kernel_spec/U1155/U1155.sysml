package IndustrialReactorAutomation {
    private import ScalarValues::*;
    
    // --- Value Types ---
    value def TemperatureValue :> Real;
    value def PressureValue :> Real;
    value def LevelValue :> Real;
    value def FlowValue :> Real;
    value def PowerValue :> Real;
    value def PositionValue :> Real;
    value def SpeedValue :> Real;

    // --- Enumerations ---
    enum def OperationMode {
        automatic;
        manual;
        maintenance;
    }
    enum def AlarmStatus {
        normal;
        warning;
        critical;
    }

    // --- Items ---
    item def SensorReading {
        attribute value : Real;
        attribute timestamp : Real;
    }
    item def TemperatureReading :> SensorReading {
        attribute :>> value : TemperatureValue;
    }
    item def PressureReading :> SensorReading {
        attribute :>> value : PressureValue;
    }
    item def LevelReading :> SensorReading {
        attribute :>> value : LevelValue;
    }
    item def FlowReading :> SensorReading {
        attribute :>> value : FlowValue;
    }

    // --- Port Definitions ---
    port def TempOutPort {
        out tempData : TemperatureReading;
    }
    port def PressOutPort {
        out pressData : PressureReading;
    }
    port def LevelOutPort {
        out levelData : LevelReading;
    }
    port def FlowOutPort {
        out flowData : FlowReading;
    }
    port def TempInPort {
        in tempData : TemperatureReading;
    }
    port def PressInPort {
        in pressData : PressureReading;
    }
    port def LevelInPort {
        in levelData : LevelReading;
    }
    port def FlowInPort {
        in flowData : FlowReading;
    }
    port def PowerInPort {
        in cmd : PowerValue;
    }
    port def PositionInPort {
        in cmd : PositionValue;
    }
    port def SpeedInPort {
        in cmd : SpeedValue;
    }
    port def PowerOutPort {
        out cmd : PowerValue;
    }
    port def PositionOutPort {
        out cmd : PositionValue;
    }
    port def SpeedOutPort {
        out cmd : SpeedValue;
    }
    port def TempSetpointOutPort {
        out setpoint : TemperatureValue;
    }
    port def PressSetpointOutPort {
        out setpoint : PressureValue;
    }
    port def LevelSetpointOutPort {
        out setpoint : LevelValue;
    }
    port def FlowSetpointOutPort {
        out setpoint : FlowValue;
    }
    port def TempSetpointInPort {
        in setpoint : TemperatureValue;
    }
    port def PressSetpointInPort {
        in setpoint : PressureValue;
    }
    port def LevelSetpointInPort {
        in setpoint : LevelValue;
    }
    port def FlowSetpointInPort {
        in setpoint : FlowValue;
    }
    port def ModeInPort {
        in mode : OperationMode;
    }
    port def AlarmOutPort {
        out alarm : AlarmStatus;
    }

    // --- Sensor & Actuator Parts ---
    part def TemperatureSensor {
        port tempDataOut : TempOutPort;
        attribute measuredTemp : TemperatureValue;
    }
    part def PressureSensor {
        port pressDataOut : PressOutPort;
        attribute measuredPress : PressureValue;
    }
    part def LevelSensor {
        port levelDataOut : LevelOutPort;
        attribute measuredLevel : LevelValue;
    }
    part def FlowMeter {
        port flowDataOut : FlowOutPort;
        attribute measuredFlow : FlowValue;
    }
    part def HeatingElement {
        port cmdIn : PowerInPort;
        attribute powerLevel : PowerValue;
    }
    part def ControlValve {
        port cmdIn : PositionInPort;
        attribute opening : PositionValue;
    }
    part def VariableSpeedDrive {
        port cmdIn : SpeedInPort;
        attribute speed : SpeedValue;
    }

    // --- Control System Parts ---
    part def TempPID {
        port measurementIn : TempInPort;
        port setpointIn : TempSetpointInPort;
        port commandOut : PowerOutPort;
        
        attribute kp : Real = 1.0;
        attribute ki : Real = 0.1;
        attribute kd : Real = 0.05;
        
        action computeControl {
            in currentMeasurement : TemperatureValue;
            in desiredSetpoint : TemperatureValue;
            out computedCommand : PowerValue;
        }
    }
    
    part def PressPID {
        port measurementIn : PressInPort;
        port setpointIn : PressSetpointInPort;
        port commandOut : PositionOutPort;
        
        attribute kp : Real = 1.0;
        attribute ki : Real = 0.1;
        attribute kd : Real = 0.05;
        
        action computeControl {
            in currentMeasurement : PressureValue;
            in desiredSetpoint : PressureValue;
            out computedCommand : PositionValue;
        }
    }
    
    part def LevelPID {
        port measurementIn : LevelInPort;
        port setpointIn : LevelSetpointInPort;
        port commandOut : PositionOutPort;
        
        attribute kp : Real = 1.0;
        attribute ki : Real = 0.1;
        attribute kd : Real = 0.05;
        
        action computeControl {
            in currentMeasurement : LevelValue;
            in desiredSetpoint : LevelValue;
            out computedCommand : PositionValue;
        }
    }
    
    part def FlowPID {
        port measurementIn : FlowInPort;
        port setpointIn : FlowSetpointInPort;
        port commandOut : SpeedOutPort;
        
        attribute kp : Real = 1.0;
        attribute ki : Real = 0.1;
        attribute kd : Real = 0.05;
        
        action computeControl {
            in currentMeasurement : FlowValue;
            in desiredSetpoint : FlowValue;
            out computedCommand : SpeedValue;
        }
    }

    // --- Events for mode transitions ---
    event def toManual;
    event def toAutomatic;
    event def toMaintenance;

    // --- State Machine Definition ---
    state def ReactorControlState {
        state automatic;
        state manual;
        state maintenance;
        transition initial -> automatic;
        transition automatic -> manual on toManual;
        transition manual -> automatic on toAutomatic;
        transition automatic -> maintenance on toMaintenance;
        transition manual -> maintenance on toMaintenance;
        transition maintenance -> automatic on toAutomatic;
        transition maintenance -> manual on toManual;
    }

    part def SupervisoryController {
        port modeIn : ModeInPort;
        port alarmOut : AlarmOutPort;
        
        port tempSetpointOut : TempSetpointOutPort;
        port pressSetpointOut : PressSetpointOutPort;
        port levelSetpointOut : LevelSetpointOutPort;
        port flowSetpointOut : FlowSetpointOutPort;
        
        port processOutflow : FlowInPort;
        
        attribute currentMode : OperationMode = OperationMode::automatic;
        attribute currentAlarm : AlarmStatus = AlarmStatus::normal;
        
        state machine reactorControl : ReactorControlState;
    }

    part def DistributedControlSystem {
        port tempIn : TempInPort;
        port pressIn : PressInPort;
        port levelIn : LevelInPort;
        port inflowIn : FlowInPort;
        port outflowIn : FlowInPort;
        
        port modeIn : ModeInPort;
        port alarmOut : AlarmOutPort;
        
        port heaterCmdOut : PowerOutPort;
        port inflowCmdOut : PositionOutPort;
        port outflowCmdOut : PositionOutPort;
        port agitatorCmdOut : SpeedOutPort;
        
        part supervisory : SupervisoryController;
        part tempPID : TempPID;
        part pressPID : PressPID;
        part levelPID : LevelPID;
        part flowPID : FlowPID;
        
        bind tempIn = tempPID.measurementIn;
        bind pressIn = pressPID.measurementIn;
        bind levelIn = levelPID.measurementIn;
        bind inflowIn = flowPID.measurementIn;
        bind outflowIn = supervisory.processOutflow;
        
        bind heaterCmdOut = tempPID.commandOut;
        bind inflowCmdOut = levelPID.commandOut;
        bind outflowCmdOut = pressPID.commandOut;
        bind agitatorCmdOut = flowPID.commandOut;
        
        bind modeIn = supervisory.modeIn;
        bind alarmOut = supervisory.alarmOut;
        
        flow tempSPFlow of TemperatureValue from supervisory.tempSetpointOut.setpoint to tempPID.setpointIn.setpoint;
        flow pressSPFlow of PressureValue from supervisory.pressSetpointOut.setpoint to pressPID.setpointIn.setpoint;
        flow levelSPFlow of LevelValue from supervisory.levelSetpointOut.setpoint to levelPID.setpointIn.setpoint;
        flow flowSPFlow of FlowValue from supervisory.flowSetpointOut.setpoint to flowPID.setpointIn.setpoint;
    }

    part def ProcessReactor {
        port heaterCmdIn : PowerInPort;
        port inflowCmdIn : PositionInPort;
        port outflowCmdIn : PositionInPort;
        port agitatorCmdIn : SpeedInPort;
        
        port tempOut : TempOutPort;
        port pressOut : PressOutPort;
        port levelOut : LevelOutPort;
        port inflowOut : FlowOutPort;
        port outflowOut : FlowOutPort;
        
        part tempSensor : TemperatureSensor;
        part pressSensor : PressureSensor;
        part levelSensor : LevelSensor;
        part inflowMeter : FlowMeter;
        part outflowMeter : FlowMeter;
        part heater : HeatingElement;
        part inflowValve : ControlValve;
        part outflowValve : ControlValve;
        part agitatorDrive : VariableSpeedDrive;
        
        bind tempOut = tempSensor.tempDataOut;
        bind pressOut = pressSensor.pressDataOut;
        bind levelOut = levelSensor.levelDataOut;
        bind inflowOut = inflowMeter.flowDataOut;
        bind outflowOut = outflowMeter.flowDataOut;
        
        bind heaterCmdIn = heater.cmdIn;
        bind inflowCmdIn = inflowValve.cmdIn;
        bind outflowCmdIn = outflowValve.cmdIn;
        bind agitatorCmdIn = agitatorDrive.cmdIn;
    }

    part def ReactorAutomationSystem {
        part reactor : ProcessReactor;
        part dcs : DistributedControlSystem;
        
        flow tempFlow of TemperatureReading from reactor.tempOut.tempData to dcs.tempIn.tempData;
        flow pressFlow of PressureReading from reactor.pressOut.pressData to dcs.pressIn.pressData;
        flow levelFlow of LevelReading from reactor.levelOut.levelData to dcs.levelIn.levelData;
        flow inflowFlow of FlowReading from reactor.inflowOut.flowData to dcs.inflowIn.flowData;
        flow outflowFlow of FlowReading from reactor.outflowOut.flowData to dcs.outflowIn.flowData;
        
        flow heaterCmdFlow of PowerValue from dcs.heaterCmdOut.cmd to reactor.heaterCmdIn.cmd;
        flow inflowCmdFlow of PositionValue from dcs.inflowCmdOut.cmd to reactor.inflowCmdIn.cmd;
        flow outflowCmdFlow of PositionValue from dcs.outflowCmdOut.cmd to reactor.outflowCmdIn.cmd;
        flow agitatorCmdFlow of SpeedValue from dcs.agitatorCmdOut.cmd to reactor.agitatorCmdIn.cmd;
    }

    requirement def ReactorSafetyRequirements {
        doc /* Requirements for safe and efficient reactor operation */;
        
        requirement MaintainTemperature {
            doc /* The system shall maintain the reactor temperature within +/- 2 degrees of the setpoint. */;
        }
        requirement MaintainPressure {
            doc /* The system shall maintain the reactor pressure below critical limits. */;
        }
        requirement AlarmGeneration {
            doc /* The system shall generate an alarm if any sensor exceeds safe operating limits. */;
        }
        requirement OperationModes {
            doc /* The system shall support automatic, manual, and maintenance modes. */;
        }
    }
}
