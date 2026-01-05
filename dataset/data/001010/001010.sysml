package 'ChemFET Sensing System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ChemicalConcentration :> Real;
    attribute def SurfacePotential :> Real;
    attribute def GatePotential :> Real;
    
    item def ChemicalAnalyte {
        attribute concentration : ChemicalConcentration;
        attribute pH : Real;
        attribute ionicStrength : Real;
    }
    
    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute current : ElectricCurrentValue;
    }
    
    port def ChemicalInputPort {
        in item analyte : ChemicalAnalyte;
    }
    
    port def ElectricalBiasPort {
        in attribute gateVoltage : VoltageValue;
        in attribute drainVoltage : VoltageValue;
        in attribute sourceVoltage : VoltageValue;
    }
    
    port def ElectricalOutputPort {
        out item signal : ElectricalSignal;
    }
    
    part def IonSelectiveMembrane {
        attribute selectivity : Real;
        attribute surfaceCharge : SurfacePotential;
        
        port chemicalInterface : ChemicalInputPort;
        
        action def BindAnalyte {
            in analyteConcentration : ChemicalConcentration;
            out surfacePotentialChange : SurfacePotential;
        }
    }
    
    part def ReferenceElectrode {
        attribute referencePotential : VoltageValue;
        
        action def ProvideReference {
            out refVoltage : VoltageValue;
        }
    }
    
    part def FETTransducer {
        attribute thresholdVoltage : VoltageValue;
        attribute channelConductance : Real;
        
        port biasInput : ElectricalBiasPort;
        port currentOutput : ElectricalOutputPort;
        
        action def ModulateChannel {
            in effectiveGateVoltage : VoltageValue;
            in drainSourceVoltage : VoltageValue;
            out drainCurrent : ElectricCurrentValue;
        }
    }
    
    part def ReadoutCircuit {
        attribute amplificationGain : Real;
        
        action def ConvertCurrentToVoltage {
            in inputCurrent : ElectricCurrentValue;
            out outputVoltage : VoltageValue;
        }
        
        action def FilterNoise {
            in rawSignal : VoltageValue;
            out filteredSignal : VoltageValue;
        }
    }
    
    part def ChemFETSensor {
        part membrane : IonSelectiveMembrane;
        part reference : ReferenceElectrode;
        part transistor : FETTransducer;
        part readout : ReadoutCircuit;
        
        port analyteInput : ChemicalInputPort;
        port biasControl : ElectricalBiasPort;
        port signalOutput : ElectricalOutputPort;
        
        connect membrane.chemicalInterface to analyteInput;
        connect transistor.biasInput to biasControl;
        connect transistor.currentOutput to signalOutput;
    }
    
    action def TransduceChemicalToElectrical {
        in inputAnalyte : ChemicalAnalyte;
        in gateVoltage : VoltageValue;
        in drainVoltage : VoltageValue;
        in sourceVoltage : VoltageValue;
        out measuredSignal : VoltageValue;
        
        first start;
        then action bindAnalyte : IonSelectiveMembrane::BindAnalyte {
            in analyteConcentration = inputAnalyte.concentration;
            out surfacePotentialChange : SurfacePotential;
        }
        then action provideReference : ReferenceElectrode::ProvideReference {
            out refVoltage : VoltageValue;
        }
        then action modulateChannel : FETTransducer::ModulateChannel {
            in effectiveGateVoltage = gateVoltage + bindAnalyte.surfacePotentialChange;
            in drainSourceVoltage = drainVoltage - sourceVoltage;
            out drainCurrent : ElectricCurrentValue;
        }
        then action convertSignal : ReadoutCircuit::ConvertCurrentToVoltage {
            in inputCurrent = modulateChannel.drainCurrent;
            out outputVoltage : VoltageValue;
        }
        then action filterSignal : ReadoutCircuit::FilterNoise {
            in rawSignal = convertSignal.outputVoltage;
            out filteredSignal : VoltageValue;
        }
        then assign measuredSignal := filterSignal.filteredSignal;
        then done;
    }
    
    state def ChemFETOperationalStates {
        entry; then idle;
        
        state idle;
        accept powerOn;
        then calibrating;
        
        state calibrating;
        accept calibrationComplete;
        then measuring;
        
        state measuring;
        accept measurementComplete;
        then idle;
        
        accept powerOff;
        then idle;
    }
    
    action def ContinuousSensing {
        in analyteSamples : ChemicalAnalyte[*];
        in operatingGateVoltage : VoltageValue;
        in operatingDrainVoltage : VoltageValue;
        in operatingSourceVoltage : VoltageValue;
        out measurements : VoltageValue[*] := ( );
        
        private attribute currentMeasurement : VoltageValue;
        
        for sample in analyteSamples {
            perform action transduce : TransduceChemicalToElectrical {
                in inputAnalyte = sample;
                in gateVoltage = operatingGateVoltage;
                in drainVoltage = operatingDrainVoltage;
                in sourceVoltage = operatingSourceVoltage;
                out measuredSignal;
            }
            then assign currentMeasurement := transduce.measuredSignal;
            then assign measurements := measurements->including(currentMeasurement);
        }
    }
    
    part chemFETSystem : ChemFETSensor {
        exhibit state operationalStates : ChemFETOperationalStates;
        
        perform action sensing[*] ordered references ContinuousSensing;
        
        part ionSensitiveMembrane : IonSelectiveMembrane {
            perform sensing.transduce.bindAnalyte;
        }
        
        part referenceElectrode : ReferenceElectrode {
            perform sensing.transduce.provideReference;
        }
        
        part fieldEffectTransistor : FETTransducer {
            perform sensing.transduce.modulateChannel;
        }
        
        part signalReadout : ReadoutCircuit {
            perform sensing.transduce.convertSignal;
            perform sensing.transduce.filterSignal;
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The ChemFET system shall transduce chemical concentration information 
               into a proportional electrical signal through field-effect modulation. */
        
        subject chemFETSystem;
    }
    
    requirement def SensitivityRequirement {
        doc /* The sensor shall detect analyte concentration changes with specified sensitivity. */
        
        attribute minimumDetectableChange : ChemicalConcentration;
        attribute linearRange : ChemicalConcentration[2];
        
        require constraint {
            minimumDetectableChange <= 1.0e-6
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The sensor shall respond to concentration changes within specified time. */
        
        attribute maximumResponseTime : TimeValue;
        
        require constraint {
            maximumResponseTime <= 10.0
        }
    }
    
    requirement def SelectivityRequirement {
        doc /* The membrane shall exhibit selectivity for target analyte. */
        
        attribute selectivityCoefficient : Real;
        
        require constraint {
            selectivityCoefficient >= 100.0
        }
    }
    
    requirement <'ChemFET-SYS-001'> systemRequirements {
        doc /* The ChemFET system shall convert chemical analyte concentration into 
               a measurable electrical signal for real-time chemical sensing applications. */
        
        subject chemFETSystem;
        
        require primaryFunction : PrimaryFunctionRequirement;
        
        require sensitivity : SensitivityRequirement {
            attribute :>> minimumDetectableChange = 1.0e-7;
            attribute :>> linearRange = (1.0e-6, 1.0e-2);
        }
        
        require responseTime : ResponseTimeRequirement {
            attribute :>> maximumResponseTime = 5.0;
        }
        
        require selectivity : SelectivityRequirement {
            attribute :>> selectivityCoefficient = 500.0;
        }
    }
}
