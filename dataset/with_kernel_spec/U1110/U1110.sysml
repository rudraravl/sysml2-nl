package DaVinciSystem {
    package Libraries {
        private import ScalarValues::*;
        
        attribute def Length :> Real;
        attribute def Speed :> Real;
        attribute def Force :> Real;
        attribute def PlaneAngle :> Real;
        attribute def Frequency :> Real;
        
        item def VideoData;
        item def ControlSignal;
        
        enum def SafetyStatus {
            Normal;
            Warning;
            Emergency;
        }
        
        item def MotionCommand {
            attribute position : Length;
            attribute velocity : Speed;
            attribute force : Force;
        }
    }
    
    package Ports {
        private import Libraries::*;
        
        port def MotionInputPort {
            in item motion : MotionCommand;
        }
        port def MotionOutputPort {
            out item motion : MotionCommand;
        }
        port def VideoInputPort {
            in item video : VideoData;
        }
        port def VideoOutputPort {
            out item video : VideoData;
        }
        port def ControlPort {
            in item control : ControlSignal;
            out item status : SafetyStatus;
        }
    }
    
    package Actions {
        private import Libraries::*;
        private import Ports::*;
        
        action def ProcessMotion {
            in item rawMotion : MotionCommand;
            out item scaledMotion : MotionCommand;
        }
        
        action def EnhanceVideo {
            in item rawVideo : VideoData;
            out item enhancedVideo : VideoData;
        }
        
        action def CheckSafety {
            in item motion : MotionCommand;
            out item status : SafetyStatus;
        }
    }
    
    package Components {
        private import ScalarValues::*;
        private import Libraries::*;
        private import Ports::*;
        private import Actions::*;
        
        part def StereoscopicViewer {
            port videoIn : VideoInputPort;
        }
        
        part def MasterController {
            port motionOut : MotionOutputPort;
        }
        
        part def FootPedal {
            port controlOut : ControlPort;
        }
        
        part def SurgeonConsole {
            part viewer : StereoscopicViewer;
            part leftController : MasterController;
            part rightController : MasterController;
            part pedals : FootPedal[1..*];
            
            port visionIn : VideoInputPort;
            port motionOut : MotionOutputPort;
            port controlOut : ControlPort;
            
            connect visionIn to viewer.videoIn;
            connect leftController.motionOut to motionOut;
            connect rightController.motionOut to motionOut;
            connect pedals.controlOut to controlOut;
        }
        
        part def SurgicalInstrument {
            attribute maxWristAngle : PlaneAngle;
            port motionIn : MotionInputPort;
        }
        
        part def EndoscopicCamera {
            port videoOut : VideoOutputPort;
        }
        
        part def RoboticArm {
            part instrument : SurgicalInstrument;
            port motionIn : MotionInputPort;
            port controlIn : ControlPort;
        }
        
        part def PatientSideCart {
            part instrumentArms : RoboticArm[3..*];
            part cameraArm : RoboticArm {
                part camera : EndoscopicCamera;
            }
            
            port motionIn : MotionInputPort;
            port videoOut : VideoOutputPort;
            port controlIn : ControlPort;
            
            connect motionIn to instrumentArms.motionIn;
            connect motionIn to cameraArm.motionIn;
            connect controlIn to instrumentArms.controlIn;
            connect controlIn to cameraArm.controlIn;
            connect cameraArm.camera.videoOut to videoOut;
        }
        
        part def MotionControlProcessor {
            port motionIn : MotionInputPort;
            port motionOut : MotionOutputPort;
            port controlIn : ControlPort;
            
            attribute scaleFactor : Real = 0.1;
            attribute tremorCutoff : Frequency = 5.0;
            attribute isEmergency : Boolean = false;
            
            action processMotion : ProcessMotion;
            
            state machine motionControlSM {
                state Active;
                state EmergencyStopped;
                initial -> Active;
                transition t1 : Active -> EmergencyStopped when isEmergency;
                transition t2 : EmergencyStopped -> Active when not isEmergency;
            }
        }
        
        part def VisionProcessingUnit {
            port videoIn : VideoInputPort;
            port videoOut : VideoOutputPort;
            
            action enhanceVideo : EnhanceVideo;
        }
        
        part def SafetyMonitoringSystem {
            port motionIn : MotionInputPort;
            port controlOut : ControlPort;
            
            attribute maxForce : Force = 10.0;
            attribute maxVelocity : Speed = 0.5;
            attribute limitExceeded : Boolean = false;
            
            action checkSafety : CheckSafety;
            
            state machine safetySM {
                state Monitoring;
                state EmergencyStop;
                initial -> Monitoring;
                transition t1 : Monitoring -> EmergencyStop when limitExceeded;
                transition t2 : EmergencyStop -> Monitoring when not limitExceeded;
            }
        }
        
        part def VisionTower {
            part motionProcessor : MotionControlProcessor;
            part visionProcessor : VisionProcessingUnit;
            part safetySystem : SafetyMonitoringSystem;
            
            port motionIn : MotionInputPort;
            port videoIn : VideoInputPort;
            port motionOut : MotionOutputPort;
            port videoOut : VideoOutputPort;
            port controlIn : ControlPort;
            port controlOut : ControlPort;
            
            connect motionIn to motionProcessor.motionIn;
            connect motionProcessor.motionOut to safetySystem.motionIn;
            connect safetySystem.controlOut to motionProcessor.controlIn;
            connect motionProcessor.motionOut to motionOut;
            
            connect videoIn to visionProcessor.videoIn;
            connect visionProcessor.videoOut to videoOut;
            
            connect controlIn to controlOut;
            connect controlIn to motionProcessor.controlIn;
        }
    }
    
    package Requirements {
        private import Components::*;
        
        requirement def MotionScalingRequirement {
            subject processor : MotionControlProcessor;
            doc /* The processor shall scale surgeon hand movements down to micromovements. */
        }
        
        requirement def TremorFilteringRequirement {
            subject processor : MotionControlProcessor;
            doc /* The processor shall filter out natural hand tremors. */
        }
        
        requirement def SafetyMonitoringRequirement {
            subject safetySystem : SafetyMonitoringSystem;
            doc /* The system shall monitor position, force, and velocity against safety limits. */
        }
    }
    
    package Usages {
        private import Components::*;
        private import Requirements::*;
        
        part daVinciSystem {
            part console : SurgeonConsole;
            part cart : PatientSideCart;
            part tower : VisionTower;
            
            connect console.motionOut to tower.motionIn;
            connect tower.motionOut to cart.motionIn;
            connect cart.videoOut to tower.videoIn;
            connect tower.videoOut to console.visionIn;
            connect console.controlOut to tower.controlIn;
            connect tower.controlOut to cart.controlIn;
            
            satisfy MotionScalingRequirement by tower.motionProcessor;
            satisfy TremorFilteringRequirement by tower.motionProcessor;
            satisfy SafetyMonitoringRequirement by tower.safetySystem;
        }
    }
}
