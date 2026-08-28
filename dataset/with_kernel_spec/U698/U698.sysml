package GolayCellDetectorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    item def InfraredRadiation {
        attribute intensity : PowerValue;
        attribute wavelength : LengthValue;
    }
    
    item def Heat {
        attribute amount : EnergyValue;
    }
    
    item def GasPressure {
        attribute value : PressureValue;
    }
    
    item def MembraneDeflection {
        attribute displacement : LengthValue;
    }
    
    item def OpticalSignal {
        attribute power : PowerValue;
    }
    
    item def Voltage {
        attribute value : ElectricPotentialValue;
    }
    
    attribute def RadiationDetected;
    attribute def RadiationRemoved;
    attribute def PressureNormalized;
    
    action def AbsorbRadiation {
        in radiation : InfraredRadiation;
        out heat : Heat;
    }
    
    action def ExpandGas {
        in heat : Heat;
        out pressure : GasPressure;
    }
    
    action def DeflectMembrane {
        in pressure : GasPressure;
        out deflection : MembraneDeflection;
    }
    
    action def GenerateProbeLight {
        out light : OpticalSignal;
    }
    
    action def ReflectLight {
        in probeLight : OpticalSignal;
        in deflection : MembraneDeflection;
        out reflectedLight : OpticalSignal;
    }
    
    action def ConvertToVoltage {
        in deflection : MembraneDeflection;
        out voltage : Voltage;
    }
    
    part def AbsorptionWindow {
        in item incidentRadiation : InfraredRadiation;
        out item heat : Heat;
        perform action absorb : AbsorbRadiation;
        bind absorb.radiation = incidentRadiation;
        bind absorb.heat = heat;
    }
    
    part def GasChamber {
        in item heat : Heat;
        out item pressure : GasPressure;
        perform action expand : ExpandGas;
        bind expand.heat = heat;
        bind expand.pressure = pressure;
    }
    
    part def FlexibleMembrane {
        in item pressure : GasPressure;
        in item probeLight : OpticalSignal;
        out item reflectedLight : OpticalSignal;
        out item deflection : MembraneDeflection;
        perform action deflect : DeflectMembrane;
        perform action reflect : ReflectLight;
        bind deflect.pressure = pressure;
        bind deflect.deflection = deflection;
        bind reflect.probeLight = probeLight;
        bind reflect.deflection = deflection;
        bind reflect.reflectedLight = reflectedLight;
    }
    
    part def OpticalReadout {
        out item probeLight : OpticalSignal;
        in item reflectedLight : OpticalSignal;
        in item deflection : MembraneDeflection;
        out item voltage : Voltage;
        perform action generate : GenerateProbeLight;
        perform action convert : ConvertToVoltage;
        bind generate.light = probeLight;
        bind convert.deflection = deflection;
        bind convert.voltage = voltage;
    }
    
    state def DetectorStates {
        entry action initial {
            doc /* Initial pseudo state. */
        }
        transition initial then equilibrium;
        
        state equilibrium;
        state detecting;
        state cooling;
        
        transition equilibrium_to_detecting
            first equilibrium
            accept RadiationDetected
            then detecting;
        
        transition detecting_to_cooling
            first detecting
            accept RadiationRemoved
            then cooling;
        
        transition cooling_to_equilibrium
            first cooling
            accept PressureNormalized
            then equilibrium;
    }
    
    part def GolayCellDetector {
        in item incidentRadiation : InfraredRadiation;
        out item outputVoltage : Voltage;
        
        part absorptionWindow : AbsorptionWindow;
        part gasChamber : GasChamber;
        part flexibleMembrane : FlexibleMembrane;
        part opticalReadout : OpticalReadout;
        
        bind absorptionWindow.incidentRadiation = incidentRadiation;
        flow absorptionWindow.heat to gasChamber.heat;
        flow gasChamber.pressure to flexibleMembrane.pressure;
        flow opticalReadout.probeLight to flexibleMembrane.probeLight;
        flow flexibleMembrane.reflectedLight to opticalReadout.reflectedLight;
        flow flexibleMembrane.deflection to opticalReadout.deflection;
        bind outputVoltage = opticalReadout.voltage;
        
        exhibit state detectorStates : DetectorStates;
    }
    
    requirement def InfraredDetectionRequirement {
        doc /* The Golay Cell Detector System shall detect incident infrared radiation and convert it into a measurable electrical voltage signal. */
    }
    
    requirement def BroadSpectrumRequirement {
        doc /* The system shall be sensitive to a broad spectrum of infrared wavelengths. */
    }
    
    requirement def ProportionalOutputRequirement {
        doc /* The output electrical signal shall be proportional to the intensity of the incident infrared radiation. */
    }
    
    requirement def ReturnToEquilibriumRequirement {
        doc /* After the infrared radiation is removed, the system shall return to its equilibrium state ready for another measurement. */
    }
    
    part golayCell : GolayCellDetector;
    
    requirement irDetection : InfraredDetectionRequirement;
    requirement broadSpectrum : BroadSpectrumRequirement;
    requirement proportionalOutput : ProportionalOutputRequirement;
    requirement returnEquilibrium : ReturnToEquilibriumRequirement;
}
