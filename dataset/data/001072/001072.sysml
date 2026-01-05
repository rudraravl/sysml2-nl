package 'Golay Cell Detector System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def IrradianceValue :> Real;
    attribute def PressureValue :> Real;
    attribute def DisplacementValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def CapacitanceValue :> Real;
    
    item def InfraredRadiation {
        attribute irradiance : IrradianceValue;
        attribute wavelength : LengthValue;
    }
    
    item def GasPressure {
        attribute pressure : PressureValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }
    
    item def OpticalSignal {
        attribute intensity : Real;
        attribute displacement : DisplacementValue;
    }
    
    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute current : ElectricCurrentValue;
    }
    
    port def RadiationInputPort {
        in item radiation : InfraredRadiation;
    }
    
    port def PressurePort {
        inout item gasPressure : GasPressure;
    }
    
    port def OpticalPort {
        out item opticalSignal : OpticalSignal;
    }
    
    port def ElectricalOutputPort {
        out item electricalSignal : ElectricalSignal;
    }
    
    part def AbsorptionWindow {
        port radiationIn : RadiationInputPort;
        attribute transmittance : Real;
        attribute absorptance : Real;
    }
    
    part def GasChamber {
        port pressurePort : PressurePort;
        attribute volume : VolumeValue;
        attribute gasConstant : Real;
        attribute sealedMass : MassValue;
    }
    
    part def FlexibleMembrane {
        port pressureIn : PressurePort;
        port opticalOut : OpticalPort;
        attribute area : AreaValue;
        attribute compliance : Real;
        attribute reflectivity : Real;
    }
    
    part def OpticalReadout {
        port opticalIn : OpticalPort;
        port electricalOut : ElectricalOutputPort;
        attribute laserWavelength : LengthValue;
        attribute photodetectorSensitivity : Real;
    }
    
    part def GolayCellDetector {
        doc /* A Golay cell is a thermal detector that converts incident 
               infrared radiation into an electrical signal through gas 
               expansion and optical readout of membrane displacement. */
        
        port irInput : RadiationInputPort;
        port signalOutput : ElectricalOutputPort;
        
        part window : AbsorptionWindow {
            doc /* Absorbs incident IR radiation and converts it to heat. */
        }
        
        part chamber : GasChamber {
            doc /* Sealed gas chamber that expands when heated by absorbed radiation. */
            attribute volume = 500.0;
            attribute sealedMass = 0.001;
        }
        
        part membrane : FlexibleMembrane {
            doc /* Flexible reflective membrane that deflects due to pressure changes. */
            attribute area = 25.0;
            attribute compliance = 0.002;
            attribute reflectivity = 0.95;
        }
        
        part readout : OpticalReadout {
            doc /* Optical system that measures membrane displacement and converts to voltage. */
            attribute laserWavelength = 650.0e-9;
            attribute photodetectorSensitivity = 0.5;
        }
        
        connection windowToChamber connect window.radiationIn to chamber.pressurePort;
        connection chamberToMembrane connect chamber.pressurePort to membrane.pressureIn;
        connection membraneToReadout connect membrane.opticalOut to readout.opticalIn;
        connection readoutToOutput connect readout.electricalOut to signalOutput;
    }
    
    action def AbsorbInfraredRadiation {
        in incidentIrradiance : IrradianceValue;
        in absorptance : Real;
        out absorbedPower : PowerValue;
    }
    
    action def HeatGas {
        in absorbedPower : PowerValue;
        in gasMass : MassValue;
        in specificHeat : Real;
        out temperatureIncrease : ThermodynamicTemperatureValue;
    }
    
    action def ExpandGas {
        in temperatureIncrease : ThermodynamicTemperatureValue;
        in chamberVolume : VolumeValue;
        in gasConstant : Real;
        out pressureIncrease : PressureValue;
    }
    
    action def DeflectMembrane {
        in pressureIncrease : PressureValue;
        in membraneArea : AreaValue;
        in compliance : Real;
        out displacement : DisplacementValue;
    }
    
    action def MeasureDisplacement {
        in displacement : DisplacementValue;
        in laserWavelength : LengthValue;
        out intensityChange : Real;
    }
    
    action def ConvertToVoltage {
        in intensityChange : Real;
        in photodetectorSensitivity : Real;
        out outputVoltage : VoltageValue;
    }
    
    action def DetectInfraredRadiation {
        doc /* Primary detection function: Convert incident infrared radiation 
               into proportional electrical voltage through thermal expansion 
               and optical displacement measurement. */
        
        in incidentRadiation : IrradianceValue;
        out detectedVoltage : VoltageValue;
        
        first start;
        
        then action absorb : AbsorbInfraredRadiation {
            in incidentIrradiance = incidentRadiation;
            in absorptance;
            out absorbedPower;
        }
        
        then action heat : HeatGas {
            in absorbedPower = absorb.absorbedPower;
            in gasMass;
            in specificHeat;
            out temperatureIncrease;
        }
        
        then action expand : ExpandGas {
            in temperatureIncrease = heat.temperatureIncrease;
            in chamberVolume;
            in gasConstant;
            out pressureIncrease;
        }
        
        then action deflect : DeflectMembrane {
            in pressureIncrease = expand.pressureIncrease;
            in membraneArea;
            in compliance;
            out displacement;
        }
        
        then action measure : MeasureDisplacement {
            in displacement = deflect.displacement;
            in laserWavelength;
            out intensityChange;
        }
        
        then action convert : ConvertToVoltage {
            in intensityChange = measure.intensityChange;
            in photodetectorSensitivity;
            out outputVoltage;
        }
        
        then assign detectedVoltage := convert.outputVoltage;
        
        then done;
    }
    
    attribute def RadiationIncidentSignal;
    
    state def GolayCellOperatingStates {
        entry; then equilibrium;
        
        state equilibrium {
            doc /* Detector at thermal equilibrium, ready to detect radiation. */
        }
        
        transition equilibrium_to_absorbing
            first equilibrium
            accept at radiationIncident : RadiationIncidentSignal
            then absorbing;
        
        state absorbing {
            doc /* Window absorbing incident IR radiation and heating gas. */
            entry action absorbRadiation : AbsorbInfraredRadiation;
        }
        
        transition absorbing_to_expanding
            first absorbing
            then expanding;
        
        state expanding {
            doc /* Gas expanding due to temperature increase. */
            entry action expandGas : ExpandGas;
        }
        
        transition expanding_to_deflecting
            first expanding
            then deflecting;
        
        state deflecting {
            doc /* Membrane deflecting due to pressure differential. */
            entry action deflectMembrane : DeflectMembrane;
        }
        
        transition deflecting_to_measuring
            first deflecting
            then measuring;
        
        state measuring {
            doc /* Optical readout measuring membrane displacement. */
            entry action measureDisplacement : MeasureDisplacement;
        }
        
        transition measuring_to_converting
            first measuring
            then converting;
        
        state converting {
            doc /* Converting optical signal to electrical voltage. */
            entry action convertSignal : ConvertToVoltage;
        }
        
        transition converting_to_cooling
            first converting
            then cooling;
        
        state cooling {
            doc /* System cooling and returning to equilibrium. */
        }
        
        transition cooling_to_equilibrium
            first cooling
            then equilibrium;
    }
    
    part golayDetectorSystem : GolayCellDetector {
        perform action detection : DetectInfraredRadiation;
        
        exhibit state operatingCycle : GolayCellOperatingStates;
        
        part window : AbsorptionWindow {
            attribute transmittance = 0.05;
            attribute absorptance = 0.95;
        }
        
        part chamber : GasChamber {
            attribute volume = 500.0;
            attribute gasConstant = 287.0;
            attribute sealedMass = 0.001;
        }
        
        part membrane : FlexibleMembrane {
            attribute area = 25.0;
            attribute compliance = 0.002;
            attribute reflectivity = 0.95;
        }
        
        part readout : OpticalReadout {
            attribute laserWavelength = 650.0e-9;
            attribute photodetectorSensitivity = 0.5;
        }
    }
    
    requirement def DetectionSensitivityRequirement {
        doc /* The Golay cell shall detect infrared radiation with specified 
               minimum detectable power. */
        
        subject detector : GolayCellDetector;
        
        require constraint minimumDetectablePower {
            doc /* Minimum detectable power shall be less than 10 nanowatts. */
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The Golay cell shall respond to radiation changes within 
               specified time constant. */
        
        subject detector : GolayCellDetector;
        
        require constraint responseTime {
            doc /* Thermal time constant shall be less than 100 milliseconds. */
        }
    }
    
    requirement def SpectralRangeRequirement {
        doc /* The Golay cell shall operate across specified infrared 
               wavelength range. */
        
        subject detector : GolayCellDetector;
        
        require constraint wavelengthRange {
            doc /* Effective detection from 1 micrometer to 1000 micrometers. */
        }
    }
    
    requirement def LinearityRequirement {
        doc /* The Golay cell output shall be linear with incident radiation 
               over specified dynamic range. */
        
        subject detector : GolayCellDetector;
        
        require constraint outputLinearity {
            doc /* Output voltage proportional to irradiance within 5 percent over three decades. */
        }
    }
    
    requirement <'GC-SYS-001'> golaySystemRequirement {
        doc /* The Golay cell detector system shall convert incident infrared 
               radiation into a proportional electrical signal through thermal 
               expansion of sealed gas and optical measurement of membrane 
               displacement, providing broadband infrared detection with high 
               sensitivity independent of wavelength. */
        
        subject system : GolayCellDetector;
        
        assume constraint thermalIsolation {
            doc /* Gas chamber is thermally isolated from ambient environment. */
        }
        
        assume constraint sealedChamber {
            doc /* Gas chamber maintains hermetic seal with constant gas mass. */
        }
        
        assume constraint opticalAlignment {
            doc /* Optical readout system is properly aligned with membrane. */
        }
        
        require constraint sensitivityReq : DetectionSensitivityRequirement;
        require constraint responseReq : ResponseTimeRequirement;
        require constraint spectralReq : SpectralRangeRequirement;
        require constraint linearityReq : LinearityRequirement;
    }
}
