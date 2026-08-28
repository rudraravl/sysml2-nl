package FlowMeasurementSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    public import Definitions::*;

    package Definitions {
        item def Fluid {
            attribute temperature :> ISQ::temperature;
            attribute pressure :> ISQ::pressure;
        }

        item def RawSignal {
            attribute voltage : Real;
        }

        item def CalibratedMeasurement {
            attribute flowRate : Real;
            attribute temperature :> ISQ::temperature;
            attribute pressure :> ISQ::pressure;
            attribute timestamp : Time::DateTime;
            attribute status : String;
        }

        item def CalibrationData {
            attribute offset : Real;
            attribute gain : Real;
        }

        item def ReferenceFlow {
            attribute flowRate : Real;
        }

        item def DataPacket {
            ref item measurement : CalibratedMeasurement;
            attribute unitId : String;
        }

        item def StartMeasurement;
        item def StopMeasurement;
        item def StartCalibration;
        item def CalibrationComplete;
        item def FaultDetected;
        item def Reset;

        port def FluidPort {
            inout item fluid : Fluid;
        }

        port def RawSignalPort {
            inout item signal : RawSignal;
        }

        port def MeasurementPort {
            inout item measurement : CalibratedMeasurement;
        }

        port def DataPort {
            inout item data : DataPacket;
        }

        port def CommPort {
            inout item data : DataPacket;
        }

        port def PowerPort {
            attribute voltage : Real;
        }

        action def MeasureFlow {
            in signal : RawSignal;
            in calibration : CalibrationData;
            out measurement : CalibratedMeasurement;
        }

        action def PerformCalibration {
            in reference : ReferenceFlow;
            out calibration : CalibrationData;
        }

        action def LogData {
            in packet : DataPacket;
        }

        state def SensorStates {
            action measureFlow : MeasureFlow;
            action performCalibration : PerformCalibration;

            entry; then standby;
            state standby;
            accept StartMeasurement then operational;
            accept StartCalibration then calibrating;

            state operational {
                do measureFlow;
            }
            accept StopMeasurement then standby;
            accept FaultDetected then fault;

            state calibrating {
                do performCalibration;
            }
            accept CalibrationComplete then standby;
            accept FaultDetected then fault;

            state fault;
            accept Reset then standby;
        }

        part def SensingElement {
            port fluidPort : FluidPort;
            port signalOut : RawSignalPort;
        }

        part def SignalConditioner {
            port signalIn : RawSignalPort;
            port signalOut : RawSignalPort;
        }

        part def FlowSensor {
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
            port measurementOut : MeasurementPort;
            port powerIn : PowerPort;

            part sensingElement : SensingElement;
            part signalConditioner : SignalConditioner;
            ref item calibrationData : CalibrationData;

            exhibit state sensorStates : SensorStates;

            connect fluidIn to sensingElement.fluidPort;
            connect sensingElement.fluidPort to fluidOut;
            connect sensingElement.signalOut to signalConditioner.signalIn;
        }

        part def DataProcessor {
            port measurementIn : MeasurementPort;
            port dataOut : DataPort;
            port powerIn : PowerPort;
        }

        part def PowerModule {
            port powerOut : PowerPort;
            attribute outputVoltage : Real = 24;
        }

        part def CommunicationModule {
            port dataIn : DataPort;
            port commOut : CommPort;
            port powerIn : PowerPort;
        }

        part def SensingUnit {
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
            port commPort : CommPort;
            port powerIn : PowerPort;

            part flowSensor : FlowSensor;
            part dataProcessor : DataProcessor;
            part powerModule : PowerModule;
            part commModule : CommunicationModule;

            connect fluidIn to flowSensor.fluidIn;
            connect flowSensor.fluidOut to fluidOut;
            connect flowSensor.measurementOut to dataProcessor.measurementIn;
            connect dataProcessor.dataOut to commModule.dataIn;
            connect commModule.commOut to commPort;
            connect powerIn to powerModule.powerOut;
            connect powerModule.powerOut to flowSensor.powerIn;
            connect powerModule.powerOut to dataProcessor.powerIn;
            connect powerModule.powerOut to commModule.powerIn;
        }

        part def DataLogger {
            port commPort : CommPort;
            attribute storageCapacity : Integer = 10000;
            perform action logData : LogData;
        }

        part def Pipeline {
            port fluidPort : FluidPort;
        }

        requirement def AccuracyRequirement {
            doc /* The flow sensor shall have an accuracy of within +/- 1.5% of the reading. */
            attribute accuracy : Real = 1.5;
        }

        requirement def RangeRequirement {
            doc /* The flow sensor shall measure flow rates from 0 to 500 liters per minute. */
            attribute minFlow : Real = 0.0;
            attribute maxFlow : Real = 500.0;
        }

        requirement def ResponseTimeRequirement {
            doc /* The flow sensor shall have a response time of less than 200 milliseconds. */
            attribute maxResponseTime :> ISQ::time = 0.2 [SI::s];
        }

        requirement def FlowSensorRequirements {
            public import AccuracyRequirement;
            public import RangeRequirement;
            public import ResponseTimeRequirement;
        }
    }

    package Usages {
        private import Definitions::*;

        part flowMeasurementSystem {
            part pipeline : Pipeline;
            part sensingUnit : SensingUnit;
            part dataLogger : DataLogger;

            connect pipeline.fluidPort to sensingUnit.fluidIn;
            connect sensingUnit.fluidOut to pipeline.fluidPort;
            connect sensingUnit.commPort to dataLogger.commPort;
        }
    }
}
