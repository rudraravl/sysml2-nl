package 'Peristaltic Pumping Subsystem' {
	private import ScalarValues::*;
	
	attribute def VolumeUnit :> Real;
	attribute def FlowRateUnit :> Real;
	attribute def PressureUnit :> Real;
	attribute def RotationSpeedUnit :> Real;
	attribute def ViscosityUnit :> Real;
	attribute def TemperatureUnit :> Real;
	attribute def PowerUnit :> Real;
	attribute def VoltageUnit :> Real;
	attribute def CurrentUnit :> Real;
	
	enum def OperatingStatus {
		enum idle;
		enum priming;
		enum running;
		enum stopping;
		enum faulted;
	}
	
	enum def RollerPosition {
		enum roller1;
		enum roller2;
		enum roller3;
	}
	
	item def Fluid {
		attribute volume : VolumeUnit;
		attribute viscosity : ViscosityUnit;
		attribute temperature : TemperatureUnit;
		attribute density : Real;
	}
	
	port def FluidInPort {
		attribute inletPressure : PressureUnit;
		in item fluidIn : Fluid;
	}
	
	port def FluidOutPort {
		attribute outletPressure : PressureUnit;
		out item fluidOut : Fluid;
	}
	
	port def PowerInPort {
		attribute voltage : VoltageUnit;
		attribute current : CurrentUnit;
	}
	
	port def ControlPort {
		in attribute commandedSpeed : RotationSpeedUnit;
		out attribute actualSpeed : RotationSpeedUnit;
		out attribute status : OperatingStatus;
	}
	
	part def FlexibleTubing {
		attribute innerDiameter : Real;
		attribute outerDiameter : Real;
		attribute wallThickness : Real;
		attribute elasticity : Real;
		attribute maxCompressionCycles : Integer;
		attribute currentCycles : Integer;
		
		port tubeInlet : FluidInPort;
		port tubeOutlet : FluidOutPort;
	}
	
	part def RotorAssembly {
		attribute numberOfRollers : Integer;
		attribute rollerDiameter : Real;
		attribute rotorRadius : Real;
		attribute currentAngle : Real;
		attribute rotationSpeed : RotationSpeedUnit;
		
		part rollers[3] {
			attribute position : RollerPosition;
			attribute compressionDepth : Real;
		}
	}
	
	part def DriveMotor {
		attribute ratedPower : PowerUnit;
		attribute maxSpeed : RotationSpeedUnit;
		attribute currentSpeed : RotationSpeedUnit;
		attribute outputTorque : Real;
		
		port powerInput : ~PowerInPort;
		port controlInput : ~ControlPort;
	}
	
	part def PumpHousing {
		attribute housingDiameter : Real;
		attribute compressionTrackLength : Real;
		
		part occlusionBed {
			attribute bedRadius : Real;
			attribute compressionAngle : Real;
		}
	}
	
	part def PeristalticPump {
		attribute designFlowRate : FlowRateUnit;
		attribute maxOperatingPressure : PressureUnit;
		attribute currentStatus : OperatingStatus;
		attribute volumePerRevolution : VolumeUnit;
		
		port fluidInlet : FluidInPort;
		port fluidOutlet : FluidOutPort;
		port controlInterface : ~ControlPort;
		port powerInterface : ~PowerInPort;
		
		part motor : DriveMotor;
		part rotor : RotorAssembly;
		part tubing : FlexibleTubing;
		part housing : PumpHousing;
		
		connection motorToRotor connect motor to rotor;
		
		flow fluidInlet.fluidIn to tubing.tubeInlet.fluidIn;
		flow tubing.tubeOutlet.fluidOut to fluidOutlet.fluidOut;
		
		bind controlInterface = motor.controlInput;
		bind powerInterface = motor.powerInput;
		
		assert constraint pressureLimit {
			fluidOutlet.outletPressure <= maxOperatingPressure
		}
		
		assert constraint flowRateCalculation {
			fluidOutlet.fluidOut.volume == volumePerRevolution * motor.currentSpeed / 60.0
		}
	}
	
	part def FluidReservoir {
		attribute capacity : VolumeUnit;
		attribute currentLevel : VolumeUnit;
		attribute minimumLevel : VolumeUnit;
		
		port outlet : FluidOutPort;
		
		item storedFluid : Fluid {
			attribute :>> volume = currentLevel;
		}
	}
	
	part def ReceivingTank {
		attribute capacity : VolumeUnit;
		attribute currentLevel : VolumeUnit;
		attribute maximumLevel : VolumeUnit;
		
		port inlet : FluidInPort;
		
		item receivedFluid : Fluid {
			attribute :>> volume = currentLevel;
		}
	}
	
	part def PumpController {
		attribute targetFlowRate : FlowRateUnit;
		attribute measuredFlowRate : FlowRateUnit;
		attribute controlGain : Real;
		
		port controlOutput : ControlPort;
	}
	
	part def PowerSupply {
		attribute outputVoltage : VoltageUnit;
		attribute maxCurrent : CurrentUnit;
		attribute outputPower : PowerUnit;
		
		port powerOutput : PowerInPort;
	}
	
	action def CompressFluidSegment {
		in attribute rollerPos : RollerPosition;
		in attribute compressionRatio : Real;
		in item fluidSegment : Fluid;
		out attribute displacedVolume : VolumeUnit;
	}
	
	action def RotateRotorStep {
		in attribute targetSpeed : RotationSpeedUnit;
		in attribute currentPosition : Real;
		out attribute newPosition : Real;
		out attribute achievedSpeed : RotationSpeedUnit;
	}
	
	action def PrimePump {
		in item initialFluid : Fluid;
		out item primedFluid : Fluid;
		out attribute primeComplete : Boolean;
	}
	
	action def TransferFluid {
		in attribute commandedFlowRate : FlowRateUnit;
		in item inputFluid : Fluid;
		out item outputFluid : Fluid;
		out attribute actualFlowRate : FlowRateUnit;
		
		first start;
		then action prime : PrimePump {
			in initialFluid = inputFluid;
		}
		then merge pumpingCycle;
		then action rotateStep : RotateRotorStep {
			in targetSpeed = commandedFlowRate * 60.0 / 0.5;
		}
		then action compress1 : CompressFluidSegment {
			in rollerPos = RollerPosition::roller1;
			in compressionRatio = 1.0;
			in fluidSegment = prime.primedFluid;
		}
		then action compress2 : CompressFluidSegment {
			in rollerPos = RollerPosition::roller2;
			in compressionRatio = 1.0;
			in fluidSegment = prime.primedFluid;
		}
		then action compress3 : CompressFluidSegment {
			in rollerPos = RollerPosition::roller3;
			in compressionRatio = 1.0;
			in fluidSegment = prime.primedFluid;
		}
		then decide;
			if rotateStep.achievedSpeed > 0.0 then pumpingCycle;
			if rotateStep.achievedSpeed == 0.0 then stopTransfer;
		action stopTransfer;
		then done;
		
		bind outputFluid = compress3.fluidSegment;
		bind actualFlowRate = rotateStep.achievedSpeed * 0.5 / 60.0;
	}
	
	action def AdjustSpeed {
		in attribute targetFlow : FlowRateUnit;
		in attribute measuredFlow : FlowRateUnit;
		in attribute gainFactor : Real;
		out attribute speedCommand : RotationSpeedUnit;
	}
	
	action def MonitorPressure {
		in attribute currentPressure : PressureUnit;
		in attribute maxPressure : PressureUnit;
		out attribute pressureOK : Boolean;
	}
	
	message StartCommand;
	message StopCommand;
	message ResetCommand;
	
	state def PumpOperationStates {
		entry; then idleState;
		
		state idleState {
			entry assign currentStatus = OperatingStatus::idle;
		}
		
		transition idleToStart
			first idleState
			accept StartCommand
			then primingState;
		
		state primingState {
			entry assign currentStatus = OperatingStatus::priming;
			do action primePump : PrimePump;
		}
		
		transition primingToRunning
			first primingState
			if primingState.primePump.primeComplete == true
			then runningState;
		
		state runningState {
			entry assign currentStatus = OperatingStatus::running;
			do action transferFluid : TransferFluid;
		}
		
		transition runningToStopping
			first runningState
			accept StopCommand
			then stoppingState;
		
		transition runningToFault
			first runningState
			if fluidOutlet.outletPressure > maxOperatingPressure
			then faultedState;
		
		state stoppingState {
			entry assign currentStatus = OperatingStatus::stopping;
			do action decelerate {
				out rampDownSpeed : RotationSpeedUnit;
			}
		}
		
		transition stoppingToIdle
			first stoppingState
			if stoppingState.decelerate.rampDownSpeed == 0.0
			then idleState;
		
		state faultedState {
			entry assign currentStatus = OperatingStatus::faulted;
		}
		
		transition faultToIdle
			first faultedState
			accept ResetCommand
			then idleState;
	}
	
	requirement def FlowRateAccuracyReq {
		subject pump : PeristalticPump;
		
		doc /* The pump shall maintain flow rate within ±3% of commanded value */
		
		require accuracyTolerance {
			assume commandedFlow : FlowRateUnit;
			assert constraint {
				(pump.fluidOutlet.fluidOut.volume >= commandedFlow * 0.97) &
				(pump.fluidOutlet.fluidOut.volume <= commandedFlow * 1.03)
			}
		}
	}
	
	requirement def PressureLimitReq {
		subject pump : PeristalticPump;
		
		doc /* The pump shall not exceed maximum operating pressure */
		
		assert constraint {
			pump.fluidOutlet.outletPressure <= pump.maxOperatingPressure
		}
	}
	
	requirement def TubingLifetimeReq {
		subject tubing : FlexibleTubing;
		
		doc /* Tubing shall be replaced before exceeding maximum compression cycles */
		
		assert constraint {
			tubing.currentCycles < tubing.maxCompressionCycles
		}
	}
	
	requirement def FluidCompatibilityReq {
		subject fluid : Fluid;
		
		doc /* System shall handle fluids with viscosity 1-500 cP and temperature 5-60°C */
		
		require viscosityRange {
			assert constraint {
				(fluid.viscosity >= 1.0) & (fluid.viscosity <= 500.0)
			}
		}
		
		require temperatureRange {
			assert constraint {
				(fluid.temperature >= 5.0) & (fluid.temperature <= 60.0)
			}
		}
	}
	
	requirement def SelfPrimingReq {
		subject pump : PeristalticPump;
		
		doc /* Pump shall self-prime within 10 seconds from dry start */
		
		attribute maxPrimeTime : Real = 10.0;
	}
	
	part pumpingSystem {
		part sourceReservoir : FluidReservoir {
			attribute :>> capacity = 10000.0;
			attribute :>> currentLevel = 8500.0;
			attribute :>> minimumLevel = 1000.0;
			
			item :>> storedFluid {
				attribute :>> viscosity = 25.0;
				attribute :>> temperature = 22.0;
				attribute :>> density = 1.05;
			}
		}
		
		part pump : PeristalticPump {
			attribute :>> designFlowRate = 150.0;
			attribute :>> maxOperatingPressure = 250.0;
			attribute :>> currentStatus = OperatingStatus::idle;
			attribute :>> volumePerRevolution = 2.5;
			
			part :>> motor {
				attribute :>> ratedPower = 75.0;
				attribute :>> maxSpeed = 600.0;
				attribute :>> currentSpeed = 0.0;
				attribute :>> outputTorque = 1.2;
			}
			
			part :>> rotor {
				attribute :>> numberOfRollers = 3;
				attribute :>> rollerDiameter = 18.0;
				attribute :>> rotorRadius = 45.0;
				attribute :>> currentAngle = 0.0;
				attribute :>> rotationSpeed = 0.0;
			}
			
			part :>> tubing {
				attribute :>> innerDiameter = 8.0;
				attribute :>> outerDiameter = 12.0;
				attribute :>> wallThickness = 2.0;
				attribute :>> elasticity = 0.9;
				attribute :>> maxCompressionCycles = 2000000;
				attribute :>> currentCycles = 125000;
			}
			
			part :>> housing {
				attribute :>> housingDiameter = 150.0;
				attribute :>> compressionTrackLength = 140.0;
				
				part :>> occlusionBed {
					attribute :>> bedRadius = 45.0;
					attribute :>> compressionAngle = 180.0;
				}
			}
			
			perform state operationControl : PumpOperationStates;
		}
		
		part receivingTank : ReceivingTank {
			attribute :>> capacity = 8000.0;
			attribute :>> currentLevel = 2000.0;
			attribute :>> maximumLevel = 7500.0;
		}
		
		part controller : PumpController {
			attribute :>> targetFlowRate = 150.0;
			attribute :>> measuredFlowRate = 0.0;
			attribute :>> controlGain = 0.8;
		}
		
		part powerSupply : PowerSupply {
			attribute :>> outputVoltage = 24.0;
			attribute :>> maxCurrent = 5.0;
			attribute :>> outputPower = 120.0;
		}
		
		flow of transferredFluid : Fluid
			from sourceReservoir.outlet.fluidOut
			to pump.fluidInlet.fluidIn;
		
		flow of transferredFluid : Fluid
			from pump.fluidOutlet.fluidOut
			to receivingTank.inlet.fluidIn;
		
		connection controlConnection
			connect controller.controlOutput to pump.controlInterface;
		
		connection powerConnection
			connect powerSupply.powerOutput to pump.powerInterface;
		
		satisfy flowAccuracyReq : FlowRateAccuracyReq {
			subject pumpSubject = pump;
		}
		
		satisfy pressureLimitReq : PressureLimitReq {
			subject pumpSubject = pump;
		}
		
		satisfy tubingLifeReq : TubingLifetimeReq {
			subject tubingSubject = pump.tubing;
		}
		
		satisfy fluidCompatReq : FluidCompatibilityReq {
			subject fluidSubject = sourceReservoir.storedFluid;
		}
		
		satisfy selfPrimeReq : SelfPrimingReq {
			subject pumpSubject = pump;
		}
	}
}
