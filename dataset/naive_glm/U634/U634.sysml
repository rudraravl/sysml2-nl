package ChemFETSensingSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ---- Value Types with Units ----
    value type Voltage :> Real { unit 'V' = 'volt'; }
    value type Current :> Real { unit 'A' = 'ampere'; }
    value type Concentration :> Real { unit 'mol/L' = 'mole per litre'; }
    value type Resistance :> Real { unit 'Ohm' = 'ohm'; }
    value type Capacitance :> Real { unit 'F' = 'farad'; }
    value type TimeValue :> Real { unit 's' = 'second'; }
    value type Frequency :> Real { unit 'Hz' = 'hertz'; }
    value type Gain :> Real { unit '1' = 'dimensionless'; }
    
    // ---- Item Types ----
    item def Analyte {
        attribute concentration : Concentration;
        attribute targetName : String;
    }
    
    item def Solution {
        item analytes : Analyte[0..*];
        attribute temperature : Real;
    }
    
    item def ElectricalSignal {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    
    // ---- Port Definitions ----
    port def ChemicalPort {
        in item solution : Solution;
    }
    
    port def VoltagePort {
        out attribute voltage : Voltage;
        in attribute voltage : Voltage;
    }
    
    port def CurrentPort {
        out attribute current : Current;
        in attribute current : Current;
    }
    
    // ---- Requirements ----
    requirement def SensitivityRequirement {
        attribute minDetectableConcentration : Concentration = 1e-6 [mol/L];
        require attribute detectedConcentration : Concentration >= minDetectableConcentration;
    }
    
    requirement def SelectivityRequirement {
        attribute targetChemical : String;
        require attribute boundChemical : String == targetChemical;
    }
    
    requirement def ResponseTimeRequirement {
        attribute maxResponseTime : TimeValue = 0.5 [s];
        require attribute actualResponseTime : TimeValue <= maxResponseTime;
    }
    
    requirement def OutputStabilityRequirement {
        attribute maxNoiseAmplitude : Voltage = 0.001 [V];
        require attribute outputNoise : Voltage <= maxNoiseAmplitude;
    }
    
    // ---- Ion-Selective Membrane ----
    part def IonSelectiveMembrane {
        attribute targetChemical : String = "K+";
        attribute bindingConstant : Real;
        attribute surfacePotential : Voltage;
        attribute baselinePotential : Voltage;
        
        port chemicalIn : ChemicalPort;
        port potentialOut : VoltagePort;
        
        action def BindAnalyte {
            in item incomingSolution : Solution;
            out attribute resultingPotential : Voltage;
        }
        
        perform action bind : BindAnalyte {
            in item incomingSolution = chemicalIn.solution;
            out attribute resultingPotential = surfacePotential;
        }
        
        satisfy SelectivityRequirement {
            attribute targetChemical = targetChemical;
            attribute boundChemical = targetChemical;
        }
    }
    
    // ---- Reference Electrode ----
    part def ReferenceElectrode {
        attribute referenceVoltage : Voltage = 0.0 [V];
        attribute stability : Real;
        
        port refOut : VoltagePort;
        
        action def EstablishBaseline {
            out attribute baseline : Voltage;
        }
        
        perform action establish : EstablishBaseline {
            out attribute baseline = referenceVoltage;
        }
    }
    
    // ---- FET Transducer ----
    part def FETTransducer {
        attribute transconductance : Real;
        attribute drainCurrent : Current;
        attribute thresholdVoltage : Voltage;
        attribute supplyVoltage : Voltage = 5.0 [V];
        attribute gatePotential : Voltage;
        
        port gateIn : VoltagePort;
        port referenceIn : VoltagePort;
        port drainOut : CurrentPort;
        
        action def ModulateCurrent {
            in attribute gateVoltage : Voltage;
            in attribute referenceVoltage : Voltage;
            out attribute outputCurrent : Current;
        }
        
        perform action modulate : ModulateCurrent {
            in attribute gateVoltage = gateIn.voltage;
            in attribute referenceVoltage = referenceIn.voltage;
            out attribute outputCurrent = drainCurrent;
        }
    }
    
    // ---- Readout Circuit ----
    part def ReadoutCircuit {
        attribute transimpedanceGain : Resistance = 1e6 [Ohm];
        attribute voltageGain : Gain = 10.0;
        attribute cutoffFrequency : Frequency = 100.0 [Hz];
        attribute outputVoltage : Voltage;
        attribute filteredVoltage : Voltage;
        
        port currentIn : CurrentPort;
        port voltageOut : VoltagePort;
        
        action def ConvertCurrentToVoltage {
            in attribute inputCurrent : Current;
            out attribute convertedVoltage : Voltage;
        }
        
        action def AmplifyVoltage {
            in attribute inputVoltage : Voltage;
            out attribute amplifiedVoltage : Voltage;
        }
        
        action def FilterNoise {
            in attribute inputVoltage : Voltage;
            out attribute outputVoltage : Voltage;
        }
        
        perform action convert : ConvertCurrentToVoltage {
            in attribute inputCurrent = currentIn.current;
            out attribute convertedVoltage = outputVoltage;
        }
        
        perform action amplify : AmplifyVoltage {
            in attribute inputVoltage = outputVoltage;
            out attribute amplifiedVoltage = filteredVoltage;
        }
        
        perform action filter : FilterNoise {
            in attribute inputVoltage = filteredVoltage;
            out attribute outputVoltage = voltageOut.voltage;
        }
        
        satisfy OutputStabilityRequirement {
            attribute outputNoise = 0.0005 [V];
        }
    }
    
    // ---- State Machine for ChemFET Sensor ----
    state def ChemFETOperation {
        entry; then idle;
        
        state idle;
        
        transition from idle to calibrating
            when (true) {
                attribute calibrationTrigger : Boolean = true;
            };
        
        state calibrating {
            entry {
                attribute baselineEstablished : Boolean = false;
            }
            do {
                attribute baselineValue : Voltage;
            }
            exit {
                attribute baselineEstablished = true;
            }
        }
        
        transition from calibrating to activeMeasuring
            when (calibrating.baselineEstablished == true);
        
        state activeMeasuring {
            do {
                attribute measuredConcentration : Concentration;
                attribute outputSignal : Voltage;
            }
        }
        
        transition from activeMeasuring to idle
            when (false);
    }
    
    // ---- Top-level ChemFET Sensor ----
    part def ChemFETSensor {
        attribute systemName : String = "ChemFET Sensor";
        attribute targetAnalyte : String = "K+";
        attribute responseTime : TimeValue;
        attribute sensitivity : Concentration;
        
        port chemicalInput : ChemicalPort;
        port electricalOutput : VoltagePort;
        
        part membrane : IonSelectiveMembrane {
            attribute targetChemical = targetAnalyte;
        }
        
        part reference : ReferenceElectrode;
        
        part fet : FETTransducer;
        
        part readout : ReadoutCircuit;
        
        // Connections
        connection chemicalToMembrane connect chemicalInput to membrane.chemicalIn;
        
        connection membraneToFET connect membrane.potentialOut to fet.gateIn;
        
        connection referenceToFET connect reference.refOut to fet.referenceIn;
        
        connection fetToReadout connect fet.drainOut to readout.currentIn;
        
        connection readoutOutput connect readout.voltageOut to electricalOutput;
        
        // Behavior
        exhibit state operation : ChemFETOperation;
        
        // Requirement satisfaction
        satisfy SensitivityRequirement {
            attribute detectedConcentration = sensitivity;
        }
        
        satisfy ResponseTimeRequirement {
            attribute actualResponseTime = responseTime;
        }
    }
    
    // ---- Instantiated System ----
    part chemFETSystem : ChemFETSensor {
        attribute systemName = "Potassium ChemFET System";
        attribute targetAnalyte = "K+";
        attribute responseTime = 0.3 [s];
        attribute sensitivity = 1e-7 [mol/L];
        
        part membrane redefines membrane {
            attribute bindingConstant = 2.5e4;
            attribute baselinePotential = 0.0 [V];
        }
        
        part reference redefines reference {
            attribute referenceVoltage = 0.0 [V];
            attribute stability = 0.99;
        }
        
        part fet redefines fet {
            attribute transconductance = 2.0e-3;
            attribute thresholdVoltage = 1.0 [V];
            attribute supplyVoltage = 5.0 [V];
        }
        
        part readout redefines readout {
            attribute transimpedanceGain = 1e6 [Ohm];
            attribute voltageGain = 10.0;
            attribute cutoffFrequency = 100.0 [Hz];
        }
    }
}
