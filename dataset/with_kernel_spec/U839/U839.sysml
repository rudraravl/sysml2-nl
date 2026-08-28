package AtmosphericMonitoringStation {
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        public import AttributeDefinitions::*;
        public import ItemDefinitions::*;
        public import PortDefinitions::*;
        public import PartDefinitions::*;
        public import ActionDefinitions::*;
        public import RequirementDefinitions::*;

        package AttributeDefinitions {
            attribute def StartSignal;
            attribute def StopSignal;
            attribute def DataReadySignal;
            attribute def ValidationPassSignal;
            attribute def ArchiveCompleteSignal;

            enum def QualityGrade {
                excellent;
                good;
                poor;
            }

            attribute def VoltageValue :> ScalarValues::Real;
            attribute def TemperatureValue :> ScalarValues::Real;
            attribute def CurrentValue :> ScalarValues::Real;
            attribute def IrradianceValue :> ScalarValues::Real;

            attribute def CalibrationCoefficients {
                attribute sensitivityFactor : ScalarValues::Real;
                attribute stefanBoltzmannConstant : ScalarValues::Real = 5.670374419e-8;
                attribute domeEmissivity : ScalarValues::Real;
            }
        }

        package ItemDefinitions {
            item def InfraredRadiation;

            item def VoltageSignal {
                attribute value : VoltageValue;
            }

            item def TemperatureReading {
                attribute value : TemperatureValue;
            }

            item def ConditionedData {
                attribute thermopileVoltage : VoltageValue;
                attribute caseTemperature : TemperatureValue;
                attribute domeTemperature : TemperatureValue;
            }

            item def IrradianceResult {
                attribute value : IrradianceValue;
                attribute quality : QualityGrade;
            }

            item def DataReport {
                attribute timestamp : ScalarValues::String;
                attribute irradiance : IrradianceValue;
                attribute quality : QualityGrade;
            }

            item def ValidatedReport {
                item report : DataReport;
                attribute isValid : ScalarValues::Boolean;
            }
        }

        package PortDefinitions {
            port def RadiationInPort {
                in item radiation : InfraredRadiation;
            }

            port def VoltageOutPort {
                out item signal : VoltageSignal;
            }

            port def TemperatureOutPort {
                out item reading : TemperatureReading;
            }

            port def ConditionedDataOutPort {
                out item data : ConditionedData;
            }

            port def IrradianceResultOutPort {
                out item result : IrradianceResult;
            }

            port def ReportOutPort {
                out item report : DataReport;
            }

            port def ReportInPort {
                in item report : DataReport;
            }

            port def ValidatedReportOutPort {
                out item validatedReport : ValidatedReport;
            }

            port def PowerOutPort {
                out voltage : VoltageValue;
                out current : CurrentValue;
            }

            port def PowerInPort {
                in voltage : VoltageValue;
                in current : CurrentValue;
            }
        }

        package ActionDefinitions {
            action def DetectRadiation {
                in item radiation : InfraredRadiation;
                out item signal : VoltageSignal;
            }

            action def MeasureTemperature {
                out item reading : TemperatureReading;
            }

            action def ConditionSignal {
                in item thermopileSignal : VoltageSignal;
                in item caseTemp : TemperatureReading;
                in item domeTemp : TemperatureReading;
                out item data : ConditionedData;
            }

            action def CalculateIrradiance {
                in item data : ConditionedData;
                in calibration : CalibrationCoefficients;
                out item result : IrradianceResult;
            }

            action def LogData {
                in item result : IrradianceResult;
                out item report : DataReport;
            }

            action def ValidateReport {
                in item report : DataReport;
                out item validatedReport : ValidatedReport;
            }

            action def ArchiveReport {
                in item validatedReport : ValidatedReport;
            }

            action def AcquireData {
                in item radiation : InfraredRadiation;
                out item report : DataReport;
            }

            action def ProvidePower {
                out voltage : VoltageValue;
                out current : CurrentValue;
            }
        }

        package PartDefinitions {
            part def ThermopileDetector {
                port radiationInPort : RadiationInPort;
                port voltageOutPort : VoltageOutPort;
                perform action detectRadiation : DetectRadiation {
                    in item radiation = radiationInPort.radiation;
                    out item signal = voltageOutPort.signal;
                }
            }

            part def Thermistor {
                attribute location : ScalarValues::String;
                port tempOutPort : TemperatureOutPort;
                perform action measureTemperature : MeasureTemperature {
                    out item reading = tempOutPort.reading;
                }
            }

            part def SignalConditioner {
                port thermopileInPort : ~VoltageOutPort;
                port caseTempInPort : ~TemperatureOutPort;
                port domeTempInPort : ~TemperatureOutPort;
                port dataOutPort : ConditionedDataOutPort;
                port powerInPort : PowerInPort;
                perform action conditionSignal : ConditionSignal {
                    in item thermopileSignal = thermopileInPort.signal;
                    in item caseTemp = caseTempInPort.reading;
                    in item domeTemp = domeTempInPort.reading;
                    out item data = dataOutPort.data;
                }
            }

            part def IrradianceCalculator {
                attribute calibration : CalibrationCoefficients;
                port dataInPort : ~ConditionedDataOutPort;
                port resultOutPort : IrradianceResultOutPort;
                port powerInPort : PowerInPort;
                perform action calculateIrradiance : CalculateIrradiance {
                    in item data = dataInPort.data;
                    in calibration = calibration;
                    out item result = resultOutPort.result;
                }
            }

            part def DataLogger {
                port resultInPort : ~IrradianceResultOutPort;
                port reportOutPort : ReportOutPort;
                port powerInPort : PowerInPort;
                perform action logData : LogData {
                    in item result = resultInPort.result;
                    out item report = reportOutPort.report;
                }
            }

            part def Pyrgeometer {
                attribute serialNumber : ScalarValues::String;
                attribute calibration : CalibrationCoefficients;
                port radiationInPort : RadiationInPort;
                port powerInPort : PowerInPort;
                port reportOutPort : ReportOutPort;

                part thermopileDetector : ThermopileDetector;
                part caseThermistor : Thermistor {
                    attribute location = "case";
                }
                part domeThermistor : Thermistor {
                    attribute location = "dome";
                }
                part signalConditioner : SignalConditioner;
                part irradianceCalculator : IrradianceCalculator {
                    :>> calibration = Pyrgeometer::calibration;
                }
                part dataLogger : DataLogger;

                flow radiationInPort.radiation to thermopileDetector.radiationInPort.radiation;
                flow thermopileDetector.voltageOutPort.signal to signalConditioner.thermopileInPort.signal;
                flow caseThermistor.tempOutPort.reading to signalConditioner.caseTempInPort.reading;
                flow domeThermistor.tempOutPort.reading to signalConditioner.domeTempInPort.reading;
                flow signalConditioner.dataOutPort.data to irradianceCalculator.dataInPort.data;
                flow irradianceCalculator.resultOutPort.result to dataLogger.resultInPort.result;
                flow dataLogger.reportOutPort.report to reportOutPort.report;
                flow powerInPort.voltage to signalConditioner.powerInPort.voltage;
                flow powerInPort.current to signalConditioner.powerInPort.current;
                flow powerInPort.voltage to irradianceCalculator.powerInPort.voltage;
                flow powerInPort.current to irradianceCalculator.powerInPort.current;
                flow powerInPort.voltage to dataLogger.powerInPort.voltage;
                flow powerInPort.current to dataLogger.powerInPort.current;

                exhibit state pyrgeometerStates {
                    entry; then idle;
                    state idle;
                    accept StartSignal then measuring;
                    state measuring {
                        do performMeasurementCycle;
                    }
                    accept StopSignal then idle;
                }

                perform action performMeasurementCycle : AcquireData {
                    in item radiation = radiationInPort.radiation;
                    out item report = reportOutPort.report;
                    action detect : DetectRadiation {
                        in item radiation = thermopileDetector.radiationInPort.radiation;
                        out item signal : VoltageSignal;
                    }
                    flow detect.signal to condition.thermopileSignal;
                    action measureCaseTemp : MeasureTemperature {
                        out item reading : TemperatureReading;
                    }
                    flow measureCaseTemp.reading to condition.caseTemp;
                    action measureDomeTemp : MeasureTemperature {
                        out item reading : TemperatureReading;
                    }
                    flow measureDomeTemp.reading to condition.domeTemp;
                    action condition : ConditionSignal {
                        in item thermopileSignal : VoltageSignal;
                        in item caseTemp : TemperatureReading;
                        in item domeTemp : TemperatureReading;
                        out item data : ConditionedData;
                    }
                    flow condition.data to calculate.data;
                    action calculate : CalculateIrradiance {
                        in item data : ConditionedData;
                        in calibration = calibration;
                        out item result : IrradianceResult;
                    }
                    flow calculate.result to log.result;
                    action log : LogData {
                        in item result : IrradianceResult;
                        out item report : DataReport;
                    }
                }
            }

            part def PowerSupply {
                port powerOutPort : PowerOutPort;
                perform action providePower : ProvidePower {
                    out voltage = powerOutPort.voltage;
                    out current = powerOutPort.current;
                }
            }

            part def DataArchive {
                port reportInPort : ReportInPort;
                port validatedOutPort : ValidatedReportOutPort;
                perform action validateReport : ValidateReport {
                    in item report = reportInPort.report;
                    out item validatedReport = validatedOutPort.validatedReport;
                }
                perform action archiveReport : ArchiveReport {
                    in item validatedReport = validatedOutPort.validatedReport;
                }
            }

            part def AtmosphericStation {
                attribute stationId : ScalarValues::String;
                port powerOutPort : PowerOutPort;
                port archiveOutPort : ValidatedReportOutPort;

                part pyrgeometer : Pyrgeometer;
                part dataArchive : DataArchive;
                part powerSupply : PowerSupply;

                flow powerSupply.powerOutPort.voltage to pyrgeometer.powerInPort.voltage;
                flow powerSupply.powerOutPort.current to pyrgeometer.powerInPort.current;
                flow powerSupply.powerOutPort.voltage to powerOutPort.voltage;
                flow powerSupply.powerOutPort.current to powerOutPort.current;
                flow pyrgeometer.reportOutPort.report to dataArchive.reportInPort.report;
                flow dataArchive.validatedOutPort.validatedReport to archiveOutPort.validatedReport;

                exhibit state stationStates {
                    entry; then off;
                    state off;
                    state monitoring {
                        do acquireAndArchive;
                    }
                    transition off_to_monitoring
                        first off
                        accept StartSignal
                        then monitoring;
                    transition monitoring_to_off
                        first monitoring
                        accept StopSignal
                        then off;
                }

                perform action acquireAndArchive {
                    action acquire : AcquireData {
                        in item radiation = pyrgeometer.radiationInPort.radiation;
                        out item report : DataReport;
                    }
                    flow acquire.report to validate.report;
                    action validate : ValidateReport {
                        in item report : DataReport;
                        out item validatedReport : ValidatedReport;
                    }
                    flow validate.validatedReport to archive.validatedReport;
                    action archive : ArchiveReport {
                        in item validatedReport : ValidatedReport;
                    }
                }
            }
        }

        package RequirementDefinitions {
            requirement def MeasurementRangeRequirement {
                doc /* The pyrgeometer shall measure downwelling longwave irradiance from 0 to 800 W/m^2. */
                subject pyrgeometer : Pyrgeometer;
                attribute minRange : IrradianceValue = 0;
                attribute maxRange : IrradianceValue = 800;
            }

            requirement def MeasurementAccuracyRequirement {
                doc /* The pyrgeometer shall achieve measurement uncertainty within 5 W/m^2. */
                subject pyrgeometer : Pyrgeometer;
                attribute maxUncertainty : IrradianceValue = 5;
            }

            requirement def DataQualityRequirement {
                doc /* Each measurement shall include a quality indicator of excellent, good, or poor. */
                subject pyrgeometer : Pyrgeometer;
            }

            requirement def ContinuousOperationRequirement {
                doc /* The station shall continuously acquire radiation data when powered. */
                subject station : AtmosphericStation;
            }

            requirement def ArchivingRequirement {
                doc /* The station shall archive validated radiation reports for long-term analysis. */
                subject station : AtmosphericStation;
            }
        }
    }

    package Usages {
        import Definitions::*;

        part station : AtmosphericStation {
            satisfy ContinuousOperationRequirement {
                subject station = station;
            }
            satisfy ArchivingRequirement {
                subject station = station;
            }
            satisfy MeasurementRangeRequirement {
                subject pyrgeometer = pyrgeometer;
            }
            satisfy MeasurementAccuracyRequirement {
                subject pyrgeometer = pyrgeometer;
            }
            satisfy DataQualityRequirement {
                subject pyrgeometer = pyrgeometer;
            }
        }
    }
}
