package PressureSensingUnitModel {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value def PressureValue :> Real {
        unit 'Pa';
    }
    value def VoltageValue :> Real {
        unit 'V';
    }
    value def TemperatureValue :> Real {
        unit 'degC';
    }
    value def FrequencyValue :> Real {
        unit 'Hz';
    }
    value def TimeValue :> Real {
        unit 's';
    }
    value def AccuracyPercent :> Real {
        unit '%';
    }
    value def PowerValue :> Real {
        unit 'W';
    }

    item def RawSignal {
        attribute voltage : VoltageValue;
        attribute timestamp : TimeValue;
    }
    item def ConditionedSignal {
        attribute voltage : VoltageValue;
        attribute timestamp : TimeValue;
        attribute noiseFloor : VoltageValue;
    }
    item def SampledData {
        attribute voltage : VoltageValue;
        attribute sampleIndex : Integer;
        attribute timestamp : TimeValue;
    }
    item def CalibratedPressure {
        attribute value : PressureValue;
        attribute timestamp : TimeValue;
        attribute confidence : Real;
    }
    item def PowerOnSignal;
    item def TriggerSignal;
    item def FaultReport {
        attribute code : Integer;
        attribute description : String;
        attribute timestamp : TimeValue;
    }

    // ===== Interfaces / Port Definitions =====
    interface def PhysicalPressureInterface {
        end pressureIn : PressureValue;
    }
    interface def RawSignalInterface {
        end rawOut : RawSignal;
    }
    interface def ConditionedSignalInterface {
        end conditionedOut : ConditionedSignal;
    }
    interface def DigitalDataInterface {
        end dataOut : SampledData;
    }
    interface def PressureOutputInterface {
        end pressureOut : CalibratedPressure;
    }
    interface def PowerInterface {
        end powerIn : PowerOnSignal;
    }
    interface def ControlInterface {
        end triggerIn : TriggerSignal;
        end faultOut : FaultReport;
    }

    // ===== Sensing Element =====
    part def SensingElement {
        attribute sensitivity : VoltageValue = 0.001 [V];
        attribute maxPressure : PressureValue = 1000000 [Pa];
        attribute minPressure : PressureValue = 0 [Pa];
        port physicalIn : PhysicalPressureInterface;
        port rawOut : RawSignalInterface;
        attribute currentPressure : PressureValue;
        action def transduce {
            in pressure : PressureValue;
            out signal : RawSignal;
        }
        action transduceAction : transduce {
            in pressure = currentPressure;
            out signal;
        }
    }

    // ===== Signal Conditioner =====
    part def SignalConditioner {
        attribute gain : Real = 1000.0;
        attribute cutoffFrequency : FrequencyValue = 1000 [Hz];
        attribute outputRangeMin : VoltageValue = 0 [V];
        attribute outputRangeMax : VoltageValue = 5 [V];
        port rawIn : RawSignalInterface;
        port conditionedOut : ConditionedSignalInterface;
        action def amplifyAndFilter {
            in raw : RawSignal;
            out conditioned : ConditionedSignal;
        }
        action conditionAction : amplifyAndFilter;
    }

    // ===== Pressure Sensor (composite) =====
    part def PressureSensor {
        part sensingElement : SensingElement;
        part signalConditioner : SignalConditioner;
        port physicalIn : PhysicalPressureInterface;
        port conditionedOut : ConditionedSignalInterface;
        connection physicalToSensing connect physicalIn to sensingElement.physicalIn;
        connection rawToConditioner connect sensingElement.rawOut to signalConditioner.rawIn;
        connection conditionerOut connect signalConditioner.conditionedOut to conditionedOut;
    }

    // ===== Data Processor =====
    part def DataProcessor {
        attribute sampleRate : FrequencyValue = 10000 [Hz];
        attribute bufferSize : Integer = 256;
        attribute calibrationOffset : PressureValue = 0 [Pa];
        attribute calibrationScale : Real = 200000.0;
        attribute buffer : SampledData[0..256];
        port conditionedIn : ConditionedSignalInterface;
        port pressureOut : PressureOutputInterface;
        port controlIn : ControlInterface;
        action def sample {
            in signal : ConditionedSignal;
            out data : SampledData;
        }
        action def bufferData {
            in data : SampledData;
            out stored : SampledData;
        }
        action def calibrate {
            in data : SampledData;
            out pressure : CalibratedPressure;
        }
        action def processSequence {
            in signal : ConditionedSignal;
            out pressure : CalibratedPressure;
            action sampleAction : sample {
                in signal;
                out sampled;
            }
            action bufferAction : bufferData {
                in data = sampled;
                out stored;
            }
            action calibrateAction : calibrate {
                in data = stored;
                out pressure;
            }
            flow from sampleAction.sampled to bufferAction.data;
            flow from bufferAction.stored to calibrateAction.data;
        }
        action processAction : processSequence;
    }

    // ===== Protective Housing =====
    part def ProtectiveHousing {
        attribute material : String = "Stainless Steel 316L";
        attribute ipRating : String = "IP67";
        attribute operatingTempMin : TemperatureValue = -40 [degC];
        attribute operatingTempMax : TemperatureValue = 85 [degC];
        attribute wallThickness : Real = 2.5;
        attribute unit : String = "mm";
        attribute shockResistance : Real = 50;
        attribute shockUnit : String = "g";
        port physicalIn : PhysicalPressureInterface;
    }

    // ===== Pressure Sensing Unit (top-level) =====
    part def PressureSensingUnit {
        attribute manufacturer : String = "IndustrialSensors Inc.";
        attribute modelNumber : String = "PSU-1000";
        attribute accuracy : AccuracyPercent = 0.5 [%];
        attribute responseTime : TimeValue = 0.005 [s];
        attribute powerConsumption : PowerValue = 0.5 [W];
        attribute supplyVoltage : VoltageValue = 24 [V];
        attribute operatingTempMin : TemperatureValue = -40 [degC];
        attribute operatingTempMax : TemperatureValue = 85 [degC];

        port powerIn : PowerInterface;
        port controlIn : ControlInterface;
        port physicalIn : PhysicalPressureInterface;
        port pressureOut : PressureOutputInterface;

        part housing : ProtectiveHousing;
        part pressureSensor : PressureSensor;
        part dataProcessor : DataProcessor;

        connection physicalToHousing connect physicalIn to housing.physicalIn;
        connection housingToSensor connect housing.physicalIn to pressureSensor.physicalIn;
        connection sensorToProcessor connect pressureSensor.conditionedOut to dataProcessor.conditionedIn;
        connection processorOutput connect dataProcessor.pressureOut to pressureOut;
        connection powerToProcessor connect powerIn to dataProcessor.controlIn;
        connection controlToProcessor connect controlIn to dataProcessor.controlIn;

        // State Machine
        state def LifecycleStates;
        state machine LifecycleStateMachine : LifecycleStates {
            state off;
            state initializing;
            state idle;
            state measuring;
            state fault;

            transition off_to_initializing
                first off
                if powerIn.powerIn instanceof PowerOnSignal
                then initializing;
            transition initializing_to_idle
                first initializing
                if dataProcessor.bufferSize > 0
                then idle;
            transition idle_to_measuring
                first idle
                if controlIn.triggerIn instanceof TriggerSignal
                then measuring;
            transition measuring_to_idle
                first measuring
                if dataProcessor.processAction.calibrateAction.pressure.value > 0 [Pa]
                then idle;
            transition any_to_fault
                first {idle, measuring, initializing}
                if controlIn.faultOut instanceof FaultReport
                then fault;
            transition fault_to_idle
                first fault
                if controlIn.triggerIn instanceof TriggerSignal
                then idle;
        }

        exhibit stateBehavior : LifecycleStateMachine;

        // Measurement action
        action def performMeasurement {
            in physicalPressure : PressureValue;
            out calibratedPressure : CalibratedPressure;
            action sense : PressureSensor;
            action process : DataProcessor;
            flow from sense.conditionedOut to process.conditionedIn;
        }
    }

    // ===== Multi-Sensor Array =====
    part def MultiSensorArray {
        attribute arraySize : Integer = 4;
        attribute arrayType : String = "Quad-Pressure Array";
        attribute synchronizationMode : String = "Synchronous";
        part sensors : PressureSensingUnit[4];
        port physicalIn : PhysicalPressureInterface[4];
        port pressureOut : PressureOutputInterface[4];
        port powerIn : PowerInterface;
        port controlIn : ControlInterface;
        connection arrayPower connect powerIn to sensors.powerIn;
        connection arrayControl connect controlIn to sensors.controlIn;
        connection arrayPhysical connect physicalIn to sensors.physicalIn;
        connection arrayOutput connect sensors.pressureOut to pressureOut;
    }

    // ===== Requirements =====
    requirement def AccuracyRequirement {
        attribute requiredAccuracy : AccuracyPercent = 0.5 [%];
        subject : PressureSensingUnit;
        require constraint { subject.accuracy <= requiredAccuracy }
    }
    requirement def TemperatureRangeRequirement {
        attribute minTemp : TemperatureValue = -40 [degC];
        attribute maxTemp : TemperatureValue = 85 [degC];
        subject : PressureSensingUnit;
        require constraint { subject.operatingTempMin <= minTemp and subject.operatingTempMax >= maxTemp }
    }
    requirement def ResponseTimeRequirement {
        attribute maxResponseTime : TimeValue = 0.01 [s];
        subject : PressureSensingUnit;
        require constraint { subject.responseTime <= maxResponseTime }
    }
    requirement def EnvironmentalProtectionRequirement {
        attribute requiredIPRating : String = "IP67";
        attribute requiredMaterial : String = "Stainless Steel";
        subject : PressureSensingUnit;
        require constraint { subject.housing.ipRating == requiredIPRating and subject.housing.material.contains(requiredMaterial) }
    }
    requirement def LifecycleRequirement {
        subject : PressureSensingUnit;
        require constraint { subject.stateBehavior.states.includes("idle") and subject.stateBehavior.states.includes("measuring") and subject.stateBehavior.states.includes("fault") }
    }
    requirement def ScalabilityRequirement {
        subject : MultiSensorArray;
        require constraint { subject.arraySize >= 4 }
    }

    // ===== Requirement Satisfaction =====
    part def PressureSensingUnitSystem {
        part unit : PressureSensingUnit;
        part array : MultiSensorArray;
        satisfy accuracyReq : AccuracyRequirement by unit;
        satisfy tempRangeReq : TemperatureRangeRequirement by unit;
        satisfy responseTimeReq : ResponseTimeRequirement by unit;
        satisfy envProtectionReq : EnvironmentalProtectionRequirement by unit;
        satisfy lifecycleReq : LifecycleRequirement by unit;
        satisfy scalabilityReq : ScalabilityRequirement by array;
    }
}
