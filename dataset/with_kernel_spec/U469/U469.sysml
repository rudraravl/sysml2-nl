package 'ArtificioDeJuanelo' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		item def Water;

		attribute def StartSignal;
		attribute def StopSignal;
		attribute def BucketFilledSignal;
		attribute def ReachedTopSignal;
		attribute def BucketEmptySignal;
		attribute def ReachedBottomSignal;

		port def WaterOutPort {
			out item water : Water;
		}

		port def WaterInPort {
			in item water : Water;
		}

		port def MechanicalPowerOutPort {
			out torque : TorqueValue;
			out rotationalSpeed : AngularVelocityValue;
		}

		port def MechanicalPowerInPort {
			in torque : TorqueValue;
			in rotationalSpeed : AngularVelocityValue;
		}

		state def WheelOperationStates {
			entry; then idle;
			state idle;
			accept StartSignal then operating;
			state operating;
			accept StopSignal then idle;
		}

		state def BucketCycleStates {
			entry; then filling;
			state filling;
			accept BucketFilledSignal then lifting;
			state lifting;
			accept ReachedTopSignal then discharging;
			state discharging;
			accept BucketEmptySignal then returning;
			state returning;
			accept ReachedBottomSignal then filling;
		}

		part def TagusRiver {
			attribute flowRate : VolumeFlowRateValue = 13.0 [m^3/s];
			port waterOutPort : WaterOutPort;
		}

		part def WaterWheel {
			attribute wheelRadius : LengthValue = 4.0 [m];
			attribute efficiency : Real = 0.70;
			port riverPort : WaterInPort;
			port powerOutPort : MechanicalPowerOutPort;
			state wheelState : WheelOperationStates;
		}

		part def Bucket {
			attribute capacity : VolumeValue = 0.05 [m^3];
			attribute currentVolume : VolumeValue;
			attribute position : LengthValue;
			attribute isFull : Boolean;
			port waterInPort : WaterInPort;
			port waterOutPort : WaterOutPort;
			state bucketState : BucketCycleStates;
		}

		part def BucketChain {
			attribute chainLength : LengthValue = 120.0 [m];
			attribute bucketCount : Integer = 20;
			attribute liftHeight : LengthValue = 100.0 [m];
			port powerInPort : MechanicalPowerInPort;
			port riverAccessPort : WaterInPort;
			port reservoirPort : WaterOutPort;
			part buckets : Bucket[*];
		}

		part def AlcazarReservoir {
			attribute maxVolume : VolumeValue = 500.0 [m^3];
			attribute currentVolume : VolumeValue;
			attribute fillLevel : Real = currentVolume / maxVolume;
			port waterInPort : WaterInPort;
		}

		part def ArtificioDeJuanelo {
			part tagusRiver : TagusRiver;
			part waterWheel : WaterWheel;
			part bucketChain : BucketChain;
			part alcazarReservoir : AlcazarReservoir;
		}

		action def FillBucket {
			in item riverWater : Water;
			out item bucketWater : Water;
		}

		action def LiftBucket {
			in item water : Water;
			in liftHeight : LengthValue;
			out item liftedWater : Water;
		}

		action def DischargeBucket {
			in item bucketWater : Water;
			out item reservoirWater : Water;
		}

		action def ReturnBucket {
			out item emptyBucketReady : Water;
		}

		action def BucketCycle {
			in item riverWater : Water;
			out item reservoirWater : Water;
		}
	}

	package Usages {
		private import Definitions::*;

		part artificio : ArtificioDeJuanelo {
			flow of riverWater : Water
				from tagusRiver.waterOutPort.water to waterWheel.riverPort.water;

			flow of mechanicalPowerTorque : TorqueValue
				from waterWheel.powerOutPort.torque to bucketChain.powerInPort.torque;
			flow of mechanicalPowerSpeed : AngularVelocityValue
				from waterWheel.powerOutPort.rotationalSpeed to bucketChain.powerInPort.rotationalSpeed;

			flow of riverWaterToBuckets : Water
				from tagusRiver.waterOutPort.water to bucketChain.riverAccessPort.water;

			flow of dischargedWater : Water
				from bucketChain.reservoirPort.water to alcazarReservoir.waterInPort.water;
		}

		action bucketCycle : BucketCycle {
			in item riverWater : Water;
			out item reservoirWater : Water;

			loop {
				action fillBucket : FillBucket {
					in item riverWater = bucketCycle::riverWater;
					out item bucketWater : Water;
				}
				flow fillBucket.bucketWater to liftBucket.water;

				action liftBucket : LiftBucket {
					in item water : Water;
					in liftHeight : LengthValue = 100.0 [m];
					out item liftedWater : Water;
				}
				flow liftBucket.liftedWater to dischargeBucket.bucketWater;

				action dischargeBucket : DischargeBucket {
					in item bucketWater : Water;
					out item reservoirWater : Water;
				}

				action returnBucket : ReturnBucket {
					out item emptyBucketReady : Water;
				}
			}
		}
	}

	package Requirements {
		private import Definitions::*;

		requirement def LiftHeightRequirement {
			doc /* The machine shall lift water approximately 100 meters from the Tagus River to the Alcazar. */
			attribute requiredLiftHeight : LengthValue = 100.0 [m];
		}

		requirement def WaterDeliveryRequirement {
			doc /* The machine shall deliver a steady supply of water to the Alcazar reservoir. */
			attribute requiredDailyVolume : VolumeValue = 300.0 [m^3];
		}

		requirement def PowerSourceRequirement {
			doc /* The machine shall be powered entirely by the natural current of the Tagus River. */
			attribute requiredFlowRate : VolumeFlowRateValue = 13.0 [m^3/s];
		}

		requirement def ContinuousOperationRequirement {
			doc /* The bucket chain shall operate as a continuous cycle: fill, lift, discharge, return. */
			attribute requiredBucketCount : Integer = 20;
		}

		requirement artificioLiftHeight : LiftHeightRequirement {
			subject artificio : ArtificioDeJuanelo;
			require artificio.bucketChain.liftHeight >= requiredLiftHeight;
		}

		requirement artificioPowerSource : PowerSourceRequirement {
			subject artificio : ArtificioDeJuanelo;
			require artificio.tagusRiver.flowRate >= requiredFlowRate;
		}

		requirement artificioContinuousOperation : ContinuousOperationRequirement {
			subject artificio : ArtificioDeJuanelo;
			require artificio.bucketChain.bucketCount >= requiredBucketCount;
		}

		requirement artificioWaterDelivery : WaterDeliveryRequirement {
			subject artificio : ArtificioDeJuanelo;
			require artificio.alcazarReservoir.maxVolume >= requiredDailyVolume;
		}
	}
}
