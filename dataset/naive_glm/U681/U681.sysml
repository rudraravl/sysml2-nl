package FlowMeasurementSystem {
    import ScalarValues::*;
    import ISQ::*;
    import Quantities::*;
    import MeasurementReferences::*;

    // ===== Value Types =====
    value def VolumetricFlowRate :> Real {
        :>> unit = VolumePerTimeUnit::'liter per minute';
    }
    value def TemperatureValue :> Real {
        :>> unit = ThermodynamicTemperatureUnit::kelvin;
    }
    value def PressureValue :> Real {
        :>> unit = PressureUnit::pascal;
    }
    value def Voltage :> Real {
        :>> unit = ElectricPotentialUnit::volt;
    }
    value def Current :> Real {
        :>> unit = ElectricCurrentUnit::ampere;
    }
    value def TimeValue :> Real {
        :>> unit = TimeUnit::millisecond;
    }
    value def Percent :> Real {
        :>> unit = One::percent;
    }

    item def Fluid;
    item def RawSignal;
    item def ConditionedSignal;
    item def CalibrationData;
    item def MeasurementRecord {
        attribute flowRate : VolumetricFlowRate;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute timestamp : DateTime;
        attribute status : SensorStatus;
    }

    enumeration def SensorStatus { operational; standby; calibrating; fault; }

    // ===== Requirements =====
    requirement def FlowSensorAccuracy {
        doc << "The flow sensor shall measure volumetric flow rate with an accuracy of within +/- 1.5%." 
        attribute maxError : Percent = 1.5;
        subject sensor : FlowSensor;
        require constraint { abs(sensor.measuredFlowRate - sensor.actualFlowRate) <= maxError }
    }

    requirement def FlowSensorRange {
        doc << "The flow sensor shall measure flow rates from 0 to 500 liters per minute." 
        attribute minRange : VolumetricFlowRate = 0;
        attribute maxRange : VolumetricFlowRate = 500;
        subject sensor : FlowSensor;
        require constraint { sensor.measuredFlowRate >= minRange and sensor.measuredFlowRate <= maxRange }
    }

    requirement def FlowSensorResponseTime {
        doc << "The flow sensor shall have a response time of less than 200 milliseconds." 
        attribute maxResponseTime : TimeValue = 200;
        subject sensor : FlowSensor;
        require constraint { sensor.responseTime < maxResponseTime }
    }

    requirement def SystemLogging {
        doc << "The Data Logger shall record all measurements transmitted by the Sensing Unit." 
        subject logger : DataLogger;
        subject sensingUnit : SensingUnit;
        require constraint { logger.recordedCount == sensingUnit.transmittedCount }
    }

    // ===== Ports =====
    port def FluidPort {
        out item fluid : Fluid;
    }

    port def ElectricalPowerPort {
        in attribute voltage : Voltage;
        in attribute current : Current;
    }

    port def DataPort {
        out item record : MeasurementRecord;
    }

    port def RawSignalPort {
        out item signal : RawSignal;
    }

    port def ConditionedSignalPort {
        out item signal : ConditionedSignal;
    }

    port def CalibrationPort {
        inout item calData : CalibrationData;
    }

    // ===== Flow Sensor =====
    part def FlowSensor {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port powerIn : ElectricalPowerPort;
        port dataOut : DataPort;
        port calibPort : CalibrationPort;

        attribute measuredFlowRate : VolumetricFlowRate;
        attribute actualFlowRate : VolumetricFlowRate;
        attribute responseTime : TimeValue;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute timestamp : DateTime;
        attribute status : SensorStatus;

        satisfy FlowSensorAccuracy { subject = self; }
        satisfy FlowSensorRange { subject = self; }
        satisfy FlowSensorResponseTime { subject = self; }

        part sensingElement : SensingElement {
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
            port signalOut : RawSignalPort;
            port powerIn : ElectricalPowerPort;
        }

        part signalConditioner : SignalConditioner {
            port signalIn : RawSignalPort;
            port signalOut : ConditionedSignalPort;
            port powerIn : ElectricalPowerPort;
        }

        part dataProcessor : DataProcessor {
            port signalIn : ConditionedSignalPort;
            port calibPort : CalibrationPort;
            port dataOut : DataPort;
            port powerIn : ElectricalPowerPort;
        }

        part calibrationStore : CalibrationStore {
            port calibPort : CalibrationPort;
            port powerIn : ElectricalPowerPort;
        }

        connection fluidThroughSensor connect fluidIn.fluid to sensingElement.fluidIn.fluid;
        connection fluidReturn connect sensingElement.fluidOut.fluid to fluidOut.fluid;
        connection rawSignalFlow connect sensingElement.signalOut.signal to signalConditioner.signalIn.signal;
        connection conditionedSignalFlow connect signalConditioner.signalOut.signal to dataProcessor.signalIn.signal;
        connection calibrationFlow connect calibrationStore.calibPort.calData to dataProcessor.calibPort.calData;
        connection dataOutputFlow connect dataProcessor.dataOut.record to dataOut.record;
        connection powerToElement connect powerIn to sensingElement.powerIn;
        connection powerToConditioner connect powerIn to signalConditioner.powerIn;
        connection powerToProcessor connect powerIn to dataProcessor.powerIn;
        connection powerToCalibration connect powerIn to calibrationStore.powerIn;

        state def FlowSensorStateMachine {
            idle;
            operational;
            calibrating;
            fault;
            transition standby_to_operational first idle to operational when { self.status == SensorStatus::operational };
            transition operational_to_standby operational to idle when { self.status == SensorStatus::standby };
            transition operational_to_calibrating operational to calibrating when { self.status == SensorStatus::calibrating };
            transition calibrating_to_operational calibrating to operational when { self.status == SensorStatus::operational };
            transition any_to_fault operational to fault when { self.status == SensorStatus::fault };
            transition calibrating_to_fault calibrating to fault when { self.status == SensorStatus::fault };
            transition idle_to_fault idle to fault when { self.status == SensorStatus::fault };
            transition fault_to_standby fault to idle when { self.status == SensorStatus::standby };
        }

        exhibit state behavior : FlowSensorStateMachine;
    }

    part def SensingElement {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port signalOut : RawSignalPort;
        port powerIn : ElectricalPowerPort;
        attribute rawVoltage : Voltage;
        action def generateRawSignal {
            in fluid : Fluid;
            out signal : RawSignal;
        }
        perform generateRawSignal;
    }

    part def SignalConditioner {
        port signalIn : RawSignalPort;
        port signalOut : ConditionedSignalPort;
        port powerIn : ElectricalPowerPort;
        attribute gain : Real = 10.0;
        action def conditionSignal {
            in raw : RawSignal;
            out conditioned : ConditionedSignal;
        }
        perform conditionSignal;
    }

    part def DataProcessor {
        port signalIn : ConditionedSignalPort;
        port calibPort : CalibrationPort;
        port dataOut : DataPort;
        port powerIn : ElectricalPowerPort;
        action def processMeasurement {
            in signal : ConditionedSignal;
            in calData : CalibrationData;
            out record : MeasurementRecord;
        }
        perform processMeasurement;
    }

    part def CalibrationStore {
        port calibPort : CalibrationPort;
        port powerIn : ElectricalPowerPort;
        attribute storedCalibration : CalibrationData;
    }

    // ===== Power Module =====
    part def PowerModule {
        port powerOut : ElectricalPowerPort;
        attribute supplyVoltage : Voltage = 24;
        attribute supplyCurrent : Current = 2;
        action def supplyPower {
            out voltage : Voltage;
            out current : Current;
        }
        perform supplyPower;
    }

    // ===== Communication Module =====
    part def CommunicationModule {
        port dataIn : DataPort;
        port dataOut : DataPort;
        port powerIn : ElectricalPowerPort;
        attribute transmittedCount : Integer = 0;
        action def transmitData {
            in record : MeasurementRecord;
            out forwarded : MeasurementRecord;
        }
        perform transmitData;
    }

    // ===== Sensing Unit =====
    part def SensingUnit {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port dataOut : DataPort;
        port powerIn : ElectricalPowerPort;
        attribute transmittedCount : Integer = 0;

        part flowSensor : FlowSensor;
        part powerModule : PowerModule;
        part communicationModule : CommunicationModule;

        connection fluidInToSensor connect fluidIn.fluid to flowSensor.fluidIn.fluid;
        connection fluidOutFromSensor connect flowSensor.fluidOut.fluid to fluidOut.fluid;
        connection powerToSensor connect powerModule.powerOut to flowSensor.powerIn;
        connection powerToComm connect powerModule.powerOut to communicationModule.powerIn;
        connection sensorDataToComm connect flowSensor.dataOut.record to communicationModule.dataIn.record;
        connection commDataOut connect communicationModule.dataOut.record to dataOut.record;
    }

    // ===== Data Logger =====
    part def DataLogger {
        port dataIn : DataPort;
        port powerIn : ElectricalPowerPort;
        attribute recordedCount : Integer = 0;
        attribute storage : MeasurementRecord[0..*];

        action def logMeasurement {
            in record : MeasurementRecord;
            out stored : MeasurementRecord;
        }
        perform logMeasurement;

        satisfy SystemLogging { subject = self; subject sensingUnit : SensingUnit; }
    }

    // ===== Top-level System =====
    part def FlowMeasurementSystem {
        port pipelineIn : FluidPort;
        port pipelineOut : FluidPort;
        port externalPower : ElectricalPowerPort;

        part sensingUnit : SensingUnit;
        part dataLogger : DataLogger;

        connection pipelineToSensingUnit connect pipelineIn.fluid to sensingUnit.fluidIn.fluid;
        connection sensingUnitToPipeline connect sensingUnit.fluidOut.fluid to pipelineOut.fluid;
        connection sensingUnitToLogger connect sensingUnit.dataOut.record to dataLogger.dataIn.record;
        connection powerToSensingUnit connect externalPower to sensingUnit.powerIn;
        connection powerToLogger connect externalPower to dataLogger.powerIn;
    }
}
