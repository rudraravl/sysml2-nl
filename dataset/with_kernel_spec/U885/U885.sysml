package 'Soft Sensor System' {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SI::*;

    package DataItems {
        item def RawSensorData {
            attribute temperature : ISQ::temperature;
            attribute pressure : ISQ::pressure;
            attribute flowRate : ISQ::volumeFlowRate;
        }

        item def ProcessedSensorData {
            attribute temperature : ISQ::temperature;
            attribute pressure : ISQ::pressure;
            attribute flowRate : ISQ::volumeFlowRate;
        }

        item def ConcentrationEstimate {
            attribute concentration : Real;
            attribute confidenceScore : Real;
            attribute qualityMetric : Real;
        }

        attribute def CalibrationCoefficients {
            attribute intercept : Real;
            attribute temperatureCoeff : Real;
            attribute pressureCoeff : Real;
            attribute flowCoeff : Real;
        }
    }

    package Ports {
        private import DataItems::*;

        port def RawDataOutPort {
            out data : RawSensorData;
        }

        port def RawDataInPort {
            in data : RawSensorData;
        }

        port def ProcessedDataOutPort {
            out data : ProcessedSensorData;
        }

        port def ProcessedDataInPort {
            in data : ProcessedSensorData;
        }

        port def EstimateOutPort {
            out data : ConcentrationEstimate;
        }

        port def EstimateInPort {
            in data : ConcentrationEstimate;
        }
    }

    package Calculations {
        private import DataItems::*;

        calc def FilterTemperature {
            in raw : ISQ::temperature;
            in alpha : Real;
            in prev : ISQ::temperature;
            return : ISQ::temperature = alpha * raw + (1.0 - alpha) * prev;
        }

        calc def FilterPressure {
            in raw : ISQ::pressure;
            in alpha : Real;
            in prev : ISQ::pressure;
            return : ISQ::pressure = alpha * raw + (1.0 - alpha) * prev;
        }

        calc def FilterFlow {
            in raw : ISQ::volumeFlowRate;
            in alpha : Real;
            in prev : ISQ::volumeFlowRate;
            return : ISQ::volumeFlowRate = alpha * raw + (1.0 - alpha) * prev;
        }

        calc def MultipleLinearRegression {
            in intercept : Real;
            in tempCoeff : Real;
            in pressureCoeff : Real;
            in flowCoeff : Real;
            in temperature : ISQ::temperature;
            in pressure : ISQ::pressure;
            in flowRate : ISQ::volumeFlowRate;
            return : Real = intercept + tempCoeff * temperature + pressureCoeff * pressure + flowCoeff * flowRate;
        }
    }

    package Actions {
        private import DataItems::*;
        private import Calculations::*;

        action def AcquireData {
            in temp : ISQ::temperature;
            in pres : ISQ::pressure;
            in flow : ISQ::volumeFlowRate;
            out raw : RawSensorData = new RawSensorData(
                temperature = temp,
                pressure = pres,
                flowRate = flow
            );
        }

        action def ProcessSignals {
            in raw : RawSensorData;
            in alpha : Real;
            in prevTemp : ISQ::temperature;
            in prevPressure : ISQ::pressure;
            in prevFlow : ISQ::volumeFlowRate;
            out processed : ProcessedSensorData = new ProcessedSensorData(
                temperature = FilterTemperature(raw.temperature, alpha, prevTemp),
                pressure = FilterPressure(raw.pressure, alpha, prevPressure),
                flowRate = FilterFlow(raw.flowRate, alpha, prevFlow)
            );
            out newPrevTemp : ISQ::temperature = processed.temperature;
            out newPrevPressure : ISQ::pressure = processed.pressure;
            out newPrevFlow : ISQ::volumeFlowRate = processed.flowRate;
        }

        action def EstimateConcentration {
            in processed : ProcessedSensorData;
            in coefficients : CalibrationCoefficients;
            out concentration : Real = MultipleLinearRegression(
                coefficients.intercept,
                coefficients.temperatureCoeff,
                coefficients.pressureCoeff,
                coefficients.flowCoeff,
                processed.temperature,
                processed.pressure,
                processed.flowRate
            );
        }

        action def ValidateEstimate {
            in estimate : Real;
            in minConcentration : Real;
            in maxConcentration : Real;
            out result : ConcentrationEstimate = new ConcentrationEstimate(
                concentration = estimate,
                confidenceScore = 1.0,
                qualityMetric = 100.0
            );
        }
    }

    package Components {
        private import DataItems::*;
        private import Ports::*;

        part def DataAcquisitionModule {
            in envTemp : ISQ::temperature;
            in envPressure : ISQ::pressure;
            in envFlow : ISQ::volumeFlowRate;
            port outPort : RawDataOutPort;
        }

        part def SignalProcessor {
            attribute alpha : Real = 0.2;
            attribute prevTemp : ISQ::temperature;
            attribute prevPressure : ISQ::pressure;
            attribute prevFlow : ISQ::volumeFlowRate;
            port inPort : RawDataInPort;
            port outPort : ProcessedDataOutPort;
        }

        part def MathematicalModel {
            attribute coefficients : CalibrationCoefficients;
            port inPort : ProcessedDataInPort;
            port outPort : EstimateOutPort;
        }

        part def ValidationModule {
            attribute minConcentration : Real = 0.0;
            attribute maxConcentration : Real = 1000.0;
            port inPort : EstimateInPort;
            port outPort : EstimateOutPort;
        }
    }

    package System {
        private import DataItems::*;
        private import Ports::*;
        private import Calculations::*;
        private import Actions::*;
        private import Components::*;

        part def SoftSensorSystem {
            in tempSignal : ISQ::temperature;
            in pressureSignal : ISQ::pressure;
            in flowSignal : ISQ::volumeFlowRate;
            port resultPort : EstimateOutPort;

            part dataAcquisition : DataAcquisitionModule;
            part signalProcessor : SignalProcessor;
            part mathModel : MathematicalModel;
            part validation : ValidationModule;

            connect dataAcquisition.outPort to signalProcessor.inPort;
            connect signalProcessor.outPort to mathModel.inPort;
            connect mathModel.outPort to validation.inPort;
            connect validation.outPort to resultPort;

            attribute raw : RawSensorData;
            attribute processed : ProcessedSensorData;
            attribute estimate : Real;
            attribute result : ConcentrationEstimate;

            state machine def SoftSensorOperation {
                state AcquiringData;
                state Processing;
                state Estimating;
                state Validating;

                transition from AcquiringData to Processing;
                transition from Processing to Estimating;
                transition from Estimating to Validating;
                transition from Validating to AcquiringData;
            }

            state machine operation : SoftSensorOperation;
        }
    }

    package Requirements {
        private import System::*;
        private import DataItems::*;

        requirement def AccuracyRequirement {
            doc /* The estimated concentration shall be within 3 percent of the actual concentration. */
            subject softSensor : SoftSensorSystem;
            attribute estimated : Real;
            attribute actual : Real;
            constraint { estimated >= 0.97 * actual and estimated <= 1.03 * actual }
        }

        requirement def LatencyRequirement {
            doc /* The system shall produce an estimate within 200 milliseconds of receiving new data. */
            subject softSensor : SoftSensorSystem;
            attribute latency : ISQ::time;
            constraint { latency <= 0.2 [s] }
        }

        requirement def ReliabilityRequirement {
            doc /* The system shall operate continuously without failure for extended periods. */
            subject softSensor : SoftSensorSystem;
            attribute targetUptime : Real = 0.999;
        }

        requirement def SoftSensorRequirements {
            subject softSensor : SoftSensorSystem;
            requirement accuracy : AccuracyRequirement;
            requirement latency : LatencyRequirement;
            requirement reliability : ReliabilityRequirement;
        }
    }

    package Instances {
        private import System::*;
        private import DataItems::*;
        private import Components::*;

        individual part def SoftSensor_1 :> SoftSensorSystem;

        individual part softSensor_1 : SoftSensor_1 {
            part :>> mathModel : MathematicalModel {
                attribute :>> coefficients : CalibrationCoefficients {
                    :>> intercept = 10.0;
                    :>> temperatureCoeff = 0.05;
                    :>> pressureCoeff = 0.0001;
                    :>> flowCoeff = 50.0;
                }
            }
            part :>> validation : ValidationModule {
                attribute :>> minConcentration = 0.0;
                attribute :>> maxConcentration = 500.0;
            }
        }
    }
}
