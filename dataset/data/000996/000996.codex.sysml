package BrakeFluidPressureSensingUnit {

    import ScalarValues::*;
    import SI::*;

    attribute def PressureValue :> Real {
        unit = "Pa";
    }

    attribute def VoltageValue :> Real {
        unit = "V";
    }

    attribute def CurrentValue :> Real {
        unit = "A";
    }

    attribute def TemperatureValue :> Real {
        unit = "degC";
    }

    attribute def TimeValue :> Real {
        unit = "s";
    }

    attribute def PercentValue :> Real {
        unit = "%";
    }

    attribute def FrequencyValue :> Real {
        unit = "Hz";
    }

    attribute def DiagnosticCode :> String;

    item def BrakeFluid {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }

    item def PressureSignal {
        attribute measuredPressure : PressureValue;
        attribute sensorTemperature : TemperatureValue;
        attribute timestamp : TimeValue;
        attribute validity : Boolean;
    }

    item def ElectricalPower {
        attribute supplyVoltage : VoltageValue;
        attribute supplyCurrent : CurrentValue;
    }

    item def AnalogVoltageSignal {
        attribute voltage : VoltageValue;
        attribute sourceImpedance : Real;
    }

    item def DigitalPressureMessage {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute statusValid : Boolean;
        attribute diagnosticStatus : DiagnosticCode;
        attribute sampleCounter : Integer;
    }

    item def DiagnosticMessage {
        attribute code : DiagnosticCode;
        attribute faultActive : Boolean;
        attribute severity : Integer;
    }

    port def HydraulicPressurePort {
        in item fluid : BrakeFluid;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def AnalogSignalPort {
        out item signal : AnalogVoltageSignal;
    }

    port def DigitalCommunicationPort {
        out item message : DigitalPressureMessage;
        out item diagnostic : DiagnosticMessage;
    }

    port def GroundPort {
        in item reference : ElectricalPower;
    }

    action def SenseBrakeFluidPressure {
        in item fluid : BrakeFluid;
        in item power : ElectricalPower;
        out item pressureSignal : PressureSignal;

        attribute minimumPressure : PressureValue = 0.0;
        attribute maximumPressure : PressureValue = 20000000.0;
        attribute responseTime : TimeValue = 0.003;
        attribute accuracy : PercentValue = 1.0;

        assert constraint {
            fluid.pressure >= minimumPressure and fluid.pressure <= maximumPressure
        }

        pressureSignal.measuredPressure = fluid.pressure;
        pressureSignal.sensorTemperature = fluid.temperature;
        pressureSignal.validity = true;
    }

    action def ConvertPressureToVoltage {
        in item pressureSignal : PressureSignal;
        out item analogSignal : AnalogVoltageSignal;

        attribute offsetVoltage : VoltageValue = 0.5;
        attribute fullScaleVoltage : VoltageValue = 4.5;
        attribute fullScalePressure : PressureValue = 20000000.0;

        analogSignal.voltage =
            offsetVoltage + ((pressureSignal.measuredPressure / fullScalePressure) * (fullScaleVoltage - offsetVoltage));
        analogSignal.sourceImpedance = 100.0;
    }

    action def DigitizePressureSignal {
        in item pressureSignal : PressureSignal;
        out item message : DigitalPressureMessage;

        attribute sampleRate : FrequencyValue = 1000.0;

        message.pressure = pressureSignal.measuredPressure;
        message.temperature = pressureSignal.sensorTemperature;
        message.statusValid = pressureSignal.validity;
        message.diagnosticStatus = "OK";
    }

    action def RunPressureSensorDiagnostics {
        in item fluid : BrakeFluid;
        in item power : ElectricalPower;
        out item diagnostic : DiagnosticMessage;

        attribute minimumSupplyVoltage : VoltageValue = 4.75;
        attribute maximumSupplyVoltage : VoltageValue = 5.25;
        attribute minimumValidPressure : PressureValue = 0.0;
        attribute maximumValidPressure : PressureValue = 20000000.0;

        if power.supplyVoltage < minimumSupplyVoltage {
            diagnostic.code = "SUPPLY_UNDERVOLTAGE";
            diagnostic.faultActive = true;
            diagnostic.severity = 2;
        } else if power.supplyVoltage > maximumSupplyVoltage {
            diagnostic.code = "SUPPLY_OVERVOLTAGE";
            diagnostic.faultActive = true;
            diagnostic.severity = 2;
        } else if fluid.pressure < minimumValidPressure {
            diagnostic.code = "PRESSURE_BELOW_RANGE";
            diagnostic.faultActive = true;
            diagnostic.severity = 3;
        } else if fluid.pressure > maximumValidPressure {
            diagnostic.code = "PRESSURE_ABOVE_RANGE";
            diagnostic.faultActive = true;
            diagnostic.severity = 3;
        } else {
            diagnostic.code = "OK";
            diagnostic.faultActive = false;
            diagnostic.severity = 0;
        }
    }

    state def SensingUnitOperatingState {
        entry action initialize;

        state Off;
        state PowerOnSelfTest;
        state Measuring;
        state Degraded;
        state FaultLatched;

        transition initial then Off;

        transition Off_to_PowerOnSelfTest
            first Off
            accept PowerApplied
            then PowerOnSelfTest;

        transition PowerOnSelfTest_to_Measuring
            first PowerOnSelfTest
            accept SelfTestPassed
            then Measuring;

        transition PowerOnSelfTest_to_FaultLatched
            first PowerOnSelfTest
            accept SelfTestFailed
            then FaultLatched;

        transition Measuring_to_Degraded
            first Measuring
            accept DiagnosticWarning
            then Degraded;

        transition Measuring_to_FaultLatched
            first Measuring
            accept CriticalDiagnosticFault
            then FaultLatched;

        transition Degraded_to_Measuring
            first Degraded
            accept DiagnosticRecovered
            then Measuring;

        transition Degraded_to_FaultLatched
            first Degraded
            accept CriticalDiagnosticFault
            then FaultLatched;

        transition FaultLatched_to_PowerOnSelfTest
            first FaultLatched
            accept ResetCommand
            then PowerOnSelfTest;

        transition Measuring_to_Off
            first Measuring
            accept PowerRemoved
            then Off;

        transition Degraded_to_Off
            first Degraded
            accept PowerRemoved
            then Off;

        transition FaultLatched_to_Off
            first FaultLatched
            accept PowerRemoved
            then Off;
    }

    part def BrakeFluidPressureSensor {
        port hydraulicInput : HydraulicPressurePort;
        port powerInput : PowerInputPort;
        port groundReference : GroundPort;
        port analogOutput : AnalogSignalPort;
        port digitalOutput : DigitalCommunicationPort;

        attribute measurementRangeMinimum : PressureValue = 0.0;
        attribute measurementRangeMaximum : PressureValue = 20000000.0;
        attribute overloadPressureLimit : PressureValue = 30000000.0;
        attribute supplyVoltageNominal : VoltageValue = 5.0;
        attribute supplyCurrentMaximum : CurrentValue = 0.025;
        attribute operatingTemperatureMinimum : TemperatureValue = -40.0;
        attribute operatingTemperatureMaximum : TemperatureValue = 125.0;
        attribute pressureAccuracy : PercentValue = 1.0;
        attribute responseTime : TimeValue = 0.003;
        attribute outputSampleRate : FrequencyValue = 1000.0;

        action sense : SenseBrakeFluidPressure;
        action convert : ConvertPressureToVoltage;
        action digitize : DigitizePressureSignal;
        action diagnose : RunPressureSensorDiagnostics;

        perform sense;
        perform convert;
        perform digitize;
        perform diagnose;
    }

    part def SignalConditioningCircuit {
        port analogInput : AnalogSignalPort;
        port conditionedOutput : AnalogSignalPort;
        port powerInput : PowerInputPort;

        attribute lowPassCutoffFrequency : FrequencyValue = 500.0;
        attribute gain : Real = 1.0;
        attribute offsetErrorMaximum : VoltageValue = 0.01;
        attribute noiseMaximum : VoltageValue = 0.02;
    }

    part def MicrocontrollerInterface {
        port pressureMessageInput : DigitalCommunicationPort;
        port conditionedAnalogInput : AnalogSignalPort;
        port vehicleNetworkOutput : DigitalCommunicationPort;
        port powerInput : PowerInputPort;

        attribute adcResolutionBits : Integer = 12;
        attribute adcReferenceVoltage : VoltageValue = 5.0;
        attribute diagnosticCycleTime : TimeValue = 0.01;
        attribute communicationPeriod : TimeValue = 0.005;
    }

    part def BrakeFluidPressureSensingUnit {
        port brakeHydraulicPort : HydraulicPressurePort;
        port electricalPowerPort : PowerInputPort;
        port electricalGroundPort : GroundPort;
        port pressureDataPort : DigitalCommunicationPort;

        part sensor : BrakeFluidPressureSensor;
        part conditioner : SignalConditioningCircuit;
        part controller : MicrocontrollerInterface;

        attribute unitMeasurementRangeMinimum : PressureValue = 0.0;
        attribute unitMeasurementRangeMaximum : PressureValue = 20000000.0;
        attribute unitAccuracy : PercentValue = 1.5;
        attribute unitResponseTime : TimeValue = 0.006;
        attribute unitSupplyVoltageNominal : VoltageValue = 5.0;
        attribute unitSupplyCurrentMaximum : CurrentValue = 0.05;

        state operatingState : SensingUnitOperatingState;

        connect brakeHydraulicPort to sensor.hydraulicInput;
        connect electricalPowerPort to sensor.powerInput;
        connect electricalPowerPort to conditioner.powerInput;
        connect electricalPowerPort to controller.powerInput;
        connect electricalGroundPort to sensor.groundReference;
        connect sensor.analogOutput to conditioner.analogInput;
        connect conditioner.conditionedOutput to controller.conditionedAnalogInput;
        connect sensor.digitalOutput to controller.pressureMessageInput;
        connect controller.vehicleNetworkOutput to pressureDataPort;
    }

    requirement def MeasureBrakeFluidPressureRequirement {
        subject sensingUnit : BrakeFluidPressureSensingUnit;

        attribute requiredMinimumPressure : PressureValue = 0.0;
        attribute requiredMaximumPressure : PressureValue = 20000000.0;
        attribute requiredAccuracy : PercentValue = 1.5;
        attribute requiredResponseTime : TimeValue = 0.010;

        require constraint {
            sensingUnit.unitMeasurementRangeMinimum <= requiredMinimumPressure and
            sensingUnit.unitMeasurementRangeMaximum >= requiredMaximumPressure and
            sensingUnit.unitAccuracy <= requiredAccuracy and
            sensingUnit.unitResponseTime <= requiredResponseTime
        }
    }

    requirement def BrakeFluidPressureSensorRequirement {
        subject sensor : BrakeFluidPressureSensor;

        require constraint {
            sensor.measurementRangeMinimum <= 0.0 and
            sensor.measurementRangeMaximum >= 20000000.0 and
            sensor.pressureAccuracy <= 1.0 and
            sensor.responseTime <= 0.003
        }
    }

    requirement def ElectricalSupplyRequirement {
        subject sensingUnit : BrakeFluidPressureSensingUnit;

        require constraint {
            sensingUnit.unitSupplyVoltageNominal == 5.0 and
            sensingUnit.unitSupplyCurrentMaximum <= 0.05
        }
    }

    requirement def DiagnosticCoverageRequirement {
        subject sensor : BrakeFluidPressureSensor;

        require constraint {
            sensor.overloadPressureLimit >= 30000000.0 and
            sensor.operatingTemperatureMinimum <= -40.0 and
            sensor.operatingTemperatureMaximum >= 125.0
        }
    }

    part brakeFluidPressureSensingUnit : BrakeFluidPressureSensingUnit;

    satisfy MeasureBrakeFluidPressureRequirement by brakeFluidPressureSensingUnit;
    satisfy ElectricalSupplyRequirement by brakeFluidPressureSensingUnit;
    satisfy BrakeFluidPressureSensorRequirement by brakeFluidPressureSensingUnit.sensor;
    satisfy DiagnosticCoverageRequirement by brakeFluidPressureSensingUnit.sensor;
}