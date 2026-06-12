package NDIRSensingUnitModel {

    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    attribute def Concentration {
        :> ScalarValues::Real;
        unit = ppm;
    }

    attribute def Voltage {
        :> ScalarValues::Real;
        unit = V;
    }

    attribute def Current {
        :> ScalarValues::Real;
        unit = mA;
    }

    attribute def Power {
        :> ScalarValues::Real;
        unit = W;
    }

    attribute def Temperature {
        :> ScalarValues::Real;
        unit = K;
    }

    attribute def Pressure {
        :> ScalarValues::Real;
        unit = Pa;
    }

    attribute def TimeInterval {
        :> ScalarValues::Real;
        unit = s;
    }

    attribute def OpticalIntensity {
        :> ScalarValues::Real;
        unit = W;
    }

    attribute def DigitalCount {
        :> ScalarValues::Integer;
    }

    item def GasSample {
        attribute co2Concentration : Concentration;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute humidityPercent : ScalarValues::Real;
    }

    item def InfraredRadiation {
        attribute wavelength : Length;
        attribute intensity : OpticalIntensity;
    }

    item def AnalogSignal {
        attribute voltage : Voltage;
        attribute noiseRms : Voltage;
    }

    item def DigitalMeasurement {
        attribute rawAbsorbanceCount : DigitalCount;
        attribute compensatedConcentration : Concentration;
        attribute sampleTemperature : Temperature;
        attribute timestamp : TimeInterval;
        attribute valid : Boolean;
    }

    item def PowerSupply {
        attribute supplyVoltage : Voltage;
        attribute availableCurrent : Current;
    }

    port def GasPort {
        in item sample : GasSample;
    }

    port def OpticalPort {
        out item radiation : InfraredRadiation;
    }

    port def DetectorPort {
        in item radiation : InfraredRadiation;
        out item signal : AnalogSignal;
    }

    port def AnalogPort {
        out item signal : AnalogSignal;
    }

    port def DigitalMeasurementPort {
        out item measurement : DigitalMeasurement;
    }

    port def PowerPort {
        in item supply : PowerSupply;
    }

    part def InfraredEmitter {
        attribute centerWavelength : Length = 4.26 [um];
        attribute opticalPower : OpticalIntensity = 0.018 [W];
        attribute warmupTime : TimeInterval = 30 [s];
        attribute driveCurrent : Current = 60 [mA];

        port power : PowerPort;
        port opticalOut : OpticalPort;

        action emitInfrared {
            in item electricalSupply : PowerSupply;
            out item emittedRadiation : InfraredRadiation;
        }
    }

    part def OpticalGasCell {
        attribute pathLength : Length = 50 [mm];
        attribute internalVolume : Volume = 4.0 [cm^3];
        attribute targetGas = "carbon dioxide";
        attribute measurementWavelength : Length = 4.26 [um];

        port gasIn : GasPort;
        port sourceOptics : OpticalPort;
        port detectorOptics : DetectorPort;

        action attenuateRadiationByGasAbsorption {
            in item incomingRadiation : InfraredRadiation;
            in item gas : GasSample;
            out item transmittedRadiation : InfraredRadiation;
        }
    }

    part def InfraredDetector {
        attribute responsivity : ScalarValues::Real = 9500;
        attribute darkVoltage : Voltage = 0.015 [V];
        attribute detectorNoiseRms : Voltage = 0.002 [V];

        port opticalIn : DetectorPort;
        port analogOut : AnalogPort;

        action convertInfraredToVoltage {
            in item transmittedRadiation : InfraredRadiation;
            out item analogSignal : AnalogSignal;
        }
    }

    part def TemperaturePressureSensor {
        attribute temperatureAccuracy : Temperature = 0.5 [K];
        attribute pressureAccuracy : Pressure = 100 [Pa];

        action measureEnvironment {
            in item gas : GasSample;
            out attribute measuredTemperature : Temperature;
            out attribute measuredPressure : Pressure;
        }
    }

    part def AnalogFrontEnd {
        attribute gain : ScalarValues::Real = 12.0;
        attribute adcResolutionBits : ScalarValues::Integer = 16;
        attribute samplingPeriod : TimeInterval = 1.0 [s];

        port analogIn : AnalogPort;

        action sampleAndDigitize {
            in item detectorSignal : AnalogSignal;
            out attribute absorbanceCount : DigitalCount;
        }
    }

    part def CompensationProcessor {
        attribute lowerMeasurementRange : Concentration = 0 [ppm];
        attribute upperMeasurementRange : Concentration = 5000 [ppm];
        attribute nominalAccuracy : Concentration = 50 [ppm];
        attribute responseTimeT90 : TimeInterval = 20 [s];

        port measurementOut : DigitalMeasurementPort;

        action computeConcentration {
            in attribute rawAbsorbanceCount : DigitalCount;
            in attribute temperature : Temperature;
            in attribute pressure : Pressure;
            out item measurement : DigitalMeasurement;
        }
    }

    part def NDIRSensor {
        attribute targetQuantity = "carbon dioxide concentration";
        attribute measurementPrinciple = "nondispersive infrared absorption";
        attribute operatingTemperatureMin : Temperature = 263.15 [K];
        attribute operatingTemperatureMax : Temperature = 323.15 [K];
        attribute measurementInterval : TimeInterval = 1.0 [s];

        port gasSampleIn : GasPort;
        port powerIn : PowerPort;
        port measurementOut : DigitalMeasurementPort;

        part emitter : InfraredEmitter;
        part gasCell : OpticalGasCell;
        part detector : InfraredDetector;
        part frontEnd : AnalogFrontEnd;
        part environmentSensor : TemperaturePressureSensor;
        part processor : CompensationProcessor;

        connect powerIn to emitter.power;
        connect emitter.opticalOut to gasCell.sourceOptics;
        connect gasSampleIn to gasCell.gasIn;
        connect gasCell.detectorOptics to detector.opticalIn;
        connect detector.analogOut to frontEnd.analogIn;
        connect processor.measurementOut to measurementOut;

        action measureGasConcentration {
            in item gas : GasSample;
            out item result : DigitalMeasurement;

            first start;
            then emit : emitter.emitInfrared;
            then absorb : gasCell.attenuateRadiationByGasAbsorption;
            then detect : detector.convertInfraredToVoltage;
            then digitize : frontEnd.sampleAndDigitize;
            then compensate : processor.computeConcentration;
            then done;
        }

        state def SensorOperatingState {
            entry;
            state Off;
            state Warmup;
            state Ready;
            state Measuring;
            state Fault;

            transition initial then Off;
            transition Off_to_Warmup first Off accept PowerApplied then Warmup;
            transition Warmup_to_Ready first Warmup accept WarmupComplete then Ready;
            transition Ready_to_Measuring first Ready accept SamplePeriodElapsed then Measuring;
            transition Measuring_to_Ready first Measuring accept MeasurementComplete then Ready;
            transition Any_to_Fault first Off accept SelfTestFailed then Fault;
            transition Any_to_Fault2 first Warmup accept SelfTestFailed then Fault;
            transition Any_to_Fault3 first Ready accept SelfTestFailed then Fault;
            transition Any_to_Fault4 first Measuring accept SelfTestFailed then Fault;
            transition Fault_to_Off first Fault accept PowerRemoved then Off;
        }

        exhibit stateMachine : SensorOperatingState;
    }

    part def SensingUnit {
        attribute unitName = "NDIR carbon dioxide sensing unit";
        attribute measuredQuantity = "CO2 concentration in sampled gas";
        attribute nominalSupplyVoltage : Voltage = 5.0 [V];
        attribute maximumCurrentDraw : Current = 150 [mA];
        attribute maximumPowerDraw : Power = 0.75 [W];
        attribute reportingPeriod : TimeInterval = 1.0 [s];

        port gasInput : GasPort;
        port supplyInput : PowerPort;
        port digitalOutput : DigitalMeasurementPort;

        part ndirSensor : NDIRSensor;
        part enclosure {
            attribute ingressProtection = "IP40";
            attribute material = "polycarbonate";
        }

        connect gasInput to ndirSensor.gasSampleIn;
        connect supplyInput to ndirSensor.powerIn;
        connect ndirSensor.measurementOut to digitalOutput;
    }

    requirement def MeasurementRangeRequirement {
        subject sensingUnit : SensingUnit;
        require constraint {
            sensingUnit.ndirSensor.processor.lowerMeasurementRange <= 0 [ppm] and
            sensingUnit.ndirSensor.processor.upperMeasurementRange >= 5000 [ppm]
        }
    }

    requirement def AccuracyRequirement {
        subject sensingUnit : SensingUnit;
        require constraint {
            sensingUnit.ndirSensor.processor.nominalAccuracy <= 50 [ppm]
        }
    }

    requirement def ResponseTimeRequirement {
        subject sensingUnit : SensingUnit;
        require constraint {
            sensingUnit.ndirSensor.processor.responseTimeT90 <= 20 [s]
        }
    }

    requirement def PowerRequirement {
        subject sensingUnit : SensingUnit;
        require constraint {
            sensingUnit.maximumPowerDraw <= 0.75 [W] and
            sensingUnit.nominalSupplyVoltage == 5.0 [V]
        }
    }

    requirement def NDIRPrincipleRequirement {
        subject sensor : NDIRSensor;
        require constraint {
            sensor.measurementPrinciple == "nondispersive infrared absorption" and
            sensor.gasCell.measurementWavelength == 4.26 [um]
        }
    }

    part ndirCO2SensingUnit : SensingUnit;

    requirement measurementRangeSatisfied : MeasurementRangeRequirement {
        subject sensingUnit = ndirCO2SensingUnit;
    }

    requirement accuracySatisfied : AccuracyRequirement {
        subject sensingUnit = ndirCO2SensingUnit;
    }

    requirement responseTimeSatisfied : ResponseTimeRequirement {
        subject sensingUnit = ndirCO2SensingUnit;
    }

    requirement powerSatisfied : PowerRequirement {
        subject sensingUnit = ndirCO2SensingUnit;
    }

    requirement ndirPrincipleSatisfied : NDIRPrincipleRequirement {
        subject sensor = ndirCO2SensingUnit.ndirSensor;
    }
}