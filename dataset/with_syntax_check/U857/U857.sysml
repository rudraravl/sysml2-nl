package 'Rotary Encoder System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def EncoderResolution {
        attribute pulsesPerRevolution : Integer;
        attribute degreesPerPulse : Real;
    }
    
    attribute def QuadratureState {
        attribute channelA : Boolean;
        attribute channelB : Boolean;
        attribute indexPulse : Boolean;
    }
    
    item def MechanicalShaft {
        attribute angularPosition : AngleValue;
        attribute angularVelocity : AngularSpeedValue;
        attribute torque : TorqueValue;
    }
    
    item def OpticalDisk {
        attribute slotCount : Integer;
        attribute hasIndexTrack : Boolean;
    }
    
    item def PhotosensorPair {
        attribute channelAOutput : Boolean;
        attribute channelBOutput : Boolean;
    }
    
    item def IndexSensor {
        attribute indexOutput : Boolean;
    }
    
    port def MechanicalInputPort {
        in shaftAngle : AngleValue;
        in shaftVelocity : AngularSpeedValue;
    }
    
    port def QuadratureOutputPort {
        out channelA : Boolean;
        out channelB : Boolean;
        out index : Boolean;
    }
    
    port def PositionDataPort {
        out absolutePosition : AngleValue;
        out relativePosition : Integer;
        out velocity : AngularSpeedValue;
        out direction : Boolean;
    }
    
    part def RotaryEncoder {
        doc /* 
            A rotary encoder is an electromechanical device that converts angular position 
            or motion of a shaft into analog or digital output signals. This encoder uses 
            quadrature encoding with two phase-shifted output channels and an index pulse.
        */
        
        attribute resolution : EncoderResolution {
            attribute pulsesPerRevolution = 2048;
            attribute degreesPerPulse = 360.0 / 2048.0;
        }
        
        port mechanicalInput : MechanicalInputPort;
        port quadratureOutput : QuadratureOutputPort;
        
        part shaft : MechanicalShaft {
            attribute angularPosition : AngleValue;
            attribute angularVelocity : AngularSpeedValue;
        }
        
        part codeDisk : OpticalDisk {
            attribute slotCount = resolution.pulsesPerRevolution;
            attribute hasIndexTrack = true;
        }
        
        part quadratureSensors : PhotosensorPair {
            attribute channelAOutput : Boolean;
            attribute channelBOutput : Boolean;
        }
        
        part indexSensor : IndexSensor {
            attribute indexOutput : Boolean;
        }
        
        connection shaftToDisk connect shaft to codeDisk;
        connection diskToSensors connect codeDisk to quadratureSensors;
        connection diskToIndex connect codeDisk to indexSensor;
    }
    
    part def SignalProcessor {
        doc /* 
            Processes quadrature signals to determine position, direction, and velocity.
        */
        
        port quadratureInput : QuadratureOutputPort;
        port dataOutput : PositionDataPort;
        
        attribute pulseCounter : Integer = 0;
        attribute previousChannelA : Boolean = false;
        attribute previousChannelB : Boolean = false;
        attribute clockwiseRotation : Boolean = true;
    }
    
    action def GenerateQuadratureSignals {
        in shaftAngle : AngleValue;
        in pulsesPerRev : Integer;
        out channelA : Boolean;
        out channelB : Boolean;
        out index : Boolean;
    }
    
    action def DecodeQuadratureSignals {
        in currentChannelA : Boolean;
        in currentChannelB : Boolean;
        in priorChannelA : Boolean;
        in priorChannelB : Boolean;
        out rotationDirection : Boolean;
        out incrementDetected : Boolean;
        
        first start;
        then decide;
            if (currentChannelA != priorChannelA) or (currentChannelB != priorChannelB) then detectTransition;
            else noChange;
        
        action detectTransition {
            then decide;
                if (priorChannelA == false and currentChannelA == true and currentChannelB == false) then clockwise;
                if (priorChannelA == true and currentChannelA == false and currentChannelB == true) then clockwise;
                if (priorChannelB == false and currentChannelB == true and currentChannelA == true) then clockwise;
                if (priorChannelB == true and currentChannelB == false and currentChannelA == false) then clockwise;
                else counterClockwise;
        }
        
        action clockwise {
            then assign rotationDirection := true;
            then assign incrementDetected := true;
        }
        then done;
        
        action counterClockwise {
            then assign rotationDirection := false;
            then assign incrementDetected := true;
        }
        then done;
        
        action noChange {
            then assign incrementDetected := false;
        }
        then done;
    }
    
    action def UpdatePositionCounter {
        in increment : Boolean;
        in direction : Boolean;
        inout counter : Integer;
        
        first start;
        then decide;
            if increment and direction then incrementCounter;
            if increment and not direction then decrementCounter;
            else maintainCounter;
        
        action incrementCounter {
            then assign counter := counter + 1;
        }
        then done;
        
        action decrementCounter {
            then assign counter := counter - 1;
        }
        then done;
        
        action maintainCounter;
        then done;
    }
    
    action def CalculateAbsolutePosition {
        in pulseCount : Integer;
        in pulsesPerRevolution : Integer;
        out absoluteAngle : AngleValue;
    }
    
    action def CalculateAngularVelocity {
        in currentPosition : AngleValue;
        in previousPosition : AngleValue;
        in timeInterval : TimeValue;
        out velocity : AngularSpeedValue;
    }
    
    action def ProcessEncoderSignals {
        in channelASignal : Boolean;
        in channelBSignal : Boolean;
        in indexSignal : Boolean;
        in encoderResolution : EncoderResolution;
        out position : AngleValue;
        out velocity : AngularSpeedValue;
        out direction : Boolean;
        out pulseCount : Integer;
        
        private attribute previousA : Boolean := false;
        private attribute previousB : Boolean := false;
        private attribute counter : Integer := 0;
        private attribute lastPosition : AngleValue := AngleValue(0.0, SI::deg);
        private attribute lastTime : TimeValue := TimeValue(0.0, SI::s);
        
        first start;
        then merge continuousProcessing;
        
        then action decode : DecodeQuadratureSignals {
            in currentChannelA = channelASignal;
            in currentChannelB = channelBSignal;
            in priorChannelA = previousA;
            in priorChannelB = previousB;
            out rotationDirection;
            out incrementDetected;
        }
        
        then action updateCounter : UpdatePositionCounter {
            in increment = decode.incrementDetected;
            in direction = decode.rotationDirection;
            inout counter = counter;
        }
        
        then action calculatePosition : CalculateAbsolutePosition {
            in pulseCount = counter;
            in pulsesPerRevolution = encoderResolution.pulsesPerRevolution;
            out absoluteAngle;
        }
        
        then action calculateVelocity : CalculateAngularVelocity {
            in currentPosition = calculatePosition.absoluteAngle;
            in previousPosition = lastPosition;
            in timeInterval = TimeValue(0.001, SI::s);
            out velocity;
        }
        
        then decide;
            if indexSignal then resetCounter;
            else updateOutputs;
        
        action resetCounter {
            then assign counter := 0;
        }
        then updateOutputs;
        
        action updateOutputs {
            then assign position := calculatePosition.absoluteAngle;
            then assign velocity := calculateVelocity.velocity;
            then assign direction := decode.rotationDirection;
            then assign pulseCount := counter;
            then assign previousA := channelASignal;
            then assign previousB := channelBSignal;
            then assign lastPosition := calculatePosition.absoluteAngle;
        }
        
        then continuousProcessing;
    }
    
    part def RotaryEncoderSystem {
        doc /* 
            The Rotary Encoder System converts mechanical shaft rotation into precise 
            digital position and velocity measurements. The system uses quadrature encoding 
            to detect both magnitude and direction of rotation, providing high-resolution 
            angular position feedback for motion control applications.
        */
        
        part encoder : RotaryEncoder;
        part processor : SignalProcessor;
        
        port mechanicalInterface : MechanicalInputPort;
        port digitalOutput : PositionDataPort;
        
        connection mechanicalToEncoder connect mechanicalInterface to encoder.mechanicalInput;
        connection encoderToProcessor connect encoder.quadratureOutput to processor.quadratureInput;
        connection processorToOutput connect processor.dataOutput to digitalOutput;
    }
    
    part rotaryEncoderSystem : RotaryEncoderSystem {
        perform action processSignals : ProcessEncoderSignals {
            in channelASignal = encoder.quadratureOutput.channelA;
            in channelBSignal = encoder.quadratureOutput.channelB;
            in indexSignal = encoder.quadratureOutput.index;
            in encoderResolution = encoder.resolution;
            out position;
            out velocity;
            out direction;
            out pulseCount;
        }
        
        bind processSignals.position = digitalOutput.absolutePosition;
        bind processSignals.velocity = digitalOutput.velocity;
        bind processSignals.direction = digitalOutput.direction;
        bind processSignals.pulseCount = digitalOutput.relativePosition;
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def AccuracyRequirement;
    
    requirement <'REQ-001'> primaryFunction : FunctionalRequirement {
        doc /* 
            The Rotary Encoder System shall convert mechanical shaft rotation into 
            digital signals representing angular position, velocity, and direction of rotation.
        */
    }
    
    requirement <'REQ-002'> resolutionRequirement : PerformanceRequirement {
        doc /* 
            The encoder shall provide a minimum resolution of 2048 pulses per revolution 
            to ensure adequate position measurement granularity.
        */
    }
    
    requirement <'REQ-003'> accuracyRequirement : AccuracyRequirement {
        doc /* 
            The system shall maintain position accuracy within ±0.18 degrees over 
            the full range of operation.
        */
    }
    
    requirement <'REQ-004'> responseTimeRequirement : PerformanceRequirement {
        doc /* 
            The signal processor shall update position and velocity outputs within 
            1 millisecond of detecting a quadrature state change.
        */
    }
    
    requirement <'REQ-005'> directionDetectionRequirement : FunctionalRequirement {
        doc /* 
            The system shall accurately detect and report the direction of shaft rotation 
            using quadrature signal phase relationship.
        */
        require primaryFunction;
    }
    
    requirement <'REQ-006'> indexPulseRequirement : FunctionalRequirement {
        doc /* 
            The encoder shall provide an index pulse once per revolution to enable 
            absolute position reference and counter reset capability.
        */
    }
    
    requirement systemRequirements {
        doc /* 
            Top-level requirements for the Rotary Encoder System encompassing 
            functional capabilities and performance specifications.
        */
        require primaryFunction;
        require resolutionRequirement;
        require accuracyRequirement;
        require responseTimeRequirement;
        require directionDetectionRequirement;
        require indexPulseRequirement;
    }
}
