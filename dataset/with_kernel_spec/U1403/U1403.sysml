package 'Resistivity Measurement System' {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    package Definitions {
        attribute def Voltage :> Real;
        attribute def Current :> Real;
        attribute def Resistance :> Real;
        attribute def Resistivity :> Real;
        attribute def Conductivity :> Real;
        attribute def Temperature :> Real;
        attribute def Length :> Real;
        attribute def TemperatureCoefficient :> Real;

        item def MaterialSample {
            attribute thickness : Length;
            attribute targetTemperature : Temperature;
            attribute actualTemperature : Temperature;
        }

        item def CurrentFlow {
            attribute value : Current;
        }

        item def VoltageSignal {
            attribute value : Voltage;
        }

        item def TemperatureReading {
            attribute value : Temperature;
        }

        item def SetCurrentCommand {
            attribute targetCurrent : Current;
        }

        item def SetTemperatureCommand {
            attribute targetTemp : Temperature;
        }

        part def VoltageSource {
            port in commandIn : SetCurrentCommand;
            port out currentOutput : CurrentFlow;
            port in currentReturn : CurrentFlow;
        }

        part def Ammeter {
            port in currentInput : CurrentFlow;
            port out currentOutput : CurrentFlow;
            port out currentReading : CurrentReading;
            attribute measuredCurrent : Current;
        }

        part def Voltmeter {
            port in voltageInput : VoltageSignal;
            port out voltageReading : VoltageSignal;
            attribute measuredVoltage : Voltage;
        }

        part def FourPointProbe {
            attribute probeSpacing : Length;
            port in outerPositive : CurrentFlow;
            port out outerNegative : CurrentFlow;
            port out innerPositive : VoltageSignal;
            port out innerNegative : VoltageSignal;
        }

        part def TemperatureController {
            port in commandIn : SetTemperatureCommand;
            port in feedbackInput : TemperatureReading;
            port out setpointOutput : TemperatureReading;
            attribute currentSetpoint : Temperature;
            attribute measuredTemperature : Temperature;
        }

        part def DataAcquisitionUnit {
            port in voltageInput : VoltageSignal;
            port in currentInput : CurrentReading;
            port in temperatureInput : TemperatureReading;
            port out voltageOutput : VoltageSignal;
            port out currentOutput : CurrentReading;
            port out temperatureOutput : TemperatureReading;
            attribute measuredVoltage : Voltage;
            attribute measuredCurrent : Current;
            attribute measuredTemperature : Temperature;
        }

        part def ControlUnit {
            port in voltageInput : VoltageSignal;
            port in currentInput : CurrentReading;
            port in temperatureInput : TemperatureReading;
            port out currentCommandOutput : SetCurrentCommand;
            port out temperatureCommandOutput : SetTemperatureCommand;
            attribute probeSpacing : Length;
            attribute calculatedResistance : Resistance;
            attribute calculatedResistivity : Resistivity;
            attribute calculatedConductivity : Conductivity;
        }

        part def MeasurementSystem;

        state def MeasurementStates {
            state idle;
            state calibrating;
            state stabilizingTemperature;
            state measuring;
            state processing;
            state reporting;
            transition from idle to calibrating;
            transition from calibrating to stabilizingTemperature;
            transition from stabilizingTemperature to measuring;
            transition from measuring to processing;
            transition from processing to reporting;
            transition from reporting to idle;
        }

        requirement def MeasurementAccuracy {
            attribute measuredValue : Real;
            attribute referenceValue : Real;
            attribute tolerancePercent : Real;
            doc /* The measured value shall be within the specified tolerance of the reference value. */
            require constraint { abs(measuredValue - referenceValue) / referenceValue * 100.0 <= tolerancePercent }
        }

        requirement def TemperatureStability {
            attribute setpoint : Temperature;
            attribute actual : Temperature;
            attribute maxDeviation : Temperature;
            doc /* The actual temperature shall remain within the specified deviation of the setpoint. */
            require constraint { abs(actual - setpoint) <= maxDeviation }
        }

        requirement def ContactResistanceElimination {
            doc /* The system shall use a four-point probe technique to eliminate contact resistance errors. */
        }

        requirement def TemperatureCompensation {
            doc /* The system shall compensate for the effect of temperature on material properties during calculation. */
        }
    }

    package Usages {
        requirement measurementAccuracyReq : Definitions::MeasurementAccuracy {
            :>> tolerancePercent = 0.5;
            doc /* All electrical measurements shall be accurate to within 0.5 percent. */
        }

        requirement temperatureStabilityReq : Definitions::TemperatureStability {
            :>> maxDeviation = 0.1 [K];
            doc /* The sample temperature shall be stable within 0.1 K of the setpoint. */
        }

        requirement contactResistanceReq : Definitions::ContactResistanceElimination;

        requirement tempCompensationReq : Definitions::TemperatureCompensation;

        part measurementSystem : Definitions::MeasurementSystem {
            ref item sample : Definitions::MaterialSample {
                :>> thickness = 0.001 [m];
                :>> targetTemperature = 300 [K];
            }

            part voltageSource : Definitions::VoltageSource;
            part ammeter : Definitions::Ammeter;
            part voltmeter : Definitions::Voltmeter;
            part fourPointProbe : Definitions::FourPointProbe {
                :>> probeSpacing = 0.001 [m];
            }
            part temperatureController : Definitions::TemperatureController {
                :>> currentSetpoint = 300 [K];
            }
            part dataAcquisitionUnit : Definitions::DataAcquisitionUnit;
            part controlUnit : Definitions::ControlUnit {
                :>> probeSpacing = 0.001 [m];
            }

            connect voltageSource.currentOutput to fourPointProbe.outerPositive;
            connect fourPointProbe.outerNegative to ammeter.currentInput;
            connect ammeter.currentOutput to voltageSource.currentReturn;
            connect fourPointProbe.innerPositive to voltmeter.voltageInput;
            connect fourPointProbe.innerNegative to voltmeter.voltageInput;
            connect voltmeter.voltageReading to dataAcquisitionUnit.voltageInput;
            connect ammeter.currentReading to dataAcquisitionUnit.currentInput;
            connect temperatureController.setpointOutput to dataAcquisitionUnit.temperatureInput;
            connect dataAcquisitionUnit.voltageOutput to controlUnit.voltageInput;
            connect dataAcquisitionUnit.currentOutput to controlUnit.currentInput;
            connect dataAcquisitionUnit.temperatureOutput to controlUnit.temperatureInput;
            connect controlUnit.currentCommandOutput to voltageSource.commandIn;
            connect controlUnit.temperatureCommandOutput to temperatureController.commandIn;

            bind sample.actualTemperature = temperatureController.measuredTemperature;

            state measurementStates : Definitions::MeasurementStates;

            action measureMaterialSample {
                action calibrate {
                    out calibrationStatus : Boolean;
                }
                flow calibrate.calibrationStatus to stabilizeTemperature.calibrationStatus;
                action stabilizeTemperature {
                    in calibrationStatus : Boolean;
                    in targetTemp : Definitions::Temperature = sample.targetTemperature;
                    out stabilizationStatus : Boolean;
                }
                flow stabilizeTemperature.stabilizationStatus to performMeasurement.readyStatus;
                action performMeasurement {
                    in readyStatus : Boolean;
                    in current : Definitions::Current = ammeter.measuredCurrent;
                    in voltage : Definitions::Voltage = voltmeter.measuredVoltage;
                    in temperature : Definitions::Temperature = temperatureController.measuredTemperature;
                    out measuredVoltage : Definitions::Voltage;
                    out measuredCurrent : Definitions::Current;
                    out measuredTemperature : Definitions::Temperature;
                }
                flow performMeasurement.measuredVoltage to processData.voltage;
                flow performMeasurement.measuredCurrent to processData.current;
                flow performMeasurement.measuredTemperature to processData.temperature;
                action processData {
                    in voltage : Definitions::Voltage;
                    in current : Definitions::Current;
                    in temperature : Definitions::Temperature;
                    in probeSpacing : Definitions::Length = fourPointProbe.probeSpacing;
                    out resistance : Definitions::Resistance;
                    out resistivity : Definitions::Resistivity;
                    out conductivity : Definitions::Conductivity;
                    doc
                    /*
                     * Resistance R = V / I
                     * Resistivity rho = 2 * pi * s * (V / I) for bulk four-point probe
                     * Conductivity sigma = 1 / rho
                     */
                }
                flow processData.resistance to reportResults.resistance;
                flow processData.resistivity to reportResults.resistivity;
                flow processData.conductivity to reportResults.conductivity;
                action reportResults {
                    in resistance : Definitions::Resistance;
                    in resistivity : Definitions::Resistivity;
                    in conductivity : Definitions::Conductivity;
                }
            }
        }

        individual def TestSample1 :> Definitions::MaterialSample;
        individual def TestSample2 :> Definitions::MaterialSample;
        individual def TestMeasurementSystem :> Definitions::MeasurementSystem;

        individual testSystem : TestMeasurementSystem :> measurementSystem {
            satisfies measurementAccuracyReq;
            satisfies temperatureStabilityReq;
            satisfies contactResistanceReq;
            satisfies tempCompensationReq;
            timeslice test1 {
                ref individual :>> sample : TestSample1 {
                    :>> thickness = 0.0005 [m];
                    :>> targetTemperature = 298 [K];
                }
            }
            then timeslice test2 {
                ref individual :>> sample : TestSample2 {
                    :>> thickness = 0.002 [m];
                    :>> targetTemperature = 350 [K];
                }
            }
        }
    }
}
