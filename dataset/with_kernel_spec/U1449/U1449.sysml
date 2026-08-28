package MechaPlatform {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    // ---- Item definitions ----
    item def Energy;
    item def PilotCommand;
    item def SensorData;
    item def TargetData;
    item def Projectile;
    item def ControlSignal;

    // ---- Port definitions ----
    port def PowerPort {
        out item energy : Energy;
    }
    port def CommandPort {
        out item command : PilotCommand;
    }
    port def ControlPort {
        out item control : ControlSignal;
    }
    port def SensorDataPort {
        out item data : SensorData;
    }
    port def TargetPort {
        out item target : TargetData;
    }
    port def ProjectilePort {
        in item projectile : Projectile;
    }

    // ---- Action definitions ----
    action def GeneratePower {
        out item generatedEnergy : Energy;
        first start;
        then action produceFusionReaction;
        then action convertToElectricity;
        then done;
    }
    action def ProcessPilotCommand {
        in item command : PilotCommand;
        out item weaponCmd : TargetData;
        out item locomotionCmd : ControlSignal;
        out item defenseCmd : ControlSignal;
        first start;
        then action interpretCommand;
        then action dispatchCommands;
        then done;
    }
    action def ProcessSensorData {
        in item rawData : SensorData;
        out item threatAssessment : SensorData;
        first start;
        then action filterNoise;
        then action identifyThreats;
        then done;
    }
    action def Walk {
        in speed : Real;
        first start;
        then action coordinateLegs;
        then action maintainBalance;
        then done;
    }
    action def Run {
        in speed : Real;
        first start;
        then action rapidLegCycle;
        then action stabilizeGyro;
        then done;
    }
    action def ScanEnvironment {
        out item detectedObjects : SensorData;
        first start;
        then action activateRadar;
        then action activateThermal;
        then action activateOptical;
        then action fuseData;
        then done;
    }
    action def EngageTarget {
        in item target : TargetData;
        first start;
        then action acquireLock;
        then action fireWeapon;
        then done;
    }
    action def DefendAgainstThreat {
        in item threat : Projectile;
        first start;
        then action energizeShield;
        then action interceptThreat;
        then done;
    }

    // ---- Subsystem part definitions ----
    part def FusionReactor {
        attribute maxOutput : Real = 5000.0; // kW
        port powerOutPort : PowerPort;
        perform action generatePower : GeneratePower {
            out generatedEnergy = powerOutPort.energy;
        }
    }

    part def BatterySystem {
        attribute capacity : Real = 10000.0; // kJ
        attribute currentCharge : Real = 0.0; // kJ
        port powerInPort : ~PowerPort;
        port powerOutPort : PowerPort;
        perform action charge;
        perform action discharge;
    }

    part def ControlComputer {
        port commandInPort : ~CommandPort;
        port sensorInPort : ~SensorDataPort;
        port powerInPort : ~PowerPort;
        port weaponControlPort : TargetPort;
        port locomotionControlPort : ControlPort;
        port defenseControlPort : ControlPort;
        perform action processPilotCommand : ProcessPilotCommand;
        perform action processSensorData : ProcessSensorData;
    }

    part def Cockpit {
        port commandOutPort : CommandPort;
        attribute isPressurized : Boolean = true;
        attribute oxygenLevel : Real; // percentage
        attribute internalPressure : Real; // kPa
        perform action pilotInput;
    }

    part def Leg {
        attribute hipAngle : Real; // degrees
        attribute kneeAngle : Real; // degrees
        attribute ankleAngle : Real; // degrees
        port controlInPort : ~ControlPort;
        port powerInPort : ~PowerPort;
        perform action actuate;
    }

    part def Gyroscope {
        attribute spinRate : Real; // Hz
        port controlInPort : ~ControlPort;
        perform action stabilize;
    }

    part def BipedalLocomotionSystem {
        part leftLeg : Leg;
        part rightLeg : Leg;
        part gyroscopicStabilizer : Gyroscope;
        port controlInPort : ~ControlPort;
        port powerInPort : ~PowerPort;
        perform action walk : Walk;
        perform action run : Run;
    }

    part def Radar {
        attribute maxRange : Real = 10000.0; // meters
        port powerInPort : ~PowerPort;
        port dataOutPort : SensorDataPort;
        perform action detect;
    }

    part def ThermalImager {
        port powerInPort : ~PowerPort;
        port dataOutPort : SensorDataPort;
        perform action detectHeatSignatures;
    }

    part def OpticalSensor {
        attribute zoomLevel : Real;
        port powerInPort : ~PowerPort;
        port dataOutPort : SensorDataPort;
        perform action captureImage;
    }

    part def SensorArray {
        part radar : Radar;
        part thermalImager : ThermalImager;
        part opticalSensor : OpticalSensor;
        port powerInPort : ~PowerPort;
        port dataOutPort : SensorDataPort;
        perform action scan : ScanEnvironment;
    }

    part def Autocannon {
        attribute fireRate : Real = 600.0; // rounds per minute
        attribute caliber : Real = 30.0; // mm
        port powerInPort : ~PowerPort;
        port targetInPort : ~TargetPort;
        perform action fire;
    }

    part def MissileLauncher {
        attribute missileCount : Integer = 12;
        port powerInPort : ~PowerPort;
        port targetInPort : ~TargetPort;
        perform action launch;
    }

    part def EnergyWeapon {
        attribute powerDraw : Real = 2000.0; // kW
        port powerInPort : ~PowerPort;
        port targetInPort : ~TargetPort;
        perform action fire;
    }

    part def WeaponSystem {
        part autocannon : Autocannon;
        part missileLauncher : MissileLauncher;
        part energyWeapon : EnergyWeapon;
        port powerInPort : ~PowerPort;
        port targetInPort : ~TargetPort;
        perform action engageTarget : EngageTarget;
    }

    part def EnergyShield {
        attribute maxStrength : Real = 1000.0; // shield units
        attribute currentStrength : Real = 1000.0;
        port powerInPort : ~PowerPort;
        perform action recharge;
        perform action absorbDamage;
    }

    part def CompositeArmor {
        attribute thickness : Real = 150.0; // mm
        perform action absorbDamage;
    }

    part def ActiveDefenseSystem {
        attribute interceptRange : Real = 500.0; // meters
        port powerInPort : ~PowerPort;
        port projectileInPort : ProjectilePort;
        perform action intercept;
    }

    part def DefenseSystem {
        part energyShield : EnergyShield;
        part compositeArmor : CompositeArmor;
        part activeDefenseSystem : ActiveDefenseSystem;
        port powerInPort : ~PowerPort;
        port defenseControlPort : ~ControlPort;
        perform action defend : DefendAgainstThreat;
    }

    // ---- Main Mecha part definition ----
    part def Mecha {
        attribute maxSpeed : Real; // km/h
        attribute operationalRange : Real; // km
        attribute combatWeight : Real; // tonnes

        part fusionReactor : FusionReactor;
        part batterySystem : BatterySystem;
        part controlComputer : ControlComputer;
        part cockpit : Cockpit;
        part locomotionSystem : BipedalLocomotionSystem;
        part sensorArray : SensorArray;
        part weaponSystem : WeaponSystem;
        part defenseSystem : DefenseSystem;

        // Power distribution
        connect fusionReactor.powerOutPort to batterySystem.powerInPort;
        connect batterySystem.powerOutPort to controlComputer.powerInPort;
        connect batterySystem.powerOutPort to locomotionSystem.powerInPort;
        connect batterySystem.powerOutPort to sensorArray.powerInPort;
        connect batterySystem.powerOutPort to weaponSystem.powerInPort;
        connect batterySystem.powerOutPort to defenseSystem.powerInPort;

        // Command and data flow
        connect cockpit.commandOutPort to controlComputer.commandInPort;
        connect sensorArray.dataOutPort to controlComputer.sensorInPort;
        connect controlComputer.weaponControlPort to weaponSystem.targetInPort;
        connect controlComputer.locomotionControlPort to locomotionSystem.controlInPort;
        connect controlComputer.defenseControlPort to defenseSystem.defenseControlPort;

        // Operational state machine
        state mechaStates {
            in mecha : Mecha;
            entry;
            then Standby;

            state Standby {
                doc /* Mecha is powered on but idle; all systems in low-power mode awaiting deployment. */
            }
            state Patrol {
                doc /* Mecha is moving through designated zones; sensors at nominal power, weapons on standby. */
            }
            state Combat {
                doc /* Mecha is actively engaging hostile forces; all systems at full power, shield at maximum. */
            }
            state Retreat {
                doc /* Mecha is disengaging from superior hostiles; power diverted to locomotion and defense. */
            }
            state Maintenance {
                doc /* Mecha is undergoing repairs, resupply, and diagnostics; systems offline. */
            }

            transition standby_to_patrol
                first Standby
                accept patrolCommand : PilotCommand via mecha.controlComputer.commandInPort
                then Patrol;
            transition patrol_to_combat
                first Patrol
                accept threatDetected : SensorData via mecha.sensorArray.dataOutPort
                then Combat;
            transition combat_to_retreat
                first Combat
                accept retreatCommand : PilotCommand via mecha.controlComputer.commandInPort
                then Retreat;
            transition retreat_to_standby
                first Retreat
                accept holdCommand : PilotCommand via mecha.controlComputer.commandInPort
                then Standby;
            transition standby_to_maintenance
                first Standby
                accept maintenanceCommand : PilotCommand via mecha.controlComputer.commandInPort
                then Maintenance;
            transition maintenance_to_standby
                first Maintenance
                accept restartCommand : PilotCommand via mecha.controlComputer.commandInPort
                then Standby;
        }
    }

    // ---- Requirements ----
    requirement def MechaOperationalRequirement {
        doc /* The Mecha shall operate in standby, patrol, combat, retreat, and maintenance modes,
               adapting power consumption and subsystem activation to the current tactical situation. */
        subject mecha : Mecha;
    }
    requirement def MechaPowerRequirement {
        doc /* The fusion reactor shall provide at least 5000 kW of continuous power,
               supplemented by a battery system for peak load management. */
        subject mecha : Mecha;
        attribute minPower : Real = 5000.0;
        constraint { mecha.fusionReactor.maxOutput >= minPower }
    }
    requirement def MechaShieldRequirement {
        doc /* The energy shield shall withstand at least 1000 units of damage before depletion,
               backed by composite armor and an active defense system for layered protection. */
        subject mecha : Mecha;
        attribute minShield : Real = 1000.0;
        constraint { mecha.defenseSystem.energyShield.maxStrength >= minShield }
    }
    requirement def MechaSensorRangeRequirement {
        doc /* The radar shall detect targets at a range of at least 10 km for initial threat identification. */
        subject mecha : Mecha;
        attribute minRange : Real = 10000.0;
        constraint { mecha.sensorArray.radar.maxRange >= minRange }
    }
    requirement def MechaSurvivabilityRequirement {
        doc /* The Mecha shall employ layered defenses—energy shield, composite armor, and active defense—
               to ensure pilot safety and platform survivability under hostile fire. */
        subject mecha : Mecha;
    }
    requirement def MechaMobilityRequirement {
        doc /* The bipedal locomotion system shall maintain balance during walking and running
               using gyroscopic stabilization across all terrain conditions. */
        subject mecha : Mecha;
    }
    requirement def MechaCockpitRequirement {
        doc /* The cockpit shall be pressurized and life-supported to protect the pilot
               during all operational modes including combat and retreat. */
        subject mecha : Mecha;
        constraint { mecha.cockpit.isPressurized == true }
    }

    // ---- Context usage ----
    part context {
        part operationalMecha : Mecha {
            :>> maxSpeed = 80.0;
            :>> operationalRange = 500.0;
            :>> combatWeight = 45.0;
        }
    }
}
