package 'SQUID Magnetometer System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def MagneticFluxValue :> ISQ::MagneticFluxValue;
    attribute def CurrentValue :> ISQ::ElectricCurrentValue;
    attribute def VoltageValue :> ISQ::ElectricPotentialValue;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def ResistanceValue :> ISQ::ResistanceValue;
    attribute def InductanceValue :> ISQ::InductanceValue;
    attribute def CapacitanceValue :> ISQ::CapacitanceValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def AreaValue :> ISQ::AreaValue;
    attribute def MagneticFluxDensityValue :> ISQ::MagneticFluxDensityValue;

    attribute def FluxQuantum {
        attribute value : MagneticFluxValue = 2.067833848e-15 [SI::Wb];
        doc /* Fundamental magnetic flux quantum h/2e approximately 2.07e-15 Weber */
    }

    item def MagneticFieldData {
        attribute flux : MagneticFluxValue;
        attribute timestamp : ISQ::TimeValue;
    }

    item def VoltageSignal {
        attribute voltage : VoltageValue;
        attribute frequency : FrequencyValue;
    }

    item def BiasCommand {
        attribute current : CurrentValue;
    }

    item def CoolingCommand {
        attribute targetTemperature : TemperatureValue;
    }

    port def MagneticInputPort {
        in item magneticField : MagneticFieldData;
    }

    port def VoltageOutputPort {
        out item voltageSignal : VoltageSignal;
    }

    port def CryogenicPort {
        in item coolingCmd : CoolingCommand;
        out temperature : TemperatureValue;
    }

    port def BiasPort {
        in item biasCmd : BiasCommand;
    }

    port def DataPort {
        out item measurementData : MagneticFieldData;
    }

    part def JosephsonJunction {
        doc /* Superconducting tunnel junction that exhibits quantum interference effects */
        
        attribute criticalCurrent : CurrentValue;
        attribute normalResistance : ResistanceValue;
        attribute capacitance : CapacitanceValue;
        attribute plasmaFrequency : FrequencyValue;

        port biasInput : BiasPort;
        port fluxInput : MagneticInputPort;
        port voltageOut : VoltageOutputPort;

        action tunnelCooperPairs {
            in appliedFlux : MagneticFluxValue;
            in biasCurrent : CurrentValue;
            out junctionVoltage : VoltageValue;
            out tunnelingCurrent : CurrentValue;
            doc /* Cooper pair tunneling modulated by magnetic flux */
        }
    }

    part def SuperconductingLoop {
        doc /* Closed superconducting loop that maintains flux quantization */
        
        attribute loopInductance : InductanceValue;
        attribute loopArea : AreaValue;
        attribute persistentCurrent : CurrentValue;
        attribute quantizedFlux : MagneticFluxValue;

        port externalFluxPort : MagneticInputPort;

        action maintainFluxQuantization {
            in externalFlux : MagneticFluxValue;
            out screeningCurrent : CurrentValue;
            out totalFlux : MagneticFluxValue;
            doc /* Maintains flux quantization by generating screening currents */
        }
    }

    part def CryogenicSystem {
        doc /* Liquid helium or closed-cycle refrigeration system */
        
        attribute coolingPower : PowerValue;
        attribute baseTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute heatLoad : PowerValue;

        port cryoPort : CryogenicPort;

        action coolToOperatingTemp {
            in targetTemp : TemperatureValue;
            in ambientTemp : TemperatureValue;
            out achievedTemp : TemperatureValue;
            doc /* Cools SQUID components below superconducting critical temperature */
        }

        action maintainTemperature {
            in heatLoad : PowerValue;
            out stabilizedTemp : TemperatureValue;
            doc /* Maintains stable cryogenic temperature during operation */
        }
    }

    part def ReadoutElectronics {
        doc /* Low-noise amplification and signal processing electronics */
        
        attribute inputImpedance : ResistanceValue;
        attribute voltageGain : Real;
        attribute bandwidth : FrequencyValue;
        attribute noiseTemperature : TemperatureValue;

        port signalInput : VoltageOutputPort;
        port dataOutput : DataPort;

        action amplifySignal {
            in inputVoltage : VoltageValue;
            in gain : Real;
            out amplifiedVoltage : VoltageValue;
            doc /* Amplifies weak SQUID voltage signal */
        }

        action filterNoise {
            in rawSignal : VoltageValue;
            in bandwidth : FrequencyValue;
            out filteredSignal : VoltageValue;
            doc /* Filters out-of-band noise */
        }

        action digitizeSignal {
            in analogVoltage : VoltageValue;
            out digitalValue : Real;
            doc /* Converts analog voltage to digital measurement */
        }
    }

    part def FluxTransformer {
        doc /* Superconducting input coil that couples external flux to SQUID */
        
        attribute pickupCoilTurns : Integer;
        attribute pickupCoilArea : AreaValue;
        attribute inputCoilTurns : Integer;
        attribute couplingCoefficient : Real;
        attribute mutualInductance : InductanceValue;

        port fieldSensor : MagneticInputPort;
        port squidCoupling {
            out coupledFlux : MagneticFluxValue;
        }

        action transformFlux {
            in externalField : MagneticFluxDensityValue;
            in pickupArea : AreaValue;
            out coupledFlux : MagneticFluxValue;
            doc /* Transforms external magnetic field to flux coupled to SQUID */
        }
    }

    part def BiasCurrentSource {
        doc /* Precision current source for biasing Josephson junctions */
        
        attribute outputCurrent : CurrentValue;
        attribute currentStability : Real;
        attribute noiseLevel : CurrentValue;

        port biasOutput : BiasPort;

        action generateBiasCurrent {
            in targetCurrent : CurrentValue;
            out actualCurrent : CurrentValue;
            doc /* Generates stable bias current */
        }
    }

    part def MagneticShield {
        doc /* Multi-layer magnetic shielding to reduce environmental noise */
        
        attribute shieldingFactor : Real;
        attribute numberOfLayers : Integer;
        attribute residualField : MagneticFluxDensityValue;

        action attenuateExternalFields {
            in externalField : MagneticFluxDensityValue;
            out shieldedField : MagneticFluxDensityValue;
            doc /* Reduces external magnetic field interference */
        }
    }

    part def SQUID_Magnetometer {
        doc /* Complete SQUID-based magnetometer system for ultra-sensitive magnetic field detection.
               Primary function: Detect and measure extremely weak magnetic fields by exploiting 
               quantum interference effects in superconducting loops containing Josephson junctions.
               The system converts magnetic flux changes into measurable voltage oscillations with 
               sensitivity approaching the quantum limit. */

        attribute fluxSensitivity : MagneticFluxValue;
        attribute fieldSensitivity : MagneticFluxDensityValue;
        attribute operatingTemperature : TemperatureValue;
        attribute measurementBandwidth : FrequencyValue;
        attribute dynamicRange : Real;

        part junction1 : JosephsonJunction {
            attribute :>> criticalCurrent = 10.0e-6 [SI::A];
            attribute :>> normalResistance = 5.0 [SI::'Ω'];
            attribute :>> capacitance = 1.0e-12 [SI::F];
        }

        part junction2 : JosephsonJunction {
            attribute :>> criticalCurrent = 10.0e-6 [SI::A];
            attribute :>> normalResistance = 5.0 [SI::'Ω'];
            attribute :>> capacitance = 1.0e-12 [SI::F];
        }

        part squidLoop : SuperconductingLoop {
            attribute :>> loopInductance = 100.0e-12 [SI::H];
            attribute :>> loopArea = 1.0e-8 [SI::m^2];
        }

        part cryostat : CryogenicSystem {
            attribute :>> baseTemperature = 4.2 [SI::K];
            attribute :>> coolingPower = 1.5 [SI::W];
        }

        part readout : ReadoutElectronics {
            attribute :>> voltageGain = 5000.0;
            attribute :>> bandwidth = 100.0e3 [SI::Hz];
            attribute :>> inputImpedance = 1.0e6 [SI::'Ω'];
        }

        part inputCoil : FluxTransformer {
            attribute :>> pickupCoilTurns = 1000;
            attribute :>> inputCoilTurns = 10;
            attribute :>> couplingCoefficient = 0.95;
        }

        part biasSource : BiasCurrentSource {
            attribute :>> outputCurrent = 8.0e-6 [SI::A];
            attribute :>> currentStability = 1.0e-6;
        }

        part shield : MagneticShield {
            attribute :>> shieldingFactor = 1000.0;
            attribute :>> numberOfLayers = 3;
        }

        port magneticInput : MagneticInputPort;
        port measurementOutput : DataPort;
        port biasControl : BiasPort;
        port coolingInterface : CryogenicPort;

        connect inputCoil.fieldSensor to magneticInput;
        connect inputCoil.squidCoupling to squidLoop.externalFluxPort;
        connect biasSource.biasOutput to junction1.biasInput;
        connect biasSource.biasOutput to junction2.biasInput;
        connect junction1.voltageOut to readout.signalInput;
        connect readout.dataOutput to measurementOutput;
        connect cryostat.cryoPort to coolingInterface;

        perform action operateMagnetometer;
        exhibit state squidOperatingStates;
    }

    action def InitializeCryogenics {
        in ambientTemp : TemperatureValue;
        in targetTemp : TemperatureValue;
        out finalTemp : TemperatureValue;
        out coolingComplete : Boolean;
    }

    action def SetBiasCurrent {
        in criticalCurrent : CurrentValue;
        out optimalBias : CurrentValue;
        out biasStable : Boolean;
    }

    action def CoupleExternalFlux {
        in externalField : MagneticFluxDensityValue;
        in transformerArea : AreaValue;
        in couplingFactor : Real;
        out coupledFlux : MagneticFluxValue;
    }

    action def GenerateQuantumInterference {
        in loopFlux : MagneticFluxValue;
        in biasCurrent : CurrentValue;
        in fluxQuantum : MagneticFluxValue;
        out interferenceVoltage : VoltageValue;
        out phaseShift : Real;
    }

    action def ProcessSQUIDSignal {
        in rawVoltage : VoltageValue;
        in gain : Real;
        out amplifiedVoltage : VoltageValue;
        out filteredVoltage : VoltageValue;
    }

    action def ComputeMagneticFlux {
        in voltageSignal : VoltageValue;
        in transferFunction : Real;
        out measuredFlux : MagneticFluxValue;
        out measuredField : MagneticFluxDensityValue;
    }

    action operateMagnetometer {
        doc /* Primary operational sequence for SQUID magnetometer measurement cycle */

        first start;
        then merge continueMeasurement;

        then action initCryo : InitializeCryogenics {
            in ambientTemp = 300.0 [SI::K];
            in targetTemp = 4.2 [SI::K];
            out finalTemp;
            out coolingComplete;
        }

        then decide;
            if initCryo.coolingComplete and initCryo.finalTemp <= 4.5 [SI::K] then setBias;
            if not initCryo.coolingComplete then continueMeasurement;

        action setBias : SetBiasCurrent {
            in criticalCurrent = 10.0e-6 [SI::A];
            out optimalBias;
            out biasStable;
        }

        then decide;
            if setBias.biasStable then coupleFlux;
            if not setBias.biasStable then continueMeasurement;

        action coupleFlux : CoupleExternalFlux {
            in externalField;
            in transformerArea = 1.0e-4 [SI::m^2];
            in couplingFactor = 0.95;
            out coupledFlux;
        }

        then action generateInterference : GenerateQuantumInterference {
            in loopFlux = coupleFlux.coupledFlux;
            in biasCurrent = setBias.optimalBias;
            in fluxQuantum = 2.067833848e-15 [SI::Wb];
            out interferenceVoltage;
            out phaseShift;
        }

        then action processSignal : ProcessSQUIDSignal {
            in rawVoltage = generateInterference.interferenceVoltage;
            in gain = 5000.0;
            out amplifiedVoltage;
            out filteredVoltage;
        }

        then action computeFlux : ComputeMagneticFlux {
            in voltageSignal = processSignal.filteredVoltage;
            in transferFunction = 1.0e-9;
            out measuredFlux;
            out measuredField;
        }

        then decide;
            if computeFlux.measuredFlux then continueMeasurement;

        then done;
    }

    state machine def SQUIDOperatingStates {
        doc /* State machine governing SQUID magnetometer operational modes */

        attribute currentTemperature : TemperatureValue;

        initial state Idle;

        state Cooldown {
            entry action startCooling;
            do action monitorTemperature {
                out temperature : TemperatureValue;
            }
        }

        state Stabilizing {
            entry action stabilizeTemperature;
            do action checkThermalStability {
                out isStable : Boolean;
            }
        }

        state Biasing {
            entry action applyBiasCurrent;
            do action optimizeBias {
                out biasOptimal : Boolean;
            }
        }

        state Measuring {
            entry action beginMeasurement;
            do action continuousMeasure {
                out fluxData : MagneticFluxValue;
            }
        }

        state Fault {
            entry action logFault;
        }

        transition idle_to_cooldown
            first Idle
            then Cooldown;

        transition cooldown_to_stabilizing
            first Cooldown
            then Stabilizing;

        transition stabilizing_to_biasing
            first Stabilizing
            then Biasing;

        transition biasing_to_measuring
            first Biasing
            then Measuring;

        transition measuring_to_idle
            first Measuring
            then Idle;

        transition any_to_fault
            first Cooldown
            then Fault;

        transition fault_to_idle
            first Fault
            then Idle;
    }

    requirement def FluxSensitivityRequirement {
        doc /* SQUID shall detect magnetic flux changes approaching the quantum limit */

        subject magnetometer : SQUID_Magnetometer;

        require constraint {
            magnetometer.fluxSensitivity <= 1.0e-15 [SI::Wb]
        }
    }

    requirement def FieldSensitivityRequirement {
        doc /* SQUID shall measure magnetic field with femtotesla sensitivity */

        subject magnetometer : SQUID_Magnetometer;

        require constraint {
            magnetometer.fieldSensitivity <= 1.0e-15 [SI::T]
        }
    }

    requirement def OperatingTemperatureRequirement {
        doc /* SQUID shall operate below superconducting critical temperature */

        subject magnetometer : SQUID_Magnetometer;

        require constraint {
            magnetometer.operatingTemperature < 10.0 [SI::K]
        }
    }

    requirement def BandwidthRequirement {
        doc /* SQUID shall provide measurement bandwidth suitable for dynamic signals */

        subject magnetometer : SQUID_Magnetometer;

        require constraint {
            magnetometer.measurementBandwidth >= 10.0e3 [SI::Hz]
        }
    }

    requirement def NoisePerformanceRequirement {
        doc /* SQUID system shall achieve quantum-limited noise performance */

        subject device : SQUID_Magnetometer;

        require constraint {
            device.readout.noiseTemperature <= 5.0 [SI::K]
        }
    }

    requirement squidSystemRequirements {
        doc /* Top-level requirements for SQUID magnetometer system performance */

        subject system : SQUID_Magnetometer;

        require FluxSensitivityRequirement;
        require FieldSensitivityRequirement;
        require OperatingTemperatureRequirement;
        require BandwidthRequirement;
        require NoisePerformanceRequirement;
    }

    part squidMagnetometerInstance : SQUID_Magnetometer {
        attribute :>> operatingTemperature = 4.2 [SI::K];
        attribute :>> fluxSensitivity = 5.0e-16 [SI::Wb];
        attribute :>> fieldSensitivity = 5.0e-16 [SI::T];
        attribute :>> measurementBandwidth = 100.0e3 [SI::Hz];
        attribute :>> dynamicRange = 1.0e6;

        satisfy squidSystemRequirements;
    }
}
