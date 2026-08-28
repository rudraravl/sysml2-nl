package DigitalBarometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    enum def PowerStateKind {
        active;
        standby;
        shutdown;
    }

    item def RawSensorData {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }

    item def ProcessedData {
        attribute pressure : PressureValue;
        attribute altitude : LengthValue;
    }

    attribute def 'Start Measurement';
    attribute def 'Stop Measurement';
    attribute def 'Start Calibration';
    attribute def 'Calibration Complete';
    attribute def 'Enter Standby';
    attribute def 'Enter Active';
    attribute def 'Shutdown';
    attribute def 'Power On';

    port def PressureSensorOut {
        out raw : RawSensorData;
    }

    port def ProcessorIn {
        in raw : RawSensorData;
    }

    port def ProcessorOut {
        out data : ProcessedData;
    }

    port def DisplayIn {
        in data : ProcessedData;
    }

    port def PowerOut {
        out powerState : PowerStateKind;
    }

    port def PowerControlIn {
        in powerState : PowerStateKind;
    }

    action def SensePressure {
        out raw : RawSensorData;
    }

    action def CompensateTemperature {
        in raw : RawSensorData;
        out compensatedPressure : PressureValue;
    }

    action def FilterData {
        in pressure : PressureValue;
        out filteredPressure : PressureValue;
    }

    calc def AltitudeFromPressure {
        in pressure : PressureValue;
        in seaLevelPressure : PressureValue;
        return altitude : LengthValue;
    }

    action def CalculateAltitude {
        in pressure : PressureValue;
        in seaLevelPressure : PressureValue;
        out altitude : LengthValue;
    }

    action def AssembleData {
        in pressure : PressureValue;
        in altitude : LengthValue;
        out data : ProcessedData;
    }

    action def UpdateDisplay {
        in data : ProcessedData;
    }

    action def MeasurementCycle {
        in seaLevelPressure : PressureValue;
        out data : ProcessedData;

        first start;
        then action sense : SensePressure;
        then action compensate : CompensateTemperature;
        then action filterData : FilterData;
        then action calcAlt : CalculateAltitude;
        then action assemble : AssembleData;
        then action update : UpdateDisplay;
        then done;
    }

    state def BarometerStates;
    state def PowerStates;

    part def PressureSensor {
        port sensorOut : PressureSensorOut;
        port powerCtrlPort : PowerControlIn;
        perform action sense : SensePressure;
    }

    part def DataProcessor {
        port procIn : ProcessorIn;
        port procOut : ProcessorOut;
        port powerCtrlPort : PowerControlIn;
        attribute seaLevelPressure : PressureValue = 101325;
        perform action compensate : CompensateTemperature;
        perform action filterData : FilterData;
        perform action calcAlt : CalculateAltitude;
        perform action assemble : AssembleData;
    }

    part def UserInterface {
        port displayIn : DisplayIn;
        port powerCtrlPort : PowerControlIn;
        perform action update : UpdateDisplay;
    }

    part def PowerManagement {
        port powerOut : PowerOut;
        attribute batteryLevel : Real;
        exhibit state 'power states' : PowerStates {
            entry; then active;

            state active;
            accept 'Enter Standby' then standby;
            accept 'Shutdown' then shutdown;

            state standby;
            accept 'Enter Active' then active;
            accept 'Shutdown' then shutdown;

            state shutdown;
            accept 'Power On' then active;
        }
    }

    part def DigitalBarometer;

    part digitalBarometer : DigitalBarometer {
        part pressureSensor : PressureSensor;
        part dataProcessor : DataProcessor;
        part userInterface : UserInterface;
        part powerManagement : PowerManagement;

        action 'measurement cycle' : MeasurementCycle;

        connect pressureSensor.sensorOut to dataProcessor.procIn;
        connect dataProcessor.procOut to userInterface.displayIn;
        connect powerManagement.powerOut to pressureSensor.powerCtrlPort;
        connect powerManagement.powerOut to dataProcessor.powerCtrlPort;
        connect powerManagement.powerOut to userInterface.powerCtrlPort;

        exhibit state 'barometer states' : BarometerStates {
            entry; then idle;

            state idle;
            accept 'Start Measurement' then measuring;
            accept 'Start Calibration' then calibration;

            state measuring {
                do 'measurement cycle';
            }
            accept 'Stop Measurement' then idle;

            state calibration;
            accept 'Calibration Complete' then idle;
        }
    }

    requirement def PressureAccuracy {
        doc /* The system shall measure atmospheric pressure with an accuracy of ±0.5 hPa. */
    }

    requirement def AltitudeAccuracy {
        doc /* The system shall calculate altitude with an accuracy of ±5 meters. */
    }

    requirement def TemperatureCompensation {
        doc /* The system shall compensate pressure readings for temperature variations. */
    }

    requirement def BatteryLife {
        doc /* The system shall operate for at least 24 hours on a single battery charge. */
    }

    requirement def PowerStateManagement {
        doc /* The system shall support active, standby, and shutdown power states. */
    }

    requirement def RealTimeMeasurement {
        doc /* The system shall continuously measure and display pressure and altitude when in measuring mode. */
    }
}
