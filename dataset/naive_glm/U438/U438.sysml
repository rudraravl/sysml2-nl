package VacuumExtractionSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ---- Value types with units ----
    value def Power :> Real { unit 'W'; }
    value def Pressure :> Real { unit 'Pa'; }
    value def RotationalSpeed :> Real { unit 'rpm'; }
    value def MassFlowRate :> Real { unit 'kg/s'; }
    value def VolumeFlowRate :> Real { unit 'm3/s'; }
    value def FillPercentage :> Real { unit '%'; }
    value def FilterLoadPercentage :> Real { unit '%'; }
    value def Temperature :> Real { unit 'degC'; }
    value def Duration :> Real { unit 's'; }

    // ---- Enumerations ----
    enum def SystemMode { standby; startup; operating; shutdown; }
    enum def FilterCondition { clean; partiallyLoaded; saturated; }
    enum def Command { powerOn; powerOff; }
    enum def ContainerStatus { empty; partiallyFull; full; }
    enum def AlertLevel { none; info; warning; critical; }

    // ---- Item definitions ----
    item def ContaminatedAir;
    item def CleanAir;
    item def SolidDebris;
    item def FineDust;
    item def CapturedContaminants :> SolidDebris;

    // ---- Port definitions ----
    port def AirFlowPort {
        attribute flowRate : VolumeFlowRate;
        out item : ContaminatedAir | CleanAir;
    }

    port def DebrisPort {
        attribute massFlow : MassFlowRate;
        out item : SolidDebris | FineDust;
    }

    port def ShaftPort {
        attribute speed : RotationalSpeed;
        attribute torque : Real;
    }

    port def CommandPort {
        in item : Command;
    }

    port def StatusPort {
        out item : SystemMode;
    }

    port def FilterStatusPort {
        attribute load : FilterLoadPercentage;
        attribute condition : FilterCondition;
    }

    port def ContainerStatusPort {
        attribute fillLevel : FillPercentage;
        attribute status : ContainerStatus;
    }

    port def PowerControlPort {
        attribute power : Power;
    }

    port def AlertPort {
        attribute level : AlertLevel;
        attribute message : String;
    }

    // ---- Requirements ----
    requirement def SuctionRequirement {
        doc /* The system shall generate sufficient suction to draw contaminated air through the intake nozzle. */
        subject system : VacuumExtractionSystem;
        requirement {
            subject fan : ImpellerFan;
            fan.currentSpeed >= 10000 [rpm];
        }
    }

    requirement def FiltrationRequirement {
        doc /* The filter assembly shall separate solid particles from the air stream and deposit them into the collection container. */
        subject filter : FilterAssembly;
        requirement {
            filter.condition != FilterCondition::saturated implies filter.currentLoad < 100 [%];
        }
    }

    requirement def MaintenanceRequirement {
        doc /* The system shall alert the operator when the collection container is full or the filter is saturated. */
        subject system : VacuumExtractionSystem;
        requirement {
            container.status == ContainerStatus::full or filter.condition == FilterCondition::saturated
            implies alert.level == AlertLevel::critical;
        }
    }

    requirement def PowerManagementRequirement {
        doc /* The controller shall reduce motor power when the filter becomes saturated. */
        subject controller : ControlUnit;
        requirement {
            filterStatusIn.condition == FilterCondition::saturated
            implies powerControlOut.power <= 0.5 * motor.nominalPower;
        }
    }

    // ---- Part definitions ----

    part def ElectricMotor {
        attribute nominalPower : Power = 1500 [W];
        attribute currentPower : Power = 0 [W];
        attribute targetPower : Power = 0 [W];
        attribute operatingTemperature : Temperature = 25 [degC];

        in port commandIn : CommandPort;
        in port powerControlIn : PowerControlPort;
        out port shaftOut : ShaftPort;
        out port powerStatusOut : StatusPort;

        action def accelerate {
            in target : Power;
            out achieved : Power;
            perform {
                currentPower = target;
                shaftOut.speed = (currentPower / nominalPower) * 18000 [rpm];
            }
        }

        state motorStates {
            entry; then off;
            state off {
                entry { currentPower = 0 [W]; shaftOut.speed = 0 [rpm]; }
                accept commandIn.powerOn then starting;
            }
            state starting {
                entry { currentPower = 0.3 * nominalPower; }
                do { currentPower = currentPower + 100 [W]; } 
                transition to running when currentPower >= targetPower;
            }
            state running {
                entry { currentPower = targetPower; }
                accept commandIn.powerOff then stopping;
                accept powerControlIn when powerControlIn.power < currentPower {
                    targetPower = powerControlIn.power;
                }
            }
            state stopping {
                entry { currentPower = currentPower * 0.5; }
                transition to off when currentPower <= 1 [W];
            }
        }
    }

    part def ImpellerFan {
        attribute nominalSpeed : RotationalSpeed = 18000 [rpm];
        attribute currentSpeed : RotationalSpeed = 0 [rpm];
        attribute suctionPressure : Pressure = 0 [Pa];
        attribute maxSuction : Pressure = 20000 [Pa];

        in port shaftIn : ShaftPort;
        out port suctionOut : AirFlowPort;

        compute fanDynamics {
            currentSpeed = shaftIn.speed;
            suctionPressure = (currentSpeed / nominalSpeed) * maxSuction;
            suctionOut.flowRate = (currentSpeed / nominalSpeed) * 0.5 [m3/s];
        }

        state fanStates {
            entry; then idle;
            state idle {
                entry { currentSpeed = 0 [rpm]; suctionPressure = 0 [Pa]; }
                transition to spinning when shaftIn.speed > 0 [rpm];
            }
            state spinning {
                entry { currentSpeed = shaftIn.speed; }
                transition to idle when shaftIn.speed == 0 [rpm];
            }
        }
    }

    part def IntakeNozzle {
        attribute diameter : Real = 0.05 [m];
        attribute length : Real = 0.3 [m];
        out port airOut : AirFlowPort;

        compute intakeFlow {
            airOut.flowRate = 0.0 [m3/s];
            airOut.item = ContaminatedAir {};
        }
    }

    part def FilterAssembly {
        attribute maxLoad : FilterLoadPercentage = 100 [%];
        attribute currentLoad : FilterLoadPercentage = 0 [%];
        attribute condition : FilterCondition = FilterCondition::clean;
        attribute separationEfficiency : Real = 0.995;

        in port airIn : AirFlowPort;
        out port cleanAirOut : AirFlowPort;
        out port debrisOut : DebrisPort;
        out port filterStatusOut : FilterStatusPort;

        compute filterOperation {
            currentLoad = currentLoad + (airIn.flowRate * 0.0001 [%]);
            filterStatusOut.load = currentLoad;
            filterStatusOut.condition = condition;
            cleanAirOut.flowRate = airIn.flowRate;
            cleanAirOut.item = CleanAir {};
            debrisOut.massFlow = airIn.flowRate * 1.2 [kg/m3] * (1.0 - separationEfficiency);
            debrisOut.item = SolidDebris {};
        }

        state filterLifecycle {
            entry; then clean;
            state clean {
                entry { condition = FilterCondition::clean; }
                transition to partiallyLoaded when currentLoad > 30 [%];
            }
            state partiallyLoaded {
                entry { condition = FilterCondition::partiallyLoaded; }
                transition to saturated when currentLoad >= 90 [%];
            }
            state saturated {
                entry { condition = FilterCondition::saturated; }
            }
        }
    }

    part def CollectionContainer {
        attribute maxCapacity : MassFlowRate = 50 [kg];
        attribute currentFill : MassFlowRate = 0 [kg];
        attribute fillLevel : FillPercentage = 0 [%];
        attribute status : ContainerStatus = ContainerStatus::empty;

        in port debrisIn : DebrisPort;
        out port containerStatusOut : ContainerStatusPort;

        compute fillAccumulation {
            currentFill = currentFill + debrisIn.massFlow * 1.0 [s];
            fillLevel = (currentFill / maxCapacity) * 100 [%];
            containerStatusOut.fillLevel = fillLevel;
            containerStatusOut.status = status;
        }

        state fillMonitor {
            entry; then empty;
            state empty {
                entry { status = ContainerStatus::empty; }
                transition to partiallyFull when fillLevel > 10 [%];
            }
            state partiallyFull {
                entry { status = ContainerStatus::partiallyFull; }
                transition to full when fillLevel >= 95 [%];
            }
            state full {
                entry { status = ContainerStatus::full; }
                transition to empty when currentFill == 0 [kg];
            }
        }
    }

    part def ExhaustPort {
        attribute outletDiameter : Real = 0.08 [m];
        in port airIn : AirFlowPort;

        compute exhaustFlow {
            // pass-through clean air to environment
        }
    }

    part def ControlUnit {
        attribute mode : SystemMode = SystemMode::standby;
        attribute powerReductionFactor : Real = 1.0;
        attribute startupDuration : Duration = 5.0 [s];
        attribute shutdownDuration : Duration = 3.0 [s];

        in port commandIn : CommandPort;
        in port filterStatusIn : FilterStatusPort;
        in port containerStatusIn : ContainerStatusPort;
        out port motorCommandOut : CommandPort;
        out port powerControlOut : PowerControlPort;
        out port systemStatusOut : StatusPort;
        out port alertOut : AlertPort;

        action def issueCommand {
            in cmd : Command;
            out port : CommandPort;
            perform { port.item = cmd; }
        }

        action def evaluatePerformance {
            in filterCond : FilterCondition;
            in containerStat : ContainerStatus;
            out power : Power;
            out alert : AlertLevel;
            perform {
                if filterCond == FilterCondition::saturated {
                    power = 750 [W];
                    powerReductionFactor = 0.5;
                    alert = AlertLevel::critical;
                } else if filterCond == FilterCondition::partiallyLoaded {
                    power = 1200 [W];
                    powerReductionFactor = 0.8;
                    alert = AlertLevel::info;
                } else {
                    power = 1500 [W];
                    powerReductionFactor = 1.0;
                    alert = AlertLevel::none;
                }
                if containerStat == ContainerStatus::full {
                    alert = AlertLevel::critical;
                }
            }
        }

        state controlStateMachine {
            entry; then standby;
            state standby {
                entry {
                    mode = SystemMode::standby;
                    systemStatusOut.item = mode;
                    powerControlOut.power = 0 [W];
                    alertOut.level = AlertLevel::none;
                    alertOut.message = "System idle.";
                }
                accept commandIn.powerOn then startup;
            }
            state startup {
                entry {
                    mode = SystemMode::startup;
                    systemStatusOut.item = mode;
                    motorCommandOut.item = Command::powerOn;
                    powerControlOut.power = 1500 [W];
                    alertOut.level = AlertLevel::info;
                    alertOut.message = "System starting up.";
                }
                do {
                    perform evaluatePerformance(
                        filterStatusIn.condition,
                        containerStatusIn.status,
                        powerControlOut.power,
                        alertOut.level
                    );
                }
                transition to operating when startupDuration elapsed;
            }
            state operating {
                entry {
                    mode = SystemMode::operating;
                    systemStatusOut.item = mode;
                }
                do {
                    perform evaluatePerformance(
                        filterStatusIn.condition,
                        containerStatusIn.status,
                        powerControlOut.power,
                        alertOut.level
                    );
                    if filterStatusIn.condition == FilterCondition::saturated {
                        alertOut.message = "Filter saturated: replace filter.";
                    }
                    if containerStatusIn.status == ContainerStatus::full {
                        alertOut.message = "Collection container full: empty container.";
                    }
                }
                accept commandIn.powerOff then shutdown;
            }
            state shutdown {
                entry {
                    mode = SystemMode::shutdown;
                    systemStatusOut.item = mode;
                    motorCommandOut.item = Command::powerOff;
                    powerControlOut.power = 0 [W];
                    alertOut.level = AlertLevel::info;
                    alertOut.message = "System shutting down.";
                }
                transition to standby when shutdownDuration elapsed;
            }
        }
    }

    // ---- Top-level system ----
    part def VacuumExtractionSystem {
        port externalCommand : CommandPort;
        port operatorAlert : AlertPort;

        part motor : ElectricMotor {
            attribute nominalPower = 1500 [W];
        }
        part fan : ImpellerFan {
            attribute nominalSpeed = 18000 [rpm];
        }
        part intake : IntakeNozzle;
        part filter : FilterAssembly;
        part container : CollectionContainer;
        part exhaust : ExhaustPort;
        part controller : ControlUnit;

        connection shaftConnection connect motor.shaftOut to fan.shaftIn;
        connection intakeAirFlow connect intake.airOut to filter.airIn;
        connection cleanAirFlow connect filter.cleanAirOut to exhaust.airIn;
        connection debrisFlow connect filter.debrisOut to container.debrisIn;
        connection motorCommand connect controller.motorCommandOut to motor.commandIn;
        connection powerControl connect controller.powerControlOut to motor.powerControlIn;
        connection filterStatus connect filter.filterStatusOut to controller.filterStatusIn;
        connection containerStatus connect container.containerStatusOut to controller.containerStatusIn;
        connection externalCommandFlow connect externalCommand to controller.commandIn;
        connection alertFlow connect controller.alertOut to operatorAlert;

        // Requirements satisfaction
        satisfy SuctionRequirement by system;
        satisfy FiltrationRequirement by filter;
        satisfy MaintenanceRequirement by system;
        satisfy PowerManagementRequirement by controller;
    }

    // ---- Instantiated system ----
    part vacuumSystem : VacuumExtractionSystem {
        // Operational configuration
    }
}
