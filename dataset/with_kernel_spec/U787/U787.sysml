package NDIR_Gas_Sensor_System {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        unit PPM;
        
        attribute def Concentration :> ScalarValues::Real;
        
        item def IRBeam {
            attribute intensity : ScalarValues::Real;
            attribute wavelength : ScalarValues::Real;
        }
        
        item def GasSample {
            attribute co2Concentration : Concentration;
        }
        
        item def ElectricalSignal {
            attribute voltage : ScalarValues::Real;
        }
        
        item def MeasurementData {
            attribute concentration : Concentration;
            attribute timestamp : ScalarValues::Real;
        }
        
        attribute def PowerOnSignal;
        attribute def InitCompleteSignal;
        attribute def WarmUpCompleteSignal;
        attribute def CalCompleteSignal;
        attribute def ErrorDetectedSignal;
        attribute def IssueResolvedSignal;
        attribute def MaintenanceScheduledSignal;
        attribute def MaintenanceCompleteSignal;
        attribute def PowerOffSignal;
        
        action def EmitBeam {
            out beam : IRBeam;
        }
        
        action def CalculateConcentration {
            in meas : ElectricalSignal;
            in ref : ElectricalSignal;
            out data : MeasurementData;
        }
        
        port def IRBeamOutPort {
            out item beam : IRBeam;
        }
        port def IRBeamInPort {
            in item beam : IRBeam;
        }
        port def SignalOutPort {
            out item signal : ElectricalSignal;
        }
        port def SignalInPort {
            in item signal : ElectricalSignal;
        }
        port def DataOutPort {
            out item data : MeasurementData;
        }

        part def InfraredEmitter {
            out port beamOut : IRBeamOutPort;
            action emitBeam : EmitBeam;
            exhibit state emitterStates {
                entry; then off;
                state off;
                accept PowerOnSignal then warmingUp;
                state warmingUp {
                    do emitBeam;
                }
                accept WarmUpCompleteSignal then stable;
                state stable {
                    do emitBeam;
                }
                accept PowerOffSignal then off;
            }
        }
        
        part def OpticalFilter {
            in port beamIn : IRBeamInPort;
            out port beamOut : IRBeamOutPort;
        }
        
        part def BeamSplitter {
            in port beamIn : IRBeamInPort;
            out port measurementBeamOut : IRBeamOutPort;
            out port referenceBeamOut : IRBeamOutPort;
        }
        
        part def GasMeasurementChamber {
            in port beamIn : IRBeamInPort;
            out port beamOut : IRBeamOutPort;
            in port gasIn : GasSample;
            out port gasOut : GasSample;
        }
        
        part def Photodetector {
            in port beamIn : IRBeamInPort;
            out port signalOut : SignalOutPort;
        }
        
        part def SignalProcessingUnit {
            in port measurementSignalIn : SignalInPort;
            in port referenceSignalIn : SignalInPort;
            out port dataOut : DataOutPort;
            
            action calc : CalculateConcentration;
            
            exhibit state processingStates {
                entry; then idle;
                state idle;
                accept CalCompleteSignal then processing;
                state processing {
                    do calc;
                }
                accept PowerOffSignal then idle;
            }
        }
        
        state def SensorLifecycle;
    }
    
    package Usages {
        private import Definitions::*;
        
        part ndirSensor {
            part emitter : InfraredEmitter;
            part filter : OpticalFilter;
            part splitter : BeamSplitter;
            part chamber : GasMeasurementChamber;
            part measDetector : Photodetector;
            part refDetector : Photodetector;
            part processor : SignalProcessingUnit;
            
            connect emitter.beamOut to filter.beamIn;
            connect filter.beamOut to splitter.beamIn;
            connect splitter.measurementBeamOut to chamber.beamIn;
            connect chamber.beamOut to measDetector.beamIn;
            connect splitter.referenceBeamOut to refDetector.beamIn;
            
            connect measDetector.signalOut to processor.measurementSignalIn;
            connect refDetector.signalOut to processor.referenceSignalIn;
            
            exhibit state lifecycle : SensorLifecycle {
                entry; then poweredOff;
                state poweredOff;
                accept PowerOnSignal then initializing;
                state initializing;
                accept InitCompleteSignal then warmUp;
                state warmUp;
                accept WarmUpCompleteSignal then calibration;
                state calibration;
                accept CalCompleteSignal then normalMeasurement;
                state normalMeasurement;
                accept ErrorDetectedSignal then errorState;
                state errorState;
                accept IssueResolvedSignal then normalMeasurement;
                accept MaintenanceScheduledSignal then maintenance;
                state maintenance;
                accept MaintenanceCompleteSignal then normalMeasurement;
                accept PowerOffSignal then poweredOff;
            }
        }
        
        requirement def AccuracyRequirement {
            doc "The sensor shall measure CO2 concentration with an accuracy of +/- 50 ppm."
        }
        
        requirement def StabilityRequirement {
            doc "The sensor shall compensate for light source degradation using the reference beam."
        }
        
        requirement def LifecycleRequirement {
            doc "The sensor shall perform a warm-up and calibration sequence before normal measurement."
        }
        
        requirement accuracyReq : AccuracyRequirement;
        requirement stabilityReq : StabilityRequirement;
        requirement lifecycleReq : LifecycleRequirement;
    }
}
