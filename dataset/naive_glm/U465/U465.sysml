package AldgatePumpingSubsystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type VolumeUnit > Real {
        unit 'L';
    }
    value type FlowRateUnit > Real {
        unit 'L/min';
    }
    value type PressureUnit > Real {
        unit 'bar';
    }
    value type LevelUnit > Real {
        unit 'm';
    }
    value type PowerUnit > Real {
        unit 'kW';
    }
    value type RotationalSpeedUnit > Real {
        unit 'rpm';
    }

    item def Fluid;

    // ===== Interfaces =====
    interface def FluidFlow {
        in items fluid : Fluid;
        out attributes flowRate : FlowRateUnit;
    }

    interface def PressureReading {
        out attributes pressure : PressureUnit;
    }

    interface def FlowReading {
        out attributes flowRate : FlowRateUnit;
    }

    interface def LevelReading {
        out attributes level : LevelUnit;
    }

    interface def LevelCommand {
        in attributes level : LevelUnit;
    }

    interface def PumpCommand {
        in attributes run : Boolean;
    }

    interface def PowerFlow {
        in attributes power : PowerUnit;
    }

    interface def MechanicalDrive {
        out attributes speed : RotationalSpeedUnit;
        out attributes torque : Real;
    }

    // ===== Requirements =====
    requirement def TransferFluidRequirement {
        subject pumpSubsystem : AldgatePumpingSubsystem;
        objective {
            doc /* The subsystem shall transfer fluid from the source tank to the destination tank. */
        }
        require satisfied pumpSubsystem.transfersFluid == true;
    }

    requirement def MinFlowRateRequirement {
        subject pumpSubsystem : AldgatePumpingSubsystem;
        attribute minFlowRate : FlowRateUnit = 50 [L/min];
        objective {
            doc /* The subsystem shall maintain a minimum flow rate during active pumping. */
        }
        require satisfied pumpSubsystem.measuredFlowRate >= minFlowRate;
    }

    requirement def MaxPressureRequirement {
        subject pumpSubsystem : AldgatePumpingSubsystem;
        attribute maxPressure : PressureUnit = 6.0 [bar];
        objective {
            doc /* The subsystem shall operate below a maximum pressure limit. */
        }
        require satisfied pumpSubsystem.dischargePressure <= maxPressure;
    }

    requirement def SourceTankCapacityRequirement {
        attribute sourceCapacity : VolumeUnit = 10000 [L];
        objective {
            doc /* The source tank shall have a capacity of 10,000 liters. */
        }
    }

    requirement def DestinationTankCapacityRequirement {
        attribute destinationCapacity : VolumeUnit = 15000 [L];
        objective {
            doc /* The destination tank shall have a capacity of 15,000 liters. */
        }
    }

    requirement def SafeOperationRequirement {
        subject pumpSubsystem : AldgatePumpingSubsystem;
        objective {
            doc /* The pump shall stop when source is below minimum level or destination is above maximum capacity. */
        }
        require satisfied {
            if pumpSubsystem.sourceLevelLow or pumpSubsystem.destinationLevelHigh then
                pumpSubsystem.pumpRunning == false
            else true
        }
    }

    // ===== Part Definitions =====
    part def SourceTank {
        attribute capacity : VolumeUnit = 10000 [L];
        attribute currentVolume : VolumeUnit;
        attribute minOperatingLevel : VolumeUnit = 500 [L];
        attribute maxLevel : VolumeUnit = 10000 [L];
        attribute levelLow : Boolean;
        port fluidOut : FluidFlow;
        perform action updateLevel(in delta : VolumeUnit);
    }

    part def DestinationTank {
        attribute capacity : VolumeUnit = 15000 [L];
        attribute currentVolume : VolumeUnit;
        attribute maxCapacity : VolumeUnit = 15000 [L];
        attribute minLevel : VolumeUnit = 0 [L];
        attribute levelHigh : Boolean;
        port fluidIn : FluidFlow;
        perform action updateLevel(in delta : VolumeUnit);
    }

    part def Motor {
        attribute ratedPower : PowerUnit = 5.5 [kW];
        attribute ratedSpeed : RotationalSpeedUnit = 1450 [rpm];
        attribute active : Boolean;
        port powerIn : PowerFlow;
        port driveOut : MechanicalDrive;
        perform action start();
        perform action stop();
    }

    part def Impeller {
        attribute diameter : Real = 0.15;
        attribute speed : RotationalSpeedUnit;
        port driveIn : MechanicalDrive;
        port suctionPort : FluidFlow;
        port dischargePort : FluidFlow;
    }

    part def AldgatePump {
        part motor : Motor;
        part impeller : Impeller;
        attribute running : Boolean;
        port suction : FluidFlow;
        port discharge : FluidFlow;
        port command : PumpCommand;
        perform action startPump() {
            assign motor.active := true;
            assign running := true;
        }
        perform action stopPump() {
            assign motor.active := false;
            assign running := false;
        }
    }

    part def FlowMeter {
        attribute measuredFlowRate : FlowRateUnit;
        port flowPort : FluidFlow;
        port reading : FlowReading;
        perform action measureFlow();
    }

    part def PressureSensor {
        attribute measuredPressure : PressureUnit;
        port pressurePort : FluidFlow;
        port reading : PressureReading;
        perform action measurePressure();
    }

    part def LevelSensor {
        attribute measuredLevel : LevelUnit;
        port reading : LevelReading;
        perform action measureLevel();
    }

    part def Controller {
        attribute sourceLevelLow : Boolean;
        attribute destinationLevelHigh : Boolean;
        attribute measuredFlowRate : FlowRateUnit;
        attribute dischargePressure : PressureUnit;
        attribute suctionPressure : PressureUnit;
        attribute pumpRunning : Boolean;
        attribute minFlowRate : FlowRateUnit = 50 [L/min];
        attribute maxPressure : PressureUnit = 6.0 [bar];
        port sourceLevelIn : LevelReading;
        port destinationLevelIn : LevelReading;
        port flowIn : FlowReading;
        port suctionPressureIn : PressureReading;
        port dischargePressureIn : PressureReading;
        port pumpCommandOut : PumpCommand;
        state machine controlStateMachine {
            entry;
            then Idle;
            state Idle {
                entry {
                    assign pumpRunning := false;
                    send PumpCommand(run=false) to pumpCommandOut;
                }
            }
            transition from Idle to Monitoring
                when sourceLevelIn.level > 0 [m] and destinationLevelIn.level < 15 [m];
            state Monitoring {
                entry {
                    assign pumpRunning := true;
                    send PumpCommand(run=true) to pumpCommandOut;
                }
            }
            transition from Monitoring to Idle
                when sourceLevelIn.level <= 0.05 [m] or destinationLevelIn.level >= 14.95 [m] or dischargePressureIn.pressure >= maxPressure;
            transition from Monitoring to Fault
                when dischargePressureIn.pressure >= maxPressure;
            state Fault {
                entry {
                    assign pumpRunning := false;
                    send PumpCommand(run=false) to pumpCommandOut;
                }
            }
        }
        perform action evaluateConditions() {
            assign sourceLevelLow := sourceLevelIn.level <= 0.05 [m];
            assign destinationLevelHigh := destinationLevelIn.level >= 14.95 [m];
        }
    }

    // ===== Top-level Subsystem =====
    part def AldgatePumpingSubsystem {
        attribute transfersFluid : Boolean = true;
        attribute measuredFlowRate : FlowRateUnit;
        attribute dischargePressure : PressureUnit;
        attribute sourceLevelLow : Boolean;
        attribute destinationLevelHigh : Boolean;
        attribute pumpRunning : Boolean;

        part sourceTank : SourceTank {
            attribute currentVolume := 8000 [L];
        }
        part destinationTank : DestinationTank {
            attribute currentVolume := 3000 [L];
        }
        part pump : AldgatePump;
        part flowMeter : FlowMeter;
        part suctionPressureSensor : PressureSensor;
        part dischargePressureSensor : PressureSensor;
        part sourceLevelSensor : LevelSensor;
        part destinationLevelSensor : LevelSensor;
        part controller : Controller;

        connections {
            flow sourceTank.fluidOut to pump.suction;
            flow pump.discharge to destinationTank.fluidIn;
            flow pump.suction to suctionPressureSensor.pressurePort;
            flow pump.discharge to dischargePressureSensor.pressurePort;
            flow pump.discharge to flowMeter.flowPort;
            bind sourceLevelSensor.reading to controller.sourceLevelIn;
            bind destinationLevelSensor.reading to controller.destinationLevelIn;
            bind flowMeter.reading to controller.flowIn;
            bind suctionPressureSensor.reading to controller.suctionPressureIn;
            bind dischargePressureSensor.reading to controller.dischargePressureIn;
            bind controller.pumpCommandOut to pump.command;
            bind pump.motor.powerIn to pump.motor.powerIn;
            bind pump.motor.driveOut to pump.impeller.driveIn;
            bind pump.impeller.suctionPort to pump.suction;
            bind pump.impeller.dischargePort to pump.discharge;
        }

        satisfy TransferFluidRequirement;
        satisfy MinFlowRateRequirement;
        satisfy MaxPressureRequirement;
        satisfy SafeOperationRequirement;
    }
}
