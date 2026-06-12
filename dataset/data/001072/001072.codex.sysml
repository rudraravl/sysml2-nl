package GolayCellSystemModel {
    import ScalarValues::*;
    import SI::*;

    attribute def Pressure;
    attribute def Temperature;
    attribute def OpticalPower;
    attribute def Voltage;
    attribute def Frequency;
    attribute def Time;
    attribute def Length;
    attribute def Volume;
    attribute def Stiffness;
    attribute def Displacement;
    attribute def Gain;
    attribute def NoiseEquivalentPower;

    item def InfraredRadiation {
        attribute wavelength : Length;
        attribute modulatedPower : OpticalPower;
        attribute modulationFrequency : Frequency;
    }

    item def ThermalEnergy {
        attribute heatFlow : OpticalPower;
        attribute temperatureRise : Temperature;
    }

    item def GasPressurePulse {
        attribute staticPressure : Pressure;
        attribute dynamicPressure : Pressure;
        attribute pulseFrequency : Frequency;
    }

    item def MembraneMotion {
        attribute deflection : Displacement;
        attribute velocity : Length;
    }

    item def MeasurementSignal {
        attribute outputVoltage : Voltage;
        attribute signalFrequency : Frequency;
        attribute signalToNoiseRatio : Real;
    }

    port def OpticalInputPort {
        in item incidentRadiation : InfraredRadiation;
    }

    port def ThermalPort {
        in item absorbedHeat : ThermalEnergy;
        out item pressurePulse : GasPressurePulse;
    }

    port def MechanicalPort {
        in item pressurePulse : GasPressurePulse;
        out item membraneMotion : MembraneMotion;
    }

    port def ElectricalOutputPort {
        out item measurementSignal : MeasurementSignal;
    }

    port def DiagnosticPort {
        out attribute chamberTemperature : Temperature;
        out attribute chamberPressure : Pressure;
        out attribute detectorHealth : Real;
    }

    part def GolayCellDetector {
        attribute operatingPressure : Pressure = 101325.0 [Pa];
        attribute nominalTemperature : Temperature = 293.15 [K];
        attribute chamberVolume : Volume = 1.2e-6 [m^3];
        attribute usableWavelengthMin : Length = 2.0e-6 [m];
        attribute usableWavelengthMax : Length = 25.0e-6 [m];
        attribute nominalModulationFrequency : Frequency = 20.0 [Hz];
        attribute responsivity : Gain = 8.0e4;
        attribute noiseEquivalentPower : NoiseEquivalentPower = 1.0e-10;
        attribute maximumSafeOpticalPower : OpticalPower = 5.0e-3 [W];

        port opticalIn : OpticalInputPort;
        port electricalOut : ElectricalOutputPort;
        port diagnostics : DiagnosticPort;

        part infraredWindow : InfraredWindow;
        part absorptionChamber : GasFilledAbsorptionChamber;
        part flexibleMembrane : DeflectingMembrane;
        part opticalReadout : MembraneReadout;
        part signalConditioner : SignalConditioningElectronics;
        part controller : DetectorController;

        connect opticalIn to infraredWindow.input;
        connect infraredWindow.transmittedRadiation to absorptionChamber.thermalInput;
        connect absorptionChamber.pressureOutput to flexibleMembrane.mechanicalInput;
        connect flexibleMembrane.motionOutput to opticalReadout.motionInput;
        connect opticalReadout.rawSignalOutput to signalConditioner.rawInput;
        connect signalConditioner.conditionedOutput to electricalOut;
        connect absorptionChamber.diagnostics to diagnostics;
        connect controller.controlledElectronics to signalConditioner.controlInput;
    }

    part def InfraredWindow {
        attribute apertureDiameter : Length = 8.0e-3 [m];
        attribute windowThickness : Length = 1.0e-3 [m];
        attribute averageTransmission : Real = 0.82;

        port input : OpticalInputPort;
        port transmittedRadiation : OpticalInputPort;

        action transmitRadiation {
            in item incoming : InfraredRadiation;
            out item transmitted : InfraredRadiation;

            first start;
            then attenuatePower;
            then passModulatedRadiation;
            then done;

            action attenuatePower;
            action passModulatedRadiation;
        }
    }

    part def GasFilledAbsorptionChamber {
        attribute fillGas : String = "xenon";
        attribute chamberVolume : Volume = 1.2e-6 [m^3];
        attribute absorptionEfficiency : Real = 0.76;
        attribute thermalTimeConstant : Time = 8.0e-3 [s];
        attribute staticPressure : Pressure = 101325.0 [Pa];
        attribute gasTemperature : Temperature = 293.15 [K];

        port thermalInput : OpticalInputPort;
        port pressureOutput : MechanicalPort;
        port diagnostics : DiagnosticPort;

        action convertOpticalPowerToPressure {
            in item incidentRadiation : InfraredRadiation;
            out item pressurePulse : GasPressurePulse;

            first receiveInfraredRadiation;
            then absorbRadiationInGas;
            then raiseGasTemperature;
            then expandGasAtConstantVolume;
            then emitPressurePulse;
            then done;

            action receiveInfraredRadiation;
            action absorbRadiationInGas;
            action raiseGasTemperature;
            action expandGasAtConstantVolume;
            action emitPressurePulse;
        }

        state def ChamberOperationalState {
            entry action initializeChamber;
            state Standby;
            state ReceivingRadiation;
            state HeatingGas;
            state GeneratingPressurePulse;
            state OverPowerProtection;
            state Fault;

            transition first Standby;
            transition Standby to ReceivingRadiation
                accept InfraredRadiation;
            transition ReceivingRadiation to HeatingGas;
            transition HeatingGas to GeneratingPressurePulse;
            transition GeneratingPressurePulse to ReceivingRadiation
                if gasTemperature < 323.15 [K];
            transition GeneratingPressurePulse to OverPowerProtection
                if gasTemperature >= 323.15 [K];
            transition OverPowerProtection to Standby
                if gasTemperature <= 303.15 [K];
            transition ReceivingRadiation to Fault
                if staticPressure < 90000.0 [Pa];
        }
    }

    part def DeflectingMembrane {
        attribute membraneDiameter : Length = 6.0e-3 [m];
        attribute membraneThickness : Length = 2.0e-6 [m];
        attribute springConstant : Stiffness = 0.35;
        attribute maximumDeflection : Displacement = 40.0e-6 [m];
        attribute nominalDeflectionSensitivity : Real = 2.5e-8;

        port mechanicalInput : MechanicalPort;
        port motionOutput : MechanicalPort;

        action convertPressureToMotion {
            in item pressurePulse : GasPressurePulse;
            out item membraneMotion : MembraneMotion;

            first receivePressurePulse;
            then computeMembraneDeflection;
            then limitDeflection;
            then outputMotion;
            then done;

            action receivePressurePulse;
            action computeMembraneDeflection;
            action limitDeflection;
            action outputMotion;
        }
    }

    part def MembraneReadout {
        attribute readoutType : String = "optical lever";
        attribute probeOpticalPower : OpticalPower = 0.5e-3 [W];
        attribute displacementGain : Gain = 2.0e6;
        attribute readoutBandwidth : Frequency = 200.0 [Hz];

        port motionInput : MechanicalPort;
        port rawSignalOutput : ElectricalOutputPort;

        action senseMembraneMotion {
            in item motion : MembraneMotion;
            out item rawSignal : MeasurementSignal;

            first illuminateMembrane;
            then detectAngularChange;
            then convertMotionToVoltage;
            then outputRawSignal;
            then done;

            action illuminateMembrane;
            action detectAngularChange;
            action convertMotionToVoltage;
            action outputRawSignal;
        }
    }

    part def SignalConditioningElectronics {
        attribute lowCutFrequency : Frequency = 1.0 [Hz];
        attribute highCutFrequency : Frequency = 100.0 [Hz];
        attribute voltageGain : Gain = 100.0;
        attribute outputNoiseRms : Voltage = 2.0e-6 [V];

        port rawInput : ElectricalOutputPort;
        port conditionedOutput : ElectricalOutputPort;
        port controlInput : ElectricalOutputPort;

        action conditionSignal {
            in item rawSignal : MeasurementSignal;
            out item conditionedSignal : MeasurementSignal;

            first receiveRawVoltage;
            then bandpassFilter;
            then amplifySignal;
            then rejectOutOfBandNoise;
            then outputConditionedSignal;
            then done;

            action receiveRawVoltage;
            action bandpassFilter;
            action amplifySignal;
            action rejectOutOfBandNoise;
            action outputConditionedSignal;
        }
    }

    part def DetectorController {
        attribute samplePeriod : Time = 10.0e-3 [s];
        attribute healthThreshold : Real = 0.85;

        port controlledElectronics : ElectricalOutputPort;

        action superviseDetector {
            first readDiagnostics;
            then evaluateHealth;
            then configureSignalGain;
            then reportStatus;
            then done;

            action readDiagnostics;
            action evaluateHealth;
            action configureSignalGain;
            action reportStatus;
        }

        state def ControllerState {
            state PowerOff;
            state WarmUp;
            state Ready;
            state Measuring;
            state Protecting;
            state ServiceRequired;

            transition first PowerOff;
            transition PowerOff to WarmUp;
            transition WarmUp to Ready
                if elapsedTime >= 2.0 [s];
            transition Ready to Measuring
                accept InfraredRadiation;
            transition Measuring to Protecting
                if detectorHealth < healthThreshold;
            transition Protecting to Ready
                if detectorHealth >= healthThreshold;
            transition Protecting to ServiceRequired
                if chamberPressure < 90000.0 [Pa];
        }
    }

    part def GolayCellBasedInfraredMeasurementSystem {
        attribute primaryFunction : String =
            "Convert modulated infrared radiation into a proportional electrical signal by absorption-induced gas heating, pressure generation, membrane deflection, and displacement readout.";

        part detector : GolayCellDetector;
        part modulatedInfraredSource : ModulatedInfraredSource;
        part measurementInterface : MeasurementInterface;

        connect modulatedInfraredSource.radiationOutput to detector.opticalIn;
        connect detector.electricalOut to measurementInterface.signalInput;
    }

    part def ModulatedInfraredSource {
        attribute centerWavelength : Length = 10.6e-6 [m];
        attribute emittedPower : OpticalPower = 1.0e-3 [W];
        attribute modulationFrequency : Frequency = 20.0 [Hz];

        port radiationOutput : OpticalInputPort;

        action emitModulatedInfraredRadiation {
            out item radiation : InfraredRadiation;

            first generateInfraredBeam;
            then applyAmplitudeModulation;
            then directBeamToDetector;
            then done;

            action generateInfraredBeam;
            action applyAmplitudeModulation;
            action directBeamToDetector;
        }
    }

    part def MeasurementInterface {
        attribute inputRange : Voltage = 10.0 [V];
        attribute sampleRate : Frequency = 1000.0 [Hz];
        attribute minimumReportableSnr : Real = 3.0;

        port signalInput : ElectricalOutputPort;

        action reportInfraredPowerMeasurement {
            in item signal : MeasurementSignal;

            first acquireVoltage;
            then computeIncidentOpticalPower;
            then validateSignalToNoiseRatio;
            then publishMeasurement;
            then done;

            action acquireVoltage;
            action computeIncidentOpticalPower;
            action validateSignalToNoiseRatio;
            action publishMeasurement;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall use a Golay cell to detect modulated infrared radiation and provide a proportional electrical measurement signal. */
        subject system : GolayCellBasedInfraredMeasurementSystem;

        require constraint {
            system.detector.responsivity > 1.0e4
        }
    }

    requirement def SpectralCoverageRequirement {
        doc /* The detector shall accept infrared radiation from 2 micrometers through 25 micrometers. */
        subject detector : GolayCellDetector;

        require constraint {
            detector.usableWavelengthMin <= 2.0e-6 [m] and
            detector.usableWavelengthMax >= 25.0e-6 [m]
        }
    }

    requirement def ModulationFrequencyRequirement {
        doc /* The Golay cell shall support detection of chopped or otherwise modulated infrared input near 20 hertz. */
        subject detector : GolayCellDetector;

        require constraint {
            detector.nominalModulationFrequency >= 10.0 [Hz] and
            detector.nominalModulationFrequency <= 30.0 [Hz]
        }
    }

    requirement def OpticalPowerSafetyRequirement {
        doc /* The incident optical power shall remain below the chamber thermal protection limit during normal operation. */
        subject detector : GolayCellDetector;

        require constraint {
            detector.maximumSafeOpticalPower <= 5.0e-3 [W]
        }
    }

    requirement def SensitivityRequirement {
        doc /* The Golay cell shall provide sub-nanowatt class noise-equivalent optical power for low-frequency infrared measurements. */
        subject detector : GolayCellDetector;

        require constraint {
            detector.noiseEquivalentPower <= 1.0e-9
        }
    }

    requirement def PressureIntegrityRequirement {
        doc /* The gas-filled absorption chamber shall maintain sufficient pressure for repeatable pressure-pulse generation. */
        subject chamber : GasFilledAbsorptionChamber;

        require constraint {
            chamber.staticPressure >= 90000.0 [Pa]
        }
    }

    requirement def SignalOutputRequirement {
        doc /* The system shall provide a conditioned voltage signal representing incident modulated infrared power. */
        subject interface : MeasurementInterface;

        require constraint {
            interface.inputRange >= 1.0 [V] and
            interface.sampleRate >= 200.0 [Hz]
        }
    }

    satisfy PrimaryFunctionRequirement by GolayCellBasedInfraredMeasurementSystem;
    satisfy SpectralCoverageRequirement by GolayCellDetector;
    satisfy ModulationFrequencyRequirement by GolayCellDetector;
    satisfy OpticalPowerSafetyRequirement by GolayCellDetector;
    satisfy SensitivityRequirement by GolayCellDetector;
    satisfy PressureIntegrityRequirement by GasFilledAbsorptionChamber;
    satisfy SignalOutputRequirement by MeasurementInterface;
}