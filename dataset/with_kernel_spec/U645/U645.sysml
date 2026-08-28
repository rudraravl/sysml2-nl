package DalyDetectorSystem {
    private import ScalarValues::*;
    
    package Definitions {
        value def VoltageValue :> Real;
        value def PressureValue :> Real;
        
        item def Ion;
        item def Electron;
        item def Photon;
        item def HighVoltage;
        item def ElectricalPulse {
            attribute amplitude: VoltageValue;
            attribute count: Integer;
        }
        
        attribute def StartDetection;
        attribute def StopDetection;
        attribute def StartCalibration;
        attribute def FaultDetected;
        attribute def ResetFault;
        
        part def ConversionDynode {
            in highVoltage: HighVoltage;
            in ion: Ion;
            out electrons: Electron;
            attribute voltage: VoltageValue = -20000;
        }
        
        part def Scintillator {
            in electrons: Electron;
            out photons: Photon;
        }
        
        part def PhotomultiplierTube {
            in highVoltage: HighVoltage;
            in photons: Photon;
            out rawPulse: ElectricalPulse;
            attribute gain: Real = 1000000;
        }
        
        part def SignalProcessor {
            in rawPulse: ElectricalPulse;
            out conditionedPulse: ElectricalPulse;
            attribute threshold: VoltageValue = 0.1;
        }
        
        part def HighVoltageSupply {
            out highVoltage: HighVoltage;
            attribute outputVoltage: VoltageValue = -20000;
        }
        
        part def VacuumChamber {
            part dynode : ConversionDynode;
            part scintillator : Scintillator;
            part pmt : PhotomultiplierTube;
            attribute pressure: PressureValue = 0.000001;
        }
        
        action def 'Convert Ion to Electrons' { in ion: Ion; out electrons: Electron; }
        action def 'Convert Electrons to Photons' { in electrons: Electron; out photons: Photon; }
        action def 'Amplify Photons to Pulse' { in photons: Photon; out rawPulse: ElectricalPulse; }
        action def 'Process Signal' { in rawPulse: ElectricalPulse; out conditionedPulse: ElectricalPulse; }
        
        action def 'Detect Ion' {
            in ion: Ion;
            out conditionedPulse: ElectricalPulse;
            
            action 'convert ion to electrons' : 'Convert Ion to Electrons';
            action 'convert electrons to photons' : 'Convert Electrons to Photons';
            action 'amplify photons to pulse' : 'Amplify Photons to Pulse';
            action 'process signal' : 'Process Signal';
            
            flow ion to 'convert ion to electrons'.ion;
            flow 'convert ion to electrons'.electrons to 'convert electrons to photons'.electrons;
            flow 'convert electrons to photons'.photons to 'amplify photons to pulse'.photons;
            flow 'amplify photons to pulse'.rawPulse to 'process signal'.rawPulse;
            flow 'process signal'.conditionedPulse to conditionedPulse;
            
            first 'convert ion to electrons';
            then 'convert electrons to photons';
            then 'amplify photons to pulse';
            then 'process signal';
        }
        
        part def DalyDetector {
            part chamber : VacuumChamber;
            part processor : SignalProcessor;
            part hvSupply : HighVoltageSupply;
            
            in ion: Ion;
            out conditionedPulse: ElectricalPulse;
            
            flow ion to chamber.dynode.ion;
            flow chamber.dynode.electrons to chamber.scintillator.electrons;
            flow chamber.scintillator.photons to chamber.pmt.photons;
            flow chamber.pmt.rawPulse to processor.rawPulse;
            flow processor.conditionedPulse to conditionedPulse;
            
            flow hvSupply.highVoltage to chamber.dynode.highVoltage;
            flow hvSupply.highVoltage to chamber.pmt.highVoltage;
            
            action 'detect ion' : 'Detect Ion';
            flow ion to 'detect ion'.ion;
            flow 'detect ion'.conditionedPulse to conditionedPulse;
            
            state detectorState {
                state idle;
                state active;
                state calibration;
                state fault;
                
                transition first idle accept start : StartDetection then active;
                transition first active accept stop : StopDetection then idle;
                transition first idle accept cal : StartCalibration then calibration;
                transition first calibration accept stop : StopDetection then idle;
                transition first idle accept fault : FaultDetected then fault;
                transition first active accept fault : FaultDetected then fault;
                transition first calibration accept fault : FaultDetected then fault;
                transition first fault accept reset : ResetFault then idle;
            }
        }
        
        constraint def C;
        constraint c : C;
        
        requirement def DetectionRequirement {
            doc /* The system must detect and count individual ions. */
            subject detector : DalyDetector;
            require c;
        }
        
        requirement def VacuumRequirement {
            doc /* The detector assembly must be housed within a vacuum chamber to prevent particle interference. */
            subject chamber : VacuumChamber;
            require c;
        }
        
        requirement def HVSupplyRequirement {
            doc /* A dedicated high-voltage supply must provide stable high-potential fields for the dynode and PMT. */
            subject supply : HighVoltageSupply;
            require c;
        }
        
        requirement def ThresholdFilterRequirement {
            doc /* The signal processor must filter out background noise by ignoring pulses below a defined threshold. */
            subject processor : SignalProcessor;
            require c;
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part dalyDetector : DalyDetector {
            requirement r : DetectionRequirement;
            satisfy r by dalyDetector;
            requirement vacReq : VacuumRequirement;
            satisfy vacReq by dalyDetector.chamber;
            requirement hvReq : HVSupplyRequirement;
            satisfy hvReq by dalyDetector.hvSupply;
            requirement threshReq : ThresholdFilterRequirement;
            satisfy threshReq by dalyDetector.processor;
        }
    }
}
