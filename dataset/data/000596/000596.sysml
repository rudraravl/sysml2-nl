package 'Electromagnetic Diaphragm System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    doc /* 
     * This model describes an electromagnetic diaphragm system used for converting 
     * electrical signals into mechanical motion and acoustic output. The primary 
     * function is to transform alternating electrical current through a voice coil 
     * into controlled diaphragm displacement, which generates sound pressure waves 
     * or actuates mechanical loads. The system operates through electromagnetic 
     * interaction between a current-carrying coil and a permanent magnetic field, 
     * producing force that drives a flexible diaphragm against a restoring suspension.
     */
    
    attribute def VoltageValue :> ISQ::voltage;
    attribute def CurrentValue :> ISQ::current;
    attribute def ForceValue :> ISQ::force;
    attribute def DisplacementValue :> ISQ::length;
    attribute def VelocityValue :> ISQ::speed;
    attribute def FrequencyValue :> ISQ::frequency;
    attribute def PressureValue :> ISQ::pressure;
    attribute def ResistanceValue :> Real;
    attribute def InductanceValue :> Real;
    attribute def MassValue :> ISQ::mass;
    attribute def StiffnessValue :> Real;
    attribute def DampingValue :> Real;
    
    attribute def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute frequency : FrequencyValue;
    }
    
    attribute def MechanicalState {
        attribute displacement : DisplacementValue;
        attribute velocity : VelocityValue;
        attribute force : ForceValue;
    }
    
    attribute def AcousticOutput {
        attribute soundPressure : PressureValue;
        attribute frequency : FrequencyValue;
    }
    
    port def ElectricalInputPort {
        in signal : ElectricalSignal;
    }
    
    port def MechanicalOutputPort {
        out motion : MechanicalState;
    }
    
    port def AcousticOutputPort {
        out sound : AcousticOutput;
    }
    
    part def VoiceCoil {
        doc /* Conductive coil that carries electrical current and generates force in magnetic field */
        
        attribute resistance : ResistanceValue;
        attribute inductance : InductanceValue;
        attribute numberOfTurns : Real;
        attribute coilDiameter : ISQ::length;
        attribute wireGauge : Real;
        
        port electricalInput : ElectricalInputPort;
        
        action generateElectromagneticForce {
            in inputSignal : ElectricalSignal;
            in magneticFluxDensity : Real;
            out electromagneticForce : ForceValue;
        }
    }
    
    part def PermanentMagnet {
        doc /* Provides static magnetic field for electromagnetic interaction */
        
        attribute magneticFluxDensity : Real;
        attribute magnetGrade : String;
        attribute polarity : String;
        attribute geometry : String;
        
        action provideMagneticField {
            out staticField : Real;
        }
    }
    
    part def Diaphragm {
        doc /* Flexible membrane that converts force into displacement and radiates sound */
        
        attribute material : String;
        attribute thickness : ISQ::length;
        attribute effectiveDiameter : ISQ::length;
        attribute effectiveMass : MassValue;
        attribute effectiveArea : Real;
        
        port mechanicalInput : ForceValue;
        port mechanicalOutput : MechanicalOutputPort;
        port acousticOutput : AcousticOutputPort;
        
        action respondToForce {
            in appliedForce : ForceValue;
            in suspensionStiffness : StiffnessValue;
            in dampingCoefficient : DampingValue;
            out displacement : DisplacementValue;
            out velocity : VelocityValue;
        }
        
        action radiateSound {
            in diaphragmVelocity : VelocityValue;
            in effectiveArea : Real;
            out soundPressure : PressureValue;
        }
    }
    
    part def Suspension {
        doc /* Elastic support structure providing centering force and compliance */
        
        attribute stiffness : StiffnessValue;
        attribute mechanicalDamping : DampingValue;
        attribute linearExcursion : DisplacementValue;
        attribute material : String;
        
        action provideRestoringForce {
            in displacement : DisplacementValue;
            out restoringForce : ForceValue;
        }
        
        action provideDamping {
            in velocity : VelocityValue;
            out dampingForce : ForceValue;
        }
    }
    
    part def MagneticCircuit {
        doc /* Magnetic structure that concentrates and directs magnetic flux */
        
        attribute topPlate : String;
        attribute backPlate : String;
        attribute polePiece : String;
        attribute airGapWidth : ISQ::length;
        
        action concentrateFlux {
            in magneticSource : Real;
            out concentratedFlux : Real;
        }
    }
    
    part def Housing {
        doc /* Enclosure providing structural support and acoustic cavity */
        
        attribute material : String;
        attribute internalVolume : ISQ::volume;
        attribute ventingType : String;
        
        action containComponents;
        
        action formAcousticCavity {
            out backPressure : PressureValue;
        }
    }
    
    action def ConvertElectricalToMagnetic {
        in electricalInput : ElectricalSignal;
        in magneticField : Real;
        out magneticForce : ForceValue;
    }
    
    action def ConvertMagneticToMechanical {
        in magneticForce : ForceValue;
        in mass : MassValue;
        in stiffness : StiffnessValue;
        in damping : DampingValue;
        out mechanicalMotion : MechanicalState;
    }
    
    action def ConvertMechanicalToAcoustic {
        in mechanicalMotion : MechanicalState;
        in radiatingArea : Real;
        out acousticOutput : AcousticOutput;
    }
    
    part def ElectromagneticDiaphragmTransducer {
        doc /* Complete electromagnetic diaphragm transducer assembly */
        
        part voiceCoil : VoiceCoil {
            attribute resistance = 6.5;
            attribute inductance = 0.0004;
            attribute numberOfTurns = 120.0;
            attribute coilDiameter = 0.0254;
            attribute wireGauge = 32.0;
        }
        
        part permanentMagnet : PermanentMagnet {
            attribute magneticFluxDensity = 1.0;
            attribute magnetGrade = "N42";
            attribute polarity = "radial";
            attribute geometry = "ring";
        }
        
        part flexibleDiaphragm : Diaphragm {
            attribute material = "polypropylene";
            attribute thickness = 0.00015;
            attribute effectiveDiameter = 0.05;
            attribute effectiveMass = 0.0008;
            attribute effectiveArea = 0.00196;
        }
        
        part surroundSuspension : Suspension {
            attribute stiffness = 800.0;
            attribute mechanicalDamping = 1.2;
            attribute linearExcursion = 0.003;
            attribute material = "rubber";
        }
        
        part magneticCircuit : MagneticCircuit {
            attribute topPlate = "steel";
            attribute backPlate = "steel";
            attribute polePiece = "steel";
            attribute airGapWidth = 0.001;
        }
        
        part enclosure : Housing {
            attribute material = "ABS plastic";
            attribute internalVolume = 0.000008;
            attribute ventingType = "sealed";
        }
        
        port electricalInput : ElectricalInputPort;
        port mechanicalOutput : MechanicalOutputPort;
        port acousticOutput : AcousticOutputPort;
        
        connection electricalConnection connect electricalInput to voiceCoil.electricalInput;
        connection mechanicalConnection connect flexibleDiaphragm.mechanicalOutput to mechanicalOutput;
        connection acousticConnection connect flexibleDiaphragm.acousticOutput to acousticOutput;
    }
    
    action operateElectromagneticDiaphragm {
        doc /* 
         * Primary operational behavior: Convert electrical input signal into 
         * mechanical displacement and acoustic output through electromagnetic 
         * actuation. The process involves generating electromagnetic force, 
         * moving the diaphragm assembly, and radiating sound waves.
         */
        
        in inputSignal : ElectricalSignal;
        in magneticFieldStrength : Real;
        in diaphragmMass : MassValue;
        in suspensionStiffness : StiffnessValue;
        in suspensionDamping : DampingValue;
        in radiatingArea : Real;
        out mechanicalOutput : MechanicalState;
        out acousticOutput : AcousticOutput;
        
        first start;
        
        then action convertToMagnetic : ConvertElectricalToMagnetic {
            in electricalInput = inputSignal;
            in magneticField = magneticFieldStrength;
            out magneticForce : ForceValue;
        }
        
        flow convertToMagnetic.magneticForce to convertToMechanical.magneticForce;
        
        then action convertToMechanical : ConvertMagneticToMechanical {
            in magneticForce : ForceValue;
            in mass = diaphragmMass;
            in stiffness = suspensionStiffness;
            in damping = suspensionDamping;
            out mechanicalMotion : MechanicalState;
        }
        
        flow convertToMechanical.mechanicalMotion to convertToAcoustic.mechanicalMotion;
        
        then action convertToAcoustic : ConvertMechanicalToAcoustic {
            in mechanicalMotion : MechanicalState;
            in radiatingArea = radiatingArea;
            out acousticOutput : AcousticOutput;
        }
        
        then assign mechanicalOutput := convertToMechanical.mechanicalMotion;
        then assign acousticOutput := convertToAcoustic.acousticOutput;
        
        then done;
    }
    
    state def TransducerOperatingStates {
        doc /* State machine governing transducer operational modes */
        
        entry; then off;
        
        state off {
            doc /* Transducer is unpowered and inactive */
        }
        
        accept powerOn;
        then idle;
        
        state idle {
            doc /* Transducer is powered but not receiving input signal */
            entry action initializeSystem;
        }
        
        accept signalDetected : ElectricalSignal;
        then active;
        
        state active {
            doc /* Transducer is actively converting electrical signal */
            
            entry; then coilEnergized;
            
            state coilEnergized {
                doc /* Voice coil carrying current and generating force */
                entry action energizeCoil;
            }
            
            then diaphragmMoving;
            
            state diaphragmMoving {
                doc /* Diaphragm in motion responding to electromagnetic force */
                entry action actuateDiaphragm;
                
                entry; then forwardStroke;
                
                state forwardStroke {
                    doc /* Diaphragm moving outward */
                }
                
                accept reverseDirection;
                then reverseStroke;
                
                state reverseStroke {
                    doc /* Diaphragm moving inward */
                }
            }
            
            then soundRadiating;
            
            state soundRadiating {
                doc /* Diaphragm radiating acoustic energy */
                entry action emitSound;
            }
        }
        
        accept signalEnded;
        then idle;
        
        accept powerOff;
        then off;
    }
    
    requirement def TransducerPerformanceRequirements {
        doc /* Performance specifications for electromagnetic diaphragm transducer */
        
        requirement frequencyResponse {
            doc /* Transducer shall operate over specified frequency range with uniform response */
            attribute minFrequency : FrequencyValue = 100.0;
            attribute maxFrequency : FrequencyValue = 10000.0;
            attribute responseVariation : Real = 3.0;
        }
        
        requirement sensitivityRequirement {
            doc /* Transducer shall achieve minimum sound pressure level at reference conditions */
            attribute minSPL : PressureValue = 90.0;
            attribute referenceVoltage : VoltageValue = 1.0;
            attribute referenceDistance : ISQ::length = 1.0;
        }
        
        requirement impedanceRequirement {
            doc /* Transducer shall maintain nominal electrical impedance within tolerance */
            attribute nominalImpedance : ResistanceValue = 6.5;
            attribute impedanceTolerance : Real = 0.20;
            attribute measurementFrequency : FrequencyValue = 1000.0;
        }
        
        requirement powerHandling {
            doc /* Transducer shall handle specified continuous and peak power without damage */
            attribute continuousPower : ISQ::power = 2.0;
            attribute peakPower : ISQ::power = 5.0;
        }
        
        requirement excursionLimit {
            doc /* Diaphragm displacement shall remain within mechanical limits */
            attribute maxExcursion : DisplacementValue = 0.003;
        }
        
        requirement distortionRequirement {
            doc /* Total harmonic distortion shall remain below specified level */
            attribute maxTHD : Real = 0.05;
            attribute measurementLevel : ISQ::power = 1.0;
        }
    }
    
    requirement systemRequirement : TransducerPerformanceRequirements {
        subject transducerSystem : ElectromagneticDiaphragmTransducer;
        
        doc /* System-level requirement allocation for electromagnetic diaphragm transducer */
        
        require frequencyResponse;
        require sensitivityRequirement;
        require impedanceRequirement;
        require powerHandling;
        require excursionLimit;
        require distortionRequirement;
    }
    
    part electromagneticDiaphragmSystem : ElectromagneticDiaphragmTransducer {
        doc /* Complete electromagnetic diaphragm system instance for audio transduction */
        
        perform action systemOperation : operateElectromagneticDiaphragm {
            in inputSignal : ElectricalSignal;
            in magneticFieldStrength = permanentMagnet.magneticFluxDensity;
            in diaphragmMass = flexibleDiaphragm.effectiveMass;
            in suspensionStiffness = surroundSuspension.stiffness;
            in suspensionDamping = surroundSuspension.mechanicalDamping;
            in radiatingArea = flexibleDiaphragm.effectiveArea;
            out mechanicalOutput : MechanicalState;
            out acousticOutput : AcousticOutput;
        }
        
        part voiceCoil {
            perform systemOperation.convertToMagnetic;
        }
        
        part flexibleDiaphragm {
            perform systemOperation.convertToMechanical;
            perform systemOperation.convertToAcoustic;
        }
        
        exhibit state operatingBehavior : TransducerOperatingStates;
    }
}
