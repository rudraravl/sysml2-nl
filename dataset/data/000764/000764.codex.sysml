package ShuntCheckSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value def PressureValue {
        unit = 'Pa';
        quantityKind = pressure;
    }

    value def FlowRateValue {
        unit = 'mL/s';
        quantityKind = volumeFlowRate;
    }

    value def TemperatureValue {
        unit = 'degC';
        quantityKind = thermodynamicTemperature;
    }

    value def VoltageValue {
        unit = 'V';
        quantityKind = electricPotential;
    }

    value def CurrentValue {
        unit = 'mA';
        quantityKind = electricCurrent;
    }

    value def TimeValue {
        unit = 's';
        quantityKind = time;
    }

    value def PercentValue {
        unit = '%';
    }

    value def DiagnosticConfidence {
        specializes PercentValue;
    }

    enum def ShuntCondition {
        enum normal;
        enum partialOcclusion;
        enum completeOcclusion;
        enum overDrainage;
        enum disconnection;
        enum unknown;
    }

    enum def DeviceMode {
        enum off;
        enum standby;
        enum selfTest;
        enum acquiring;
        enum analyzing;
        enum reporting;
        enum fault;
    }

    item def CerebrospinalFluid {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute temperature : TemperatureValue;
    }

    item def PressureSample {
        attribute sampledPressure : PressureValue;
        attribute sampleTime : TimeValue;
        attribute signalQuality : PercentValue;
    }

    item def FlowSample {
        attribute sampledFlowRate : FlowRateValue;
        attribute sampleTime : TimeValue;
        attribute signalQuality : PercentValue;
    }

    item def DiagnosticResult {
        attribute detectedCondition : ShuntCondition;
        attribute confidence : DiagnosticConfidence;
        attribute measuredPressureGradient : PressureValue;
        attribute measuredFlowRate : FlowRateValue;
        attribute recommendation : String;
    }

    item def UserCommand {
        attribute requestedMode : DeviceMode;
        attribute operatorId : String;
    }

    item def AlertMessage {
        attribute severity : String;
        attribute messageText : String;
        attribute condition : ShuntCondition;
    }

    port def FluidMeasurementPort {
        in item fluid : CerebrospinalFluid;
        out item pressureSample : PressureSample;
        out item flowSample : FlowSample;
    }

    port def ElectricalPowerPort {
        in attribute supplyVoltage : VoltageValue;
        in attribute supplyCurrent : CurrentValue;
    }

    port def UserInterfacePort {
        in item command : UserCommand;
        out item result : DiagnosticResult;
        out item alert : AlertMessage;
    }

    port def DataPort {
        out item diagnosticResult : DiagnosticResult;
        out item pressureData : PressureSample;
        out item flowData : FlowSample;
    }

    part def PressureSensor {
        attribute measurementRangeMin : PressureValue = 0 [Pa];
        attribute measurementRangeMax : PressureValue = 5000 [Pa];
        attribute accuracy : PercentValue = 2 [%];
        attribute responseTime : TimeValue = 0.2 [s];

        port measurementPort : FluidMeasurementPort;
        port powerPort : ElectricalPowerPort;

        action acquirePressure {
            in item incomingFluid : CerebrospinalFluid;
            out item pressureSample : PressureSample;
        }
    }

    part def FlowSensor {
        attribute measurementRangeMin : FlowRateValue = 0 [mL/s];
        attribute measurementRangeMax : FlowRateValue = 5 [mL/s];
        attribute accuracy : PercentValue = 5 [%];
        attribute responseTime : TimeValue = 0.5 [s];

        port measurementPort : FluidMeasurementPort;
        port powerPort : ElectricalPowerPort;

        action acquireFlow {
            in item incomingFluid : CerebrospinalFluid;
            out item flowSample : FlowSample;
        }
    }

    part def SignalProcessor {
        attribute pressureNoiseLimit : PercentValue = 10 [%];
        attribute flowNoiseLimit : PercentValue = 15 [%];

        in item rawPressure : PressureSample;
        in item rawFlow : FlowSample;
        out item filteredPressure : PressureSample;
        out item filteredFlow : FlowSample;

        action filterMeasurements {
            in item pressureIn : PressureSample;
            in item flowIn : FlowSample;
            out item pressureOut : PressureSample;
            out item flowOut : FlowSample;
        }
    }

    part def DiagnosticEngine {
        attribute lowFlowThreshold : FlowRateValue = 0.2 [mL/s];
        attribute highFlowThreshold : FlowRateValue = 3.0 [mL/s];
        attribute highPressureGradientThreshold : PressureValue = 1200 [Pa];
        attribute minimumConfidenceToReport : DiagnosticConfidence = 85 [%];

        in item pressureInput : PressureSample;
        in item flowInput : FlowSample;
        out item diagnosticOutput : DiagnosticResult;

        action classifyShuntCondition {
            in item pressureSample : PressureSample;
            in item flowSample : FlowSample;
            out item result : DiagnosticResult;
        }
    }

    part def OperatorInterface {
        port uiPort : UserInterfacePort;

        in item operatorCommand : UserCommand;
        out item displayedResult : DiagnosticResult;
        out item displayedAlert : AlertMessage;

        action showResult {
            in item result : DiagnosticResult;
        }

        action showAlert {
            in item alert : AlertMessage;
        }
    }

    part def DataLogger {
        attribute storageCapacityHours : TimeValue = 2592000 [s];

        port dataPort : DataPort;

        in item loggedPressure : PressureSample;
        in item loggedFlow : FlowSample;
        in item loggedResult : DiagnosticResult;

        action recordDiagnosticSession {
            in item pressureSample : PressureSample;
            in item flowSample : FlowSample;
            in item result : DiagnosticResult;
        }
    }

    part def PowerSubsystem {
        attribute nominalVoltage : VoltageValue = 5 [V];
        attribute maximumCurrent : CurrentValue = 500 [mA];
        attribute batteryStateOfCharge : PercentValue;

        port sensorPower : ElectricalPowerPort;
        port processorPower : ElectricalPowerPort;
        port interfacePower : ElectricalPowerPort;

        action provideRegulatedPower {
            out attribute voltage : VoltageValue;
            out attribute current : CurrentValue;
        }
    }

    part def ShuntCheck {
        attribute operatingMode : DeviceMode = DeviceMode::off;
        attribute intendedFunction : String = "Assess shunt patency and drainage behavior by measuring pressure and flow, analyzing the measurements, and reporting whether the shunt appears normal, obstructed, disconnected, or over-draining.";

        port patientFluidInterface : FluidMeasurementPort;
        port operatorInterface : UserInterfacePort;
        port externalDataInterface : DataPort;
        port externalPowerInput : ElectricalPowerPort;

        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part signalProcessor : SignalProcessor;
        part diagnosticEngine : DiagnosticEngine;
        part userInterface : OperatorInterface;
        part dataLogger : DataLogger;
        part powerSubsystem : PowerSubsystem;

        connection pressureFluidConnection connect patientFluidInterface to pressureSensor.measurementPort;
        connection flowFluidConnection connect patientFluidInterface to flowSensor.measurementPort;

        connection pressurePowerConnection connect powerSubsystem.sensorPower to pressureSensor.powerPort;
        connection flowPowerConnection connect powerSubsystem.sensorPower to flowSensor.powerPort;
        connection interfacePowerConnection connect powerSubsystem.interfacePower to externalPowerInput;

        connection userConnection connect operatorInterface to userInterface.uiPort;
        connection dataExportConnection connect externalDataInterface to dataLogger.dataPort;

        flow pressureMeasurementFlow from pressureSensor.measurementPort.pressureSample to signalProcessor.rawPressure;
        flow flowMeasurementFlow from flowSensor.measurementPort.flowSample to signalProcessor.rawFlow;
        flow filteredPressureFlow from signalProcessor.filteredPressure to diagnosticEngine.pressureInput;
        flow filteredFlowFlow from signalProcessor.filteredFlow to diagnosticEngine.flowInput;
        flow diagnosticDisplayFlow from diagnosticEngine.diagnosticOutput to userInterface.displayedResult;
        flow diagnosticLogFlow from diagnosticEngine.diagnosticOutput to dataLogger.loggedResult;
        flow pressureLogFlow from signalProcessor.filteredPressure to dataLogger.loggedPressure;
        flow flowLogFlow from signalProcessor.filteredFlow to dataLogger.loggedFlow;

        action performShuntCheck {
            in item patientFluid : CerebrospinalFluid;
            in item command : UserCommand;
            out item result : DiagnosticResult;

            first start;
            then acquirePressure;
            then acquireFlow;
            then filterSignals;
            then analyzeCondition;
            then reportResult;
            then logSession;
            then done;

            action acquirePressure {
                in item patientFluid : CerebrospinalFluid;
                out item pressureSample : PressureSample;
            }

            action acquireFlow {
                in item patientFluid : CerebrospinalFluid;
                out item flowSample : FlowSample;
            }

            action filterSignals {
                in item pressureSample : PressureSample;
                in item flowSample : FlowSample;
                out item filteredPressure : PressureSample;
                out item filteredFlow : FlowSample;
            }

            action analyzeCondition {
                in item filteredPressure : PressureSample;
                in item filteredFlow : FlowSample;
                out item result : DiagnosticResult;
            }

            action reportResult {
                in item result : DiagnosticResult;
            }

            action logSession {
                in item result : DiagnosticResult;
            }
        }

        state def ShuntCheckOperatingState {
            entry action initializeDevice;

            state Off;
            state Standby;
            state SelfTest;
            state AcquireMeasurements;
            state AnalyzeMeasurements;
            state ReportFindings;
            state FaultDetected;

            transition initial then Off;
            transition powerOn first Off then Standby;
            transition beginSelfTest first Standby then SelfTest;
            transition selfTestPassed first SelfTest then AcquireMeasurements;
            transition selfTestFailed first SelfTest then FaultDetected;
            transition samplesValid first AcquireMeasurements then AnalyzeMeasurements;
            transition samplesInvalid first AcquireMeasurements then FaultDetected;
            transition analysisComplete first AnalyzeMeasurements then ReportFindings;
            transition reportAcknowledged first ReportFindings then Standby;
            transition resetFault first FaultDetected then Standby;
            transition powerOff first Standby then Off;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject shuntCheck : ShuntCheck;

        require constraint {
            shuntCheck.intendedFunction == "Assess shunt patency and drainage behavior by measuring pressure and flow, analyzing the measurements, and reporting whether the shunt appears normal, obstructed, disconnected, or over-draining."
        }
    }

    requirement def MeasurementRequirement {
        subject pressureSensor : PressureSensor;
        subject flowSensor : FlowSensor;

        require constraint {
            pressureSensor.measurementRangeMax >= 5000 [Pa] and
            flowSensor.measurementRangeMax >= 5 [mL/s]
        }
    }

    requirement def DiagnosticRequirement {
        subject diagnosticEngine : DiagnosticEngine;

        require constraint {
            diagnosticEngine.minimumConfidenceToReport >= 85 [%]
        }
    }

    requirement def ReportingRequirement {
        subject shuntCheck : ShuntCheck;

        require constraint {
            shuntCheck.operatorInterface != null and
            shuntCheck.externalDataInterface != null
        }
    }

    requirement def PowerRequirement {
        subject powerSubsystem : PowerSubsystem;

        require constraint {
            powerSubsystem.nominalVoltage == 5 [V] and
            powerSubsystem.maximumCurrent <= 500 [mA]
        }
    }

    satisfy primaryFunctionSatisfied by ShuntCheck;
    satisfy measurementSatisfied by PressureSensor;
    satisfy measurementFlowSatisfied by FlowSensor;
    satisfy diagnosticSatisfied by DiagnosticEngine;
    satisfy reportingSatisfied by OperatorInterface;
    satisfy powerSatisfied by PowerSubsystem;
}