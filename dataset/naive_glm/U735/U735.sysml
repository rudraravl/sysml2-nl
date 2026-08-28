package IonizationChamberSystemModel {
    
    package ValueTypes {
        value type ElectricCharge :> Real { unit "C"; }
        value type ElectricCurrent :> Real { unit "A"; }
        value type ElectricPotential :> Real { unit "V"; }
        value type ElectricFieldStrength :> Real { unit "V/m"; }
        value type Resistance :> Real { unit "Ohm"; }
        value type RadiationDoseRate :> Real { unit "Sv/h"; }
        value type TimeDuration :> Real { unit "s"; }
        value type Frequency :> Real { unit "Hz"; }
    }
    
    package ItemDefinitions {
        import ValueTypes::*;
        
        item def IonizingRadiation {
            attribute doseRate : RadiationDoseRate;
        }
        
        item def HVPotential {
            attribute value : ElectricPotential;
        }
        
        item def GroundPotential {
            attribute value : ElectricPotential;
        }
        
        item def IonizationCurrentSignal {
            attribute current : ElectricCurrent;
        }
        
        item def AmplifiedVoltageSignal {
            attribute voltage : ElectricPotential;
        }
        
        item def RadiationMeasurement {
            attribute measuredDoseRate : RadiationDoseRate;
        }
    }
    
    package PortDefinitions {
        import ItemDefinitions::*;
        
        port def RadiationInPort {
            in item radiation : IonizingRadiation;
        }
        
        port def HVOutPort {
            out item hv : HVPotential;
        }
        
        port def HVInPort {
            in item hv : HVPotential;
        }
        
        port def GroundOutPort {
            out item ground : GroundPotential;
        }
        
        port def GroundInPort {
            in item ground : GroundPotential;
        }
        
        port def CurrentOutPort {
            out item currentSignal : IonizationCurrentSignal;
        }
        
        port def CurrentInPort {
            in item currentSignal : IonizationCurrentSignal;
        }
        
        port def VoltageOutPort {
            out item voltageSignal : AmplifiedVoltageSignal;
        }
        
        port def VoltageInPort {
            in item voltageSignal : AmplifiedVoltageSignal;
        }
        
        port def MeasurementOutPort {
            out item measurement : RadiationMeasurement;
        }
    }
    
    package ComponentDefinitions {
        import ValueTypes::*;
        import ItemDefinitions::*;
        import PortDefinitions::*;
        
        part def Electrode {
            attribute polarity : String;
            attribute potential : ElectricPotential;
        }
        
        part def Insulator {
            attribute material : String = "Ceramic";
        }
        
        part def IonizationChamber {
            part anode : Electrode { :>> polarity = "Positive"; }
            part cathode : Electrode { :>> polarity = "Negative"; }
            part insulators : Insulator[2];
            
            attribute fillGas : String = "Argon";
            attribute internalField : ElectricFieldStrength;
            
            port radiationIn : RadiationInPort;
            port hvIn : HVInPort;
            port groundIn : GroundInPort;
            port currentOut : CurrentOutPort;
            
            exhibit state ChamberOperation {
                state Idle;
                state Active {
                    do generateCurrent {
                        currentOut.currentSignal.current := radiationIn.radiation.doseRate * 1e-9 [A/(Sv/h)];
                    }
                }
                transition Idle to Active if radiationIn.radiation.doseRate > 0 [Sv/h];
                transition Active to Idle if radiationIn.radiation.doseRate == 0 [Sv/h];
            }
        }
        
        part def HighVoltageSupply {
            attribute outputPotential : ElectricPotential = 500 [V];
            port hvOut : HVOutPort;
            port groundOut : GroundOutPort;
            
            exhibit state HVOperation {
                state Off;
                state On {
                    do maintainVoltage {
                        hvOut.hv.value := outputPotential;
                        groundOut.ground.value := 0 [V];
                    }
                }
                transition Off to On;
            }
        }
        
        part def ChargeAmplifier {
            attribute transimpedance : Resistance = 1e9 [Ohm];
            port currentIn : CurrentInPort;
            port voltageOut : VoltageOutPort;
            
            exhibit state AmplifierOperation {
                state Idle;
                state Amplifying {
                    do amplifySignal {
                        voltageOut.voltageSignal.voltage := currentIn.currentSignal.current * transimpedance;
                    }
                }
                transition Idle to Amplifying if currentIn.currentSignal.current > 0 [A];
                transition Amplifying to Idle if currentIn.currentSignal.current == 0 [A];
            }
        }
        
        part def SignalProcessor {
            attribute integrationTime : TimeDuration = 1 [s];
            attribute filterCutoff : Frequency = 100 [Hz];
            port voltageIn : VoltageInPort;
            port measurementOut : MeasurementOutPort;
            
            exhibit state ProcessorOperation {
                state Idle;
                state Processing {
                    do processSignal {
                        measurementOut.measurement.measuredDoseRate := voltageIn.voltageSignal.voltage / 1.0 [V/(Sv/h)];
                    }
                }
                transition Idle to Processing if voltageIn.voltageSignal.voltage > 0 [V];
                transition Processing to Idle if voltageIn.voltageSignal.voltage == 0 [V];
            }
        }
    }
    
    package SystemAssembly {
        import ComponentDefinitions::*;
        import PortDefinitions::*;
        import ValueTypes::*;
        
        part def IonizationChamberSystem {
            port externalRadiation : RadiationInPort;
            port outputDisplay : MeasurementOutPort;
            
            part hvSupply : HighVoltageSupply;
            part chamber : IonizationChamber;
            part amplifier : ChargeAmplifier;
            part processor : SignalProcessor;
            
            connection radiationConnection {
                externalRadiation -> chamber.radiationIn;
            }
            connection anodeHVConnection {
                hvSupply.hvOut -> chamber.hvIn;
            }
            connection cathodeGroundConnection {
                hvSupply.groundOut -> chamber.groundIn;
            }
            connection currentConnection {
                chamber.currentOut -> amplifier.currentIn;
            }
            connection voltageConnection {
                amplifier.voltageOut -> processor.voltageIn;
            }
            connection outputConnection {
                processor.measurementOut -> outputDisplay;
            }
            
            exhibit state SystemOperation {
                state Off;
                state Initializing;
                state Measuring;
                transition Off to Initializing;
                transition Initializing to Measuring;
            }
        }
    }
    
    package Requirements {
        import SystemAssembly::*;
        import ValueTypes::*;
        
        requirement def DetectIonizingRadiation {
            doc "The system shall detect invisible ionizing radiation and convert it to a measurable electrical signal.";
            subject system : IonizationChamberSystem;
            objective {
                system.chamber.currentOut.currentSignal.current > 0 [A] 
                when system.chamber.radiationIn.radiation.doseRate > 0 [Sv/h];
            }
        }
        
        requirement def LinearResponse {
            doc "The system response shall be linear and proportional to the radiation intensity.";
            subject system : IonizationChamberSystem;
            objective {
                system.processor.measurementOut.measurement.measuredDoseRate == system.chamber.radiationIn.radiation.doseRate;
            }
        }
        
        requirement def HighStability {
            doc "The system shall be highly stable and reliable over long periods of continuous operation.";
            subject system : IonizationChamberSystem;
            objective {
                system.hvSupply.outputPotential >= 400 [V];
            }
        }
        
        requirement def SignalProcessing {
            doc "The signal processor shall filter electronic noise and integrate the signal over a specific period.";
            subject system : IonizationChamberSystem;
            objective {
                system.processor.integrationTime == 1 [s];
            }
        }
        
        requirement IonizationChamberSystemRequirements :> DetectIonizingRadiation, LinearResponse, HighStability, SignalProcessing {
            subject system : IonizationChamberSystem;
        }
    }
}
