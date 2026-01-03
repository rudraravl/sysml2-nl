package SewingMachineSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ThreadTension :> Real;
	attribute def StitchLength :> Real;
	attribute def StitchPattern;
	
	value def RotationalSpeed {
		attribute value : Real;
		attribute unit : RotationalSpeedUnit;
	}
	
	enum def RotationalSpeedUnit {
		enum RPM;
	}
	
	value def LinearVelocity {
		attribute value : Real;
		attribute unit : LinearVelocityUnit;
	}
	
	enum def LinearVelocityUnit {
		enum millimeterPerSecond;
	}
	
	item def Thread {
		attribute thickness : LengthValue;
		attribute material : String;
	}
	
	item def Fabric {
		attribute thickness : LengthValue;
		attribute layers : Integer;
	}
	
	item def Bobbin {
		attribute threadCapacity : LengthValue;
		attribute currentThread : LengthValue;
	}
	
	item def ElectricalPower;
	item def MechanicalPower;
	
	port def ThreadSupplyPort {
		out item threadSupply : Thread;
		attribute tension : ThreadTension;
	}
	
	port def ThreadIntakePort {
		in item threadIntake : Thread;
		attribute tension : ThreadTension;
	}
	
	port def FabricPort {
		in item fabricIn : Fabric;
		out item fabricOut : Fabric;
	}
	
	port def PowerPort {
		in item power : ElectricalPower;
	}
	
	port def DrivePort {
		out item mechanicalDrive : MechanicalPower;
		attribute speed : RotationalSpeed;
	}
	
	part def ThreadSpool {
		port supplyPort : ThreadSupplyPort;
		attribute remainingThread : LengthValue;
	}
	
	part def TensionRegulator {
		port inputPort : ThreadIntakePort;
		port outputPort : ThreadSupplyPort;
		attribute tensionSetting : ThreadTension;
		
		action def AdjustTension {
			in currentTension : ThreadTension;
			in desiredTension : ThreadTension;
			out adjustedTension : ThreadTension;
		}
	}
	
	part def NeedleBar {
		port threadPort : ThreadIntakePort;
		attribute position : LengthValue;
		attribute verticalSpeed : LinearVelocity;
		
		action def PenetrateDown {
			in fabric : Fabric;
			out penetrationDepth : LengthValue;
		}
		
		action def RetractUp {
			out clearanceHeight : LengthValue;
		}
	}
	
	part def BobbinAssembly {
		part bobbin : Bobbin;
		port threadPort : ThreadSupplyPort;
		attribute rotationAngle : Real;
		
		action def CatchUpperThread {
			in upperThread : Thread;
			in lowerThread : Thread;
			out interlocked : Boolean;
		}
	}
	
	part def FeedDogMechanism {
		port fabricPort : FabricPort;
		attribute feedLength : StitchLength;
		attribute feedSpeed : LinearVelocity;
		
		action def AdvanceFabric {
			in fabric : Fabric;
			in advanceDistance : LengthValue;
			out movedFabric : Fabric;
		}
	}
	
	part def PresserFoot {
		attribute pressure : ForceValue;
		attribute isLifted : Boolean;
		
		action def ApplyPressure {
			in fabric : Fabric;
			out secured : Boolean;
		}
		
		action def ReleasePressure {
			out released : Boolean;
		}
	}
	
	part def Motor {
		port powerInput : PowerPort;
		port driveOutput : DrivePort;
		attribute currentSpeed : RotationalSpeed;
		attribute targetSpeed : RotationalSpeed;
		
		action def AdjustSpeed {
			in pedalPosition : Real;
			out motorSpeed : RotationalSpeed;
		}
	}
	
	part def FootPedal {
		attribute position : Real;
		attribute isPressed : Boolean;
	}
	
	part def ControlUnit {
		attribute selectedStitchLength : StitchLength;
		attribute selectedPattern : StitchPattern;
		attribute operatingSpeed : RotationalSpeed;
		
		action def ProcessPedalInput {
			in pedalPosition : Real;
			out speedCommand : RotationalSpeed;
		}
		
		action def CoordinateStitchCycle {
			in needlePosition : LengthValue;
			in bobbinAngle : Real;
			out syncSignal : Boolean;
		}
	}
	
	action def ThreadMachine {
		first start;
		then action loadUpperThread {
			out upperThreadLoaded : Boolean;
		}
		then action loadBobbin {
			out bobbinLoaded : Boolean;
		}
		then action threadNeedle {
			out needleThreaded : Boolean;
		}
		then done;
	}
	
	action def PrepareFabric {
		first start;
		then action positionFabric {
			in fabric : Fabric;
			out positioned : Boolean;
		}
		then action lowerPresserFoot {
			out footDown : Boolean;
		}
		then done;
	}
	
	action def FormSingleStitch {
		first start;
		then action needleDescends {
			in upperThread : Thread;
			in fabric : Fabric;
			out penetrated : Boolean;
		}
		then action bobbinCatchesThread {
			in upperThread : Thread;
			in lowerThread : Thread;
			out loopFormed : Boolean;
		}
		then action lockThreads {
			in loopFormed : Boolean;
			out stitchLocked : Boolean;
		}
		then action needleAscends {
			out needleUp : Boolean;
		}
		then done;
	}
	
	action def SewSeam {
		first start;
		then merge stitchLoop;
		
		then action checkFabric {
			out fabricPresent : Boolean;
			out seamComplete : Boolean;
		}
		
		then decide;
			if checkFabric.fabricPresent and !checkFabric.seamComplete then createStitch;
			if checkFabric.seamComplete then finishSeam;
		
		action createStitch : FormSingleStitch {
			in upperThread;
			in lowerThread;
			in fabric;
			out stitchLocked;
		}
		
		then action advanceFabric {
			in stitchLength;
			out fabricAdvanced : Boolean;
		}
		
		then stitchLoop;
		
		action finishSeam;
		then done;
	}
	
	state def SewingMachineStates {
		entry; then off;
		
		state off {
			entry action assignPowerOff {
				assign isPowered = false;
			}
		}
		accept at off then idle if powerOn;
		
		state idle {
			entry action assignIdleState {
				assign isPowered = true;
				assign isOperating = false;
			}
		}
		accept at idle then threading if threadingInitiated;
		accept at idle then ready if machineThreaded;
		
		state threading {
			do action threadingProcess : ThreadMachine;
		}
		accept at threading then ready if threadingComplete;
		
		state ready {
			entry action assignReadyState {
				assign isOperating = false;
			}
		}
		accept at ready then preparing if fabricInserted;
		
		state preparing {
			do action preparationProcess : PrepareFabric;
		}
		accept at preparing then sewing if pedalPressed;
		
		state sewing {
			entry action assignSewingState {
				assign isOperating = true;
			}
			do action sewingProcess : SewSeam;
		}
		accept at sewing then paused if pedalReleased;
		accept at sewing then error if threadBreaks;
		accept at sewing then ready if seamFinished;
		
		state paused {
			entry action assignPausedState {
				assign isOperating = false;
			}
		}
		accept at paused then sewing if pedalPressed;
		accept at paused then ready if fabricRemoved;
		
		state error {
			entry action assignErrorState {
				assign isOperating = false;
				assign errorActive = true;
			}
		}
		accept at error then idle if errorCleared;
		
		attribute isPowered : Boolean;
		attribute isOperating : Boolean;
		attribute errorActive : Boolean;
		
		event powerOn;
		event threadingInitiated;
		event threadingComplete;
		event machineThreaded;
		event fabricInserted;
		event pedalPressed;
		event pedalReleased;
		event threadBreaks;
		event seamFinished;
		event fabricRemoved;
		event errorCleared;
	}
	
	part def SewingMachine {
		attribute selectedStitchLength : StitchLength;
		attribute selectedPattern : StitchPattern;
		attribute currentOperatingSpeed : RotationalSpeed;
		
		part upperSpool : ThreadSpool {
			port :>> supplyPort;
		}
		
		part tensionControl : TensionRegulator {
			port :>> inputPort;
			port :>> outputPort;
		}
		
		part needleAssembly : NeedleBar {
			port :>> threadPort;
		}
		
		part bobbinCase : BobbinAssembly {
			port :>> threadPort;
		}
		
		part feedDog : FeedDogMechanism {
			port :>> fabricPort;
		}
		
		part presser : PresserFoot;
		
		part driveMotor : Motor {
			port :>> powerInput;
			port :>> driveOutput;
		}
		
		part pedal : FootPedal;
		
		part controller : ControlUnit;
		
		connect upperSpool.supplyPort to tensionControl.inputPort;
		connect tensionControl.outputPort to needleAssembly.threadPort;
		
		connector driveTrain {
			end motorEnd : driveMotor.driveOutput;
			end needleEnd : needleAssembly;
			end bobbinEnd : bobbinCase;
			end feedEnd : feedDog;
		}
		
		perform action mainOperation[*] ordered references SewSeam {
			perform createStitch by needleAssembly;
			perform advanceFabric by feedDog;
		}
		
		exhibit state operatingState : SewingMachineStates;
	}
	
	requirement def <'REQ-SM-001'> PrimaryFunctionRequirement {
		doc /* The sewing machine shall join fabric layers by forming interlocked stitches using upper thread from the needle and lower thread from the bobbin. */
		
		subject machine : SewingMachine;
		
		require constraint {
			machine.upperSpool.remainingThread > 0.0 and
			machine.bobbinCase.bobbin.currentThread > 0.0
		}
	}
	
	requirement def <'REQ-SM-002'> StitchFormationRequirement {
		doc /* The sewing machine shall form each stitch by penetrating the fabric with the needle, interlocking the upper and lower threads, and securing the stitch before advancing the fabric. */
		
		subject machine : SewingMachine;
		
		require constraint {
			machine.needleAssembly.position != null and
			machine.bobbinCase.rotationAngle != null
		}
	}
	
	requirement def <'REQ-SM-003'> FabricAdvanceRequirement {
		doc /* The sewing machine shall advance the fabric by the selected stitch length after each stitch is completed. */
		
		subject machine : SewingMachine;
		
		require constraint {
			machine.feedDog.feedLength == machine.selectedStitchLength
		}
	}
	
	requirement def <'REQ-SM-004'> ThreadTensionRequirement {
		doc /* The sewing machine shall maintain consistent thread tension to ensure uniform stitch quality and prevent thread breakage. */
		
		subject machine : SewingMachine;
		
		require constraint {
			machine.tensionControl.tensionSetting != null and
			machine.tensionControl.outputPort.tension == machine.tensionControl.tensionSetting
		}
	}
	
	requirement def <'REQ-SM-005'> SpeedControlRequirement {
		doc /* The sewing machine shall vary its operating speed in response to foot pedal position, from stopped to maximum rated speed. */
		
		subject machine : SewingMachine;
		
		require constraint {
			machine.pedal.position >= 0.0 and
			machine.pedal.position <= 1.0 and
			machine.driveMotor.currentSpeed <= machine.driveMotor.targetSpeed
		}
	}
	
	requirement sewingMachineSystemRequirements {
		doc /* Top-level requirements for the sewing machine system defining its primary function and operational characteristics. */
		
		require PrimaryFunctionRequirement;
		require StitchFormationRequirement;
		require FabricAdvanceRequirement;
		require ThreadTensionRequirement;
		require SpeedControlRequirement;
	}
	
	part completeSewingMachineSystem : SewingMachine {
		satisfy sewingMachineSystemRequirements;
		
		:>> selectedStitchLength = 2.5;
		:>> currentOperatingSpeed = RotationalSpeed(value = 0.0, unit = RotationalSpeedUnit::RPM);
	}
}
