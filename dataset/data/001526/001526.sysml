package 'PMC System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CommandSignal;
    attribute def StatusCode;
    attribute def ErrorCode;
    
    attribute def MotorSpeed :> ISQ::AngularVelocityValue {
        attribute :>> num : Real;
        attribute :>> mRef : AngularVelocityUnit;
    }
    
    attribute def MotorTorque :> ISQ::TorqueValue {
        attribute :>> num : Real;
        attribute :>> mRef : TorqueUnit;
    }
    
    attribute def MotorPosition :> Real;
    
    attribute def MotorVoltage :> ISQ::ElectricPotentialValue {
        attribute :>> num : Real;
        attribute :>> mRef : ElectricPotentialUnit;
    }
    
    attribute def MotorCurrent :> ISQ::ElectricCurrentValue {
        attribute :>> num : Real;
        attribute :>> mRef : ElectricCurrentUnit;
    }
    
    attribute def PWMDutyCycle :> Real;
    
    port def PowerInputPort {
        in attribute voltage : MotorVoltage;
        in attribute current : MotorCurrent;
    }
    
    port def MotorDrivePort {
        out attribute driveVoltage : MotorVoltage;
        out attribute driveCurrent : MotorCurrent;
    }
    
    port def SensorPort {
        out attribute position : MotorPosition;
        out attribute speed : MotorSpeed;
        out attribute current : MotorCurrent;
    }
    
    port def CommandPort {
        in attribute targetPosition : MotorPosition;
        in attribute targetSpeed : MotorSpeed;
        out attribute status : StatusCode;
    }
    
    part def PowerSupply {
        port powerOut : PowerInputPort;
        attribute nominalVoltage : MotorVoltage;
        attribute maxCurrent : MotorCurrent;
    }
    
    part def MotorController {
        port sensorIn : ~SensorPort;
        port commandIn : CommandPort;
        port driveOut : ~MotorDrivePort;
        
        attribute controlFrequency : ISQ::FrequencyValue;
        attribute pidGainP : Real;
        attribute pidGainI : Real;
        attribute pidGainD : Real;
    }
    
    part def PowerStage {
        port powerIn : ~PowerInputPort;
        port controlIn : ~MotorDrivePort;
        port motorOut : MotorDrivePort;
        
        attribute switchingFrequency : ISQ::FrequencyValue;
        attribute efficiency : Real;
    }
    
    part def PermanentMagnetMotor {
        port driveIn : ~MotorDrivePort;
        port sensorOut : SensorPort;
        port mechanicalOut : MechanicalOutputPort;
        
        attribute ratedPower : ISQ::PowerValue;
        attribute ratedSpeed : MotorSpeed;
        attribute ratedTorque : MotorTorque;
        attribute polePairs : Integer;
    }
    
    port def MechanicalOutputPort {
        out attribute torque : MotorTorque;
        out attribute speed : MotorSpeed;
    }
    
    part def EncoderSensor {
        port sensorOut : SensorPort;
        attribute resolution : Integer;
        attribute accuracy : Real;
    }
    
    part def CurrentSensor {
        port sensorOut : SensorPort;
        attribute range : MotorCurrent;
        attribute bandwidth : ISQ::FrequencyValue;
    }
    
    action def ReadSensorData {
        in attribute rawSensorData : SensorPort;
        out attribute position : MotorPosition;
        out attribute speed : MotorSpeed;
        out attribute current : MotorCurrent;
    }
    
    action def ComputeControlSignal {
        in attribute targetPosition : MotorPosition;
        in attribute currentPosition : MotorPosition;
        in attribute currentSpeed : MotorSpeed;
        in attribute currentCurrent : MotorCurrent;
        out attribute pwmDutyCycle : PWMDutyCycle;
        out attribute driveVoltage : MotorVoltage;
    }
    
    action def GeneratePWM {
        in attribute dutyCycle : PWMDutyCycle;
        in attribute supplyVoltage : MotorVoltage;
        out attribute outputVoltage : MotorVoltage;
        out attribute outputCurrent : MotorCurrent;
    }
    
    action def ProduceMechanicalOutput {
        in attribute appliedVoltage : MotorVoltage;
        in attribute appliedCurrent : MotorCurrent;
        out attribute torque : MotorTorque;
        out attribute speed : MotorSpeed;
    }
    
    state def PMCOperationalState {
        entry; then initialization;
        
        state initialization {
            entry assign systemReady := false;
            do action calibrateSensors;
        }
        
        transition init_to_idle
            first initialization
            if sensorsCalibrated
            then idle;
        
        state idle {
            entry assign systemReady := true;
        }
        
        transition idle_to_active
            first idle
            accept commandReceived : CommandSignal
            then active;
        
        state active {
            do action executeControl;
            
            state normalOperation {
                do action maintainPosition;
            }
            
            state faultCondition {
                entry assign faultActive := true;
                do action handleFault;
            }
            
            transition normal_to_fault
                first normalOperation
                if overCurrentDetected or overTemperatureDetected
                then faultCondition;
            
            transition fault_to_normal
                first faultCondition
                if faultCleared
                then normalOperation;
        }
        
        transition active_to_stopping
            first active
            accept stopCommand : CommandSignal
            then stopping;
        
        state stopping {
            do action decelerateMotor;
        }
        
        transition stopping_to_idle
            first stopping
            if motorStopped
            then idle;
        
        attribute systemReady : Boolean;
        attribute sensorsCalibrated : Boolean;
        attribute faultActive : Boolean;
        attribute overCurrentDetected : Boolean;
        attribute overTemperatureDetected : Boolean;
        attribute faultCleared : Boolean;
        attribute motorStopped : Boolean;
    }
    
    action def ControlMotorOperation {
        in attribute targetPosition : MotorPosition;
        in attribute targetSpeed : MotorSpeed;
        out attribute finalPosition : MotorPosition;
        out attribute finalSpeed : MotorSpeed;
        
        first start;
        then merge controlLoop;
        
        then action readSensors : ReadSensorData {
            in rawSensorData;
            out position;
            out speed;
            out current;
        }
        
        then action computeControl : ComputeControlSignal {
            in targetPosition = ControlMotorOperation::targetPosition;
            in currentPosition = readSensors.position;
            in currentSpeed = readSensors.speed;
            in currentCurrent = readSensors.current;
            out pwmDutyCycle;
            out driveVoltage;
        }
        
        then action generatePWM : GeneratePWM {
            in dutyCycle = computeControl.pwmDutyCycle;
            in supplyVoltage;
            out outputVoltage;
            out outputCurrent;
        }
        
        then action produceMechanical : ProduceMechanicalOutput {
            in appliedVoltage = generatePWM.outputVoltage;
            in appliedCurrent = generatePWM.outputCurrent;
            out torque;
            out speed;
        }
        
        then decide;
            if positionError > tolerance then controlLoop;
            if positionError <= tolerance then complete;
        
        action complete {
            assign finalPosition := readSensors.position;
            assign finalSpeed := readSensors.speed;
        }
        then done;
        
        private attribute positionError : Real;
        private attribute tolerance : Real;
    }
    
    requirement def PositionControlRequirement {
        doc /* The PMC system shall accurately control motor position to commanded setpoints. */
        
        subject pmcSystem : PMCSystem;
        
        require constraint positionAccuracy {
            doc /* Position accuracy shall be within +/- 0.1 degrees of commanded position. */
        }
        
        require constraint settlingTime {
            doc /* System shall reach commanded position within 50 milliseconds. */
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* The PMC system shall meet specified performance criteria. */
        
        require constraint responseTime {
            doc /* Control loop response time shall be less than 1 millisecond. */
        }
        
        require constraint efficiency {
            doc /* Overall system efficiency shall exceed 92 percent at rated load. */
        }
        
        require constraint speedRange {
            doc /* System shall operate across speed range from 0 to 6000 RPM. */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The PMC system shall operate safely under all conditions. */
        
        require constraint currentProtection {
            doc /* System shall limit motor current to 110 percent of rated maximum. */
        }
        
        require constraint faultResponse {
            doc /* System shall detect and respond to fault conditions within 2 milliseconds. */
        }
        
        require constraint emergencyStop {
            doc /* System shall support emergency stop with motor halt within 50 milliseconds. */
        }
    }
    
    part def PMCSystem {
        doc /* 
        Permanent Magnet Motor Control (PMC) System.
        
        This system provides precise closed-loop control of a permanent magnet motor for 
        applications requiring accurate position and speed regulation. The primary function 
        is to convert electrical power into controlled mechanical motion by continuously 
        monitoring motor position, speed, and current, then adjusting drive signals to 
        achieve commanded setpoints while maintaining stable operation and protecting 
        against fault conditions.
        
        The system operates through a high-frequency control loop where sensor feedback 
        is processed by control algorithms to generate pulse-width modulated drive signals. 
        These signals are amplified by a power stage to energize the motor windings, 
        producing the desired mechanical output. The architecture ensures responsive 
        performance, high efficiency, and robust fault protection.
        */
        
        port externalCommand : CommandPort;
        port powerInput : ~PowerInputPort;
        port mechanicalOutput : ~MechanicalOutputPort;
        
        part powerSupply : PowerSupply {
            port :>> powerOut;
            attribute :>> nominalVoltage = 48.0 [V];
            attribute :>> maxCurrent = 20.0 [A];
        }
        
        part controller : MotorController {
            port :>> sensorIn;
            port :>> commandIn;
            port :>> driveOut;
            attribute :>> controlFrequency = 10000.0 [Hz];
            attribute :>> pidGainP = 1.5;
            attribute :>> pidGainI = 0.8;
            attribute :>> pidGainD = 0.2;
        }
        
        part powerStage : PowerStage {
            port :>> powerIn;
            port :>> controlIn;
            port :>> motorOut;
            attribute :>> switchingFrequency = 20000.0 [Hz];
            attribute :>> efficiency = 0.95;
        }
        
        part motor : PermanentMagnetMotor {
            port :>> driveIn;
            port :>> sensorOut;
            port :>> mechanicalOut;
            attribute :>> ratedPower = 750.0 [W];
            attribute ratedSpeedValue : Real = 3000.0;
            attribute :>> ratedTorque = 2.4 [SI::N*SI::m];
            attribute :>> polePairs = 4;
        }
        
        part encoder : EncoderSensor {
            port :>> sensorOut;
            attribute :>> resolution = 8192;
            attribute :>> accuracy = 0.02;
        }
        
        part currentSensor : CurrentSensor {
            port :>> sensorOut;
            attribute :>> range = 25.0 [A];
            attribute :>> bandwidth = 100000.0 [Hz];
        }
        
        connect powerSupply.powerOut to powerStage.powerIn;
        connect controller.driveOut to powerStage.controlIn;
        connect powerStage.motorOut to motor.driveIn;
        connect motor.sensorOut to controller.sensorIn;
        connect encoder.sensorOut to controller.sensorIn;
        connect currentSensor.sensorOut to controller.sensorIn;
        connect externalCommand to controller.commandIn;
        connect motor.mechanicalOut to mechanicalOutput;
        
        perform action controlOperation : ControlMotorOperation;
        
        exhibit state operationalState : PMCOperationalState;
    }
    
    part pmcSystemInstance : PMCSystem;
    
    requirement positionControlReq : PositionControlRequirement {
        subject pmcSystem = pmcSystemInstance;
    }
    
    requirement performanceReq : PerformanceRequirement;
    
    requirement safetyReq : SafetyRequirement;
}
