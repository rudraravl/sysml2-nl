package MetalCorsetSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CompressionLevel :> Real;
    attribute def TorsoCircumference :> LengthValue;
    attribute def SupportForce :> ForceValue;
    attribute def PostureAngle :> Real;
    
    item def CompressionCommand {
        attribute targetLevel : CompressionLevel;
        attribute targetCircumference : TorsoCircumference;
    }
    
    item def PostureData {
        attribute spinalAlignment : PostureAngle;
        attribute currentCircumference : TorsoCircumference;
    }
    
    port def SensorPort {
        out item postureData : PostureData;
    }
    
    port def ActuatorPort {
        in item command : CompressionCommand;
        out item appliedForce : SupportForce;
    }
    
    part def MetalBoning {
        attribute material : String = "spring steel";
        attribute stiffness : Real;
        attribute maxSupportForce : ForceValue;
    }
    
    part def LacingMechanism {
        attribute currentTension : ForceValue;
        attribute maxAdjustmentRange : LengthValue;
    }
    
    part def PostureSensor {
        port sensorOutput : SensorPort;
        attribute measurementAccuracy : Real = 0.95;
    }
    
    part def CompressionActuator {
        port actuatorInput : ~ActuatorPort;
        attribute responseTime : TimeValue;
    }
    
    part def ControlUnit {
        port sensorInput : ~SensorPort;
        port actuatorOutput : ActuatorPort;
        
        attribute targetPostureAngle : PostureAngle = 90.0;
        attribute targetCompressionLevel : CompressionLevel = 70.0;
        attribute postureTolerance : PostureAngle = 5.0;
        
        private attribute currentPosture : PostureAngle;
        private attribute currentCircumference : TorsoCircumference;
    }
    
    action def SensePosture {
        in sensor : PostureSensor;
        out postureData : PostureData;
    }
    
    action def CalculateAdjustment {
        in currentData : PostureData;
        in targetAngle : PostureAngle;
        in targetLevel : CompressionLevel;
        out adjustmentCommand : CompressionCommand;
    }
    
    action def ApplyCompression {
        in command : CompressionCommand;
        in actuator : CompressionActuator;
        out resultingForce : SupportForce;
    }
    
    action def ProvideTorsoSupport {
        in corset : MetalCorset;
        
        first start;
        then merge continuousControl;
        
        then action sense : SensePosture {
            in sensor = corset.sensors;
            out postureData;
        }
        
        then action calculate : CalculateAdjustment {
            in currentData = sense.postureData;
            in targetAngle = corset.controller.targetPostureAngle;
            in targetLevel = corset.controller.targetCompressionLevel;
            out adjustmentCommand;
        }
        
        then decide;
            if sense.postureData.spinalAlignment < 85.0 then applyAdjustment;
            if sense.postureData.spinalAlignment >= 85.0 then maintainCurrent;
        
        action applyAdjustment : ApplyCompression {
            in command = calculate.adjustmentCommand;
            in actuator = corset.actuators;
            out resultingForce;
        }
        then continuousControl;
        
        action maintainCurrent : ApplyCompression {
            in command = calculate.adjustmentCommand;
            in actuator = corset.actuators;
            out resultingForce;
        }
        then continuousControl;
    }
    
    part def MetalCorset {
        attribute designCircumference : TorsoCircumference = 75.0[cm];
        attribute maxCompressionForce : ForceValue = 150.0[N];
        attribute numberOfBoningElements : Integer = 12;
        
        part structuralFrame {
            part frontBoning : MetalBoning[6] {
                :>> maxSupportForce = 25.0[N];
            }
            part backBoning : MetalBoning[6] {
                :>> maxSupportForce = 30.0[N];
            }
        }
        
        part lacingSystem : LacingMechanism {
            :>> currentTension = 0.0[N];
            :>> maxAdjustmentRange = 20.0[cm];
        }
        
        part sensors : PostureSensor {
            port :>> sensorOutput;
        }
        
        part actuators : CompressionActuator {
            port :>> actuatorInput;
            :>> responseTime = 0.5[s];
        }
        
        part controller : ControlUnit {
            port :>> sensorInput;
            port :>> actuatorOutput;
        }
        
        connection sensorToController connect sensors.sensorOutput to controller.sensorInput;
        connection controllerToActuator connect controller.actuatorOutput to actuators.actuatorInput;
        
        perform action supportOperation : ProvideTorsoSupport {
            in corset = MetalCorset::this;
        }
    }
    
    requirement def <'R-1'> TorsoSupportRequirement {
        doc /* The metal corset shall provide continuous structural support to the torso 
                by applying controlled compression through an adjustable lacing mechanism 
                and rigid boning elements. */
        
        subject corset : MetalCorset;
        
        require constraint adequateBoningCount {
            corset.numberOfBoningElements >= 12
        }
        
        require constraint safeCompressionLimit {
            corset.maxCompressionForce <= 200.0[N]
        }
    }
    
    requirement def <'R-2'> PosturalCorrectionRequirement {
        doc /* The system shall continuously monitor spinal alignment and automatically 
                adjust compression to maintain proper posture within specified tolerance. */
        
        subject corset : MetalCorset;
        
        require constraint continuousMonitoring {
            corset.sensors.measurementAccuracy >= 0.90
        }
        
        require constraint responsiveAdjustment {
            corset.actuators.responseTime <= 1.0[s]
        }
    }
    
    requirement def <'R-3'> AdjustabilityRequirement {
        doc /* The lacing mechanism shall provide sufficient adjustment range to 
                accommodate varying torso dimensions and compression requirements. */
        
        subject lacing : LacingMechanism;
        
        require constraint adjustmentRange {
            lacing.maxAdjustmentRange >= 15.0[cm]
        }
    }
    
    requirement <'SYS-REQ-1'> metalCorsetSystemRequirement {
        doc /* The metal corset system shall provide torso support, posture correction, 
                and adjustable compression for therapeutic and structural purposes. */
        
        require <'R-1'> torsoSupport : TorsoSupportRequirement;
        require <'R-2'> posturalCorrection : PosturalCorrectionRequirement;
        require <'R-3'> adjustability : AdjustabilityRequirement;
    }
    
    part corsetInstance : MetalCorset {
        :>> designCircumference = 80.0[cm];
        :>> maxCompressionForce = 180.0[N];
        
        part :>> structuralFrame {
            part :>> frontBoning {
                :>> stiffness = 0.8;
            }
            part :>> backBoning {
                :>> stiffness = 0.9;
            }
        }
        
        part :>> controller {
            :>> targetPostureAngle = 92.0;
            :>> targetCompressionLevel = 75.0;
        }
        
        satisfy metalCorsetSystemRequirement;
    }
}
