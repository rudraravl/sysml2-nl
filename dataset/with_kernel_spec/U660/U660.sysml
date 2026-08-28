package EIS_pH_Sensing_Unit_Model {
    private import ScalarValues::*;

    attribute def pH :> Real {
        doc /* pH value, dimensionless */
    }
    attribute def Temperature :> Real {
        doc /* Temperature in degrees Celsius */
    }
    attribute def Capacitance :> Real {
        doc /* Capacitance in farads */
    }
    attribute def Voltage :> Real {
        doc /* Voltage in volts */
    }
    attribute def Timestamp :> Real {
        doc /* Timestamp in seconds since unit start */
    }

    attribute def PowerOnSignal;
    attribute def WarmupCompleteSignal;
    attribute def SamplePresentSignal;
    attribute def MeasurementCompleteSignal;
    attribute def ProcessingCompleteSignal;
    attribute def SensorFaultSignal;
    attribute def ResetSignal;

    port def CapacitancePort {
        attribute value : Capacitance;
    }
    port def TemperaturePort {
        attribute value : Temperature;
    }
    port def VoltagePort {
        attribute value : Voltage;
    }
    port def DigitalSignalPort {
        attribute value : Voltage;
    }
    port def pHResultPort {
        attribute ph : pH;
        attribute temperature : Temperature;
        attribute timestamp : Timestamp;
    }

    part def PTypeSiliconSubstrate;
    part def SiO2InsulatorLayer;
    part def AgAgClReferenceElectrode;

    part def EIS_SensorElement {
        part substrate : PTypeSiliconSubstrate;
        part insulator : SiO2InsulatorLayer;
        part referenceElectrode : AgAgClReferenceElectrode;
        port capacitanceOut : CapacitancePort;
        port powerIn : VoltagePort;
        action detectCapacitance;
    }

    part def TemperatureSensor {
        port temperatureOut : TemperaturePort;
        port powerIn : VoltagePort;
        action detectTemperature;
    }

    part def SignalConditioner {
        port rawSignalIn : CapacitancePort;
        port conditionedSignalOut : DigitalSignalPort;
        port powerIn : VoltagePort;
        action amplify;
        action filterSignal;
        action digitize;
    }

    part def PowerSupply {
        port powerIn : VoltagePort;
        port powerOut : VoltagePort;
        attribute nominalVoltage : Voltage := 3.3;
    }

    part def Processor {
        port conditionedSignalIn : DigitalSignalPort;
        port temperatureIn : TemperaturePort;
        port phResultOut : pHResultPort;
        port powerIn : VoltagePort;
        action calculatepH;
    }

    part def EIS_pH_SensingUnit {
        attribute rawCapacitance : Capacitance;
        attribute rawTemperature : Temperature;
        attribute phValue : pH;
        attribute timestamp : Timestamp := 0.0;
        attribute referenceCapacitance : Capacitance := 100.0;
        attribute calibrationSlope : Real := 0.1;

        part eisSensor : EIS_SensorElement;
        part tempSensor : TemperatureSensor;
        part signalConditioner : SignalConditioner;
        part powerSupply : PowerSupply;
        part processor : Processor;

        port powerIn : VoltagePort;
        port resultOut : pHResultPort;

        connect powerIn to powerSupply.powerIn;
        connect powerSupply.powerOut to eisSensor.powerIn;
        connect powerSupply.powerOut to tempSensor.powerIn;
        connect powerSupply.powerOut to signalConditioner.powerIn;
        connect powerSupply.powerOut to processor.powerIn;

        connect eisSensor.capacitanceOut to signalConditioner.rawSignalIn;
        connect tempSensor.temperatureOut to processor.temperatureIn;
        connect signalConditioner.conditionedSignalOut to processor.conditionedSignalIn;
        connect processor.phResultOut to resultOut;

        action measureRawData {
            assign rawCapacitance := eisSensor.capacitanceOut.value;
            assign rawTemperature := tempSensor.temperatureOut.value;
        }
        action processMeasurement {
            assign phValue := 7.0 - (rawCapacitance - referenceCapacitance) * calibrationSlope;
            assign timestamp := timestamp + 1.0;
        }
    }

    state def EIS_pH_UnitStates {
        part unit : EIS_pH_SensingUnit;

        entry; then off;

        state off;
        transition off_to_warmup
            first off
            accept PowerOnSignal
            then warmup;

        state warmup;
        transition warmup_to_ready
            first warmup
            accept WarmupCompleteSignal
            then ready;
        transition warmup_to_errorState
            first warmup
            accept SensorFaultSignal
            then errorState;

        state ready;
        transition ready_to_measuring
            first ready
            accept SamplePresentSignal
            then measuring;
        transition ready_to_errorState
            first ready
            accept SensorFaultSignal
            then errorState;

        state measuring {
            do unit.measureRawData;
        }
        transition measuring_to_processing
            first measuring
            accept MeasurementCompleteSignal
            then processing;
        transition measuring_to_errorState
            first measuring
            accept SensorFaultSignal
            then errorState;

        state processing {
            do unit.processMeasurement;
        }
        transition processing_to_ready
            first processing
            accept ProcessingCompleteSignal
            then ready;
        transition processing_to_errorState
            first processing
            accept SensorFaultSignal
            then errorState;

        state errorState;
        transition errorState_to_off
            first errorState
            accept ResetSignal
            then off;
    }

    requirement pHAccuracySpec {
        doc /* The pH measurement accuracy shall be within plus or minus 0.1 pH units over a range of 2 to 12. */
    }
    requirement TemperatureAccuracySpec {
        doc /* The temperature measurement accuracy shall be within plus or minus 0.5 degrees Celsius over -10 to 80 degrees Celsius. */
    }
    requirement WarmupTimeSpec {
        doc /* The unit shall complete warm-up and be ready for measurement within 60 seconds of power-on. */
    }
    requirement MeasurementResponseTimeSpec {
        doc /* The unit shall complete a measurement and return to ready state within 10 seconds after sample introduction. */
    }
    requirement ErrorHandlingSpec {
        doc /* The unit shall enter an error state upon detection of a sensor fault and shall be resettable via a reset signal. */
    }
    requirement SensorCompositionSpec {
        doc /* The EIS sensor shall comprise a p-type silicon substrate, a silicon dioxide insulator layer, and an Ag/AgCl reference electrode. */
    }

    requirement sensingUnitSpecification {
        doc /* Overall requirements for the EIS pH sensing unit. */
        subject unit : EIS_pH_SensingUnit;
        require pHAccuracySpec;
        require TemperatureAccuracySpec;
        require WarmupTimeSpec;
        require MeasurementResponseTimeSpec;
        require ErrorHandlingSpec;
        require SensorCompositionSpec;
    }
}
