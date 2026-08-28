package BlindsightVisualProcessing {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Item and Value Types =====
    
    item def VisualStimulus {
        attribute luminance : Real [cd/m²]; // luminance in candela per square meter
        attribute wavelength : Real [nm]; // wavelength in nanometers
        attribute positionX : Real [deg]; // horizontal angular position
        attribute positionY : Real [deg]; // vertical angular position
        attribute velocity : Real [deg/s]; // angular velocity
        attribute contrast : Real; // dimensionless contrast ratio
    }
    
    item def NeuralSignal {
        attribute firingRate : Real [Hz]; // firing rate in hertz
        attribute latency : Real [ms]; // response latency in milliseconds
        attribute signalStrength : Real; // normalized 0..1
    }
    
    item def SpatialInfo {
        attribute targetX : Real [deg];
        attribute targetY : Real [deg];
        attribute targetVelocity : Real [deg/s];
        attribute confidence : Real; // 0..1
    }
    
    item def MotorCommand {
        attribute actionType : String;
        attribute reachX : Real [deg];
        attribute reachY : Real [deg];
        attribute force : Real [N]; // force in newtons
        attribute reactionTime : Real [ms];
    }
    
    item def ConsciousReport {
        attribute aware : Boolean;
        attribute reportedContent : String;
    }
    
    value type cd_per_m2 > Real { unit "cd/m²"; }
    value type nm > Real { unit "nm"; }
    value type deg > Real { unit "deg"; }
    value type deg_per_s > Real { unit "deg/s"; }
    value type Hz > Real { unit "Hz"; }
    value type ms > Real { unit "ms"; }
    value type N > Real { unit "N"; }
    
    // ===== Port Definitions =====
    
    port def LightInputPort {
        in item light : VisualStimulus;
    }
    
    port def NeuralOutputPort {
        out item signal : NeuralSignal;
    }
    
    port def NeuralInputPort {
        in item signal : NeuralSignal;
    }
    
    port def SpatialOutputPort {
        out item spatial : SpatialInfo;
    }
    
    port def SpatialInputPort {
        in item spatial : SpatialInfo;
    }
    
    port def MotorOutputPort {
        out item command : MotorCommand;
    }
    
    port def ConsciousnessPort {
        out item report : ConsciousReport;
    }
    
    // ===== Requirements =====
    
    requirement def ConsciousPerceptionRequirement {
        doc /* The ventral stream shall produce conscious awareness of visual stimuli. */
        subject ventralStream : PartDefinition;
        require ventralStream.functional == false;
    }
    
    requirement def UnconsciousActionRequirement {
        doc /* The system shall generate accurate motor actions toward visual stimuli despite no conscious awareness. */
        subject system : PartDefinition;
        require system.consciousReport.aware == false and system.motorAccuracy > 0.75;
    }
    
    requirement def DorsalStreamRequirement {
        doc /* The dorsal stream shall process spatial location and motion to guide action. */
        subject dorsalStream : PartDefinition;
        require dorsalStream.functional == true;
    }
    
    requirement def SuperiorColliculusRequirement {
        doc /* The superior colliculus shall process stimulus location for rapid reflexive responses. */
        subject sc : PartDefinition;
        require sc.functional == true and sc.responseLatency < 100 [ms];
    }
    
    requirement def MotorIntegrationRequirement {
        doc /* The motor cortex shall integrate unconscious spatial data to plan physical actions. */
        subject motorCortex : PartDefinition;
        require motorCortex.functional == true;
    }
    
    requirement BlindsightSystemRequirement {
        doc /* The complete blindsight system shall demonstrate dissociation between conscious perception and visually guided action. */
        satisfy ConsciousPerceptionRequirement;
        satisfy UnconsciousActionRequirement;
        satisfy DorsalStreamRequirement;
        satisfy SuperiorColliculusRequirement;
        satisfy MotorIntegrationRequirement;
    }
    
    // ===== Part Definitions =====
    
    part def Retina {
        port lightIn : LightInputPort;
        port neuralOut : NeuralOutputPort;
        
        attribute functional : Boolean = true;
        attribute photoreceptorDensity : Real [1/deg²];
        
        action def TransduceLight :> Action {
            in stimulus : VisualStimulus;
            out signal : NeuralSignal;
        }
        
        action transduce : TransduceLight {
            in stimulus = lightIn.light;
            out signal = neuralOut.signal;
        }
    }
    
    part def OpticNerve {
        port neuralIn : NeuralInputPort;
        port neuralOut : NeuralOutputPort;
        
        attribute functional : Boolean = true;
        attribute conductionVelocity : Real [m/s];
        
        action def ConductSignal :> Action {
            in input : NeuralSignal;
            out output : NeuralSignal;
        }
        
        action conduct : ConductSignal {
            in input = neuralIn.signal;
            out output = neuralOut.signal;
        }
    }
    
    part def LateralGeniculateNucleus {
        port neuralIn : NeuralInputPort;
        port corticalOut : NeuralOutputPort;
        port subcorticalOut : NeuralOutputPort;
        
        attribute functional : Boolean = true;
        
        action def RelaySignal :> Action {
            in input : NeuralSignal;
            out cortical : NeuralSignal;
            out subcortical : NeuralSignal;
        }
        
        action relay : RelaySignal {
            in input = neuralIn.signal;
            out cortical = corticalOut.signal;
            out subcortical = subcorticalOut.signal;
        }
    }
    
    part def VentralStream {
        port neuralIn : NeuralInputPort;
        port consciousOut : ConsciousnessPort;
        
        attribute functional : Boolean = false; // DAMAGED - characteristic of blindsight
        attribute damageLocation : String = "primary visual cortex (V1) to inferior temporal cortex";
        attribute damageSeverity : Real = 0.95; // 95% lesion
        
        state def VentralStreamStates {
            initial state Damaged {
                entry consciousOut.report.aware = false;
                entry consciousOut.report.reportedContent = "I see nothing - completely blind";
            }
            transition from Damaged to Damaged
                guard neuralIn.signal.signalStrength > 0.5
                accept neuralIn;
        }
        
        exhibit state behavior : VentralStreamStates;
        
        requirement ventralReq : ConsciousPerceptionRequirement {
            subject = ventralReq_subject :>> self;
        }
    }
    
    part def DorsalStream {
        port neuralIn : NeuralInputPort;
        port spatialOut : SpatialOutputPort;
        
        attribute functional : Boolean = true;
        attribute processingLatency : Real [ms] = 40.0;
        
        action def ProcessSpatial :> Action {
            in input : NeuralSignal;
            out spatial : SpatialInfo;
        }
        
        action process : ProcessSpatial {
            in input = neuralIn.signal;
            out spatial = spatialOut.spatial;
        }
        
        requirement dorsalReq : DorsalStreamRequirement {
            subject = dorsalReq_subject :>> self;
        }
    }
    
    part def SuperiorColliculus {
        port neuralIn : NeuralInputPort;
        port spatialOut : SpatialOutputPort;
        
        attribute functional : Boolean = true;
        attribute responseLatency : Real [ms] = 70.0;
        
        action def ProcessReflexive :> Action {
            in input : NeuralSignal;
            out spatial : SpatialInfo;
        }
        
        action processReflex : ProcessReflexive {
            in input = neuralIn.signal;
            out spatial = spatialOut.spatial;
        }
        
        requirement scReq : SuperiorColliculusRequirement {
            subject = scReq_subject :>> self;
        }
    }
    
    part def MotorCortex {
        port dorsalIn : SpatialInputPort;
        port colliculusIn : SpatialInputPort;
        port motorOut : MotorOutputPort;
        
        attribute functional : Boolean = true;
        attribute motorAccuracy : Real = 0.82;
        attribute integrationLatency : Real [ms] = 30.0;
        
        action def IntegrateAndPlan :> Action {
            in dorsalSpatial : SpatialInfo;
            in colliculusSpatial : SpatialInfo;
            out command : MotorCommand;
            
            // Weighted integration of both pathways
            private attribute weightDorsal : Real = 0.6;
            private attribute weightColliculus : Real = 0.4;
        }
        
        action integrate : IntegrateAndPlan {
            in dorsalSpatial = dorsalIn.spatial;
            in colliculusSpatial = colliculusIn.spatial;
            out command = motorOut.command;
        }
        
        requirement motorReq : MotorIntegrationRequirement {
            subject = motorReq_subject :>> self;
        }
    }
    
    part def ConsciousnessModule {
        port ventralIn : ConsciousnessPort;
        port reportOut : ConsciousnessPort;
        
        attribute aware : Boolean = false;
        attribute reportedContent : String = "No visual experience";
        
        action def GenerateReport :> Action {
            in ventralReport : ConsciousReport;
            out report : ConsciousReport;
        }
        
        action generate : GenerateReport {
            in ventralReport = ventralIn.report;
            out report = reportOut.report;
        }
    }
    
    part def Effector {
        port motorIn : MotorOutputPort;
        
        attribute effectorType : String = "arm/hand";
        
        action def ExecuteAction :> Action {
            in command : MotorCommand;
        }
        
        action execute : ExecuteAction {
            in command = motorIn.command;
        }
    }
    
    // ===== Top-Level System =====
    
    part def BlindsightVisualSystem {
        port stimulusIn : LightInputPort;
        port actionOut : MotorOutputPort;
        port consciousReportOut : ConsciousnessPort;
        
        attribute motorAccuracy : Real = 0.82;
        attribute consciousReport : ConsciousReport;
        
        part leftEye : Retina {
            lightIn = stimulusIn;
        }
        
        part leftOpticNerve : OpticNerve;
        part lgn : LateralGeniculateNucleus;
        part ventralStream : VentralStream;
        part dorsalStream : DorsalStream;
        part superiorColliculus : SuperiorColliculus;
        part motorCortex : MotorCortex;
        part consciousness : ConsciousnessModule;
        part effector : Effector;
        
        // Connections from eye to optic nerve
        connection leftEye.neuralOut to leftOpticNerve.neuralIn;
        
        // Optic nerve to LGN
        connection leftOpticNerve.neuralOut to lgn.neuralIn;
        
        // LGN to ventral stream (damaged pathway)
        connection lgn.corticalOut to ventralStream.neuralIn;
        
        // LGN to dorsal stream (intact pathway)
        connection lgn.corticalOut to dorsalStream.neuralIn;
        
        // LGN subcortical output to superior colliculus (intact pathway)
        connection lgn.subcorticalOut to superiorColliculus.neuralIn;
        
        // Dorsal stream to motor cortex
        connection dorsalStream.spatialOut to motorCortex.dorsalIn;
        
        // Superior colliculus to motor cortex
        connection superiorColliculus.spatialOut to motorCortex.colliculusIn;
        
        // Ventral stream to consciousness module
        connection ventralStream.consciousOut to consciousness.ventralIn;
        
        // Motor cortex to effector
        connection motorCortex.motorOut to effector.motorIn;
        
        // Bind system output ports
        actionOut = motorCortex.motorOut;
        consciousReportOut = consciousness.reportOut;
        
        requirement systemReq : BlindsightSystemRequirement;
        
        // System-level state machine
        state def SystemStates {
            initial state StimulusAbsent;
            state StimulusPresent {
                // Ventral stream produces no awareness
                // Dorsal + SC produce spatial info
                // Motor cortex generates action
            }
            state ActionExecuted;
            
            transition from StimulusAbsent to StimulusPresent
                guard stimulusIn.light.luminance > 0.0;
            
            transition from StimulusPresent to ActionExecuted
                guard motorCortex.motorOut.command.reactionTime > 0.0;
            
            transition from ActionExecuted to StimulusAbsent
                guard stimulusIn.light.luminance == 0.0;
        }
        
        exhibit state behavior : SystemStates;
    }
    
    // ===== Verification =====
    
    verification VerifyBlindsightDissociation {
        subject blindsightSystem : BlindsightVisualSystem;
        objective {
            doc /* Verify that the system reports no conscious awareness while still producing accurate motor actions. */
        }
    }
    
}
