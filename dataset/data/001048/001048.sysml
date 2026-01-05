package 'Fiber Bragg Grating Sensing System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def WavelengthValue :> LengthValue;
    attribute def RefractiveIndexValue :> Real;
    attribute def GratingPeriodValue :> LengthValue;
    attribute def StrainValue :> Real;
    attribute def ReflectivityValue :> Real;
    
    item def OpticalSignal {
        attribute wavelength : WavelengthValue;
        attribute power : PowerValue;
        attribute spectralWidth : WavelengthValue;
    }
    
    item def BroadbandLight :> OpticalSignal {
        attribute centerWavelength : WavelengthValue;
        attribute bandwidth : WavelengthValue;
    }
    
    item def ReflectedLight :> OpticalSignal {
        attribute peakWavelength : WavelengthValue;
        attribute reflectivity : ReflectivityValue;
    }
    
    item def TransmittedLight :> OpticalSignal {
        attribute attenuatedPower : PowerValue;
    }
    
    port def OpticalInputPort {
        in item inputLight : OpticalSignal;
    }
    
    port def OpticalOutputPort {
        out item outputLight : OpticalSignal;
    }
    
    port def BidirectionalOpticalPort {
        in item signalIn : OpticalSignal;
        out item signalOut : OpticalSignal;
    }
    
    port def SensingPort {
        in attribute appliedStrain : StrainValue;
        in attribute ambientTemperature : ThermodynamicTemperatureValue;
    }
    
    port def DataOutputPort {
        out attribute measuredStrain : StrainValue;
        out attribute measuredTemperature : ThermodynamicTemperatureValue;
    }
    
    part def BroadbandLightSource {
        doc /* Generates broadband optical signal for interrogation. */
        port emissionPort : OpticalOutputPort;
        attribute sourceWavelength : WavelengthValue;
        attribute sourcePower : PowerValue;
    }
    
    part def OpticalCirculator {
        doc /* Routes light from source to FBG and reflected light to detector. */
        port port1 : OpticalInputPort;
        port port2 : BidirectionalOpticalPort;
        port port3 : OpticalOutputPort;
    }
    
    part def FiberBraggGrating {
        doc /* Periodic refractive index modulation that reflects specific wavelength. */
        port opticalPort : BidirectionalOpticalPort;
        port sensingPort : SensingPort;
        
        attribute gratingPeriod : GratingPeriodValue;
        attribute gratingLength : LengthValue;
        attribute effectiveRefractiveIndex : RefractiveIndexValue;
        attribute braggWavelength : WavelengthValue;
        attribute peakReflectivity : ReflectivityValue;
    }
    
    part def OpticalSpectrumAnalyzer {
        doc /* Measures wavelength spectrum of reflected light. */
        port inputPort : OpticalInputPort;
        attribute detectedWavelength : WavelengthValue;
        attribute detectedPower : PowerValue;
        attribute wavelengthResolution : WavelengthValue;
    }
    
    part def SignalProcessingUnit {
        doc /* Converts wavelength shift to physical measurements. */
        attribute wavelengthData : WavelengthValue;
        attribute powerData : PowerValue;
        attribute strainOutput : StrainValue;
        attribute temperatureOutput : ThermodynamicTemperatureValue;
        
        attribute referenceWavelength : WavelengthValue;
        attribute strainSensitivity : Real;
        attribute temperatureSensitivity : Real;
    }
    
    action def EmitBroadbandLight {
        out broadbandSignal : BroadbandLight;
    }
    
    action def CalculateBraggWavelength {
        in refractiveIndex : RefractiveIndexValue;
        in period : GratingPeriodValue;
        out braggLambda : WavelengthValue;
    }
    
    action def ReflectAtBraggWavelength {
        in incidentLight : BroadbandLight;
        in currentBraggWavelength : WavelengthValue;
        in reflectivity : ReflectivityValue;
        out reflected : ReflectedLight;
        out transmitted : TransmittedLight;
    }
    
    action def MeasureWavelengthSpectrum {
        in opticalInput : ReflectedLight;
        out peakWavelength : WavelengthValue;
        out signalPower : PowerValue;
    }
    
    action def ComputePhysicalParameters {
        in measuredWavelength : WavelengthValue;
        in referenceWavelength : WavelengthValue;
        in strainCoefficient : Real;
        in temperatureCoefficient : Real;
        out strain : StrainValue;
        out temperature : ThermodynamicTemperatureValue;
    }
    
    action def PerformSensingCycle {
        in appliedStrain : StrainValue;
        in appliedTemperature : ThermodynamicTemperatureValue;
        out measuredStrain : StrainValue;
        out measuredTemperature : ThermodynamicTemperatureValue;
        
        private attribute emittedLight : BroadbandLight;
        private attribute currentBraggWavelength : WavelengthValue;
        private attribute reflectedSignal : ReflectedLight;
        private attribute detectedWavelength : WavelengthValue;
        private attribute detectedPower : PowerValue;
        
        first start;
        then action emit : EmitBroadbandLight {
            out broadbandSignal;
        }
        then assign emittedLight := emit.broadbandSignal;
        then action calculateBragg : CalculateBraggWavelength {
            in refractiveIndex;
            in period;
            out braggLambda;
        }
        then assign currentBraggWavelength := calculateBragg.braggLambda;
        then action reflect : ReflectAtBraggWavelength {
            in incidentLight = emittedLight;
            in currentBraggWavelength;
            in reflectivity;
            out reflected;
            out transmitted;
        }
        then assign reflectedSignal := reflect.reflected;
        then action measure : MeasureWavelengthSpectrum {
            in opticalInput = reflectedSignal;
            out peakWavelength;
            out signalPower;
        }
        then assign detectedWavelength := measure.peakWavelength;
        then assign detectedPower := measure.signalPower;
        then action compute : ComputePhysicalParameters {
            in measuredWavelength = detectedWavelength;
            in referenceWavelength;
            in strainCoefficient;
            in temperatureCoefficient;
            out strain;
            out temperature;
        }
        then assign measuredStrain := compute.strain;
        then assign measuredTemperature := compute.temperature;
        then done;
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* Defines required measurement precision for sensing applications. */
        attribute strainAccuracy : StrainValue;
        attribute temperatureAccuracy : ThermodynamicTemperatureValue;
    }
    
    requirement def OpticalCharacteristicsRequirement {
        doc /* Specifies optical performance parameters of the FBG. */
        attribute minimumReflectivity : ReflectivityValue;
        attribute maximumBandwidth : WavelengthValue;
        attribute operatingWavelengthRange : WavelengthValue;
    }
    
    requirement def SystemFunctionalRequirement {
        doc /* 
            The Fiber Bragg Grating sensing system shall measure physical parameters
            by detecting wavelength shifts in reflected light caused by environmental changes.
        */
        
        require constraint accuracyConstraint {
            doc /* System shall meet specified measurement accuracy requirements. */
        }
        
        require constraint opticalConstraint {
            doc /* System shall meet specified optical performance requirements. */
        }
        
        require constraint primaryFunction {
            doc /* 
                The system shall reflect light at a wavelength determined by the Bragg condition,
                and the reflected wavelength shall shift in response to applied strain and temperature,
                enabling precise measurement of these physical parameters.
            */
        }
    }
    
    part def FiberBraggGratingSensingSystem {
        doc /* 
            A Fiber Bragg Grating (FBG) sensing system that measures physical parameters
            such as strain and temperature by detecting shifts in the wavelength of light
            reflected from a periodic refractive index structure within an optical fiber.
            The system operates by illuminating the FBG with broadband light and analyzing
            the wavelength spectrum of the reflected signal to determine environmental changes.
        */
        
        port systemSensingPort : SensingPort;
        port systemDataPort : DataOutputPort;
        
        part lightSource : BroadbandLightSource {
            attribute :>> sourceWavelength = 1550.0e-9;
            attribute :>> sourcePower = 1.0e-3;
        }
        
        part circulator : OpticalCirculator;
        
        part fbg : FiberBraggGrating {
            attribute :>> gratingPeriod = 535.0e-9;
            attribute :>> gratingLength = 10.0e-3;
            attribute :>> effectiveRefractiveIndex = 1.45;
            attribute :>> braggWavelength = 1550.0e-9;
            attribute :>> peakReflectivity = 0.95;
        }
        
        part spectrumAnalyzer : OpticalSpectrumAnalyzer {
            attribute :>> wavelengthResolution = 0.01e-9;
        }
        
        part processor : SignalProcessingUnit {
            attribute :>> referenceWavelength = 1550.0e-9;
            attribute :>> strainSensitivity = 1.2e-6;
            attribute :>> temperatureSensitivity = 10.0e-6;
        }
        
        connection sourceToCirculator 
            connect lightSource.emissionPort to circulator.port1;
        
        connection circulatorToFBG 
            connect circulator.port2 to fbg.opticalPort;
        
        connection circulatorToAnalyzer 
            connect circulator.port3 to spectrumAnalyzer.inputPort;
        
        connection sensingToFBG 
            connect systemSensingPort to fbg.sensingPort;
        
        perform action sensingOperation : PerformSensingCycle {
            in appliedStrain;
            in appliedTemperature;
            out measuredStrain;
            out measuredTemperature;
        }
    }
    
    part fbgSensingSystem : FiberBraggGratingSensingSystem {
        satisfy sysReq : SystemFunctionalRequirement by fbgSensingSystem;
    }
}
