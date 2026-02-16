package PatientLiftSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    
    attribute def LiftCapacity :> MassValue;
    attribute def LiftHeight :> LengthValue;
    attribute def BatteryCharge :> Real;
    attribute def OperatingVoltage :> ElectricPotentialValue;
    attribute def LiftSpeed :> Real;
    
    enum def LiftOperationMode {
        standby;
        manual;
        powered;
        emergency;
    }
    
    enum def LiftState {
        lowered;
        raising;
        elevated;
        lowering;
        locked;
    }
    
    enum def SafetyLevel {
        normal;
        warning;
        critical;
        fault;
    }
    
    item def Patient {
        attribute bodyMass : MassValue;
        attribute isSecured : Boolean;
        attribute comfortLevel : Real;
    }
    
    item def Caregiver {
        attribute operatorId : String;
        attribute certificationLevel : String;
    }
    
    port def PowerPort {
        attribute voltage : OperatingVoltage;
        attribute current : ElectricCurrentValue;
    }
    
    port def ControlSignalPort {
        attribute commandType : String;
        attribute commandValue : Real;
    }
    
    port def SensorDataPort {
        attribute sensorReading : Real;
        attribute timestamp : Real;
    }
    
    port def MechanicalLoadPort {
        attribute appliedForce : ForceValue;
        attribute displacement : LengthValue;
    }
    
    part def Battery {
        attribute capacity : Real;
        attribute chargeLevel : BatteryCharge;
        attribute voltage : OperatingVoltage;
        attribute remainingRuntime : Real;
        
        port powerOutput : PowerPort;
        
        assert constraint batteryConstraint {
            chargeLevel >= 0.0 and chargeLevel <= 100.0
        }
    }
    
    part def ElectricActuator {
        attribute maxForce : ForceValue;
        attribute maxStroke : LiftHeight;
        attribute currentPosition : LiftHeight;
        attribute operatingSpeed : LiftSpeed;
        
        port powerInput : PowerPort;
        port controlInput : ControlSignalPort;
        port mechanicalOutput : MechanicalLoadPort;
    }
    
    part def HydraulicPump {
        attribute maxPressure : Real;
        attribute flowRate : Real;
        attribute efficiency : Real;
        
        port powerInput : PowerPort;
        port hydraulicOutput;
    }
    
    part def LiftingArm {
        attribute armLength : LengthValue;
        attribute currentAngle : Real;
        attribute maxAngle : Real;
        attribute minAngle : Real;
        
        port mechanicalInput : MechanicalLoadPort;
        port slingAttachment;
    }
    
    part def Sling {
        attribute ratedCapacity : LiftCapacity;
        attribute material : String;
        attribute slingType : String;
        attribute isAttached : Boolean;
        
        port patientInterface;
        port liftAttachment;
    }
    
    part def LoadCell {
        attribute maxCapacity : LiftCapacity;
        attribute measuredLoad : MassValue;
        attribute accuracy : Real;
        
        port sensorOutput : SensorDataPort;
        port mechanicalInput : MechanicalLoadPort;
    }
    
    part def HeightSensor {
        attribute maxRange : LiftHeight;
        attribute measuredHeight : LiftHeight;
        attribute resolution : LengthValue;
        
        port sensorOutput : SensorDataPort;
    }
    
    part def ControlModule {
        attribute operatingMode : LiftOperationMode;
        attribute safetyStatus : SafetyLevel;
        attribute currentState : LiftState;
        
        port sensorInputs : SensorDataPort[*];
        port actuatorControl : ControlSignalPort;
        port userInterface : ControlSignalPort;
        port emergencyInput : ControlSignalPort;
    }
    
    part def EmergencyStopButton {
        attribute isPressed : Boolean;
        attribute resetRequired : Boolean;
        
        port emergencySignal : ControlSignalPort;
    }
    
    part def HandControl {
        attribute controlType : String;
        attribute raiseButton : Boolean;
        attribute lowerButton : Boolean;
        attribute stopButton : Boolean;
        
        port commandOutput : ControlSignalPort;
    }
    
    part def BaseFrame {
        attribute wheelbase : LengthValue;
        attribute trackWidth : LengthValue;
        attribute totalMass : MassValue;
        attribute stabilityFactor : Real;
        
        port structuralMount[*];
    }
    
    part def CasterWheel {
        attribute diameter : LengthValue;
        attribute hasBrake : Boolean;
        attribute brakeEngaged : Boolean;
        
        port mounting;
    }
    
    part def MastAssembly {
        attribute height : LiftHeight;
        attribute crossSection : Real;
        attribute material : String;
        
        port baseMount;
        port armMount;
    }
    
    part def PatientLift {
        attribute maxPatientCapacity : LiftCapacity;
        attribute minLiftHeight : LiftHeight;
        attribute maxLiftHeight : LiftHeight;
        attribute systemMass : MassValue;
        attribute operationalMode : LiftOperationMode;
        
        part baseFrame : BaseFrame {
            attribute :>> wheelbase = 900.0 [mm];
            attribute :>> trackWidth = 700.0 [mm];
            attribute :>> totalMass = 65.0 [kg];
        }
        
        part frontCasters : CasterWheel[2] {
            attribute :>> diameter = 100.0 [mm];
            attribute :>> hasBrake = true;
        }
        
        part rearCasters : CasterWheel[2] {
            attribute :>> diameter = 100.0 [mm];
            attribute :>> hasBrake = false;
        }
        
        part mast : MastAssembly {
            attribute :>> height = 1800.0 [mm];
            attribute :>> material = "steel";
        }
        
        part battery : Battery {
            attribute :>> capacity = 15000.0;
            attribute :>> voltage = 24.0 [V];
            attribute :>> chargeLevel : BatteryCharge;
        }
        
        part hydraulicPump : HydraulicPump {
            attribute :>> maxPressure = 180.0;
            attribute :>> flowRate = 2.5;
            attribute :>> efficiency = 0.85;
        }
        
        part actuator : ElectricActuator {
            attribute :>> maxForce = 2500.0 [N];
            attribute :>> maxStroke = 1500.0 [mm];
            attribute :>> operatingSpeed = 0.04;
        }
        
        part liftArm : LiftingArm {
            attribute :>> armLength = 1200.0 [mm];
            attribute :>> maxAngle = 75.0;
            attribute :>> minAngle = 15.0;
        }
        
        part sling : Sling {
            attribute :>> ratedCapacity = 220.0 [kg];
            attribute :>> material = "polyester mesh";
            attribute :>> slingType = "full body";
        }
        
        part loadSensor : LoadCell {
            attribute :>> maxCapacity = 250.0 [kg];
            attribute :>> accuracy = 0.5;
        }
        
        part heightSensor : HeightSensor {
            attribute :>> maxRange = 2000.0 [mm];
            attribute :>> resolution = 1.0 [mm];
        }
        
        part controller : ControlModule {
            attribute :>> operatingMode = LiftOperationMode::standby;
            attribute :>> safetyStatus : SafetyLevel;
        }
        
        part handControl : HandControl {
            attribute :>> controlType = "pendant";
        }
        
        part emergencyStop : EmergencyStopButton {
            attribute :>> isPressed = false;
            attribute :>> resetRequired = false;
        }
        
        connection powerToPump connect battery.powerOutput to hydraulicPump.powerInput;
        connection powerToActuator connect battery.powerOutput to actuator.powerInput;
        connection actuatorToArm connect actuator.mechanicalOutput to liftArm.mechanicalInput;
        connection armToSling connect liftArm.slingAttachment to sling.liftAttachment;
        connection loadToSensor connect loadSensor.mechanicalInput to liftArm.mechanicalInput;
        connection loadDataToController connect loadSensor.sensorOutput to controller.sensorInputs;
        connection heightDataToController connect heightSensor.sensorOutput to controller.sensorInputs;
        connection controllerToActuator connect controller.actuatorControl to actuator.controlInput;
        connection handToController connect handControl.commandOutput to controller.userInterface;
        connection emergencyToController connect emergencyStop.emergencySignal to controller.emergencyInput;
        
        assert constraint capacityConstraint {
            maxPatientCapacity <= sling.ratedCapacity and
            maxPatientCapacity <= loadSensor.maxCapacity
        }
        
        assert constraint heightConstraint {
            maxLiftHeight <= actuator.maxStroke and
            minLiftHeight >= 0.0 [mm]
        }
        
        assert constraint stabilityConstraint {
            baseFrame.stabilityFactor >= 1.5
        }
    }
    
    action def CheckBatteryLevel {
        in chargeLevel : BatteryCharge;
        out batteryOk : Boolean;
    }
    
    action def VerifyPatientSecured {
        in patient : Patient;
        in sling : Sling;
        out secured : Boolean;
    }
    
    action def MeasurePatientWeight {
        in loadSensor : LoadCell;
        out patientMass : MassValue;
    }
    
    action def ValidateLoadCapacity {
        in measuredLoad : MassValue;
        in maxCapacity : LiftCapacity;
        out loadSafe : Boolean;
    }
    
    action def RaisePatient {
        in targetHeight : LiftHeight;
        in currentHeight : LiftHeight;
        in liftSpeed : LiftSpeed;
        out finalHeight : LiftHeight;
    }
    
    action def LowerPatient {
        in targetHeight : LiftHeight;
        in currentHeight : LiftHeight;
        in liftSpeed : LiftSpeed;
        out finalHeight : LiftHeight;
    }
    
    action def HoldPosition {
        in currentHeight : LiftHeight;
        out positionLocked : Boolean;
    }
    
    action def EmergencyStop {
        out systemHalted : Boolean;
    }
    
    action def PerformPatientTransfer {
        first start;
        
        then action checkBattery : CheckBatteryLevel;
        
        then decide;
            if checkBattery.batteryOk then verifySecured;
            if !checkBattery.batteryOk then emergencyShutdown;
        
        action verifySecured : VerifyPatientSecured;
        
        then action measureWeight : MeasurePatientWeight;
        
        then action validateLoad : ValidateLoadCapacity;
        
        then decide;
            if validateLoad.loadSafe then raisePatient;
            if !validateLoad.loadSafe then emergencyShutdown;
        
        action raisePatient : RaisePatient;
        
        then action holdPosition : HoldPosition;
        
        then action repositionLift;
        
        then action lowerPatient : LowerPatient;
        
        then action releasePatient;
        
        then done;
        
        action emergencyShutdown : EmergencyStop;
        then done;
    }
    
    state def LiftControlStateMachine {
        entry; then idle;
        
        state idle;
        accept at systemCheck;
        
        state systemCheck;
        accept at ready;
        accept at fault;
        
        state ready;
        accept at lifting;
        accept at lowering;
        
        state lifting;
        accept at elevated;
        accept at emergencyHalt;
        
        state elevated;
        accept at lowering;
        accept at emergencyHalt;
        
        state lowering;
        accept at lowered;
        accept at emergencyHalt;
        
        state lowered;
        accept at ready;
        
        state emergencyHalt;
        accept at fault;
        
        state fault;
        accept at idle;
    }
    
    requirement <'REQ-PL-001'> primaryFunction {
        doc /* The patient lift system shall safely transfer patients with limited 
             * mobility from one location to another by lifting, repositioning, and 
             * lowering them while minimizing physical strain on caregivers and 
             * ensuring patient safety, comfort, and dignity throughout the transfer process.
            */
        subject lift : PatientLift;
    }
    
    requirement <'REQ-PL-002'> liftCapacityRequirement {
        doc /* The patient lift shall support a maximum patient weight of 200 kg 
             * to accommodate the majority of patient populations.
            */
        subject lift : PatientLift;
        assert constraint {
            lift.maxPatientCapacity >= 200.0 [kg]
        }
    }
    
    requirement <'REQ-PL-003'> heightRangeRequirement {
        doc /* The lifting mechanism shall provide a minimum lift height of 400 mm 
             * and a maximum lift height of 1800 mm to enable transfers between 
             * various surfaces including beds, chairs, and wheelchairs.
            */
        subject lift : PatientLift;
        assert constraint {
            lift.minLiftHeight <= 400.0 [mm] and
            lift.maxLiftHeight >= 1800.0 [mm]
        }
    }
    
    requirement <'REQ-PL-004'> batteryOperationRequirement {
        doc /* The patient lift shall operate on rechargeable battery power for 
             * a minimum of 30 lift cycles on a single charge to ensure mobility 
             * and independence from fixed power sources.
            */
        subject battery : PatientLift::battery;
        assert constraint {
            battery.capacity >= 15000.0
        }
    }
    
    requirement <'REQ-PL-005'> emergencyStopRequirement {
        doc /* The patient lift shall include an accessible emergency stop mechanism 
             * that immediately halts all motion when activated and requires manual 
             * reset before resuming operation.
            */
        subject emergencyStop : PatientLift::emergencyStop;
    }
    
    requirement <'REQ-PL-006'> loadMonitoringRequirement {
        doc /* The patient lift shall continuously monitor the applied load and 
             * prevent lifting operation if the measured load exceeds the maximum 
             * rated capacity.
            */
        subject loadSensor : PatientLift::loadSensor;
        assert constraint {
            loadSensor.measuredLoad <= loadSensor.maxCapacity
        }
    }
    
    requirement <'REQ-PL-007'> stabilityRequirement {
        doc /* The base frame shall provide a stability factor of at least 1.5 
             * to prevent tipping during normal operation with maximum rated load 
             * at maximum lift height.
            */
        subject baseFrame : PatientLift::baseFrame;
        assert constraint {
            baseFrame.stabilityFactor >= 1.5
        }
    }
    
    requirement <'REQ-PL-008'> liftSpeedRequirement {
        doc /* The lifting and lowering speed shall not exceed 50 mm/s to ensure 
             * smooth and controlled patient movement.
            */
        subject actuator : PatientLift::actuator;
        assert constraint {
            actuator.operatingSpeed <= 0.05
        }
    }
    
    part patientLiftSystem : PatientLift {
        attribute :>> maxPatientCapacity = 200.0 [kg];
        attribute :>> minLiftHeight = 350.0 [mm];
        attribute :>> maxLiftHeight = 1850.0 [mm];
        attribute :>> systemMass = 95.0 [kg];
        
        perform action transferOperation : PerformPatientTransfer;
    }
    
    satisfy primaryFunction by patientLiftSystem;
    satisfy liftCapacityRequirement by patientLiftSystem;
    satisfy heightRangeRequirement by patientLiftSystem;
    satisfy batteryOperationRequirement by patientLiftSystem.battery;
    satisfy emergencyStopRequirement by patientLiftSystem.emergencyStop;
    satisfy loadMonitoringRequirement by patientLiftSystem.loadSensor;
    satisfy stabilityRequirement by patientLiftSystem.baseFrame;
    satisfy liftSpeedRequirement by patientLiftSystem.actuator;
}
