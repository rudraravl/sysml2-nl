package StandingWheelchairSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    enum def PostureMode {
        seated;
        transitioning;
        standing;
    }
    
    enum def SafetyState {
        safe;
        warning;
        unsafe;
    }
    
    enum def LockState {
        locked;
        unlocked;
    }
    
    attribute def AngleValue :> Real;
    attribute def TorqueValue :> Real;
    attribute def PressureValue :> Real;
    
    item def User {
        attribute bodyMass : MassValue;
        attribute height : LengthValue;
    }
    
    part def Battery {
        attribute capacity : Real;
        attribute voltage : Real;
        attribute currentCharge : Real;
        port powerOut;
    }
    
    part def DriveMotor {
        attribute maxTorque : TorqueValue;
        attribute maxSpeed : Real;
        port powerIn;
        port controlIn;
    }
    
    part def LiftActuator {
        attribute maxForce : Real;
        attribute maxStroke : LengthValue;
        attribute currentPosition : LengthValue;
        port powerIn;
        port controlIn;
    }
    
    part def SeatFrame {
        attribute seatAngle : AngleValue;
        attribute maxAngle : AngleValue;
        attribute minAngle : AngleValue;
    }
    
    part def StabilizerLeg {
        attribute extended : Boolean;
        attribute lockState : LockState;
        port controlIn;
    }
    
    part def PressureSensor {
        attribute pressure : PressureValue;
        port dataOut;
    }
    
    part def TiltSensor {
        attribute pitchAngle : AngleValue;
        attribute rollAngle : AngleValue;
        port dataOut;
    }
    
    part def ControlUnit {
        attribute currentMode : PostureMode;
        attribute safetyState : SafetyState;
        port powerIn;
        port userCommandIn;
        port sensorDataIn;
        port actuatorControlOut;
        port driveControlOut;
    }
    
    part def UserInterface {
        attribute standButtonPressed : Boolean;
        attribute sitButtonPressed : Boolean;
        attribute emergencyStopPressed : Boolean;
        port commandOut;
    }
    
    part def WheelAssembly {
        attribute diameter : LengthValue;
        part leftWheel;
        part rightWheel;
    }
    
    action def MonitorUserInput {
        out standCommand : Boolean;
        out sitCommand : Boolean;
        out emergencyStop : Boolean;
    }
    
    action def CheckSafetyConditions {
        in seatPressure : PressureValue;
        in pitchAngle : AngleValue;
        in rollAngle : AngleValue;
        in currentSpeed : Real;
        out isSafe : Boolean;
    }
    
    action def DeployStabilizers {
        out stabilizersDeployed : Boolean;
    }
    
    action def RetractStabilizers {
        out stabilizersRetracted : Boolean;
    }
    
    action def DisableDriveMotors;
    
    action def EnableDriveMotors;
    
    action def ExtendLiftMechanism {
        in targetHeight : LengthValue;
        in currentHeight : LengthValue;
        out newHeight : LengthValue;
    }
    
    action def RetractLiftMechanism {
        in currentHeight : LengthValue;
        out newHeight : LengthValue;
    }
    
    action def TiltSeatBack {
        in targetAngle : AngleValue;
        in currentAngle : AngleValue;
        out newAngle : AngleValue;
    }
    
    action def LevelSeat {
        in currentAngle : AngleValue;
        out newAngle : AngleValue;
    }
    
    action def UpdatePostureMode {
        in angle : AngleValue;
        in height : LengthValue;
        out mode : PostureMode;
    }
    
    action def EmergencyShutdown;
    
    action def OperateStandingWheelchair {
        first start;
        then merge monitoringLoop;
        
        then action monitorInput : MonitorUserInput {
            out standCmd : Boolean;
            out sitCmd : Boolean;
            out eStop : Boolean;
        }
        
        then decide;
            if monitorInput.eStop then emergencyShutdown;
            if monitorInput.standCmd then initiateStandingSequence;
            if monitorInput.sitCmd then initiateSeatingSequence;
        
        action initiateStandingSequence;
        then action checkSafetyForStanding : CheckSafetyConditions {
            in seatPressure : PressureValue;
            in pitchAngle : AngleValue;
            in rollAngle : AngleValue;
            in currentSpeed : Real;
            out isSafe : Boolean;
        }
        
        then decide;
            if checkSafetyForStanding.isSafe then disableDrive;
        
        action disableDrive : DisableDriveMotors;
        then action deployStabilizers : DeployStabilizers {
            out stabilizersDeployed : Boolean;
        }
        
        then action extendLift : ExtendLiftMechanism {
            in targetHeight : LengthValue = 0.45 [m];
            in currentHeight : LengthValue;
            out newHeight : LengthValue;
        }
        
        then action tiltSeat : TiltSeatBack {
            in targetAngle : AngleValue = 80.0;
            in currentAngle : AngleValue;
            out newAngle : AngleValue;
        }
        
        then action updateToStanding : UpdatePostureMode {
            in angle : AngleValue;
            in height : LengthValue;
            out mode : PostureMode;
        }
        
        then monitoringLoop;
        
        action initiateSeatingSequence;
        then action checkSafetyForSeating : CheckSafetyConditions {
            in seatPressure : PressureValue;
            in pitchAngle : AngleValue;
            in rollAngle : AngleValue;
            in currentSpeed : Real;
            out isSafe : Boolean;
        }
        
        then decide;
            if checkSafetyForSeating.isSafe then levelSeat;
        
        action levelSeat : LevelSeat {
            in currentAngle : AngleValue;
            out newAngle : AngleValue;
        }
        
        then action retractLift : RetractLiftMechanism {
            in currentHeight : LengthValue;
            out newHeight : LengthValue;
        }
        
        then action retractStabilizers : RetractStabilizers {
            out stabilizersRetracted : Boolean;
        }
        
        then action updateToSeated : UpdatePostureMode {
            in angle : AngleValue;
            in height : LengthValue;
            out mode : PostureMode;
        }
        
        then action enableDrive : EnableDriveMotors;
        then monitoringLoop;
        
        action emergencyShutdown : EmergencyShutdown;
        then done;
    }
    
    part def StandingWheelchair {
        attribute totalMass : MassValue;
        attribute maxUserMass : MassValue;
        attribute currentPosture : PostureMode;
        
        part battery : Battery {
            attribute :>> capacity = 10000;
            attribute :>> voltage = 24.0;
            attribute :>> currentCharge = 10000;
        }
        
        part leftDriveMotor : DriveMotor {
            attribute :>> maxTorque = 60.0;
            attribute :>> maxSpeed = 8.0;
        }
        
        part rightDriveMotor : DriveMotor {
            attribute :>> maxTorque = 60.0;
            attribute :>> maxSpeed = 8.0;
        }
        
        part liftActuator : LiftActuator {
            attribute :>> maxForce = 2500.0;
            attribute :>> maxStroke = 0.5 [m];
            attribute :>> currentPosition = 0.0 [m];
        }
        
        part seatFrame : SeatFrame {
            attribute :>> seatAngle = 0.0;
            attribute :>> maxAngle = 85.0;
            attribute :>> minAngle = 0.0;
        }
        
        part frontStabilizer : StabilizerLeg {
            attribute :>> extended = false;
            attribute :>> lockState = LockState::unlocked;
        }
        
        part rearStabilizer : StabilizerLeg {
            attribute :>> extended = false;
            attribute :>> lockState = LockState::unlocked;
        }
        
        part seatPressureSensor : PressureSensor {
            attribute :>> pressure = 0.0;
        }
        
        part tiltSensor : TiltSensor {
            attribute :>> pitchAngle = 0.0;
            attribute :>> rollAngle = 0.0;
        }
        
        part controlUnit : ControlUnit {
            attribute :>> currentMode = PostureMode::seated;
            attribute :>> safetyState = SafetyState::safe;
        }
        
        part userInterface : UserInterface {
            attribute :>> standButtonPressed = false;
            attribute :>> sitButtonPressed = false;
            attribute :>> emergencyStopPressed = false;
        }
        
        part wheelAssembly : WheelAssembly {
            attribute :>> diameter = 0.6 [m];
        }
        
        connect battery.powerOut to controlUnit.powerIn;
        connect battery.powerOut to leftDriveMotor.powerIn;
        connect battery.powerOut to rightDriveMotor.powerIn;
        connect battery.powerOut to liftActuator.powerIn;
        connect userInterface.commandOut to controlUnit.userCommandIn;
        connect seatPressureSensor.dataOut to controlUnit.sensorDataIn;
        connect tiltSensor.dataOut to controlUnit.sensorDataIn;
        connect controlUnit.actuatorControlOut to liftActuator.controlIn;
        connect controlUnit.actuatorControlOut to frontStabilizer.controlIn;
        connect controlUnit.actuatorControlOut to rearStabilizer.controlIn;
        connect controlUnit.driveControlOut to leftDriveMotor.controlIn;
        connect controlUnit.driveControlOut to rightDriveMotor.controlIn;
        
        perform action operateWheelchair[*] ordered references OperateStandingWheelchair;
    }
    
    requirement def MobilityRequirement;
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    requirement def CapacityRequirement;
    
    requirement <'REQ-001'> primaryFunction : MobilityRequirement {
        doc /* The standing wheelchair shall enable users to transition 
             * between seated and standing postures to improve mobility, 
             * accessibility, and social interaction while providing 
             * powered mobility in both configurations.
            */
        subject wheelchair : StandingWheelchair;
    }
    
    requirement <'REQ-002'> safeTransition : SafetyRequirement {
        doc /* The wheelchair shall ensure safe posture transitions 
             * through stabilization, drive disablement, and continuous 
             * safety monitoring.
            */
        subject wheelchair : StandingWheelchair;
    }
    
    requirement <'REQ-003'> maxUserCapacity : CapacityRequirement {
        subject wheelchair : StandingWheelchair;
        assert constraint {
            wheelchair.maxUserMass <= 150 [kg]
        }
    }
    
    requirement <'REQ-004'> seatAngleRange : PerformanceRequirement {
        subject seatFrame : SeatFrame;
        assert constraint {
            seatFrame.minAngle == 0.0 && seatFrame.maxAngle >= 80.0
        }
    }
    
    requirement <'REQ-005'> liftCapability : PerformanceRequirement {
        subject liftActuator : LiftActuator;
        assert constraint {
            liftActuator.maxStroke >= 0.4 [m]
        }
    }
    
    requirement <'REQ-006'> batteryCapacity : PerformanceRequirement {
        subject battery : Battery;
        assert constraint {
            battery.capacity >= 8000
        }
    }
    
    requirement <'REQ-007'> systemMass : PerformanceRequirement {
        subject wheelchair : StandingWheelchair;
        assert constraint {
            wheelchair.totalMass <= 90 [kg]
        }
    }
    
    requirement <'REQ-008'> stabilityControl : SafetyRequirement {
        doc /* The wheelchair shall deploy stabilizers and disable drive 
             * motors before initiating any posture transition.
            */
        subject wheelchair : StandingWheelchair;
    }
    
    part standingWheelchair : StandingWheelchair {
        attribute :>> totalMass = 82 [kg];
        attribute :>> maxUserMass = 150 [kg];
        attribute :>> currentPosture = PostureMode::seated;
    }
    
    satisfy primaryFunction by standingWheelchair;
    satisfy safeTransition by standingWheelchair;
    satisfy maxUserCapacity by standingWheelchair;
    satisfy seatAngleRange by standingWheelchair.seatFrame;
    satisfy liftCapability by standingWheelchair.liftActuator;
    satisfy batteryCapacity by standingWheelchair.battery;
    satisfy systemMass by standingWheelchair;
    satisfy stabilityControl by standingWheelchair;
}
