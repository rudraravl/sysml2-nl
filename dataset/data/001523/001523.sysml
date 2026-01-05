package 'Industrial Automation System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureSetpoint :> ISQ::ThermodynamicTemperatureValue;
    attribute def PressureSetpoint :> ISQ::PressureValue;
    attribute def FlowRateSetpoint :> ISQ::VolumeFlowRateValue;
    attribute def PositionSetpoint :> ISQ::LengthValue;
    
    item def ControlSignal {
        attribute signalValue : Real;
        attribute timestamp : Real;
        attribute signalType : String;
    }
    
    item def SensorReading {
        attribute measuredValue : Real;
        attribute sensorId : String;
        attribute timestamp : Real;
        attribute quality : Real;
    }
    
    item def AlarmEvent {
        attribute severity : AlarmSeverity;
        attribute description : String;
        attribute sourceId : String;
        attribute timestamp : Real;
    }
    
    item def ProcessCommand {
        attribute commandType : String;
        attribute targetValue : Real;
        attribute priority : Integer;
    }
    
    enum def AlarmSeverity {
        enum info;
        enum warning;
        enum critical;
        enum emergency;
    }
    
    enum def OperatingMode {
        enum manual;
        enum automatic;
        enum maintenance;
        enum emergency;
    }
    
    port def SensorOutputPort {
        out item reading : SensorReading;
    }
    
    port def ActuatorInputPort {
        in item command : ControlSignal;
    }
    
    port def ControllerSensorPort {
        in item sensorData : SensorReading;
    }
    
    port def ControllerActuatorPort {
        out item controlOutput : ControlSignal;
    }
    
    port def SupervisoryControlPort {
        in item processData : SensorReading;
        out item setpointCommand : ProcessCommand;
        out item alarmNotification : AlarmEvent;
    }
    
    part def TemperatureSensor {
        attribute sensorId : String;
        attribute currentReading : TemperatureValue;
        attribute calibrationOffset : TemperatureValue;
        port output : SensorOutputPort;
    }
    
    part def PressureSensor {
        attribute sensorId : String;
        attribute currentReading : PressureValue;
        attribute calibrationOffset : PressureValue;
        port output : SensorOutputPort;
    }
    
    part def FlowMeter {
        attribute sensorId : String;
        attribute currentReading : VolumeFlowRateValue;
        attribute totalVolume : VolumeValue;
        port output : SensorOutputPort;
    }
    
    part def LevelSensor {
        attribute sensorId : String;
        attribute currentReading : LengthValue;
        attribute maxLevel : LengthValue;
        port output : SensorOutputPort;
    }
    
    part def ControlValve {
        attribute valveId : String;
        attribute currentPosition : Real;
        attribute minPosition : Real := 0.0;
        attribute maxPosition : Real := 100.0;
        port input : ActuatorInputPort;
    }
    
    part def VariableSpeedDrive {
        attribute driveId : String;
        attribute currentSpeed : Real;
        attribute ratedSpeed : Real;
        attribute powerOutput : PowerValue;
        port input : ActuatorInputPort;
    }
    
    part def HeatingElement {
        attribute elementId : String;
        attribute powerLevel : Real;
        attribute maxPower : PowerValue;
        attribute efficiency : Real;
        port input : ActuatorInputPort;
    }
    
    action def AcquireSensorData {
        in sensorId : String;
        out reading : SensorReading;
    }
    
    action def ComputePIDControl {
        in setpoint : Real;
        in processVariable : Real;
        in proportionalGain : Real;
        in integralGain : Real;
        in derivativeGain : Real;
        in previousError : Real;
        in integralAccumulator : Real;
        in deltaTime : Real;
        out controlOutput : Real;
        out newError : Real;
        out newIntegral : Real;
    }
    
    action def IssueActuatorCommand {
        in controlValue : Real;
        in actuatorId : String;
        in commandType : String;
        out command : ControlSignal;
    }
    
    action def EvaluateAlarmConditions {
        in processValue : Real;
        in lowAlarmLimit : Real;
        in highAlarmLimit : Real;
        in criticalLowLimit : Real;
        in criticalHighLimit : Real;
        out alarmActive : Boolean;
        out alarmSeverity : AlarmSeverity;
    }
    
    action def ValidateSensorData {
        in reading : SensorReading;
        in minValidValue : Real;
        in maxValidValue : Real;
        out isValid : Boolean;
        out validatedReading : Real;
    }
    
    part def PIDController {
        attribute controllerId : String;
        attribute setpoint : Real;
        attribute kp : Real;
        attribute ki : Real;
        attribute kd : Real;
        attribute outputMin : Real := 0.0;
        attribute outputMax : Real := 100.0;
        
        private attribute errorPrevious : Real := 0.0;
        private attribute integralSum : Real := 0.0;
        private attribute cycleTime : Real := 1.0;
        
        port sensorInput : ControllerSensorPort;
        port actuatorOutput : ControllerActuatorPort;
        
        action def ControlCycle {
            first start;
            then merge continuousOperation;
            
            then action acquire : AcquireSensorData {
                in sensorId;
                out reading;
            }
            
            then action validate : ValidateSensorData {
                in reading = acquire.reading;
                in minValidValue;
                in maxValidValue;
                out isValid;
                out validatedReading;
            }
            
            then decide;
                if validate.isValid then computeControl;
                if not validate.isValid then handleInvalidData;
            
            action computeControl : ComputePIDControl {
                in setpoint = setpoint;
                in processVariable = validate.validatedReading;
                in proportionalGain = kp;
                in integralGain = ki;
                in derivativeGain = kd;
                in previousError = errorPrevious;
                in integralAccumulator = integralSum;
                in deltaTime = cycleTime;
                out controlOutput;
                out newError;
                out newIntegral;
            }
            
            then assign errorPrevious := computeControl.newError;
            then assign integralSum := computeControl.newIntegral;
            
            then action issueCommand : IssueActuatorCommand {
                in controlValue = computeControl.controlOutput;
                in actuatorId;
                in commandType;
                out command;
            }
            
            then action checkAlarms : EvaluateAlarmConditions {
                in processValue = validate.validatedReading;
                in lowAlarmLimit;
                in highAlarmLimit;
                in criticalLowLimit;
                in criticalHighLimit;
                out alarmActive;
                out alarmSeverity;
            }
            
            then continuousOperation;
            
            action handleInvalidData;
            then continuousOperation;
        }
        
        perform action controlCycle[*] ordered references ControlCycle;
    }
    
    part def SupervisoryController {
        attribute systemId : String;
        attribute operatingMode : OperatingMode;
        
        port supervisoryInterface : SupervisoryControlPort;
        
        perform action supervise[*] {
            action monitorProcessVariables;
            action optimizeSetpoints;
            action coordinateControllers;
            action manageAlarms;
            action logOperationalData;
            action handleOperatorCommands;
        }
    }
    
    part def ProcessReactor {
        attribute reactorId : String;
        attribute volume : VolumeValue;
        attribute maxTemperature : TemperatureValue;
        attribute maxPressure : PressureValue;
        attribute maxLevel : LengthValue;
        
        part temperatureSensor : TemperatureSensor {
            attribute :>> sensorId = "TE-201";
            attribute :>> calibrationOffset = 0.0;
        }
        
        part pressureSensor : PressureSensor {
            attribute :>> sensorId = "PT-201";
            attribute :>> calibrationOffset = 0.0;
        }
        
        part levelSensor : LevelSensor {
            attribute :>> sensorId = "LT-201";
            attribute :>> maxLevel = 10.0;
        }
        
        part inflowMeter : FlowMeter {
            attribute :>> sensorId = "FT-201";
            attribute :>> totalVolume = 0.0;
        }
        
        part outflowMeter : FlowMeter {
            attribute :>> sensorId = "FT-202";
            attribute :>> totalVolume = 0.0;
        }
        
        part heater : HeatingElement {
            attribute :>> elementId = "HE-201";
            attribute :>> maxPower = 50000.0;
            attribute :>> efficiency = 0.95;
        }
        
        part inflowValve : ControlValve {
            attribute :>> valveId = "FV-201";
        }
        
        part outflowValve : ControlValve {
            attribute :>> valveId = "FV-202";
        }
        
        part agitatorDrive : VariableSpeedDrive {
            attribute :>> driveId = "SD-201";
            attribute :>> ratedSpeed = 1800.0;
        }
    }
    
    part def DistributedControlSystem {
        attribute systemId : String;
        
        part temperatureController : PIDController {
            attribute :>> controllerId = "TIC-201";
            attribute :>> setpoint = 85.0;
            attribute :>> kp = 2.0;
            attribute :>> ki = 0.5;
            attribute :>> kd = 0.1;
        }
        
        part pressureController : PIDController {
            attribute :>> controllerId = "PIC-201";
            attribute :>> setpoint = 3.5;
            attribute :>> kp = 1.5;
            attribute :>> ki = 0.3;
            attribute :>> kd = 0.05;
        }
        
        part levelController : PIDController {
            attribute :>> controllerId = "LIC-201";
            attribute :>> setpoint = 7.5;
            attribute :>> kp = 1.0;
            attribute :>> ki = 0.2;
            attribute :>> kd = 0.08;
        }
        
        part flowController : PIDController {
            attribute :>> controllerId = "FIC-201";
            attribute :>> setpoint = 150.0;
            attribute :>> kp = 0.8;
            attribute :>> ki = 0.15;
            attribute :>> kd = 0.03;
        }
        
        part supervisor : SupervisoryController {
            attribute :>> systemId = "DCS-MAIN-01";
            attribute :>> operatingMode = OperatingMode::automatic;
        }
    }
    
    part automationSystem : DistributedControlSystem {
        attribute :>> systemId = "DCS-PLANT-A";
        
        part reactor : ProcessReactor {
            attribute :>> reactorId = "R-201";
            attribute :>> volume = 10000.0;
            attribute :>> maxTemperature = 150.0;
            attribute :>> maxPressure = 10.0;
            attribute :>> maxLevel = 10.0;
        }
        
        connect reactor.temperatureSensor.output to temperatureController.sensorInput;
        connect temperatureController.actuatorOutput to reactor.heater.input;
        
        connect reactor.pressureSensor.output to pressureController.sensorInput;
        connect pressureController.actuatorOutput to reactor.outflowValve.input;
        
        connect reactor.levelSensor.output to levelController.sensorInput;
        connect levelController.actuatorOutput to reactor.inflowValve.input;
        
        connect reactor.inflowMeter.output to flowController.sensorInput;
        connect flowController.actuatorOutput to reactor.inflowValve.input;
        
        perform action automateProcessControl {
            doc /* 
                The primary function of this industrial automation system is to continuously 
                monitor and control a chemical process reactor to maintain safe and optimal 
                operating conditions. The distributed control system automatically regulates 
                temperature, pressure, level, and flow rate through coordinated PID control 
                loops that acquire sensor data, validate measurements, compute appropriate 
                control actions, and adjust actuators in real-time. The supervisory controller 
                coordinates multiple control loops, optimizes setpoints for process efficiency, 
                manages alarm conditions, and provides operational visibility while ensuring 
                the process remains within safe operating limits at all times.
            */
            
            first start;
            
            action temperatureRegulation {
                perform temperatureController.controlCycle;
            }
            
            action pressureRegulation {
                perform automationSystem.pressureController.controlCycle;
            }
            
            action levelRegulation {
                perform automationSystem.levelController.controlCycle;
            }
            
            action flowRegulation {
                perform flowController.controlCycle;
            }
            
            action supervisoryControl {
                perform supervisor.supervise;
            }
        }
    }
    
    requirement def ProcessSafetyRequirement {
        doc /* Safety requirements for automated process control system */
        subject system : DistributedControlSystem;
    }
    
    requirement def ControlPerformanceRequirement {
        doc /* Performance requirements for control loop execution */
        subject system : DistributedControlSystem;
    }
    
    requirement <'REQ-AUTO-001'> temperatureSafetyLimit : ProcessSafetyRequirement {
        doc /* The reactor temperature shall not exceed the maximum rated temperature */
        require constraint {
            automationSystem.reactor.temperatureSensor.currentReading <= 
            automationSystem.reactor.maxTemperature
        }
    }
    
    requirement <'REQ-AUTO-002'> pressureSafetyLimit : ProcessSafetyRequirement {
        doc /* The reactor pressure shall not exceed the maximum rated pressure */
        require constraint {
            automationSystem.reactor.pressureSensor.currentReading <= 
            automationSystem.reactor.maxPressure
        }
    }
    
    requirement <'REQ-AUTO-003'> levelSafetyLimit : ProcessSafetyRequirement {
        doc /* The reactor level shall not exceed the maximum safe level */
        require constraint {
            automationSystem.reactor.levelSensor.currentReading <= 
            automationSystem.reactor.maxLevel
        }
    }
    
    requirement <'REQ-AUTO-004'> controlLoopCycleTime : ControlPerformanceRequirement {
        doc /* Each control loop shall execute with a cycle time of 1 second or less to ensure responsive control */
    }
    
    requirement <'REQ-AUTO-005'> sensorDataValidation : ControlPerformanceRequirement {
        doc /* All sensor readings shall be validated before use in control calculations to prevent erroneous actuator commands */
    }
    
    requirement <'REQ-AUTO-006'> alarmResponseTime : ProcessSafetyRequirement {
        doc /* The system shall detect and report alarm conditions within 2 seconds of occurrence */
    }
    
    requirement <'REQ-AUTO-007'> coordinatedControl : ControlPerformanceRequirement {
        doc /* The supervisory controller shall coordinate all regulatory control loops to optimize overall process performance */
    }
}
