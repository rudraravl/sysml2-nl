package Segs4Vets {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQEnergy::*;
    import ISQElectricity::*;
    import ISQTime::*;

    // ===== Value Types =====

    value def Angle :> RealValue {
        unit deg;
    }

    value def AngularRate :> RealValue {
        unit deg/'s';
    }

    value def Torque :> RealValue {
        unit 'N*m';
    }

    value def Voltage :> RealValue {
        unit 'V';
    }

    value def Current :> RealValue {
        unit 'A';
    }

    value def Charge :> RealValue {
        unit 'A*h';
    }

    value def Power :> RealValue {
        unit 'W';
    }

    value def Mass :> RealValue {
        unit 'kg';
    }

    value def LinearSpeed :> RealValue {
        unit 'm/s';
    }

    value def Score :> RealValue {
        unit '1';
    }

    value def TherapyLevel :> IntegerValue {
        unit '1';
    }

    value def Percentage :> RealValue {
        unit '%';
    }

    // ===== Item Types =====

    item def BalanceData {
        attribute tiltAngle : Angle;
        attribute tiltRate : AngularRate;
        attribute userLoad : Mass;
    }

    item def TorqueCommand {
        attribute leftTorque : Torque;
        attribute rightTorque : Torque;
    }

    item def MotorCommand {
        attribute targetTorque : Torque;
        attribute direction : ScalarValues::Integer;
    }

    item def SafetyParameters {
        attribute maxTiltAngle : Angle = 15 [deg];
        attribute emergencyTiltAngle : Angle = 25 [deg];
        attribute maxSpeed : LinearSpeed = 1.5 [m/s];
        attribute therapyLevel : TherapyLevel = 1;
    }

    item def SessionRecord {
        attribute veteranId : String;
        attribute sessionId : String;
        attribute duration : TimeValue;
        attribute averageTilt : Angle;
        attribute balanceScore : Score;
        attribute timestamp : String;
    }

    item def SafetyAlert {
        attribute alertType : String;
        attribute severity : Integer;
        attribute measuredValue : Real;
        attribute threshold : Real;
    }

    item def DisplayInfo {
        attribute balanceScore : Score;
        attribute currentTilt : Angle;
        attribute sessionTime : TimeValue;
        attribute therapyLevel : TherapyLevel;
        attribute batteryLevel : Percentage;
    }

    item def TherapistInfo {
        attribute veteranName : String;
        attribute currentTilt : Angle;
        attribute balanceScore : Score;
        attribute batteryLevel : Percentage;
        attribute alertActive : Boolean;
    }

    item def BatteryStatus {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute charge : Charge;
        attribute chargeLevel : Percentage;
        attribute temperature : RealValue;
    }

    // ===== Port Definitions =====

    port def BalanceDataPort {
        out balanceData : BalanceData;
    }

    port def TorqueCommandPort {
        in torqueCommand : TorqueCommand;
    }

    port def MotorCommandPort {
        out motorCommand : MotorCommand;
    }

    port def SafetyParamPort {
        out safetyParameters : SafetyParameters;
    }

    port def SafetyAlertPort {
        out safetyAlert : SafetyAlert;
    }

    port def DisplayInfoPort {
        out displayInfo : DisplayInfo;
    }

    port def TherapistInfoPort {
        out therapistInfo : TherapistInfo;
    }

    port def BatteryStatusPort {
        out batteryStatus : BatteryStatus;
    }

    port def SessionRecordPort {
        out sessionRecord : SessionRecord;
    }

    port def EmergencyStopPort {
        out emergencyStop : Boolean;
    }

    // ===== Requirements =====

    requirement def BalanceTherapyRequirement {
        doc /* The system shall provide controlled balance therapy for veterans with mobility impairments. */
        subject platform : Segs4Vets::Platform;
        objective {
            doc /* Improve coordination, stability, and confidence. */
        }
    }

    requirement def SelfStabilizationRequirement :> BalanceTherapyRequirement {
        doc /* The platform shall self-stabilize using motor torque based on balance sensor data. */
        assume { platform.balanceSensor.measuresTilt == true; }
        require {
            platform.therapyController.responseTime < 50 [ms];
        }
    }

    requirement def SafetyMonitorRequirement {
        doc /* The safety monitor shall trigger an emergency stop when tilt exceeds the emergency threshold. */
        subject safetyMonitor : Segs4Vets::SafetyMonitor;
        require {
            safetyMonitor.emergencyStopTriggered == true
                when safetyMonitor.measuredTilt > safetyMonitor.emergencyThreshold;
        }
    }

    requirement def TherapyLevelRequirement {
        doc /* The therapist shall set therapy level and safety parameters per veteran. */
        subject therapistInterface : Segs4Vets::TherapistInterface;
        require {
            therapistInterface.safetyParameters.therapyLevel >= 1
            and therapistInterface.safetyParameters.therapyLevel <= 5;
        }
    }

    requirement def BatteryRequirement {
        doc /* The battery shall provide sufficient charge for a therapy session of at least 60 minutes. */
        subject battery : Segs4Vets::BatterySystem;
        require {
            battery.minSessionDuration >= 60 [min];
        }
    }

    requirement def PerformanceTrackingRequirement {
        doc /* The system shall track balance performance and log session records to the veteran profile. */
        subject performanceTracker : Segs4Vets::PerformanceTracker;
        require {
            performanceTracker.sessionRecord.balanceScore >= 0.0
            and performanceTracker.sessionRecord.balanceScore <= 100.0;
        }
    }

    // ===== Parts =====

    part def BalanceSensor {
        attribute samplingRate : TimeValue = 10 [ms];
        port balanceOut : BalanceDataPort;
        attribute measuresTilt : Boolean = true;

        action def senseBalance {
            in userLoad : Mass;
            out data : BalanceData;
        }

        perform senseBalance;
    }

    part def TherapyController {
        attribute therapyLevel : TherapyLevel;
        attribute maxTiltAngle : Angle;
        attribute emergencyTiltAngle : Angle;
        attribute responseTime : TimeValue;

        port balanceIn : BalanceDataPort opposite BalanceDataPort::balanceData;
        port torqueOut : TorqueCommandPort;
        port safetyParamIn : SafetyParamPort;
        port displayOut : DisplayInfoPort;
        port therapistOut : TherapistInfoPort;
        port batteryIn : BatteryStatusPort;
        port sessionOut : SessionRecordPort;

        attribute currentBalanceScore : Score = 0.0;
        attribute sessionStartTime : TimeValue;

        action def computeTorque {
            in balance : BalanceData;
            in level : TherapyLevel;
            in maxTilt : Angle;
            out command : TorqueCommand;

            action calculateError {
                in tilt : Angle;
                in maxTiltAngle : Angle;
                out error : Angle;
            }
            action applyControlLaw {
                in error : Angle;
                in rate : AngularRate;
                in level : TherapyLevel;
                out torque : Torque;
            }
            flow calculateError.error -> applyControlLaw.error;
            flow balance.tiltAngle -> calculateError.tilt;
            flow balance.tiltRate -> applyControlLaw.rate;
            flow level -> applyControlLaw.level;
            flow maxTilt -> calculateError.maxTiltAngle;
            flow applyControlLaw.torque -> command.leftTorque;
            flow applyControlLaw.torque -> command.rightTorque;
        }

        action def updateBalanceScore {
            in balance : BalanceData;
            in maxTilt : Angle;
            out score : Score;
        }

        state def ControllerBehavior {
            entry; then Idle;
            state Idle;
            transition from Idle to Active
                when balanceIn.balanceData.tiltAngle > 0 [deg];
            state Active {
                entry;
                do computeTorque;
            }
            transition from Active to Emergency
                when balanceIn.balanceData.tiltAngle > emergencyTiltAngle;
            state Emergency {
                entry;
            }
            transition from Emergency to Idle
                when safetyParamIn.safetyParameters.therapyLevel == 0;
        }

        perform ControllerBehavior;
    }

    part def MotorController {
        port torqueIn : TorqueCommandPort opposite TorqueCommandPort::torqueCommand;
        port motorOut : MotorCommandPort;
        port emergencyIn : EmergencyStopPort;

        action def driveMotors {
            in command : TorqueCommand;
            in emergency : Boolean;
            out motorCommand : MotorCommand;
        }

        perform driveMotors;
    }

    part def WheelAssembly {
        attribute wheelRadius : LengthValue = 0.25 [m];
        port motorIn : MotorCommandPort opposite MotorCommandPort::motorCommand;

        action def rotate {
            in command : MotorCommand;
        }

        perform rotate;
    }

    part def Platform {
        part balanceSensor : BalanceSensor;
        part therapyController : TherapyController;
        part motorController : MotorController;
        part leftWheel : WheelAssembly;
        part rightWheel : WheelAssembly;

        connection balanceSensor.balanceOut to therapyController.balanceIn;
        connection therapyController.torqueOut to motorController.torqueIn;
        connection motorController.motorOut to leftWheel.motorIn;
        connection motorController.motorOut to rightWheel.motorIn;
    }

    part def SafetyMonitor {
        attribute measuredTilt : Angle;
        attribute emergencyThreshold : Angle;
        attribute emergencyStopTriggered : Boolean = false;

        port balanceIn : BalanceDataPort opposite BalanceDataPort::balanceData;
        port safetyParamIn : SafetyParamPort;
        port emergencyOut : EmergencyStopPort;
        port alertOut : SafetyAlertPort;

        action def checkSafety {
            in tilt : Angle;
            in threshold : Angle;
            out emergency : Boolean;
            out alert : SafetyAlert;

            if tilt > threshold {
                emergency = true;
                alert.alertType = "ExcessiveTilt";
                alert.severity = 3;
                alert.measuredValue = tilt;
                alert.threshold = threshold;
            } else {
                emergency = false;
            }
        }

        state def SafetyMonitorBehavior {
            entry; then Monitoring;
            state Monitoring {
                do checkSafety;
            }
            transition from Monitoring to AlarmState
                when balanceIn.balanceData.tiltAngle > emergencyThreshold;
            state AlarmState {
                entry;
            }
            transition from AlarmState to Monitoring
                when balanceIn.balanceData.tiltAngle < emergencyThreshold;
        }

        perform SafetyMonitorBehavior;
    }

    part def DisplayPanel {
        port infoIn : DisplayInfoPort opposite DisplayInfoPort::displayInfo;

        action def renderDisplay {
            in info : DisplayInfo;
        }

        perform renderDisplay;
    }

    part def TherapistInterface {
        attribute safetyParameters : SafetyParameters;
        port paramOut : SafetyParamPort;
        port infoIn : TherapistInfoPort opposite TherapistInfoPort::therapistInfo;
        port alertIn : SafetyAlertPort opposite SafetyAlertPort::safetyAlert;
        port sessionIn : SessionRecordPort opposite SessionRecordPort::sessionRecord;

        action def registerVeteran {
            in veteranName : String;
            out veteranId : String;
        }

        action def setSafetyParameters {
            in maxTilt : Angle;
            in emergencyTilt : Angle;
            in level : TherapyLevel;
            out params : SafetyParameters;
        }

        action def monitorProgress {
            in info : TherapistInfo;
            in alert : SafetyAlert;
        }

        perform registerVeteran;
        perform setSafetyParameters;
        perform monitorProgress;
    }

    part def BatterySystem {
        attribute nominalVoltage : Voltage = 24 [V];
        attribute capacity : Charge = 10 [A*h];
        attribute chargeLevel : Percentage = 100 [%];
        attribute minSessionDuration : TimeValue = 60 [min];

        port statusOut : BatteryStatusPort;

        action def monitorBattery {
            out status : BatteryStatus;
        }

        action def recharge {
            in chargeCurrent : Current;
            out newCharge : Charge;
        }

        state def BatteryBehavior {
            entry; then Charged;
            state Charged;
            transition from Charged to Discharging
                when statusOut.batteryStatus.current > 0 [A];
            state Discharging {
                do monitorBattery;
            }
            transition from Discharging to LowBattery
                when statusOut.batteryStatus.chargeLevel < 20 [%];
            state LowBattery {
                entry;
            }
            transition from LowBattery to Charging;
            state Charging {
                do recharge;
            }
            transition from Charging to Charged
                when statusOut.batteryStatus.chargeLevel >= 100 [%];
        }

        perform BatteryBehavior;
    }

    part def PerformanceTracker {
        attribute sessionRecord : SessionRecord;
        attribute balanceScore : Score;

        port balanceIn : BalanceDataPort opposite BalanceDataPort::balanceData;
        port sessionOut : SessionRecordPort;

        action def trackPerformance {
            in balance : BalanceData;
            in maxTilt : Angle;
            out score : Score;
        }

        action def generateSessionRecord {
            in veteranId : String;
            in duration : TimeValue;
            in avgTilt : Angle;
            in score : Score;
            out record : SessionRecord;
        }

        action def logToProfile {
            in record : SessionRecord;
        }

        perform trackPerformance;
        perform generateSessionRecord;
        perform logToProfile;
    }

    part def VeteranProfile {
        attribute veteranId : String;
        attribute veteranName : String;
        attribute sessionHistory : SessionRecord[0..*];

        port sessionIn : SessionRecordPort opposite SessionRecordPort::sessionRecord;

        action def storeRecord {
            in record : SessionRecord;
        }

        perform storeRecord;
    }

    // ===== Top-Level System =====

    part def Segs4VetsSystem {

        part platform : Platform {
            part balanceSensor : BalanceSensor;
            part therapyController : TherapyController;
            part motorController : MotorController;
            part leftWheel : WheelAssembly;
            part rightWheel : WheelAssembly;
        }

        part safetyMonitor : SafetyMonitor;
        part displayPanel : DisplayPanel;
        part therapistInterface : TherapistInterface;
        part batterySystem : BatterySystem;
        part performanceTracker : PerformanceTracker;
        part veteranProfile : VeteranProfile;

        // Connections
        connection platform.balanceSensor.balanceOut to platform.therapyController.balanceIn;
        connection platform.balanceSensor.balanceOut to safetyMonitor.balanceIn;
        connection platform.balanceSensor.balanceOut to performanceTracker.balanceIn;
        connection platform.therapyController.torqueOut to platform.motorController.torqueIn;
        connection platform.motorController.motorOut to platform.leftWheel.motorIn;
        connection platform.motorController.motorOut to platform.rightWheel.motorIn;
        connection therapistInterface.paramOut to platform.therapyController.safetyParamIn;
        connection therapistInterface.paramOut to safetyMonitor.safetyParamIn;
        connection safetyMonitor.emergencyOut to platform.motorController.emergencyIn;
        connection safetyMonitor.alertOut to therapistInterface.alertIn;
        connection platform.therapyController.displayOut to displayPanel.infoIn;
        connection platform.therapyController.therapistOut to therapistInterface.infoIn;
        connection batterySystem.statusOut to platform.therapyController.batteryIn;
        connection platform.therapyController.sessionOut to therapistInterface.sessionIn;
        connection performanceTracker.sessionOut to veteranProfile.sessionIn;

        // Requirement satisfactions
        satisfy SelfStabilizationRequirement by platform;
        satisfy SafetyMonitorRequirement by safetyMonitor;
        satisfy TherapyLevelRequirement by therapistInterface;
        satisfy BatteryRequirement by batterySystem;
        satisfy PerformanceTrackingRequirement by performanceTracker;
        satisfy BalanceTherapyRequirement by platform;
    }

    // ===== Session Behavior =====

    action def TherapySession {
        in veteranName : String;
        in therapyLevel : TherapyLevel;
        in maxTilt : Angle;
        in emergencyTilt : Angle;

        action registerVeteran {
            in name : String;
            out veteranId : String;
        }

        action configureSafety {
            in level : TherapyLevel;
            in maxTiltAngle : Angle;
            in emergencyTiltAngle : Angle;
            out params : SafetyParameters;
        }

        action conductTherapy {
            in params : SafetyParameters;
            out balanceScore : Score;
            out sessionRecord : SessionRecord;
        }

        action logSession {
            in record : SessionRecord;
        }

        flow veteranName -> registerVeteran.name;
        flow therapyLevel -> configureSafety.level;
        flow maxTilt -> configureSafety.maxTiltAngle;
        flow emergencyTilt -> configureSafety.emergencyTiltAngle;
        flow configureSafety.params -> conductTherapy.params;
        flow conductTherapy.sessionRecord -> logSession.record;

        then done;
    }

}
