package 'Nitrogen Oxide Sensing Unit Model' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def ConcentrationValue {
        attribute num: Real;
        attribute unit: String;
    }

    attribute ppm: String = "ppm";

    item def ExhaustGas {
        attribute noxConcentration: ConcentrationValue;
        attribute temperature: Real;
        attribute pressure: Real;
        attribute flowRate: Real;
    }

    item def SensorSignal {
        attribute voltage: Real;
        attribute current: Real;
        attribute timestamp: Real;
    }

    item def NOxMeasurement {
        attribute concentration: ConcentrationValue;
        attribute sensorTemperature: Real;
        attribute measurementTime: Real;
        attribute validityFlag: Boolean;
        attribute errorCode: Integer;
    }

    port def GasFlowPort {
        in item gasStream: ExhaustGas;
    }

    port def ElectricalPort {
        in item powerSupply: SensorSignal;
        out item sensorOutput: SensorSignal;
    }

    port def DataOutputPort {
        out item measurement: NOxMeasurement;
    }

    part def HeatingElement {
        attribute targetTemperature: Real;
        attribute currentTemperature: Real;
        attribute heatingPower: Real;
        attribute heatingRate: Real;

        port powerInput: ElectricalPort;

        action def HeatUp {
            in targetTemp: Real;
            out currentTemp: Real;
        }

        action def MaintainTemperature {
            in setpoint: Real;
            out actualTemp: Real;
        }
    }

    part def SensingElement {
        attribute sensitivity: Real;
        attribute baselineResistance: Real;
        attribute operatingTemperature: Real;
        attribute responseTime: Real;

        port gasExposure: GasFlowPort;
        port electricalInterface: ElectricalPort;

        action def DetectNOx {
            in item gas: ExhaustGas;
            out item signal: SensorSignal;
        }
    }

    part def SignalProcessor {
        attribute amplificationGain: Real;
        attribute filterCutoffFrequency: Real;
        attribute offsetVoltage: Real;

        in item rawSignal: SensorSignal;
        out item processedSignal: SensorSignal;

        action def AmplifySignal {
            in item input: SensorSignal;
            out item output: SensorSignal;
        }

        action def FilterNoise {
            in item input: SensorSignal;
            out item output: SensorSignal;
        }
    }

    part def AnalogDigitalConverter {
        attribute resolution: Integer;
        attribute samplingRate: Real;
        attribute conversionTime: Real;

        in item analogInput: SensorSignal;
        out item digitalOutput: NOxMeasurement;

        action def ConvertSignal {
            in item analog: SensorSignal;
            out item digital: NOxMeasurement;
        }
    }

    part def TemperatureMonitor {
        attribute currentTemperature: Real;
        attribute temperatureAccuracy: Real;

        out item temperatureReading: Real;

        action def MeasureTemperature {
            out temp: Real;
        }
    }

    state def SensorOperationalStates {
        entry; then powerOff;

        state powerOff;

        transition powerOff_to_initializing
            first powerOff
            accept PowerOnCommand
            then initializing;

        state initializing;

        transition initializing_to_warmup
            first initializing
            if initializationComplete
            then warmup;

        state warmup;

        transition warmup_to_ready
            first warmup
            if operatingTemperatureReached
            then ready;

        state ready;

        transition ready_to_measuring
            first ready
            accept StartMeasurement
            then measuring;

        state measuring;

        transition measuring_to_ready
            first measuring
            accept StopMeasurement
            then ready;

        transition measuring_to_diagnostics
            first measuring
            accept DiagnosticRequest
            then diagnostics;

        state diagnostics;

        transition diagnostics_to_ready
            first diagnostics
            if diagnosticsComplete
            then ready;

        transition any_to_fault
            accept FaultDetected
            then fault;

        state fault;

        transition fault_to_initializing
            first fault
            accept ResetCommand
            then initializing;

        transition any_to_powerOff
            accept PowerOffCommand
            then powerOff;
    }

    action def CalibrateSensor {
        in item referenceGas: ExhaustGas;
        in item sensorReading: NOxMeasurement;
        out calibrationFactor: Real;
        out calibrationOffset: Real;

        action measureReference {
            in item gas: ExhaustGas;
            out rawValue: Real;
        }

        then action calculateCalibration {
            in expectedConcentration: Real;
            in measuredConcentration: Real;
            out factor: Real;
            out offset: Real;
        }
    }

    action def MeasureNOxConcentration {
        in item exhaustGas: ExhaustGas;
        out item noxReading: NOxMeasurement;

        action heatSensor {
            out sensorReady: Boolean;
        }

        then fork;

        then action exposeToGas {
            in item gas: ExhaustGas;
            out rawSignal: SensorSignal;
        }

        then joinNode;

        then action monitorTemperature {
            out sensorTemp: Real;
        }

        then joinNode;

        action processSignal {
            in inputSignal: SensorSignal;
            out amplifiedSignal: SensorSignal;
        }

        then joinNode;

        join joinNode;

        then action convertToDigital {
            in signal: SensorSignal;
            out digitalValue: Real;
        }

        then action applyCalibration {
            in digitalVal: Real;
            in calibrationData: Real;
            out calibratedConcentration: ConcentrationValue;
        }

        then action assembleMeasurement {
            in concentration: ConcentrationValue;
            in sensorTemp: Real;
            in measurementTimestamp: Real;
            out measurement: NOxMeasurement;
        }
    }

    part def NitrogenOxideSensor {
        attribute sensorID: String;
        attribute manufacturerCalibrationDate: String;
        attribute calibrationFactor: Real default 1.0;
        attribute calibrationOffset: Real default 0.0;
        attribute measurementRangeLow: ConcentrationValue;
        attribute measurementRangeHigh: ConcentrationValue;
        attribute measurementAccuracy: Real;
        attribute responseTime: Real;
        attribute sensorMode: String;
        attribute operatingTemperatureReached: Boolean default false;
        attribute initializationComplete: Boolean default false;
        attribute diagnosticsComplete: Boolean default false;

        port gasInlet: GasFlowPort;
        port powerSupply: ElectricalPort;
        port dataOutput: DataOutputPort;

        part heater: HeatingElement {
            attribute :>> targetTemperature = 573.15;
            attribute :>> heatingRate = 5.0;
        }

        part sensingCell: SensingElement {
            attribute :>> sensitivity = 0.92;
            attribute :>> baselineResistance = 15000.0;
            attribute :>> operatingTemperature = 573.15;
            attribute :>> responseTime = 5.0;
        }

        part signalConditioner: SignalProcessor {
            attribute :>> amplificationGain = 150.0;
            attribute :>> filterCutoffFrequency = 100.0;
            attribute :>> offsetVoltage = 0.05;
        }

        part adc: AnalogDigitalConverter {
            attribute :>> resolution = 24;
            attribute :>> samplingRate = 1000.0;
            attribute :>> conversionTime = 0.001;
        }

        part tempMonitor: TemperatureMonitor {
            attribute :>> temperatureAccuracy = 0.5;
        }

        connection heaterPowerConnection
            connect powerSupply to heater.powerInput;

        connection gasFlowConnection
            connect gasInlet to sensingCell.gasExposure;

        connection sensingToProcessing
            connect sensingCell.electricalInterface.sensorOutput to signalConditioner.rawSignal;

        connection processingToConversion
            connect signalConditioner.processedSignal to adc.analogInput;

        connection measurementOutput
            connect adc.digitalOutput to dataOutput.measurement;

        state operationalState: SensorOperationalStates;

        perform action measureNOx: MeasureNOxConcentration;

        perform action calibrate: CalibrateSensor;
    }

    requirement def NOxSensorRequirements {
        doc /* The nitrogen oxide sensor shall measure NOx concentration 
               within specified range and accuracy requirements. */

        subject sensor: NitrogenOxideSensor;

        require measurementRangeRequirement {
            doc /* Sensor shall measure NOx concentration from 0 to 2000 ppm. */
        }

        require accuracyRequirement {
            doc /* Sensor measurement accuracy shall be within ±3% of reading or ±5 ppm, whichever is greater. */
        }

        require responseTimeRequirement {
            doc /* Sensor response time (T90) shall be less than 10 seconds. */
        }

        require operatingTemperatureRequirement {
            doc /* Sensor shall operate at 300°C ± 5°C (573.15 K ± 5 K). */
        }

        require warmupTimeRequirement {
            doc /* Sensor warmup time shall not exceed 60 seconds. */
        }
    }

    requirement def DataIntegrityRequirement {
        doc /* Sensor shall provide valid measurement data with integrity checks. */

        subject sensor: NitrogenOxideSensor;

        require validityFlagRequirement {
            doc /* Each measurement shall include a validity flag. */
        }

        require errorCodeRequirement {
            doc /* Sensor shall report error codes for fault conditions. */
        }
    }

    part sensingUnit: NitrogenOxideSensor {
        attribute :>> sensorID = "NOX-SU-2025-001";
        attribute :>> manufacturerCalibrationDate = "2025-01-15";
        attribute :>> calibrationFactor = 1.015;
        attribute :>> calibrationOffset = 2.5;
        attribute :>> measurementRangeLow {
            attribute :>> num = 0.0;
            attribute :>> unit = "ppm";
        }
        attribute :>> measurementRangeHigh {
            attribute :>> num = 2000.0;
            attribute :>> unit = "ppm";
        }
        attribute :>> measurementAccuracy = 0.025;
        attribute :>> responseTime = 8.0;

        satisfy performanceRequirement: NOxSensorRequirements {
            subject sensor = sensingUnit;
        }

        satisfy dataRequirement: DataIntegrityRequirement {
            subject sensor = sensingUnit;
        }
    }

    individual def CalibrationGasSample :> ExhaustGas;
    individual def TestExhaustSample :> ExhaustGas;
    individual def TestScenario;

    individual testScenario: TestScenario {
        individual testUnit: NitrogenOxideSensor :> sensingUnit;

        timeslice powerOn {
            perform action powerOnSensor {
                bind testUnit.sensorMode = "Initializing";
                bind testUnit.initializationComplete = false;
            }
        }

        then timeslice initialization {
            perform action initializeSensor {
                bind testUnit.initializationComplete = true;
            }
        }

        then timeslice warmupPhase {
            perform action warmupSensor {
                bind testUnit.heater.currentTemperature = 573.15;
                bind testUnit.operatingTemperatureReached = true;
            }
        }

        then timeslice calibrationPhase {
            perform action :>> testUnit.calibrate {
                in individual :>> referenceGas: CalibrationGasSample {
                    attribute :>> noxConcentration {
                        attribute :>> num = 500.0;
                        attribute :>> unit = "ppm";
                    }
                    attribute :>> temperature = 298.15;
                    attribute :>> pressure = 101325.0;
                }
                out :>> calibrationFactor = 1.02;
                out :>> calibrationOffset = 2.0;
            }
        }

        then timeslice measurement1 {
            perform action :>> testUnit.measureNOx {
                in individual :>> exhaustGas: TestExhaustSample {
                    attribute :>> noxConcentration {
                        attribute :>> num = 250.0;
                        attribute :>> unit = "ppm";
                    }
                    attribute :>> temperature = 473.15;
                    attribute :>> pressure = 101325.0;
                    attribute :>> flowRate = 0.05;
                }
                out individual measuredData: NOxMeasurement {
                    attribute :>> concentration.num = 255.0;
                    attribute :>> sensorTemperature = 573.15;
                    attribute :>> validityFlag = true;
                    attribute :>> errorCode = 0;
                }
            }
        }

        then timeslice measurement2 {
            perform action :>> testUnit.measureNOx {
                in individual :>> exhaustGas: TestExhaustSample {
                    attribute :>> noxConcentration {
                        attribute :>> num = 850.0;
                        attribute :>> unit = "ppm";
                    }
                    attribute :>> temperature = 523.15;
                    attribute :>> pressure = 101325.0;
                    attribute :>> flowRate = 0.08;
                }
                out individual measuredData: NOxMeasurement {
                    attribute :>> concentration.num = 867.0;
                    attribute :>> sensorTemperature = 573.15;
                    attribute :>> validityFlag = true;
                    attribute :>> errorCode = 0;
                }
            }
        }

        then timeslice diagnosticCheck {
            perform action runDiagnostics {
                bind testUnit.sensorMode = "Diagnostics";
                bind testUnit.diagnosticsComplete = true;
            }
        }

        then timeslice shutdown {
            perform action shutdownSensor {
                bind testUnit.sensorMode = "Off";
                bind testUnit.operatingTemperatureReached = false;
            }
        }
    }
}
