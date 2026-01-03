package SphygmographSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PulseRate :> ISQ::FrequencyValue;
    
    attribute def WaveformAmplitude :> ISQ::LengthValue;
    
    item def PulseWaveform {
        attribute timePoints : ISQ::TimeValue[*] ordered;
        attribute amplitudes : ISQ::LengthValue[*] ordered;
        attribute frequency : PulseRate;
    }
    
    item def MechanicalSignal {
        attribute displacement : ISQ::LengthValue;
        attribute force : ISQ::ForceValue;
    }
    
    port def SensorPort {
        out arterialPulse : MechanicalSignal;
    }
    
    port def AmplifierPort {
        in inputSignal : MechanicalSignal;
        out amplifiedSignal : MechanicalSignal;
    }
    
    port def RecorderPort {
        in mechanicalInput : MechanicalSignal;
        out tracedWaveform : PulseWaveform;
    }
    
    part def PulseSensor {
        doc /* Detects arterial pulse through mechanical contact with skin surface */
        
        attribute contactForce : ISQ::ForceValue;
        attribute sensitivity : Real;
        
        port output : SensorPort;
        
        action detectArterialPulse {
            in appliedForce : ISQ::ForceValue;
            out pulseSignal : MechanicalSignal;
        }
    }
    
    part def LeverAmplifier {
        doc /* Mechanical lever system that amplifies small arterial movements */
        
        attribute leverRatio : Real;
        attribute fulcrumPosition : ISQ::LengthValue;
        
        port input : AmplifierPort;
        port output : AmplifierPort;
        
        action amplifyMovement {
            in inputDisplacement : ISQ::LengthValue;
            in ratio : Real;
            out outputDisplacement : ISQ::LengthValue;
        }
    }
    
    part def RotatingDrum {
        doc /* Cylindrical drum covered with paper that rotates at constant speed */
        
        attribute rotationSpeed : ISQ::AngularVelocityValue;
        attribute drumDiameter : ISQ::LengthValue;
        attribute paperLength : ISQ::LengthValue;
        
        action rotateDrum {
            in speed : ISQ::AngularVelocityValue;
            in duration : ISQ::TimeValue;
            out distanceTraveled : ISQ::LengthValue;
        }
    }
    
    part def StylusAssembly {
        doc /* Writing stylus that traces waveform onto moving paper */
        
        attribute stylusPosition : ISQ::LengthValue;
        attribute inkFlow : Boolean;
        
        port mechanicalInput : RecorderPort;
        
        action traceWaveform {
            in verticalMovement : MechanicalSignal;
            in drumRotation : ISQ::AngularVelocityValue;
            out waveformTrace : PulseWaveform;
        }
    }
    
    part def CalibrationScale {
        doc /* Reference scale for measuring waveform amplitude and timing */
        
        attribute timeMarkInterval : ISQ::TimeValue;
        attribute amplitudeScale : ISQ::LengthValue;
    }
    
    action def RecordPulseWaveform {
        doc /* Primary function: continuously record arterial pulse as graphical trace */
        
        in sensorContact : ISQ::ForceValue;
        in recordingDuration : ISQ::TimeValue;
        out pulseRecord : PulseWaveform;
        out averagePulseRate : PulseRate;
    }
    
    attribute def StartCommand;
    attribute def ResetCommand;
    
    action def prepareDrum;
    action def positionSensor;
    
    part def Sphygmograph {
        doc /* 
            A sphygmograph is a mechanical instrument that records arterial pulse waveforms.
            Its primary function is to detect pressure variations in arteries through skin contact,
            mechanically amplify these small movements, and trace them onto a rotating paper-covered
            drum to create a permanent graphical record showing pulse characteristics over time.
        */
        
        attribute isOperating : Boolean;
        attribute recordingSpeed : ISQ::AngularVelocityValue;
        
        part sensor : PulseSensor {
            attribute contactForce = 0.5[SI::N];
            attribute sensitivity = 0.9;
        }
        
        part amplifier : LeverAmplifier {
            attribute leverRatio = 20.0;
            attribute fulcrumPosition = 5.0[SI::mm];
        }
        
        part drum : RotatingDrum {
            attribute rotationSpeed = 25.0[SI::mm/SI::s];
            attribute drumDiameter = 100.0[SI::mm];
            attribute paperLength = 300.0[SI::mm];
        }
        
        part stylus : StylusAssembly {
            attribute inkFlow = true;
        }
        
        part calibration : CalibrationScale {
            attribute timeMarkInterval = 1.0[SI::s];
            attribute amplitudeScale = 1.0[SI::mm];
        }
        
        connection sensorToAmplifier connect 
            sensor.output.arterialPulse to 
            amplifier.input.inputSignal;
        
        connection amplifierToStylus connect 
            amplifier.output.amplifiedSignal to 
            stylus.mechanicalInput.mechanicalInput;
        
        perform action recordPulse : RecordPulseWaveform {
            in sensorContact = sensor.contactForce;
            in recordingDuration = 60.0[SI::s];
            out pulseRecord;
            out averagePulseRate;
        }
        
        state operationStates {
            entry; then idle;
            
            state idle {
                doc /* Instrument ready but not recording */
            }
            
            transition idle_to_setup
                first idle
                accept startCmd : StartCommand
                then setup;
            
            state setup {
                doc /* Positioning sensor and preparing drum */
                entry assign isOperating := false;
                do prepareDrum;
                do positionSensor;
            }
            
            transition setup_to_recording
                first setup
                if sensor.contactForce > 0.0[SI::N]
                then recording;
            
            state recording {
                doc /* Actively tracing pulse waveform */
                entry assign isOperating := true;
                do recordPulse;
                do drum.rotateDrum;
            }
            
            transition recording_to_complete
                first recording
                if recordPulse::recordingDuration >= 60.0[SI::s]
                then complete;
            
            state complete {
                doc /* Recording finished, waveform available for analysis */
                entry assign isOperating := false;
            }
            
            transition complete_to_idle
                first complete
                accept resetCmd : ResetCommand
                then idle;
        }
    }
    
    requirement def WaveformFidelity {
        doc /* System shall preserve arterial pulse waveform characteristics */
        
        require constraint fidelityConstraint {
            doc /* Mechanical amplification shall not distort pulse shape */
        }
    }
    
    requirement def TemporalResolution {
        doc /* System shall capture rapid pulse variations */
        
        require constraint resolutionConstraint {
            doc /* Recording resolution better than 20 milliseconds */
        }
    }
    
    requirement def AmplificationAccuracy {
        doc /* Mechanical amplification shall be consistent and linear */
        
        require constraint amplificationConstraint {
            doc /* Lever ratio variation less than 2% across operating range */
        }
    }
    
    requirement <'SPHYG-001'> primaryFunction {
        doc /* 
            The sphygmograph system shall continuously detect, amplify, and record
            arterial pulse waveforms as a permanent graphical trace, enabling
            visual analysis of pulse characteristics including rate, rhythm, and amplitude.
        */
        
        require waveformFidelity : WaveformFidelity;
        require temporalResolution : TemporalResolution;
        require amplificationAccuracy : AmplificationAccuracy;
        
        satisfy by sphygmograph : Sphygmograph;
    }
}
