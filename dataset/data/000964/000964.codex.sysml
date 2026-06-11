package ActinometerSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Irradiance :> ISQ::powerPerArea {
        unit = W / m^2;
    }

    attribute def RadiantExposure :> ISQ::energyPerArea {
        unit = J / m^2;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = K;
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = V;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = A;
    }

    attribute def TimeDuration :> ISQ::time {
        unit = s;
    }

    attribute def Angle :> ISQ::planeAngle {
        unit = deg;
    }

    attribute def Area :> ISQ::area {
        unit = m^2;
    }

    attribute def DataRate :> ISQ::frequency {
        unit = Hz;
    }

    enum def MeasurementStateKind {
        enum idle;
        enum darkCalibration;
        enum solarAcquisition;
        enum compensation;
        enum validated;
        enum faulted;
    }

    item def SolarRadiation {
        attribute directNormalIrradiance : Irradiance;
        attribute spectralBandLow : Real = 300.0;
        attribute spectralBandHigh : Real = 3000.0;
        attribute incidenceAngle : Angle;
    }

    item def ThermalSignal {
        attribute absorberTemperature : Temperature;
        attribute referenceTemperature : Temperature;
        attribute differentialTemperature : Temperature;
    }

    item def ElectricalSignal {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute sampleTime : TimeDuration;
    }

    item def IrradianceMeasurement {
        attribute irradiance : Irradiance;
        attribute exposure : RadiantExposure;
        attribute integrationPeriod : TimeDuration;
        attribute sensorTemperature : Temperature;
        attribute qualityCode : MeasurementStateKind;
    }

    item def Command {
        attribute startMeasurement : Boolean;
        attribute performDarkCalibration : Boolean;
        attribute resetFault : Boolean;
        attribute requestedSampleRate : DataRate;
    }

    item def Status {
        attribute state : MeasurementStateKind;
        attribute calibrated : Boolean;
        attribute faultPresent : Boolean;
        attribute messageCode : Integer;
    }

    port def OpticalInputPort {
        in item radiation : SolarRadiation;
    }

    port def ThermalSignalPort {
        out item thermalSignal : ThermalSignal;
    }

    port def ElectricalSignalPort {
        out item electricalSignal : ElectricalSignal;
    }

    port def MeasurementOutputPort {
        out item measurement : IrradianceMeasurement;
        out item status : Status;
    }

    port def CommandInputPort {
        in item command : Command;
    }

    port def PowerInputPort {
        in attribute supplyVoltage : Voltage;
        in attribute supplyCurrent : Current;
    }

    part def Actinometer {
        attribute apertureArea : Area = 0.0001 [m^2];
        attribute nominalSensitivity : Real = 12.5;
        attribute darkOffset : Voltage = 0.0 [V];
        attribute calibrationFactor : Real = 1.0;
        attribute operatingTemperatureMin : Temperature = 253.15 [K];
        attribute operatingTemperatureMax : Temperature = 323.15 [K];
        attribute sampleRate : DataRate = 1.0 [Hz];

        port opticalIn : OpticalInputPort;
        port commandIn : CommandInputPort;
        port powerIn : PowerInputPort;
        port measurementOut : MeasurementOutputPort;

        part aperture {
            attribute clearArea : Area = 0.0001 [m^2];
            attribute fieldOfView : Angle = 5.0 [deg];
            port incidentRadiation : OpticalInputPort;
        }

        part blackAbsorber {
            attribute absorptance : Real = 0.97;
            attribute thermalCapacity : Real = 2.4;
            attribute absorberTemperature : Temperature;
            port receivedRadiation : OpticalInputPort;
            port thermalOut : ThermalSignalPort;
        }

        part referenceBody {
            attribute referenceTemperature : Temperature;
            attribute emissivity : Real = 0.92;
        }

        part thermopile {
            attribute sensitivity : Real = 12.5;
            attribute outputVoltage : Voltage;
            port thermalIn : ThermalSignalPort;
            port electricalOut : ElectricalSignalPort;
        }

        part temperatureSensor {
            attribute measuredTemperature : Temperature;
            attribute accuracy : Temperature = 0.2 [K];
        }

        part analogFrontEnd {
            attribute gain : Real = 1000.0;
            attribute inputNoise : Voltage = 0.000001 [V];
            port rawInput : ElectricalSignalPort;
            port conditionedOutput : ElectricalSignalPort;
        }

        part processor {
            attribute currentState : MeasurementStateKind = MeasurementStateKind::idle;
            attribute computedIrradiance : Irradiance;
            attribute accumulatedExposure : RadiantExposure;
            attribute integrationPeriod : TimeDuration = 1.0 [s];

            port commandInput : CommandInputPort;
            port sensorInput : ElectricalSignalPort;
            port resultOutput : MeasurementOutputPort;
        }

        connect opticalIn.radiation to aperture.incidentRadiation.radiation;
        connect aperture.incidentRadiation.radiation to blackAbsorber.receivedRadiation.radiation;
        connect blackAbsorber.thermalOut.thermalSignal to thermopile.thermalIn.thermalSignal;
        connect thermopile.electricalOut.electricalSignal to analogFrontEnd.rawInput.electricalSignal;
        connect analogFrontEnd.conditionedOutput.electricalSignal to processor.sensorInput.electricalSignal;
        connect commandIn.command to processor.commandInput.command;
        connect processor.resultOutput.measurement to measurementOut.measurement;
        connect processor.resultOutput.status to measurementOut.status;

        action def AcquireSolarRadiation {
            in item radiation : SolarRadiation;
            out item thermalSignal : ThermalSignal;
        }

        action def ConvertThermalToElectrical {
            in item thermalSignal : ThermalSignal;
            out item electricalSignal : ElectricalSignal;
        }

        action def CalculateIrradiance {
            in item electricalSignal : ElectricalSignal;
            in attribute offset : Voltage;
            in attribute calibrationFactor : Real;
            in attribute integrationPeriod : TimeDuration;
            out item measurement : IrradianceMeasurement;
        }

        action def PerformDarkCalibration {
            in item electricalSignal : ElectricalSignal;
            out attribute measuredOffset : Voltage;
        }

        state def MeasurementBehavior {
            state idle;
            state darkCalibration;
            state acquiring;
            state compensating;
            state reporting;
            state faulted;

            transition first idle;

            transition idle_to_darkCalibration
                first idle
                then darkCalibration
                accept Command
                if command.performDarkCalibration;

            transition idle_to_acquiring
                first idle
                then acquiring
                accept Command
                if command.startMeasurement;

            transition darkCalibration_to_idle
                first darkCalibration
                then idle;

            transition acquiring_to_compensating
                first acquiring
                then compensating;

            transition compensating_to_reporting
                first compensating
                then reporting;

            transition reporting_to_acquiring
                first reporting
                then acquiring
                if command.startMeasurement;

            transition reporting_to_idle
                first reporting
                then idle
                if not command.startMeasurement;

            transition any_to_faulted
                first idle
                then faulted
                if powerIn.supplyVoltage < 10.0 [V] or powerIn.supplyVoltage > 30.0 [V];

            transition faulted_to_idle
                first faulted
                then idle
                accept Command
                if command.resetFault;
        }

        exhibit state MeasurementBehavior;
    }

    part def ActinometerStation {
        part actinometer : Actinometer;

        part sunTracker {
            attribute azimuthAngle : Angle;
            attribute elevationAngle : Angle;
            attribute pointingError : Angle = 0.25 [deg];
            port opticalAxis : OpticalInputPort;
        }

        part powerModule {
            attribute outputVoltage : Voltage = 24.0 [V];
            attribute maximumCurrent : Current = 1.0 [A];
            port powerOut : PowerInputPort;
        }

        part dataLogger {
            attribute storageCapacity : Integer = 1000000;
            attribute loggingRate : DataRate = 1.0 [Hz];
            port measurementInput : MeasurementOutputPort;
        }

        part operatorInterface {
            port commandOutput : CommandInputPort;
            port statusInput : MeasurementOutputPort;
        }

        connect sunTracker.opticalAxis.radiation to actinometer.opticalIn.radiation;
        connect powerModule.powerOut.supplyVoltage to actinometer.powerIn.supplyVoltage;
        connect powerModule.powerOut.supplyCurrent to actinometer.powerIn.supplyCurrent;
        connect operatorInterface.commandOutput.command to actinometer.commandIn.command;
        connect actinometer.measurementOut.measurement to dataLogger.measurementInput.measurement;
        connect actinometer.measurementOut.status to dataLogger.measurementInput.status;
        connect actinometer.measurementOut.status to operatorInterface.statusInput.status;
        connect actinometer.measurementOut.measurement to operatorInterface.statusInput.measurement;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The actinometer system shall measure incident solar radiant power per unit area by absorbing radiation in a calibrated black absorber, converting the resulting thermal difference to an electrical signal, compensating for temperature and dark offset, and reporting irradiance and accumulated radiant exposure. */
    }

    requirement def IrradianceMeasurementRequirement {
        attribute minimumRange : Irradiance = 0.0 [W / m^2];
        attribute maximumRange : Irradiance = 1400.0 [W / m^2];
        attribute maximumError : Irradiance = 10.0 [W / m^2];

        require constraint {
            minimumRange <= actinometer.processor.computedIrradiance and
            actinometer.processor.computedIrradiance <= maximumRange
        }
    }

    requirement def SamplingRequirement {
        attribute minimumSampleRate : DataRate = 1.0 [Hz];

        require constraint {
            actinometer.sampleRate >= minimumSampleRate
        }
    }

    requirement def OperatingEnvironmentRequirement {
        attribute minTemperature : Temperature = 253.15 [K];
        attribute maxTemperature : Temperature = 323.15 [K];

        require constraint {
            actinometer.operatingTemperatureMin <= minTemperature and
            actinometer.operatingTemperatureMax >= maxTemperature
        }
    }

    requirement def CalibrationRequirement {
        doc /* The actinometer shall support dark calibration before measurement and shall apply the measured dark offset when computing irradiance. */
    }

    part actinometerStation : ActinometerStation;

    satisfy PrimaryFunctionRequirement by actinometerStation.actinometer;
    satisfy IrradianceMeasurementRequirement by actinometerStation.actinometer.processor;
    satisfy SamplingRequirement by actinometerStation.actinometer;
    satisfy OperatingEnvironmentRequirement by actinometerStation.actinometer;
    satisfy CalibrationRequirement by actinometerStation.actinometer.processor;
}