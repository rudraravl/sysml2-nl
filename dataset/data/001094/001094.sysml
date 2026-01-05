package ISFETpHSensingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def pHValue :> Real;
    attribute def IonConcentration :> Real;
    attribute def SurfacePotential :> ElectricPotentialValue;
    attribute def ThresholdVoltage :> ElectricPotentialValue;
    
    port def ChemicalInterface {
        in attribute solutionpH : pHValue;
        in attribute hydrogenIonConcentration : IonConcentration;
        in attribute temperature : ThermodynamicTemperatureValue;
    }
    
    port def ElectricalInterface {
        in attribute gateVoltage : ElectricPotentialValue;
        in attribute drainVoltage : ElectricPotentialValue;
        out attribute drainCurrent : ElectricCurrentValue;
    }
    
    port def DigitalOutput {
        out attribute digitalpH : pHValue;
    }
    
    part def IonSensitiveMembrane {
        port chemPort : ChemicalInterface;
        attribute membraneType : String;
        
        action def GenerateSurfacePotential {
            in pH : pHValue;
            in ionConc : IonConcentration;
            in temp : ThermodynamicTemperatureValue;
            out potential : SurfacePotential;
        }
        
        perform action generatePotential : GenerateSurfacePotential;
    }
    
    part def ReferenceElectrode {
        attribute referenceType : String;
        port electricalOut {
            out attribute refVoltage : ElectricPotentialValue;
        }
    }
    
    part def FETTransistor {
        port gatePort : ElectricalInterface;
        port sourcePort;
        port drainPort;
        
        attribute channelWidth : LengthValue;
        attribute channelLength : LengthValue;
        attribute mobility : Real;
        
        action def ModulateCurrent {
            in vGate : ElectricPotentialValue;
            in vThreshold : ThresholdVoltage;
            in vDrain : ElectricPotentialValue;
            out iDrain : ElectricCurrentValue;
        }
        
        perform action currentModulation : ModulateCurrent;
    }
    
    part def TransimpedanceAmplifier {
        port currentIn {
            in attribute inputCurrent : ElectricCurrentValue;
        }
        port voltageOut {
            out attribute outputVoltage : ElectricPotentialValue;
        }
        
        attribute gainResistance : Real;
        
        action def ConvertCurrentToVoltage {
            in current : ElectricCurrentValue;
            in gain : Real;
            out voltage : ElectricPotentialValue;
        }
        
        perform action convert : ConvertCurrentToVoltage;
    }
    
    part def ADC {
        port analogIn {
            in attribute inputVoltage : ElectricPotentialValue;
        }
        port digitalOut {
            out attribute digitalCode : Integer;
        }
        
        attribute resolution : Integer;
        attribute referenceVoltage : ElectricPotentialValue;
        
        action def Digitize {
            in analogSignal : ElectricPotentialValue;
            in bits : Integer;
            in vRef : ElectricPotentialValue;
            out digitalValue : Integer;
        }
        
        perform action digitize : Digitize;
    }
    
    part def Microcontroller {
        port dataIn {
            in attribute adcValue : Integer;
        }
        port dataOut : DigitalOutput;
        
        attribute calibrationSlope : Real;
        attribute calibrationOffset : Real;
        
        action def ComputepH {
            in digitalCode : Integer;
            in slope : Real;
            in offset : Real;
            in temp : ThermodynamicTemperatureValue;
            out pHResult : pHValue;
        }
        
        action def TemperatureCompensation {
            in rawpH : pHValue;
            in temperature : ThermodynamicTemperatureValue;
            out compensatedpH : pHValue;
        }
        
        perform action processpH {
            action calculate : ComputepH;
            flow calculate.pHResult to compensate.rawpH;
            action compensate : TemperatureCompensation;
        }
    }
    
    part def ISFETSensor {
        doc /* 
            Ion-Sensitive Field-Effect Transistor (ISFET) sensor system for 
            measuring pH and ion concentrations in aqueous solutions through 
            direct chemical-to-electrical signal transduction.
        */
        
        port solutionInterface : ChemicalInterface;
        port measurementOutput : DigitalOutput;
        
        part membrane : IonSensitiveMembrane {
            doc /* Chemically sensitive layer that develops surface potential based on ion activity */
        }
        
        part reference : ReferenceElectrode {
            doc /* Provides stable electrochemical reference potential */
        }
        
        part transistor : FETTransistor {
            doc /* Transduces chemical potential to electrical current */
        }
        
        part amplifier : TransimpedanceAmplifier {
            doc /* Converts drain current to measurable voltage signal */
        }
        
        part converter : ADC {
            doc /* Digitizes analog voltage for microcontroller processing */
        }
        
        part processor : Microcontroller {
            doc /* Computes calibrated pH value with temperature compensation */
        }
        
        connect solutionInterface to membrane.chemPort;
        connect transistor.drainPort to amplifier.currentIn;
        connect amplifier.voltageOut to converter.analogIn;
        connect converter.digitalOut to processor.dataIn;
        connect processor.dataOut to measurementOutput;
    }
    
    action def MeasurepHValue {
        doc /* 
            Primary sensing function: Measure solution pH by detecting hydrogen ion 
            concentration at the membrane surface, which modulates the ISFET threshold 
            voltage and drain current, producing a calibrated digital pH reading.
        */
        
        in attribute solutionpH : pHValue;
        in attribute ionActivity : IonConcentration;
        in attribute ambientTemp : ThermodynamicTemperatureValue;
        out attribute measuredpH : pHValue;
        
        action exposeMembrane {
            in pH : pHValue = solutionpH;
            in ions : IonConcentration = ionActivity;
            in temp : ThermodynamicTemperatureValue = ambientTemp;
            out surfaceCharge : Real;
        }
        flow exposeMembrane.surfaceCharge to developPotential.charge;
        action developPotential {
            in charge : Real;
            in temp : ThermodynamicTemperatureValue = ambientTemp;
            out potential : SurfacePotential;
        }
        flow developPotential.potential to modulateGate.gatePotential;
        action modulateGate {
            in gatePotential : SurfacePotential;
            out drainCurrent : ElectricCurrentValue;
        }
        flow modulateGate.drainCurrent to amplifySignal.current;
        action amplifySignal {
            in current : ElectricCurrentValue;
            out voltage : ElectricPotentialValue;
        }
        flow amplifySignal.voltage to convertToDigital.analogVoltage;
        action convertToDigital {
            in analogVoltage : ElectricPotentialValue;
            out digitalCode : Integer;
        }
        flow convertToDigital.digitalCode to calculatepH.code;
        action calculatepH {
            in code : Integer;
            in temp : ThermodynamicTemperatureValue = ambientTemp;
            out pHValue : pHValue;
        }
        bind measuredpH = calculatepH.pHValue;
    }
    
    requirement def FunctionalRequirement {
        doc /* The ISFET system shall measure pH of aqueous solutions */
        subject sensor : ISFETSensor;
        
        require constraint measurementRange {
            doc /* System shall measure pH from 0 to 14 */
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* The ISFET system shall meet specified accuracy and response criteria */
        
        require constraint accuracy {
            doc /* Measurement accuracy shall be ±0.02 pH units */
        }
        
        require constraint responseTime {
            doc /* System shall stabilize within 10 seconds of solution exposure */
        }
        
        require constraint resolution {
            doc /* Digital output shall have minimum 0.01 pH resolution */
        }
    }
    
    requirement def EnvironmentalRequirement {
        doc /* The ISFET system shall operate under specified environmental conditions */
        
        require constraint operatingTemperature {
            doc /* System shall operate from 0°C to 100°C */
        }
        
        require constraint drift {
            doc /* Long-term drift shall not exceed 0.05 pH per month */
        }
    }
    
    requirement systemRequirements {
        doc /* Complete requirements specification for ISFET pH sensing system */
        
        subject isfetSystem : ISFETSensor;
        
        require functionalReq : FunctionalRequirement;
        require performanceReq : PerformanceRequirement;
        require environmentalReq : EnvironmentalRequirement;
        
        assume constraint solutionContact {
            doc /* Ion-sensitive membrane must be in contact with aqueous solution */
        }
        
        assume constraint referenceStability {
            doc /* Reference electrode must maintain stable potential */
        }
        
        assume constraint properBiasing {
            doc /* ISFET must be properly biased in saturation region */
        }
    }
    
    action primaryFunction : MeasurepHValue {
        doc /* 
            High-level system function: The ISFET sensor continuously monitors 
            solution chemistry by transducing ion concentration into electrical 
            signals, enabling real-time pH measurement through direct potentiometric 
            sensing at the gate-solution interface.
        */
    }
}
