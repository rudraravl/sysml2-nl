package BirthingChairSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value def Angle :> Real { unit = "deg"; }
    value def Distance :> Real { unit = "m"; }
    value def Force :> Real { unit = "N"; }
    value def Pressure :> Real { unit = "Pa"; }
    value def Mass :> Real { unit = "kg"; }
    value def Voltage :> Real { unit = "V"; }
    value def Current :> Real { unit = "A"; }
    value def Power :> Real { unit = "W"; }
    value def TimeValue :> Real { unit = "s"; }
    value def Speed :> Real { unit = "m/s"; }
    value def AngularSpeed :> Real { unit = "deg/s"; }

    // ===== Enumerations =====
    enum def OperationalMode {
        standby = 0,
        positioning = 1,
        activeSupport = 2,
        emergency = 3
    }

    enum def PositionProfile {
        custom = 0,
        upright = 1,
        semiUpright = 2,
        reclined = 3,
        squatting = 4,
        handsAndKnees = 5
    }

    enum def CommandKind {
        setProfile,
        setBackrestAngle,
        setSeatTilt,
        setLegAngle,
        setLegWidth,
        setArmrestHeight,
        emergencyStop,
        resetEmergency
    }

    enum def LockState {
        locked,
        unlocked
    }

    enum def MotorState {
        idle,
        extending,
        retracting,
        faulted
    }

    // ===== Item Types =====
    item def AdjustmentCommand {
        attribute kind : CommandKind;
        attribute profile : PositionProfile default PositionProfile::custom;
        attribute backrestAngle : Angle[0..1];
        attribute seatTilt : Angle[0..1];
        attribute leftLegAngle : Angle[0..1];
        attribute rightLegAngle : Angle[0..1];
        attribute legWidth : Distance[0..1];
        attribute armrestHeight : Distance[0..1];
    }

    item def SensorReading {
        attribute backrestAngle : Angle;
        attribute seatTilt : Angle;
        attribute leftLegAngle : Angle;
        attribute rightLegAngle : Angle;
        attribute legWidth : Distance;
        attribute leftArmrestHeight : Distance;
        attribute rightArmrestHeight : Distance;
        attribute totalLoad : Force;
        attribute pressureDistribution : Pressure[0..*];
    }

    item def StatusReport {
        attribute mode : OperationalMode;
        attribute reading : SensorReading;
        attribute faults : String[0..*];
    }

    item def PowerSupply {
        attribute voltage : Voltage;
        attribute maxCurrent : Current;
    }

    // ===== Interfaces =====
    port def CommandPort {
        out cmd : AdjustmentCommand;
    }

    port def StatusPort {
        out status : StatusReport;
    }

    port def MotorControlPort {
        out targetAngle : Angle;
        out enable : Boolean;
        in actualAngle : Angle;
        in motorCurrent : Current;
    }

    port def SensorPort {
        out reading : SensorReading;
    }

    port def PowerPort {
        out supply : PowerSupply;
    }

    // ===== Requirements =====
    requirement def StructuralStabilityRequirement {
        doc { The structural frame shall support a maximum load of at least 200 kg without deformation. }
        attribute maxLoad : Mass = 200 [kg];
        subject frame : StructuralFrame;
        require frame.maxLoadCapacity >= maxLoad;
    }

    requirement def BackrestAdjustmentRequirement {
        doc { The backrest shall recline and raise between 0 and 75 degrees. }
        attribute minAngle : Angle = 0 [deg];
        attribute maxAngle : Angle = 75 [deg];
        subject backrest : BackrestModule;
        require backrest.minAngle >= minAngle and backrest.maxAngle <= maxAngle;
    }

    requirement def SeatTiltRequirement {
        doc { The seat shall tilt forward and backward between -15 and +20 degrees. }
        attribute minTilt : Angle = -15 [deg];
        attribute maxTilt : Angle = 20 [deg];
        subject seat : SeatModule;
        require seat.minTilt >= minTilt and seat.maxTilt <= maxTilt;
    }

    requirement def LegSupportRequirement {
        doc { Each leg support shall adjust angle between 0 and 90 degrees and width between 0.3 m and 0.8 m. }
        attribute minAngle : Angle = 0 [deg];
        attribute maxAngle : Angle = 90 [deg];
        attribute minWidth : Distance = 0.3 [m];
        attribute maxWidth : Distance = 0.8 [m];
        subject legSupport : LegSupportModule;
        require legSupport.minAngle >= minAngle and legSupport.maxAngle <= maxAngle;
        require legSupport.minWidth >= minWidth and legSupport.maxWidth <= maxWidth;
    }

    requirement def ArmrestAdjustmentRequirement {
        doc { Armrests shall be height-adjustable between 0.1 m and 0.4 m above the seat. }
        attribute minHeight : Distance = 0.1 [m];
        attribute maxHeight : Distance = 0.4 [m];
        subject armrest : ArmrestModule;
        require armrest.minHeight >= minHeight and armrest.maxHeight <= maxHeight;
    }

    requirement def EmergencyResponseRequirement {
        doc { Upon emergency stop command or unsafe load detection, all motors shall halt within 0.2 s and all locking mechanisms shall engage. }
        attribute maxResponseTime : TimeValue = 0.2 [s];
        subject system : BirthingChair;
        require system.emergencyResponseTime <= maxResponseTime;
    }

    requirement def LoadMonitoringRequirement {
        doc { The system shall continuously monitor weight and pressure distribution across all support surfaces. }
        attribute samplingRate : Real = 10.0;
        subject controlUnit : ControlUnit;
        require controlUnit.monitoringEnabled == true;
    }

    // ===== Parts =====

    part def StructuralFrame {
        attribute material : String = "reinforced steel";
        attribute maxLoadCapacity : Mass = 250 [kg];
        port powerOut : PowerSupply;
        port stabilizerControl : Boolean;
        attribute stabilizersDeployed : Boolean = false;
    }

    part def LockingMechanism {
        attribute state : LockState = LockState::locked;
        action def engage { in angle : Angle; }
        action def release { }
    }

    part def ElectricMotor {
        attribute ratedPower : Power = 150 [W];
        attribute maxTorque : Force = 500 [N];
        attribute state : MotorState = MotorState::idle;
        port control : MotorControlPort;
        action def drive {
            in target : Angle;
            in current : Angle;
            out newAngle : Angle;
        }
    }

    part def PositionSensor {
        attribute accuracy : Angle = 0.5 [deg];
        out angle : Angle;
        action def readAngle { out value : Angle; }
    }

    part def LoadSensor {
        attribute maxCapacity : Force = 2500 [N];
        attribute overloadThreshold : Force = 2200 [N];
        out load : Force;
        action def readLoad { out value : Force; }
    }

    part def PressureSensor {
        attribute range : Pressure = 100000 [Pa];
        out pressure : Pressure;
        action def readPressure { out value : Pressure; }
    }

    part def BackrestModule {
        attribute minAngle : Angle = 0 [deg];
        attribute maxAngle : Angle = 75 [deg];
        attribute currentAngle : Angle = 30 [deg];
        attribute paddingType : String = "medical-grade foam";
        part motor : ElectricMotor {
            redefines ratedPower = 200 [W];
        }
        part lock : LockingMechanism;
        part positionSensor : PositionSensor;
        port motorControl : MotorControlPort;
        action def recline {
            in targetAngle : Angle;
            if targetAngle > currentAngle then {
                motor.state = MotorState::extending;
            } else {
                motor.state = MotorState::retracting;
            }
            currentAngle = targetAngle;
            motor.state = MotorState::idle;
            lock.state = LockState::locked;
        }
        action def raise {
            in targetAngle : Angle;
            recline(targetAngle);
        }
    }

    part def SeatModule {
        attribute minTilt : Angle = -15 [deg];
        attribute maxTilt : Angle = 20 [deg];
        attribute currentTilt : Angle = 0 [deg];
        attribute cushionType : String = "medical-grade foam";
        attribute hasDeliveryOpening : Boolean = true;
        part actuator : ElectricMotor {
            redefines ratedPower = 250 [W];
        }
        part lock : LockingMechanism;
        part tiltSensor : PositionSensor;
        part loadSensor : LoadSensor;
        port motorControl : MotorControlPort;
        action def tilt {
            in targetTilt : Angle;
            if targetTilt > currentTilt then {
                actuator.state = MotorState::extending;
            } else {
                actuator.state = MotorState::retracting;
            }
            currentTilt = targetTilt;
            actuator.state = MotorState::idle;
            lock.state = LockState::locked;
        }
    }

    part def LegSupportModule {
        attribute side : String;
        attribute minAngle : Angle = 0 [deg];
        attribute maxAngle : Angle = 90 [deg];
        attribute currentAngle : Angle = 45 [deg];
        attribute minWidth : Distance = 0.3 [m];
        attribute maxWidth : Distance = 0.8 [m];
        attribute currentWidth : Distance = 0.5 [m];
        attribute hasStirrup : Boolean = true;
        part angleMotor : ElectricMotor {
            redefines ratedPower = 120 [W];
        }
        part widthMotor : ElectricMotor {
            redefines ratedPower = 120 [W];
        }
        part lock : LockingMechanism;
        part angleSensor : PositionSensor;
        part widthSensor : PositionSensor;
        action def adjustAngle {
            in targetAngle : Angle;
            if targetAngle > currentAngle then {
                angleMotor.state = MotorState::extending;
            } else {
                angleMotor.state = MotorState::retracting;
            }
            currentAngle = targetAngle;
            angleMotor.state = MotorState::idle;
            lock.state = LockState::locked;
        }
        action def adjustWidth {
            in targetWidth : Distance;
            if targetWidth > currentWidth then {
                widthMotor.state = MotorState::extending;
            } else {
                widthMotor.state = MotorState::retracting;
            }
            currentWidth = targetWidth;
            widthMotor.state = MotorState::idle;
        }
    }

    part def ArmrestModule {
        attribute side : String;
        attribute minHeight : Distance = 0.1 [m];
        attribute maxHeight : Distance = 0.4 [m];
        attribute currentHeight : Distance = 0.2 [m];
        attribute hasGrip : Boolean = true;
        part heightMotor : ElectricMotor {
            redefines ratedPower = 80 [W];
        }
        part lock : LockingMechanism;
        part heightSensor : PositionSensor;
        action def adjustHeight {
            in targetHeight : Distance;
            if targetHeight > currentHeight then {
                heightMotor.state = MotorState::extending;
            } else {
                heightMotor.state = MotorState::retracting;
            }
            currentHeight = targetHeight;
            heightMotor.state = MotorState::idle;
            lock.state = LockState::locked;
        }
    }

    part def Microcontroller {
        attribute clockSpeed : Real = 1.6e9;
        attribute firmwareVersion : String = "BC-2.1";
        port cmdInput : CommandPort;
        port statusOutput : StatusPort;
        attribute monitoringEnabled : Boolean = true;
        action def processCommand {
            in cmd : AdjustmentCommand;
            out backrestTarget : Angle;
            out seatTarget : Angle;
            out leftLegTarget : Angle;
            out rightLegTarget : Angle;
            out legWidthTarget : Distance;
            out armrestHeightTarget : Distance;
        }
    }

    part def ControlUnit {
        part microcontroller : Microcontroller;
        part backrestSensor : PositionSensor;
        part seatSensor : PositionSensor;
        part seatLoadSensor : LoadSensor;
        part leftLegSensor : PositionSensor;
        part rightLegSensor : PositionSensor;
        part legWidthSensor : PositionSensor;
        part leftArmrestSensor : PositionSensor;
        part rightArmrestSensor : PositionSensor;
        part frameLoadSensor : LoadSensor;
        part pressureSensors : PressureSensor[4];
        attribute monitoringEnabled : Boolean = true;
        attribute emergencyResponseTime : TimeValue = 0.15 [s];
        attribute unsafeLoadThreshold : Force = 2200 [N];
        port commandInput : CommandPort;
        port statusOutput : StatusPort;
        port backrestMotor : MotorControlPort;
        port seatMotor : MotorControlPort;
        port leftLegMotor : MotorControlPort;
        port rightLegMotor : MotorControlPort;
        port leftLegWidthMotor : MotorControlPort;
        port rightLegWidthMotor : MotorControlPort;
        port leftArmrestMotor : MotorControlPort;
        port rightArmrestMotor : MotorControlPort;
        action def monitorSensors {
            out reading : SensorReading;
        }
        action def detectUnsafeLoad {
            in load : Force;
            out unsafe : Boolean;
            unsafe = load > unsafeLoadThreshold;
        }
    }

    // ===== State Machine =====
    state def BirthingChairStates {
        entry action { }
        state standby {
            entry action { /* power on, motors idle, locks engaged */ }
            transition to positioning
                when commandInput.cmd.kind == CommandKind::setProfile
                or commandInput.cmd.kind == CommandKind::setBackrestAngle
                or commandInput.cmd.kind == CommandKind::setSeatTilt
                or commandInput.cmd.kind == CommandKind::setLegAngle
                or commandInput.cmd.kind == CommandKind::setLegWidth
                or commandInput.cmd.kind == CommandKind::setArmrestHeight;
        }
        state positioning {
            entry action { /* unlock relevant modules, drive motors to target */ }
            do action { /* continuously monitor sensors and adjust motor outputs */ }
            transition to activeSupport
                when allTargetsReached == true;
            transition to emergency
                when commandInput.cmd.kind == CommandKind::emergencyStop
                or unsafeLoadDetected == true;
        }
        state activeSupport {
            entry action { /* engage all locks, motors idle */ }
            do action { /* continuously monitor load and pressure distribution */ }
            transition to positioning
                when commandInput.cmd.kind == CommandKind::setProfile
                or commandInput.cmd.kind == CommandKind::setBackrestAngle;
            transition to standby
                when commandInput.cmd.kind == CommandKind::resetEmergency;
            transition to emergency
                when commandInput.cmd.kind == CommandKind::emergencyStop
                or unsafeLoadDetected == true;
        }
        state emergency {
            entry action { /* halt all motors immediately, engage all locks */ }
            do action { /* maintain locked state, alert clinical staff */ }
            transition to standby
                when commandInput.cmd.kind == CommandKind::resetEmergency
                and unsafeLoadDetected == false;
        }
        attribute allTargetsReached : Boolean;
        attribute unsafeLoadDetected : Boolean;
    }

    // ===== Top-level System =====
    part def BirthingChair {
        attribute systemId : String = "BC-2024-001";
        attribute emergencyResponseTime : TimeValue = 0.15 [s];
        part frame : StructuralFrame;
        part backrest : BackrestModule;
        part seat : SeatModule;
        part leftLegSupport : LegSupportModule {
            redefines side = "left";
        }
        part rightLegSupport : LegSupportModule {
            redefines side = "right";
        }
        part leftArmrest : ArmrestModule {
            redefines side = "left";
        }
        part rightArmrest : ArmrestModule {
            redefines side = "right";
        }
        part controlUnit : ControlUnit;
        port externalCommand : CommandPort;
        port externalStatus : StatusPort;
        port mainPower : PowerPort;
        exhibit state : BirthingChairStates;

        connection powerFromFrame : PowerPort connect frame.powerOut to controlUnit;
        connection powerToBackrest : PowerPort connect frame.powerOut to backrest.motor.control;
        connection powerToSeat : PowerPort connect frame.powerOut to seat.actuator.control;
        connection powerToLeftLeg : PowerPort connect frame.powerOut to leftLegSupport.angleMotor.control;
        connection powerToRightLeg : PowerPort connect frame.powerOut to rightLegSupport.angleMotor.control;
        connection powerToLeftArmrest : PowerPort connect frame.powerOut to leftArmrest.heightMotor.control;
        connection powerToRightArmrest : PowerPort connect frame.powerOut to rightArmrest.heightMotor.control;

        connection cmdToControl : CommandPort connect externalCommand to controlUnit.commandInput;
        connection statusFromControl : StatusPort connect controlUnit.statusOutput to externalStatus;

        connection backrestMotorControl : MotorControlPort connect controlUnit.backrestMotor to backrest.motorControl;
        connection seatMotorControl : MotorControlPort connect controlUnit.seatMotor to seat.motorControl;
        connection leftLegMotorControl : MotorControlPort connect controlUnit.leftLegMotor to leftLegSupport.angleMotor.control;
        connection rightLegMotorControl : MotorControlPort connect controlUnit.rightLegMotor to rightLegSupport.angleMotor.control;
        connection leftLegWidthMotorControl : MotorControlPort connect controlUnit.leftLegWidthMotor to leftLegSupport.widthMotor.control;
        connection rightLegWidthMotorControl : MotorControlPort connect controlUnit.rightLegWidthMotor to rightLegSupport.widthMotor.control;
        connection leftArmrestMotorControl : MotorControlPort connect controlUnit.leftArmrestMotor to leftArmrest.heightMotor.control;
        connection rightArmrestMotorControl : MotorControlPort connect controlUnit.rightArmrestMotor to rightArmrest.heightMotor.control;

        connection backrestSensorFeedback : MotorControlPort connect backrest.motorControl to controlUnit.backrestMotor;
        connection seatSensorFeedback : MotorControlPort connect seat.motorControl to controlUnit.seatMotor;

        satisfy StructuralStabilityRequirement {
            subject frame = frame;
        }
        satisfy BackrestAdjustmentRequirement {
            subject backrest = backrest;
        }
        satisfy SeatTiltRequirement {
            subject seat = seat;
        }
        satisfy LegSupportRequirement {
            subject legSupport = leftLegSupport;
        }
        satisfy ArmrestAdjustmentRequirement {
            subject armrest = leftArmrest;
        }
        satisfy EmergencyResponseRequirement {
            subject system = BirthingChair::this;
        }
        satisfy LoadMonitoringRequirement {
            subject controlUnit = controlUnit;
        }
    }

    // ===== Action for Profile Application =====
    action def ApplyPositionProfile {
        in chair : BirthingChair;
        in profile : PositionProfile;
        in backrestAngle : Angle;
        in seatTilt : Angle;
        in leftLegAngle : Angle;
        in rightLegAngle : Angle;
        in legWidth : Distance;
        in armrestHeight : Distance;
        // Generate command
        attribute cmd : AdjustmentCommand {
            redefines kind = CommandKind::setProfile;
            redefines profile = profile;
            redefines backrestAngle = backrestAngle;
            redefines seatTilt = seatTilt;
            redefines leftLegAngle = leftLegAngle;
            redefines rightLegAngle = rightLegAngle;
            redefines legWidth = legWidth;
            redefines armrestHeight = armrestHeight;
        }
        // Send to chair
        action sendCommand { in command : AdjustmentCommand; }
        // Wait for positioning to complete
        action waitForCompletion { }
        // Confirm active support
        action confirmActiveSupport { }
    }

    action def EmergencyHalt {
        in chair : BirthingChair;
        attribute cmd : AdjustmentCommand {
            redefines kind = CommandKind::emergencyStop;
        }
        action haltAllMotors { }
        action engageAllLocks { }
        action alertStaff { }
    }
}
}
