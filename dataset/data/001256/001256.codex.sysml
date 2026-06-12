package SoilMoistureSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent :> Real {
        doc "Dimensionless percentage value in the range 0..100.";
    }

    attribute def VolumetricWaterContent :> Percent {
        doc "Soil volumetric water content expressed as percent.";
    }

    attribute def Voltage :> Real {
        doc "Electrical potential in volts.";
    }

    attribute def Current :> Real {
        doc "Electrical current in milliamperes.";
    }

    attribute def TemperatureCelsius :> Real {
        doc "Temperature in degrees Celsius.";
    }

    attribute def TimeSecond :> Real {
        doc "Time duration in seconds.";
    }

    attribute def SoilMoistureRawCount :> Integer {
        doc "Analog-to-digital converter count from the soil moisture sensing element.";
    }

    item def SoilSample {
        attribute moisture : VolumetricWaterContent;
        attribute temperature : TemperatureCelsius;
    }

    item def AnalogSignal {
        attribute voltage : Voltage;
        attribute noiseRms : Voltage;
    }

    item def DigitalMoistureReading {
        attribute rawCount : SoilMoistureRawCount;
        attribute moisture : VolumetricWaterContent;
        attribute valid : Boolean;
        attribute timestamp : TimeSecond;
    }

    item def Power {
        attribute supplyVoltage : Voltage;
        attribute supplyCurrent : Current;
    }

    port def SoilContactPort {
        in item soil : SoilSample;
    }

    port def AnalogOutputPort {
        out item signal : AnalogSignal;
    }

    port def DigitalOutputPort {
        out item reading : DigitalMoistureReading;
    }

    port def PowerInputPort {
        in item power : Power;
    }

    port def ControlPort {
        in item enable : Boolean;
        out item fault : Boolean;
    }

    action def ExciteProbe {
        in item power : Power;
        out item excitationReady : Boolean;
    }

    action def SenseSoilMoisture {
        in item soil : SoilSample;
        out item signal : AnalogSignal;
    }

    action def FilterAnalogSignal {
        in item unfiltered : AnalogSignal;
        out item filtered : AnalogSignal;
    }

    action def ConvertAnalogToDigital {
        in item filtered : AnalogSignal;
        out item rawCount : SoilMoistureRawCount;
    }

    action def CalculateVolumetricWaterContent {
        in item rawCount : SoilMoistureRawCount;
        out item moisture : VolumetricWaterContent;
    }

    action def ValidateReading {
        in item moisture : VolumetricWaterContent;
        out item valid : Boolean;
    }

    action def PublishReading {
        in item rawCount : SoilMoistureRawCount;
        in item moisture : VolumetricWaterContent;
        in item valid : Boolean;
        out item reading : DigitalMoistureReading;
    }

    state def SensingUnitStateMachine {
        state off;
        state initializing;
        state idle;
        state measuring;
        state publishing;
        state faulted;

        transition first off;
        transition off_to_initializing
            first off
            then initializing;

        transition initializing_to_idle
            first initializing
            then idle;

        transition idle_to_measuring
            first idle
            then measuring;

        transition measuring_to_publishing
            first measuring
            then publishing;

        transition publishing_to_idle
            first publishing
            then idle;

        transition any_to_faulted
            first initializing
            then faulted;

        transition faulted_to_initializing
            first faulted
            then initializing;
    }

    part def SoilMoistureProbe {
        port soilContact : SoilContactPort;
        port powerIn : PowerInputPort;
        port analogOut : AnalogOutputPort;

        attribute operatingVoltage : Voltage = 3.3;
        attribute nominalCurrent : Current = 8.0;
        attribute measurementRangeMin : VolumetricWaterContent = 0.0;
        attribute measurementRangeMax : VolumetricWaterContent = 100.0;
        attribute responseTime : TimeSecond = 1.0;

        perform action excite : ExciteProbe;
        perform action sense : SenseSoilMoisture;
    }

    part def SignalConditioner {
        port analogIn : AnalogOutputPort;
        port analogOut : AnalogOutputPort;
        port powerIn : PowerInputPort;

        attribute inputImpedanceMegaOhm : Real = 1.0;
        attribute lowPassCutoffHz : Real = 10.0;
        attribute outputVoltageMin : Voltage = 0.0;
        attribute outputVoltageMax : Voltage = 3.3;

        perform action filter : FilterAnalogSignal;
    }

    part def AnalogToDigitalConverter {
        port analogIn : AnalogOutputPort;
        port digitalOut : DigitalOutputPort;
        port powerIn : PowerInputPort;

        attribute resolutionBits : Integer = 12;
        attribute countMin : SoilMoistureRawCount = 0;
        attribute countMax : SoilMoistureRawCount = 4095;
        attribute referenceVoltage : Voltage = 3.3;
        attribute samplePeriod : TimeSecond = 2.0;

        perform action convert : ConvertAnalogToDigital;
    }

    part def MoistureProcessor {
        port digitalIn : DigitalOutputPort;
        port readingOut : DigitalOutputPort;
        port control : ControlPort;
        port powerIn : PowerInputPort;

        attribute dryCalibrationCount : SoilMoistureRawCount = 3150;
        attribute wetCalibrationCount : SoilMoistureRawCount = 1180;
        attribute validMinMoisture : VolumetricWaterContent = 0.0;
        attribute validMaxMoisture : VolumetricWaterContent = 100.0;
        attribute measurementPeriod : TimeSecond = 10.0;

        perform action calculate : CalculateVolumetricWaterContent;
        perform action validate : ValidateReading;
        perform action publish : PublishReading;
    }

    part def RegulatedPowerSupply {
        port powerIn : PowerInputPort;
        port probePower : PowerInputPort;
        port conditionerPower : PowerInputPort;
        port adcPower : PowerInputPort;
        port processorPower : PowerInputPort;

        attribute inputVoltageMin : Voltage = 4.5;
        attribute inputVoltageMax : Voltage = 5.5;
        attribute regulatedVoltage : Voltage = 3.3;
        attribute maxOutputCurrent : Current = 100.0;
    }

    part def SoilMoistureSensingUnit {
        port soilInterface : SoilContactPort;
        port supply : PowerInputPort;
        port output : DigitalOutputPort;
        port control : ControlPort;

        attribute measuredQuantityName : String = "soil volumetric water content";
        attribute accuracy : VolumetricWaterContent = 3.0;
        attribute operatingTemperatureMin : TemperatureCelsius = -10.0;
        attribute operatingTemperatureMax : TemperatureCelsius = 60.0;
        attribute nominalMeasurementPeriod : TimeSecond = 10.0;

        part probe : SoilMoistureProbe;
        part conditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part processor : MoistureProcessor;
        part powerSupply : RegulatedPowerSupply;

        connection soil_to_probe connect soilInterface to probe.soilContact;
        connection supply_to_power connect supply to powerSupply.powerIn;
        connection power_to_probe connect powerSupply.probePower to probe.powerIn;
        connection power_to_conditioner connect powerSupply.conditionerPower to conditioner.powerIn;
        connection power_to_adc connect powerSupply.adcPower to adc.powerIn;
        connection power_to_processor connect powerSupply.processorPower to processor.powerIn;
        connection probe_to_conditioner connect probe.analogOut to conditioner.analogIn;
        connection conditioner_to_adc connect conditioner.analogOut to adc.analogIn;
        connection adc_to_processor connect adc.digitalOut to processor.digitalIn;
        connection processor_to_output connect processor.readingOut to output;
        connection external_control connect control to processor.control;

        exhibit state behavior : SensingUnitStateMachine;
    }

    requirement def MeasureSoilMoistureRequirement {
        subject sensingUnit : SoilMoistureSensingUnit;

        require constraint {
            sensingUnit.measuredQuantityName == "soil volumetric water content"
        }

        doc "The sensing unit shall measure soil volumetric water content using a soil moisture sensor probe."
    }

    requirement def MoistureRangeRequirement {
        subject sensingUnit : SoilMoistureSensingUnit;

        require constraint {
            sensingUnit.probe.measurementRangeMin <= 0.0 and
            sensingUnit.probe.measurementRangeMax >= 100.0
        }

        doc "The sensing unit shall support a soil moisture measurement range of 0 percent to 100 percent volumetric water content."
    }

    requirement def MoistureAccuracyRequirement {
        subject sensingUnit : SoilMoistureSensingUnit;

        require constraint {
            sensingUnit.accuracy <= 3.0
        }

        doc "The sensing unit shall report volumetric water content with accuracy no worse than plus or minus 3 percent after calibration."
    }

    requirement def SamplingRequirement {
        subject sensingUnit : SoilMoistureSensingUnit;

        require constraint {
            sensingUnit.nominalMeasurementPeriod <= 10.0
        }

        doc "The sensing unit shall produce a valid moisture reading at least once every 10 seconds when enabled and powered."
    }

    requirement def ElectricalSupplyRequirement {
        subject sensingUnit : SoilMoistureSensingUnit;

        require constraint {
            sensingUnit.powerSupply.regulatedVoltage == 3.3 and
            sensingUnit.powerSupply.maxOutputCurrent >= 30.0
        }

        doc "The sensing unit shall regulate input power to 3.3 volts and provide sufficient current for the probe, conditioner, converter, and processor."
    }

    requirement def ValidReadingRequirement {
        subject sensingUnit : SoilMoistureSensingUnit;

        require constraint {
            sensingUnit.processor.validMinMoisture == 0.0 and
            sensingUnit.processor.validMaxMoisture == 100.0
        }

        doc "The processor shall mark readings outside the physical moisture range as invalid."
    }

    satisfy MeasureSoilMoistureRequirement by SoilMoistureSensingUnit;
    satisfy MoistureRangeRequirement by SoilMoistureSensingUnit;
    satisfy MoistureAccuracyRequirement by SoilMoistureSensingUnit;
    satisfy SamplingRequirement by SoilMoistureSensingUnit;
    satisfy ElectricalSupplyRequirement by SoilMoistureSensingUnit;
    satisfy ValidReadingRequirement by SoilMoistureSensingUnit;
}