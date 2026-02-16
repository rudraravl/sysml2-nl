package 'Hydraulic Ram System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FluidType;
	attribute def Water :> FluidType;
	
	item def HydraulicFluid {
		attribute fluidType : FluidType;
		attribute density : ISQ::MassDensityValue;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	port def FluidPort {
		attribute pressure : ISQ::PressureValue;
		attribute flowRate : ISQ::VolumeFlowRateValue;
		attribute velocity : ISQ::SpeedValue;
		in item fluid : HydraulicFluid;
	}
	
	enum def ValveState {
		open;
		closed;
	}
	
	part def WaterSource {
		attribute sourceHead : ISQ::LengthValue;
		attribute availableFlow : ISQ::VolumeFlowRateValue;
		port outlet : FluidPort;
	}
	
	part def DrivePipe {
		attribute length : ISQ::LengthValue;
		attribute diameter : ISQ::LengthValue;
		attribute flowVelocity : ISQ::SpeedValue;
		port inlet : FluidPort;
		port outlet : FluidPort;
	}
	
	part def ImpulseValve {
		attribute valveState : ValveState;
		attribute closingVelocity : ISQ::SpeedValue;
		attribute openingPressure : ISQ::PressureValue;
		port inlet : FluidPort;
		port wasteOutlet : FluidPort;
	}
	
	part def CheckValve {
		attribute valveState : ValveState;
		attribute crackingPressure : ISQ::PressureValue;
		port inlet : FluidPort;
		port outlet : FluidPort;
	}
	
	part def AirChamber {
		attribute volume : ISQ::VolumeValue;
		attribute airPressure : ISQ::PressureValue;
		attribute waterVolume : ISQ::VolumeValue;
		port inlet : FluidPort;
		port outlet : FluidPort;
	}
	
	part def DeliveryPipe {
		attribute length : ISQ::LengthValue;
		attribute diameter : ISQ::LengthValue;
		port inlet : FluidPort;
		port outlet : FluidPort;
	}
	
	part def DeliveryReservoir {
		attribute elevation : ISQ::LengthValue;
		attribute capacity : ISQ::VolumeValue;
		attribute currentVolume : ISQ::VolumeValue;
		port inlet : FluidPort;
	}
	
	part def WasteOutlet {
		port inlet : FluidPort;
	}
	
	attribute def CycleStart;
	attribute def CycleComplete;
	
	action def AccelerateFlow {
		in sourceHead : ISQ::LengthValue;
		in pipeLength : ISQ::LengthValue;
		out flowVelocity : ISQ::SpeedValue;
	}
	
	action def GenerateWaterHammer {
		in flowVelocity : ISQ::SpeedValue;
		in fluidDensity : ISQ::MassDensityValue;
		out pressureSpike : ISQ::PressureValue;
	}
	
	action def CompressAir {
		in pressureSpike : ISQ::PressureValue;
		in chamberVolume : ISQ::VolumeValue;
		out storedPressure : ISQ::PressureValue;
		out storedVolume : ISQ::VolumeValue;
	}
	
	action def DeliverWater {
		in storedPressure : ISQ::PressureValue;
		in storedVolume : ISQ::VolumeValue;
		in deliveryHead : ISQ::LengthValue;
		out deliveredVolume : ISQ::VolumeValue;
	}
	
	action def MonitorPressure {
		in currentPressure : ISQ::PressureValue;
		in thresholdPressure : ISQ::PressureValue;
		out aboveThreshold : Boolean;
	}
	
	state def HydraulicRamCycle {
		attribute driveVelocity : ISQ::SpeedValue;
		attribute chamberPressure : ISQ::PressureValue;
		attribute impulseValveOpen : Boolean;
		attribute checkValveOpen : Boolean;
		
		entry; then Idle;
		
		state Idle;
		
		state Acceleration {
			doc /* Water flows down drive pipe, accelerating through open impulse valve. */
			entry assign impulseValveOpen := true;
			entry assign checkValveOpen := false;
		}
		
		state WaterHammer {
			doc /* Impulse valve slams shut, creating pressure spike. */
			entry assign impulseValveOpen := false;
		}
		
		state Compression {
			doc /* Pressure spike opens check valve, compressing air and storing water. */
			entry assign checkValveOpen := true;
		}
		
		state Delivery {
			doc /* Compressed air expands, pushing stored water to delivery reservoir. */
		}
		
		state Recoil {
			doc /* Pressure drops, check valve closes, impulse valve reopens. */
			entry assign checkValveOpen := false;
		}
		
		transition first Idle then Acceleration;
		
		transition first Acceleration
			accept CycleStart
			if driveVelocity > 1.5[SI::m/SI::s]
			then WaterHammer;
		
		transition first WaterHammer
			if chamberPressure > 100000[SI::Pa]
			then Compression;
		
		transition first Compression then Delivery;
		
		transition first Delivery
			if chamberPressure < 50000[SI::Pa]
			then Recoil;
		
		transition first Recoil
			accept CycleComplete
			then Acceleration;
	}
	
	action def OperateHydraulicRam {
		in sourceHead : ISQ::LengthValue;
		in deliveryHead : ISQ::LengthValue;
		in pipeLength : ISQ::LengthValue;
		in chamberVolume : ISQ::VolumeValue;
		in fluidDensity : ISQ::MassDensityValue;
		out totalDelivered : ISQ::VolumeValue;
		
		private attribute accumulatedVolume : ISQ::VolumeValue := 0[SI::m^3];
		
		first start;
		then merge cycleLoop;
		
		then action accelerate : AccelerateFlow {
			in sourceHead = sourceHead;
			in pipeLength = pipeLength;
			out flowVelocity;
		}
		
		then action hammer : GenerateWaterHammer {
			in flowVelocity = accelerate.flowVelocity;
			in fluidDensity = fluidDensity;
			out pressureSpike;
		}
		
		then action compress : CompressAir {
			in pressureSpike = hammer.pressureSpike;
			in chamberVolume = chamberVolume;
			out storedPressure;
			out storedVolume;
		}
		
		then action deliver : DeliverWater {
			in storedPressure = compress.storedPressure;
			in storedVolume = compress.storedVolume;
			in deliveryHead = deliveryHead;
			out deliveredVolume;
		}
		
		then assign accumulatedVolume := accumulatedVolume + deliver.deliveredVolume;
		then assign totalDelivered := accumulatedVolume;
		then cycleLoop;
	}
	
	requirement def PumpingEfficiencyRequirement {
		doc /* The hydraulic ram shall deliver water to elevated reservoir using only kinetic energy from source flow. */
		
		require constraint efficiencyConstraint {
			attribute deliveryHead : ISQ::LengthValue;
			attribute sourceHead : ISQ::LengthValue;
			attribute deliveryFlow : ISQ::VolumeFlowRateValue;
			attribute sourceFlow : ISQ::VolumeFlowRateValue;
			deliveryHead > sourceHead and deliveryFlow > 0[SI::m^3/SI::s]
		}
	}
	
	requirement def DeliveryHeadRequirement {
		doc /* The hydraulic ram shall pump water to minimum specified elevation above source. */
		
		require constraint headConstraint {
			attribute actualDeliveryHead : ISQ::LengthValue;
			attribute requiredDeliveryHead : ISQ::LengthValue;
			actualDeliveryHead >= requiredDeliveryHead
		}
	}
	
	requirement def ContinuousOperationRequirement {
		doc /* The hydraulic ram shall operate continuously through automatic cycling without external power. */
		
		require constraint cyclingConstraint {
			attribute cycleFrequency : ISQ::FrequencyValue;
			attribute minimumFrequency : ISQ::FrequencyValue;
			cycleFrequency >= minimumFrequency
		}
	}
	
	requirement def PressureSafetyRequirement {
		doc /* The hydraulic ram components shall withstand maximum water hammer pressure. */
		
		require constraint pressureConstraint {
			attribute maxOperatingPressure : ISQ::PressureValue;
			attribute componentRating : ISQ::PressureValue;
			maxOperatingPressure <= componentRating
		}
	}
	
	part def HydraulicRamSystem {
		doc /* 
		This system describes a hydraulic ram pump that converts the kinetic energy of flowing water 
		into pressure energy to pump a portion of that water to a higher elevation.
		
		The system's primary function is to automatically and continuously pump water from a low-head 
		source to a high-head delivery point without requiring external power. It operates by exploiting 
		the water hammer effect in a self-acting cyclic process.
		
		The process begins with water flowing from the source down a drive pipe, accelerating under 
		gravity. This flow exits through an open impulse valve. As the flow velocity increases, the 
		impulse valve suddenly closes, creating a pressure spike (water hammer effect) in the drive pipe. 
		This pressure spike forces open a check valve, allowing a small amount of water to enter an air 
		chamber where it compresses the air and is stored under pressure.
		
		The compressed air then acts as a spring, expanding and pushing the stored water up through a 
		delivery pipe to the elevated reservoir. As the air expands and pressure drops, the check valve 
		closes to prevent backflow. The reduced pressure in the drive pipe allows the impulse valve to 
		reopen, and the cycle repeats automatically.
		
		This continuous cycling converts the energy from a large volume of low-head water into pumping 
		a smaller volume to a much higher elevation, making it ideal for remote locations where 
		electricity is unavailable but flowing water is present.
		*/
		
		attribute sourceElevation : ISQ::LengthValue;
		attribute deliveryElevation : ISQ::LengthValue;
		attribute driveLength : ISQ::LengthValue;
		attribute driveDiameter : ISQ::LengthValue;
		attribute chamberSize : ISQ::VolumeValue;
		
		part source : WaterSource;
		part drivePipe : DrivePipe;
		part impulseValve : ImpulseValve;
		part checkValve : CheckValve;
		part airChamber : AirChamber;
		part deliveryPipe : DeliveryPipe;
		part deliveryReservoir : DeliveryReservoir;
		part wasteOutlet : WasteOutlet;
		part workingFluid : HydraulicFluid;
		
		requirement pumpingReq : PumpingEfficiencyRequirement;
		requirement headReq : DeliveryHeadRequirement;
		requirement operationReq : ContinuousOperationRequirement;
		requirement safetyReq : PressureSafetyRequirement;
	}
	
	part hydraulicRamSystem : HydraulicRamSystem {
		attribute sourceElevation = 0[SI::m];
		attribute deliveryElevation = 20[SI::m];
		attribute driveLength = 10[SI::m];
		attribute driveDiameter = 0.05[SI::m];
		attribute chamberSize = 0.02[SI::m^3];
		
		part source : WaterSource {
			attribute sourceHead = 2[SI::m];
			attribute availableFlow = 0.01[SI::m^3/SI::s];
		}
		
		part drivePipe : DrivePipe {
			attribute length = driveLength;
			attribute diameter = driveDiameter;
			attribute flowVelocity = 0[SI::m/SI::s];
		}
		
		part impulseValve : ImpulseValve {
			attribute valveState = ValveState::open;
			attribute closingVelocity = 2[SI::m/SI::s];
			attribute openingPressure = 50000[SI::Pa];
		}
		
		part checkValve : CheckValve {
			attribute valveState = ValveState::closed;
			attribute crackingPressure = 150000[SI::Pa];
		}
		
		part airChamber : AirChamber {
			attribute volume = chamberSize;
			attribute airPressure = 100000[SI::Pa];
			attribute waterVolume = 0[SI::m^3];
		}
		
		part deliveryPipe : DeliveryPipe {
			attribute length = 25[SI::m];
			attribute diameter = 0.025[SI::m];
		}
		
		part deliveryReservoir : DeliveryReservoir {
			attribute elevation = deliveryElevation;
			attribute capacity = 1[SI::m^3];
			attribute currentVolume = 0[SI::m^3];
		}
		
		part wasteOutlet : WasteOutlet;
		
		part workingFluid : HydraulicFluid {
			attribute fluidType = Water;
			attribute density = 1000[SI::kg/SI::m^3];
			attribute temperature = 293[SI::K];
		}
		
		connect source.outlet to drivePipe.inlet;
		connect drivePipe.outlet to impulseValve.inlet;
		connect drivePipe.outlet to checkValve.inlet;
		connect impulseValve.wasteOutlet to wasteOutlet.inlet;
		connect checkValve.outlet to airChamber.inlet;
		connect airChamber.outlet to deliveryPipe.inlet;
		connect deliveryPipe.outlet to deliveryReservoir.inlet;
		
		exhibit state pumpCycle : HydraulicRamCycle;
		
		perform action operate : OperateHydraulicRam {
			in sourceHead = source.sourceHead;
			in deliveryHead = deliveryElevation - sourceElevation;
			in pipeLength = drivePipe.length;
			in chamberVolume = airChamber.volume;
			in fluidDensity = workingFluid.density;
			out totalDelivered;
		}
		
		satisfy pumpingReq;
		satisfy headReq;
		satisfy operationReq;
		satisfy safetyReq;
	}
}
