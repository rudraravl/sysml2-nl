package BolometerSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Irradiance :> ISQ::powerDensity {
        unit = W / m^2;
    }

    attribute def TemperatureRise :> ISQ::temperature {
        unit = K;
    }

    attribute def ThermalConductance :> ISQ::thermalConductance {
        unit = W / K;
    }

    attribute def ThermalCapacity :> ISQ::heatCapacity {
        unit = J / K;
    }

    attribute def ElectricalResistance :> ISQ::resistance {
        unit = ohm;
    }

    attribute def Responsivity :> ISQ::quantityKind {
        unit = V / W;
    }

    attribute def NoiseEquivalentPower :> ISQ::power {
        unit = W;
    }

    attribute def Detectivity :> ISQ::quantityKind {
        unit = cm * sqrt(Hz) / W;
    }

    item def IncidentRadiation {
        attribute wavelength : ISQ::length;
        attribute irradiance : Irradiance;
        attribute opticalPower : ISQ::power;
        attribute modulationFrequency : ISQ::frequency;
    }

    item def AbsorbedHeat {
        attribute absorbedPower : ISQ::power;
        attribute absorberTemperatureRise : TemperatureRise;
    }

    item def BiasCurrent {
        attribute current : ISQ::electricCurrent;
        attribute stability : Real;
    }

    item def BridgeVoltage {
        attribute voltage : ISQ::voltage;
        attribute offsetVoltage : ISQ::voltage;
        attribute noiseVoltage : ISQ::voltage;
    }

    item def DigitalRadianceMeasurement {
        attribute radiantPowerEstimate : ISQ::power;
        attribute detectorTemperature : ISQ::temperature;
        attribute signalToNoiseRatio : Real;
        attribute valid : Boolean;
    }

    port def OpticalInputPort {
        in item radiation : IncidentRadiation;
    }

    port def ThermalPort {
        inout item heat : AbsorbedHeat;
    }

    port def BiasPort {
        in item bias : BiasCurrent;
    }

    port def AnalogSignalPort {
        out item signal : BridgeVoltage;
    }

    port def MeasurementOutputPort {
        out item measurement : DigitalRadianceMeasurement;
    }

    part def RadiationAbsorber {
        attribute absorptance : Real = 0.92;
        attribute area : ISQ::area = 1.0e-6 [m^2];
        attribute heatCapacity : ThermalCapacity = 1.5e-9 [J / K];

        port opticalIn : OpticalInputPort;
        port thermalOut : ThermalPort;

        action absorbRadiation {
            in item incoming : IncidentRadiation;
            out item heatFlow : AbsorbedHeat;

            first start;
            then computeAbsorbedPower;
            then emitHeat;
            then done;

            action computeAbsorbedPower {
                in item incoming : IncidentRadiation;
                out item heatFlow : AbsorbedHeat;
            }
        }
    }

    part def ThermallyIsolatedMembrane {
        attribute thermalConductanceToSubstrate : ThermalConductance = 4.0e-8 [W / K];
        attribute thermalTimeConstant : ISQ::time = 0.012 [s];
        attribute operatingTemperature : ISQ::temperature = 300.0 [K];
        attribute maximumTemperatureRise : TemperatureRise = 25.0 [K];

        port heatIn : ThermalPort;
        port detectorThermalNode : ThermalPort;

        action integrateHeat {
            in item absorbedHeat : AbsorbedHeat;
            out item detectorHeatState : AbsorbedHeat;
        }
    }

    part def TemperatureSensitiveResistor {
        attribute nominalResistance : ElectricalResistance = 100000.0 [ohm];
        attribute temperatureCoefficientOfResistance : Real = -0.025;
        attribute currentResistance : ElectricalResistance;
        attribute selfHeatingPower : ISQ::power;
        attribute temperatureRise : TemperatureRise;

        port thermalNode : ThermalPort;
        port electricalBias : BiasPort;
        port resistanceSignal : AnalogSignalPort;

        action transduceTemperatureToResistance {
            in item detectorHeatState : AbsorbedHeat;
            in item bias : BiasCurrent;
            out item bridgeSignal : BridgeVoltage;
        }
    }

    part def BiasAndReadoutBridge {
        attribute biasCurrentSetpoint : ISQ::electricCurrent = 20.0e-6 [A];
        attribute bridgeSupplyVoltage : ISQ::voltage = 3.3 [V];
        attribute commonModeRejectionRatio : Real = 90.0;
        attribute analogBandwidth : ISQ::frequency = 200.0 [Hz];

        port biasOut : BiasPort;
        port sensorSignalIn : AnalogSignalPort;
        port bridgeSignalOut : AnalogSignalPort;

        action provideStableBias {
            out item bias : BiasCurrent;
        }

        action conditionBridgeSignal {
            in item rawSignal : BridgeVoltage;
            out item conditionedSignal : BridgeVoltage;
        }
    }

    part def LowNoiseAmplifier {
        attribute gain : Real = 1000.0;
        attribute inputReferredNoise : ISQ::voltage = 8.0e-9 [V];
        attribute bandwidth : ISQ::frequency = 100.0 [Hz];

        port analogIn : AnalogSignalPort;
        port analogOut : AnalogSignalPort;

        action amplify {
            in item lowLevelSignal : BridgeVoltage;
            out item amplifiedSignal : BridgeVoltage;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolution : Integer = 24;
        attribute sampleRate : ISQ::frequency = 1000.0 [Hz];
        attribute referenceVoltage : ISQ::voltage = 2.5 [V];

        port analogIn : AnalogSignalPort;
        port digitalOut : MeasurementOutputPort;

        action digitize {
            in item amplifiedSignal : BridgeVoltage;
            out item measurement : DigitalRadianceMeasurement;
        }
    }

    part def SignalProcessor {
        attribute responsivity : Responsivity = 50000.0 [V / W];
        attribute noiseEquivalentPower : NoiseEquivalentPower = 2.0e-12 [W];
        attribute detectivity : Detectivity = 1.0e8 [cm * sqrt(Hz) / W];
        attribute calibrationOffset : ISQ::power = 0.0 [W];
        attribute calibrationGain : Real = 1.0;

        port measurementIn : MeasurementOutputPort;
        port measurementOut : MeasurementOutputPort;

        action estimateRadiantPower {
            in item rawMeasurement : DigitalRadianceMeasurement;
            out item calibratedMeasurement : DigitalRadianceMeasurement;
        }

        state def ProcessingStateMachine {
            state idle;
            state acquireBaseline;
            state measureSignal;
            state compensateTemperature;
            state outputMeasurement;
            state fault;

            transition first idle;
            transition idle_to_baseline first idle then acquireBaseline;
            transition baseline_to_measure first acquireBaseline then measureSignal;
            transition measure_to_compensate first measureSignal then compensateTemperature;
            transition compensate_to_output first compensateTemperature then outputMeasurement;
            transition output_to_measure first outputMeasurement then measureSignal;
            transition any_to_fault first idle then fault;
        }
    }

    part def TemperatureReference {
        attribute referenceTemperature : ISQ::temperature = 300.0 [K];
        attribute measurementAccuracy : ISQ::temperature = 0.05 [K];

        port referenceOut : MeasurementOutputPort;

        action measureReferenceTemperature {
            out item referenceMeasurement : DigitalRadianceMeasurement;
        }
    }

    part def Bolometer {
        attribute spectralRangeMinimum : ISQ::length = 8.0e-6 [m];
        attribute spectralRangeMaximum : ISQ::length = 14.0e-6 [m];
        attribute nominalOperatingTemperature : ISQ::temperature = 300.0 [K];
        attribute thermalTimeConstant : ISQ::time = 0.012 [s];
        attribute minimumDetectablePower : ISQ::power = 2.0e-12 [W];

        port radiationIn : OpticalInputPort;
        port measurementOut : MeasurementOutputPort;

        part absorber : RadiationAbsorber;
        part membrane : ThermallyIsolatedMembrane;
        part thermistor : TemperatureSensitiveResistor;
        part bridge : BiasAndReadoutBridge;
        part amplifier : LowNoiseAmplifier;
        part adc : AnalogToDigitalConverter;
        part processor : SignalProcessor;
        part reference : TemperatureReference;

        connect radiationIn to absorber.opticalIn;
        connect absorber.thermalOut to membrane.heatIn;
        connect membrane.detectorThermalNode to thermistor.thermalNode;
        connect bridge.biasOut to thermistor.electricalBias;
        connect thermistor.resistanceSignal to bridge.sensorSignalIn;
        connect bridge.bridgeSignalOut to amplifier.analogIn;
        connect amplifier.analogOut to adc.analogIn;
        connect adc.digitalOut to processor.measurementIn;
        connect processor.measurementOut to measurementOut;

        action detectIncidentRadiation {
            in item radiation : IncidentRadiation;
            out item radianceMeasurement : DigitalRadianceMeasurement;

            first receiveRadiation;
            then convertRadiationToHeat;
            then convertHeatToResistanceChange;
            then conditionElectricalSignal;
            then digitizeSignal;
            then computeRadiantPower;
            then publishMeasurement;

            action receiveRadiation {
                in item radiation : IncidentRadiation;
            }

            action convertRadiationToHeat {
                in item radiation : IncidentRadiation;
                out item absorbedHeat : AbsorbedHeat;
            }

            action convertHeatToResistanceChange {
                in item absorbedHeat : AbsorbedHeat;
                out item rawVoltage : BridgeVoltage;
            }

            action conditionElectricalSignal {
                in item rawVoltage : BridgeVoltage;
                out item conditionedVoltage : BridgeVoltage;
            }

            action digitizeSignal {
                in item conditionedVoltage : BridgeVoltage;
                out item rawMeasurement : DigitalRadianceMeasurement;
            }

            action computeRadiantPower {
                in item rawMeasurement : DigitalRadianceMeasurement;
                out item radianceMeasurement : DigitalRadianceMeasurement;
            }

            action publishMeasurement {
                in item radianceMeasurement : DigitalRadianceMeasurement;
            }
        }

        state def BolometerOperationalStates {
            state poweredOff;
            state initialization;
            state biasStabilization;
            state thermalBaselineAcquisition;
            state radiationMeasurement;
            state saturated;
            state fault;

            transition initial first poweredOff;
            transition powerOn first poweredOff then initialization;
            transition initialized first initialization then biasStabilization;
            transition biasStable first biasStabilization then thermalBaselineAcquisition;
            transition baselineReady first thermalBaselineAcquisition then radiationMeasurement;
            transition overRange first radiationMeasurement then saturated;
            transition recovered first saturated then thermalBaselineAcquisition;
            transition errorDetected first initialization then fault;
            transition reset first fault then initialization;
            transition powerDown first radiationMeasurement then poweredOff;
        }
    }

    part def BolometerBasedRadiationSensorSystem {
        attribute primaryFunction : String = "Convert incident electromagnetic radiation into a calibrated electrical measurement of radiant power by absorbing radiation, sensing the resulting temperature rise, and processing the resistance change of a temperature-sensitive detector.";
        attribute measurementUpdateRate : ISQ::frequency = 100.0 [Hz];
        attribute allowableAmbientTemperatureMinimum : ISQ::temperature = 253.0 [K];
        attribute allowableAmbientTemperatureMaximum : ISQ::temperature = 333.0 [K];
        attribute systemPowerConsumption : ISQ::power = 0.15 [W];

        port opticalInput : OpticalInputPort;
        port radiantPowerOutput : MeasurementOutputPort;

        part detector : Bolometer;

        connect opticalInput to detector.radiationIn;
        connect detector.measurementOut to radiantPowerOutput;

        action performPrimaryFunction {
            in item incomingRadiation : IncidentRadiation;
            out item radiantPowerMeasurement : DigitalRadianceMeasurement;

            first acceptIncomingRadiation;
            then detector.detectIncidentRadiation;
            then provideHighLevelMeasurement;

            action acceptIncomingRadiation {
                in item incomingRadiation : IncidentRadiation;
            }

            action provideHighLevelMeasurement {
                out item radiantPowerMeasurement : DigitalRadianceMeasurement;
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : BolometerBasedRadiationSensorSystem;

        require constraint {
            system.primaryFunction ==
            "Convert incident electromagnetic radiation into a calibrated electrical measurement of radiant power by absorbing radiation, sensing the resulting temperature rise, and processing the resistance change of a temperature-sensitive detector."
        }
    }

    requirement def RadiationAbsorptionRequirement {
        subject absorber : RadiationAbsorber;

        require constraint {
            absorber.absorptance >= 0.90
        }
    }

    requirement def DetectablePowerRequirement {
        subject detector : Bolometer;

        require constraint {
            detector.minimumDetectablePower <= 5.0e-12 [W]
        }
    }

    requirement def SpectralRangeRequirement {
        subject detector : Bolometer;

        require constraint {
            detector.spectralRangeMinimum <= 8.0e-6 [m] and
            detector.spectralRangeMaximum >= 14.0e-6 [m]
        }
    }

    requirement def ThermalResponseRequirement {
        subject detector : Bolometer;

        require constraint {
            detector.thermalTimeConstant <= 0.020 [s]
        }
    }

    requirement def AmbientOperatingRequirement {
        subject system : BolometerBasedRadiationSensorSystem;

        require constraint {
            system.allowableAmbientTemperatureMinimum <= 253.0 [K] and
            system.allowableAmbientTemperatureMaximum >= 333.0 [K]
        }
    }

    requirement def MeasurementOutputRequirement {
        subject measurement : DigitalRadianceMeasurement;

        require constraint {
            measurement.valid == true and
            measurement.signalToNoiseRatio >= 3.0
        }
    }

    satisfy PrimaryFunctionRequirement by BolometerBasedRadiationSensorSystem;
    satisfy RadiationAbsorptionRequirement by RadiationAbsorber;
    satisfy DetectablePowerRequirement by Bolometer;
    satisfy SpectralRangeRequirement by Bolometer;
    satisfy ThermalResponseRequirement by Bolometer;
    satisfy AmbientOperatingRequirement by BolometerBasedRadiationSensorSystem;
}