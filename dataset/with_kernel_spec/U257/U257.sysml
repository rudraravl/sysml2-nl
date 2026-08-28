package IncentiveSpirometerSystem {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import SI::*;
	
	value def VolumeValue : Real;
	value def TimeValue : Real;
	value def FlowRateValue : Real;
	
	package Definitions {
		item def Air;
		
		port def AirFlowPort {
			out item air : Air;
		}
		
		part def BaseUnit {
			attribute isStable : Boolean = true;
		}
		
		part def MeasurementChamber {
			attribute isTransparent : Boolean = true;
			attribute volumeScaleMax : VolumeValue = 4000 [SI::milliliter];
			attribute targetVolume : VolumeValue = 2500 [SI::milliliter];
			port airInPort : ~AirFlowPort;
			
			part volumePiston {
				attribute currentVolume : VolumeValue = 0 [SI::milliliter];
				attribute position : Real = 0.0;
			}
			
			event occurrence targetReached;
		}
		
		part def FlowRateCoach {
			attribute optimalMin : FlowRateValue = 300 [SI::milliliter / SI::second];
			attribute optimalMax : FlowRateValue = 600 [SI::milliliter / SI::second];
			port airInPort : ~AirFlowPort;
			port airOutPort : AirFlowPort;
			
			part indicatorBall {
				attribute currentFlowRate : FlowRateValue = 0 [SI::milliliter / SI::second];
				attribute position : Real = 0.0;
			}
			
			flow of air : Air
				from airInPort.air to airOutPort.air;
		}
		
		part def Mouthpiece {
			port airOutPort : AirFlowPort;
		}
		
		part def FlexibleTube {
			port end1 : ~AirFlowPort;
			port end2 : AirFlowPort;
		}
		
		part def Patient {
			attribute lungCapacity : VolumeValue;
			port mouthPort : ~AirFlowPort;
		}
		
		part def IncentiveSpirometer {
			part baseUnit : BaseUnit;
			part measurementChamber : MeasurementChamber;
			part flowRateCoach : FlowRateCoach;
			part mouthpiece : Mouthpiece;
			part flexibleTube : FlexibleTube;
			
			attribute recommendedHoldTime : TimeValue = 5 [SI::second];
			attribute holdTimer : TimeValue = 0 [SI::second];
			attribute exhaleComplete : Boolean = false;
			
			flow of air : Air
				from mouthpiece.airOutPort.air to flexibleTube.end1.air;
			flow of air : Air
				from flexibleTube.end2.air to flowRateCoach.airInPort.air;
			flow of air : Air
				from flowRateCoach.airOutPort.air to measurementChamber.airInPort.air;
			
			state exerciseBehavior {
				entry;
				then inhaling;
				
				state inhaling;
				
				transition inhale_to_hold
					first inhaling
					if measurementChamber.volumePiston.currentVolume >= measurementChamber.targetVolume
						and flowRateCoach.indicatorBall.currentFlowRate >= flowRateCoach.optimalMin
						and flowRateCoach.indicatorBall.currentFlowRate <= flowRateCoach.optimalMax
					then holding;
				
				state holding;
				
				transition hold_to_exhale
					first holding
					if holdTimer >= recommendedHoldTime
					then exhaling;
				
				state exhaling;
				
				transition exhale_to_reset
					first exhaling
					if exhaleComplete
					then resetting;
				
				state resetting;
				
				transition reset_to_entry
					first resetting
					if measurementChamber.volumePiston.currentVolume == 0 [SI::milliliter]
					then entry;
			}
		}
	}
	
	package Requirements {
		private import Definitions::*;
		
		requirement def VolumeMeasurementRequirement {
			doc /* The measurement chamber shall display real-time inhaled volume in milliliters via a rising piston. */
			subject spirometer : IncentiveSpirometer;
			constraint {
				spirometer.measurementChamber.volumePiston.currentVolume >= 0 [SI::milliliter];
			}
		}
		
		requirement def TargetVolumeRequirement {
			doc /* The device shall allow a healthcare provider to set a prescribed target volume. */
			subject spirometer : IncentiveSpirometer;
			attribute prescribedVolume : VolumeValue;
			constraint {
				spirometer.measurementChamber.targetVolume == prescribedVolume;
			}
		}
		
		requirement def FlowRateRequirement {
			doc /* The flow rate coach shall indicate whether inhalation flow is too low, optimal, or too high. */
			subject coach : FlowRateCoach;
			constraint {
				coach.indicatorBall.currentFlowRate >= coach.optimalMin and
				coach.indicatorBall.currentFlowRate <= coach.optimalMax;
			}
		}
		
		requirement def BreathHoldRequirement {
			doc /* Upon reaching target volume, the patient shall hold their breath for a recommended duration before exhaling. */
			subject spirometer : IncentiveSpirometer;
			constraint {
				spirometer.recommendedHoldTime >= 3 [SI::second];
			}
		}
		
		requirement def AutoResetRequirement {
			doc /* The volume piston shall return to the baseline position after exhalation to prepare for the next cycle. */
			subject spirometer : IncentiveSpirometer;
			constraint {
				spirometer.measurementChamber.volumePiston.currentVolume == 0 [SI::milliliter];
			}
		}
	}
	
	package Usages {
		private import Definitions::*;
		private import Requirements::*;
		
		part therapyContext {
			part spirometer : IncentiveSpirometer;
			part patient : Patient;
			
			flow of air : Air
				from spirometer.mouthpiece.airOutPort.air to patient.mouthPort.air;
			
			satisfy VolumeMeasurementRequirement by spirometer;
			satisfy TargetVolumeRequirement by spirometer;
			satisfy FlowRateRequirement by spirometer.flowRateCoach;
			satisfy BreathHoldRequirement by spirometer;
			satisfy AutoResetRequirement by spirometer;
		}
		
		individual def ClinicalPatient :> Patient;
		individual def ClinicalDevice :> IncentiveSpirometer;
		
		individual therapySession : ClinicalDevice {
			part testPatient : ClinicalPatient;
			
			timeslice cycle1 {
				perform exerciseBehavior;
			}
			then timeslice cycle2 {
				perform exerciseBehavior;
			}
		}
	}
}
