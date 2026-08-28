package CancerDiagnosticProbeModel {

    package ValueTypes {
        value type Concentration :> Real {
            :>> unit = BiomarkerConcentrationUnit;
        }
        attribute def BiomarkerConcentrationUnit :> Unit {
            :>> symbol = "ng/mL";
        }
        value type Temperature :> Real {
            :>> unit = CelsiusUnit;
        }
        attribute def CelsiusUnit :> Unit {
            :>> symbol = "degC";
        }
        value type Confidence :> Real {
            :>> unit = PercentUnit;
        }
        attribute def PercentUnit :> Unit {
            :>> symbol = "%";
        }
        value type Voltage :> Real {
            :>> unit = VoltUnit;
        }
        attribute def VoltUnit :> Unit {
            :>> symbol = "V";
        }
        value type Charge :> Real {
            :>> unit = MilliampHourUnit;
        }
        attribute def MilliampHourUnit :> Unit {
            :>> symbol = "mAh";
        }
        value type Power :> Real {
            :>> unit = WattUnit;
        }
        attribute def WattUnit :> Unit {
            :>> symbol = "W";
        }
        value type Wavelength :> Real {
            :>> unit = NanometerUnit;
        }
        attribute def NanometerUnit :> Unit {
            :>> symbol = "nm";
        }
        value type Mass :> Real {
            :>> unit = GramUnit;
        }
        attribute def GramUnit :> Unit {
            :>> symbol = "g";
        }
        value type Length :> Real {
            :>> unit = MillimeterUnit;
        }
        attribute def MillimeterUnit :> Unit {
            :>> symbol = "mm";
        }
    }

    package Items {
        private import ValueTypes::*;
        private import ScalarValues::*;

        enum def TissueClassification {
            benign;
            suspicious;
            malignant;
        }

        item def RawOpticalSignal {
            attribute amplitude : Voltage;
            attribute timestamp : String;
        }
        item def RawThermalSignal {
            attribute amplitude : Voltage;
            attribute timestamp : String;
        }
        item def ProcessedOpticalData {
            attribute biomarkerConcentration : Concentration;
            attribute timestamp : String;
        }
        item def ProcessedThermalData {
            attribute tissueTemperature : Temperature;
            attribute timestamp : String;
        }
        item def DiagnosticResult {
            attribute classification : TissueClassification;
            attribute confidence : Confidence;
            attribute timestamp : String;
        }
        item def CalibrationCommand;
        item def ScanCommand;
        item def ResetCommand;
        item def CalibrationComplete;
        item def CalibrationError;
        item def ScanComplete;
        item def ScanError;
        item def AnalysisComplete {
            attribute result : DiagnosticResult;
        }
        item def AnalysisError;
        item def LowBatteryAlert;
        item def PowerOnCommand;
        item def PowerOffCommand;
    }

    package Ports {
        private import Items::*;

        port def OpticalSignalOut {
            out item signal : RawOpticalSignal;
        }
        port def OpticalSignalIn {
            in item signal : RawOpticalSignal;
        }
        port def ThermalSignalOut {
            out item signal : RawThermalSignal;
        }
        port def ThermalSignalIn {
            in item signal : RawThermalSignal;
        }
        port def ProcessedOpticalOut {
            out item data : ProcessedOpticalData;
        }
        port def ProcessedOpticalIn {
            in item data : ProcessedOpticalData;
        }
        port def ProcessedThermalOut {
            out item data : ProcessedThermalData;
        }
        port def ProcessedThermalIn {
            in item data : ProcessedThermalData;
        }
        port def DiagnosticResultOut {
            out item result : DiagnosticResult;
        }
        port def DiagnosticResultIn {
            in item result : DiagnosticResult;
        }
        port def PowerOut {
            out attribute power : ValueTypes::Power;
        }
        port def PowerIn {
            in attribute power : ValueTypes::Power;
        }
        port def CommandIn {
            in item command;
        }
        port def WirelessTransmitOut {
            out item result : DiagnosticResult;
        }
    }

    package Components {
        private import Ports::*;
        private import Items::*;
        private import ValueTypes::*;
        private import ScalarValues::*;

        part def OpticalBiosensor {
            port signalOut : OpticalSignalOut;
            port powerIn : PowerIn;
            attribute redLightWavelength : Wavelength = 660.0;
            attribute isCalibrated : Boolean = false;
            attribute detectionRange : Concentration = 50.0;
            attribute noiseFloor : Voltage = 0.001;

            action def SenseOptical {
                in tissueContact : Boolean;
                out rawSignal : RawOpticalSignal;
            }
            action def CalibrateSensor {
                out success : Boolean;
            }
            perform action sense : SenseOptical;
            perform action calibrate : CalibrateSensor;
        }

        part def ThermalSensor {
            port signalOut : ThermalSignalOut;
            port powerIn : PowerIn;
            attribute measurementRangeMin : Temperature = 30.0;
            attribute measurementRangeMax : Temperature = 45.0;
            attribute accuracy : Temperature = 0.1;
            attribute isCalibrated : Boolean = false;

            action def SenseThermal {
                in tissueContact : Boolean;
                out rawSignal : RawThermalSignal;
            }
            action def CalibrateSensor {
                out success : Boolean;
            }
            perform action sense : SenseThermal;
            perform action calibrate : CalibrateSensor;
        }

        part def ProbeTip {
            port opticalSignalOut : OpticalSignalOut;
            port thermalSignalOut : ThermalSignalOut;
            port powerIn : PowerIn;
            attribute biocompatible : Boolean = true;
            attribute material : String = "Medical-grade stainless steel";
            attribute contactDiameter : Length = 2.0;
            attribute isMinimallyInvasive : Boolean = true;

            part opticalBiosensor : OpticalBiosensor {
                :>> signalOut : OpticalSignalOut;
                :>> powerIn : PowerIn;
            }
            part thermalSensor : ThermalSensor {
                :>> signalOut : ThermalSignalOut;
                :>> powerIn : PowerIn;
            }

            connection opticalSensorToTipPort connect opticalBiosensor.signalOut to opticalSignalOut;
            connection thermalSensorToTipPort connect thermalSensor.signalOut to thermalSignalOut;
            connection powerToOpticalSensor connect powerIn to opticalBiosensor.powerIn;
            connection powerToThermalSensor connect powerIn to thermalSensor.powerIn;
        }

        part def SignalProcessingUnit {
            port opticalIn : OpticalSignalIn;
            port thermalIn : ThermalSignalIn;
            port opticalOut : ProcessedOpticalOut;
            port thermalOut : ProcessedThermalOut;
            port powerIn : PowerIn;
            attribute filterCutoffFrequency : Real = 1000.0;
            attribute samplingRate : Real = 5000.0;
            attribute signalGain : Real = 10.0;

            action def FilterNoise {
                in rawOptical : RawOpticalSignal;
                in rawThermal : RawThermalSignal;
                out filteredOptical : RawOpticalSignal;
                out filteredThermal : RawThermalSignal;
            }
            action def ProcessOptical {
                in filteredSignal : RawOpticalSignal;
                out opticalData : ProcessedOpticalData;
            }
            action def ProcessThermal {
                in filteredSignal : RawThermalSignal;
                out thermalData : ProcessedThermalData;
            }
            perform action filter : FilterNoise;
            perform action processOpt : ProcessOptical;
            perform action processTherm : ProcessThermal;
        }

        part def DiagnosticAlgorithm {
            port opticalIn : ProcessedOpticalIn;
            port thermalIn : ProcessedThermalIn;
            port resultOut : DiagnosticResultOut;
            port powerIn : PowerIn;
            attribute benignThreshold : Concentration = 5.0;
            attribute suspiciousThreshold : Concentration = 15.0;
            attribute malignantThreshold : Concentration = 25.0;
            attribute minConfidence : Confidence = 75.0;
            attribute maxRescanAttempts : Integer = 3;
            attribute temperatureDeviationThreshold : Temperature = 2.0;

            action def Analyze {
                in opticalData : ProcessedOpticalData;
                in thermalData : ProcessedThermalData;
                out result : DiagnosticResult;
            }
            action def Classify {
                in biomarkerLevel : Concentration;
                in temperature : Temperature;
                in baselineTemperature : Temperature;
                out classification : TissueClassification;
                out confidence : Confidence;
            }
            action def CalculateConfidence {
                in biomarkerLevel : Concentration;
                in temperatureDeviation : Temperature;
                out confidence : Confidence;
            }
            perform action analyze : Analyze;
            perform action classify : Classify;
            perform action calcConfidence : CalculateConfidence;
        }

        part def BatteryPack {
            port powerOut : PowerOut;
            attribute capacity : Charge = 3000.0;
            attribute currentCharge : Charge = 3000.0;
            attribute nominalVoltage : Voltage = 3.7;
            attribute isRechargeable : Boolean = true;
            attribute lowBatteryThreshold : Charge = 500.0;
            attribute outputPower : Power = 1.5;

            action def SupplyPower {
                out power : Power;
            }
            action def Discharge {
                in rate : Power;
                out remaining : Charge;
            }
            action def Recharge {
                in chargeAmount : Charge;
                out newCharge : Charge;
            }
            perform action supply : SupplyPower;
            perform action discharge : Discharge;
            perform action recharge : Recharge;
        }

        part def WirelessTransceiver {
            port dataIn : DiagnosticResultIn;
            port transmitOut : WirelessTransmitOut;
            port powerIn : PowerIn;
            attribute protocol : String = "Bluetooth";
            attribute version : String = "5.0";
            attribute isConnected : Boolean = false;
            attribute transmissionRange : Real = 10.0;
            attribute encryptionEnabled : Boolean = true;

            action def Transmit {
                in result : DiagnosticResult;
            }
            action def EstablishConnection {
                out success : Boolean;
            }
            action def Disconnect;
            perform action transmit : Transmit;
            perform action connect : EstablishConnection;
            perform action disconnect : Disconnect;
        }
    }

    package System {
        private import Components::*;
        private import Ports::*;
        private import Items::*;
        private import ValueTypes::*;
        private import ScalarValues::*;

        part def DiagnosticProbe {
            port commandPort : CommandIn;
            port externalTransmitPort : WirelessTransmitOut;
            attribute deviceWeight : Mass = 250.0;
            attribute deviceLength : Length = 180.0;
            attribute isHandheld : Boolean = true;
            attribute isWireless : Boolean = true;
            attribute firmwareVersion : String = "1.0.0";
            attribute isPoweredOn : Boolean = false;

            part probeTip : ProbeTip {
                :>> opticalSignalOut : OpticalSignalOut;
                :>> thermalSignalOut : ThermalSignalOut;
                :>> powerIn : PowerIn;
            }
            part signalProcessor : SignalProcessingUnit {
                :>> opticalIn : OpticalSignalIn;
                :>> thermalIn : ThermalSignalIn;
                :>> opticalOut : ProcessedOpticalOut;
                :>> thermalOut : ProcessedThermalOut;
                :>> powerIn : PowerIn;
            }
            part diagnosticAlgorithm : DiagnosticAlgorithm {
                :>> opticalIn : ProcessedOpticalIn;
                :>> thermalIn : ProcessedThermalIn;
                :>> resultOut : DiagnosticResultOut;
                :>> powerIn : PowerIn;
            }
            part battery : BatteryPack {
                :>> powerOut : PowerOut;
            }
            part transceiver : WirelessTransceiver {
                :>> dataIn : DiagnosticResultIn;
                :>> transmitOut : WirelessTransmitOut;
                :>> powerIn : PowerIn;
            }

            connection opticalDataFlow connect probeTip.opticalSignalOut to signalProcessor.opticalIn;
            connection thermalDataFlow connect probeTip.thermalSignalOut to signalProcessor.thermalIn;
            connection processedOpticalFlow connect signalProcessor.opticalOut to diagnosticAlgorithm.opticalIn;
            connection processedThermalFlow connect signalProcessor.thermalOut to diagnosticAlgorithm.thermalIn;
            connection resultFlow connect diagnosticAlgorithm.resultOut to transceiver.dataIn;
            connection externalTransmitFlow connect transceiver.transmitOut to externalTransmitPort;

            connection batteryToTipPower connect battery.powerOut to probeTip.powerIn;
            connection batteryToSPUPower connect battery.powerOut to signalProcessor.powerIn;
            connection batteryToAlgoPower connect battery.powerOut to diagnosticAlgorithm.powerIn;
            connection batteryToTransceiverPower connect battery.powerOut to transceiver.powerIn;

            exhibit state behavior ProbeStateMachine {
                attribute isCalibrated : Boolean = false;
                attribute rescanAttempts : Integer = 0;
                attribute maxRescanAttempts : Integer = 3;
                attribute lastConfidence : Confidence = 0.0;
                attribute minConfidence : Confidence = 75.0;
                attribute lastResult : DiagnosticResult;

                state Idle {
                    entry { isPoweredOn = true; }
                    do { /* wait for clinician command */ }
                }
                state Calibrating {
                    do { /* calibrate optical biosensor and thermal sensor */ }
                }
                state Scanning {
                    do { /* actively gather optical and thermal data from tissue */ }
                }
                state Analyzing {
                    entry { /* invoke diagnostic algorithm */ }
                    do { /* process data and classify tissue */ }
                }
                state Complete {
                    do { /* transmit diagnostic result via wireless transceiver */ }
                }
                state Fault {
                    entry { /* log error and alert clinician */ }
                }

                transition first to Idle;

                transition from Idle to Calibrating accept CalibrationCommand;

                transition from Calibrating to Idle accept CalibrationComplete {
                    effect { isCalibrated = true; }
                }

                transition from Calibrating to Fault accept CalibrationError;

                transition from Idle to Scanning accept ScanCommand if { isCalibrated == true };

                transition from Scanning to Analyzing accept ScanComplete;

                transition from Scanning to Fault accept ScanError;

                transition from Analyzing to Complete accept AnalysisComplete if { lastConfidence >= minConfidence } {
                    effect { rescanAttempts = 0; }
                }

                transition from Analyzing to Scanning accept AnalysisComplete if { lastConfidence < minConfidence and rescanAttempts < maxRescanAttempts } {
                    effect { rescanAttempts = rescanAttempts + 1; }
                }

                transition from Analyzing to Fault accept AnalysisComplete if { lastConfidence < minConfidence and rescanAttempts >= maxRescanAttempts };

                transition from Analyzing to Fault accept AnalysisError;

                transition from Complete to Idle accept ResetCommand {
                    effect { rescanAttempts = 0; }
                }

                transition from Fault to Idle accept ResetCommand {
                    effect { rescanAttempts = 0; }
                }

                transition from Idle to Fault accept LowBatteryAlert;
                transition from Scanning to Fault accept LowBatteryAlert;
                transition from Analyzing to Fault accept LowBatteryAlert;
            }
        }
    }

    package Requirements {
        private import System::*;
        private import Components::*;

        requirement def DiagnosticCapability {
            doc "The probe shall classify tissue samples as benign, suspicious, or malignant in real time without requiring a traditional biopsy lab result.";
            subject probe : DiagnosticProbe;
        }
        requirement def Biocompatibility {
            doc "The probe tip shall be biocompatible and designed for minimally invasive contact with tissue.";
            subject probeTip : ProbeTip;
        }
        requirement def OpticalSensing {
            doc "The optical biosensor shall use red light to detect the concentration of specific cancer biomarkers.";
            subject sensor : OpticalBiosensor;
        }
        requirement def ThermalSensing {
            doc "The thermal sensor shall measure tissue temperature to identify metabolic irregularities associated with cancerous growths.";
            subject sensor : ThermalSensor;
        }
        requirement def SignalProcessingReq {
            doc "The signal processing unit shall filter noise from raw sensor signals and process them into a usable format.";
            subject spu : SignalProcessingUnit;
        }
        requirement def DiagnosticAnalysis {
            doc "The diagnostic algorithm shall analyze biomarker levels and other signals, classify tissue based on predefined thresholds, and calculate a confidence level.";
            subject algo : DiagnosticAlgorithm;
        }
        requirement def BatteryLife {
            doc "The battery pack shall be rechargeable and provide sufficient power for extended use during diagnostic procedures.";
            subject battery : BatteryPack;
        }
        requirement def WirelessTransmission {
            doc "The wireless transceiver shall transmit diagnostic data including tissue classification, confidence level, and timestamp to an external device.";
            subject transceiver : WirelessTransceiver;
        }
        requirement def RescanOnLowConfidence {
            doc "If the diagnostic confidence level is below the minimum threshold, the probe shall automatically re-scan the tissue to gather more data.";
            subject probe : DiagnosticProbe;
        }
        requirement def StateDrivenOperation {
            doc "The probe shall operate through Idle, Calibrating, Scanning, Analyzing, Complete, and Fault states in a state-driven workflow.";
            subject probe : DiagnosticProbe;
        }
        requirement def Portability {
            doc "The probe shall be lightweight, handheld, battery-powered, and wireless for portable clinical use.";
            subject probe : DiagnosticProbe;
        }
        requirement def FaultHandling {
            doc "The probe shall enter a Fault state upon any operational error and allow reset to return to Idle.";
            subject probe : DiagnosticProbe;
        }

        requirement diagCap : DiagnosticCapability;
        requirement biocompat : Biocompatibility;
        requirement optSensing : OpticalSensing;
        requirement thermSensing : ThermalSensing;
        requirement sigProc : SignalProcessingReq;
        requirement diagAnalysis : DiagnosticAnalysis;
        requirement battLife : BatteryLife;
        requirement wirelessTx : WirelessTransmission;
        requirement rescan : RescanOnLowConfidence;
        requirement stateOp : StateDrivenOperation;
        requirement portability : Portability;
        requirement faultHandling : FaultHandling;
    }
}
