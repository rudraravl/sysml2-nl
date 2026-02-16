package ElectricUnicycleSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import NumericalFunctions::*;
    
    attribute def VoltageValue :> Real;
    attribute def CurrentValue :> Real;
    attribute def BatteryCapacityValue :> Real;
    attribute def TorqueValue :> Real;
    attribute def AngleValue :> Real;
    attribute def AngularVelocityValue :> Real;
    attribute def TemperatureValue :> Real;
    
    enum def OperatingMode {
        eco;
        comfort;
        sport;
        custom;
    }
    
    enum def SystemStatus {
        off;
        initializing;
        ready;
        balancing;
        riding;
        charging;
        fault;
    }
    
    item def SensorData {
        attribute pitchAngle : AngleValue;
        attribute rollAngle : AngleValue;
        attribute yawRate : AngularVelocityValue;
        attribute accelerationX : Real;
        attribute accelerationY : Real;
        attribute accelerationZ : Real;
    }
    
    item def ControlCommand {
        attribute targetTorque : TorqueValue;
        attribute maxCurrent : CurrentValue;
        attribute brakeIntensity : Real;
    }
    
    item def RiderInput {
        attribute leanAngle : AngleValue;
        attribute pedalPressureLeft : Real;
        attribute pedalPressureRight : Real;
    }
    
    item def PowerButtonPressed;
    item def SystemCheckPassed;
    item def RiderMounted;
    item def ForwardLeanDetected;
    item def NeutralPositionDetected;
    item def RiderDismounted;
    item def ChargerConnected;
    item def BatteryFullyCharged;
    item def SystemFaultOccurred;
    item def FaultCleared;
    
    port def PowerPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    port def SensorPort {
        out data : SensorData;
    }
    
    port def ControlPort {
        in command : ControlCommand;
    }
    
    port def RiderInterfacePort {
        in input : RiderInput;
    }
    
    part def BatteryPack {
        attribute capacity : BatteryCapacityValue;
        attribute nominalVoltage : VoltageValue;
        attribute currentCharge : BatteryCapacityValue;
        attribute stateOfCharge : Real;
        attribute temperature : TemperatureValue;
        attribute maxDischargeCurrent : CurrentValue;
        
        port powerOutput : PowerPort;
        port chargingInput : PowerPort;
        
        assert constraint chargeLimit {
            currentCharge >= 0.0 and currentCharge <= capacity
        }
    }
    
    part def ElectricMotor {
        attribute ratedPower : PowerValue;
        attribute maxTorque : TorqueValue;
        attribute efficiency : Real;
        attribute currentRPM : Real;
        attribute temperature : TemperatureValue;
        
        port powerInput : PowerPort;
        port controlInput : ControlPort;
    }
    
    part def IMUSensor {
        attribute samplingRate : Real;
        attribute pitchAccuracy : AngleValue;
        attribute rollAccuracy : AngleValue;
        
        port dataOutput : SensorPort;
        port powerInput : PowerPort;
    }
    
    part def MotorController {
        attribute processingFrequency : Real;
        attribute maxOutputCurrent : CurrentValue;
        attribute pidGainP : Real;
        attribute pidGainI : Real;
        attribute pidGainD : Real;
        
        port sensorInput : SensorPort;
        port riderInput : RiderInterfacePort;
        port motorOutput : ControlPort;
        port batteryMonitor : PowerPort;
        port powerInput : PowerPort;
    }
    
    part def Wheel {
        attribute diameter : LengthValue;
        attribute width : LengthValue;
        attribute tirePressure : PressureValue;
        attribute mass : MassValue;
    }
    
    part def PedalAssembly {
        attribute leftPressure : Real;
        attribute rightPressure : Real;
        attribute maxLoad : MassValue;
        
        port sensorOutput : SensorPort;
    }
    
    part def ChassisFrame {
        attribute frameMass : MassValue;
        attribute material : String;
        attribute maxRiderWeight : MassValue;
    }
    
    part def LEDDisplayPanel {
        attribute brightness : Real;
        attribute displayMode : OperatingMode;
        
        port controlInput : ControlPort;
        port powerInput : PowerPort;
    }
    
    action def ReadSensorData {
        out sensorData : SensorData;
    }
    
    action def ProcessRiderInput {
        in riderInput : RiderInput;
        out desiredSpeed : Real;
        out desiredDirection : Real;
    }
    
    action def CalculateBalanceTorque {
        in sensorData : SensorData;
        in desiredSpeed : Real;
        in currentMode : OperatingMode;
        out balanceTorque : TorqueValue;
    }
    
    action def ApplyMotorControl {
        in balanceTorque : TorqueValue;
        in batteryLevel : Real;
        out motorCommand : ControlCommand;
    }
    
    action def UpdateUserInterface {
        in speed : Real;
        in batteryLevel : Real;
        in mode : OperatingMode;
        in status : SystemStatus;
    }
    
    action def SelfBalanceAndTransport {
        first start;
        then merge controlLoop;
        
        then action readSensors : ReadSensorData {
            out sensorData : SensorData;
        }
        
        then action processInput : ProcessRiderInput {
            in riderInput : RiderInput;
            out desiredSpeed : Real;
            out desiredDirection : Real;
        }
        
        then action calculateTorque : CalculateBalanceTorque {
            in sensorData = readSensors.sensorData;
            in desiredSpeed = processInput.desiredSpeed;
            in currentMode : OperatingMode;
            out balanceTorque : TorqueValue;
        }
        
        then action applyControl : ApplyMotorControl {
            in balanceTorque = calculateTorque.balanceTorque;
            in batteryLevel : Real;
            out motorCommand : ControlCommand;
        }
        
        then action updateDisplay : UpdateUserInterface {
            in speed : Real;
            in batteryLevel : Real;
            in mode : OperatingMode;
            in status : SystemStatus;
        }
        
        then decide;
            if applyControl.batteryLevel > 10.0 then controlLoop;
            if applyControl.batteryLevel <= 10.0 then emergencyShutdown;
        
        action emergencyShutdown;
        then done;
    }
    
    state def UnicycleOperationStateMachine {
        entry; then powerOff;
        
        state powerOff;
        transition powerOn
            first powerOff
            accept PowerButtonPressed
            then initializing;
        
        state initializing {
            entry; then systemCheck;
            state systemCheck;
        }
        transition initComplete
            first initializing
            accept SystemCheckPassed
            then ready;
        
        state ready;
        transition mountDetected
            first ready
            accept RiderMounted
            then balancing;
        
        state balancing {
            entry; then activeBalancing;
            state activeBalancing;
            do action maintainBalance : SelfBalanceAndTransport;
        }
        transition startRiding
            first balancing
            accept ForwardLeanDetected
            then riding;
        
        state riding {
            entry; then activeRiding;
            state activeRiding;
            do action transportRider : SelfBalanceAndTransport;
        }
        transition stopRiding
            first riding
            accept NeutralPositionDetected
            then balancing;
        
        transition dismount
            first balancing
            accept RiderDismounted
            then ready;
        
        transition startCharging
            first ready
            accept ChargerConnected
            then charging;
        
        state charging;
        transition chargeComplete
            first charging
            accept BatteryFullyCharged
            then ready;
        
        state fault;
        
        transition faultDetected1
            first initializing
            accept SystemFaultOccurred
            then fault;
        
        transition faultDetected2
            first ready
            accept SystemFaultOccurred
            then fault;
        
        transition faultDetected3
            first balancing
            accept SystemFaultOccurred
            then fault;
        
        transition faultDetected4
            first riding
            accept SystemFaultOccurred
            then fault;
        
        transition faultRecovered
            first fault
            accept FaultCleared
            then powerOff;
    }
    
    part def ElectricUnicycle {
        attribute totalMass : MassValue;
        attribute maxSpeed : Real;
        attribute maxRange : LengthValue;
        attribute currentOperatingMode : OperatingMode;
        attribute currentStatus : SystemStatus;
        
        part battery : BatteryPack {
            attribute :>> capacity = 1600.0;
            attribute :>> nominalVoltage = 84.0;
            attribute :>> currentCharge = 1600.0;
            attribute :>> stateOfCharge = 1.0;
            attribute :>> maxDischargeCurrent = 100.0;
        }
        
        part motor : ElectricMotor {
            attribute :>> ratedPower = 2500.0;
            attribute :>> maxTorque = 180.0;
            attribute :>> efficiency = 0.92;
        }
        
        part imu : IMUSensor {
            attribute :>> samplingRate = 1000.0;
            attribute :>> pitchAccuracy = 0.1;
            attribute :>> rollAccuracy = 0.1;
        }
        
        part controller : MotorController {
            attribute :>> processingFrequency = 2000.0;
            attribute :>> maxOutputCurrent = 100.0;
            attribute :>> pidGainP = 1.5;
            attribute :>> pidGainI = 0.05;
            attribute :>> pidGainD = 0.8;
        }
        
        part mainWheel : Wheel {
            attribute :>> diameter = 18.0;
            attribute :>> width = 3.5;
            attribute :>> tirePressure = 35.0;
            attribute :>> mass = 6.0;
        }
        
        part pedals : PedalAssembly {
            attribute :>> maxLoad = 120.0;
        }
        
        part chassis : ChassisFrame {
            attribute :>> frameMass = 12.0;
            attribute :>> material = "Aluminum Alloy 6061";
            attribute :>> maxRiderWeight = 120.0;
        }
        
        part display : LEDDisplayPanel {
            attribute :>> brightness = 0.8;
            attribute :>> displayMode = OperatingMode::comfort;
        }
        
        connection batteryToController connect battery.powerOutput to controller.powerInput;
        connection batteryToMotor connect battery.powerOutput to motor.powerInput;
        connection controllerToMotor connect controller.motorOutput to motor.controlInput;
        connection imuToController connect imu.dataOutput to controller.sensorInput;
        connection pedalsToController connect pedals.sensorOutput to controller.riderInput;
        connection controllerToDisplay connect controller.motorOutput to display.controlInput;
        connection batteryToDisplay connect battery.powerOutput to display.powerInput;
        connection batteryToIMU connect battery.powerOutput to imu.powerInput;
        
        perform action primaryFunction : SelfBalanceAndTransport;
        
        exhibit state operationControl : UnicycleOperationStateMachine;
        
        assert constraint massCalculation {
            totalMass == battery.currentCharge * 0.005 + motor.ratedPower * 0.003 + 
                         chassis.frameMass + mainWheel.mass + 3.5
        }
    }
    
    requirement <'EUC-REQ-001'> primaryTransportFunction {
        doc /* 
         * The Electric Unicycle shall provide personal transportation for a single rider
         * by maintaining dynamic self-balance through continuous gyroscopic sensing and
         * motor control, enabling hands-free operation controlled by rider body position.
         */
        subject unicycle : ElectricUnicycle;
    }
    
    requirement <'EUC-REQ-002'> balanceStability {
        doc /* 
         * The system shall maintain balance within safe operating angles to prevent falls.
         */
        subject unicycle : ElectricUnicycle;
        
        require constraint {
            unicycle.imu.pitchAccuracy <= 0.5 and
            unicycle.imu.rollAccuracy <= 0.5
        }
    }
    
    requirement <'EUC-REQ-003'> batteryCapacity {
        doc /* 
         * The battery shall provide sufficient capacity for extended range operation.
         */
        subject battery :>> ElectricUnicycle::battery;
        
        assert constraint {
            battery.capacity >= 1500.0 and
            battery.nominalVoltage >= 60.0
        }
    }
    
    requirement <'EUC-REQ-004'> motorPerformance {
        doc /* 
         * The motor shall deliver adequate power and torque for rider transport and hill climbing.
         */
        subject motor :>> ElectricUnicycle::motor;
        
        assert constraint {
            motor.ratedPower >= 2000.0 and
            motor.maxTorque >= 150.0
        }
    }
    
    requirement <'EUC-REQ-005'> systemMassLimit {
        doc /* 
         * The total system mass shall not exceed portability limits.
         */
        subject unicycle : ElectricUnicycle;
        
        assert constraint {
            unicycle.totalMass <= 25.0
        }
    }
    
    requirement <'EUC-REQ-006'> speedControl {
        doc /* 
         * The system shall limit maximum speed for safety across all operating modes.
         */
        subject unicycle : ElectricUnicycle;
        
        require constraint {
            unicycle.maxSpeed <= 50.0
        }
    }
    
    part unicycleInstance : ElectricUnicycle {
        attribute :>> totalMass = 22.5;
        attribute :>> maxSpeed = 45.0;
        attribute :>> maxRange = 100.0;
        attribute :>> currentOperatingMode = OperatingMode::comfort;
        attribute :>> currentStatus = SystemStatus::ready;
    }
    
    satisfy primaryTransportFunction by unicycleInstance;
    satisfy balanceStability by unicycleInstance;
    satisfy batteryCapacity by unicycleInstance.battery;
    satisfy motorPerformance by unicycleInstance.motor;
    satisfy systemMassLimit by unicycleInstance;
    satisfy speedControl by unicycleInstance;
}
