package SaqiyahSystem {
	private import ISQ::*;
	private import SI::*;

	item def Water;

	attribute def StartSignal;
	attribute def StopSignal;

	port def MechanicalPowerPort {
		out torque : TorqueValue;
		out speed : RotationalSpeedValue;
	}

	part def Animal {
		port mechanicalOut : MechanicalPowerPort;
		attribute walkingSpeed : SpeedValue;
	}

	part def HorizontalGearWheel {
		port mechanicalIn : ~MechanicalPowerPort;
		port mechanicalOut : MechanicalPowerPort;
		attribute radius : LengthValue;
		attribute gearRatio : Real;
	}

	part def VerticalWaterWheel {
		port mechanicalIn : ~MechanicalPowerPort;
		port mechanicalOut : MechanicalPowerPort;
		attribute radius : LengthValue;
	}

	part def Bucket {
		attribute capacity : VolumeValue;
	}

	part def BucketChain {
		port mechanicalIn : ~MechanicalPowerPort;
		in sourceWater : Water;
		out dischargedWater : Water;
		part buckets : Bucket[*];
		attribute liftHeight : LengthValue;
		attribute bucketCapacity : VolumeValue;
	}

	part def Well {
		out water : Water;
		attribute waterLevel : LengthValue;
	}

	part def IrrigationChannel {
		in water : Water;
		attribute elevation : LengthValue;
	}

	action def FillBucket {
		in emptyBucket : Bucket;
		in water : Water;
		out filledBucket : Bucket;
	}

	action def AscendBucket {
		in filledBucket : Bucket;
		out liftedBucket : Bucket;
	}

	action def DischargeBucket {
		in liftedBucket : Bucket;
		out dischargedWater : Water;
		out emptyBucket : Bucket;
	}

	action def DescendBucket {
		in emptyBucket : Bucket;
		out descendedBucket : Bucket;
	}

	action def LiftWaterCycle {
		action fill : FillBucket;
		action ascend : AscendBucket;
		action discharge : DischargeBucket;
		action descend : DescendBucket;

		flow descend.descendedBucket to fill.emptyBucket;
		flow fill.filledBucket to ascend.filledBucket;
		flow ascend.liftedBucket to discharge.liftedBucket;
		flow discharge.emptyBucket to descend.emptyBucket;
	}

	state def SaqiyahStates;

	requirement def LiftHeightRequirement {
		doc /* The system shall lift water to the specified height. */
		attribute requiredHeight : LengthValue;
		attribute actualHeight : LengthValue;
		require constraint { actualHeight >= requiredHeight }
	}

	requirement def FlowRateRequirement {
		doc /* The system shall deliver a consistent flow rate. */
		attribute requiredFlowRate : VolumeFlowRateValue;
		attribute actualFlowRate : VolumeFlowRateValue;
		require constraint { actualFlowRate >= requiredFlowRate }
	}

	part def Saqiyah {
		port commandPort {
			in start : StartSignal;
			in stop : StopSignal;
		}

		attribute liftHeight : LengthValue;
		attribute flowRate : VolumeFlowRateValue;

		part animal : Animal;
		part horizontalWheel : HorizontalGearWheel;
		part verticalWheel : VerticalWaterWheel;
		part bucketChain : BucketChain;
		part well : Well;
		part channel : IrrigationChannel;

		interface animalToHorizontal connect animal.mechanicalOut to horizontalWheel.mechanicalIn {
			flow torqueFlow of TorqueValue from animal.mechanicalOut.torque to horizontalWheel.mechanicalIn.torque;
			flow speedFlow of RotationalSpeedValue from animal.mechanicalOut.speed to horizontalWheel.mechanicalIn.speed;
		}

		interface horizontalToVertical connect horizontalWheel.mechanicalOut to verticalWheel.mechanicalIn {
			flow torqueFlow of TorqueValue from horizontalWheel.mechanicalOut.torque to verticalWheel.mechanicalIn.torque;
			flow speedFlow of RotationalSpeedValue from horizontalWheel.mechanicalOut.speed to verticalWheel.mechanicalIn.speed;
		}

		interface verticalToChain connect verticalWheel.mechanicalOut to bucketChain.mechanicalIn {
			flow torqueFlow of TorqueValue from verticalWheel.mechanicalOut.torque to bucketChain.mechanicalIn.torque;
			flow speedFlow of RotationalSpeedValue from verticalWheel.mechanicalOut.speed to bucketChain.mechanicalIn.speed;
		}

		flow waterIntakeFlow of Water from well.water to bucketChain.sourceWater;
		flow waterDischargeFlow of Water from bucketChain.dischargedWater to channel.water;

		state saqiyahState : SaqiyahStates {
			entry; then idle;
			state idle;
			accept StartSignal then active;
			state active;
			accept StopSignal then idle;
		}

		action liftWater : LiftWaterCycle;

		requirement liftHeightReq : LiftHeightRequirement {
			attribute redefines requiredHeight = 10[m];
			attribute redefines actualHeight = bucketChain.liftHeight;
		}

		requirement flowRateReq : FlowRateRequirement {
			attribute redefines requiredFlowRate = 0.05[m^3/s];
			attribute redefines actualFlowRate = flowRate;
		}

		satisfy liftHeightReq;
		satisfy flowRateReq;
	}
}
