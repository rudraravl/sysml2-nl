package MechaWarriorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def PowerValue :> Real;
    attribute def EnergyValue :> Real;
    attribute def VelocityValue :> Real;
    attribute def TorqueValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def RangeValue :> Real;

    enum def OperationalMode {
        standby;
        patrol;
        combat;
        retreat;
        maintenance;
    }

    enum def WeaponState {
        safe;
        armed;
        firing;
        reloading;
        malfunction;
    }

    enum def ThreatLevel {
        none;
        low;
        medium;
        high;
        critical;
    }

    item def TargetData {
        attribute targetID : String;
        attribute range : RangeValue;
        attribute bearing : Real;
        attribute velocity : VelocityValue;
        attribute threat : ThreatLevel;
    }

    item def PilotCommand {
        attribute commandType : String;
        attribute targetID : String;
        attribute priority : Integer;
    }

    item def TelemetryData {
        attribute timestamp : Real;
        attribute position : RangeValue[3];
        attribute velocity : VelocityValue;
        attribute systemStatus : String;
    }

    port def PowerBus {
        attribute voltage : Real;
        attribute current : Real;
        attribute powerFlow : PowerValue;
    }

    port def DataBus {
        attribute telemetry : TelemetryData;
        attribute commands : PilotCommand;
        attribute targets : TargetData;
    }

    port def MechanicalInterface {
        attribute torque : TorqueValue;
        attribute angularVelocity : Real;
    }

    part def FusionReactor {
        attribute maxPowerOutput : PowerValue;
        attribute currentOutput : PowerValue;
        attribute coreTemperature : TemperatureValue;
        attribute fuelRemaining : Real;
        
        port powerOut : PowerBus;
        
        assert constraint safeOperation {
            coreTemperature <= 15000000.0
        }
    }

    part def EnergyStorage {
        attribute capacity : EnergyValue;
        attribute currentCharge : EnergyValue;
        attribute chargeRate : PowerValue;
        attribute dischargeRate : PowerValue;
        
        port powerIn : PowerBus;
        port powerOut : PowerBus;
    }

    part def Cockpit {
        attribute pressurized : Boolean;
        attribute lifeSupportActive : Boolean;
        attribute oxygenLevel : Real;
        
        port pilotInterface : DataBus;
        port powerIn : PowerBus;
    }

    part def SensorArray {
        attribute radarRange : RangeValue;
        attribute thermalSensitivity : TemperatureValue;
        attribute opticalResolution : Real;
        attribute activeScanning : Boolean;
        
        port sensorData : DataBus;
        port powerIn : PowerBus;
        
        part radarSystem {
            attribute scanRadius : RangeValue;
            attribute updateRate : Real;
        }
        
        part thermalImager {
            attribute detectionRange : RangeValue;
            attribute minDetectableTemp : TemperatureValue;
        }
        
        part opticalSensors {
            attribute fieldOfView : Real;
            attribute zoomFactor : Real;
        }
    }

    part def LocomotionSystem {
        attribute maxWalkSpeed : VelocityValue;
        attribute maxRunSpeed : VelocityValue;
        attribute currentSpeed : VelocityValue;
        attribute stabilityFactor : Real;
        
        port powerIn : PowerBus;
        port controlData : DataBus;
        port groundContact : MechanicalInterface;
        
        part leftLeg {
            attribute hipTorque : TorqueValue;
            attribute kneeTorque : TorqueValue;
            attribute ankleTorque : TorqueValue;
            
            part hipActuator {
                attribute maxTorque : TorqueValue;
            }
            part kneeActuator {
                attribute maxTorque : TorqueValue;
            }
            part ankleActuator {
                attribute maxTorque : TorqueValue;
            }
        }
        
        part rightLeg {
            attribute hipTorque : TorqueValue;
            attribute kneeTorque : TorqueValue;
            attribute ankleTorque : TorqueValue;
            
            part hipActuator {
                attribute maxTorque : TorqueValue;
            }
            part kneeActuator {
                attribute maxTorque : TorqueValue;
            }
            part ankleActuator {
                attribute maxTorque : TorqueValue;
            }
        }
        
        part gyroStabilizer {
            attribute stabilizationTorque : TorqueValue;
            attribute responseTime : Real;
        }
    }

    part def WeaponSystem {
        attribute weaponState : WeaponState;
        attribute ammunition : Integer;
        attribute maxAmmunition : Integer;
        attribute effectiveRange : RangeValue;
        attribute fireRate : Real;
        
        port powerIn : PowerBus;
        port targetingData : DataBus;
        port fireControl : DataBus;
        
        part autocannon {
            attribute caliber : Real;
            attribute muzzleVelocity : VelocityValue;
            attribute roundsRemaining : Integer;
        }
        
        part missileLauncher {
            attribute missileCount : Integer;
            attribute lockOnTime : Real;
            attribute guidanceActive : Boolean;
        }
        
        part energyWeapon {
            attribute beamPower : PowerValue;
            attribute capacitorCharge : EnergyValue;
            attribute coolingRate : Real;
        }
    }

    part def DefenseSystem {
        attribute armorIntegrity : Real;
        attribute shieldStrength : Real;
        attribute shieldRegenRate : Real;
        attribute damageAbsorbed : Real;
        
        port powerIn : PowerBus;
        port damageMonitor : DataBus;
        
        part energyShield {
            attribute maxCapacity : EnergyValue;
            attribute currentCapacity : EnergyValue;
            attribute rechargeRate : PowerValue;
        }
        
        part compositeArmor {
            attribute thickness : RangeValue;
            attribute integrityPercent : Real;
            attribute ablativeLayer : Boolean;
        }
        
        part activeDefense {
            attribute interceptorCount : Integer;
            attribute reactionTime : Real;
        }
    }

    part def ControlComputer {
        attribute processingPower : Real;
        attribute memoryCapacity : Real;
        attribute currentMode : OperationalMode;
        attribute systemHealth : Real;
        
        port commandBus : DataBus;
        port sensorBus : DataBus;
        port weaponBus : DataBus;
        port powerIn : PowerBus;
    }

    part def Mecha {
        doc /* A bipedal combat platform designed for tactical battlefield superiority 
             * through integrated weapons, sensors, and mobility systems. Primary function
             * is to engage and neutralize hostile forces while maintaining pilot safety. */
        
        attribute totalMass : MassValue;
        attribute height : RangeValue;
        attribute operationalMode : OperationalMode;
        attribute missionTime : Real;
        
        part reactor : FusionReactor {
            attribute :>> maxPowerOutput = 25000000.0;
            attribute :>> currentOutput = 15000000.0;
            attribute :>> coreTemperature = 12000000.0;
            attribute :>> fuelRemaining = 85.0;
        }
        
        part batteries : EnergyStorage {
            attribute :>> capacity = 500000000.0;
            attribute :>> currentCharge = 450000000.0;
            attribute :>> chargeRate = 5000000.0;
            attribute :>> dischargeRate = 8000000.0;
        }
        
        part cockpit : Cockpit {
            attribute :>> pressurized = true;
            attribute :>> lifeSupportActive = true;
            attribute :>> oxygenLevel = 98.5;
        }
        
        part sensors : SensorArray {
            attribute :>> radarRange = 50000.0;
            attribute :>> thermalSensitivity = 0.1;
            attribute :>> opticalResolution = 2.5;
            attribute :>> activeScanning = true;
        }
        
        part locomotion : LocomotionSystem {
            attribute :>> maxWalkSpeed = 25.0;
            attribute :>> maxRunSpeed = 65.0;
            attribute :>> currentSpeed = 0.0;
            attribute :>> stabilityFactor = 0.95;
        }
        
        part weapons : WeaponSystem {
            attribute :>> weaponState = WeaponState::armed;
            attribute :>> ammunition = 2000;
            attribute :>> maxAmmunition = 2000;
            attribute :>> effectiveRange = 3000.0;
            attribute :>> fireRate = 600.0;
        }
        
        part defense : DefenseSystem {
            attribute :>> armorIntegrity = 100.0;
            attribute :>> shieldStrength = 85.0;
            attribute :>> shieldRegenRate = 5.0;
            attribute :>> damageAbsorbed = 0.0;
        }
        
        part controller : ControlComputer {
            attribute :>> processingPower = 1000.0;
            attribute :>> memoryCapacity = 10000.0;
            attribute :>> currentMode = OperationalMode::standby;
            attribute :>> systemHealth = 100.0;
        }
        
        connection reactorToBatteries connect reactor.powerOut to batteries.powerIn;
        connection batteriesToController connect batteries.powerOut to controller.powerIn;
        connection batteriesToCockpit connect batteries.powerOut to cockpit.powerIn;
        connection batteriesToSensors connect batteries.powerOut to sensors.powerIn;
        connection batteriesToLocomotion connect batteries.powerOut to locomotion.powerIn;
        connection batteriesToWeapons connect batteries.powerOut to weapons.powerIn;
        connection batteriesToDefense connect batteries.powerOut to defense.powerIn;
        
        connection cockpitToController connect cockpit.pilotInterface to controller.commandBus;
        connection sensorsToController connect sensors.sensorData to controller.sensorBus;
        connection controllerToWeapons connect controller.weaponBus to weapons.fireControl;
        connection sensorsToWeapons connect sensors.sensorData to weapons.targetingData;
        connection controllerToLocomotion connect controller.commandBus to locomotion.controlData;
        connection defenseToController connect defense.damageMonitor to controller.commandBus;
        
        assert constraint massLimit {
            totalMass <= 75000.0 [kg]
        }
        
        assert constraint powerBalance {
            reactor.currentOutput + batteries.dischargeRate >= 2000000.0
        }
    }

    action def InitializeSystems {
        in powerAvailable : Real;
        out systemsOnline : Boolean;
    }

    action def ScanEnvironment {
        in scanRange : Real;
        in scanMode : String;
        out targetsDetected : Integer;
        out targetList : TargetData[0..*];
    }

    action def NavigateToPosition {
        in destination : Real[3];
        in speed : Real;
        out positionReached : Boolean;
    }

    action def AcquireTarget {
        in targetData : TargetData;
        out lockAchieved : Boolean;
        out trackingActive : Boolean;
    }

    action def EngageHostile {
        in target : TargetData;
        in weaponSelection : String;
        out engagementSuccess : Boolean;
        out ammunitionExpended : Integer;
    }

    action def ActivateDefenses {
        in threatLevel : ThreatLevel;
        in incomingFire : Boolean;
        out shieldsActive : Boolean;
        out countermeasuresDeployed : Boolean;
    }

    action def AssessDamage {
        in damageReport : Real;
        out systemsOperational : Boolean;
        out repairRequired : Boolean;
    }

    action def CombatMission {
        doc /* Primary combat mission workflow integrating reconnaissance, 
             * engagement, and tactical maneuvering. */
        
        first start;
        then action initialize : InitializeSystems {
            in powerAvailable = 25000000.0;
        }
        then merge missionLoop;
        
        then action missionLoop {
            first action scan : ScanEnvironment {
                in scanRange = 50000.0;
                in scanMode = "active";
            }
            then decide;
                if scan.targetsDetected > 0 then engagementSequence;
                if scan.targetsDetected == 0 then continuePatrol;
            
            then action engagementSequence {
                first action activateDefense : ActivateDefenses {
                    in threatLevel = ThreatLevel::high;
                    in incomingFire = true;
                }
                then action acquireTarget : AcquireTarget;
                then action navigate : NavigateToPosition {
                    in destination = (2000.0, 0.0, 0.0);
                    in speed = 45.0;
                }
                then action engage : EngageHostile {
                    in weaponSelection = "autocannon";
                }
                then action assessDamage : AssessDamage {
                    in damageReport = 15.0;
                }
                then evaluateStatus;
            }
            
            then action evaluateStatus {
                then decide;
                    if assessDamage.systemsOperational then missionLoop;
                    if !assessDamage.systemsOperational then emergencyReturn;
            }
            
            then action continuePatrol {
                first action patrolMove : NavigateToPosition {
                    in destination = (5000.0, 5000.0, 0.0);
                    in speed = 25.0;
                }
                then missionLoop;
            }
            
            then action emergencyReturn;
        }
        
        then done;
    }

    state def MechaOperationalStates {
        entry; then standbyState;
        
        state standbyState;
        then activationTransition;
        
        state patrolState;
        then combatTransition;
        
        state combatState;
        then retreatTransition;
        then patrolTransition;
        
        state retreatState;
        then maintenanceTransition;
        
        state maintenanceState;
        then standbyTransition;
        
        transition activationTransition
            first standbyState
            then patrolState;
        
        transition combatTransition
            first patrolState
            then combatState;
        
        transition retreatTransition
            first combatState
            then retreatState;
        
        transition patrolTransition
            first combatState
            then patrolState;
        
        transition maintenanceTransition
            first retreatState
            then maintenanceState;
        
        transition standbyTransition
            first maintenanceState
            then standbyState;
    }

    requirement <'REQ-MECHA-001'> primaryMission {
        doc /* The Mecha shall provide tactical battlefield superiority through
             * integrated offensive and defensive capabilities, enabling engagement
             * of hostile forces at ranges up to 3 kilometers while maintaining
             * pilot survivability. */
        subject mecha : Mecha;
        
        require mobilityRequirement;
        require firepower;
        require survivalRequirement;
        require powerRequirement;
    }

    requirement <'REQ-MECHA-002'> mobilityRequirement {
        subject locomotion : Mecha::locomotion;
        doc /* The locomotion system shall achieve a maximum running speed
             * of at least 60 km/h to enable rapid tactical repositioning. */
        assert constraint {
            locomotion.maxRunSpeed >= 60.0
        }
    }

    requirement <'REQ-MECHA-003'> firepower {
        subject weapons : Mecha::weapons;
        doc /* The weapon system shall maintain effective engagement capability
             * at ranges of 3000 meters with ammunition capacity for sustained combat. */
        assert constraint {
            weapons.effectiveRange >= 3000.0 and
            weapons.maxAmmunition >= 2000
        }
    }

    requirement <'REQ-MECHA-004'> survivalRequirement {
        subject defense : Mecha::defense;
        doc /* The defense system shall maintain armor integrity and shield
             * protection sufficient to withstand sustained hostile fire. */
        assert constraint {
            defense.armorIntegrity >= 0.0 and
            defense.shieldStrength >= 0.0
        }
    }

    requirement <'REQ-MECHA-005'> powerRequirement {
        subject reactor : Mecha::reactor;
        doc /* The fusion reactor shall provide continuous power output
             * of at least 20 MW to support all combat systems. */
        assert constraint {
            reactor.maxPowerOutput >= 20000000.0
        }
    }

    requirement <'REQ-MECHA-006'> sensorCapability {
        subject sensors : Mecha::sensors;
        doc /* The sensor array shall detect and track targets at ranges
             * exceeding weapon effective range by at least 40%. */
        assert constraint {
            sensors.radarRange >= 42000.0
        }
    }

    requirement <'REQ-MECHA-007'> massConstraint {
        subject mecha : Mecha;
        doc /* The total mass shall not exceed 75000 kg to maintain
             * ground mobility and structural integrity. */
        assert constraint {
            mecha.totalMass <= 75000.0 [kg]
        }
    }

    part mechaUnit : Mecha {
        attribute :>> totalMass = 68000.0 [kg];
        attribute :>> height = 12.0;
        attribute :>> operationalMode = OperationalMode::standby;
        attribute :>> missionTime = 0.0;
        
        perform action mission[*] references CombatMission;
    }

    satisfy primaryMission by mechaUnit;
    satisfy mobilityRequirement by mechaUnit.locomotion;
    satisfy firepower by mechaUnit.weapons;
    satisfy survivalRequirement by mechaUnit.defense;
    satisfy powerRequirement by mechaUnit.reactor;
    satisfy sensorCapability by mechaUnit.sensors;
    satisfy massConstraint by mechaUnit;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    private import MechaWarriorSystem::*;

    part testSubject : FusionReactor {
        exhibit state sm : MechaOperationalStates;
    }

    action orchestrator {
        action actionProbe : InitializeSystems {
            in powerAvailable = 0.0;
        }
        first actionProbe;
    }
}
