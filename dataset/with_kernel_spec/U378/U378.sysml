package Segs4Vets {
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def AngleValue :> ScalarValues::Real;
    attribute def TorqueValue :> ScalarValues::Real;
    attribute def TimeValue :> ScalarValues::Real;
    attribute def ChargeValue :> ScalarValues::Real;

    item def SensorData {
        attribute tiltAngle : AngleValue;
        attribute userBalance : Real;
    }
    item def TorqueCommand {
        attribute torque : TorqueValue;
    }
    item def EmergencyStop;
    item def SafetyAlert {
        attribute alertType : String;
    }
    item def SessionData {
        attribute veteranID : Integer;
        attribute balanceScore : Real;
        attribute duration : TimeValue;
    }
    item def TherapySettings {
        attribute veteranID : Integer;
        attribute maxTiltAngle : AngleValue;
        attribute therapyLevel : Integer;
    }
    item def BatteryStatus {
        attribute chargeLevel : ChargeValue;
    }

    part def BalanceSensor {
        port sensorDataPort_out { out sensorData : SensorData; }
    }
    part def TherapyController {
        port sensorDataPort_in { in sensorData : SensorData; }
        port torqueCommandPort_out { out torqueCommand : TorqueCommand; }
        port sessionDataPort_out { out sessionData : SessionData; }
        port therapySettingsPort_in { in therapySettings : TherapySettings; }
        port safetyAlertPort_in { in safetyAlert : SafetyAlert; }
        port batteryStatusPort_in { in batteryStatus : BatteryStatus; }
        
        attribute currentTilt : AngleValue;
        attribute maxTilt : AngleValue;
        attribute therapyLevel : Integer;
        attribute veteranID : Integer;
        attribute elapsedTime : TimeValue := 0;
        
        state machine def TherapyControllerStates {
            initial state Idle;
            state Active;
            state Emergency;
            transition from Idle to Active accept therapySettings via therapySettingsPort_in;
            transition from Active to Emergency accept safetyAlert via safetyAlertPort_in;
            transition from Emergency to Idle;
        }
    }
    part def MotorController {
        port torqueCommandPort_in { in torqueCommand : TorqueCommand; }
        port emergencyStopPort_in { in emergencyStop : EmergencyStop; }
    }
    part def Wheels;
    part def DisplayPanel {
        port sessionDataPort_in { in sessionData : SessionData; }
    }
    part def TherapistInterface {
        port therapySettingsPort_out { out therapySettings : TherapySettings; }
        port safetyAlertPort_in { in safetyAlert : SafetyAlert; }
    }
    part def SafetyMonitor {
        port sensorDataPort_in { in sensorData : SensorData; }
        port emergencyStopPort_out { out emergencyStop : EmergencyStop; }
        port safetyAlertPort_out { out safetyAlert : SafetyAlert; }
        port therapySettingsPort_in { in therapySettings : TherapySettings; }
        
        attribute maxTiltThreshold : AngleValue;
        
        state machine def SafetyMonitorStates {
            initial state Monitoring;
            state EmergencyStopState;
            transition from Monitoring to EmergencyStopState 
                when sensorDataPort_in.sensorData.tiltAngle > maxTiltThreshold;
        }
    }
    part def BatterySystem {
        port batteryStatusPort_out { out batteryStatus : BatteryStatus; }
    }
    part def VeteranProfile {
        port sessionDataPort_in { in sessionData : SessionData; }
        attribute logs : SessionData[*];
    }

    part def Segs4VetsPlatform {
        part balanceSensor : BalanceSensor;
        part therapyController : TherapyController;
        part motorController : MotorController;
        part wheels : Wheels;
        part displayPanel : DisplayPanel;
        part therapistInterface : TherapistInterface;
        part safetyMonitor : SafetyMonitor;
        part batterySystem : BatterySystem;
        part veteranProfile : VeteranProfile;
        
        flow sensorDataFlow1 of SensorData 
            from balanceSensor.sensorDataPort_out.sensorData to therapyController.sensorDataPort_in.sensorData;
        flow sensorDataFlow2 of SensorData 
            from balanceSensor.sensorDataPort_out.sensorData to safetyMonitor.sensorDataPort_in.sensorData;
        flow torqueCommandFlow of TorqueCommand 
            from therapyController.torqueCommandPort_out.torqueCommand to motorController.torqueCommandPort_in.torqueCommand;
        flow sessionDataFlow1 of SessionData 
            from therapyController.sessionDataPort_out.sessionData to displayPanel.sessionDataPort_in.sessionData;
        flow sessionDataFlow2 of SessionData 
            from therapyController.sessionDataPort_out.sessionData to veteranProfile.sessionDataPort_in.sessionData;
        flow therapySettingsFlow1 of TherapySettings 
            from therapistInterface.therapySettingsPort_out.therapySettings to therapyController.therapySettingsPort_in.therapySettings;
        flow therapySettingsFlow2 of TherapySettings 
            from therapistInterface.therapySettingsPort_out.therapySettings to safetyMonitor.therapySettingsPort_in.therapySettings;
        flow safetyAlertFlow of SafetyAlert 
            from safetyMonitor.safetyAlertPort_out.safetyAlert to therapistInterface.safetyAlertPort_in.safetyAlert;
        flow emergencyStopFlow of EmergencyStop 
            from safetyMonitor.emergencyStopPort_out.emergencyStop to motorController.emergencyStopPort_in.emergencyStop;
        flow batteryStatusFlow of BatteryStatus 
            from batterySystem.batteryStatusPort_out.batteryStatus to therapyController.batteryStatusPort_in.batteryStatus;
    }

    requirement def BalanceTherapyReq {
        doc /* The system shall provide controlled balance therapy. */
        subject platform : Segs4VetsPlatform;
        constraint { platform.therapyController.torqueCommandPort_out.torqueCommand.torque > 0 }
    }
    requirement def SafetyReq {
        doc /* The system shall trigger an emergency stop if tilt exceeds max. */
        subject platform : Segs4VetsPlatform;
        constraint { platform.safetyMonitor.emergencyStopPort_out.emergencyStop.isDefined() }
    }
    requirement def DataLoggingReq {
        doc /* The system shall log balance score in veteran profile. */
        subject platform : Segs4VetsPlatform;
        constraint { platform.veteranProfile.logs->size() > 0 }
    }
}
