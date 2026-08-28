package AmorphousMetalTransformer {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Power :> Real { unit 'W'; }
    value def Temperature :> Real { unit 'K'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def MagneticFlux :> Real { unit 'Wb'; }
    value def HeatFlowRate :> Real { unit 'W'; }
    value def Efficiency :> Real { unit '%'; }
    value def TurnsRatio :> Real { }

    // ===== Item Types =====
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute frequency : Frequency;
    }

    item def ThermalEnergy {
        attribute temperature : Temperature;
        attribute heatFlow : HeatFlowRate;
    }

    item def MagneticField {
        attribute flux : MagneticFlux;
        attribute frequency : Frequency;
    }

    // ===== Interfaces =====
    interface def ElectricalInterface {
        end inPower : ElectricalPower;
        end outPower : ElectricalPower;
    }

    interface def ThermalInterface {
        end heatIn : ThermalEnergy;
        end heatOut : ThermalEnergy;
    }

    interface def MagneticInterface {
        end fluxIn : MagneticField;
        end fluxOut : MagneticField;
    }

    interface def ControlSignal {
        end command : ControlCommand;
        end status : SystemStatus;
    }

    enum def ControlCommand { energize; deenergize; trip; reset; }
    enum def SystemStatus { offline; startup; normalOperation; overload; faulted; }

    // ===== Port Definitions =====
    port def ElectricalPort {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute frequency : Frequency;
    }

    port def ThermalPort {
        attribute temperature : Temperature;
        attribute heatFlow : HeatFlowRate;
    }

    port def MagneticPort {
        attribute flux : MagneticFlux;
        attribute frequency : Frequency;
    }

    port def ControlPort {
        attribute command : ControlCommand;
        attribute status : SystemStatus;
    }

    // ===== Requirements =====
    requirement def EfficiencyRequirement {
        doc /* The transformer must achieve efficiency greater than 98% at rated load. */
        attribute minEfficiency : Efficiency = 98.0;
        subject transformer : AmorphousMetalTransformer;
        require transformer.efficiency >= minEfficiency;
    }

    requirement def CoreLossRequirement {
        doc /* Core losses due to the amorphous metal must be less than 0.2 W/kg at 1.7 T and 50 Hz. */
        attribute maxCoreLoss : Power = 50.0;
        subject core : AmorphousMetalCore;
        require core.coreLoss <= maxCoreLoss;
    }

    requirement def ThermalRequirement {
        doc /* The cooling system must maintain core temperature below 110 degrees Celsius. */
        attribute maxOperatingTemp : Temperature = 383.15;
        subject cooling : CoolingSystem;
        require cooling.coreTemperature <= maxOperatingTemp;
    }

    requirement def ProtectionRequirement {
        doc /* The protection circuit must trip within 100 ms of detecting an overload or overvoltage condition. */
        attribute maxTripTime : Time = 0.1;
        subject protection : ProtectionCircuit;
        require protection.tripResponseTime <= maxTripTime;
    }

    // ===== Components =====

    part def AmorphousMetalCore {
        doc /* A magnetic core made from amorphous metal with non-crystalline atomic structure, providing superior magnetic properties and low energy losses. */
        attribute materialName : String = "Fe78Si13B9";
        attribute atomicStructure : String = "amorphous";
        attribute coreLoss : Power;
        attribute saturationFluxDensity : Real = 1.56; // Tesla
        attribute operatingFluxDensity : Real = 1.35; // Tesla
        attribute mass : Mass;
        attribute temperature : Temperature;

        port magneticPort1 : MagneticPort;
        port magneticPort2 : MagneticPort;
        port thermalPort : ThermalPort;

        item flow magneticFlux : MagneticField;

        action def ChannelFlux :> Action {
            in primaryFlux : MagneticField;
            out secondaryFlux : MagneticField;
        }

        perform action channelFlux : ChannelFlux {
            in primaryFlux = magneticPort1.flux;
            out secondaryFlux = magneticPort2.flux;
        }
    }

    part def PrimaryWinding {
        doc /* Receives incoming high-voltage electrical power and generates a magnetic field in the core. */
        attribute turnsCount : Integer = 1000;
        attribute ratedVoltage : Voltage = 33000;
        attribute ratedCurrent : Current = 100;
        attribute resistance : Real = 0.5; // Ohms
        attribute windingLoss : Power;

        port electricalIn : ElectricalPort;
        port magneticOut : MagneticPort;

        item flow inputPower : ElectricalPower;
        item flow generatedFlux : MagneticField;

        action def Energize :> Action {
            in electricalInput : ElectricalPower;
            out magneticOutput : MagneticField;
        }

        perform action energize : Energize {
            in electricalInput = electricalIn;
            out magneticOutput = magneticOut;
        }
    }

    part def SecondaryWinding {
        doc /* Delivers outgoing transformed low-voltage electrical power induced by the core's magnetic field. */
        attribute turnsCount : Integer = 100;
        attribute ratedVoltage : Voltage = 3300;
        attribute ratedCurrent : Current = 1000;
        attribute resistance : Real = 0.01; // Ohms
        attribute windingLoss : Power;

        port electricalOut : ElectricalPort;
        port magneticIn : MagneticPort;

        item flow outputPower : ElectricalPower;
        item flow inducedFlux : MagneticField;

        action def Induce :> Action {
            in magneticInput : MagneticField;
            out electricalOutput : ElectricalPower;
        }

        perform action induce : Induce {
            in magneticInput = magneticIn;
            out electricalOutput = electricalOut;
        }
    }

    part def CoolingSystem {
        doc /* Dedicated system to dissipate thermal energy from the core, maintaining safe operating temperature. */
        attribute coolantType : String = "mineral oil";
        attribute flowRate : Real = 50.0; // liters per minute
        attribute coolingCapacity : HeatFlowRate = 5000;
        attribute coreTemperature : Temperature;
        attribute ambientTemperature : Temperature = 298.15;
        attribute maxSafeTemperature : Temperature = 383.15;

        port thermalIn : ThermalPort;
        port thermalOut : ThermalPort;

        item flow absorbedHeat : ThermalEnergy;
        item flow dissipatedHeat : ThermalEnergy;

        action def CirculateCoolant :> Action {
            in heatInput : ThermalEnergy;
            out heatOutput : ThermalEnergy;
        }

        perform action circulate : CirculateCoolant {
            in heatInput = thermalIn;
            out heatOutput = thermalOut;
        }

        state def CoolingStatus {
            entry; then Idle;
            state Idle;
            transition from Idle to Active
                when thermalIn.temperature > 313.15;
            state Active;
            transition from Active to Idle
                when thermalIn.temperature <= 308.15;
        }

        exhibit state coolingStatus : CoolingStatus;
    }

    part def ProtectionCircuit {
        doc /* Continuously monitors output power and safeguards against electrical overloads and overvoltage conditions. */
        attribute overloadThreshold : Current = 1100;
        attribute overvoltageThreshold : Voltage = 3630;
        attribute tripResponseTime : Time;
        attribute isTripped : Boolean = false;

        port monitorPort : ElectricalPort;
        port controlPort : ControlPort;

        item flow monitoredPower : ElectricalPower;
        item flow controlSignal : ControlSignal;

        action def Monitor :> Action {
            in monitoredOutput : ElectricalPower;
            out tripSignal : ControlCommand;
        }

        perform action monitor : Monitor {
            in monitoredOutput = monitorPort;
            out tripSignal = controlPort.command;
        }

        state def ProtectionStatus {
            entry; then Monitoring;
            state Monitoring;
            transition from Monitoring to Tripped
                when monitorPort.current > overloadThreshold
                or monitorPort.voltage > overvoltageThreshold;
            state Tripped {
                entry { controlPort.command = ControlCommand::trip; }
            }
            transition from Tripped to Monitoring
                when controlPort.command == ControlCommand::reset;
        }

        exhibit state protectionStatus : ProtectionStatus;
    }

    // ===== Top-Level Transformer System =====

    part def AmorphousMetalTransformer {
        doc /* A high-efficiency amorphous metal transformer system for power distribution voltage level conversion. */
        attribute ratedPower : Power = 3300000;
        attribute ratedPrimaryVoltage : Voltage = 33000;
        attribute ratedSecondaryVoltage : Voltage = 3300;
        attribute ratedFrequency : Frequency = 50;
        attribute efficiency : Efficiency;
        attribute turnsRatio : TurnsRatio = 10.0;
        attribute currentStatus : SystemStatus = SystemStatus::offline;

        port primaryPort : ElectricalPort;
        port secondaryPort : ElectricalPort;
        port systemControlPort : ControlPort;

        // Parts
        part primaryWinding : PrimaryWinding {
            attribute turnsCount = 1000;
            attribute ratedVoltage = 33000;
        }

        part secondaryWinding : SecondaryWinding {
            attribute turnsCount = 100;
            attribute ratedVoltage = 3300;
        }

        part core : AmorphousMetalCore {
            attribute materialName = "Fe78Si13B9";
            attribute atomicStructure = "amorphous";
            attribute coreLoss = 35.0;
            attribute mass = 250.0;
        }

        part coolingSystem : CoolingSystem {
            attribute coolantType = "mineral oil";
            attribute coolingCapacity = 5000;
        }

        part protectionCircuit : ProtectionCircuit {
            attribute overloadThreshold = 1100;
            attribute overvoltageThreshold = 3630;
        }

        // Connections
        connection primaryToCore connect primaryWinding.magneticOut to core.magneticPort1 {
            attribute type = "magnetic";
        }

        connection coreToSecondary connect core.magneticPort2 to secondaryWinding.magneticIn {
            attribute type = "magnetic";
        }

        connection coreToCooling connect core.thermalPort to coolingSystem.thermalIn {
            attribute type = "thermal";
        }

        connection coolingToAmbient connect coolingSystem.thermalOut to thermalPort {
            attribute type = "thermal";
        }

        connection secondaryToProtection connect secondaryWinding.electricalOut to protectionCircuit.monitorPort {
            attribute type = "electrical";
        }

        connection protectionToControl connect protectionCircuit.controlPort to systemControlPort {
            attribute type = "control";
        }

        // External port bindings
        binding primaryPort = primaryWinding.electricalIn;
        binding secondaryPort = secondaryWinding.electricalOut;

        // State Machine
        state def TransformerOperation {
            entry { currentStatus = SystemStatus::offline; }
            then Offline;

            state Offline {
                doc /* Transformer is de-energized and not operating. */
                entry { currentStatus = SystemStatus::offline; }
            }

            transition from Offline to Startup
                when systemControlPort.command == ControlCommand::energize;

            state Startup {
                doc /* Transformer is energized and building its magnetic field. */
                entry { currentStatus = SystemStatus::startup; }

                do action BuildMagneticField {
                    doc /* Ramp up the magnetic flux in the amorphous core to operating level. */
                    // Core flux builds up during startup
                }

                // Transition to normal operation once flux is stable
            }

            transition from Startup to NormalOperation
                when core.temperature <= coolingSystem.maxSafeTemperature
                and protectionCircuit.isTripped == false;

            state NormalOperation {
                doc /* Transformer is efficiently transforming power at rated conditions. */
                entry { currentStatus = SystemStatus::normalOperation; }

                do action TransformPower {
                    doc /* Continuously convert primary voltage to secondary voltage through magnetic coupling. */
                    // Primary winding energizes core, core channels flux, secondary induces voltage
                }
            }

            transition from NormalOperation to Overload
                when secondaryWinding.electricalOut.current > protectionCircuit.overloadThreshold;

            state Overload {
                doc /* Demand exceeds rated capacity; transformer is under stress. */
                entry { currentStatus = SystemStatus::overload; }

                do action ManageOverload {
                    doc /* Attempt to handle excess load while monitoring for fault conditions. */
                }
            }

            transition from Overload to NormalOperation
                when secondaryWinding.electricalOut.current <= protectionCircuit.overloadThreshold
                and protectionCircuit.isTripped == false;

            transition from Overload to Faulted
                when core.temperature > coolingSystem.maxSafeTemperature
                or protectionCircuit.isTripped == true;

            transition from NormalOperation to Faulted
                when core.temperature > coolingSystem.maxSafeTemperature
                or protectionCircuit.isTripped == true;

            state Faulted {
                doc /* Protection circuit has tripped; transformer is shutting down safely. */
                entry {
                    currentStatus = SystemStatus::faulted;
                    systemControlPort.command = ControlCommand::trip;
                }

                do action SafeShutdown {
                    doc /* Safely de-energize the transformer and isolate it from the grid. */
                }
            }

            transition from Faulted to Offline
                when systemControlPort.command == ControlCommand::reset
                and core.temperature <= coolingSystem.maxSafeTemperature
                and protectionCircuit.isTripped == false;
        }

        exhibit state operation : TransformerOperation;

        // Requirements satisfaction
        satisfy EfficiencyRequirement {
            subject = Self;
            attribute minEfficiency = 98.5;
        }

        satisfy CoreLossRequirement {
            subject = core;
            attribute maxCoreLoss = 50.0;
        }

        satisfy ThermalRequirement {
            subject = coolingSystem;
            attribute maxOperatingTemp = 383.15;
        }

        satisfy ProtectionRequirement {
            subject = protectionCircuit;
            attribute maxTripTime = 0.1;
        }
    }

    // ===== Instantiation =====
    part transformerInstance : AmorphousMetalTransformer {
        attribute ratedPower = 3300000;
        attribute ratedPrimaryVoltage = 33000;
        attribute ratedSecondaryVoltage = 3300;
        attribute ratedFrequency = 50;
        attribute efficiency = 99.1;
        attribute turnsRatio = 10.0;

        part primaryWinding {
            attribute turnsCount = 1000;
            attribute ratedVoltage = 33000;
            attribute ratedCurrent = 100;
            attribute resistance = 0.5;
        }

        part secondaryWinding {
            attribute turnsCount = 100;
            attribute ratedVoltage = 3300;
            attribute ratedCurrent = 1000;
            attribute resistance = 0.01;
        }

        part core {
            attribute materialName = "Fe78Si13B9";
            attribute atomicStructure = "amorphous";
            attribute coreLoss = 35.0;
            attribute saturationFluxDensity = 1.56;
            attribute operatingFluxDensity = 1.35;
            attribute mass = 250.0;
            attribute temperature = 323.15;
        }

        part coolingSystem {
            attribute coolantType = "mineral oil";
            attribute flowRate = 50.0;
            attribute coolingCapacity = 5000;
            attribute ambientTemperature = 298.15;
            attribute maxSafeTemperature = 383.15;
        }

        part protectionCircuit {
            attribute overloadThreshold = 1100;
            attribute overvoltageThreshold = 3630;
            attribute tripResponseTime = 0.05;
            attribute isTripped = false;
        }
    }
}
