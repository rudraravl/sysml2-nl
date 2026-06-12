package MechaSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def ArmorRating :> Real {
        unit = "mmRHAe";
    }

    attribute def RoundsPerMinute :> Real {
        unit = "rpm";
    }

    item def ElectricalPower {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute power : Power;
    }

    item def HydraulicPower {
        attribute pressure : Pressure;
        attribute flowRate : VolumeFlowRate;
    }

    item def Coolant {
        attribute temperature : Temperature;
        attribute flowRate : MassFlowRate;
    }

    item def CommandPacket {
        attribute commandId : Integer;
        attribute priority : Integer;
        attribute targetMode : String;
    }

    item def SensorTrack {
        attribute trackId : Integer;
        attribute range : Length;
        attribute bearing : PlaneAngle;
        attribute confidence : Percent;
        attribute classification : String;
    }

    item def PilotInput {
        attribute throttle : Percent;
        attribute strideCommand : Percent;
        attribute torsoYawCommand : PlaneAngle;
        attribute weaponConsent : Boolean;
    }

    item def Ammunition {
        attribute caliber : Length;
        attribute mass : Mass;
        attribute armorPiercing : Boolean;
    }

    item def DiagnosticReport {
        attribute healthScore : Percent;
        attribute faultCode : String;
        attribute missionCapable : Boolean;
    }

    port def ElectricalPowerPort {
        out item powerOut : ElectricalPower;
        in item powerIn : ElectricalPower;
    }

    port def HydraulicPort {
        out item hydraulicOut : HydraulicPower;
        in item hydraulicIn : HydraulicPower;
    }

    port def CoolantPort {
        out item coolantOut : Coolant;
        in item coolantIn : Coolant;
    }

    port def CommandPort {
        in item commandIn : CommandPacket;
        out item commandOut : CommandPacket;
    }

    port def SensorPort {
        out item trackOut : SensorTrack;
        in item trackIn : SensorTrack;
    }

    port def PilotInterfacePort {
        in item pilotInput : PilotInput;
        out item statusReport : DiagnosticReport;
    }

    port def AmmunitionPort {
        out item roundOut : Ammunition;
        in item roundIn : Ammunition;
    }

    part def BattleMecha {
        attribute height : Length = 14.2 [m];
        attribute combatMass : Mass = 48500 [kg];
        attribute maximumRoadSpeed : Speed = 18 [m/s];
        attribute endurance : Time = 21600 [s];
        attribute armorProtection : ArmorRating = 420 [mmRHAe];
        attribute crewCount : Integer = 1;

        port pilotInterface : PilotInterfacePort;
        port commandData : CommandPort;
        port externalPower : ElectricalPowerPort;
        port sensorData : SensorPort;

        part cockpit : ArmoredCockpit;
        part reactor : CompactFusionReactor;
        part powerBus : HighVoltagePowerBus;
        part thermalSystem : ThermalManagementSystem;
        part hydraulicSystem : ElectroHydraulicSystem;
        part leftLeg : ActuatedLeg;
        part rightLeg : ActuatedLeg;
        part torso : RotaryTorso;
        part leftArm : ManipulatorArm;
        part rightArm : ManipulatorArm;
        part primaryWeapon : RailCannon;
        part secondaryWeapon : MissilePod;
        part sensorMast : MultiSpectrumSensorSuite;
        part missionComputer : MissionComputer;
        part armorSystem : ModularArmorShell;
        part selfRepairSystem : FieldRepairSystem;

        connect cockpit.pilotControls to pilotInterface;
        connect cockpit.commandLink to missionComputer.pilotCommand;
        connect sensorMast.trackPort to missionComputer.sensorFusionInput;
        connect missionComputer.fireControlOutput to primaryWeapon.fireCommand;
        connect missionComputer.fireControlOutput to secondaryWeapon.fireCommand;
        connect missionComputer.motionCommandOutput to torso.motionCommand;
        connect missionComputer.motionCommandOutput to leftLeg.motionCommand;
        connect missionComputer.motionCommandOutput to rightLeg.motionCommand;
        connect missionComputer.motionCommandOutput to leftArm.motionCommand;
        connect missionComputer.motionCommandOutput to rightArm.motionCommand;
        connect reactor.electricalOutput to powerBus.reactorInput;
        connect powerBus.legPowerOutput to leftLeg.electricalInput;
        connect powerBus.legPowerOutput to rightLeg.electricalInput;
        connect powerBus.weaponPowerOutput to primaryWeapon.electricalInput;
        connect powerBus.weaponPowerOutput to secondaryWeapon.electricalInput;
        connect powerBus.computingPowerOutput to missionComputer.electricalInput;
        connect powerBus.sensorPowerOutput to sensorMast.electricalInput;
        connect powerBus.utilityPowerOutput to cockpit.electricalInput;
        connect powerBus.utilityPowerOutput to thermalSystem.electricalInput;
        connect powerBus.utilityPowerOutput to hydraulicSystem.electricalInput;
        connect hydraulicSystem.hydraulicOutput to leftLeg.hydraulicInput;
        connect hydraulicSystem.hydraulicOutput to rightLeg.hydraulicInput;
        connect hydraulicSystem.hydraulicOutput to leftArm.hydraulicInput;
        connect hydraulicSystem.hydraulicOutput to rightArm.hydraulicInput;
        connect hydraulicSystem.hydraulicOutput to torso.hydraulicInput;
        connect thermalSystem.coolantOutput to reactor.coolantInput;
        connect thermalSystem.coolantOutput to primaryWeapon.coolantInput;
        connect thermalSystem.coolantOutput to powerBus.coolantInput;
        connect armorSystem.damageTelemetry to missionComputer.diagnosticInput;
        connect selfRepairSystem.repairStatus to missionComputer.diagnosticInput;

        perform action ExecutePrimaryMission;
        exhibit state MechaOperationalState;
    }

    part def ArmoredCockpit {
        attribute internalVolume : Volume = 5.4 [m^3];
        attribute canopyArmor : ArmorRating = 280 [mmRHAe];
        attribute lifeSupportDuration : Time = 43200 [s];

        port pilotControls : PilotInterfacePort;
        port commandLink : CommandPort;
        port electricalInput : ElectricalPowerPort;

        part neuralAssistSeat : PilotSeat;
        part displaySystem : TacticalDisplay;
        part lifeSupport : LifeSupportUnit;
    }

    part def PilotSeat {
        attribute accelerationLimit : Acceleration = 58.8 [m/s^2];
        attribute biometricSamplingRate : Frequency = 200 [Hz];
    }

    part def TacticalDisplay {
        attribute displayCount : Integer = 6;
        attribute refreshRate : Frequency = 120 [Hz];
    }

    part def LifeSupportUnit {
        attribute oxygenReserveMass : Mass = 18 [kg];
        attribute carbonDioxideScrubRate : MassFlowRate = 0.0015 [kg/s];
    }

    part def CompactFusionReactor {
        attribute maximumThermalOutput : Power = 7200000 [W];
        attribute nominalElectricalOutput : Power = 2800000 [W];
        attribute fuelMass : Mass = 14 [kg];

        port electricalOutput : ElectricalPowerPort;
        port coolantInput : CoolantPort;

        exhibit state ReactorState;
    }

    part def HighVoltagePowerBus {
        attribute nominalVoltage : ElectricPotential = 2000 [V];
        attribute peakLoadCapacity : Power = 3500000 [W];
        attribute storageCapacity : Energy = 120000000 [J];

        port reactorInput : ElectricalPowerPort;
        port legPowerOutput : ElectricalPowerPort;
        port weaponPowerOutput : ElectricalPowerPort;
        port computingPowerOutput : ElectricalPowerPort;
        port sensorPowerOutput : ElectricalPowerPort;
        port utilityPowerOutput : ElectricalPowerPort;
        port coolantInput : CoolantPort;
    }

    part def ThermalManagementSystem {
        attribute heatRejectionCapacity : Power = 4100000 [W];
        attribute coolantInventory : Mass = 340 [kg];
        attribute radiatorArea : Area = 42 [m^2];

        port electricalInput : ElectricalPowerPort;
        port coolantOutput : CoolantPort;
    }

    part def ElectroHydraulicSystem {
        attribute nominalPressure : Pressure = 35000000 [Pa];
        attribute peakPressure : Pressure = 52000000 [Pa];
        attribute reservoirVolume : Volume = 0.85 [m^3];

        port electricalInput : ElectricalPowerPort;
        port hydraulicOutput : HydraulicPort;
    }

    part def ActuatedLeg {
        attribute strideLength : Length = 5.8 [m];
        attribute jointCount : Integer = 5;
        attribute peakGroundForce : Force = 920000 [N];

        port electricalInput : ElectricalPowerPort;
        port hydraulicInput : HydraulicPort;
        port motionCommand : CommandPort;

        part hipActuator : RotaryActuator;
        part kneeActuator : RotaryActuator;
        part ankleActuator : RotaryActuator;
        part footPad : StabilizedFootPad;
    }

    part def RotaryActuator {
        attribute peakTorque : Torque = 310000 [N*m];
        attribute angularRate : AngularVelocity = 2.6 [rad/s];
    }

    part def StabilizedFootPad {
        attribute contactArea : Area = 1.8 [m^2];
        attribute tractionCoefficient : Real = 0.82;
    }

    part def RotaryTorso {
        attribute yawRange : PlaneAngle = 6.283 [rad];
        attribute maximumYawRate : AngularVelocity = 1.4 [rad/s];

        port electricalInput : ElectricalPowerPort;
        port hydraulicInput : HydraulicPort;
        port motionCommand : CommandPort;
    }

    part def ManipulatorArm {
        attribute reach : Length = 6.1 [m];
        attribute liftCapacity : Mass = 8200 [kg];
        attribute fingerCount : Integer = 4;

        port electricalInput : ElectricalPowerPort;
        port hydraulicInput : HydraulicPort;
        port motionCommand : CommandPort;

        part shoulderActuator : RotaryActuator;
        part elbowActuator : RotaryActuator;
        part wristActuator : RotaryActuator;
        part endEffector : DexterousHand;
    }

    part def DexterousHand {
        attribute gripForce : Force = 185000 [N];
        attribute toolInterfaceDiameter : Length = 0.22 [m];
    }

    part def RailCannon {
        attribute muzzleEnergy : Energy = 32000000 [J];
        attribute caliber : Length = 0.08 [m];
        attribute magazineCapacity : Integer = 36;
        attribute sustainedRateOfFire : RoundsPerMinute = 18 [rpm];

        port electricalInput : ElectricalPowerPort;
        port coolantInput : CoolantPort;
        port fireCommand : CommandPort;
        port ammunitionFeed : AmmunitionPort;

        part capacitorBank : PulsePowerCapacitorBank;
        part acceleratorRails : ElectromagneticLauncher;
        part autoloader : AmmunitionAutoloader;
    }

    part def PulsePowerCapacitorBank {
        attribute storedEnergy : Energy = 64000000 [J];
        attribute rechargeTime : Time = 7 [s];
    }

    part def ElectromagneticLauncher {
        attribute railLength : Length = 6.4 [m];
        attribute launchEfficiency : Percent = 48 [%];
    }

    part def AmmunitionAutoloader {
        attribute reloadTime : Time = 3.2 [s];
        attribute jamProbability : Real = 0.003;
    }

    part def MissilePod {
        attribute tubeCount : Integer = 8;
        attribute missileMass : Mass = 42 [kg];
        attribute effectiveRange : Length = 8000 [m];

        port electricalInput : ElectricalPowerPort;
        port fireCommand : CommandPort;
    }

    part def MultiSpectrumSensorSuite {
        attribute radarRange : Length = 18000 [m];
        attribute lidarRange : Length = 6000 [m];
        attribute infraredRange : Length = 10000 [m];
        attribute trackCapacity : Integer = 128;

        port electricalInput : ElectricalPowerPort;
        port trackPort : SensorPort;

        part activeRadar : RadarArray;
        part lidar : LidarScanner;
        part infraredCamera : InfraredImager;
        part acousticArray : AcousticLocalizer;
    }

    part def RadarArray {
        attribute apertureArea : Area = 2.6 [m^2];
        attribute transmitPower : Power = 90000 [W];
    }

    part def LidarScanner {
        attribute scanRate : Frequency = 40 [Hz];
        attribute angularResolution : PlaneAngle = 0.00035 [rad];
    }

    part def InfraredImager {
        attribute detectorTemperature : Temperature = 80 [K];
        attribute frameRate : Frequency = 90 [Hz];
    }

    part def AcousticLocalizer {
        attribute microphoneCount : Integer = 32;
        attribute localizationError : PlaneAngle = 0.035 [rad];
    }

    part def MissionComputer {
        attribute computeThroughput : Real = 240 [TFLOPS];
        attribute controlLoopRate : Frequency = 500 [Hz];
        attribute cyberIntegrityScore : Percent = 97 [%];

        port electricalInput : ElectricalPowerPort;
        port pilotCommand : CommandPort;
        port sensorFusionInput : SensorPort;
        port fireControlOutput : CommandPort;
        port motionCommandOutput : CommandPort;
        port diagnosticInput : PilotInterfacePort;

        perform action FuseSensors;
        perform action StabilizeGait;
        perform action SelectEngagementSolution;
    }

    part def ModularArmorShell {
        attribute frontArmor : ArmorRating = 420 [mmRHAe];
        attribute sideArmor : ArmorRating = 260 [mmRHAe];
        attribute rearArmor : ArmorRating = 170 [mmRHAe];
        attribute replaceablePanelCount : Integer = 96;

        port damageTelemetry : PilotInterfacePort;
    }

    part def FieldRepairSystem {
        attribute spareActuatorMass : Mass = 620 [kg];
        attribute sealantVolume : Volume = 0.18 [m^3];
        attribute repairCoverage : Percent = 35 [%];

        port repairStatus : PilotInterfacePort;
    }

    action def ExecutePrimaryMission {
        in item pilotDirective : PilotInput;
        in item fusedTracks : SensorTrack;
        out item missionReport : DiagnosticReport;

        first start;
        then initializeMecha;
        then patrolAssignedArea;
        then detectAndClassifyThreats;
        then protectFriendlyAssets;
        then reportMissionStatus;
        then done;

        action initializeMecha;
        action patrolAssignedArea;
        action detectAndClassifyThreats;
        action protectFriendlyAssets;
        action reportMissionStatus;
    }

    action def FuseSensors {
        in item radarTrack : SensorTrack;
        in item lidarTrack : SensorTrack;
        in item infraredTrack : SensorTrack;
        out item fusedTrack : SensorTrack;
    }

    action def StabilizeGait {
        in item pilotInput : PilotInput;
        out item legCommand : CommandPacket;
        out item torsoCommand : CommandPacket;
    }

    action def SelectEngagementSolution {
        in item targetTrack : SensorTrack;
        in item pilotConsent : PilotInput;
        out item weaponCommand : CommandPacket;
    }

    state def MechaOperationalState {
        entry action runStartupDiagnostics;

        state PoweredDown;
        state Standby;
        state Walking;
        state CombatReady;
        state Engaging;
        state Damaged;
        state EmergencyShutdown;

        transition initial then PoweredDown;
        transition PoweredDown to Standby
            accept PowerOn
            do initializePowerBus;
        transition Standby to Walking
            accept MobilityCommand
            if allCriticalSystemsNominal;
        transition Walking to CombatReady
            accept ThreatDetected
            do raiseWeaponsAndHardenArmor;
        transition CombatReady to Engaging
            accept FireAuthorized
            if targetConfidenceAboveThreshold;
        transition Engaging to CombatReady
            accept EngagementComplete
            do reloadAndCoolWeapons;
        transition CombatReady to Walking
            accept AreaSecure;
        transition Walking to Damaged
            accept CriticalHit
            do isolateDamagedSubsystem;
        transition CombatReady to Damaged
            accept CriticalHit
            do isolateDamagedSubsystem;
        transition Engaging to Damaged
            accept CriticalHit
            do isolateDamagedSubsystem;
        transition Damaged to Standby
            accept FieldRepairComplete
            if minimumMobilityRestored;
        transition Damaged to EmergencyShutdown
            accept ReactorUnsafe;
        transition Standby to PoweredDown
            accept PowerOff
            do safeDischargeCapacitors;

        action runStartupDiagnostics;
        action initializePowerBus;
        action raiseWeaponsAndHardenArmor;
        action reloadAndCoolWeapons;
        action isolateDamagedSubsystem;
        action safeDischargeCapacitors;

        constraint allCriticalSystemsNominal {
            missionCapable == true
        }

        constraint targetConfidenceAboveThreshold {
            confidence >= 85 [%]
        }

        constraint minimumMobilityRestored {
            healthScore >= 60 [%]
        }
    }

    state def ReactorState {
        state Offline;
        state Starting;
        state StableOutput;
        state PeakOutput;
        state Scram;

        transition initial then Offline;
        transition Offline to Starting accept ReactorStart;
        transition Starting to StableOutput accept PlasmaStable;
        transition StableOutput to PeakOutput accept HighDemand;
        transition PeakOutput to StableOutput accept DemandReduced;
        transition StableOutput to Scram accept OverTemperature;
        transition PeakOutput to Scram accept OverTemperature;
        transition Scram to Offline accept ReactorSecured;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The mecha shall provide a piloted mobile armored platform that traverses difficult terrain, detects and classifies threats, protects friendly assets, and delivers precise controlled force under human authorization. */
        subject mecha : BattleMecha;

        require constraint {
            mecha.crewCount == 1
        }

        require constraint {
            mecha.maximumRoadSpeed >= 15 [m/s]
        }

        require constraint {
            mecha.endurance >= 18000 [s]
        }
    }

    requirement def MobilityRequirement {
        doc /* The mecha shall maintain stable bipedal locomotion while carrying full combat load over uneven terrain. */
        subject mecha : BattleMecha;

        require constraint {
            mecha.leftLeg.peakGroundForce >= 850000 [N] and
            mecha.rightLeg.peakGroundForce >= 850000 [N]
        }
    }

    requirement def ProtectionRequirement {
        doc /* The mecha shall protect the pilot and mission-critical subsystems from frontal ballistic threats equivalent to medium anti-armor fire. */
        subject mecha : BattleMecha;

        require constraint {
            mecha.armorProtection >= 400 [mmRHAe]
        }

        require constraint {
            mecha.cockpit.canopyArmor >= 250 [mmRHAe]
        }
    }

    requirement def SensingRequirement {
        doc /* The mecha shall detect, track, and classify ground and aerial contacts beyond direct visual range. */
        subject sensors : MultiSpectrumSensorSuite;

        require constraint {
            sensors.radarRange >= 15000 [m]
        }

        require constraint {
            sensors.trackCapacity >= 100
        }
    }

    requirement def EngagementRequirement {
        doc /* The mecha shall engage hardened targets using an electrically powered primary weapon only after positive pilot authorization. */
        subject weapon : RailCannon;

        require constraint {
            weapon.muzzleEnergy >= 30000000 [J]
        }

        require constraint {
            weapon.magazineCapacity >= 30
        }
    }

    requirement def ThermalRequirement {
        doc /* The mecha shall reject reactor, actuator, and weapon heat during sustained maneuver and limited combat engagement. */
        subject thermal : ThermalManagementSystem;

        require constraint {
            thermal.heatRejectionCapacity >= 4000000 [W]
        }
    }

    satisfy PrimaryFunctionRequirement by BattleMecha;
    satisfy MobilityRequirement by BattleMecha.leftLeg;
    satisfy MobilityRequirement by BattleMecha.rightLeg;
    satisfy ProtectionRequirement by BattleMecha.armorSystem;
    satisfy SensingRequirement by BattleMecha.sensorMast;
    satisfy EngagementRequirement by BattleMecha.primaryWeapon;
    satisfy ThermalRequirement by BattleMecha.thermalSystem;
}