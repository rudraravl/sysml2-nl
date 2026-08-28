package Mecha {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value type Power :> Real;
    value type Energy :> Real;
    value type Mass :> Real;
    value type Length :> Real;
    value type Velocity :> Real;
    value type AngularVelocity :> Real;
    value type Temperature :> Real;
    value type Pressure :> Real;
    value type Frequency :> Real;
    value type Time :> Real;
    value type Percentage :> Real;
    value type Angle :> Real;
    value type Distance :> Real;

    // ===== Item Definitions =====
    item def ElectricalEnergy;
    item def SensorData;
    item def ControlCommand;
    item def PilotCommand;

    // ===== Port Definitions =====
    port def PowerOut {
        out item energy : ElectricalEnergy;
    }
    port def PowerIn {
        in item energy : ElectricalEnergy;
    }
    port def PowerBidir {
        in item energyIn : ElectricalEnergy;
        out item energyOut : ElectricalEnergy;
    }
    port def SensorDataOut {
        out item report : SensorData;
    }
    port def SensorDataIn {
        in item report : SensorData;
    }
    port def CommandOut {
        out item cmd : ControlCommand;
    }
    port def CommandIn {
        in item cmd : ControlCommand;
    }
    port def PilotCmdOut {
        out item pilotCmd : PilotCommand;
    }
    port def PilotCmdIn {
        in item pilotCmd : PilotCommand;
    }

    // ===== Part Definitions: Power Subsystem =====
    part def FusionReactor {
        attribute ratedPower : Power = 50000.0;
        attribute fuelLevel : Percentage = 100.0;
        attribute operatingTemp : Temperature = 1500.0;
        attribute status : String = "online";
        port powerOut : PowerOut;
    }

    part def BatterySystem {
        attribute capacity : Energy = 20000.0;
        attribute chargeLevel : Percentage = 100.0;
        attribute maxDischargeRate : Power = 30000.0;
        port powerPort : PowerBidir;
    }

    // ===== Part Definitions: Control Subsystem =====
    part def ControlComputer {
        attribute cpuLoad : Percentage = 0.0;
        attribute status : String = "operational";
        port powerIn : PowerIn;
        port sensorInput : SensorDataIn;
        port pilotInput : PilotCmdIn;
        port commandOutput : CommandOut;
    }

    // ===== Part Definitions: Cockpit & Pilot =====
    part def LifeSupportSystem {
        attribute oxygenLevel : Percentage = 100.0;
        attribute co2Level : Percentage = 0.04;
        attribute airFilterStatus : String = "clean";
        port powerIn : PowerIn;
    }

    part def Pilot {
        attribute callsign : String = "Pilot-01";
        attribute healthStatus : Percentage = 100.0;
        port pilotOutput : PilotCmdOut;
    }

    part def Cockpit {
        attribute internalPressure : Pressure = 101.3;
        attribute internalTemp : Temperature = 293.0;
        attribute sealIntegrity : Percentage = 100.0;
        part lifeSupport : LifeSupportSystem;
        part pilot : Pilot;
        port powerIn : PowerIn;
        port pilotOutput : PilotCmdOut;
        connect powerIn to lifeSupport.powerIn;
        connect pilot.pilotOutput to pilotOutput;
    }

    // ===== Part Definitions: Locomotion Subsystem =====
    part def Joint {
        attribute jointType : String;
        attribute maxAngle : Angle;
        attribute currentAngle : Angle = 0.0;
        attribute torque : Power = 0.0;
        port powerIn : PowerIn;
        port cmdIn : CommandIn;
    }

    part def Leg {
        attribute legId : String;
        part hip : Joint {
            :>> jointType = "hip";
            :>> maxAngle = 90.0;
        }
        part knee : Joint {
            :>> jointType = "knee";
            :>> maxAngle = 150.0;
        }
        part ankle : Joint {
            :>> jointType = "ankle";
            :>> maxAngle = 45.0;
        }
        port powerIn : PowerIn;
        port cmdIn : CommandIn;
        connect powerIn to hip.powerIn;
        connect powerIn to knee.powerIn;
        connect powerIn to ankle.powerIn;
        connect cmdIn to hip.cmdIn;
        connect cmdIn to knee.cmdIn;
        connect cmdIn to ankle.cmdIn;
    }

    part def GyroscopicStabilizer {
        attribute spinRate : AngularVelocity = 12000.0;
        attribute stabilityMargin : Percentage = 100.0;
        port powerIn : PowerIn;
        port cmdIn : CommandIn;
    }

    part def LocomotionSystem {
        attribute maxSpeed : Velocity = 16.7;
        attribute currentSpeed : Velocity = 0.0;
        attribute strideLength : Length = 3.5;
        part leftLeg : Leg {
            :>> legId = "L";
        }
        part rightLeg : Leg {
            :>> legId = "R";
        }
        part gyro : GyroscopicStabilizer;
        port powerIn : PowerIn;
        port cmdIn : CommandIn;
        connect powerIn to leftLeg.powerIn;
        connect powerIn to rightLeg.powerIn;
        connect powerIn to gyro.powerIn;
        connect cmdIn to leftLeg.cmdIn;
        connect cmdIn to rightLeg.cmdIn;
        connect cmdIn to gyro.cmdIn;
    }

    // ===== Part Definitions: Sensor Subsystem =====
    part def RadarSensor {
        attribute maxRange : Distance = 50.0;
        attribute frequency : Frequency = 9400.0;
        attribute resolution : Length = 0.5;
        port powerIn : PowerIn;
        port dataOut : SensorDataOut;
    }

    part def ThermalImager {
        attribute maxRange : Distance = 15.0;
        attribute minDetectTemp : Temperature = 280.0;
        attribute sensitivity : Temperature = 0.1;
        port powerIn : PowerIn;
        port dataOut : SensorDataOut;
    }

    part def OpticalSensor {
        attribute maxRange : Distance = 10.0;
        attribute resolution : Length = 0.001;
        attribute zoomFactor : Real = 20.0;
        port powerIn : PowerIn;
        port dataOut : SensorDataOut;
    }

    part def SensorArray {
        part radar : RadarSensor;
        part thermal : ThermalImager;
        part optical : OpticalSensor;
        port powerIn : PowerIn;
        port dataOut : SensorDataOut;
        connect powerIn to radar.powerIn;
        connect powerIn to thermal.powerIn;
        connect powerIn to optical.powerIn;
        connect radar.dataOut to dataOut;
        connect thermal.dataOut to dataOut;
        connect optical.dataOut to dataOut;
    }

    // ===== Part Definitions: Weapon Subsystem =====
    part def Autocannon {
        attribute fireRate : Frequency = 10.0;
        attribute ammoCount : Integer = 500;
        attribute maxRange : Distance = 5.0;
        attribute caliber : Length = 0.05;
        port powerIn : PowerIn;
        port cmdIn : CommandIn;
    }

    part def MissileLauncher {
        attribute missileCount : Integer = 12;
        attribute maxRange : Distance = 30.0;
        attribute lockTime : Time = 2.0;
        port powerIn : PowerIn;
        port cmdIn : CommandIn;
    }

    part def EnergyWeapon {
        attribute damageRating : Power = 25000.0;
        attribute range : Distance = 8.0;
        attribute chargeTime : Time = 3.0;
        port powerIn : PowerIn;
        port cmdIn : CommandIn;
    }

    part def WeaponSystem {
        part autocannon : Autocannon;
        part missileLauncher : MissileLauncher;
        part energyWeapon : EnergyWeapon;
        port powerIn : PowerIn;
        port cmdIn : CommandIn;
        connect powerIn to autocannon.powerIn;
        connect powerIn to missileLauncher.powerIn;
        connect powerIn to energyWeapon.powerIn;
        connect cmdIn to autocannon.cmdIn;
        connect cmdIn to missileLauncher.cmdIn;
        connect cmdIn to energyWeapon.cmdIn;
    }

    // ===== Part Definitions: Defense Subsystem =====
    part def EnergyShield {
        attribute shieldStrength : Percentage = 100.0;
        attribute rechargeRate : Power = 5000.0;
        attribute coverage : Percentage = 95.0;
        port powerIn : PowerIn;
        port cmdIn : CommandIn;
    }

    part def CompositeArmor {
        attribute thickness : Length = 0.5;
        attribute integrity : Percentage = 100.0;
        attribute materialType : String = "composite";
    }

    part def ActiveDefenseSystem {
        attribute interceptorCount : Integer = 20;
        attribute reactionTime : Time = 0.01;
        attribute range : Distance = 2.0;
        port powerIn : PowerIn;
        port cmdIn : CommandIn;
    }

    part def DefenseSystem {
        part shield : EnergyShield;
        part armor : CompositeArmor;
        part activeDefense : ActiveDefenseSystem;
        port powerIn : PowerIn;
        port cmdIn : CommandIn;
        connect powerIn to shield.powerIn;
        connect powerIn to activeDefense.powerIn;
        connect cmdIn to shield.cmdIn;
        connect cmdIn to activeDefense.cmdIn;
    }

    // ===== Mecha Platform Definition =====
    part def MechaPlatform {
        attribute designation : String = "Mecha-01";
        attribute totalMass : Mass = 45.0;
        attribute height : Length = 12.0;
        attribute powerLevel : Percentage = 10.0;
        attribute threatDetected : Boolean = false;
        attribute threatNeutralized : Boolean = false;
        attribute safeDistance : Boolean = false;
        attribute maintenanceRequested : Boolean = false;
        attribute maintenanceComplete : Boolean = false;
        attribute patrolCommandReceived : Boolean = false;

        part reactor : FusionReactor;
        part battery : BatterySystem;
        part computer : ControlComputer;
        part cockpit : Cockpit;
        part locomotion : LocomotionSystem;
        part sensorArray : SensorArray;
        part weapons : WeaponSystem;
        part defense : DefenseSystem;

        // Power distribution from reactor
        connect reactor.powerOut to battery.powerPort;
        connect reactor.powerOut to computer.powerIn;
        connect reactor.powerOut to sensorArray.powerIn;
        connect reactor.powerOut to locomotion.powerIn;
        connect reactor.powerOut to weapons.powerIn;
        connect reactor.powerOut to defense.powerIn;
        connect reactor.powerOut to cockpit.powerIn;

        // Peak power supplementation from battery
        connect battery.powerPort to computer.powerIn;
        connect battery.powerPort to locomotion.powerIn;
        connect battery.powerPort to weapons.powerIn;
        connect battery.powerPort to defense.powerIn;

        // Data flow: sensors to computer
        connect sensorArray.dataOut to computer.sensorInput;

        // Pilot commands to computer
        connect cockpit.pilotOutput to computer.pilotInput;

        // Command distribution to subsystems
        connect computer.commandOutput to locomotion.cmdIn;
        connect computer.commandOutput to weapons.cmdIn;
        connect computer.commandOutput to defense.cmdIn;

        // Operational state machine
        state machine operationStates {
            state standby {
                entry { powerLevel = 10.0; }
            }
            state patrol {
                entry { powerLevel = 40.0; }
            }
            state combat {
                entry { powerLevel = 90.0; }
            }
            state retreat {
                entry { powerLevel = 80.0; }
            }
            state maintenance {
                entry { powerLevel = 5.0; }
            }

            transition initial -> standby;
            transition standby -> patrol [patrolCommandReceived];
            transition patrol -> combat [threatDetected];
            transition combat -> retreat [defense.shield.shieldStrength < 20.0];
            transition combat -> patrol [threatNeutralized];
            transition retreat -> patrol [safeDistance];
            transition standby -> maintenance [maintenanceRequested];
            transition maintenance -> standby [maintenanceComplete];
        }
    }

    // ===== Requirements =====
    requirement def MechaRequirement {
        subject platform : MechaPlatform;
    }

    requirement CombatCapabilityReq :> MechaRequirement {
        doc /* The Mecha must engage and neutralize hostile forces. */
        constraint { platform.weapons.autocannon.fireRate >= 5.0; }
        constraint { platform.weapons.missileLauncher.missileCount >= 8; }
        constraint { platform.weapons.energyWeapon.damageRating >= 20000.0; }
    }

    requirement OperatorSafetyReq :> MechaRequirement {
        doc /* The Mecha must ensure the safety of its operator. */
        constraint { platform.cockpit.internalPressure >= 80.0; }
        constraint { platform.cockpit.internalTemp >= 273.0; }
        constraint { platform.defense.armor.thickness >= 0.3; }
        constraint { platform.cockpit.sealIntegrity >= 90.0; }
    }

    requirement PowerGenerationReq :> MechaRequirement {
        doc /* Central fusion reactor provides energy for all systems. */
        constraint { platform.reactor.ratedPower >= 50000.0; }
        constraint { platform.battery.capacity >= 20000.0; }
    }

    requirement LocomotionReq :> MechaRequirement {
        doc /* Bipedal locomotion with gyroscopic stabilization. */
        constraint { platform.locomotion.maxSpeed >= 10.0; }
        constraint { platform.locomotion.gyro.spinRate >= 10000.0; }
    }

    requirement SensingReq :> MechaRequirement {
        doc /* Comprehensive sensor array for environment perception. */
        constraint { platform.sensorArray.radar.maxRange >= 30.0; }
        constraint { platform.sensorArray.thermal.maxRange >= 10.0; }
        constraint { platform.sensorArray.optical.maxRange >= 5.0; }
    }

    requirement DefenseReq :> MechaRequirement {
        doc /* Layered defense: energy shield, composite armor, active defense. */
        constraint { platform.defense.shield.shieldStrength >= 80.0; }
        constraint { platform.defense.activeDefense.interceptorCount >= 10; }
        constraint { platform.defense.armor.integrity >= 90.0; }
    }

    requirement OperationalModesReq :> MechaRequirement {
        doc /* Multiple operational modes: standby, patrol, combat, retreat, maintenance. */
        constraint { platform.powerLevel >= 0.0; }
        constraint { platform.powerLevel <= 100.0; }
    }

    // ===== Instance =====
    part mechaUnit : MechaPlatform {
        :>> designation = "Mecha-A1";
    }
}
