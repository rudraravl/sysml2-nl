package 'Bird Anatomy System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def NeuralSignal;
	attribute def FlightCommand;
	attribute def FeedingCommand;

	item def Air {
		attribute density : ISQ::DensityValue;
		attribute velocity : ISQ::SpeedValue;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
	}

	item def Food {
		attribute mass : ISQ::MassValue;
		attribute energyContent : ISQ::EnergyValue;
	}

	item def OxygenatedBlood {
		attribute oxygenSaturation : Real;
		attribute flowRate : ISQ::VolumeFlowRateValue;
	}

	attribute def LiftForce :> ISQ::ForceValue;
	attribute def ThrustForce :> ISQ::ForceValue;
	attribute def WingbeatFrequency :> ISQ::FrequencyValue;
	attribute def BodyTemperature :> ISQ::ThermodynamicTemperatureValue;

	port def AerodynamicPort {
		in item airstream : Air;
		out attribute liftGenerated : LiftForce;
		out attribute thrustGenerated : ThrustForce;
	}

	port def RespiratoryPort {
		in item airIntake : Air;
		out item oxygenatedBlood : OxygenatedBlood;
	}

	port def NeuromuscularPort {
		in attribute signal : NeuralSignal;
		out attribute force : ISQ::ForceValue;
	}

	port def DigestivePort {
		in item foodIntake : Food;
		out attribute energyReleased : ISQ::EnergyValue;
	}

	part def Brain {
		out attribute motorControl : NeuralSignal;
		out attribute flightDecision : Real;
		out attribute feedingDecision : Real;

		action def ProcessSensoryInput {
			in visualInput : Real;
			in proprioceptiveInput : Real;
			out controlSignal : NeuralSignal;
		}

		perform action processInputs : ProcessSensoryInput;
	}

	part def RespiratorySystem {
		port respiration : RespiratoryPort;
		attribute oxygenExtractionEfficiency : Real;

		part def Lung {
			attribute volume : ISQ::VolumeValue;
			attribute gasExchangeArea : ISQ::AreaValue;
			attribute exchangeRate : Real;
		}

		part def AirSac {
			attribute capacity : ISQ::VolumeValue;
			attribute pressureRegulation : Real;
		}

		part leftLung : Lung;
		part rightLung : Lung;
		part anteriorAirSacs : AirSac[4];
		part posteriorAirSacs : AirSac[5];

		action def OxygenateBlood {
			in inhaledAir : Air;
			in lungCapacity : ISQ::VolumeValue;
			out bloodOxygenated : OxygenatedBlood;
		}

		perform action breathe : OxygenateBlood;
	}

	part def DigestiveSystem {
		port digestion : DigestivePort;
		attribute metabolicEfficiency : Real;

		part def Beak {
			attribute length : ISQ::LengthValue;
			attribute graspingStrength : ISQ::ForceValue;
			attribute shape : Real;
		}

		part def Esophagus {
			attribute diameter : ISQ::LengthValue;
		}

		part def Crop {
			attribute storageVolume : ISQ::VolumeValue;
		}

		part def Proventriculus {
			attribute acidProduction : Real;
		}

		part def Gizzard {
			attribute grindingForce : ISQ::ForceValue;
			attribute muscleThickness : ISQ::LengthValue;
		}

		part def Intestine {
			attribute length : ISQ::LengthValue;
			attribute absorptionArea : ISQ::AreaValue;
		}

		part beak : Beak;
		part esophagus : Esophagus;
		part crop : Crop;
		part proventriculus : Proventriculus;
		part gizzard : Gizzard;
		part intestine : Intestine;

		action def DigestFood {
			in foodItem : Food;
			in grindingForce : ISQ::ForceValue;
			out energyExtracted : ISQ::EnergyValue;
			out wasteProduced : ISQ::MassValue;
		}

		perform action digest : DigestFood;
	}

	part def MusculoskeletalSystem {
		attribute totalBoneMass : ISQ::MassValue;
		attribute muscleMass : ISQ::MassValue;

		part def Bone {
			attribute hollowness : Real;
			attribute density : ISQ::DensityValue;
			attribute tensileStrength : ISQ::ForceValue;
		}

		part def FlightMuscle {
			attribute mass : ISQ::MassValue;
			attribute maxContractionForce : ISQ::ForceValue;
			attribute contractionSpeed : ISQ::FrequencyValue;
			attribute fatigueResistance : Real;
		}

		part skeleton : Bone[*];
		part pectoralisMajor : FlightMuscle[2];
		part supracoracoideus : FlightMuscle[2];
		part legMuscles : FlightMuscle[*];

		port neuromuscular : NeuromuscularPort;

		action def ContractMuscle {
			in neuralStimulus : NeuralSignal;
			in muscleProperties : ISQ::MassValue;
			out contractionForce : ISQ::ForceValue;
		}

		perform action contract : ContractMuscle;
	}

	part def Wing {
		attribute wingspan : ISQ::LengthValue;
		attribute wingArea : ISQ::AreaValue;
		attribute aspectRatio : Real;

		port aerodynamics : AerodynamicPort;
		port muscleAttachment : NeuromuscularPort;

		part def PrimaryFeather {
			attribute length : ISQ::LengthValue;
			attribute stiffness : Real;
			attribute asymmetry : Real;
		}

		part def SecondaryFeather {
			attribute length : ISQ::LengthValue;
			attribute flexibility : Real;
		}

		part def Covert {
			attribute density : Real;
		}

		part primaries : PrimaryFeather[10];
		part secondaries : SecondaryFeather[20];
		part coverts : Covert[*];

		action def GenerateAerodynamicForce {
			in airflow : Air;
			in wingAngle : ISQ::PlaneAngleValue;
			in flapFrequency : WingbeatFrequency;
			in wingArea : ISQ::AreaValue;
			out liftForce : LiftForce;
			out thrustForce : ThrustForce;
		}

		perform action produceLift : GenerateAerodynamicForce;
	}

	part def Tail {
		attribute tailArea : ISQ::AreaValue;
		attribute spreadAngle : ISQ::PlaneAngleValue;

		port aerodynamics : AerodynamicPort;

		action def StabilizeFlight {
			in airstream : Air;
			in tailAngle : ISQ::PlaneAngleValue;
			out stabilizingForce : ISQ::ForceValue;
			out yawControl : ISQ::ForceValue;
		}

		perform action stabilize : StabilizeFlight;
	}

	part def Eye {
		attribute visualAcuity : Real;
		attribute fieldOfView : ISQ::PlaneAngleValue;

		action def DetectMotion {
			in lightIntensity : Real;
			out visualSignal : Real;
		}

		perform action see : DetectMotion;
	}

	part def Bird {
		attribute bodyMass : ISQ::MassValue;
		attribute coreTemperature : BodyTemperature;
		attribute restingMetabolicRate : ISQ::PowerValue;
		attribute flightMetabolicRate : ISQ::PowerValue;

		part brain : Brain;
		part respiratorySystem : RespiratorySystem;
		part digestiveSystem : DigestiveSystem;
		part musculoskeletalSystem : MusculoskeletalSystem;
		part leftWing : Wing;
		part rightWing : Wing;
		part tail : Tail;
		part leftEye : Eye;
		part rightEye : Eye;

		connect brain to musculoskeletalSystem.neuromuscular;
		connect musculoskeletalSystem to leftWing.muscleAttachment;
		connect musculoskeletalSystem to rightWing.muscleAttachment;

		perform action executeFlight {
			first start;
			then merge flightLoop;
			then accept flightCommand : FlightCommand;
			then action activateNervousSystem {
				perform brain.processInputs;
			}
			then action coordinateFlightSystems {
				action breatheForFlight {
					perform respiratorySystem.breathe;
				}
				action contractFlightMuscles {
					perform musculoskeletalSystem.contract;
				}
				action flapLeftWing {
					perform leftWing.produceLift;
				}
				action flapRightWing {
					perform rightWing.produceLift;
				}
				action stabilizeWithTail {
					perform tail.stabilize;
				}
			}
			then decide;
				if coreTemperature < 315.15[K] then continueFlying;
				if coreTemperature >= 315.15[K] then descendToRest;
			action continueFlying;
			then flightLoop;
			action descendToRest;
			then done;
		}

		perform action executeFeeding {
			first start;
			then accept feedingCommand : FeedingCommand;
			then action locateFood {
				perform leftEye.see;
				perform rightEye.see;
			}
			then action graspFood {
				perform digestiveSystem.digest;
			}
			then action extractNutrients;
			then done;
		}

		state birdLifeCycle {
			entry; then resting;
			
			state resting {
				entry assign coreTemperature := 310.15[K];
			}
			
			transition restingToActive
				first resting
				accept FlightCommand
				then active;
			
			state active {
				entry; then flying;
				
				state flying {
					entry assign coreTemperature := 313.15[K];
					do perform executeFlight;
				}
				
				transition flyingToForaging
					first flying
					accept FeedingCommand
					then foraging;
				
				state foraging {
					do perform executeFeeding;
				}
				
				transition foragingToFlying
					first foraging
					accept FlightCommand
					then flying;
			}
			
			transition activeToResting
				first active
				when coreTemperature <= 310.15[K]
				then resting;
		}
	}

	requirement def PrimaryFlightFunction {
		doc /* The bird shall achieve sustained powered flight through coordinated wing flapping 
		       driven by pectoral muscles, generating sufficient lift to overcome body weight. */
		
		subject bird : Bird;
		
		require constraint {
			bird.leftWing.wingspan > 0.2[m] and
			bird.rightWing.wingspan > 0.2[m] and
			bird.musculoskeletalSystem.pectoralisMajor->size() == 2
		}
	}

	requirement def RespiratoryCapability {
		doc /* The respiratory system shall provide continuous oxygen supply during flight 
		       through efficient unidirectional airflow via air sacs and lungs. */
		
		subject respiratory : RespiratorySystem;
		
		require constraint {
			respiratory.oxygenExtractionEfficiency > 0.85 and
			respiratory.anteriorAirSacs->size() >= 4 and
			respiratory.posteriorAirSacs->size() >= 5
		}
	}

	requirement def MetabolicEnergySupply {
		doc /* The digestive system shall extract sufficient energy from food to sustain 
		       high metabolic demands of flight. */
		
		subject digestive : DigestiveSystem;
		
		require constraint {
			digestive.metabolicEfficiency > 0.7
		}
	}

	requirement def StructuralLightweight {
		doc /* The skeletal system shall minimize mass while maintaining structural integrity 
		       through hollow, pneumatic bones. */
		
		subject skeleton : MusculoskeletalSystem;
		
		require constraint {
			skeleton.totalBoneMass < 0.15 * skeleton.muscleMass and
			skeleton.skeleton->forAll(bone : Bone; bone.hollowness > 0.6)
		}
	}

	requirement def AerodynamicEfficiency {
		doc /* Wings shall generate lift-to-drag ratio sufficient for sustained flight 
		       through optimized feather arrangement and wing geometry. */
		
		subject wing : Wing;
		
		require constraint {
			wing.aspectRatio > 5.0 and
			wing.primaries->size() >= 9
		}
	}

	requirement birdFlightMission {
		doc /* The bird system shall achieve powered flight as its primary function by integrating 
		       respiratory, muscular, skeletal, and aerodynamic subsystems to generate lift, 
		       maintain stability, and sustain energy metabolism. */
		
		require flightCapability : PrimaryFlightFunction;
		require respiratorySupport : RespiratoryCapability;
		require energySupply : MetabolicEnergySupply;
		require lightweightStructure : StructuralLightweight;
		require aerodynamicPerformance : AerodynamicEfficiency;
	}

	part sparrow : Bird {
		:>> bodyMass = 0.028[kg];
		:>> coreTemperature = 312.15[K];
		:>> restingMetabolicRate = 0.8[W];
		:>> flightMetabolicRate = 4.5[W];
		
		part :>> leftWing {
			:>> wingspan = 0.095[m];
			:>> wingArea = 0.0045[m^2];
			:>> aspectRatio = 6.2;
		}
		
		part :>> rightWing {
			:>> wingspan = 0.095[m];
			:>> wingArea = 0.0045[m^2];
			:>> aspectRatio = 6.2;
		}
		
		part :>> musculoskeletalSystem {
			:>> totalBoneMass = 0.0035[kg];
			:>> muscleMass = 0.012[kg];
		}
		
		part :>> respiratorySystem {
			:>> oxygenExtractionEfficiency = 0.92;
		}
		
		part :>> digestiveSystem {
			:>> metabolicEfficiency = 0.78;
		}
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Bird Anatomy System'::*;

    action orchestrator {
        action actionProbe : ProcessSensoryInput {
            in visualInput = 0.0;
            in proprioceptiveInput = 0.0;
        }
        first actionProbe;
    }
}
