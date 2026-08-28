package MassFlowSensingUnitModel {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    package Definitions {
        value type MassFlowRateValue :> ISQ::massFlowRate;
        value type TemperatureValue :> ISQ::temperature;
        value type PressureValue :> ISQ::pressure;
        value type ResponseTimeValue :> ISQ::time;
        value type Percentage :> ScalarValues::Real;

        enum def OperationalStatus {
            nominal;
            degraded;
            fault;
        }

        item def ProcessFluid {
            attribute massFlowRate : MassFlowRateValue;
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
        }

        item def RawMeasurement {
            attribute massFlowRate : MassFlowRateValue;
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
        }

        item def ProcessedData {
            attribute massFlowRate : MassFlowRateValue;
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
            attribute status : OperationalStatus;
        }

        item def StartMeasurement;
        item def StopMeasurement;
        item def FaultDetected;
        item def Reset;

        port def FluidInPort {
            in item fluid : ProcessFluid;
        }

        port def FluidOutPort {
            out item fluid : ProcessFluid;
        }

        port def RawDataOutPort {
            out item raw : RawMeasurement;
        }

        port def RawDataInPort {
            in item raw : RawMeasurement;
        }

        port def DataOutPort {
            out item data : ProcessedData;
        }

        port def DataInPort {
            in item data : ProcessedData;
        }

        action def Initialize;

        action def SenseFluidProperties {
            in item fluid : ProcessFluid;
            out item raw : RawMeasurement;
        }

        action def FilterData {
            in item raw : RawMeasurement;
            out item processed : ProcessedData;
        }

        action def MeasureFluid {
            in item fluid : ProcessFluid;
            out item processed : ProcessedData;
        }

        part def MassFlowSensor {
            port fluidIn : FluidInPort;
            port fluidOut : FluidOutPort;
            port rawOut : RawDataOutPort;
            perform action senseFluidProperties : SenseFluidProperties;
        }

        part def SignalProcessor {
            port rawIn : RawDataInPort;
            port dataOut : DataOutPort;
            perform action filterData : FilterData;
        }

        part def ExternalMonitoringSystem {
            port dataIn : DataInPort;
        }

        part def MassFlowSensingUnit {
            attribute id : ScalarValues::String;
            attribute lastCalibrationDate : ScalarValues::String;
            attribute accuracy : Percentage;
            attribute responseTime : ResponseTimeValue;
            attribute operationalStatus : OperationalStatus;

            port inlet : FluidInPort;
            port outlet : FluidOutPort;
            port dataInterface : DataOutPort;

            part massFlowSensor : MassFlowSensor;
            part signalProcessor : SignalProcessor;

            connect inlet to massFlowSensor.fluidIn;
            connect massFlowSensor.fluidOut to outlet;
            connect massFlowSensor.rawOut to signalProcessor.rawIn;
            connect signalProcessor.dataOut to dataInterface;

            perform action initialize : Initialize;
            perform action measureFluid : MeasureFluid;
            exhibit state operationalStates : OperationalStates;
        }

        state def OperationalStates {
            state Initializing {
                do action initialize : Initialize;
            }
            state Ready;
            state Measuring {
                do action measureFluid : MeasureFluid;
            }
            state Fault;

            transition initial then Initializing;
            transition init_to_ready first Initializing then Ready;
            transition ready_to_measuring first Ready accept StartMeasurement then Measuring;
            transition measuring_to_ready first Measuring accept StopMeasurement then Ready;
            transition ready_to_fault first Ready accept FaultDetected then Fault;
            transition measuring_to_fault first Measuring accept FaultDetected then Fault;
            transition fault_to_ready first Fault accept Reset then Ready;
        }

        requirement def FlowRangeRequirement {
            doc /* The unit shall measure mass flow rate in the range 0 to 100 kg/s. */
            attribute minFlow : MassFlowRateValue = 0 [SI::kg/s];
            attribute maxFlow : MassFlowRateValue = 100 [SI::kg/s];
        }

        requirement def AccuracyRequirement {
            doc /* The unit shall have an accuracy of at least 2%. */
            attribute maxError : Percentage = 2.0;
        }

        requirement def ResponseTimeRequirement {
            doc /* The unit shall respond to changes in flow within 100 milliseconds. */
            attribute maxResponseTime : ResponseTimeValue = 100 [SI::ms];
        }
    }

    package Usages {
        private import Definitions::*;

        individual def SpecificMassFlowSensingUnit :> MassFlowSensingUnit;

        part massFlowSensingInstallation {
            individual mfsUnit : SpecificMassFlowSensingUnit {
                :>> id = "MFS-2024-001";
                :>> lastCalibrationDate = "2024-01-15";
                :>> accuracy = 2.0;
                :>> responseTime = 100 [SI::ms];
                :>> operationalStatus = OperationalStatus::nominal;

                satisfy req FlowRangeRequirement;
                satisfy req AccuracyRequirement;
                satisfy req ResponseTimeRequirement;
            }

            part externalSystem : ExternalMonitoringSystem;

            connect mfsUnit.dataInterface to externalSystem.dataIn;
        }
    }
}
