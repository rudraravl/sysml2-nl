package OpticalFiberCommunicationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RefractiveIndex :> Real;
    attribute def AttenuationCoefficient :> Real;
    attribute def NumericalAperture :> Real;
    attribute def BitErrorRate :> Real;
    attribute def SignalToNoiseRatio :> Real;
    
    item def ElectricalSignal {
        attribute bitRate : FrequencyValue;
        attribute voltage : VoltageValue;
        attribute dataPayload : String;
    }
    
    item def OpticalSignal {
        attribute wavelength : LengthValue;
        attribute power : PowerValue;
        attribute frequency : FrequencyValue;
        attribute modulatedData : String;
    }
    
    item def LightPulse :> OpticalSignal {
        attribute pulseDuration : TimeValue;
        attribute pulseAmplitude : Real;
    }
    
    port def ElectricalPort {
        in item inputSignal : ElectricalSignal;
        out item outputSignal : ElectricalSignal;
    }
    
    port def OpticalPort {
        in item inputLight : OpticalSignal;
        out item outputLight : OpticalSignal;
    }
    
    action def ConvertElectricalToOptical {
        in item electricalInput : ElectricalSignal;
        out item opticalOutput : OpticalSignal;
    }
    
    action def ConvertOpticalToElectrical {
        in item opticalInput : OpticalSignal;
        out item electricalOutput : ElectricalSignal;
    }
    
    action def PropagateLight {
        in item inputLight : OpticalSignal;
        in fiberLength : LengthValue;
        in attenuationRate : AttenuationCoefficient;
        out item outputLight : OpticalSignal;
    }
    
    part def LaserDiode {
        attribute operatingWavelength : LengthValue;
        attribute outputPower : PowerValue;
        attribute threshold : PowerValue;
        
        action emitLight {
            in driveCurrent : ElectricCurrentValue;
            out laserOutput : OpticalSignal;
        }
    }
    
    part def OpticalModulator {
        attribute modulationDepth : Real;
        attribute modulationBandwidth : FrequencyValue;
        
        action modulateSignal {
            in carrierLight : OpticalSignal;
            in dataSignal : ElectricalSignal;
            out modulatedLight : OpticalSignal;
        }
    }
    
    part def OpticalTransmitter {
        port electricalInput : ElectricalPort;
        port opticalOutput : OpticalPort;
        
        part laser : LaserDiode {
            attribute operatingWavelength = 1550.0[nm];
            attribute outputPower = 10.0[W] * 0.001;
            attribute threshold = 5.0[W] * 0.001;
        }
        
        part modulator : OpticalModulator {
            attribute modulationDepth = 0.95;
            attribute modulationBandwidth = 10.0[Hz] * 1.0e9;
        }
        
        action transmit : ConvertElectricalToOptical {
            in item electricalInput : ElectricalSignal;
            out item opticalOutput : OpticalSignal;
            
            first action generateCarrier : laser.emitLight {
                in driveCurrent = 50.0[A] * 0.001;
                out laserOutput;
            }
            flow from generateCarrier.laserOutput to modulateData.carrierLight;
            then action modulateData : modulator.modulateSignal {
                in carrierLight;
                in dataSignal = electricalInput;
                out modulatedLight;
            }
            then assign opticalOutput := modulateData.modulatedLight;
        }
    }
    
    part def FiberCore {
        attribute coreRefractiveIndex : RefractiveIndex;
        attribute coreDiameter : LengthValue;
        attribute coreMaterial : String;
    }
    
    part def FiberCladding {
        attribute claddingRefractiveIndex : RefractiveIndex;
        attribute claddingDiameter : LengthValue;
        attribute claddingMaterial : String;
    }
    
    part def OpticalFiber {
        attribute fiberLength : LengthValue;
        attribute totalAttenuation : AttenuationCoefficient;
        attribute numericalAperture : NumericalAperture;
        attribute dispersion : Real;
        
        port inputPort : OpticalPort;
        port outputPort : OpticalPort;
        
        part core : FiberCore {
            attribute coreRefractiveIndex = 1.468;
            attribute coreDiameter = 9.0[m] * 1.0e-6;
            attribute coreMaterial = "Silica";
        }
        
        part cladding : FiberCladding {
            attribute claddingRefractiveIndex = 1.458;
            attribute claddingDiameter = 125.0[m] * 1.0e-6;
            attribute claddingMaterial = "Doped Silica";
        }
        
        action propagate : PropagateLight {
            in item inputLight : OpticalSignal;
            in fiberLength : LengthValue;
            in attenuationRate : AttenuationCoefficient;
            out item outputLight : OpticalSignal;
            
            first action acceptInput accept incomingLight : OpticalSignal;
            then action guideThroughCore {
                in light : OpticalSignal = acceptInput.incomingLight;
                out guidedLight : OpticalSignal;
            }
            then action applyAttenuation {
                in light : OpticalSignal = guideThroughCore.guidedLight;
                out attenuatedLight : OpticalSignal;
            }
            then action compensateDispersion {
                in light : OpticalSignal = applyAttenuation.attenuatedLight;
                out compensatedLight : OpticalSignal;
            }
            then assign outputLight := compensateDispersion.compensatedLight;
        }
    }
    
    part def Photodetector {
        attribute responsivity : Real;
        attribute detectionBandwidth : FrequencyValue;
        
        action detectLight {
            in opticalInput : OpticalSignal;
            out photocurrent : ElectricCurrentValue;
        }
    }
    
    part def SignalAmplifier {
        attribute gain : Real;
        attribute noiseFigure : Real;
        
        action amplifySignal {
            in weakSignal : ElectricalSignal;
            out amplifiedSignal : ElectricalSignal;
        }
    }
    
    part def OpticalReceiver {
        port opticalInput : OpticalPort;
        port electricalOutput : ElectricalPort;
        
        part detector : Photodetector {
            attribute responsivity = 0.85;
            attribute detectionBandwidth = 10.0[Hz] * 1.0e9;
        }
        
        part amplifier : SignalAmplifier {
            attribute gain = 20.0;
            attribute noiseFigure = 3.0;
        }
        
        action receive : ConvertOpticalToElectrical {
            in item opticalInput : OpticalSignal;
            out item electricalOutput : ElectricalSignal;
            
            first action acceptInput accept incomingLight : OpticalSignal;
            then action detect : detector.detectLight {
                in opticalInput = acceptInput.incomingLight;
                out photocurrent;
            }
            then action amplify : amplifier.amplifySignal {
                in weakSignal;
                out amplifiedSignal;
            }
            then assign electricalOutput := amplify.amplifiedSignal;
        }
    }
    
    state def TransmissionStates {
        entry; then idle;
        
        state idle {
            entry action initializeSystem;
        }
        
        transition idle_to_active
            first idle
            accept startTransmission
            then active;
        
        state active {
            entry action beginTransmission;
            do action monitorSignalQuality;
            
            state normalOperation;
            state degradedOperation;
            
            transition normal_to_degraded
                first normalOperation
                if signalQualityLow
                then degradedOperation;
            
            transition degraded_to_normal
                first degradedOperation
                if signalQualityRestored
                then normalOperation;
        }
        
        transition active_to_idle
            first active
            accept stopTransmission
            then idle;
    }
    
    requirement def TransmissionPerformanceRequirement {
        doc /* The optical fiber system shall transmit data with high fidelity and minimal signal degradation. */
        
        attribute maxAttenuation : AttenuationCoefficient;
        attribute minBandwidth : FrequencyValue;
        attribute maxBitErrorRate : BitErrorRate;
        
        require constraint attenuationLimit {
            maxAttenuation <= 0.25
        }
        
        require constraint bandwidthRequirement {
            minBandwidth >= 10.0[Hz] * 1.0e9
        }
        
        require constraint errorRateLimit {
            maxBitErrorRate <= 1.0e-12
        }
    }
    
    requirement def SignalIntegrityRequirement {
        doc /* The system shall maintain signal integrity throughout the transmission path. */
        
        attribute minSignalToNoiseRatio : SignalToNoiseRatio;
        
        require constraint snrRequirement {
            minSignalToNoiseRatio >= 20.0
        }
    }
    
    requirement def ReliabilityRequirement {
        doc /* The optical fiber system shall operate reliably under specified environmental conditions. */
        
        assume constraint operatingTemperature {
            ambientTemperature >= -40.0[K] + 233.15[K] and ambientTemperature <= 85.0[K] + 188.15[K]
        }
        
        assume constraint operatingHumidity {
            relativeHumidity <= 95.0
        }
    }
    
    part opticalFiberSystem {
        doc /* 
            This system describes an optical fiber communication system designed to transmit 
            digital data over long distances using modulated light signals. The system's primary 
            function is to convert electrical data signals into optical signals, transmit them 
            through an optical fiber with minimal loss and distortion, and convert them back to 
            electrical signals at the receiving end.
            
            The optical fiber uses total internal reflection to guide light through its core, 
            enabling high-bandwidth, low-loss transmission of information encoded in light pulses. 
            This technology is fundamental to modern telecommunications infrastructure, providing 
            the backbone for internet, telephone, and data networks worldwide.
        */
        
        port dataInput : ElectricalPort;
        port dataOutput : ElectricalPort;
        
        part transmitter : OpticalTransmitter;
        
        part fiber : OpticalFiber {
            attribute fiberLength = 20.0[km];
            attribute totalAttenuation = 0.20;
            attribute numericalAperture = 0.13;
            attribute dispersion = 17.0;
        }
        
        part receiver : OpticalReceiver;
        
        connect dataInput to transmitter.electricalInput;
        connect transmitter.opticalOutput to fiber.inputPort;
        connect fiber.outputPort to receiver.opticalInput;
        connect receiver.electricalOutput to dataOutput;
        
        action communicateData {
            doc /* 
                Primary system function: transmit data from input to output through optical conversion,
                fiber propagation, and optical-to-electrical reconversion.
            */
            
            first start;
            then merge continuousTransmission;
            
            then action acceptData accept inputData : ElectricalSignal;
            
            then action convertToOptical : transmitter.transmit {
                in item electricalInput = acceptData.inputData;
                out item opticalOutput;
            }
            
            flow from convertToOptical.opticalOutput to propagateThroughFiber.inputLight;
            
            then action propagateThroughFiber : fiber.propagate {
                in item inputLight;
                in fiberLength = fiber.fiberLength;
                in attenuationRate = fiber.totalAttenuation;
                out item outputLight;
            }
            
            flow from propagateThroughFiber.outputLight to convertToElectrical.opticalInput;
            
            then action convertToElectrical : receiver.receive {
                in item opticalInput;
                out item electricalOutput;
            }
            
            then action evaluateQuality {
                in signal : ElectricalSignal = convertToElectrical.electricalOutput;
                out qualityMetric : SignalToNoiseRatio;
            }
            
            then decide;
                if evaluateQuality.qualityMetric >= 20.0 then deliverData;
                if evaluateQuality.qualityMetric < 20.0 then handleError;
            
            action deliverData {
                then assign dataOutput.outputSignal := convertToElectrical.electricalOutput;
            }
            then continuousTransmission;
            
            action handleError {
                action logError;
                then action requestRetransmission;
            }
            then continuousTransmission;
        }
        
        requirement performanceReq : TransmissionPerformanceRequirement {
            attribute maxAttenuation = 0.25;
            attribute minBandwidth = 10.0[Hz] * 1.0e9;
            attribute maxBitErrorRate = 1.0e-12;
            
            assume constraint fiberQuality {
                fiber.totalAttenuation <= maxAttenuation
            }
        }
        
        requirement signalIntegrityReq : SignalIntegrityRequirement {
            attribute minSignalToNoiseRatio = 20.0;
        }
        
        requirement reliabilityReq : ReliabilityRequirement;
    }
}
