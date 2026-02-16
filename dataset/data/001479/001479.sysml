package 'Intuitive Surgical da Vinci System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def Precision {
		attribute value : Real;
		attribute unit : String = "mm";
	}
	
	attribute def MotionScalingRatio {
		attribute value : Real;
	}
	
	attribute def VideoQuality {
		attribute horizontalResolution : Integer;
		attribute verticalResolution : Integer;
		attribute frameRate : Real;
		attribute unit : String = "Hz";
		attribute stereoscopic : Boolean;
	}
	
	attribute def TremorFilterFrequency {
		attribute value : Real;
		attribute unit : String = "Hz";
	}
	
	item def SurgeonMotionCommand {
		attribute position : LengthValue[3];
		attribute orientation : Real[3];
		attribute gripperState : Real;
	}
	
	item def InstrumentTelemetry {
		attribute actualPosition : LengthValue[3];
		attribute actualOrientation : Real[3];
		attribute appliedForce : ForceValue[3];
		attribute appliedTorque : TorqueValue[3];
	}
	
	item def VideoStream {
		attribute resolution : VideoQuality;
		attribute latency : TimeValue;
	}
	
	port def SurgeonInputPort {
		out leftHandMotion : SurgeonMotionCommand;
		out rightHandMotion : SurgeonMotionCommand;
		out footPedalCommands : Real[3];
	}
	
	port def VisualFeedbackPort {
		in videoFeed : VideoStream;
	}
	
	port def InstrumentControlPort {
		in motionCommand : SurgeonMotionCommand;
		out telemetry : InstrumentTelemetry;
	}
	
	port def CameraControlPort {
		in cameraCommand : SurgeonMotionCommand;
		out videoOutput : VideoStream;
	}
	
	part def MasterInputDevice {
		attribute degreesOfFreedom : Integer = 7;
		attribute workspaceRadius : LengthValue;
		port outputPort : SurgeonInputPort;
	}
	
	part def StereoscopicViewer {
		attribute viewingAngle : Real;
		attribute eyeSeparation : LengthValue;
		port inputPort : VisualFeedbackPort;
	}
	
	part def SurgeonConsole {
		part leftMaster : MasterInputDevice;
		part rightMaster : MasterInputDevice;
		part footPedals {
			attribute clutchPedal : Boolean;
			attribute cameraPedal : Boolean;
			attribute energyPedal : Boolean;
		}
		part viewer : StereoscopicViewer;
		port masterOutputs : SurgeonInputPort;
		port visualInputs : VisualFeedbackPort;
	}
	
	part def RoboticInstrumentArm {
		attribute numberOfJoints : Integer = 7;
		attribute reachDistance : LengthValue;
		attribute payloadCapacity : MassValue;
		port controlInput : InstrumentControlPort;
		part endEffector {
			attribute wristJoints : Integer = 3;
			attribute jawOpening : LengthValue;
		}
	}
	
	part def EndoscopicCameraArm {
		attribute numberOfJoints : Integer = 6;
		attribute cameraAngle : Real;
		port cameraControl : CameraControlPort;
		part stereoscopicCamera {
			attribute leftSensor : VideoQuality;
			attribute rightSensor : VideoQuality;
			attribute illuminationPower : PowerValue;
		}
	}
	
	part def PatientSideCart {
		part instrumentArm1 : RoboticInstrumentArm;
		part instrumentArm2 : RoboticInstrumentArm;
		part instrumentArm3 : RoboticInstrumentArm;
		part cameraArm : EndoscopicCameraArm;
		port armControl1 : InstrumentControlPort;
		port armControl2 : InstrumentControlPort;
		port armControl3 : InstrumentControlPort;
		port cameraControl : CameraControlPort;
	}
	
	part def VisionProcessingUnit {
		attribute processingLatency : TimeValue;
		attribute imageEnhancement : Boolean;
		port rawVideoInput : CameraControlPort;
		port processedVideoOutput : VisualFeedbackPort;
	}
	
	part def MotionControlProcessor {
		attribute scalingFactor : MotionScalingRatio;
		attribute tremorFilterCutoff : TremorFilterFrequency;
		attribute updateRate : FrequencyValue;
		port surgeonInput : SurgeonInputPort;
		port instrumentOutput1 : InstrumentControlPort;
		port instrumentOutput2 : InstrumentControlPort;
		port instrumentOutput3 : InstrumentControlPort;
		port cameraOutput : CameraControlPort;
	}
	
	part def SafetyMonitoringSystem {
		attribute workspaceBoundaries : LengthValue[6];
		attribute maxForceLimit : ForceValue;
		attribute maxVelocityLimit : SpeedValue;
		port telemetryInput1 : InstrumentControlPort;
		port telemetryInput2 : InstrumentControlPort;
		port telemetryInput3 : InstrumentControlPort;
	}
	
	action def AcquireSurgeonInput {
		out leftCommand : SurgeonMotionCommand;
		out rightCommand : SurgeonMotionCommand;
		out pedalStates : Real[3];
	}
	
	action def FilterAndScaleMotion {
		in rawMotion : SurgeonMotionCommand;
		in scalingRatio : MotionScalingRatio;
		in filterFreq : TremorFilterFrequency;
		out scaledMotion : SurgeonMotionCommand;
	}
	
	action def ComputeInverseKinematics {
		in desiredEndEffectorPose : SurgeonMotionCommand;
		out jointAngles : Real[7];
	}
	
	action def DriveInstrumentActuators {
		in commandedJointAngles : Real[7];
		out achievedPosition : LengthValue[3];
		out achievedOrientation : Real[3];
		out measuredForces : ForceValue[3];
	}
	
	action def CaptureStereoscopicVideo {
		in illuminationLevel : PowerValue;
		in cameraPosition : LengthValue[3];
		out leftImage : VideoStream;
		out rightImage : VideoStream;
	}
	
	action def ProcessAndEnhanceVideo {
		in rawLeftImage : VideoStream;
		in rawRightImage : VideoStream;
		out enhancedStereoVideo : VideoStream;
	}
	
	action def MonitorSafetyLimits {
		in instrumentPositions : LengthValue[3];
		in instrumentForces : ForceValue[3];
		in instrumentVelocities : SpeedValue[3];
		out safetyViolation : Boolean;
		out emergencyStopRequired : Boolean;
	}
	
	action def PerformRoboticAssistedSurgery {
		in procedureType : ScalarValues::String;
		out procedureComplete : ScalarValues::Boolean;
		
		first start;
		then merge surgeryLoop;
		
		action systemInitialization {
			action powerOnSubsystems;
			then action calibrateInstruments;
			then action verifySystemReadiness;
			then action dockInstruments;
		}
		
		then surgeryLoop;
		
		action surgicalOperationCycle {
			action acquireInput : AcquireSurgeonInput {
				out leftCommand;
				out rightCommand;
				out pedalStates;
			}
			
			flow acquireInput.leftCommand to filterLeft.rawMotion;
			flow acquireInput.rightCommand to filterRight.rawMotion;
			
			action filterLeft : FilterAndScaleMotion {
				in rawMotion;
				in scalingRatio : MotionScalingRatio;
				in filterFreq : TremorFilterFrequency;
				out scaledMotion;
			}
			
			action filterRight : FilterAndScaleMotion {
				in rawMotion;
				in scalingRatio : MotionScalingRatio;
				in filterFreq : TremorFilterFrequency;
				out scaledMotion;
			}
			
			flow filterLeft.scaledMotion to kinematicsLeft.desiredEndEffectorPose;
			flow filterRight.scaledMotion to kinematicsRight.desiredEndEffectorPose;
			
			action kinematicsLeft : ComputeInverseKinematics {
				in desiredEndEffectorPose;
				out jointAngles;
			}
			
			action kinematicsRight : ComputeInverseKinematics {
				in desiredEndEffectorPose;
				out jointAngles;
			}
			
			flow kinematicsLeft.jointAngles to driveLeft.commandedJointAngles;
			flow kinematicsRight.jointAngles to driveRight.commandedJointAngles;
			
			action driveLeft : DriveInstrumentActuators {
				in commandedJointAngles;
				out achievedPosition;
				out achievedOrientation;
				out measuredForces;
			}
			
			action driveRight : DriveInstrumentActuators {
				in commandedJointAngles;
				out achievedPosition;
				out achievedOrientation;
				out measuredForces;
			}
			
			action captureVideo : CaptureStereoscopicVideo {
				in illuminationLevel : PowerValue;
				in cameraPosition : LengthValue[3];
				out leftImage;
				out rightImage;
			}
			
			flow captureVideo.leftImage to processVideo.rawLeftImage;
			flow captureVideo.rightImage to processVideo.rawRightImage;
			
			action processVideo : ProcessAndEnhanceVideo {
				in rawLeftImage;
				in rawRightImage;
				out enhancedStereoVideo;
			}
			
			flow driveLeft.achievedPosition to monitorSafety.instrumentPositions;
			flow driveLeft.measuredForces to monitorSafety.instrumentForces;
			
			action monitorSafety : MonitorSafetyLimits {
				in instrumentPositions;
				in instrumentForces;
				in instrumentVelocities : SpeedValue[3];
				out safetyViolation;
				out emergencyStopRequired;
			}
		}
		
		then decide;
			if surgicalOperationCycle.monitorSafety.emergencyStopRequired then emergencyStop;
			if not surgicalOperationCycle.monitorSafety.emergencyStopRequired then checkContinuation;
		
		action checkContinuation;
		
		then decide;
			if procedureType == "continue" then surgeryLoop;
			if procedureType == "complete" then normalShutdown;
		
		action emergencyStop {
			action freezeAllMotion;
			then action retractInstruments;
			then action alertSurgicalTeam;
		}
		then done;
		
		action normalShutdown {
			action retractInstrumentsSafely;
			then action undockInstruments;
			then action powerDownSystem;
		}
		then done;
	}
	
	part daVinciSurgicalSystem {
		doc /* The da Vinci Surgical System enables surgeons to perform complex minimally invasive procedures 
		       through robotic assistance, providing enhanced precision, dexterity, and visualization beyond 
		       the capabilities of conventional laparoscopic surgery. */
		
		perform action surgery[*] ordered : PerformRoboticAssistedSurgery;
		
		part console : SurgeonConsole {
			perform surgery.surgicalOperationCycle.acquireInput;
		}
		
		part patientCart : PatientSideCart {
			perform surgery.surgicalOperationCycle.driveLeft;
			perform surgery.surgicalOperationCycle.driveRight;
			perform surgery.surgicalOperationCycle.captureVideo;
		}
		
		part visionSystem : VisionProcessingUnit {
			perform surgery.surgicalOperationCycle.processVideo;
		}
		
		part motionController : MotionControlProcessor {
			perform surgery.surgicalOperationCycle.filterLeft;
			perform surgery.surgicalOperationCycle.filterRight;
			perform surgery.surgicalOperationCycle.kinematicsLeft;
			perform surgery.surgicalOperationCycle.kinematicsRight;
		}
		
		part safetyMonitor : SafetyMonitoringSystem {
			perform surgery.surgicalOperationCycle.monitorSafety;
		}
		
		connect console.masterOutputs to motionController.surgeonInput;
		connect motionController.instrumentOutput1 to patientCart.armControl1;
		connect motionController.instrumentOutput2 to patientCart.armControl2;
		connect motionController.cameraOutput to patientCart.cameraControl;
		connect patientCart.cameraControl to visionSystem.rawVideoInput;
		connect visionSystem.processedVideoOutput to console.visualInputs;
		connect patientCart.armControl1 to safetyMonitor.telemetryInput1;
		connect patientCart.armControl2 to safetyMonitor.telemetryInput2;
	}
	
	requirement def InstrumentPrecisionRequirement {
		doc /* The robotic instrument arms shall achieve and maintain positional accuracy of 0.1 mm or better 
		       at the instrument tip throughout the surgical workspace. */
		
		subject system : daVinciSurgicalSystem;
		
		require constraint {
			system.patientCart.instrumentArm1.endEffector.jawOpening >= 0.0 and
			system.patientCart.instrumentArm1.endEffector.jawOpening <= 0.1
		}
	}
	
	requirement def MotionScalingRequirement {
		doc /* The system shall provide adjustable motion scaling ratios from 1:1 to 5:1 to reduce the effect 
		       of surgeon hand tremor and enable fine manipulation. */
		
		subject controller : MotionControlProcessor;
		
		require constraint {
			controller.scalingFactor.value >= 1.0 and
			controller.scalingFactor.value <= 5.0
		}
	}
	
	requirement def StereoscopicVisualizationRequirement {
		doc /* The system shall provide high-definition 3D stereoscopic visualization with minimum 1080p 
		       resolution at 60 Hz to enable depth perception and spatial awareness. */
		
		subject vision : VisionProcessingUnit;
		
		require constraint {
			vision.rawVideoInput.videoOutput.resolution.horizontalResolution >= 1920 and
			vision.rawVideoInput.videoOutput.resolution.verticalResolution >= 1080 and
			vision.rawVideoInput.videoOutput.resolution.frameRate >= 60.0 and
			vision.rawVideoInput.videoOutput.resolution.stereoscopic == true
		}
	}
	
	requirement def TremorFilteringRequirement {
		doc /* The system shall filter surgeon hand tremor by applying a low-pass filter with cutoff frequency 
		       between 1-3 Hz to eliminate unintended micro-movements. */
		
		subject controller : MotionControlProcessor;
		
		require constraint {
			controller.tremorFilterCutoff.value >= 1.0 and
			controller.tremorFilterCutoff.value <= 3.0
		}
	}
	
	requirement def SafetyMonitoringRequirement {
		doc /* The system shall continuously monitor instrument positions, forces, and velocities, and shall 
		       initiate emergency stop if any parameter exceeds defined safety limits. */
		
		subject safety : SafetyMonitoringSystem;
		
		require constraint {
			safety.maxForceLimit > 0.0 and
			safety.maxVelocityLimit > 0.0
		}
	}
	
	requirement def SystemLatencyRequirement {
		doc /* The end-to-end latency from surgeon input at the console to corresponding instrument motion 
		       shall not exceed 100 milliseconds to maintain natural hand-eye coordination. */
		
		subject controller : MotionControlProcessor;
		
		require constraint {
			controller.updateRate >= 10.0
		}
	}
	
	requirement <'DVSYS-001'> primaryMissionRequirement {
		doc /* The da Vinci Surgical System shall enable surgeons to perform complex minimally invasive surgical 
		       procedures with enhanced precision, dexterity, and three-dimensional visualization, translating 
		       surgeon hand movements into scaled, filtered, and precise instrument motions inside the patient 
		       while maintaining patient safety through continuous monitoring and emergency stop capabilities. */
		
		assume constraint surgeonTrainingComplete {
			doc /* Surgeon has completed required da Vinci system training and certification. */
		}
		
		assume constraint patientPrepared {
			doc /* Patient is properly positioned, prepped, and under anesthesia with trocar ports established. */
		}
		
		assume constraint instrumentsSterilized {
			doc /* All surgical instruments are properly sterilized and functionally verified. */
		}
		
		require InstrumentPrecisionRequirement;
		require MotionScalingRequirement;
		require StereoscopicVisualizationRequirement;
		require TremorFilteringRequirement;
		require SafetyMonitoringRequirement;
		require SystemLatencyRequirement;
	}
}
