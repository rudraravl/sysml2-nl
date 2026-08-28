package CancerDiagnosticProbe {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def BiomarkerConcentration :> ScalarValues::Real;
    attribute def OpticalSignalValue :> ScalarValues::Real;
    attribute def TissueTemperature :> ISQ::TemperatureValue;
    attribute def ConfidenceLevel :> ScalarValues::Real;
    attribute def Timestamp :> ScalarValues::String;

    enum def TissueClassification {
        benign;
        suspicious;
        malignant;
    }

    attribute def OpticalSample {
        attribute biomarkerConcentration : BiomarkerConcentration;
        attribute signalStrength : OpticalSignalValue;
    }
    attribute def ThermalSample {
        attribute temperature : TissueTemperature;
    }
    attribute def ProcessedData {
        attribute filteredOptical : OpticalSample;
        attribute filteredThermal : ThermalSample;
        attribute timestamp : Timestamp;
    }
    attribute def DiagnosticOutput {
        attribute classification : TissueClassification;
        attribute confidence : ConfidenceLevel;
        attribute timestamp : Timestamp;
    }

    port def OpticalOutPort { out optical : OpticalSample; }
    port def OpticalInPort { in optical : OpticalSample; }
    port def ThermalOutPort { out thermal : ThermalSample; }
    port def ThermalInPort { in thermal : ThermalSample; }
    port def ProcessedOutPort { out processed : ProcessedData; }
    port def ProcessedInPort { in processed : ProcessedData; }
    port def DiagnosticOutPort { out result : DiagnosticOutput; }
    port def DiagnosticInPort { in result : DiagnosticOutput; }

    part def OpticalBiosensor {
        port opticalOut : OpticalOutPort;
        action acquire;
    }
    part def ThermalSensor {
        port thermalOut : ThermalOutPort;
        action acquire;
    }

    part def ProbeTip {
        port opticalOut : OpticalOutPort;
        port thermalOut : ThermalOutPort;
        part opticalSensor : OpticalBiosensor;
        part thermalSensor : ThermalSensor;
        connect opticalSensor.opticalOut to opticalOut;
        connect thermalSensor.thermalOut to thermalOut;
    }

    part def SignalProcessingUnit {
        port opticalIn : OpticalInPort;
        port thermalIn : ThermalInPort;
        port processedOut : ProcessedOutPort;
        action process;
    }

    part def DiagnosticAlgorithm {
        port processedIn : ProcessedInPort;
        port resultOut : DiagnosticOutPort;
        attribute benignThreshold : BiomarkerConcentration := 5.0;
        attribute suspiciousThreshold : BiomarkerConcentration := 10.0;
        attribute minConfidence : ConfidenceLevel := 0.80;
        attribute lastResult : DiagnosticOutput;
        action analyze;
    }

    part def BatteryPack {
        attribute capacity : ElectricChargeValue := 5000 [SI::C];
        attribute voltage : ElectricPotentialValue := 3.7 [SI::V];
    }

    part def WirelessTransceiver {
        port resultIn : DiagnosticInPort;
        port wirelessOut : DiagnosticOutPort;
        action transmit;
    }

    attribute def CalibrateCommand;
    attribute def ReadySignal;
    attribute def ScanCommand;
    attribute def ScanComplete;
    attribute def AnalysisComplete;
    attribute def TransmitComplete;
    attribute def ResetCommand;
    attribute def ErrorSignal;

    part def Probe {
        part tip : ProbeTip;
        part spu : SignalProcessingUnit;
        part algorithm : DiagnosticAlgorithm;
        part battery : BatteryPack;
        part transceiver : WirelessTransceiver;
        port wirelessOut : DiagnosticOutPort;
        attribute weight : MassValue := 0.5 [SI::kg];
        attribute length : LengthValue := 0.2 [SI::m];
        
        connect tip.opticalOut to spu.opticalIn;
        connect tip.thermalOut to spu.thermalIn;
        connect spu.processedOut to algorithm.processedIn;
        connect algorithm.resultOut to transceiver.resultIn;
        connect transceiver.wirelessOut to wirelessOut;
        
        action calibrateSensors {
            perform tip.opticalSensor.acquire;
            perform tip.thermalSensor.acquire;
        }
        action scanTissue {
            perform tip.opticalSensor.acquire;
            perform tip.thermalSensor.acquire;
            perform spu.process;
        }
        action analyzeTissue {
            perform algorithm.analyze;
        }
        action transmitResult {
            perform transceiver.transmit;
        }
        action handleFault;
        
        exhibit state probeStates {
            entry; then idle;
            state idle;
            accept CalibrateCommand then calibrating;
            accept ScanCommand then scanning;
            
            state calibrating {
                do calibrateSensors;
            }
            accept ReadySignal then idle;
            accept ErrorSignal then fault;
            
            state scanning {
                do scanTissue;
            }
            accept ScanComplete then analyzing;
            accept ErrorSignal then fault;
            
            state analyzing {
                do analyzeTissue;
            }
            accept AnalysisComplete if algorithm.lastResult.confidence >= algorithm.minConfidence then transmitting;
            accept AnalysisComplete if algorithm.lastResult.confidence < algorithm.minConfidence then scanning;
            accept ErrorSignal then fault;
            
            state transmitting {
                do transmitResult;
            }
            accept TransmitComplete then complete;
            accept ErrorSignal then fault;
            
            state complete;
            accept ResetCommand then idle;
            
            state fault {
                do handleFault;
            }
            accept ResetCommand then idle;
        }
    }

    part probe : Probe;

    requirement def DiagnosticAccuracy {
        attribute minConfidence : ConfidenceLevel;
    }
    requirement def BatteryLife {
        attribute minOperatingTime : Real;
    }
    requirement def WirelessDataTransmission;

    requirement rAccuracy : DiagnosticAccuracy {
        attribute minConfidence := 0.90;
    }
    requirement rBatteryLife : BatteryLife {
        attribute minOperatingTime := 8.0;
    }
    requirement rWireless : WirelessDataTransmission;
}
