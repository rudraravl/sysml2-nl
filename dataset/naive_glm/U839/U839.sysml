package AtmosphericMonitoringStation {
    import ISQ::TemperatureValue;
    import ISQ::ThermodynamicTemperatureValue;
    import ScalarValues::Real;
    import ScalarValues::Integer;
    import ScalarValues::String;
    import ScalarValues::Boolean;

    // ---- Value types with units ----
    attribute def Voltage {
        attribute :>> value : Real;
        attribute :>> unit : String = "V";
    }

    attribute def Resistance {
        attribute :>> value : Real;
        attribute :>> unit : String = "Ohm";
    }

    attribute def Irradiance {
        attribute :>> value : Real;
        attribute :>> unit : String = "W/m^2";
    }

    attribute def Temperature {
        attribute :>> value : Real;
        attribute :>> unit : String = "K";
    }

    attribute def Timestamp {
        attribute :>> value : Integer;
        attribute :>> unit : String = "s";
    }

    enumeration def QualityIndicator {
        EXCELLENT;
        GOOD;
        POOR;
    }

    // ---- Item definitions ----
    item def RawThermopileSignal {
        attribute voltage : Voltage;
    }

    item def RawThermistorReading {
        attribute resistance : Resistance;
        attribute source : String;
    }

    item def ConditionedSample {
        attribute thermopileVoltage : Voltage;
        attribute caseTemperature : Temperature;
        attribute domeTemperature : Temperature;
    }

    item def IrradianceResult {
        attribute downwellingIrradiance : Irradiance;
        attribute quality : QualityIndicator;
    }

    item def MeasurementReport {
        attribute timestamp : Timestamp;
        attribute result : IrradianceResult;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute active : Boolean;
    }

    // ---- Port definitions ----
    port def InfraredPort {
        in item incomingIR : RawThermopileSignal;
    }

    port def RawSignalPort {
        out item thermopileSignal : RawThermopileSignal;
        out item thermistorReading : RawThermistorReading;
    }

    port def ConditionedSignalPort {
        out item sample : ConditionedSample;
    }

    port def ResultPort {
        out item result : IrradianceResult;
    }

    port def ReportPort {
        out item report : MeasurementReport;
        in item power : ElectricalPower;
    }

    // ---- Requirements ----
    requirement def MeasurementAccuracyRequirement {
        attribute maxError : Real = 5.0;
        doc /*
         * The pyrgeometer shall measure downwelling longwave radiation
         * with an error not exceeding maxError W/m^2 under nominal conditions.
         */
    }

    requirement def ContinuousOperationRequirement {
        attribute dutyCycle : Real = 1.0;
        doc /*
         * The station shall continuously acquire, validate, and archive
         * radiation data for long-term scientific analysis.
         */
    }

    requirement def QualityReportingRequirement {
        doc /*
         * Each measurement report shall include a quality indicator
         * classifying the result as excellent, good, or poor.
         */
    }

    // ---- Parts ----
    part def ThermopileDetector {
        attribute sensitivity : Real = 1.0e-6; // V/(W/m^2)
        port infraredIn : InfraredPort;
        port signalOut : RawSignalPort;

        action def ConvertRadiation {
            in ir : RawThermopileSignal;
            out signal : RawThermopileSignal;
        }

        perform ConvertRadiation;
    }

    part def Thermistor {
        attribute nominalResistance : Resistance;
        attribute betaParameter : Real;
        port signalOut : RawSignalPort;

        action def MeasureTemperature {
            out reading : RawThermistorReading;
        }

        perform MeasureTemperature;
    }

    part def SignalConditioner {
        attribute gain : Real = 100.0;
        attribute filterCutoffHz : Real = 1.0;
        port signalIn : RawSignalPort;
        port signalOut : ConditionedSignalPort;

        action def ConditionSignals {
            in thermopile : RawThermopileSignal;
            in caseReading : RawThermistorReading;
            in domeReading : RawThermistorReading;
            out sample : ConditionedSample;
        }

        perform ConditionSignals;
    }

    part def IrradianceCalculator {
        attribute stefanBoltzmannConstant : Real = 5.670374419e-8;
        attribute calibrationFactor : Real = 1.0;
        port signalIn : ConditionedSignalPort;
        port resultOut : ResultPort;

        action def ComputeIrradiance {
            in sample : ConditionedSample;
            out result : IrradianceResult;

            // Apply simplified pyrgeometer equation:
            // E_down = (V_thermopile / sensitivity) + sigma*(T_case^4 - k*(T_dome^4 - T_case^4))
            private attribute computed : Irradiance;
            private attribute qual : QualityIndicator;

            then assign computed.value := sample.thermopileVoltage.value / 1.0e-6
                + stefanBoltzmannConstant * (sample.caseTemperature.value ^ 4);
            then assign qual := if computed.value > 0.0 then QualityIndicator::EXCELLENT
                else if computed.value > -10.0 then QualityIndicator::GOOD
                else QualityIndicator::POOR
                endif endif;
            then assign result.downwellingIrradiance := computed;
            then assign result.quality := qual;
        }

        perform ComputeIrradiance;
    }

    part def DataLogger {
        port resultIn : ResultPort;
        port reportOut : ReportPort;

        action def LogMeasurement {
            in result : IrradianceResult;
            out report : MeasurementReport;

            private attribute ts : Timestamp;
            then assign ts.value := 0; // placeholder replaced by station clock
            then assign report.timestamp := ts;
            then assign report.result := result;
        }

        perform LogMeasurement;
    }

    part def Pyrgeometer {
        attribute serialNumber : String;
        attribute calibrationDate : String;

        port instrumentPort : ReportPort;

        part thermopile : ThermopileDetector;
        part caseThermistor : Thermistor {
            :>> nominalResistance.value := 10000.0;
            :>> nominalResistance.unit := "Ohm";
            :>> betaParameter := 3977.0;
        }
        part domeThermistor : Thermistor {
            :>> nominalResistance.value := 10000.0;
            :>> nominalResistance.unit := "Ohm";
            :>> betaParameter := 3977.0;
        }
        part conditioner : SignalConditioner;
        part calculator : IrradianceCalculator;
        part logger : DataLogger;

        satisfy MeasurementAccuracyRequirement;
        satisfy QualityReportingRequirement;

        connection thermopileToConditioner connect thermopile.signalOut to conditioner.signalIn;
        connection caseThermistorToConditioner connect caseThermistor.signalOut to conditioner.signalIn;
        connection domeThermistorToConditioner connect domeThermistor.signalOut to conditioner.signalIn;
        connection conditionerToCalculator connect conditioner.signalOut to calculator.signalIn;
        connection calculatorToLogger connect calculator.resultOut to logger.resultIn;
        connection loggerToStation connect logger.reportOut to instrumentPort;
    }

    part def AtmosphericMonitoringStation {
        attribute stationId : String;
        attribute location : String;

        port stationPort : ReportPort;

        part pyrgeometer : Pyrgeometer;
        part powerSupply {
            attribute outputVoltage : Voltage;
            port powerOut : ReportPort;
        }
        part archive {
            attribute records : MeasurementReport[0..*];

            action def ArchiveReport {
                in report : MeasurementReport;
                then append report to records;
            }

            perform ArchiveReport;
        }
        part validator {
            action def ValidateReport {
                in report : MeasurementReport;
                out valid : Boolean;
                then assign valid := report.result.quality != QualityIndicator::POOR;
            }
            perform ValidateReport;
        }

        satisfy ContinuousOperationRequirement;

        connection powerToInstrument connect powerSupply.powerOut to pyrgeometer.instrumentPort;
        connection instrumentToStation connect pyrgeometer.instrumentPort to stationPort;

        state machine StationOperation {
            initialize state Initializing;
            state Acquiring;
            state Validating;
            state Archiving;
            state Faulted;

            transition initToAcquire first Initializing then Acquiring
                when pyrgeometer.logger.reportOut.report.timestamp.value > 0;

            transition acquireToValidate first Acquiring then Validating
                when stationPort.report.result.downwellingIrradiance.value >= 0.0;

            transition validateToArchive first Validating then Archiving
                when validator.ValidateReport.valid == true;

            transition archiveToAcquire first Archiving then Acquiring
                when archive.ArchiveReport.done;

            transition anyToFaulted first Acquiring | Validating | Archiving then Faulted
                when stationPort.report.result.quality == QualityIndicator::POOR;

            transition faultedToAcquire first Faulted then Acquiring
                when stationPort.power.active == true;
        }

        exhibit StationOperation;
    }
}
