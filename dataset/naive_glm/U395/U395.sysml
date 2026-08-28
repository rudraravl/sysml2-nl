package StadiometerSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value type LengthValue :> Real { unit mm; }
    value type VelocityValue :> Real { unit 'mm/s'; }
    value type ForceValue :> Real { unit N; }
    value type AngleValue :> Real { unit deg; }
    value type DurationValue :> Real { unit s; }
    value type MassValue :> Real { unit kg; }

    // ===== Enumerations =====
    enumeration def DirectionEnum { up; down; stop; }

    // ===== Item Definitions =====
    item def Person {
        attribute standingHeight : LengthValue;
        attribute weight : MassValue;
    }

    item def HeightMeasurement {
        attribute rawValue : LengthValue;
        attribute calibratedValue : LengthValue;
        attribute timestamp : String;
        attribute valid : Boolean;
    }

    item def CalibrationData {
        attribute offset : LengthValue = 0 [mm];
        attribute scale : Real = 1.0;
        attribute lastCalibrationDate : String;
        attribute valid : Boolean = true;
    }

    item def DiagnosticStatus {
        attribute baseLevelOk : Boolean = true;
        attribute calibrationValid : Boolean = true;
        attribute motorFunctional : Boolean = true;
        attribute sensorFunctional : Boolean = true;
        attribute overallOk : Boolean = true;
    }

    // ===== Port Definitions =====
    port def PresencePort {
        out attribute personPresent : Boolean;
    }

    port def ContactPort {
        out attribute contactDetected : Boolean;
        out attribute contactForce : ForceValue;
    }

    port def PositionPort {
        out attribute position : LengthValue;
        out attribute valid : Boolean;
    }

    port def LevelPort {
        out attribute tiltAngle : AngleValue;
        out attribute levelOk : Boolean;
    }

    port def MotorCmdPort {
        in attribute direction : DirectionEnum;
        in attribute speed : VelocityValue;
        in attribute enable : Boolean;
    }

    port def DisplayCmdPort {
        in attribute height : LengthValue;
        in attribute message : String;
        in attribute clear : Boolean;
    }

    port def LockCmdPort {
        in attribute lock : Boolean;
    }

    // ===== Component Part Definitions =====
    abstract part def StadiometerComponent {
        attribute componentId : String;
        attribute operational : Boolean = true;
    }

    part def BasePlatform :> StadiometerComponent {
        attribute massCapacity : MassValue = 200 [kg];
        attribute width : LengthValue = 450 [mm];
        attribute depth : LengthValue = 350 [mm];
        attribute thickness : LengthValue = 50 [mm];
        attribute surfaceMaterial : String = "Non-slip rubber";
    }

    part def VerticalRail :> StadiometerComponent {
        attribute height : LengthValue = 2500 [mm];
        attribute calibrationMarks : Integer = 2500;
        attribute calibrated : Boolean = true;
        attribute material : String = "Anodized Aluminum";
        attribute crossSection : String = "T-slot extrusion";
    }

    part def SlidingHeadpiece :> StadiometerComponent {
        attribute restPosition : LengthValue = 2400 [mm];
        attribute currentPosition : LengthValue = 2400 [mm];
        attribute locked : Boolean = false;
        attribute minContactForce : ForceValue = 0.5 [N];
        attribute maxContactForce : ForceValue = 5.0 [N];
        attribute padMaterial : String = "Soft foam";

        port contactPort : ContactPort;
        port lockCmdPort : LockCmdPort;
    }

    part def PresenceSensor :> StadiometerComponent {
        attribute detectionRange : LengthValue = 500 [mm];
        attribute responseTime : DurationValue = 0.1 [s];
        attribute sensorType : String = "Infrared reflective";
        port presencePort : PresencePort;
    }

    part def PositionSensor :> StadiometerComponent {
        attribute resolution : LengthValue = 0.1 [mm];
        attribute accuracy : LengthValue = 0.5 [mm];
        attribute maxRange : LengthValue = 2500 [mm];
        attribute sensorType : String = "Optical encoder";
        port positionPort : PositionPort;
    }

    part def LevelSensor :> StadiometerComponent {
        attribute maxTilt : AngleValue = 1.0 [deg];
        attribute resolution : AngleValue = 0.1 [deg];
        attribute sensorType : String = "MEMS accelerometer";
        port levelPort : LevelPort;
    }

    part def DriveMotor :> StadiometerComponent {
        attribute maxSpeed : VelocityValue = 50 ['mm/s'];
        attribute currentSpeed : VelocityValue = 0 ['mm/s'];
        attribute ratedTorque : Real = 0.5;
        attribute motorType : String = "Stepper";
        port cmdPort : MotorCmdPort;
    }

    part def DigitalDisplay :> StadiometerComponent {
        attribute displayType : String = "LCD";
        attribute resolution : LengthValue = 0.1 [mm];
        attribute backlight : Boolean = true;
        attribute digits : Integer = 5;
        port cmdPort : DisplayCmdPort;
    }

    // ===== Action Definitions =====
    action def ProcessMeasurement {
        in rawHeight : LengthValue;
        in calibration : CalibrationData;
        out calibratedHeight : LengthValue;
        out valid : Boolean;

        action {
            calibratedHeight = rawHeight * calibration.scale + calibration.offset;
            valid = calibration.valid;
        }
    }

    action def ValidateSystemStatus {
        in levelOk : Boolean;
        in calibrationValid : Boolean;
        in motorOk : Boolean;
        in sensorOk : Boolean;
        out status : DiagnosticStatus;
        out overallOk : Boolean;

        action {
            status.baseLevelOk = levelOk;
            status.calibrationValid = calibrationValid;
            status.motorFunctional = motorOk;
            status.sensorFunctional = sensorOk;
            overallOk = levelOk and calibrationValid and motorOk and sensorOk;
            status.overallOk = overallOk;
        }
    }

    action def PerformMeasurement {
        in positionReading : LengthValue;
        in calibration : CalibrationData;
        out measurement : HeightMeasurement;

        action {
            measurement.rawValue = positionReading;
            measurement.calibratedValue = positionReading * calibration.scale + calibration.offset;
            measurement.valid = calibration.valid;
            measurement.timestamp = "now";
        }
    }

    // ===== Electronic Control Unit =====
    part def ElectronicControlUnit :> StadiometerComponent {
        attribute sampleRate : Integer = 100;
        attribute displayDuration : DurationValue = 5.0 [s];
        attribute loweringTimeout : DurationValue = 30.0 [s];
        attribute loweringSpeed : VelocityValue = 30 ['mm/s'];
        attribute retractingSpeed : VelocityValue = 40 ['mm/s'];
        attribute calibration : CalibrationData;
        attribute currentMeasurement : HeightMeasurement;
        attribute status : DiagnosticStatus;

        port presenceIn : PresencePort;
        port contactIn : ContactPort;
        port positionIn : PositionPort;
        port levelIn : LevelPort;
        port motorOut : MotorCmdPort;
        port displayOut : DisplayCmdPort;
        port lockOut : LockCmdPort;

        state machine ControlStateMachine {
            entry; then ready;

            state ready {
                entry action {
                    motorOut.direction = DirectionEnum::stop;
                    motorOut.speed = 0 ['mm/s'];
                    motorOut.enable = false;
                    displayOut.clear = true;
                    displayOut.message = "Ready";
                }
            }

            transition from ready to detecting
                when presenceIn.personPresent == true;

            transition from ready to error
                when levelIn.levelOk == false;

            state detecting {
                entry action {
                    displayOut.clear = true;
                    displayOut.message = "Measuring...";
                }
            }

            transition from detecting to lowering
                when levelIn.levelOk == true;

            transition from detecting to error
                when levelIn.levelOk == false;

            state lowering {
                entry action {
                    motorOut.direction = DirectionEnum::down;
                    motorOut.speed = 30 ['mm/s'];
                    motorOut.enable = true;
                }
            }

            transition from lowering to contact
                when contactIn.contactDetected == true;

            transition from lowering to error
                when contactIn.contactForce > 5.0 [N];

            transition from lowering to error
                when levelIn.levelOk == false;

            state contact {
                entry action {
                    motorOut.direction = DirectionEnum::stop;
                    motorOut.speed = 0 ['mm/s'];
                    motorOut.enable = false;
                    lockOut.lock = true;
                }
            }

            transition from contact to measuring
                when positionIn.valid == true;

            state measuring {
                entry action {
                    currentMeasurement.rawValue = positionIn.position;
                    currentMeasurement.calibratedValue =
                        positionIn.position * calibration.scale + calibration.offset;
                    currentMeasurement.valid = calibration.valid;
                }
            }

            transition from measuring to displaying
                when currentMeasurement.valid == true;

            transition from measuring to error
                when currentMeasurement.valid == false;

            state displaying {
                entry action {
                    displayOut.height = currentMeasurement.calibratedValue;
                    displayOut.message = "Height:";
                    displayOut.clear = false;
                }
            }

            transition from displaying to retracting
                after 5.0 [s];

            state retracting {
                entry action {
                    lockOut.lock = false;
                    motorOut.direction = DirectionEnum::up;
                    motorOut.speed = 40 ['mm/s'];
                    motorOut.enable = true;
                }
            }

            transition from retracting to ready
                when positionIn.position >= 2400 [mm];

            transition from retracting to error
                when levelIn.levelOk == false;

            state error {
                entry action {
                    motorOut.direction = DirectionEnum::stop;
                    motorOut.speed = 0 ['mm/s'];
                    motorOut.enable = false;
                    lockOut.lock = false;
                    displayOut.clear = true;
                    displayOut.message = "Error: Check system";
                }
            }

            transition from error to ready
                when levelIn.levelOk == true and calibration.valid == true;
        }
    }

    // ===== Requirements =====
    requirement def HeightAccuracyRequirement {
        doc /* The stadiometer shall measure standing height with an accuracy of plus or minus 0.5 mm. */;
        subject stadiometer : Stadiometer;
        require constraint {
            stadiometer.positionSensor.accuracy <= 0.5 [mm]
        }
    }

    requirement def MeasurementRangeRequirement {
        doc /* The stadiometer shall measure heights from 400 mm to 2400 mm. */;
        subject stadiometer : Stadiometer;
        require constraint {
            stadiometer.positionSensor.maxRange >= 2500 [mm]
        }
    }

    requirement def ContactForceRequirement {
        doc /* The headpiece contact force shall not exceed 5.0 N to ensure user comfort. */;
        subject stadiometer : Stadiometer;
        require constraint {
            stadiometer.headpiece.maxContactForce <= 5.0 [N]
        }
    }

    requirement def LevelStabilityRequirement {
        doc /* The base platform shall remain level within 1.0 degree tilt for valid measurements. */;
        subject stadiometer : Stadiometer;
        require constraint {
            stadiometer.levelSensor.maxTilt <= 1.0 [deg]
        }
    }

    requirement def AutoRetractRequirement {
        doc /* The headpiece shall automatically retract to rest position within 10 seconds after measurement. */;
        subject stadiometer : Stadiometer;
        require constraint {
            stadiometer.ecu.displayDuration <= 10.0 [s]
        }
    }

    requirement def ResolutionRequirement {
        doc /* The display shall show height with 0.1 mm resolution. */;
        subject stadiometer : Stadiometer;
        require constraint {
            stadiometer.display.resolution <= 0.1 [mm]
        }
    }

    requirement def ContinuousMonitoringRequirement {
        doc /* The system shall continuously monitor base level and calibration validity, entering error state if conditions are not met. */;
        subject stadiometer : Stadiometer;
        require constraint {
            stadiometer.ecu.status.baseLevelOk == true and
            stadiometer.ecu.status.calibrationValid == true
        }
    }

    requirement def PresenceDetectionRequirement {
        doc /* The system shall detect a person standing on the base platform within 0.5 seconds. */;
        subject stadiometer : Stadiometer;
        require constraint {
            stadiometer.presenceSensor.responseTime <= 0.5 [s]
        }
    }

    requirement def BaseCapacityRequirement {
        doc /* The base platform shall support persons up to 200 kg. */;
        subject stadiometer : Stadiometer;
        require constraint {
            stadiometer.base.massCapacity >= 200 [kg]
        }
    }

    // ===== Top-level Stadiometer System =====
    part def Stadiometer {
        attribute systemId : String;
        attribute manufacturer : String = "Precision Instruments";
        attribute model : String = "StadioMax-2000";
        attribute firmwareVersion : String = "2.1.0";

        part base : BasePlatform {
            attribute componentId = "BASE-001";
        }
        part rail : VerticalRail {
            attribute componentId = "RAIL-001";
        }
        part headpiece : SlidingHeadpiece {
            attribute componentId = "HEAD-001";
        }
        part presenceSensor : PresenceSensor {
            attribute componentId = "PRES-001";
        }
        part positionSensor : PositionSensor {
            attribute componentId = "POS-001";
        }
        part levelSensor : LevelSensor {
            attribute componentId = "LVL-001";
        }
        part motor : DriveMotor {
            attribute componentId = "MOT-001";
        }
        part display : DigitalDisplay {
            attribute componentId = "DISP-001";
        }
        part ecu : ElectronicControlUnit {
            attribute componentId = "ECU-001";
        }

        connection presenceConn connect presenceSensor.presencePort to ecu.presenceIn;
        connection contactConn connect headpiece.contactPort to ecu.contactIn;
        connection positionConn connect positionSensor.positionPort to ecu.positionIn;
        connection levelConn connect levelSensor.levelPort to ecu.levelIn;
        connection motorCmdConn connect ecu.motorOut to motor.cmdPort;
        connection displayConn connect ecu.displayOut to display.cmdPort;
        connection lockConn connect ecu.lockOut to headpiece.lockCmdPort;

        satisfy HeightAccuracyRequirement;
        satisfy MeasurementRangeRequirement;
        satisfy ContactForceRequirement;
        satisfy LevelStabilityRequirement;
        satisfy AutoRetractRequirement;
        satisfy ResolutionRequirement;
        satisfy ContinuousMonitoringRequirement;
        satisfy PresenceDetectionRequirement;
        satisfy BaseCapacityRequirement;
    }
}
