package IntelligentWaterDeliverySystem {

    import ScalarValues::*;
    import ScalarFunctions::*;

    // ===== Value Types with Units =====
    value type Volume :> Real { unit "gal"; }
    value type Energy :> Real { unit "Wh"; }
    value type Power :> Real { unit "W"; }
    value type FlowRate :> Real { unit "gal/min"; }
    value type Efficiency :> Real { unit "gal/Wh"; }
    value type Pressure :> Real { unit "psi"; }
    value type RotationalSpeed :> Real { unit "rpm"; }
    value type TimeDuration :> Real { unit "s"; }
    value type Dimensionless :> Real { unit ""; }

    // ===== Item Definitions =====
    item def Water;

    item def ElectricalEnergy {
        attribute voltage : Real;
        attribute current : Real;
    }

    item def EnergyData {
        attribute instantaneousPower : Power;
        attribute cumulativeEnergy : Energy;
        attribute timestamp : TimeDuration;
    }

    item def FlowData {
        attribute flowRate : FlowRate;
        attribute cumulativeVolume : Volume;
        attribute timestamp : TimeDuration;
    }

    item def EfficiencyData {
        attribute measuredEfficiency : Efficiency;
        attribute targetEfficiency : Efficiency;
        attribute deviation : Dimensionless;
        attribute timestamp : TimeDuration;
    }

    item def ControlCommand {
        attribute targetSpeed : RotationalSpeed;
        attribute speedDelta : RotationalSpeed;
        attribute timestamp : TimeDuration;
    }

    // ===== Port Definitions =====
    port def WaterFlowPort {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        out item water : Water;
    }

    port def ElectricalPowerPort {
        in item power : ElectricalEnergy;
    }

    port def EnergyDataPort {
        out item energyData : EnergyData;
    }

    port def FlowDataPort {
        out item flowData : FlowData;
    }

    port def EfficiencyDataPort {
        out item efficiencyData : EfficiencyData;
    }

    port def ControlCommandPort {
        in item command : ControlCommand;
    }

    // ===== Requirements =====
    requirement def EnergyEfficiencyRequirement {
        doc "The system shall maximize gallons of water delivered per watt-hour of electrical energy consumed.";
        attribute minTargetEfficiency : Efficiency = 0.5 [gal/Wh];
        subject deliverySystem : IntelligentWaterDeliverySystem;
        require deliverySystem.measuredEfficiency >= minTargetEfficiency;
    }

    requirement def ClosedLoopControlRequirement {
        doc "The system shall continuously monitor efficiency and adjust pump speed to optimize performance.";
        attribute maxControlCycleTime : TimeDuration = 1 [s];
        subject controller : SystemController;
        require controller.controlCyclePeriod <= maxControlCycleTime;
    }

    requirement def WaterDeliveryRequirement {
        doc "The system shall deliver water from the reservoir to the distribution network at adequate pressure.";
        attribute minDeliveryPressure : Pressure = 30 [psi];
        subject pump : PumpUnit;
        require pump.dischargePressure >= minDeliveryPressure;
    }

    requirement def ReservoirProtectionRequirement {
        doc "The system shall halt pumping when the reservoir level falls below the minimum safe level.";
        subject reservoir : WaterReservoir;
        require reservoir.currentLevel >= reservoir.minLevel;
    }

    // ===== Component Part Definitions =====
    part def WaterReservoir {
        attribute capacity : Volume = 5000 [gal];
        attribute currentLevel : Volume = 2500 [gal];
        attribute minLevel : Volume = 100 [gal];
        attribute maxLevel : Volume = 5000 [gal];

        port waterSupply : WaterFlowPort;

        action def supplyWater {
            in requestedVolume : Volume;
            out deliveredVolume : Volume;
            out outletPressure : Pressure;
        }

        state reservoirState {
            entry; then normal;
            state normal {
                entry do assign waterSupply.pressure = 14.7 [psi];
            }
            state lowLevel;
            transition normal -> lowLevel
                when currentLevel <= minLevel
                do assign waterSupply.pressure = 0 [psi];
            transition lowLevel -> normal
                when currentLevel > minLevel
                do assign waterSupply.pressure = 14.7 [psi];
        }
    }

    part def PumpUnit {
        attribute nominalSpeed : RotationalSpeed = 1800 [rpm];
        attribute minSpeed : RotationalSpeed = 600 [rpm];
        attribute maxSpeed : RotationalSpeed = 3500 [rpm];
        attribute currentSpeed : RotationalSpeed = 1800 [rpm];
        attribute intakePressure : Pressure;
        attribute dischargePressure : Pressure;
        attribute instantaneousPower : Power;

        port waterIntake : ~WaterFlowPort;
        port waterDischarge : WaterFlowPort;
        port powerInput : ElectricalPowerPort;
        port speedCommand : ControlCommandPort;

        action def pumpWater {
            in speed : RotationalSpeed;
            in intakePressure : Pressure;
            out dischargePressure : Pressure;
            out flow : FlowRate;
            out power : Power;
        }

        action def applySpeedCommand {
            in command : ControlCommand;
            out newSpeed : RotationalSpeed;
        }

        state pumpOperation {
            entry; then idle;
            state idle {
                entry do assign currentSpeed = 0 [rpm];
                entry do assign dischargePressure = 0 [psi];
                entry do assign instantaneousPower = 0 [W];
            }
            state running {
                entry do assign currentSpeed = nominalSpeed;
            }
            transition idle -> running
                when speedCommand.command.targetSpeed > 0 [rpm]
                do assign currentSpeed = speedCommand.command.targetSpeed;
            transition running -> idle
                when speedCommand.command.targetSpeed == 0 [rpm]
                do assign currentSpeed = 0 [rpm];
            transition running -> running
                when speedCommand.command.targetSpeed != currentSpeed
                do assign currentSpeed = speedCommand.command.targetSpeed;
        }
    }

    part def EnergyMonitor {
        attribute samplingInterval : TimeDuration = 0.5 [s];
        attribute measuredPower : Power;
        attribute cumulativeEnergy : Energy = 0 [Wh];

        port monitoredPower : ElectricalPowerPort;
        port energyDataOut : EnergyDataPort;

        action def measurePower {
            in power : ElectricalEnergy;
            out instantaneousPower : Power;
        }

        action def accumulateEnergy {
            in power : Power;
            in duration : TimeDuration;
            out energy : Energy;
        }

        action def publishEnergyData {
            out data : EnergyData;
        }

        state monitoring {
            entry; then sampling;
            state sampling {
                do measurePower;
                then accumulating;
            }
            state accumulating {
                do accumulateEnergy;
                then transmitting;
            }
            state transmitting {
                do publishEnergyData;
                then sampling;
            }
        }
    }

    part def FlowMonitor {
        attribute samplingInterval : TimeDuration = 0.5 [s];
        attribute measuredFlowRate : FlowRate;
        attribute cumulativeVolume : Volume = 0 [gal];

        port waterFlow : ~WaterFlowPort;
        port flowDataOut : FlowDataPort;

        action def measureFlow {
            in water : Water;
            out flowRate : FlowRate;
        }

        action def accumulateVolume {
            in flowRate : FlowRate;
            in duration : TimeDuration;
            out volume : Volume;
        }

        action def publishFlowData {
            out data : FlowData;
        }

        state monitoring {
            entry; then sampling;
            state sampling {
                do measureFlow;
                then accumulating;
            }
            state accumulating {
                do accumulateVolume;
                then transmitting;
            }
            state transmitting {
                do publishFlowData;
                then sampling;
            }
        }
    }

    part def EfficiencyAnalyzer {
        attribute calculatedEfficiency : Efficiency;
        attribute targetEfficiency : Efficiency = 0.6 [gal/Wh];
        attribute windowSize : TimeDuration = 10 [s];
        attribute lastDeviation : Dimensionless;

        port energyDataIn : ~EnergyDataPort;
        port flowDataIn : ~FlowDataPort;
        port efficiencyDataOut : EfficiencyDataPort;

        action def calculateEfficiency {
            in energy : Energy;
            in volume : Volume;
            out efficiency : Efficiency;
        }

        action def computeDeviation {
            in measured : Efficiency;
            in target : Efficiency;
            out deviation : Dimensionless;
        }

        action def publishEfficiencyData {
            out data : EfficiencyData;
        }

        state analyzing {
            entry; then collecting;
            state collecting {
                do calculateEfficiency;
                then evaluating;
            }
            state evaluating {
                do computeDeviation;
                then reporting;
            }
            state reporting {
                do publishEfficiencyData;
                then collecting;
            }
        }
    }

    part def SystemController {
        attribute targetEfficiency : Efficiency = 0.6 [gal/Wh];
        attribute currentEfficiency : Efficiency;
        attribute controlCyclePeriod : TimeDuration = 1 [s];
        attribute speedAdjustmentStep : RotationalSpeed = 50 [rpm];
        attribute lastCommand : ControlCommand;
        attribute currentDeviation : Dimensionless;

        port efficiencyDataIn : ~EfficiencyDataPort;
        port pumpCommandOut : ControlCommandPort;

        action def compareEfficiency {
            in measured : Efficiency;
            in target : Efficiency;
            out deviation : Dimensionless;
        }

        action def computeAdjustment {
            in deviation : Dimensionless;
            in currentSpeed : RotationalSpeed;
            out targetSpeed : RotationalSpeed;
        }

        action def issueCommand {
            in targetSpeed : RotationalSpeed;
            out command : ControlCommand;
        }

        state controlLoop {
            entry; then monitoring;
            state monitoring {
                do compareEfficiency;
                then deciding;
            }
            state deciding {
                do computeAdjustment;
                then commanding;
            }
            state commanding {
                do issueCommand;
                then monitoring;
            }
        }
    }

    part def DistributionNetwork {
        attribute pipeLength : Real = 500;
        attribute pipeDiameter : Real = 4;
        attribute deliveryPressure : Pressure;
        attribute totalDelivered : Volume = 0 [gal];
        attribute numberOfDeliveryPoints : Integer = 12;

        port waterInput : ~WaterFlowPort;

        action def distributeWater {
            in water : Water;
            in pressure : Pressure;
            out delivered : Volume;
        }

        state distribution {
            entry; then delivering;
            state delivering {
                do distributeWater;
            }
        }
    }

    // ===== System Assembly =====
    part def IntelligentWaterDeliverySystem {

        attribute measuredEfficiency : Efficiency;
        attribute totalWaterDelivered : Volume;
        attribute totalEnergyConsumed : Energy;

        part reservoir : WaterReservoir;
        part pump : PumpUnit;
        part energyMonitor : EnergyMonitor;
        part flowMonitor : FlowMonitor;
        part efficiencyAnalyzer : EfficiencyAnalyzer;
        part controller : SystemController;
        part distribution : DistributionNetwork;

        // Water flow connections
        connection reservoirToPump connect reservoir.waterSupply to pump.waterIntake;
        connection pumpToFlowMonitor connect pump.waterDischarge to flowMonitor.waterFlow;
        connection pumpToDistribution connect pump.waterDischarge to distribution.waterInput;

        // Electrical power monitoring
        connection pumpPowerToMonitor connect pump.powerInput to energyMonitor.monitoredPower;

        // Data flow connections
        connection energyDataFlow connect energyMonitor.energyDataOut to efficiencyAnalyzer.energyDataIn;
        connection flowDataFlow connect flowMonitor.flowDataOut to efficiencyAnalyzer.flowDataIn;
        connection efficiencyDataFlow connect efficiencyAnalyzer.efficiencyDataOut to controller.efficiencyDataIn;
        connection commandFlow connect controller.pumpCommandOut to pump.speedCommand;

        // Requirements satisfaction
        satisfy EnergyEfficiencyRequirement by self;
        satisfy ClosedLoopControlRequirement by controller;
        satisfy WaterDeliveryRequirement by pump;
        satisfy ReservoirProtectionRequirement by reservoir;

        // System-level state machine
        state systemOperation {
            entry; then initializing;
            state initializing {
                do assign pump.currentSpeed = pump.nominalSpeed;
                then normalOperation;
            }
            state normalOperation;
            state shutdown;
            transition normalOperation -> shutdown
                when reservoir.currentLevel <= reservoir.minLevel;
        }
    }
}
