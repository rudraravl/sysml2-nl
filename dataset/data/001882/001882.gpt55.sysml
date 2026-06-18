package VacuumTubeSystemModel {
    import ScalarValues::*;

    attribute def Voltage :> Real {
        attribute unitSymbol : String = "V";
    }

    attribute def Current :> Real {
        attribute unitSymbol : String = "A";
    }

    attribute def Resistance :> Real {
        attribute unitSymbol : String = "ohm";
    }

    attribute def Capacitance :> Real {
        attribute unitSymbol : String = "F";
    }

    attribute def Power :> Real {
        attribute unitSymbol : String = "W";
    }

    attribute def Temperature :> Real {
        attribute unitSymbol : String = "K";
    }

    attribute def Pressure :> Real {
        attribute unitSymbol : String = "Pa";
    }

    attribute def Time :> Real {
        attribute unitSymbol : String = "s";
    }

    attribute def Frequency :> Real {
        attribute unitSymbol : String = "Hz";
    }

    attribute def Gain :> Real {
        attribute unitSymbol : String = "V/V";
    }

    attribute def Transconductance :> Real {
        attribute unitSymbol : String = "S";
    }

    attribute def Length :> Real {
        attribute unitSymbol : String = "m";
    }

    attribute def Dimensionless :> Real {
        attribute unitSymbol : String = "1";
    }

    item def ElectricalSignal {
        attribute instantaneousVoltage : Voltage;
        attribute rmsVoltage : Voltage;
        attribute frequency : Frequency;
        attribute sourceImpedance : Resistance;
    }

    item def AmplifiedElectricalSignal :> ElectricalSignal {
        attribute voltageGain : Gain;
        attribute loadImpedance : Resistance;
    }

    item def ElectronStream {
        attribute electronCurrent : Current;
        attribute kineticEnergyEquivalentVoltage : Voltage;
        attribute modulationDepth : Dimensionless;
    }

    item def HeatFlow {
        attribute thermalPower : Power;
        attribute sourceTemperature : Temperature;
        attribute sinkTemperature : Temperature;
    }

    item def ResidualGas {
        attribute partialPressure : Pressure;
        attribute ionizationFraction : Dimensionless;
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    item def ControlCommand {
        attribute requestedEnergized : Boolean;
    }

    port def ElectricalTerminal {
        inout item energy : ElectricalEnergy;
        attribute terminalVoltage : Voltage;
        attribute terminalCurrent : Current;
    }

    port def SignalInputPort {
        in item signalIn : ElectricalSignal;
        attribute inputImpedance : Resistance;
        attribute maximumRmsVoltage : Voltage;
    }

    port def SignalOutputPort {
        out item signalOut : AmplifiedElectricalSignal;
        attribute outputImpedance : Resistance;
        attribute maximumRmsVoltage : Voltage;
    }

    port def ElectronFlowPort {
        inout item electrons : ElectronStream;
        attribute localPotential : Voltage;
    }

    port def ThermalPort {
        inout item heat : HeatFlow;
        attribute surfaceTemperature : Temperature;
    }

    port def VacuumPort {
        inout item gas : ResidualGas;
        attribute absolutePressure : Pressure;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    part def GlassEnvelope {
        attribute material : String = "borosilicate glass";
        attribute internalPressure : Pressure = 0.00001;
        attribute maximumSafeTemperature : Temperature = 520.0;
        attribute wallThickness : Length = 0.0012;
        attribute leakRate : Pressure = 0.000000001;
        port internalVacuum : VacuumPort;
        port outerSurfaceThermal : ThermalPort;
    }

    part def Getter {
        attribute material : String = "barium flash getter";
        attribute gasAbsorptionCapacity : Dimensionless = 1.0;
        attribute activationTemperature : Temperature = 900.0;
        port vacuumInterface : VacuumPort;
    }

    part def HeaterFilament {
        attribute material : String = "tungsten";
        attribute ratedVoltage : Voltage = 6.3;
        attribute ratedCurrent : Current = 0.3;
        attribute ratedPower : Power = 1.89;
        attribute warmupDuration : Time = 12.0;
        attribute normalTemperature : Temperature = 1250.0;
        port terminalA : ElectricalTerminal;
        port terminalB : ElectricalTerminal;
        port heatOut : ThermalPort;
    }

    part def OxideCathode {
        attribute coating : String = "barium strontium oxide";
        attribute emissionTemperature : Temperature = 1050.0;
        attribute maximumEmissionCurrent : Current = 0.02;
        attribute cathodeSleevePotential : Voltage = 0.0;
        attribute heaterCathodeInsulationResistance : Resistance = 100000000.0;
        port terminal : ElectricalTerminal;
        port heaterThermalIn : ThermalPort;
        port electronEmitter : ElectronFlowPort;
        port vacuumInterface : VacuumPort;
    }

    part def ControlGrid {
        attribute material : String = "molybdenum wire";
        attribute nominalBiasVoltage : Voltage = -1.5;
        attribute maximumPositiveGridVoltage : Voltage = 0.0;
        attribute gridLeakResistance : Resistance = 1000000.0;
        attribute gridCathodeSpacing : Length = 0.00035;
        port terminal : ElectricalTerminal;
        port electronModulationRegion : ElectronFlowPort;
        port vacuumInterface : VacuumPort;
    }

    part def AnodePlate {
        attribute material : String = "nickel-coated steel";
        attribute nominalPlateVoltage : Voltage = 250.0;
        attribute maximumDissipation : Power = 2.5;
        attribute plateArea : Dimensionless = 1.0;
        port terminal : ElectricalTerminal;
        port electronCollector : ElectronFlowPort;
        port thermalOut : ThermalPort;
        port vacuumInterface : VacuumPort;
    }

    part def TubeBase {
        attribute pinCount : Dimensionless = 9.0;
        attribute dielectricMaterial : String = "mica-filled phenolic";
        attribute isolationResistance : Resistance = 1000000000.0;
        port heaterPinA : ElectricalTerminal;
        port heaterPinB : ElectricalTerminal;
        port cathodePin : ElectricalTerminal;
        port gridPin : ElectricalTerminal;
        port platePin : ElectricalTerminal;
    }

    action def HeatCathode {
        in heaterVoltage : Voltage;
        in heaterCurrent : Current;
        out cathodeTemperature : Temperature;
        out emissionReady : Boolean;
        attribute nominalWarmupTime : Time = 12.0;
    }

    action def EmitElectrons {
        in cathodeTemperature : Temperature;
        in cathodePotential : Voltage;
        out emittedCurrent : Current;
        out electronStream : ElectronStream;
    }

    action def ModulateElectronStream {
        in gridVoltage : Voltage;
        in cathodeVoltage : Voltage;
        in incomingStream : ElectronStream;
        out modulatedStream : ElectronStream;
        attribute controlSensitivity : Transconductance = 0.0022;
    }

    action def CollectElectronsAtPlate {
        in plateVoltage : Voltage;
        in modulatedStream : ElectronStream;
        out plateCurrent : Current;
        out plateHeat : HeatFlow;
    }

    action def AmplifyVoltageSignal {
        in smallSignalInput : ElectricalSignal;
        in plateSupplyVoltage : Voltage;
        out amplifiedOutput : AmplifiedElectricalSignal;
        attribute nominalVoltageGain : Gain = 18.0;
        attribute lowerBandwidthLimit : Frequency = 20.0;
        attribute upperBandwidthLimit : Frequency = 20000.0;
    }

    state def TubeOperationalStates {
        attribute heaterTemperature : Temperature;
        attribute cathodeEmissionAvailable : Boolean;
        attribute plateVoltagePresent : Boolean;

        state Off;
        state HeaterWarmup;
        state EmissionReady;
        state Amplifying;
        state Standby;
        state Fault;

        transition InitialToOff first Off;

        transition PowerApplied
            from Off
            to HeaterWarmup
            accept ControlCommand
            do HeatCathode;

        transition WarmupComplete
            from HeaterWarmup
            to EmissionReady
            if heaterTemperature >= 1050.0;

        transition HighVoltageApplied
            from EmissionReady
            to Amplifying
            if plateVoltagePresent == true;

        transition InputMuted
            from Amplifying
            to Standby
            if cathodeEmissionAvailable == true;

        transition InputRestored
            from Standby
            to Amplifying
            if plateVoltagePresent == true;

        transition OverTemperature
            from Amplifying
            to Fault
            if heaterTemperature > 1400.0;

        transition PowerRemovedFromAny
            from HeaterWarmup
            to Off
            accept ControlCommand;

        transition FaultReset
            from Fault
            to Off
            accept ControlCommand;
    }

    part def VacuumTriodeTube {
        attribute tubeFamily : String = "high-vacuum thermionic triode";
        attribute primaryPhysicalPrinciple : String = "thermionic electron emission from a heated cathode and electrostatic modulation by a control grid in an evacuated envelope";
        attribute nominalTransconductance : Transconductance = 0.0022;
        attribute nominalAmplificationFactor : Gain = 20.0;
        attribute maximumPlateVoltage : Voltage = 300.0;
        attribute maximumPlateCurrent : Current = 0.012;
        attribute maximumEnvelopeTemperature : Temperature = 470.0;

        port heaterPositive : ElectricalTerminal;
        port heaterNegative : ElectricalTerminal;
        port cathodeTerminal : ElectricalTerminal;
        port gridTerminal : ElectricalTerminal;
        port plateTerminal : ElectricalTerminal;
        port envelopeHeat : ThermalPort;

        part envelope : GlassEnvelope;
        part getter : Getter;
        part heater : HeaterFilament;
        part cathode : OxideCathode;
        part controlGrid : ControlGrid;
        part anode : AnodePlate;
        part base : TubeBase;

        connect heaterPositive to base.heaterPinA;
        connect heaterNegative to base.heaterPinB;
        connect cathodeTerminal to base.cathodePin;
        connect gridTerminal to base.gridPin;
        connect plateTerminal to base.platePin;

        connect base.heaterPinA to heater.terminalA;
        connect base.heaterPinB to heater.terminalB;
        connect base.cathodePin to cathode.terminal;
        connect base.gridPin to controlGrid.terminal;
        connect base.platePin to anode.terminal;

        connect heater.heatOut to cathode.heaterThermalIn;
        connect anode.thermalOut to envelope.outerSurfaceThermal;
        connect envelope.outerSurfaceThermal to envelopeHeat;

        connect envelope.internalVacuum to getter.vacuumInterface;
        connect envelope.internalVacuum to cathode.vacuumInterface;
        connect envelope.internalVacuum to controlGrid.vacuumInterface;
        connect envelope.internalVacuum to anode.vacuumInterface;

        connect cathode.electronEmitter to controlGrid.electronModulationRegion;
        connect controlGrid.electronModulationRegion to anode.electronCollector;

        perform action cathodeHeating : HeatCathode;
        perform action thermionicEmission : EmitElectrons;
        perform action gridControl : ModulateElectronStream;
        perform action plateCollection : CollectElectronsAtPlate;

        exhibit state behavior tubeStates : TubeOperationalStates;
    }

    part def RectifiedHighVoltageSupply {
        attribute acInputVoltage : Voltage = 120.0;
        attribute dcOutputVoltage : Voltage = 250.0;
        attribute maximumOutputCurrent : Current = 0.03;
        attribute rippleVoltageRms : Voltage = 0.5;
        attribute bleederResistance : Resistance = 220000.0;
        port acInputLine : ElectricalTerminal;
        port acInputNeutral : ElectricalTerminal;
        port highVoltageOut : ElectricalTerminal;
        port returnOut : ElectricalTerminal;
    }

    part def HeaterSupply {
        attribute outputVoltage : Voltage = 6.3;
        attribute maximumOutputCurrent : Current = 1.0;
        attribute regulationTolerance : Dimensionless = 0.05;
        port supplyPositive : ElectricalTerminal;
        port supplyNegative : ElectricalTerminal;
    }

    part def BiasNetwork {
        attribute gridLeakResistance : Resistance = 1000000.0;
        attribute cathodeBiasResistance : Resistance = 1500.0;
        attribute cathodeBypassCapacitance : Capacitance = 0.000047;
        attribute nominalGridBias : Voltage = -1.5;
        port gridNode : ElectricalTerminal;
        port cathodeNode : ElectricalTerminal;
        port signalReference : ElectricalTerminal;
    }

    part def InputCouplingNetwork {
        attribute couplingCapacitance : Capacitance = 0.000000022;
        attribute maximumInputVoltageRms : Voltage = 2.0;
        attribute highPassCornerFrequency : Frequency = 20.0;
        port externalInput : SignalInputPort;
        port gridDrive : ElectricalTerminal;
        port reference : ElectricalTerminal;
    }

    part def PlateLoadNetwork {
        attribute plateLoadResistance : Resistance = 100000.0;
        attribute outputCouplingCapacitance : Capacitance = 0.0000001;
        attribute nominalQuiescentPlateCurrent : Current = 0.0012;
        attribute nominalQuiescentPlateVoltage : Voltage = 130.0;
        port highVoltageNode : ElectricalTerminal;
        port plateNode : ElectricalTerminal;
        port outputNode : ElectricalTerminal;
    }

    part def OutputLoad {
        attribute loadResistance : Resistance = 470000.0;
        attribute requiredMinimumSignalVoltageRms : Voltage = 5.0;
        port signalInputNode : ElectricalTerminal;
        port externalOutput : SignalOutputPort;
    }

    action def ProvideAmplifiedSignal {
        in inputSignal : ElectricalSignal;
        in supplyEnergy : ElectricalEnergy;
        out outputSignal : AmplifiedElectricalSignal;
        attribute intendedPrimaryFunction : String = "increase the voltage amplitude of an applied electrical signal by controlling anode current through a vacuum-tube triode";
        attribute nominalGain : Gain = 18.0;
    }

    state def AmplifierSystemStates {
        state DeEnergized;
        state Warming;
        state Ready;
        state AmplifyingSignal;
        state SafeShutdown;
        state Faulted;

        transition Start first DeEnergized;

        transition ApplyPower
            from DeEnergized
            to Warming
            accept ControlCommand;

        transition TubeReady
            from Warming
            to Ready;

        transition SignalPresent
            from Ready
            to AmplifyingSignal;

        transition SignalAbsent
            from AmplifyingSignal
            to Ready;

        transition ShutdownCommanded
            from Ready
            to SafeShutdown
            accept ControlCommand;

        transition ShutdownFromAmplifying
            from AmplifyingSignal
            to SafeShutdown
            accept ControlCommand;

        transition ShutdownComplete
            from SafeShutdown
            to DeEnergized;

        transition FaultDetected
            from AmplifyingSignal
            to Faulted;

        transition FaultCleared
            from Faulted
            to DeEnergized
            accept ControlCommand;
    }

    part def VacuumTubeVoltageAmplifier {
        attribute systemName : String = "single-ended vacuum-tube voltage amplifier";
        attribute primaryFunction : String = "The system uses a heated cathode, evacuated envelope, control grid, and positively biased anode to convert small input voltage variations into larger output voltage variations.";
        attribute nominalInputVoltageRms : Voltage = 0.25;
        attribute nominalOutputVoltageRms : Voltage = 4.5;
        attribute openLoopVoltageGain : Gain = 18.0;
        attribute nominalBandwidthLow : Frequency = 20.0;
        attribute nominalBandwidthHigh : Frequency = 20000.0;
        attribute maximumTouchSafeLeakageCurrent : Current = 0.0005;

        port commandIn : CommandPort;
        port mainsLine : ElectricalTerminal;
        port mainsNeutral : ElectricalTerminal;
        port audioInput : SignalInputPort;
        port audioOutput : SignalOutputPort;
        port chassisReference : ElectricalTerminal;
        port rejectedHeat : ThermalPort;

        part tube : VacuumTriodeTube;
        part highVoltageSupply : RectifiedHighVoltageSupply;
        part heaterSupply : HeaterSupply;
        part biasNetwork : BiasNetwork;
        part inputCoupler : InputCouplingNetwork;
        part plateLoad : PlateLoadNetwork;
        part load : OutputLoad;

        connect mainsLine to highVoltageSupply.acInputLine;
        connect mainsNeutral to highVoltageSupply.acInputNeutral;

        connect heaterSupply.supplyPositive to tube.heaterPositive;
        connect heaterSupply.supplyNegative to tube.heaterNegative;

        connect highVoltageSupply.highVoltageOut to plateLoad.highVoltageNode;
        connect highVoltageSupply.returnOut to chassisReference;

        connect audioInput to inputCoupler.externalInput;
        connect inputCoupler.gridDrive to biasNetwork.gridNode;
        connect biasNetwork.gridNode to tube.gridTerminal;

        connect biasNetwork.cathodeNode to tube.cathodeTerminal;
        connect biasNetwork.signalReference to chassisReference;

        connect plateLoad.plateNode to tube.plateTerminal;
        connect plateLoad.outputNode to load.signalInputNode;
        connect load.externalOutput to audioOutput;

        connect tube.envelopeHeat to rejectedHeat;

        perform action amplify : ProvideAmplifiedSignal;
        perform action smallSignalTubeAction : AmplifyVoltageSignal;

        exhibit state behavior amplifierStates : AmplifierSystemStates;
    }

    constraint def GainConsistency {
        in inputVoltage : Voltage;
        in outputVoltage : Voltage;
        in measuredGain : Gain;
        measuredGain == outputVoltage / inputVoltage;
    }

    constraint def PlateDissipationLimit {
        in plateVoltage : Voltage;
        in plateCurrent : Current;
        in plateDissipation : Power;
        plateDissipation == plateVoltage * plateCurrent;
    }

    constraint def VacuumIntegrityLimit {
        in internalPressure : Pressure;
        internalPressure <= 0.001;
    }

    requirement def PrimaryFunctionRequirement {
        subject amplifier : VacuumTubeVoltageAmplifier;
        require constraint {
            amplifier.openLoopVoltageGain >= 10.0
        }
    }

    requirement def VacuumTubeFunctionRequirement {
        subject tube : VacuumTriodeTube;
        require constraint {
            tube.nominalAmplificationFactor >= 15.0
        }
    }

    requirement def HeaterSupplyRequirement {
        subject heater : HeaterFilament;
        require constraint {
            heater.ratedVoltage >= 6.0 and heater.ratedVoltage <= 6.6
        }
    }

    requirement def EnvelopeVacuumRequirement {
        subject envelope : GlassEnvelope;
        require constraint {
            envelope.internalPressure <= 0.001
        }
    }

    requirement def PlateSafetyRequirement {
        subject tube : VacuumTriodeTube;
        require constraint {
            tube.maximumPlateVoltage <= 300.0
        }
    }

    requirement def OutputSignalRequirement {
        subject amplifier : VacuumTubeVoltageAmplifier;
        require constraint {
            amplifier.nominalOutputVoltageRms >= 4.0
        }
    }

    requirement def BandwidthRequirement {
        subject amplifier : VacuumTubeVoltageAmplifier;
        require constraint {
            amplifier.nominalBandwidthLow <= 20.0 and amplifier.nominalBandwidthHigh >= 20000.0
        }
    }

    requirement def ThermalSafetyRequirement {
        subject tube : VacuumTriodeTube;
        require constraint {
            tube.maximumEnvelopeTemperature <= 470.0
        }
    }

    part vacuumTubeAmplifierSystem : VacuumTubeVoltageAmplifier {
        attribute systemName = "VT-01 thermionic triode voltage amplifier";
        attribute primaryFunction = "Amplify a small alternating input voltage into a larger output voltage by modulating thermionic electron flow between cathode and anode inside a high-vacuum tube.";
        attribute nominalInputVoltageRms = 0.25;
        attribute nominalOutputVoltageRms = 4.5;
        attribute openLoopVoltageGain = 18.0;
        attribute nominalBandwidthLow = 20.0;
        attribute nominalBandwidthHigh = 20000.0;
    }
}
