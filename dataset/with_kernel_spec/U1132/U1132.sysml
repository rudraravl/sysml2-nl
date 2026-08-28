package AutonomousMilitaryGroundRobot {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def BatteryCapacity :> ISQ::EnergyValue;
    attribute def FiringRate :> Real;
    attribute def AmmunitionCount :> Integer;
    attribute def DetectionRange :> ISQ::LengthValue;

    enum def ThreatType { personnel; vehicle; unknown; }

    item def Coordinate {
        attribute latitude : Real;
        attribute longitude : Real;
    }

    attribute def SigStartMission;
    attribute def SigReachWaypoint;
    attribute def SigThreatDetected;
    attribute def SigThreatClear;
    attribute def SigEngagementComplete;
    attribute def SigTransmissionComplete;
    attribute def SigReturnToBase;
    attribute def SigArrivedBase;
    attribute def SigLowBattery;

    action def NavigateToWaypoint;
    action def ScanAreaForThreats;
    action def EngageTarget;
    action def TransmitIntelligence;
    action def ReturnToBase;

    part def AutonomousMilitaryGroundRobot {
        attribute mass : ISQ::MassValue;
        
        part mobilityPlatform : MobilityPlatform;
        part batterySystem : BatterySystem;
        part missionController : MissionController;
        part sensorSuite : SensorSuite;
        part weaponSystem : WeaponSystem;
        part communicationSystem : CommunicationSystem;
        part navigationSystem : NavigationSystem;
        
        connect batterySystem.powerPort to mobilityPlatform.powerPort;
        connect batterySystem.powerPort to missionController.powerPort;
        connect batterySystem.powerPort to sensorSuite.powerPort;
        connect batterySystem.powerPort to weaponSystem.powerPort;
        connect batterySystem.powerPort to communicationSystem.powerPort;
        connect batterySystem.powerPort to navigationSystem.powerPort;
        
        connect missionController.mobilityCmdPort to mobilityPlatform.commandPort;
        connect missionController.sensorCmdPort to sensorSuite.commandPort;
        connect missionController.weaponCmdPort to weaponSystem.commandPort;
        connect missionController.commCmdPort to communicationSystem.commandPort;
        connect missionController.navCmdPort to navigationSystem.commandPort;
        
        connect sensorSuite.dataPort to missionController.sensorDataPort;
        connect navigationSystem.dataPort to missionController.navDataPort;
        connect communicationSystem.dataPort to missionController.commDataPort;
    }

    part def MobilityPlatform {
        port powerPort { in attribute power : ISQ::PowerValue; }
        port commandPort { in attribute command : String; }
    }

    part def BatterySystem {
        attribute capacity : BatteryCapacity = 50 [kW*h];
        port powerPort { out attribute power : ISQ::PowerValue; }
    }

    part def MissionController {
        port powerPort { in attribute power : ISQ::PowerValue; }
        port mobilityCmdPort { out attribute command : String; }
        port sensorCmdPort { out attribute command : String; }
        port weaponCmdPort { out attribute command : String; }
        port commCmdPort { out attribute command : String; }
        port navCmdPort { out attribute command : String; }
        
        port sensorDataPort { in attribute sensorData : String; }
        port navDataPort { in attribute navData : String; }
        port commDataPort { in attribute commData : String; }
        
        state missionStates {
            entry; then idle;
            state idle;
            transition idle_to_navigating
                first idle
                accept SigStartMission
                do action navigateToWaypoint : NavigateToWaypoint
                then navigating;
            state navigating;
            transition navigating_to_scanning
                first navigating
                accept SigReachWaypoint
                do action scanAreaForThreats : ScanAreaForThreats
                then scanning;
            state scanning;
            transition scanning_to_engaging
                first scanning
                accept SigThreatDetected
                do action engageTarget : EngageTarget
                then engaging;
            transition scanning_to_transmitting
                first scanning
                accept SigThreatClear
                do action transmitIntelligence : TransmitIntelligence
                then transmitting;
            state engaging;
            transition engaging_to_transmitting
                first engaging
                accept SigEngagementComplete
                do action transmitIntelligence : TransmitIntelligence
                then transmitting;
            state transmitting;
            transition transmitting_to_returning
                first transmitting
                accept SigReturnToBase
                do action returnToBase : ReturnToBase
                then returning;
            state returning;
            transition returning_to_idle
                first returning
                accept SigArrivedBase
                then idle;
            transition lowBattery_to_returning
                first idle
                accept SigLowBattery
                do action returnToBase : ReturnToBase
                then returning;
        }
    }

    part def SensorSuite {
        part opticalCamera : OpticalCamera;
        part thermalSensor : ThermalSensor;
        part radarSystem : RadarSystem;
        port powerPort { in attribute power : ISQ::PowerValue; }
        port commandPort { in attribute command : String; }
        port dataPort { out attribute sensorData : String; }
    }

    part def OpticalCamera {
        attribute resolution : Real;
    }
    part def ThermalSensor {
        attribute sensitivity : Real;
    }
    part def RadarSystem {
        attribute range : DetectionRange;
    }

    part def WeaponSystem {
        attribute ammunition : AmmunitionCount = 1000;
        attribute firingRate : FiringRate = 600;
        port powerPort { in attribute power : ISQ::PowerValue; }
        port commandPort { in attribute command : String; }
    }

    part def CommunicationSystem {
        attribute encryptionLevel : Integer = 256;
        port powerPort { in attribute power : ISQ::PowerValue; }
        port commandPort { in attribute command : String; }
        port dataPort { out attribute commData : String; }
    }

    part def NavigationSystem {
        attribute accuracy : ISQ::LengthValue;
        port powerPort { in attribute power : ISQ::PowerValue; }
        port commandPort { in attribute command : String; }
        port dataPort { out attribute navData : String; }
    }

    requirement def ReconnaissanceMission {
        subject robot : AutonomousMilitaryGroundRobot;
        doc /* The robot shall autonomously navigate, scan, engage, and transmit data. */
    }
}
