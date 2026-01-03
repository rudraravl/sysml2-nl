package SpacecraftPropulsionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def ThrustValue :> Real;
    attribute def MassFlowRateValue :> Real;
    attribute def SpecificImpulseValue :> Real;
    attribute def PropellantMassValue :> Real;
    attribute def ExhaustVelocityValue :> Real;
    attribute def PressureValue :> Real;
    attribute def TemperatureValue :> Real;

    item def Propellant {
        attribute mass : PropellantMassValue;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
    }

    item def ExhaustGas {
        attribute velocity : ExhaustVelocityValue;
        attribute massFlowRate : MassFlowRateValue;
        attribute temperature : TemperatureValue;
    }

    item def ThrustCommand {
        attribute requestedThrust : ThrustValue;
        attribute duration : Real;
    }

    item def TelemetryData {
        attribute actualThrust : ThrustValue;
        attribute propellantRemaining : PropellantMassValue;
        attribute chamberPressure : PressureValue;
        attribute chamberTemperature : TemperatureValue;
    }

    port def PropellantSupplyPort {
        out item propellant : Propellant;
    }

    port def ExhaustPort {
        out item exhaust : ExhaustGas;
    }

    port def CommandPort {
        in item command : ThrustCommand;
    }

    port def TelemetryPort {
        out item telemetry : TelemetryData;
    }

    part def PropellantTank {
        attribute capacity : PropellantMassValue;
        attribute currentLevel : PropellantMassValue;
        attribute storagePressure : PressureValue;
        port supplyPort : PropellantSupplyPort;

        assert constraint tankCapacity {
            currentLevel <= capacity
        }

        assert constraint positiveLevel {
            currentLevel >= 0.0
        }
    }

    part def PropellantFeedSystem {
        attribute feedPressure : PressureValue;
        attribute flowRate : MassFlowRateValue;
        port inletPort : ~PropellantSupplyPort;
        port outletPort : PropellantSupplyPort;
    }

    part def CombustionChamber {
        attribute chamberPressure : PressureValue;
        attribute chamberTemperature : TemperatureValue;
        attribute combustionEfficiency : Real;
        port propellantInlet : ~PropellantSupplyPort;
        port exhaustOutlet : ExhaustPort;

        assert constraint operatingPressure {
            chamberPressure >= 1.0e6 and chamberPressure <= 2.0e7
        }

        assert constraint operatingTemperature {
            chamberTemperature >= 2500.0 and chamberTemperature <= 3800.0
        }
    }

    part def Nozzle {
        attribute expansionRatio : Real;
        attribute exitVelocity : ExhaustVelocityValue;
        attribute throatArea : Real;
        port exhaustInlet : ~ExhaustPort;
        port exhaustExit : ExhaustPort;
    }

    part def ThrustController {
        attribute targetThrust : ThrustValue;
        attribute currentThrust : ThrustValue;
        attribute controlGain : Real;
        port commandInput : ~CommandPort;
        port telemetryOutput : TelemetryPort;

        perform action controlLoop;
    }

    action def MonitorPropellant {
        in propellantLevel : PropellantMassValue;
        in capacity : PropellantMassValue;
        out levelStatus : Boolean;
        out percentRemaining : Real;
    }

    action def IgniteEngine {
        in ignitionSignal : Boolean;
        in propellantAvailable : Boolean;
        out ignitionSuccess : Boolean;
    }

    action def RegulateThrust {
        in targetThrust : ThrustValue;
        in actualThrust : ThrustValue;
        in propellantLevel : PropellantMassValue;
        out valvePosition : Real;
        out flowRate : MassFlowRateValue;
    }

    action def ShutdownEngine {
        in shutdownSignal : Boolean;
        out shutdownComplete : Boolean;
    }

    action def EmergencyShutdown {
        in anomalyDetected : Boolean;
        out emergencyComplete : Boolean;
    }

    part def PropulsionSystem {
        attribute totalMass : Real;
        attribute specificImpulse : SpecificImpulseValue;
        attribute maxThrust : ThrustValue;
        attribute totalImpulse : Real;

        part tank : PropellantTank {
            attribute :>> capacity = 800.0;
            attribute :>> currentLevel = 800.0;
            attribute :>> storagePressure = 3.0e6;
        }

        part feedSystem : PropellantFeedSystem {
            attribute :>> feedPressure = 1.5e7;
            attribute :>> flowRate = 4.0;
        }

        part chamber : CombustionChamber {
            attribute :>> chamberPressure = 1.0e7;
            attribute :>> chamberTemperature = 3400.0;
            attribute :>> combustionEfficiency = 0.95;
        }

        part nozzle : Nozzle {
            attribute :>> expansionRatio = 50.0;
            attribute :>> exitVelocity = 4200.0;
            attribute :>> throatArea = 0.02;
        }

        part controller : ThrustController {
            attribute :>> targetThrust = 16800.0;
            attribute :>> currentThrust = 0.0;
            attribute :>> controlGain = 0.8;
        }

        connection propellantFlow1 connect tank.supplyPort to feedSystem.inletPort;
        connection propellantFlow2 connect feedSystem.outletPort to chamber.propellantInlet;
        connection exhaustFlow1 connect chamber.exhaustOutlet to nozzle.exhaustInlet;

        perform action operatePropulsion {
            first start;
            then merge checkStatus;

            action checkStatus : MonitorPropellant {
                in propellantLevel = tank.currentLevel;
                in capacity = tank.capacity;
                out levelStatus : Boolean;
                out percentRemaining : Real;
            }

            then decide;
                if checkStatus.levelStatus then ignite;
                if not checkStatus.levelStatus then abort;

            action ignite : IgniteEngine {
                in ignitionSignal = true;
                in propellantAvailable = checkStatus.levelStatus;
                out ignitionSuccess : Boolean;
            }

            then decide;
                if ignite.ignitionSuccess then maintainThrust;
                if not ignite.ignitionSuccess then abort;

            action maintainThrust : RegulateThrust {
                in targetThrust = controller.targetThrust;
                in actualThrust = controller.currentThrust;
                in propellantLevel = tank.currentLevel;
                out valvePosition : Real;
                out flowRate : MassFlowRateValue;
            }

            then merge continueOperation;

            action continueOperation;
            then checkStatus;

            action abort : ShutdownEngine {
                in shutdownSignal = true;
                out shutdownComplete : Boolean;
            }

            then done;
        }

        assert constraint thrustCalculation {
            maxThrust == feedSystem.flowRate * nozzle.exitVelocity
        }

        assert constraint specificImpulseCalculation {
            specificImpulse == nozzle.exitVelocity / 9.81
        }

        assert constraint massConservation {
            tank.currentLevel >= 0.0
        }
    }

    part def Spacecraft {
        attribute dryMass : Real;
        attribute wetMass : Real;
        attribute deltaV : ExhaustVelocityValue;

        part propulsion : PropulsionSystem {
            attribute :>> totalMass = 1200.0;
            attribute :>> specificImpulse = 428.0;
            attribute :>> maxThrust = 16800.0;
            attribute :>> totalImpulse = 3360000.0;
        }

        assert constraint totalMassCalculation {
            wetMass == dryMass + propulsion.tank.currentLevel
        }
    }

    package StakeholderRequirements {
        requirement <'SR-001'> providePropulsion {
            doc /* The spacecraft propulsion system shall provide controlled thrust 
                 * to enable orbital maneuvers, trajectory corrections, and station-keeping 
                 * operations throughout the mission lifetime.
                 */
            subject propulsionSystem : PropulsionSystem;
        }

        requirement <'SR-002'> reliableOperation {
            doc /* The propulsion system shall operate reliably with controlled ignition, 
                 * steady-state thrust, and safe shutdown capabilities.
                 */
            subject propulsionSystem : PropulsionSystem;
        }

        requirement <'SR-003'> missionDeltaV {
            doc /* The propulsion system shall provide sufficient delta-V capability 
                 * to accomplish all planned mission maneuvers.
                 */
            subject spacecraft : Spacecraft;
        }
    }

    package SystemRequirements {
        requirement <'SYS-001'> thrustRequirement {
            doc /* The propulsion system shall generate a maximum thrust of at least 16800 N 
                 * in vacuum conditions.
                 */
            subject propulsionSystem : PropulsionSystem;
            assert constraint {
                propulsionSystem.maxThrust >= 16800.0
            }
        }

        requirement <'SYS-002'> specificImpulseRequirement {
            doc /* The propulsion system shall achieve a specific impulse of at least 400 seconds 
                 * to ensure efficient propellant utilization.
                 */
            subject propulsionSystem : PropulsionSystem;
            assert constraint {
                propulsionSystem.specificImpulse >= 400.0
            }
        }

        requirement <'SYS-003'> propellantCapacityRequirement {
            doc /* The propellant tank shall have a capacity of at least 800 kg to support 
                 * mission delta-V requirements.
                 */
            subject tank : PropellantTank;
            assert constraint {
                tank.capacity >= 800.0
            }
        }

        requirement <'SYS-004'> chamberPressureRequirement {
            doc /* The combustion chamber shall maintain operating pressure between 1 MPa and 20 MPa 
                 * during thrust operations.
                 */
            subject chamber : CombustionChamber;
            assert constraint {
                chamber.chamberPressure >= 1.0e6 and chamber.chamberPressure <= 2.0e7
            }
        }

        requirement <'SYS-005'> systemMassRequirement {
            doc /* The total mass of the propulsion system including propellant shall not exceed 1200 kg.
                 */
            subject propulsionSystem : PropulsionSystem;
            assert constraint {
                propulsionSystem.totalMass <= 1200.0
            }
        }
    }

    package SystemArchitecture {
        part missionSpacecraft : Spacecraft {
            attribute :>> dryMass = 2500.0;
            attribute :>> wetMass = 3300.0;
            attribute :>> deltaV = 2800.0;
        }

        satisfy StakeholderRequirements::providePropulsion by missionSpacecraft.propulsion;
        satisfy StakeholderRequirements::reliableOperation by missionSpacecraft.propulsion;
        satisfy StakeholderRequirements::missionDeltaV by missionSpacecraft;
    }
}
