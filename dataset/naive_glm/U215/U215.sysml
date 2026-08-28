package ErbiumGlassLaserSystem {
    import ScalarValues::*;

    // ============================================================
    // Value Types
    // ============================================================

    value type Voltage :> Real;
    value type Current :> Real;
    value type Capacitance :> Real;
    value type Charge :> Real;
    value type Energy :> Real;
    value type Power :> Real;
    value type TimeDuration :> Real;
    value type Frequency :> Real;
    value type Temperature :> Real;
    value type Wavelength :> Real;
    value type FlowRate :> Real;
    value type Pressure :> Real;
    value type Volume :> Real;
    value type OpticalIntensity :> Real;
    value type BeamDivergence :> Real;
    value type Length :> Real;
    value type Diameter :> Real;
    value type Reflectance :> Real;
    value type Transmittance :> Real;
    value type DopingConcentration :> Real;
    value type PulseEnergy :> Energy;
    value type PulseDuration :> TimeDuration;
    value type PeakPower :> Power;
    value type PulseRate :> Frequency;
    value type HeatFlux :> Power;

    // ============================================================
    // Items (Flow Items)
    // ============================================================

    item ElectricEnergy;
    item PumpLight;
    item LaserBeam;
    item ThermalFlux;
    item Coolant;
    item TriggerSignal;
    item ControlSignal;
    item StatusSignal;
    item ChargeCommand;
    item DischargeCommand;
    item OpenCommand;

    // ============================================================
    // Port Definitions
    // ============================================================

    port def ElectricInputPort {
        attribute voltage : Voltage;
        attribute current : Current;
        in electricEnergy : ElectricEnergy;
    }

    port def ElectricOutputPort {
        attribute voltage : Voltage;
        attribute current : Current;
        out electricEnergy : ElectricEnergy;
    }

    port def PumpLightInputPort {
        attribute pumpWavelength : Wavelength;
        in pumpLight : PumpLight;
    }

    port def PumpLightOutputPort {
        attribute pumpWavelength : Wavelength;
        out pumpLight : PumpLight;
    }

    port def LaserInputPort {
        attribute laserWavelength : Wavelength;
        in laserBeam : LaserBeam;
    }

    port def LaserOutputPort {
        attribute laserWavelength : Wavelength;
        attribute pulseEnergy : PulseEnergy;
        attribute pulseDuration : PulseDuration;
        out laserBeam : LaserBeam;
    }

    port def ThermalOutputPort {
        attribute temperature : Temperature;
        attribute heatFlux : HeatFlux;
        out thermalFlux : ThermalFlux;
    }

    port def ThermalInputPort {
        attribute temperature : Temperature;
        in thermalFlux : ThermalFlux;
    }

    port def CoolantInletPort {
        attribute temperature : Temperature;
        attribute flowRate : FlowRate;
        in coolant : Coolant;
    }

    port def CoolantOutletPort {
        attribute temperature : Temperature;
        attribute flowRate : FlowRate;
        out coolant : Coolant;
    }

    port def ControlInputPort {
        in trigger : TriggerSignal;
        in chargeCommand : ChargeCommand;
        in dischargeCommand : DischargeCommand;
        in openCommand : OpenCommand;
    }

    port def ControlOutputPort {
        out status : StatusSignal;
    }

    // ============================================================
    // Connection Definitions
    // ============================================================

    connection def ElectricPowerConnection {
        end source : ElectricOutputPort;
        end target : ElectricInputPort;
    }

    connection def OpticalPumpConnection {
        end source : PumpLightOutputPort;
        end target : PumpLightInputPort;
    }

    connection def LaserBeamConnection {
        end source : LaserOutputPort;
        end target : LaserInputPort;
    }

    connection def CoolantFlowConnection {
        end source : CoolantOutletPort;
        end target : CoolantInletPort;
    }

    connection def ThermalFlowConnection {
        end source : ThermalOutputPort;
        end target : ThermalInputPort;
    }

    // ============================================================
    // Component Definitions
    // ============================================================

    part def CapacitorBankPowerSupply {
        doc : "Stores electrical energy and rapidly discharges it into the flashlamp.";
        attribute nominalVoltage : Voltage = 2000;
        attribute capacitance : Capacitance = 0.001;
        attribute maxStoredEnergy : Energy = 200;
        attribute currentStoredEnergy : Energy = 0;
        attribute chargeTime : TimeDuration = 0.05;
        attribute dischargeTime : TimeDuration = 0.0001;
        attribute efficiency : Real = 0.9;
        attribute bankCount : Integer = 4;

        port electricInput : ElectricInputPort;
        port electricOutput : ElectricOutputPort;
        port controlInput : ControlInputPort;
        port statusOutput : ControlOutputPort;

        action Charge;
        action Discharge;
        action MonitorVoltage;

        state machine CapacitorState {
            state idle;
            state charging;
            state charged;
            state discharging;
            state faulted;
            transition idle then charging when controlInput.chargeCommand;
            transition charging then charged after 0.05;
            transition charged then discharging when controlInput.dischargeCommand;
            transition discharging then idle after 0.0001;
            transition charging then faulted when electricInput.voltage > 2500;
            transition faulted then idle;
        }
    }

    part def XenonFlashlampAssembly {
        doc : "Xenon flashlamp that produces an intense optical pump pulse for the Er:glass rod.";
        attribute arcLength : Length = 0.1;
        attribute boreDiameter : Diameter = 0.005;
        attribute fillPressure : Pressure = 50000;
        attribute fillGas : String = "Xenon";
        attribute coolingRequirement : Power = 50;
        attribute serviceLife : TimeDuration = 1000000;
        attribute pulseEnergyRating : Energy = 200;

        port electricInput : ElectricInputPort;
        port pumpOutput : PumpLightOutputPort;
        port thermalOutput : ThermalOutputPort;
        port controlInput : ControlInputPort;

        action Fire;
        action Cool;

        state machine FlashlampState {
            state idle;
            state firing;
            state cooling;
            transition idle then firing when controlInput.dischargeCommand;
            transition firing then cooling after 0.0001;
            transition cooling then idle after 0.5;
        }
    }

    part def ErbiumDopedGlassRod {
        doc : "Active gain medium; erbium-doped glass rod that emits at 1.54 micrometers.";
        attribute rodLength : Length = 0.08;
        attribute rodDiameter : Diameter = 0.006;
        attribute dopingConcentration : DopingConcentration = 0.0001;
        attribute glassType : String = "PhosphateGlass";
        attribute emissionWavelength : Wavelength = 1.54e-6;
        attribute absorptionBandPeak : Wavelength = 0.98e-6;
        attribute storedEnergy : Energy = 0;
        attribute maxStoredEnergy : Energy = 100;
        attribute quantumEfficiency : Real = 0.8;
        attribute fluorescenceLifetime : TimeDuration = 0.001;
        attribute maxOperatingTemperature : Temperature = 350;
        attribute currentTemperature : Temperature = 293;

        port pumpInput : PumpLightInputPort;
        port laserOutput : LaserOutputPort;
        port thermalOutput : ThermalOutputPort;

        action AbsorbPump;
        action EmitLaser;
        action Relax;

        state machine GainMediumState {
            state ground;
            state absorbing;
            state excited;
            state emitting;
            transition ground then absorbing when pumpInput.pumpLight;
            transition absorbing then excited when storedEnergy >= maxStoredEnergy;
            transition excited then emitting;
            transition emitting then ground after 1e-8;
        }
    }

    part def HighReflectorMirror {
        doc : "High-reflectivity mirror at one end of the resonator.";
        attribute reflectivity : Reflectance = 0.999;
        attribute operatingWavelength : Wavelength = 1.54e-6;
        attribute substrateDiameter : Diameter = 0.025;
        attribute substrateThickness : Length = 0.006;
        attribute substrateMaterial : String = "FusedSilica";

        port opticalPort : LaserInputPort;
    }

    part def OutputCouplerMirror {
        doc : "Partially transparent output coupler mirror at the other end of the resonator.";
        attribute reflectivity : Reflectance = 0.5;
        attribute transmittance : Transmittance = 0.5;
        attribute operatingWavelength : Wavelength = 1.54e-6;
        attribute substrateDiameter : Diameter = 0.025;
        attribute substrateThickness : Length = 0.006;
        attribute substrateMaterial : String = "FusedSilica";

        port inputPort : LaserInputPort;
        port outputPort : LaserOutputPort;
    }

    part def OpticalResonator {
        doc : "Optical cavity formed by the high reflector and output coupler; traps and amplifies the laser beam.";
        attribute resonatorLength : Length = 0.15;
        attribute alignmentTolerance : Length = 1e-5;
        attribute stabilityFactor : Real = 0.5;
        attribute cavityMode : String = "TEM00";

        part highReflector : HighReflectorMirror;
        part outputCoupler : OutputCouplerMirror;

        port cavityInput : LaserInputPort;
        port cavityOutput : LaserOutputPort;

        connection c1 connect cavityInput to highReflector.opticalPort;
        connection c2 connect outputCoupler.outputPort to cavityOutput;

        action AmplifyBeam;
        action AlignCavity;
    }

    part def QSwitchModule {
        doc : "High-speed optical shutter that blocks/unblocks the cavity to produce a single giant pulse.";
        attribute switchingTime : TimeDuration = 1e-8;
        attribute insertionLoss : Transmittance = 0.99;
        attribute blockingStateAttenuation : Reflectance = 0.99;
        attribute activeStateTransmittance : Transmittance = 0.95;
        attribute modulationFrequency : Frequency = 1000000;
        attribute switchType : String = "ElectroOptic";

        port opticalInput : LaserInputPort;
        port opticalOutput : LaserOutputPort;
        port controlInput : ControlInputPort;

        action Block;
        action Unblock;

        state machine QSwitchState {
            state closed;
            state open;
            transition closed then open when controlInput.openCommand;
            transition open then closed after 1e-6;
        }
    }

    part def BeamShapingOptics {
        doc : "Collimates and shapes the output laser beam to ensure high beam quality.";
        attribute outputBeamDivergence : BeamDivergence = 1e-3;
        attribute outputBeamDiameter : Diameter = 0.01;
        attribute operatingWavelength : Wavelength = 1.54e-6;
        attribute qualityFactor : Real = 0.95;
        attribute elementCount : Integer = 3;

        part collimator;
        part apertureStop;
        part spatialFilter;

        port inputPort : LaserInputPort;
        port outputPort : LaserOutputPort;

        action Collimate;
        action FilterSpatial;
    }

    part def CoolantPump {
        doc : "Circulates coolant through the laser head to remove waste heat.";
        attribute nominalFlowRate : FlowRate = 0.5;
        attribute operatingPressure : Pressure = 100000;
        attribute powerConsumption : Power = 25;
        attribute pumpType : String = "Centrifugal";

        port inlet : CoolantInletPort;
        port outlet : CoolantOutletPort;
        port controlInput : ControlInputPort;

        action Circulate;
    }

    part def HeatExchanger {
        doc : "Removes heat from the circulating coolant to maintain stable operating temperature.";
        attribute coolingCapacity : Power = 500;
        attribute coolantVolume : Volume = 0.5;
        attribute operatingTemperature : Temperature = 293;
        attribute ambientHeatRemovalRate : Power = 500;
        attribute heatTransferArea : Length = 0.5;

        port inlet : CoolantInletPort;
        port outlet : CoolantOutletPort;
        port thermalOutput : ThermalOutputPort;

        action RejectHeat;
    }

    part def ThermalManagementSystem {
        doc : "Active cooling system that circulates coolant through the laser head to maintain stable temperature.";
        attribute setpointTemperature : Temperature = 293;
        attribute nominalFlowRate : FlowRate = 0.5;
        attribute maxOperatingPressure : Pressure = 200000;
        attribute coolantType : String = "EthyleneGlycol-Water";
        attribute coolantConcentration : Real = 0.3;

        part pump : CoolantPump;
        part heatExchanger : HeatExchanger;

        connection c1 : CoolantFlowConnection connect pump.outlet to heatExchanger.inlet;

        port coolantSupply : CoolantOutletPort;
        port coolantReturn : CoolantInletPort;
        port controlInput : ControlInputPort;
        port statusOutput : ControlOutputPort;

        action Circulate;
        action Monitor;
        action RegulateTemperature;

        state machine ThermalState {
            state idle;
            state circulating;
            state overheated;
            transition idle then circulating when controlInput.trigger;
            transition circulating then overheated when heatExchanger.operatingTemperature > 320;
            transition overheated then circulating when heatExchanger.operatingTemperature <= 300;
        }
    }

    part def LaserHead {
        doc : "Enclosed assembly containing the gain medium, flashlamp, resonator, and Q-switch.";
        attribute housingMaterial : String = "Aluminum";
        attribute housingLength : Length = 0.25;
        attribute housingDiameter : Diameter = 0.1;
        attribute operatingTemperature : Temperature = 293;
        attribute maxTemperature : Temperature = 350;
        attribute coolantJacketVolume : Volume = 0.02;

        part flashlamp : XenonFlashlampAssembly;
        part gainMedium : ErbiumDopedGlassRod;
        part resonator : OpticalResonator;
        part qSwitch : QSwitchModule;

        connection c1 : OpticalPumpConnection connect flashlamp.pumpOutput to gainMedium.pumpInput;
        connection c2 : LaserBeamConnection connect gainMedium.laserOutput to qSwitch.opticalInput;
        connection c3 : LaserBeamConnection connect qSwitch.opticalOutput to resonator.cavityInput;
        connection c4 connect resonator.cavityOutput to resonator.outputCoupler.outputPort;

        port electricInput : ElectricInputPort;
        port laserOutput : LaserOutputPort;
        port coolantInlet : CoolantInletPort;
        port coolantOutlet : CoolantOutletPort;
        port thermalOutput : ThermalOutputPort;
        port controlInput : ControlInputPort;
        port statusOutput : ControlOutputPort;

        connection c5 connect electricInput to flashlamp.electricInput;
        connection c6 connect resonator.cavityOutput to laserOutput;
        connection c7 connect controlInput to flashlamp.controlInput;
        connection c8 connect controlInput to qSwitch.controlInput;
        connection c9 connect flashlamp.thermalOutput to gainMedium.thermalOutput;
        connection c10 connect coolantInlet to coolantOutlet;
    }

    // ============================================================
    // Top-Level Laser System
    // ============================================================

    part def ErbiumGlassLaserSystem {
        doc : "High-energy pulsed Erbium-doped glass laser system emitting at 1.54 micrometers.";
        attribute systemName : String = "ErGlassPulsedLaser";
        attribute manufacturer : String = "DefenseLaserCorp";
        attribute designLife : TimeDuration = 10000000;
        attribute eyeSafeWavelength : Wavelength = 1.54e-6;
        attribute outputPulseEnergy : PulseEnergy = 0.05;
        attribute outputPulseDuration : PulseDuration = 1e-8;
        attribute peakOutputPower : PeakPower = 5000000;
        attribute maxRepetitionRate : PulseRate = 10;
        attribute systemMass : Real = 15;
        attribute systemVolume : Volume = 0.02;
        attribute inputPowerRequirement : Power = 1000;

        part powerSupply : CapacitorBankPowerSupply;
        part laserHead : LaserHead;
        part beamShaping : BeamShapingOptics;
        part thermal : ThermalManagementSystem;

        port externalControl : ControlInputPort;
        port externalStatus : ControlOutputPort;
        port laserOutput : LaserOutputPort;
        port powerInput : ElectricInputPort;

        connection c1 connect powerInput to powerSupply.electricInput;
        connection c2 : ElectricPowerConnection connect powerSupply.electricOutput to laserHead.electricInput;
        connection c3 : LaserBeamConnection connect laserHead.laserOutput to beamShaping.inputPort;
        connection c4 connect beamShaping.outputPort to laserOutput;
        connection c5 : CoolantFlowConnection connect thermal.coolantSupply to laserHead.coolantInlet;
        connection c6 : CoolantFlowConnection connect laserHead.coolantOutlet to thermal.coolantReturn;
        connection c7 connect externalControl to powerSupply.controlInput;
        connection c8 connect externalControl to laserHead.controlInput;
        connection c9 connect externalControl to thermal.controlInput;
        connection c10 connect powerSupply.statusOutput to externalStatus;
        connection c11 connect laserHead.statusOutput to externalStatus;
        connection c12 connect thermal.statusOutput to externalStatus;

        action FirePulse;
        action CoolDown;
        action SelfTest;

        state machine SystemStateMachine {
            state standby;
            state charging;
            state pumping;
            state qSwitchOpening;
            state emitting;
            state thermalRecovery;
            state faulted;

            transition standby then charging when externalControl.trigger;
            transition charging then pumping after 0.05;
            transition pumping then qSwitchOpening after 0.0001;
            transition qSwitchOpening then emitting after 1e-8;
            transition emitting then thermalRecovery after 1e-8;
            transition thermalRecovery then standby after 0.5;
            transition charging then faulted when powerSupply.electricInput.voltage > 2500;
            transition pumping then faulted when laserHead.gainMedium.currentTemperature > 340;
            transition faulted then standby;
        }
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def EyeSafeWavelengthRequirement {
        doc : "The laser system shall emit light at the eye-safe wavelength of 1.54 micrometers.";
        subject laserSystem : ErbiumGlassLaserSystem;
        require laserSystem.eyeSafeWavelength == 1.54e-6;
        require laserSystem.laserHead.gainMedium.emissionWavelength == 1.54e-6;
        require laserSystem.laserHead.resonator.highReflector.operatingWavelength == 1.54e-6;
        require laserSystem.laserHead.resonator.outputCoupler.operatingWavelength == 1.54e-6;
        require laserSystem.beamShaping.operatingWavelength == 1.54e-6;
    }

    requirement def HighEnergyPulseRequirement {
        doc : "The system shall generate high-energy pulses of at least 50 millijoules.";
        subject laserSystem : ErbiumGlassLaserSystem;
        require laserSystem.outputPulseEnergy >= 0.05;
        require laserSystem.peakOutputPower >= 5000000;
    }

    requirement def ShortPulseDurationRequirement {
        doc : "The system shall produce pulses of nanosecond duration.";
        subject laserSystem : ErbiumGlassLaserSystem;
        require laserSystem.outputPulseDuration <= 1e-8;
    }

    requirement def QSwitchingSpeedRequirement {
        doc : "The Q-switch shall open in nanoseconds to allow a single giant pulse.";
        subject qSwitch : QSwitchModule;
        require qSwitch.switchingTime <= 1e-8;
        require qSwitch.activeStateTransmittance >= 0.9;
    }

    requirement def ThermalManagementRequirement {
        doc : "The thermal management system shall maintain operating temperature below the maximum safe limit.";
        subject thermal : ThermalManagementSystem;
        require thermal.heatExchanger.operatingTemperature <= 320;
        require thermal.heatExchanger.coolingCapacity >= 400;
        require thermal.nominalFlowRate >= 0.4;
    }

    requirement def BeamQualityRequirement {
        doc : "The output beam shall be well-collimated with divergence less than 1 milliradian.";
        subject beamShaping : BeamShapingOptics;
        require beamShaping.outputBeamDivergence <= 1e-3;
        require beamShaping.qualityFactor >= 0.9;
    }

    requirement def CapacitorEnergyStorageRequirement {
        doc : "The capacitor bank shall store at least 200 joules of electrical energy.";
        subject powerSupply : CapacitorBankPowerSupply;
        require powerSupply.maxStoredEnergy >= 200;
        require powerSupply.nominalVoltage >= 1500;
        require powerSupply.capacitance >= 0.0005;
    }

    requirement def RepetitionRateRequirement {
        doc : "The system shall support a maximum repetition rate of at least 10 Hz.";
        subject laserSystem : ErbiumGlassLaserSystem;
        require laserSystem.maxRepetitionRate >= 10;
    }

    requirement def GainMediumDopingRequirement {
        doc : "The erbium-doped glass rod shall have a doping concentration suitable for efficient lasing.";
        subject gainMedium : ErbiumDopedGlassRod;
        require gainMedium.dopingConcentration >= 0.00005;
        require gainMedium.dopingConcentration <= 0.0002;
        require gainMedium.maxStoredEnergy >= 80;
    }

    requirement def OpticalResonatorRequirement {
        doc : "The optical resonator shall be aligned within 10 microns of tolerance.";
        subject resonator : OpticalResonator;
        require resonator.alignmentTolerance <= 1e-5;
        require resonator.highReflector.reflectivity >= 0.995;
        require resonator.outputCoupler.reflectivity >= 0.3;
        require resonator.outputCoupler.transmittance >= 0.3;
    }

    requirement def FlashlampPumpRequirement {
        doc : "The xenon flashlamp shall deliver sufficient pump energy to excite the erbium atoms.";
        subject flashlamp : XenonFlashlampAssembly;
        require flashlamp.pulseEnergyRating >= 150;
        require flashlamp.serviceLife >= 500000;
    }

    requirement def SystemReliabilityRequirement {
        doc : "The system shall have a design life of at least 10 million pulses.";
        subject laserSystem : ErbiumGlassLaserSystem;
        require laserSystem.designLife >= 10000000;
    }

    requirement def EyeSafetyComplianceRequirement {
        doc : "All emitted optical energy shall be at wavelengths within the eye-safe region (1.5-1.6 micrometers).";
        subject laserSystem : ErbiumGlassLaserSystem;
        require laserSystem.eyeSafeWavelength >= 1.5e-6;
        require laserSystem.eyeSafeWavelength <= 1.6e-6;
    }

    requirement def PowerInputRequirement {
        doc : "The system shall accept standard electrical power input.";
        subject laserSystem : ErbiumGlassLaserSystem;
        require laserSystem.inputPowerRequirement <= 1500;
    }
}
