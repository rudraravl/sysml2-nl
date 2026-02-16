package FarmWiseAutonomousWeeder {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def GPSCoordinate {
		attribute latitude : Real;
		attribute longitude : Real;
	}
	
	attribute def ImageFrame;
	
	attribute def PlantClassification {
		attribute isCrop : Boolean;
		attribute confidence : Real;
		attribute position : GPSCoordinate;
	}
	
	attribute def FieldBoundary {
		attribute corners : GPSCoordinate[*];
		attribute totalArea : AreaValue;
	}
	
	item def ElectricalPower {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	item def NavigationCommand {
		attribute targetPosition : GPSCoordinate;
		attribute speed : ISQ::SpeedValue;
		attribute heading : ISQ::AngleValue;
	}
	
	item def WeedingCommand {
		attribute targetLocation : GPSCoordinate;
		attribute toolDepth : ISQ::LengthValue;
		attribute toolWidth : ISQ::LengthValue;
	}
	
	port def PowerSupplyPort {
		out item power : ElectricalPower;
	}
	
	port def PowerConsumerPort {
		in item power : ElectricalPower;
	}
	
	port def CameraPort {
		out item imageData : ImageFrame;
	}
	
	port def VisionProcessingPort {
		in item imageData : ImageFrame;
		out item classifications : PlantClassification[*];
	}
	
	port def NavigationControlPort {
		in item navCommand : NavigationCommand;
		out item currentPosition : GPSCoordinate;
	}
	
	port def WeedingControlPort {
		in item weedCommand : WeedingCommand;
		out item operationComplete : Boolean;
	}
	
	connection def PowerConnection {
		end supplier : PowerSupplyPort;
		end consumer : PowerConsumerPort;
	}
	
	connection def VisionDataConnection {
		end source : CameraPort;
		end processor : VisionProcessingPort;
	}
	
	part def CameraSystem {
		port cameraOut : CameraPort;
		port powerIn : PowerConsumerPort;
		
		attribute resolution : Real;
		attribute fieldOfView : ISQ::AngleValue;
		attribute frameRate : ISQ::FrequencyValue;
		
		action captureImage {
			out frame : ImageFrame;
		}
	}
	
	part def VisionProcessor {
		port visionIn : VisionProcessingPort;
		port powerIn : PowerConsumerPort;
		
		attribute processingRate : ISQ::FrequencyValue;
		attribute detectionAccuracy : Real;
		
		action analyzeFrame {
			in frame : ImageFrame;
			out detections : PlantClassification[*];
		}
		
		action filterCrops {
			in detections : PlantClassification[*];
			out weedsOnly : PlantClassification[*];
		}
	}
	
	part def GPSNavigationSystem {
		port navControl : NavigationControlPort;
		port powerIn : PowerConsumerPort;
		
		attribute positionAccuracy : ISQ::LengthValue;
		attribute updateRate : ISQ::FrequencyValue;
		
		action getCurrentPosition {
			out position : GPSCoordinate;
		}
		
		action calculatePath {
			in start : GPSCoordinate;
			in target : GPSCoordinate;
			out waypoints : GPSCoordinate[*];
		}
		
		action followPath {
			in waypoints : GPSCoordinate[*];
			out reachedDestination : Boolean;
		}
	}
	
	part def MechanicalWeeder {
		port weedControl : WeedingControlPort;
		port powerIn : PowerConsumerPort;
		
		attribute maxDepth : ISQ::LengthValue;
		attribute toolWidth : ISQ::LengthValue;
		attribute actuationSpeed : ISQ::SpeedValue;
		
		action positionTool {
			in targetLocation : GPSCoordinate;
			out toolReady : Boolean;
		}
		
		action engageTool {
			in depth : ISQ::LengthValue;
			out weedRemoved : Boolean;
		}
		
		action retractTool {
			out toolRetracted : Boolean;
		}
	}
	
	part def DriveSystem {
		port powerIn : PowerConsumerPort;
		
		attribute maxSpeed : ISQ::SpeedValue;
		attribute wheelDiameter : ISQ::LengthValue;
		attribute trackWidth : ISQ::LengthValue;
		
		action driveForward {
			in speed : ISQ::SpeedValue;
			in distance : ISQ::LengthValue;
		}
		
		action turn {
			in angle : ISQ::AngleValue;
		}
		
		action halt;
	}
	
	part def BatteryPack {
		port powerOut : PowerSupplyPort;
		
		attribute capacity : ISQ::EnergyValue;
		attribute voltage : ISQ::VoltageValue;
		attribute currentCharge : Real;
		
		action providePower {
			out power : ElectricalPower;
		}
		
		action monitorCharge {
			out chargeLevel : Real;
		}
		
		action estimateRemainingTime {
			in currentDraw : ISQ::ElectricCurrentValue;
			out timeRemaining : ISQ::TimeValue;
		}
	}
	
	part def ControlComputer {
		port powerIn : PowerConsumerPort;
		
		attribute processingPower : ISQ::PowerValue;
		attribute memoryCapacity : Real;
		
		action coordinateOperations;
		action logData;
		action handleEmergency;
	}
	
	requirement def <'REQ-FW-001'> AutonomousWeedingCapability {
		doc /* The FarmWise system shall autonomously navigate crop fields, 
		       identify weeds using computer vision, and selectively remove 
		       weeds while preserving crop plants. */
		
		require weedDetectionPerformance;
		require cropSafetyPerformance;
		require operationalAutonomy;
	}
	
	requirement def <'REQ-FW-002'> WeedDetectionPerformance {
		doc /* The vision system shall detect weeds with minimum 92% accuracy 
		       under normal field lighting conditions. */
		
		attribute minAccuracy : Real = 0.92;
		attribute lightingConditions : String = "daylight 500-10000 lux";
	}
	
	requirement def <'REQ-FW-003'> CropSafetyPerformance {
		doc /* The system shall avoid damaging crop plants with minimum 98% 
		       success rate during weeding operations. */
		
		attribute minSafetyRate : Real = 0.98;
	}
	
	requirement def <'REQ-FW-004'> OperationalAutonomy {
		doc /* The system shall operate continuously for minimum 8 hours 
		       on a single battery charge. */
		
		attribute minOperatingTime : ISQ::TimeValue;
	}
	
	requirement def <'REQ-FW-005'> FieldCoverageRate {
		doc /* The system shall cover minimum 0.5 hectares per hour 
		       during active weeding operations. */
		
		attribute minCoverageRate : ISQ::AreaValue;
	}
	
	action def ScanRow {
		in rowStartPosition : GPSCoordinate;
		in rowEndPosition : GPSCoordinate;
		out weedLocations : GPSCoordinate[*];
	}
	
	action def RemoveWeedAtLocation {
		in weedPosition : GPSCoordinate;
		out success : Boolean;
	}
	
	action def TraverseField {
		in fieldBoundary : FieldBoundary;
		in rowSpacing : ISQ::LengthValue;
		out rowsCompleted : Integer;
	}
	
	part def FarmWiseWeeder;
	
	part farmWiseWeeder : FarmWiseWeeder {
		doc /* 
		FarmWise autonomous weeding robot.
		
		Primary Function:
		The FarmWise system provides autonomous, precision weeding for agricultural 
		crop fields. It combines advanced computer vision, GPS navigation, and 
		mechanical weeding tools to identify and remove weeds while protecting crops.
		
		The system operates by autonomously traversing crop rows, continuously 
		capturing images of plants using onboard cameras. An AI-powered vision 
		processor analyzes each image in real-time to distinguish between valuable 
		crop plants and unwanted weeds based on visual characteristics. When weeds 
		are detected, the system records their precise GPS coordinates.
		
		The robot then navigates to each identified weed location with centimeter-level 
		accuracy and deploys a mechanical weeding tool to physically remove the weed 
		from the soil. This targeted approach eliminates weeds without disturbing 
		nearby crops or requiring chemical herbicides.
		
		The system repeats this cycle of scanning, detecting, navigating, and weeding 
		continuously as it methodically covers the entire field. It operates 
		autonomously for extended periods on battery power, returning to a charging 
		station when needed. This enables farmers to maintain weed-free fields with 
		reduced labor costs, zero herbicide use, and minimal crop damage.
		*/
		
		satisfy weedingCapability;
		
		part camera : CameraSystem {
			port cameraOut;
			port powerIn;
		}
		
		part visionProc : VisionProcessor {
			port visionIn;
			port powerIn;
		}
		
		part gpsNav : GPSNavigationSystem {
			port navControl;
			port powerIn;
		}
		
		part weeder : MechanicalWeeder {
			port weedControl;
			port powerIn;
		}
		
		part drive : DriveSystem {
			port powerIn;
		}
		
		part battery : BatteryPack {
			port powerOut;
		}
		
		part controller : ControlComputer {
			port powerIn;
		}
		
		connection powerToCamera : PowerConnection {
			end supplier = battery.powerOut;
			end consumer = camera.powerIn;
		}
		
		connection powerToVision : PowerConnection {
			end supplier = battery.powerOut;
			end consumer = visionProc.powerIn;
		}
		
		connection powerToNav : PowerConnection {
			end supplier = battery.powerOut;
			end consumer = gpsNav.powerIn;
		}
		
		connection powerToWeeder : PowerConnection {
			end supplier = battery.powerOut;
			end consumer = weeder.powerIn;
		}
		
		connection powerToDrive : PowerConnection {
			end supplier = battery.powerOut;
			end consumer = drive.powerIn;
		}
		
		connection powerToController : PowerConnection {
			end supplier = battery.powerOut;
			end consumer = controller.powerIn;
		}
		
		connection visionData : VisionDataConnection {
			end source = camera.cameraOut;
			end processor = visionProc.visionIn;
		}
		
		perform action autonomousWeedingOperation {
			in fieldBounds : FieldBoundary;
			in rowSpacing : ISQ::LengthValue;
			
			private attribute currentRow : Integer := 0;
			private attribute detectedWeeds : GPSCoordinate[*];
			private attribute batteryLevel : Real;
			
			first start;
			
			then action initialize {
				action checkBattery {
					perform battery.monitorCharge;
				}
				then assign batteryLevel := 1.0;
				
				then action getStartPosition {
					perform gpsNav.getCurrentPosition;
				}
			}
			
			then merge beginRowScan;
			
			action scanCurrentRow {
				action captureImages {
					perform camera.captureImage;
				}
				
				then action processImages {
					perform visionProc.analyzeFrame;
				}
				
				then action identifyWeeds {
					perform visionProc.filterCrops;
				}
			}
			
			then decide;
				if batteryLevel > 0.5 then processWeeds;
				if batteryLevel <= 0.5 then advanceToNextRow;
			
			action processWeeds {
				action navigateToWeed {
					perform gpsNav.followPath;
				}
				
				then action removeWeed {
					perform weeder.positionTool;
					
					then perform weeder.engageTool;
					
					then perform weeder.retractTool;
				}
			}
			
			then advanceToNextRow;
			
			action advanceToNextRow {
				action moveToNextRow {
					perform drive.driveForward;
				}
				
				then assign currentRow := currentRow + 1;
				
				then action checkBatteryStatus {
					perform battery.monitorCharge;
				}
			}
			
			then decide;
				if batteryLevel > 0.15 then beginRowScan;
				if batteryLevel <= 0.15 then returnToBase;
			
			action returnToBase {
				perform gpsNav.calculatePath;
				
				then perform gpsNav.followPath;
				
				then perform drive.halt;
			}
			
			then done;
		}
	}
	
	requirement <'REQ-FW-001'> weedingCapability : AutonomousWeedingCapability;
	requirement <'REQ-FW-002'> detectionPerf : WeedDetectionPerformance;
	requirement <'REQ-FW-003'> cropSafety : CropSafetyPerformance;
	requirement <'REQ-FW-004'> autonomy : OperationalAutonomy;
	requirement <'REQ-FW-005'> coverage : FieldCoverageRate;
}
