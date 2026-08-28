package FuelLevelSensingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Quantities::ScalarQuantityValue;

    package AttributeDefinitions {
        attribute def CapacitanceValue :> ScalarQuantityValue;
        attribute def VoltageValue :> ScalarQuantityValue;
        attribute def DigitalSampleValue :> ScalarQuantityValue;
        attribute def FuelLevelPercent :> ScalarQuantityValue;
        attribute def ErrorCode;
        attribute def OperationalStatus :> ScalarValues::String;
        attribute def CalibrationTable {
            attribute samplePoints : Real[*];
            attribute levelValues : FuelLevelPercent[*];
        }
    }

    package ItemDefinitions {
        private import AttributeDefinitions::*;
        private import ISQ::*;
        item def Fuel {
            attribute dielectricConstant : Real;
            attribute density : Real;
        }
        item def Air {
            attribute dielectricConstant : Real;
        }
    }

    package SignalDefinitions {
        private import AttributeDefinitions::*;
        private import ISQ::*;
        attribute def FuelLevelReport {
            attribute levelPercent : FuelLevelPercent;
            attribute volume : VolumeValue;
            attribute status : OperationalStatus;
            attribute timestamp : TimeValue;
        }
        attribute def DiagnosticReport {
            attribute status : OperationalStatus;
            attribute errorCodes : ErrorCode[*];
            attribute sensorHealth : Real;
            attribute uptime : TimeValue;
        }
        attribute def MeasurementTrigger;
        attribute def CalibrationCommand {
            attribute referenceLevel : FuelLevelPercent;
        }
        attribute def FaultDetected {
            attribute code : ErrorCode;
        }
        attribute def PowerOn;
        attribute def PowerOff;
        attribute def SelfTestComplete {
            attribute passed : Boolean;
        }
        attribute def FaultCleared;
    }

    package PortDefinitions {
        private import AttributeDefinitions::*;
        private import SignalDefinitions::*;
        port def DigitalOutputPort {
            out fuelLevelReport : FuelLevelReport;
        }
        port def DiagnosticPort {
            in calibrationCommand : CalibrationCommand;
            out diagnosticReport : DiagnosticReport;
        }
        port def PowerPort {
            in supplyVoltage : VoltageValue;
        }
        port def FuelInterfacePort {
            ref item fuel : Fuel;
        }
    }

    package InterfaceDefinitions {
        private import PortDefinitions::*;
        private import AttributeDefinitions::*;
        private import SignalDefinitions::*;
        interface def VehiclePowerInterface {
            end supplier : PowerPort;
            end consumer : PowerPort;
            flow supplyVoltage : VoltageValue from supplier to consumer;
        }
        interface def DiagnosticInterface {
            end tool : DiagnosticPort;
            end unit : DiagnosticPort;
            flow calibrationCommand : CalibrationCommand from tool to unit;
            flow diagnosticReport : DiagnosticReport from unit to tool;
        }
        interface def FuelReportInterface {
            end sender : DigitalOutputPort;
            end receiver : DigitalOutputPort;
            flow fuelLevelReport : FuelLevelReport from sender to receiver;
        }
    }

    package PartDefinitions {
        private import ScalarValues::*;
        private import ISQ::*;
        private import AttributeDefinitions::*;
        private import ItemDefinitions::*;
        private import SignalDefinitions::*;
        private import PortDefinitions::*;
        private import InterfaceDefinitions::*;
        private import ActionDefinitions::*;
        private import StateDefinitions::*;

        part def FuelTank {
            attribute capacity : VolumeValue;
            ref item fuel : Fuel;
            attribute currentVolume : VolumeValue;
            attribute fuelLevel : FuelLevelPercent;
            assert constraint {
                currentVolume <= capacity
            }
        }

        part def CapacitiveProbe {
            attribute probeLength : LengthValue;
            attribute baseCapacitance : CapacitanceValue;
            attribute submergedCapacitance : CapacitanceValue;
            attribute fuelDielectricConstant : Real;
            attribute airDielectricConstant : Real;
            port fuelInterface : FuelInterfacePort;
            out measuredCapacitance : CapacitanceValue;
            perform action senseCapacitance;
            assert constraint {
                measuredCapacitance == baseCapacitance +
                    (submergedCapacitance - baseCapacitance) *
                    (fuelInterface.fuel.dielectricConstant - airDielectricConstant) /
                    (fuelDielectricConstant - airDielectricConstant)
            }
        }

        part def SignalConditioningCircuit {
            in rawCapacitance : CapacitanceValue;
            out analogVoltage : VoltageValue;
            attribute gain : Real;
            attribute offset : VoltageValue;
            perform action conditionSignal;
            assert constraint {
                analogVoltage == gain * rawCapacitance + offset
            }
        }

        part def AnalogToDigitalConverter {
            in inputVoltage : VoltageValue;
            out digitalValue : DigitalSampleValue;
            attribute resolutionBits : Integer;
            attribute referenceVoltage : VoltageValue;
            attribute samplingRate : FrequencyValue;
            perform action convertSignal;
            assert constraint {
                digitalValue == inputVoltage / referenceVoltage * (2^resolutionBits - 1)
            }
        }

        part def SignalProcessor {
            in rawDigital : DigitalSampleValue;
            out fuelLevelPercent : FuelLevelPercent;
            out fuelVolume : VolumeValue;
            out status : OperationalStatus;
            attribute calibrationData : CalibrationTable;
            attribute filterCoefficient : Real;
            attribute tankCapacity : VolumeValue;
            attribute previousLevel : FuelLevelPercent;
            attribute errorCodes : ErrorCode[*];
            perform action processData;
            perform action filterSignal;
            perform action applyCalibration;
            assert constraint {
                fuelVolume == fuelLevelPercent / 100.0 * tankCapacity
            }
        }

        part def FuelLevelSensorUnit {
            attribute supplyVoltage : VoltageValue = 12 ['V'];
            attribute powerConsumption : PowerValue;
            attribute operatingTemperature : TemperatureValue;
            attribute uptime : TimeValue;
            attribute serviceLife : TimeValue;
            attribute updateRate : FrequencyValue;
            attribute accuracy : Real;
            port powerInput : PowerPort;
            port digitalOutput : DigitalOutputPort;
            port diagnosticOutput : DiagnosticPort;
            part capacitiveProbe : CapacitiveProbe;
            part conditioningCircuit : SignalConditioningCircuit;
            part adc : AnalogToDigitalConverter;
            part processor : SignalProcessor;
            perform action providePower;
            perform action performSelfTest;
            perform action measureFuelLevel;
            perform action processData;
            perform action transmitResult;
            perform action logError;
            exhibit state sensorStates : SensorStates;
            connect capacitiveProbe.measuredCapacitance to conditioningCircuit.rawCapacitance;
            connect conditioningCircuit.analogVoltage to adc.inputVoltage;
            connect adc.digitalValue to processor.rawDigital;
        }

        part def VehicleECU {
            port fuelLevelInput : DigitalOutputPort;
            port diagnosticAccess : DiagnosticPort;
            attribute receivedFuelLevel : FuelLevelPercent;
            attribute receivedVolume : VolumeValue;
            attribute vehicleStatus : OperationalStatus;
        }

        part def DiagnosticTool {
            port diagnosticConnection : DiagnosticPort;
            attribute retrievedErrorCodes : ErrorCode[*];
            attribute sensorHealthStatus : OperationalStatus;
        }

        part def Vehicle {
            part fuelTank : FuelTank;
            part sensorUnit : FuelLevelSensorUnit;
            part ecu : VehicleECU;
            part diagnosticTool : DiagnosticTool;
            part vehiclePowerSource {
                port powerPort : PowerPort;
                attribute outputVoltage : VoltageValue = 12 ['V'];
            }
            connection powerToSensor : VehiclePowerInterface {
                supplier = vehiclePowerSource.powerPort;
                consumer = sensorUnit.powerInput;
            }
            connection sensorToECU : FuelReportInterface {
                sender = sensorUnit.digitalOutput;
                receiver = ecu.fuelLevelInput;
            }
            connection sensorToDiagnostic : DiagnosticInterface {
                tool = diagnosticTool.diagnosticConnection;
                unit = sensorUnit.diagnosticOutput;
            }
        }
    }

    package ActionDefinitions {
        private import ScalarValues::*;
        private import AttributeDefinitions::*;
        private import ItemDefinitions::*;
        private import SignalDefinitions::*;
        private import PartDefinitions::*;

        action def SenseCapacitance {
            in probe : CapacitiveProbe;
            out capacitance : CapacitanceValue;
        }
        action def ConditionSignal {
            in capacitance : CapacitanceValue;
            in gain : Real;
            in offset : VoltageValue;
            out voltage : VoltageValue;
        }
        action def ConvertSignal {
            in voltage : VoltageValue;
            in resolution : Integer;
            in reference : VoltageValue;
            out digitalValue : DigitalSampleValue;
        }
        action def FilterSignal {
            in rawValue : DigitalSampleValue;
            in coefficient : Real;
            in previous : FuelLevelPercent;
            out filteredValue : FuelLevelPercent;
        }
        action def ApplyCalibration {
            in filteredValue : DigitalSampleValue;
            in calibration : CalibrationTable;
            out levelPercent : FuelLevelPercent;
        }
        action def ProcessData {
            in rawDigital : DigitalSampleValue;
            in calibration : CalibrationTable;
            in filterCoefficient : Real;
            in previousLevel : FuelLevelPercent;
            in tankCapacity : VolumeValue;
            out fuelLevelPercent : FuelLevelPercent;
            out fuelVolume : VolumeValue;
        }
        action def PerformSelfTest {
            in sensorUnit : FuelLevelSensorUnit;
            out passed : Boolean;
            out errorCodes : ErrorCode[*];
        }
        action def TransmitResult {
            in levelPercent : FuelLevelPercent;
            in volume : VolumeValue;
            in status : OperationalStatus;
            out report : FuelLevelReport;
        }
        action def LogError {
            in code : ErrorCode;
            out diagnosticReport : DiagnosticReport;
        }
        action def ProvidePower {
            in voltage : VoltageValue;
            out powerActive : Boolean;
        }
    }

    package StateDefinitions {
        private import ScalarValues::*;
        private import AttributeDefinitions::*;
        private import SignalDefinitions::*;
        private import ActionDefinitions::*;
        private import PartDefinitions::*;

        state def SensorStates {
            in sensorUnit : FuelLevelSensorUnit;
            entry; then off;
            state off;
            accept PowerOn then powerUp;
            state powerUp {
                entry action providePowerAction : ProvidePower {
                    in voltage = sensorUnit.supplyVoltage;
                }
            }
            then selfTest;
            state selfTest {
                entry action selfTestAction : PerformSelfTest {
                    in sensorUnit = sensorUnit;
                }
            }
            accept SelfTestComplete then standby;
            accept FaultDetected then fault;
            state standby;
            accept MeasurementTrigger then measuring;
            accept CalibrationCommand then calibrationMode;
            state measuring {
                entry action senseAction : SenseCapacitance {
                    in probe = sensorUnit.capacitiveProbe;
                }
            }
            then processing;
            state processing {
                entry action processAction : ProcessData {
                    in rawDigital = sensorUnit.adc.digitalValue;
                    in calibration = sensorUnit.processor.calibrationData;
                    in filterCoefficient = sensorUnit.processor.filterCoefficient;
                    in previousLevel = sensorUnit.processor.previousLevel;
                    in tankCapacity = sensorUnit.processor.tankCapacity;
                }
            }
            then transmitting;
            state transmitting {
                entry action transmitAction : TransmitResult {
                    in levelPercent = processAction.fuelLevelPercent;
                    in volume = processAction.fuelVolume;
                    in status = sensorUnit.processor.status;
                }
            }
            then standby;
            state calibrationMode {
                entry action calibrateAction : ApplyCalibration {
                    in filteredValue = sensorUnit.adc.digitalValue;
                    in calibration = sensorUnit.processor.calibrationData;
                }
            }
            accept MeasurementTrigger then standby;
            state fault {
                entry action logErrorAction : LogError;
            }
            accept FaultCleared then standby;
            accept PowerOff then off;
        }
    }

    package RequirementDefinitions {
        private import ScalarValues::*;
        private import ISQ::*;
        private import AttributeDefinitions::*;
        private import PartDefinitions::*;

        requirement def AccuracyRequirement {
            doc /* The fuel level sensing system shall measure fuel level with an accuracy of ±1.5% or better across the full operating range of the fuel tank. */
            attribute requiredAccuracy : Real = 1.5;
            subject sensorUnit : FuelLevelSensorUnit;
            require constraint {
                sensorUnit.accuracy <= requiredAccuracy
            }
        }

        requirement def UpdateRateRequirement {
            doc /* The fuel level sensing system shall update its fuel level measurement at least 10 times per second. */
            attribute minimumUpdateRate : FrequencyValue = 10 ['Hz'];
            subject sensorUnit : FuelLevelSensorUnit;
            require constraint {
                sensorUnit.updateRate >= minimumUpdateRate
            }
        }

        requirement def ServiceLifeRequirement {
            doc /* The fuel level sensing system shall have a mean time between failures of at least 10,000 operating hours. */
            attribute minimumServiceLife : TimeValue = 10000 ['h'];
            subject sensorUnit : FuelLevelSensorUnit;
            require constraint {
                sensorUnit.serviceLife >= minimumServiceLife
            }
        }

        requirement def PowerSupplyRequirement {
            doc /* The fuel level sensing system shall operate on a standard 12V automotive power supply with low power consumption. */
            attribute requiredVoltage : VoltageValue = 12 ['V'];
            attribute maxPowerConsumption : PowerValue = 1 ['W'];
            subject sensorUnit : FuelLevelSensorUnit;
            require constraint {
                sensorUnit.supplyVoltage == requiredVoltage &
                sensorUnit.powerConsumption <= maxPowerConsumption
            }
        }

        requirement def CommunicationRequirement {
            doc /* The fuel level sensing system shall communicate the fuel level percentage, calculated fuel volume, and operational status to the vehicle ECU via a digital output port. */
            subject sensorUnit : FuelLevelSensorUnit;
            require constraint {
                sensorUnit.digitalOutput.fuelLevelReport.levelPercent >= 0 [%] &
                sensorUnit.digitalOutput.fuelLevelReport.levelPercent <= 100 [%] &
                sensorUnit.digitalOutput.fuelLevelReport.volume >= 0 ['L'] &
                sensorUnit.digitalOutput.fuelLevelReport.status != null
            }
        }

        requirement def DiagnosticRequirement {
            doc /* The fuel level sensing system shall provide a separate diagnostic port for technicians to access detailed status information and error codes. */
            subject sensorUnit : FuelLevelSensorUnit;
            require constraint {
                sensorUnit.diagnosticOutput.diagnosticReport.errorCodes != null
            }
        }

        requirement def SelfTestRequirement {
            doc /* Upon vehicle power-up, the fuel level sensing system shall perform a self-test of all components before entering standby mode. */
            subject sensorUnit : FuelLevelSensorUnit;
            require constraint {
                sensorUnit.performSelfTest != null
            }
        }

        requirement def FaultHandlingRequirement {
            doc /* The fuel level sensing system shall enter a fault mode upon detection of any component failure and shall log error codes for diagnostic purposes. */
            subject sensorUnit : FuelLevelSensorUnit;
            require constraint {
                sensorUnit.logError != null
            }
        }

        package FuelSensorRequirements {
            requirement accuracyReq : AccuracyRequirement;
            requirement updateRateReq : UpdateRateRequirement;
            requirement serviceLifeReq : ServiceLifeRequirement;
            requirement powerSupplyReq : PowerSupplyRequirement;
            requirement communicationReq : CommunicationRequirement;
            requirement diagnosticReq : DiagnosticRequirement;
            requirement selfTestReq : SelfTestRequirement;
            requirement faultHandlingReq : FaultHandlingRequirement;
        }
    }

    package FuelSensorSystem {
        private import PartDefinitions::*;
        private import RequirementDefinitions::FuelSensorRequirements::*;

        part fuelSensorVehicle : Vehicle {
            part redefines fuelTank : FuelTank {
                attribute redefines capacity = 60 ['L'];
            }
            part redefines sensorUnit : FuelLevelSensorUnit {
                attribute redefines supplyVoltage = 12 ['V'];
                attribute redefines powerConsumption = 0.5 ['W'];
                attribute redefines updateRate = 20 ['Hz'];
                attribute redefines accuracy = 1.2;
                attribute redefines serviceLife = 12000 ['h'];
                part redefines capacitiveProbe : CapacitiveProbe {
                    attribute redefines probeLength = 0.4 ['m'];
                    attribute redefines baseCapacitance = 50 ['pF'];
                    attribute redefines submergedCapacitance = 200 ['pF'];
                    attribute redefines fuelDielectricConstant = 2.0;
                    attribute redefines airDielectricConstant = 1.0;
                }
                part redefines conditioningCircuit : SignalConditioningCircuit {
                    attribute redefines gain = 0.04;
                    attribute redefines offset = 0.5 ['V'];
                }
                part redefines adc : AnalogToDigitalConverter {
                    attribute redefines resolutionBits = 12;
                    attribute redefines referenceVoltage = 5 ['V'];
                    attribute redefines samplingRate = 20 ['Hz'];
                }
                part redefines processor : SignalProcessor {
                    attribute redefines filterCoefficient = 0.3;
                    attribute redefines tankCapacity = 60 ['L'];
                }
            }
            part redefines ecu : VehicleECU;
            part redefines diagnosticTool : DiagnosticTool;
        }

        satisfy accuracyReq by fuelSensorVehicle.sensorUnit;
        satisfy updateRateReq by fuelSensorVehicle.sensorUnit;
        satisfy serviceLifeReq by fuelSensorVehicle.sensorUnit;
        satisfy powerSupplyReq by fuelSensorVehicle.sensorUnit;
        satisfy communicationReq by fuelSensorVehicle.sensorUnit;
        satisfy diagnosticReq by fuelSensorVehicle.sensorUnit;
        satisfy selfTestReq by fuelSensorVehicle.sensorUnit;
        satisfy faultHandlingReq by fuelSensorVehicle.sensorUnit;
    }
}
