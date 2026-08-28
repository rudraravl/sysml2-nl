package BoilerFeedwaterPumpingSubsystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQVolume::*;
    import ISQFlowRate::*;
    import ISQPressure::*;
    import ISQEnergy::*;
    import ISQPower::*;
    import ISQTemperature::*;
    import ISQSpeed::*;

    // ---- Value Types ----
    value def PressureBar :> Real { unit = "bar"; }
    value def FlowRateM3PerHr :> Real { unit = "m3/hr"; }
    value def FlowRateKgPerS :> Real { unit = "kg/s"; }
    value def RotationalSpeedRPM :> Real { unit = "rpm"; }
    value def PowerkW :> Real { unit = "kW"; }
    value def TemperatureCelsius :> Real { unit = "degC"; }
    value def Percent :> Real { unit = "%"; }
    value def ElapsedTimeSec :> Real { unit = "s"; }

    // ---- Item Types ----
    item def Feedwater {
        attribute temperature : TemperatureCelsius;
        attribute density : Real = 1000;
    }

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute frequency : Real;
    }

    item def ControlSignal {
        attribute command : String;
        attribute setpoint : Real;
    }

    item def SensorReading {
        attribute measuredValue : Real;
        attribute quality : String;
    }

    // ---- Port Definitions ----
    port def FluidPort {
        out item feedwater : Feedwater;
        attribute pressure : PressureBar;
        attribute flowRate : FlowRateM3PerHr;
    }

    port def FluidInPort :> FluidPort {
        in item feedwater : Feedwater;
    }

    port def FluidOutPort :> FluidPort {
        out item feedwater : Feedwater;
    }

    port def ElectricalPort {
        in item power : ElectricalPower;
    }

    port def ControlPort {
        in item command : ControlSignal;
        out item feedback : SensorReading;
    }

    // ---- Requirements ----
    requirement def FeedwaterFlowRequirement {
        doc /* The subsystem shall deliver feedwater at a minimum flow rate to the boiler. */
        attribute minFlowRate : FlowRateM3PerHr = 200;
        attribute maxFlowRate : FlowRateM3PerHr = 400;
        subject subsystemFlow : FlowRateM3PerHr;
        constraint { minFlowRate <= subsystemFlow <= maxFlowRate }
    }

    requirement def BoilerPressureRequirement {
        doc /* The subsystem shall deliver feedwater at sufficient pressure to overcome boiler pressure. */
        attribute minDischargePressure : PressureBar = 180;
        subject dischargePressure : PressureBar;
        constraint { dischargePressure >= minDischargePressure }
    }

    requirement def EnergyEfficiencyRequirement {
        doc /* The subsystem shall operate within specified energy consumption limits. */
        attribute maxSpecificEnergy : Real = 0.25; // kWh per m3
        subject specificEnergy : Real;
        constraint { specificEnergy <= maxSpecificEnergy }
    }

    requirement def RedundancyRequirement {
        doc /* The subsystem shall maintain at least one operational pump line at all times. */
        attribute minActiveLines : Integer = 1;
        subject activeLines : Integer;
        constraint { activeLines >= minActiveLines }
    }

    requirement def ReliabilityRequirement {
        doc /* The subsystem shall achieve a minimum mean time between failures. */
        attribute minMTBF : ElapsedTimeSec = 2_592_000; // 30 days in seconds
        subject achievedMTBF : ElapsedTimeSec;
        constraint { achievedMTBF >= minMTBF }
    }

    // ---- State Machine for Pump Controller ----
    state def PumpControlStates {
        entry; then state stopped;
        state stopped {
            entry { /* Pump de-energized, motor off */ }
            transition stopped_to_starting
                first stopped
                accept StartCommand
                then starting;
        }
        state starting {
            entry { /* Initiate ramp-up sequence */ }
            do { /* Ramp motor speed from 0 to operating speed */ }
            transition starting_to_running
                first starting
                accept RampComplete
                then running;
            transition starting_to_tripped
                first starting
                accept Fault
                then tripped;
        }
        state running {
            entry { /* Pump at full operating speed */ }
            do { /* Monitor sensors, regulate speed */ }
            transition running_to_stopping
                first running
                accept StopCommand
                then stopping;
            transition running_to_tripped
                first running
                accept Fault
                then tripped;
        }
        state stopping {
            entry { /* Initiate ramp-down sequence */ }
            do { /* Ramp motor speed down to zero */ }
            transition stopping_to_stopped
                first stopping
                accept RampComplete
                then stopped;
            transition stopping_to_tripped
                first stopping
                accept Fault
                then tripped;
        }
        state tripped {
            entry { /* Emergency shutdown, isolate pump */ }
            do { /* Log fault, await manual reset */ }
            transition tripped_to_stopped
                first tripped
                accept ResetCommand
                then stopped;
        }
    }

    // ---- Action Definitions ----
    action def RampUp {
        in initialSpeed : RotationalSpeedRPM;
        in targetSpeed : RotationalSpeedRPM;
        in rampRate : Real;
        out achievedSpeed : RotationalSpeedRPM;
    }

    action def RampDown {
        in initialSpeed : RotationalSpeedRPM;
        in targetSpeed : RotationalSpeedRPM;
        in rampRate : Real;
        out achievedSpeed : RotationalSpeedRPM;
    }

    action def MonitorSensors {
        in flowReading : SensorReading;
        in pressureReading : SensorReading;
        out status : String;
    }

    action def RegulateFlow {
        in setpoint : FlowRateM3PerHr;
        in currentFlow : FlowRateM3PerHr;
        out valvePosition : Percent;
        out speedCommand : RotationalSpeedRPM;
    }

    // ---- Part Definitions: Components ----
    part def DeaeratorTank {
        attribute capacity : FlowRateM3PerHr = 500;
        attribute operatingPressure : PressureBar = 1.5;
        attribute operatingTemperature : TemperatureCelsius = 105;
        port dischargePort : FluidOutPort;
        port levelSensorPort : ControlPort;
    }

    part def SuctionStrainer {
        attribute meshSize : Real = 0.5; // mm
        attribute maxDifferentialPressure : PressureBar = 0.5;
        port inletPort : FluidInPort;
        port outletPort : FluidOutPort;
    }

    part def MechanicalSeal {
        attribute sealType : String = "Mechanical";
        attribute maxPressure : PressureBar = 250;
        attribute leakageRate : FlowRateKgPerS = 0.001;
    }

    part def Impeller {
        attribute diameter : Real = 0.35; // meters
        attribute numberOfBlades : Integer = 7;
        attribute ratedSpeed : RotationalSpeedRPM = 3550;
    }

    part def PumpCasing {
        attribute material : String = "Stainless Steel 316L";
        attribute designPressure : PressureBar = 250;
        attribute inletDiameter : Real = 0.20; // meters
        attribute outletDiameter : Real = 0.15; // meters;
    }

    part def PumpMotor {
        attribute ratedPower : PowerkW = 1500;
        attribute ratedVoltage : Real = 6600;
        attribute ratedSpeed : RotationalSpeedRPM = 3550;
        attribute efficiency : Percent = 96.5;
        port powerPort : ElectricalPort;
    }

    part def BoilerFeedwaterPump {
        attribute ratedFlow : FlowRateM3PerHr = 250;
        attribute ratedHead : PressureBar = 200;
        attribute ratedSpeed : RotationalSpeedRPM = 3550;
        port suctionPort : FluidInPort;
        port dischargePort : FluidOutPort;
        port motorPowerPort : ElectricalPort;
        part motor : PumpMotor;
        part impeller : Impeller;
        part casing : PumpCasing;
        part mechanicalSeal : MechanicalSeal[2];
        connection motorToImpeller connect motor to impeller;
        connection impellerInCasing connect impeller to casing;
        connection sealToCasing connect mechanicalSeal to casing;
    }

    part def CheckValve {
        attribute type : String = "Swing Check";
        attribute crackingPressure : PressureBar = 0.3;
        attribute maxPressure : PressureBar = 250;
        port inletPort : FluidInPort;
        port outletPort : FluidOutPort;
    }

    part def ControlValve {
        attribute type : String = "Globe Control Valve";
        attribute cv : Real = 400;
        attribute actuatorType : String = "Pneumatic";
        attribute position : Percent;
        port inletPort : FluidInPort;
        port outletPort : FluidOutPort;
        port controlPort : ControlPort;
    }

    part def FlowTransmitter {
        attribute type : String = "Electromagnetic";
        attribute rangeMin : FlowRateM3PerHr = 0;
        attribute rangeMax : FlowRateM3PerHr = 500;
        attribute accuracy : Percent = 0.5;
        port fluidPort : FluidInPort;
        port signalPort : ControlPort;
    }

    part def PressureTransmitter {
        attribute type : String = "Piezoresistive";
        attribute rangeMin : PressureBar = 0;
        attribute rangeMax : PressureBar = 300;
        attribute accuracy : Percent = 0.25;
        port fluidPort : FluidInPort;
        port signalPort : ControlPort;
    }

    part def PumpController {
        attribute controllerType : String = "PLC";
        attribute scanTime : Real = 0.01; // seconds
        exhibit state machine : PumpControlStates;
        port controlPort : ControlPort;
        port sensorPort : ControlPort;
        action rampUp : RampUp;
        action rampDown : RampDown;
        action monitor : MonitorSensors;
        action regulate : RegulateFlow;
    }

    // ---- Part Definition: Pump Line ----
    part def PumpLine {
        attribute lineId : String;
        port lineInlet : FluidInPort;
        port lineOutlet : FluidOutPort;
        part strainer : SuctionStrainer;
        part pump : BoilerFeedwaterPump;
        part checkValve : CheckValve;
        part flowTransmitter : FlowTransmitter;
        part pressureTransmitter : PressureTransmitter;
        part controller : PumpController;
        connection strainerToPump connect strainer.outletPort to pump.suctionPort;
        connection pumpToCheckValve connect pump.dischargePort to checkValve.inletPort;
        connection checkValveToFlowTX connect checkValve.outletPort to flowTransmitter.fluidPort;
        connection flowTXToPressureTX connect flowTransmitter.fluidPort to pressureTransmitter.fluidPort;
        connection pressureTXToOutlet connect pressureTransmitter.fluidPort to lineOutlet;
        connection controllerToPump connect controller.controlPort to pump.motorPowerPort;
        connection flowTXToController connect flowTransmitter.signalPort to controller.sensorPort;
        connection pressureTXToController connect pressureTransmitter.signalPort to controller.sensorPort;
    }

    // ---- Top-level Subsystem ----
    part def BoilerFeedwaterPumpingSubsystem {
        attribute systemId : String = "BFP-001";
        port deaeratorInlet : FluidInPort;
        port boilerOutlet : FluidOutPort;
        part deaerator : DeaeratorTank;
        part pumpLineA : PumpLine {
            attribute lineId = "Line-A";
        }
        part pumpLineB : PumpLine {
            attribute lineId = "Line-B";
        }
        part finalControlValve : ControlValve;
        part systemFlowTransmitter : FlowTransmitter;
        part systemPressureTransmitter : PressureTransmitter;
        part supervisoryController : PumpController {
            attribute controllerType = "SCADA";
        }

        // Connections from deaerator to pump lines
        connection deaeratorToLineA connect deaerator.dischargePort to pumpLineA.lineInlet;
        connection deaeratorToLineB connect deaerator.dischargePort to pumpLineB.lineInlet;

        // Connections from pump lines to common header (final control valve)
        connection lineAToControlValve connect pumpLineA.lineOutlet to finalControlValve.inletPort;
        connection lineBToControlValve connect pumpLineB.lineOutlet to finalControlValve.inletPort;

        // Connections through final control valve to sensors and boiler
        connection controlValveToFlowTX connect finalControlValve.outletPort to systemFlowTransmitter.fluidPort;
        connection flowTXToPressureTX connect systemFlowTransmitter.fluidPort to systemPressureTransmitter.fluidPort;
        connection pressureTXToBoiler connect systemPressureTransmitter.fluidPort to boilerOutlet;

        // Control connections
        connection supervisoryToControlValve connect supervisoryController.controlPort to finalControlValve.controlPort;
        connection lineAControllerToSupervisory connect pumpLineA.controller.controlPort to supervisoryController.sensorPort;
        connection lineBControllerToSupervisory connect pumpLineB.controller.controlPort to supervisoryController.sensorPort;
        connection systemFlowTXToSupervisory connect systemFlowTransmitter.signalPort to supervisoryController.sensorPort;
        connection systemPressureTXToSupervisory connect systemPressureTransmitter.signalPort to supervisoryController.sensorPort;

        // Requirements satisfaction
        satisfy FeedwaterFlowRequirement {
            subject subsystemFlow = systemFlowTransmitter.rangeMax;
        }
        satisfy BoilerPressureRequirement {
            subject dischargePressure = systemPressureTransmitter.rangeMax;
        }
        satisfy RedundancyRequirement {
            subject activeLines = 2;
        }
        satisfy EnergyEfficiencyRequirement {
            subject specificEnergy = 0.22;
        }
        satisfy ReliabilityRequirement {
            subject achievedMTBF = 2_700_000;
        }
    }

    // ---- Verification Actions ----
    action def VerifyFlowRate {
        in subsystem : BoilerFeedwaterPumpingSubsystem;
        in requiredFlow : FlowRateM3PerHr;
        out result : Boolean;
    }

    action def VerifyPressure {
        in subsystem : BoilerFeedwaterPumpingSubsystem;
        in requiredPressure : PressureBar;
        out result : Boolean;
    }

    action def VerifyRedundancy {
        in subsystem : BoilerFeedwaterPumpingSubsystem;
        out result : Boolean;
    }

    action def VerifyEnergyEfficiency {
        in subsystem : BoilerFeedwaterPumpingSubsystem;
        in maxSpecificEnergy : Real;
        out result : Boolean;
    }
}
