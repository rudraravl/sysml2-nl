package 'Sound Locator System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def AzimuthAngle :> ISQ::planeAngleValue {
        doc /* Horizontal angle measured from reference direction (0-360 degrees) */
    }
    
    attribute def ElevationAngle :> ISQ::planeAngleValue {
        doc /* Vertical angle measured from horizontal plane (-90 to +90 degrees) */
    }
    
    attribute def SoundIntensityLevel :> Real {
        doc /* Sound pressure level in decibels (dB SPL) */
    }
    
    attribute def TimeDifferenceOfArrival :> ISQ::TimeValue {
        doc /* Time delay between signal arrivals at different microphones */
    }
    
    item def AcousticSignal {
        attribute timestamp : ISQ::TimeValue;
        attribute amplitude : Real;
        attribute frequency : ISQ::FrequencyValue;
        attribute phase : ISQ::planeAngleValue;
    }
    
    item def SoundSourceLocation {
        attribute azimuth : AzimuthAngle;
        attribute elevation : ElevationAngle;
        attribute distance : ISQ::LengthValue;
        attribute intensity : SoundIntensityLevel;
        attribute confidence : Real;
    }
    
    item def MicrophonePosition {
        attribute x : ISQ::LengthValue;
        attribute y : ISQ::LengthValue;
        attribute z : ISQ::LengthValue;
    }
    
    port def AcousticInputPort {
        in signal : AcousticSignal;
    }
    
    port def LocationDataPort {
        out location : SoundSourceLocation;
    }
    
    port def PowerPort {
        in voltage : ISQ::VoltageValue;
        in current : ISQ::ElectricCurrentValue;
    }
    
    part def Microphone {
        doc /* Transducer converting acoustic pressure waves to electrical signals */
        
        attribute sensitivity : Real;
        attribute frequencyResponse : ISQ::FrequencyValue[2];
        attribute position : MicrophonePosition;
        
        port power : PowerPort;
        port acousticOutput : ~AcousticInputPort;
    }
    
    part def MicrophoneArray {
        doc /* Spatially distributed array of microphones for directional sensing */
        
        attribute arrayGeometry : String;
        attribute baselineDistance : ISQ::LengthValue;
        
        part mic1 : Microphone {
            attribute :>> position = MicrophonePosition {
                attribute :>> x = 0.0[SI::m];
                attribute :>> y = 0.0[SI::m];
                attribute :>> z = 0.0[SI::m];
            }
        }
        
        part mic2 : Microphone {
            attribute :>> position = MicrophonePosition {
                attribute :>> x = 0.5[SI::m];
                attribute :>> y = 0.0[SI::m];
                attribute :>> z = 0.0[SI::m];
            }
        }
        
        part mic3 : Microphone {
            attribute :>> position = MicrophonePosition {
                attribute :>> x = 0.0[SI::m];
                attribute :>> y = 0.5[SI::m];
                attribute :>> z = 0.0[SI::m];
            }
        }
        
        part mic4 : Microphone {
            attribute :>> position = MicrophonePosition {
                attribute :>> x = 0.0[SI::m];
                attribute :>> y = 0.0[SI::m];
                attribute :>> z = 0.5[SI::m];
            }
        }
        
        port power : PowerPort;
    }
    
    part def SignalConditioner {
        doc /* Amplifies, filters, and digitizes microphone signals */
        
        attribute gain : Real;
        attribute filterCutoffLow : ISQ::FrequencyValue;
        attribute filterCutoffHigh : ISQ::FrequencyValue;
        attribute samplingRate : ISQ::FrequencyValue;
        
        port power : PowerPort;
        port signalIn1 : AcousticInputPort;
        port signalIn2 : AcousticInputPort;
        port signalIn3 : AcousticInputPort;
        port signalIn4 : AcousticInputPort;
        port conditionedOut1 : ~AcousticInputPort;
        port conditionedOut2 : ~AcousticInputPort;
        port conditionedOut3 : ~AcousticInputPort;
        port conditionedOut4 : ~AcousticInputPort;
    }
    
    part def DigitalSignalProcessor {
        doc /* Computes time delays and triangulates sound source position */
        
        attribute processingSpeed : ISQ::FrequencyValue;
        attribute algorithmType : String;
        
        port power : PowerPort;
        port dataIn1 : AcousticInputPort;
        port dataIn2 : AcousticInputPort;
        port dataIn3 : AcousticInputPort;
        port dataIn4 : AcousticInputPort;
        port locationOut : LocationDataPort;
        
        attribute micPositions : MicrophonePosition[4];
    }
    
    part def DisplayUnit {
        doc /* Visualizes computed sound source direction and distance */
        
        attribute displayType : String;
        attribute updateRate : ISQ::FrequencyValue;
        
        port power : PowerPort;
        port locationIn : ~LocationDataPort;
        
        attribute currentLocation : SoundSourceLocation;
    }
    
    part def PowerSupply {
        doc /* Provides regulated power to all system components */
        
        attribute inputVoltage : ISQ::VoltageValue;
        attribute outputVoltage : ISQ::VoltageValue;
        attribute maxCurrent : ISQ::ElectricCurrentValue;
        
        port powerOut : ~PowerPort;
    }
    
    action def CaptureAcousticSignals {
        doc /* Simultaneously capture sound at all microphone positions */
        
        in micPosition1 : MicrophonePosition;
        in micPosition2 : MicrophonePosition;
        in micPosition3 : MicrophonePosition;
        in micPosition4 : MicrophonePosition;
        
        out signal1 : AcousticSignal;
        out signal2 : AcousticSignal;
        out signal3 : AcousticSignal;
        out signal4 : AcousticSignal;
    }
    
    action def ConditionSignals {
        doc /* Filter and amplify raw microphone signals */
        
        in rawSignal1 : AcousticSignal;
        in rawSignal2 : AcousticSignal;
        in rawSignal3 : AcousticSignal;
        in rawSignal4 : AcousticSignal;
        
        out conditionedSignal1 : AcousticSignal;
        out conditionedSignal2 : AcousticSignal;
        out conditionedSignal3 : AcousticSignal;
        out conditionedSignal4 : AcousticSignal;
    }
    
    action def ComputeTimeDifferences {
        doc /* Calculate TDOA between microphone pairs using cross-correlation */
        
        in signal1 : AcousticSignal;
        in signal2 : AcousticSignal;
        in signal3 : AcousticSignal;
        in signal4 : AcousticSignal;
        
        out tdoa12 : TimeDifferenceOfArrival;
        out tdoa13 : TimeDifferenceOfArrival;
        out tdoa14 : TimeDifferenceOfArrival;
        out tdoa23 : TimeDifferenceOfArrival;
        out tdoa24 : TimeDifferenceOfArrival;
        out tdoa34 : TimeDifferenceOfArrival;
    }
    
    action def TriangulatePosition {
        doc /* Compute 3D position from time differences and microphone geometry */
        
        in tdoa12 : TimeDifferenceOfArrival;
        in tdoa13 : TimeDifferenceOfArrival;
        in tdoa14 : TimeDifferenceOfArrival;
        in tdoa23 : TimeDifferenceOfArrival;
        in tdoa24 : TimeDifferenceOfArrival;
        in tdoa34 : TimeDifferenceOfArrival;
        in micPositions : MicrophonePosition[4];
        
        out location : SoundSourceLocation;
    }
    
    action def ValidateLocation {
        doc /* Check if computed location meets quality criteria */
        
        in location : SoundSourceLocation;
        out isValid : Boolean;
    }
    
    action def UpdateDisplay {
        doc /* Render location information on display unit */
        
        in location : SoundSourceLocation;
    }
    
    action def LocateSound {
        doc /* 
        Primary system function: Continuously detect and locate sound sources in 3D space.
        Uses time difference of arrival (TDOA) technique with multiple microphones to 
        triangulate the position of acoustic events in real-time.
        */
        
        first start;
        then merge continuousMonitoring;
        
        then action capture : CaptureAcousticSignals {
            in micPosition1;
            in micPosition2;
            in micPosition3;
            in micPosition4;
            out signal1;
            out signal2;
            out signal3;
            out signal4;
        }
        
        then action condition : ConditionSignals {
            in rawSignal1 = capture.signal1;
            in rawSignal2 = capture.signal2;
            in rawSignal3 = capture.signal3;
            in rawSignal4 = capture.signal4;
            out conditionedSignal1;
            out conditionedSignal2;
            out conditionedSignal3;
            out conditionedSignal4;
        }
        
        then action computeTDOA : ComputeTimeDifferences {
            in signal1 = condition.conditionedSignal1;
            in signal2 = condition.conditionedSignal2;
            in signal3 = condition.conditionedSignal3;
            in signal4 = condition.conditionedSignal4;
            out tdoa12;
            out tdoa13;
            out tdoa14;
            out tdoa23;
            out tdoa24;
            out tdoa34;
        }
        
        then action triangulate : TriangulatePosition {
            in tdoa12 = computeTDOA.tdoa12;
            in tdoa13 = computeTDOA.tdoa13;
            in tdoa14 = computeTDOA.tdoa14;
            in tdoa23 = computeTDOA.tdoa23;
            in tdoa24 = computeTDOA.tdoa24;
            in tdoa34 = computeTDOA.tdoa34;
            in micPositions;
            out soundLocation : SoundSourceLocation;
        }
        
        then action validate : ValidateLocation {
            in location = triangulate.soundLocation;
            out isValid;
        }
        
        then decide;
            if validate.isValid then displayLocation;
            if not validate.isValid then continuousMonitoring;
        
        action displayLocation : UpdateDisplay {
            in location = triangulate.soundLocation;
        }
        
        then continuousMonitoring;
    }
    
    part def SoundLocatorSystem {
        doc /* 
        A sound locator system that detects and determines the spatial location of 
        sound sources in three-dimensional space using an array of microphones and 
        time difference of arrival (TDOA) processing techniques.
        */
        
        attribute operatingFrequencyRange : ISQ::FrequencyValue[2];
        attribute maxDetectionRange : ISQ::LengthValue;
        attribute angularResolution : ISQ::planeAngleValue;
        attribute locationAccuracy : ISQ::LengthValue;
        attribute updateRate : ISQ::FrequencyValue;
        
        part micArray : MicrophoneArray {
            attribute :>> arrayGeometry = "tetrahedral";
            attribute :>> baselineDistance = 0.5[SI::m];
        }
        
        part conditioner : SignalConditioner {
            attribute :>> gain = 40.0;
            attribute :>> filterCutoffLow = 100.0[SI::Hz];
            attribute :>> filterCutoffHigh = 10000.0[SI::Hz];
            attribute :>> samplingRate = 48000.0[SI::Hz];
        }
        
        part processor : DigitalSignalProcessor {
            attribute :>> processingSpeed = 1000000000.0[SI::Hz];
            attribute :>> algorithmType = "GCC-PHAT";
        }
        
        part display : DisplayUnit {
            attribute :>> displayType = "LED matrix";
            attribute :>> updateRate = 10.0[SI::Hz];
        }
        
        part power : PowerSupply {
            attribute :>> inputVoltage = 12.0[SI::V];
            attribute :>> outputVoltage = 5.0[SI::V];
            attribute :>> maxCurrent = 3.0[SI::A];
        }
        
        connection powerToArray connect power.powerOut to micArray.power;
        connection powerToConditioner connect power.powerOut to conditioner.power;
        connection powerToProcessor connect power.powerOut to processor.power;
        connection powerToDisplay connect power.powerOut to display.power;
        
        connection mic1ToConditioner connect micArray.mic1.acousticOutput to conditioner.signalIn1;
        connection mic2ToConditioner connect micArray.mic2.acousticOutput to conditioner.signalIn2;
        connection mic3ToConditioner connect micArray.mic3.acousticOutput to conditioner.signalIn3;
        connection mic4ToConditioner connect micArray.mic4.acousticOutput to conditioner.signalIn4;
        
        connection conditionerToProcessor1 connect conditioner.conditionedOut1 to processor.dataIn1;
        connection conditionerToProcessor2 connect conditioner.conditionedOut2 to processor.dataIn2;
        connection conditionerToProcessor3 connect conditioner.conditionedOut3 to processor.dataIn3;
        connection conditionerToProcessor4 connect conditioner.conditionedOut4 to processor.dataIn4;
        
        connection processorToDisplay connect processor.locationOut to display.locationIn;
        
        perform action locateSound : LocateSound;
    }
    
    requirement def AccuracyRequirement {
        doc /* The system shall locate sound sources with specified spatial accuracy */
        
        subject system : SoundLocatorSystem;
        
        require constraint {
            system.locationAccuracy <= 0.3[SI::m]
        }
    }
    
    requirement def RangeRequirement {
        doc /* The system shall detect and locate sound sources within specified range */
        
        subject system : SoundLocatorSystem;
        
        require constraint {
            system.maxDetectionRange >= 50.0[SI::m]
        }
    }
    
    requirement def FrequencyRangeRequirement {
        doc /* The system shall operate across specified acoustic frequency range */
        
        subject system : SoundLocatorSystem;
        
        require constraint {
            system.operatingFrequencyRange[1] >= 100.0[SI::Hz] and
            system.operatingFrequencyRange[2] <= 10000.0[SI::Hz]
        }
    }
    
    requirement def AngularResolutionRequirement {
        doc /* The system shall resolve sound source direction with specified angular precision */
        
        subject system : SoundLocatorSystem;
        
        require constraint {
            system.angularResolution <= 0.0873[SI::'rad']
        }
    }
    
    requirement def UpdateRateRequirement {
        doc /* The system shall update location estimates at specified minimum rate */
        
        subject system : SoundLocatorSystem;
        
        require constraint {
            system.updateRate >= 5.0[SI::Hz]
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for sound locator system performance */
        
        require AccuracyRequirement;
        require RangeRequirement;
        require FrequencyRangeRequirement;
        require AngularResolutionRequirement;
        require UpdateRateRequirement;
    }
    
    part soundLocator : SoundLocatorSystem {
        attribute :>> operatingFrequencyRange = (100.0[SI::Hz], 10000.0[SI::Hz]);
        attribute :>> maxDetectionRange = 50.0[SI::m];
        attribute :>> angularResolution = 0.0524[SI::'rad'];
        attribute :>> locationAccuracy = 0.25[SI::m];
        attribute :>> updateRate = 10.0[SI::Hz];
    }
}
