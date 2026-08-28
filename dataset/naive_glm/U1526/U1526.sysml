package WaterStorageDistributionSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    attribute def Pressure :> Real { unit 'bar'; }
    attribute def Volume :> Real { unit 'L'; }
    attribute def Percentage :> Real { unit '%'; }
    attribute def FlowRate :> Real { unit 'L/min'; }
    attribute def Turbidity :> Real { unit 'NTU'; }
    attribute def TemperatureValue :> Real { unit '°C'; }
    attribute def pHValue :> Real { unit 'pH'; }

    // ===== Items =====
    item def Water {
        attribute pH : pHValue;
        attribute turbidity : Turbidity;
        attribute temperature : TemperatureValue;
    }

    // ===== Port Definitions =====
    port def FluidPort {
        attribute flowRate : FlowRate;
        attribute pressure : Pressure;
        item water : Water;
    }

    port def LevelSignalPort {
        attribute level : Percentage;
    }

    port def QualitySignalPort {
        attribute pH : pHValue;
        attribute turbidity : Turbidity;
        attribute temperature : TemperatureValue;
    }

    port def ValveCommandPort {
        attribute open : Boolean;
    }

    port def StatusPort {
        attribute status : String;
    }

    // ===== Enumerations =====
    enum def SystemStatus { NORMAL; FILLING; DRAINING; FULL; }

    // ===== Requirements =====
    requirement def ReservoirCapacityRequirement {
        doc /* The storage tank shall hold up to 100,000 liters of water. */
        attribute maxCapacity : Volume = 100000 'L';
        subject tank : StorageTank;
        require tank.capacity == maxCapacity;
    }

    requirement def SafeFillRangeRequirement {
        doc /* The tank shall operate between 5% and 95% of total capacity. */
        attribute minLevel : Percentage = 5 '%';
        attribute maxLevel : Percentage = 95 '%';
        subject tank : StorageTank;
        require tank.currentLevel >= minLevel and tank.currentLevel <= maxLevel;
    }

    requirement def InletPressureRequirement {
        doc /* The inlet pressure regulator shall manage incoming pressure to 4 bar. */
        attribute targetPressure : Pressure = 4 'bar';
        subject regulator : PressureRegulator;
        require regulator.regulatedPressure == targetPressure;
    }

    requirement def OutletPressureRequirement {
        doc /* The outlet pressure regulator shall deliver water at 3 bar. */
        attribute targetPressure : Pressure = 3 'bar';
        subject regulator : PressureRegulator;
        require regulator.regulatedPressure == targetPressure;
    }

    requirement def OptimalLevelRequirement {
        doc /* The controller shall maintain the water level at an optimal target of 80%. */
        attribute targetLevel : Percentage = 80 '%';
        subject controller : SystemController;
        require controller.targetLevel == targetLevel;
    }

    requirement def AutomatedOperationRequirement {
        doc /* The system shall operate without manual intervention. */
        subject system : WaterStorageSystem;
        require system.automated == true;
    }

    // ===== Part Definitions =====
    part def PressureRegulator {
        attribute regulatedPressure : Pressure;
        port in unregulatedIn : FluidPort;
        port out regulatedOut : FluidPort;
    }

    part def FlowValve {
        attribute isOpen : Boolean = false;
        attribute maxFlowRate : FlowRate = 500 'L/min';
        port in fluidIn : FluidPort;
        port out fluidOut : FluidPort;
        port in command : ValveCommandPort;

        action def setValve {
            in cmd : Boolean;
            then assign isOpen = cmd;
        }
    }

    part def StorageTank {
        attribute capacity : Volume = 100000 'L';
        attribute currentLevel : Percentage = 50 '%';
        attribute currentVolume : Volume = 50000 'L';
        attribute minSafeLevel : Percentage = 5 '%';
        attribute maxSafeLevel : Percentage = 95 '%';

        port in inlet : FluidPort;
        port out outlet : FluidPort;

        action def updateLevel {
            in inflow : FlowRate;
            in outflow : FlowRate;
            attribute deltaVolume : Volume;
            then assign deltaVolume = (inflow - outflow) * 1 'min';
            then assign currentVolume = currentVolume + deltaVolume;
            then assign currentLevel = (currentVolume / capacity) * 100 '%';
        }
    }

    part def LevelSensor {
        port in tankConnection : FluidPort;
        port out levelSignal : LevelSignalPort;

        action def readLevel {
            in tankLevel : Percentage;
            then assign levelSignal.level = tankLevel;
        }
    }

    part def QualityMonitor {
        port in sampleIn : FluidPort;
        port out qualitySignal : QualitySignalPort;

        action def measureQuality {
            in sample : Water;
            then assign qualitySignal.pH = sample.pH;
            then assign qualitySignal.turbidity = sample.turbidity;
            then assign qualitySignal.temperature = sample.temperature;
        }
    }

    part def SystemController {
        attribute targetLevel : Percentage = 80 '%';
        attribute lowThreshold : Percentage = 70 '%';
        attribute highThreshold : Percentage = 90 '%';
        attribute currentStatus : SystemStatus = NORMAL;
        attribute automated : Boolean = true;

        port in levelInput : LevelSignalPort;
        port in qualityInput : QualitySignalPort;
        port out inletValveCmd : ValveCommandPort;
        port out outletValveCmd : ValveCommandPort;
        port out statusOutput : StatusPort;

        state machine def ControllerStateMachine {
            entry action {
                assign currentStatus := NORMAL;
                assign inletValveCmd.open := false;
                assign outletValveCmd.open := false;
            }

            state Normal {
                entry action {
                    assign currentStatus := NORMAL;
                    assign statusOutput.status := "normal";
                }
                transition Normal_to_Filling
                    first Normal
                    then Filling
                    if levelInput.level < lowThreshold;
                transition Normal_to_Draining
                    first Normal
                    then Draining
                    if levelInput.level > highThreshold;
            }

            state Filling {
                entry action {
                    assign currentStatus := FILLING;
                    assign statusOutput.status := "filling";
                    assign inletValveCmd.open := true;
                    assign outletValveCmd.open := false;
                }
                transition Filling_to_Normal
                    first Filling
                    then Normal
                    if levelInput.level >= targetLevel;
                transition Filling_to_Full
                    first Filling
                    then Full
                    if levelInput.level >= maxSafeLevel;
            }

            state Draining {
                entry action {
                    assign currentStatus := DRAINING;
                    assign statusOutput.status := "draining";
                    assign inletValveCmd.open := false;
                    assign outletValveCmd.open := true;
                }
                transition Draining_to_Normal
                    first Draining
                    then Normal
                    if levelInput.level <= targetLevel;
            }

            state Full {
                entry action {
                    assign currentStatus := FULL;
                    assign statusOutput.status := "full";
                    assign inletValveCmd.open := false;
                    assign outletValveCmd.open := true;
                }
                transition Full_to_Draining
                    first Full
                    then Draining
                    if levelInput.level < maxSafeLevel;
            }
        }

        action def evaluateLevel {
            in level : Percentage;
            if level < lowThreshold {
                assign inletValveCmd.open := true;
                assign outletValveCmd.open := false;
                assign currentStatus := FILLING;
                assign statusOutput.status := "filling";
            } else if level > highThreshold {
                assign inletValveCmd.open := false;
                assign outletValveCmd.open := true;
                assign currentStatus := DRAINING;
                assign statusOutput.status := "draining";
            } else {
                assign inletValveCmd.open := false;
                assign outletValveCmd.open := false;
                assign currentStatus := NORMAL;
                assign statusOutput.status := "normal";
            }
        }
    }

    // ===== Inlet and Outlet Path Assemblies =====
    part def InletPath {
        part pressureRegulator : PressureRegulator {
            attribute regulatedPressure : Pressure = 4 'bar';
        }
        part flowValve : FlowValve {
            attribute maxFlowRate : FlowRate = 600 'L/min';
        }
        port in sourcePort : FluidPort;
        port out tankPort : FluidPort;

        connection regulatorToValve connect pressureRegulator.regulatedOut to flowValve.fluidIn;
        connection sourceToRegulator connect sourcePort to pressureRegulator.unregulatedIn;
        connection valveToTank connect flowValve.fluidOut to tankPort;
    }

    part def OutletPath {
        part flowValve : FlowValve {
            attribute maxFlowRate : FlowRate = 400 'L/min';
        }
        part pressureRegulator : PressureRegulator {
            attribute regulatedPressure : Pressure = 3 'bar';
        }
        port in tankPort : FluidPort;
        port out distributionPort : FluidPort;

        connection tankToValve connect tankPort to flowValve.fluidIn;
        connection valveToRegulator connect flowValve.fluidOut to pressureRegulator.unregulatedIn;
        connection regulatorToDistribution connect pressureRegulator.regulatedOut to distributionPort;
    }

    // ===== Top-Level System =====
    part def WaterStorageSystem {
        attribute automated : Boolean = true;

        part tank : StorageTank {
            attribute capacity : Volume = 100000 'L';
        }

        part inletPath : InletPath {
            part pressureRegulator : PressureRegulator {
                attribute regulatedPressure : Pressure = 4 'bar';
            }
            part flowValve : FlowValve;
        }

        part outletPath : OutletPath {
            part flowValve : FlowValve;
            part pressureRegulator : PressureRegulator {
                attribute regulatedPressure : Pressure = 3 'bar';
            }
        }

        part levelSensor : LevelSensor;
        part qualityMonitor : QualityMonitor;
        part controller : SystemController;

        port in waterSource : FluidPort;
        port out distribution : FluidPort;
        port out systemStatus : StatusPort;

        connection sourceToInlet connect waterSource to inletPath.sourcePort;
        connection inletToTank connect inletPath.tankPort to tank.inlet;
        connection tankToOutlet connect tank.outlet to outletPath.tankPort;
        connection outletToDistribution connect outletPath.distributionPort to distribution;

        connection tankToLevelSensor connect tank.outlet to levelSensor.tankConnection;
        connection levelSensorToController connect levelSensor.levelSignal to controller.levelInput;

        connection tankToQualityMonitor connect tank.outlet to qualityMonitor.sampleIn;
        connection qualityMonitorToController connect qualityMonitor.qualitySignal to controller.qualityInput;

        connection controllerToInletValve connect controller.inletValveCmd to inletPath.flowValve.command;
        connection controllerToOutletValve connect controller.outletValveCmd to outletPath.flowValve.command;
        connection controllerToStatus connect controller.statusOutput to systemStatus;

        satisfy ReservoirCapacityRequirement by tank;
        satisfy SafeFillRangeRequirement by tank;
        satisfy InletPressureRequirement by inletPath.pressureRegulator;
        satisfy OutletPressureRequirement by outletPath.pressureRegulator;
        satisfy OptimalLevelRequirement by controller;
        satisfy AutomatedOperationRequirement by WaterStorageSystem;
    }

    part waterSystem : WaterStorageSystem;
}
