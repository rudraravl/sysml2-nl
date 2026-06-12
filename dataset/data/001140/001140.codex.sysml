package MassFlowSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def MassFlowRate :> ISQ::massFlowRate {
        unit = SI::kilogramPerSecond;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def Pressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Time :> ISQ::time {
        unit = SI::second;
    }

    item def FluidSample {
        attribute massFlowRate : MassFlowRate;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
    }

    item def ElectricalPower {
        attribute supplyVoltage : Voltage;
        attribute supplyCurrent : Current;
    }

    item def MassFlowMeasurement {
        attribute measuredMassFlowRate : MassFlowRate;
        attribute sensorTemperature : Temperature;
        attribute measurementTime : Time;
        attribute valid : Boolean;
    }

    item def DiagnosticStatus {
        attribute sensorHealthy : Boolean;
        attribute calibrationValid : Boolean;
        attribute flowInRange : Boolean;
        attribute faultCode : Integer;
    }

    port def FluidInletPort {
        in item fluid : FluidSample;
    }

    port def FluidOutletPort {
        out item fluid : FluidSample;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def MeasurementOutputPort {
        out item measurement : MassFlowMeasurement;
    }

    port def DiagnosticOutputPort {
        out item status : DiagnosticStatus;
    }

    port def InternalFluidPort {
        inout item fluid : FluidSample;
    }

    part def MassFlowSensor {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port powerIn : PowerInputPort;
        port measurementOut : MeasurementOutputPort;
        port diagnosticOut : DiagnosticOutputPort;

        attribute minimumRange : MassFlowRate = 0.0 [SI::kilogramPerSecond];
        attribute maximumRange : MassFlowRate = 0.25 [SI::kilogramPerSecond];
        attribute accuracy : MassFlowRate = 0.0025 [SI::kilogramPerSecond];
        attribute responseTime : Time = 0.05 [SI::second];
        attribute operatingVoltage : Voltage = 5.0 [SI::volt];

        action measureMassFlow {
            in item sensedFluid : FluidSample;
            out item measurement : MassFlowMeasurement;

            first start;
            then validateRange;
            then compensateTemperature;
            then emitMeasurement;
            then done;

            action validateRange {
                in item sensedFluid : FluidSample;
                out attribute inRange : Boolean;
            }

            action compensateTemperature {
                in item sensedFluid : FluidSample;
                out attribute compensatedFlow : MassFlowRate;
            }

            action emitMeasurement {
                in attribute compensatedFlow : MassFlowRate;
                out item measurement : MassFlowMeasurement;
            }
        }

        state def SensorStateMachine {
            entry action initializeSensor;

            state off;
            state startup;
            state ready;
            state measuring;
            state fault;

            transition initial then off;
            transition off_to_startup
                first off
                accept PowerApplied
                then startup;

            transition startup_to_ready
                first startup
                accept SelfTestPassed
                then ready;

            transition startup_to_fault
                first startup
                accept SelfTestFailed
                then fault;

            transition ready_to_measuring
                first ready
                accept FluidFlowDetected
                then measuring;

            transition measuring_to_ready
                first measuring
                accept FlowStopped
                then ready;

            transition measuring_to_fault
                first measuring
                accept SensorSignalInvalid
                then fault;

            transition fault_to_startup
                first fault
                accept ResetCommand
                then startup;
        }
    }

    part def SignalConditioner {
        port powerIn : PowerInputPort;
        port measurementIn : MeasurementOutputPort;
        port measurementOut : MeasurementOutputPort;
        port diagnosticOut : DiagnosticOutputPort;

        attribute samplePeriod : Time = 0.01 [SI::second];
        attribute lowPassCutoffFrequency : ISQ::frequency = 20.0 [SI::hertz];

        action filterMeasurement {
            in item rawMeasurement : MassFlowMeasurement;
            out item filteredMeasurement : MassFlowMeasurement;
        }

        action checkDiagnostics {
            in item filteredMeasurement : MassFlowMeasurement;
            out item status : DiagnosticStatus;
        }
    }

    part def SensingUnitController {
        port powerIn : PowerInputPort;
        port measurementIn : MeasurementOutputPort;
        port diagnosticIn : DiagnosticOutputPort;
        port measurementOut : MeasurementOutputPort;
        port diagnosticOut : DiagnosticOutputPort;

        attribute reportingPeriod : Time = 0.1 [SI::second];

        action acquireAndReport {
            in item conditionedMeasurement : MassFlowMeasurement;
            in item diagnosticStatus : DiagnosticStatus;
            out item reportedMeasurement : MassFlowMeasurement;
            out item reportedStatus : DiagnosticStatus;
        }

        state def ControllerStateMachine {
            state unpowered;
            state initializing;
            state operational;
            state degraded;
            state failed;

            transition initial then unpowered;

            transition unpowered_to_initializing
                first unpowered
                accept PowerApplied
                then initializing;

            transition initializing_to_operational
                first initializing
                accept SensorReady
                then operational;

            transition operational_to_degraded
                first operational
                accept DiagnosticWarning
                then degraded;

            transition degraded_to_operational
                first degraded
                accept DiagnosticNominal
                then operational;

            transition operational_to_failed
                first operational
                accept CriticalFault
                then failed;

            transition degraded_to_failed
                first degraded
                accept CriticalFault
                then failed;

            transition failed_to_initializing
                first failed
                accept ResetCommand
                then initializing;
        }
    }

    part def MassFlowSensingUnit {
        port fluidIn : FluidInletPort;
        port fluidOut : FluidOutletPort;
        port powerIn : PowerInputPort;
        port measuredMassFlowOut : MeasurementOutputPort;
        port diagnosticsOut : DiagnosticOutputPort;

        part sensor : MassFlowSensor;
        part conditioner : SignalConditioner;
        part controller : SensingUnitController;

        connection fluidPathIn connect fluidIn to sensor.inlet;
        connection fluidPathOut connect sensor.outlet to fluidOut;

        connection powerToSensor connect powerIn to sensor.powerIn;
        connection powerToConditioner connect powerIn to conditioner.powerIn;
        connection powerToController connect powerIn to controller.powerIn;

        connection rawMeasurementSignal connect sensor.measurementOut to conditioner.measurementIn;
        connection sensorDiagnosticSignal connect sensor.diagnosticOut to controller.diagnosticIn;
        connection conditionedMeasurementSignal connect conditioner.measurementOut to controller.measurementIn;
        connection conditionedDiagnosticSignal connect conditioner.diagnosticOut to controller.diagnosticIn;

        connection reportedMeasurementSignal connect controller.measurementOut to measuredMassFlowOut;
        connection reportedDiagnosticSignal connect controller.diagnosticOut to diagnosticsOut;

        attribute measurementRangeMinimum : MassFlowRate = 0.0 [SI::kilogramPerSecond];
        attribute measurementRangeMaximum : MassFlowRate = 0.25 [SI::kilogramPerSecond];
        attribute requiredAccuracy : MassFlowRate = 0.005 [SI::kilogramPerSecond];
        attribute maximumLatency : Time = 0.15 [SI::second];
        attribute nominalSupplyVoltage : Voltage = 5.0 [SI::volt];

        action senseMassFlow {
            in item incomingFluid : FluidSample;
            out item reportedMeasurement : MassFlowMeasurement;
            out item reportedDiagnostics : DiagnosticStatus;

            first receiveFluid;
            then sensor.measureMassFlow;
            then conditioner.filterMeasurement;
            then conditioner.checkDiagnostics;
            then controller.acquireAndReport;
            then publishOutputs;
            then done;

            action receiveFluid {
                in item incomingFluid : FluidSample;
                out item sensedFluid : FluidSample;
            }

            action publishOutputs {
                in item reportedMeasurement : MassFlowMeasurement;
                in item reportedDiagnostics : DiagnosticStatus;
            }
        }
    }

    requirement def MeasureMassFlowRequirement {
        doc /* The sensing unit shall measure mass flow rate of the fluid passing through it using a mass flow sensor. */

        subject sensingUnit : MassFlowSensingUnit;

        require constraint {
            sensingUnit.sensor.maximumRange >= sensingUnit.measurementRangeMaximum
        }

        require constraint {
            sensingUnit.sensor.minimumRange <= sensingUnit.measurementRangeMinimum
        }
    }

    requirement def AccuracyRequirement {
        doc /* The sensing unit shall report measured mass flow rate with error not exceeding the required accuracy over the specified measurement range. */

        subject sensingUnit : MassFlowSensingUnit;

        require constraint {
            sensingUnit.sensor.accuracy <= sensingUnit.requiredAccuracy
        }
    }

    requirement def LatencyRequirement {
        doc /* The sensing unit shall output a valid mass flow measurement within the maximum latency after fluid flow is detected. */

        subject sensingUnit : MassFlowSensingUnit;

        require constraint {
            sensingUnit.sensor.responseTime <= sensingUnit.maximumLatency
        }
    }

    requirement def DiagnosticRequirement {
        doc /* The sensing unit shall provide diagnostic status indicating sensor health, calibration validity, range validity, and fault condition. */

        subject sensingUnit : MassFlowSensingUnit;

        require constraint {
            sensingUnit.diagnosticsOut.status.sensorHealthy implies sensingUnit.diagnosticsOut.status.calibrationValid
        }
    }

    requirement def PowerRequirement {
        doc /* The sensing unit shall operate from the specified nominal electrical supply voltage. */

        subject sensingUnit : MassFlowSensingUnit;

        require constraint {
            sensingUnit.nominalSupplyVoltage == sensingUnit.sensor.operatingVoltage
        }
    }

    part massFlowSensingUnit : MassFlowSensingUnit;

    satisfy MeasureMassFlowRequirement by massFlowSensingUnit;
    satisfy AccuracyRequirement by massFlowSensingUnit;
    satisfy LatencyRequirement by massFlowSensingUnit;
    satisfy DiagnosticRequirement by massFlowSensingUnit;
    satisfy PowerRequirement by massFlowSensingUnit;
}