package BeamSolarPhotovoreRobot {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Voltage :> Real {
        unit = "V";
    }

    attribute def Current :> Real {
        unit = "A";
    }

    attribute def Power :> Real {
        unit = "W";
    }

    attribute def Energy :> Real {
        unit = "J";
    }

    attribute def Illuminance :> Real {
        unit = "lx";
    }

    attribute def Speed :> Real {
        unit = "m/s";
    }

    attribute def Distance :> Real {
        unit = "m";
    }

    attribute def Angle :> Real {
        unit = "deg";
    }

    attribute def TimeDuration :> Real {
        unit = "s";
    }

    enum def LightSide {
        enum left;
        enum right;
        enum balanced;
        enum dark;
    }

    enum def MotionMode {
        enum sleeping;
        enum charging;
        enum seekingLight;
        enum approachingLight;
        enum avoidingObstacle;
        enum stalled;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    item def SolarEnergy {
        attribute incidentIlluminance : Illuminance;
        attribute harvestedPower : Power;
    }

    item def MotorDriveSignal {
        attribute dutyCycle : Real;
        attribute polarity : Integer;
        attribute driveVoltage : Voltage;
    }

    item def LightGradientSignal {
        attribute leftIlluminance : Illuminance;
        attribute rightIlluminance : Illuminance;
        attribute dominantSide : LightSide;
        attribute gradientMagnitude : Illuminance;
    }

    item def ContactSignal {
        attribute obstacleDetected : Boolean;
        attribute leftWhiskerPressed : Boolean;
        attribute rightWhiskerPressed : Boolean;
    }

    item def KinematicMotion {
        attribute forwardSpeed : Speed;
        attribute turnRate : Angle;
        attribute travelDistance : Distance;
    }

    port def ElectricalPort {
        inout power : ElectricalPower;
    }

    port def SolarInputPort {
        out energy : SolarEnergy;
    }

    port def LightSensorPort {
        out gradient : LightGradientSignal;
    }

    port def ContactSensorPort {
        out contact : ContactSignal;
    }

    port def MotorCommandPort {
        in command : MotorDriveSignal;
    }

    port def MotionPort {
        out motion : KinematicMotion;
    }

    port def MechanicalLoadPort {
        in torqueDemand : Real;
        out rotationSpeed : Real;
    }

    action def HarvestSolarEnergy {
        in incidentLight : SolarEnergy;
        out storedEnergy : Energy;
        attribute conversionEfficiency : Real = 0.18;
    }

    action def SenseLightGradient {
        in leftLight : Illuminance;
        in rightLight : Illuminance;
        out gradientSignal : LightGradientSignal;
    }

    action def SelectBeamMotorBias {
        in gradientSignal : LightGradientSignal;
        in storedEnergy : Energy;
        in contactSignal : ContactSignal;
        out leftMotorCommand : MotorDriveSignal;
        out rightMotorCommand : MotorDriveSignal;
    }

    action def DriveTowardLight {
        in leftCommand : MotorDriveSignal;
        in rightCommand : MotorDriveSignal;
        out robotMotion : KinematicMotion;
    }

    action def ReverseAndTurnAway {
        in contactSignal : ContactSignal;
        out leftMotorCommand : MotorDriveSignal;
        out rightMotorCommand : MotorDriveSignal;
        out avoidanceMotion : KinematicMotion;
    }

    state def PhotovoreControlStateMachine {
        attribute storedEnergy : Energy;
        attribute minimumStartEnergy : Energy = 0.45;
        attribute lowEnergyThreshold : Energy = 0.18;
        attribute lightGradient : LightGradientSignal;
        attribute contact : ContactSignal;
        attribute mode : MotionMode;

        entry action initialize {
            mode = MotionMode::sleeping;
        }

        state Sleeping {
            entry action disableMotors;
        }

        state Charging {
            entry action harvestAmbientLight;
        }

        state SeekingLight {
            entry action pulseMotorsWithNervousNetwork;
        }

        state ApproachingLight {
            entry action biasMotorsTowardDominantPhotodiode;
        }

        state AvoidingObstacle {
            entry action reverseOppositePressedWhisker;
        }

        state Stalled {
            entry action reduceLoadAndRecharge;
        }

        transition first Sleeping;

        transition Sleeping_to_Charging
            first Sleeping
            then Charging
            if storedEnergy < minimumStartEnergy;

        transition Charging_to_SeekingLight
            first Charging
            then SeekingLight
            if storedEnergy >= minimumStartEnergy;

        transition SeekingLight_to_ApproachingLight
            first SeekingLight
            then ApproachingLight
            if lightGradient.dominantSide != LightSide::dark;

        transition ApproachingLight_to_SeekingLight
            first ApproachingLight
            then SeekingLight
            if lightGradient.dominantSide == LightSide::balanced;

        transition AnyMotion_to_AvoidingObstacle
            first SeekingLight
            then AvoidingObstacle
            if contact.obstacleDetected;

        transition Approach_to_AvoidingObstacle
            first ApproachingLight
            then AvoidingObstacle
            if contact.obstacleDetected;

        transition AvoidingObstacle_to_SeekingLight
            first AvoidingObstacle
            then SeekingLight
            if not contact.obstacleDetected;

        transition Motion_to_Stalled
            first ApproachingLight
            then Stalled
            if storedEnergy <= lowEnergyThreshold;

        transition Stalled_to_Charging
            first Stalled
            then Charging
            if storedEnergy < minimumStartEnergy;
    }

    part def SolarCell {
        port sunInput : SolarInputPort;
        port electricalOutput : ElectricalPort;

        attribute openCircuitVoltage : Voltage = 3.2;
        attribute shortCircuitCurrent : Current = 0.080;
        attribute ratedPower : Power = 0.180;
        attribute activeArea : Real = 0.0036;
    }

    part def StorageCapacitor {
        port chargePort : ElectricalPort;
        port loadPort : ElectricalPort;

        attribute capacitance : Real = 1.0;
        attribute maximumVoltage : Voltage = 5.5;
        attribute storedEnergy : Energy;
        attribute leakageCurrent : Current = 0.000015;
    }

    part def BeamNervousNetwork {
        port electricalInput : ElectricalPort;
        port lightInput : LightSensorPort;
        port contactInput : ContactSensorPort;
        port leftMotorOutput : MotorCommandPort;
        port rightMotorOutput : MotorCommandPort;

        attribute oscillatorPeriod : TimeDuration = 0.32;
        attribute triggerVoltage : Voltage = 2.4;
        attribute hysteresisVoltage : Voltage = 0.35;
        attribute analogBiasGain : Real = 0.72;

        perform action SelectBeamMotorBias;
        exhibit state PhotovoreControlStateMachine;
    }

    part def PhotodiodePair {
        port sensorOutput : LightSensorPort;

        attribute leftIlluminance : Illuminance;
        attribute rightIlluminance : Illuminance;
        attribute saturationIlluminance : Illuminance = 95000.0;
        attribute minimumDetectableGradient : Illuminance = 20.0;

        perform action SenseLightGradient;
    }

    part def WhiskerBumperArray {
        port contactOutput : ContactSensorPort;

        attribute leftWhiskerLength : Distance = 0.035;
        attribute rightWhiskerLength : Distance = 0.035;
        attribute contactForceThreshold : Real = 0.08;
    }

    part def CorelessDcMotor {
        port commandInput : MotorCommandPort;
        port shaftOutput : MechanicalLoadPort;

        attribute nominalVoltage : Voltage = 3.0;
        attribute stallCurrent : Current = 0.320;
        attribute noLoadSpeed : Real = 18500.0;
        attribute gearRatio : Real = 48.0;
        attribute wheelTorque : Real;
    }

    part def DifferentialDrive {
        port leftWheelInput : MechanicalLoadPort;
        port rightWheelInput : MechanicalLoadPort;
        port motionOutput : MotionPort;

        attribute wheelDiameter : Distance = 0.032;
        attribute axleTrack : Distance = 0.075;
        attribute maximumForwardSpeed : Speed = 0.22;
        attribute minimumTurnRadius : Distance = 0.040;

        perform action DriveTowardLight;
        perform action ReverseAndTurnAway;
    }

    part def LightweightChassis {
        attribute mass : Real = 0.085;
        attribute length : Distance = 0.105;
        attribute width : Distance = 0.085;
        attribute groundClearance : Distance = 0.012;
        attribute materialName : String = "recycled polypropylene sheet";
    }

    part def BeamPhotovoreRobot {
        port solarExposure : SolarInputPort;
        port locomotion : MotionPort;

        attribute primaryFunction : String =
            "Autonomously harvest ambient light and use minimal analog BEAM control to move toward stronger illumination while avoiding simple obstacles.";
        attribute currentMode : MotionMode;
        attribute nominalOperatingVoltage : Voltage = 3.0;
        attribute minimumOperatingIlluminance : Illuminance = 2500.0;
        attribute expectedIndoorSpeed : Speed = 0.06;
        attribute expectedOutdoorSpeed : Speed = 0.18;
        attribute maximumContinuousRunTimeWithoutLight : TimeDuration = 45.0;

        part solarCell : SolarCell;
        part energyStore : StorageCapacitor;
        part nervousNetwork : BeamNervousNetwork;
        part lightSensors : PhotodiodePair;
        part whiskers : WhiskerBumperArray;
        part leftMotor : CorelessDcMotor;
        part rightMotor : CorelessDcMotor;
        part drive : DifferentialDrive;
        part chassis : LightweightChassis;

        connect solarExposure to solarCell.sunInput;
        connect solarCell.electricalOutput to energyStore.chargePort;
        connect energyStore.loadPort to nervousNetwork.electricalInput;
        connect lightSensors.sensorOutput to nervousNetwork.lightInput;
        connect whiskers.contactOutput to nervousNetwork.contactInput;
        connect nervousNetwork.leftMotorOutput to leftMotor.commandInput;
        connect nervousNetwork.rightMotorOutput to rightMotor.commandInput;
        connect leftMotor.shaftOutput to drive.leftWheelInput;
        connect rightMotor.shaftOutput to drive.rightWheelInput;
        connect drive.motionOutput to locomotion;

        perform action HarvestSolarEnergy;
        perform action SenseLightGradient;
        perform action SelectBeamMotorBias;
        perform action DriveTowardLight;
        perform action ReverseAndTurnAway;
    }

    requirement def HighLevelPrimaryFunctionRequirement {
        subject robot : BeamPhotovoreRobot;

        require constraint {
            robot.primaryFunction ==
            "Autonomously harvest ambient light and use minimal analog BEAM control to move toward stronger illumination while avoiding simple obstacles."
        }
    }

    requirement def SolarAutonomyRequirement {
        subject robot : BeamPhotovoreRobot;

        require constraint {
            robot.minimumOperatingIlluminance <= 2500.0
        }

        require constraint {
            robot.nominalOperatingVoltage >= 2.4
        }
    }

    requirement def MinimalBeamControlRequirement {
        subject controller : BeamNervousNetwork;

        require constraint {
            controller.oscillatorPeriod >= 0.05 and controller.oscillatorPeriod <= 1.0
        }

        require constraint {
            controller.triggerVoltage <= 2.4
        }
    }

    requirement def PhototaxisRequirement {
        subject robot : BeamPhotovoreRobot;

        require constraint {
            robot.expectedIndoorSpeed >= 0.04
        }

        require constraint {
            robot.expectedOutdoorSpeed >= robot.expectedIndoorSpeed
        }
    }

    requirement def ObstacleAvoidanceRequirement {
        subject bumper : WhiskerBumperArray;

        require constraint {
            bumper.contactForceThreshold <= 0.10
        }

        require constraint {
            bumper.leftWhiskerLength >= 0.030 and bumper.rightWhiskerLength >= 0.030
        }
    }

    requirement def EnergyStorageRequirement {
        subject capacitor : StorageCapacitor;

        require constraint {
            capacitor.maximumVoltage >= 5.0
        }

        require constraint {
            capacitor.leakageCurrent <= 0.000020
        }
    }

    part beamPhotovoreSystem : BeamPhotovoreRobot;

    satisfy HighLevelPrimaryFunctionRequirement by beamPhotovoreSystem;
    satisfy SolarAutonomyRequirement by beamPhotovoreSystem;
    satisfy PhototaxisRequirement by beamPhotovoreSystem;
    satisfy MinimalBeamControlRequirement by beamPhotovoreSystem.nervousNetwork;
    satisfy ObstacleAvoidanceRequirement by beamPhotovoreSystem.whiskers;
    satisfy EnergyStorageRequirement by beamPhotovoreSystem.energyStore;
}