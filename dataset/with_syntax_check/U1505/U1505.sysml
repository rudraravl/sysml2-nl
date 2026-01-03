package SpringSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import SequenceFunctions::*;
	
	attribute def SpringConstant :> Real;
	attribute def Displacement :> Real;
	attribute def RestLength :> Real;
	
	item def ForceVector {
		attribute magnitude :> Real;
		attribute direction : Real;
	}
	
	item def Position {
		attribute x :> Real;
		attribute velocity :> Real;
		attribute acceleration :> Real;
	}
	
	part def SpringMaterial {
		attribute elasticModulus :> Real;
		attribute yieldStrength :> Real;
		attribute wireDiameter :> Real;
	}
	
	part def MountingPoint {
		attribute position : Position;
		attribute isFixed : Boolean;
	}
	
	part def Mass {
		attribute mass :> Real;
		attribute position : Position;
		port forceInput {
			in item appliedForce : ForceVector;
		}
		port forceOutput {
			out item reactionForce : ForceVector;
		}
	}
	
	part def Spring {
		attribute springConstant : SpringConstant;
		attribute restLength : RestLength;
		attribute currentLength :> Real;
		attribute maxCompression :> Real;
		attribute maxExtension :> Real;
		
		part material : SpringMaterial;
		
		port end1 {
			in item displacement1 :> Real;
			out item force1 : ForceVector;
		}
		
		port end2 {
			in item displacement2 :> Real;
			out item force2 : ForceVector;
		}
		
		perform action generateRestoringForce[*] ordered;
	}
	
	action def CalculateSpringForce {
		in k : SpringConstant;
		in x0 : RestLength;
		in x :> Real;
		out restoringForce :> Real;
	}
	
	action def UpdatePosition {
		in currentPosition : Position;
		in netForce :> Real;
		in mass :> Real;
		in deltaTime :> Real;
		out newPosition : Position;
	}
	
	action def SpringOscillation {
		in initialDisplacement :> Real;
		in initialVelocity :> Real;
		in springConstant : SpringConstant;
		in attachedMass :> Real;
		in dampingCoefficient : Real;
		in timeStep :> Real;
		in simulationDuration :> Real;
		out positionHistory : Position[*] := ( );
		
		private attribute currentPos : Position;
		private attribute currentTime :> Real := 0.0;
		
		first start;
		then merge continueOscillation;
		then action calculateForce : CalculateSpringForce {
			in k = springConstant;
			in x0 = 0.0;
			in x = currentPos.x;
			out restoringForce;
		}
		then action applyDamping {
			in dampingForce :> Real = dampingCoefficient * currentPos.velocity;
			out netForce :> Real = calculateForce.restoringForce - dampingForce;
		}
		then action updatePos : UpdatePosition {
			in currentPosition = currentPos;
			in netForce = applyDamping.netForce;
			in mass = attachedMass;
			in deltaTime = timeStep;
			out newPosition;
		}
		then assign currentPos := updatePos.newPosition;
		then assign currentTime := currentTime + timeStep;
		then assign positionHistory := positionHistory->including(currentPos);
		then decide;
			if currentTime < simulationDuration then continueOscillation;
			if currentTime >= simulationDuration then done;
	}
	
	state def SpringBehavior {
		entry; then idle;
		
		state idle;
		transition idle_to_compressed
			first idle
			then compressed;
			
		state compressed;
		transition compressed_to_restoring
			first compressed
			then restoring;
			
		state restoring {
			do action generateRestoringForce : CalculateSpringForce;
		}
		transition restoring_to_equilibrium
			first restoring
			then equilibrium;
			
		state equilibrium;
		transition equilibrium_to_extended
			first equilibrium
			then extended;
			
		state extended;
		transition extended_to_restoring2
			first extended
			then restoring;
			
		transition restoring_to_idle
			first restoring
			then idle;
	}
	
	part springSystem {
		part fixedMount : MountingPoint {
			attribute :>> position {
				attribute :>> x = 0.0;
				attribute :>> velocity = 0.0;
				attribute :>> acceleration = 0.0;
			}
			attribute :>> isFixed = true;
		}
		
		part helicalSpring : Spring {
			attribute :>> springConstant = 100.0;
			attribute :>> restLength = 0.2;
			attribute :>> currentLength = 0.2;
			attribute :>> maxCompression = 0.05;
			attribute :>> maxExtension = 0.15;
			
			part :>> material {
				attribute :>> elasticModulus = 200.0e9;
				attribute :>> yieldStrength = 1.5e9;
				attribute :>> wireDiameter = 0.002;
			}
			
			perform action :>> generateRestoringForce {
				first start;
				then action checkState;
				then action computeForce : CalculateSpringForce;
				then action transmitForce;
				then done;
			}
			
			exhibit state springStateMachine : SpringBehavior;
		}
		
		part attachedMass : Mass {
			attribute :>> mass = 1.0;
			attribute :>> position {
				attribute :>> x = 0.2;
				attribute :>> velocity = 0.0;
				attribute :>> acceleration = 0.0;
			}
		}
		
		connection springToMount connect 
			fixedMount.position to helicalSpring.end1.displacement1;
		
		connection springToMass connect 
			helicalSpring.end2.force2 to attachedMass.forceInput.appliedForce;
		
		connection massToSpring connect 
			attachedMass.position.x to helicalSpring.end2.displacement2;
		
		perform action oscillate : SpringOscillation {
			in initialDisplacement = 0.05;
			in initialVelocity = 0.0;
			in springConstant = helicalSpring.springConstant;
			in attachedMass = attachedMass.mass;
			in dampingCoefficient = 0.1;
			in timeStep = 0.01;
			in simulationDuration = 10.0;
			out positionHistory;
		}
	}
	
	requirement def SpringSystemRequirements {
		doc /* Requirements for the spring system. */
	}
	
	requirement <'1'> storeAndReleaseEnergy {
		doc /* The spring system shall store mechanical energy when compressed or extended 
		       and release it as restoring force to return to equilibrium position. */
		
		subject system : springSystem;
		
		assume constraint energyConservation {
			doc /* Total mechanical energy shall be conserved in the absence of damping. */
		}
		
		require constraint hookesLaw {
			doc /* The restoring force shall be proportional to displacement from rest length. */
		}
	}
	
	requirement <'2'> provideMechanicalCoupling {
		doc /* The spring shall mechanically couple the fixed mount to the attached mass, 
		       transmitting forces while allowing relative motion. */
		
		subject system : springSystem;
		
		require constraint forceTransmission {
			doc /* Forces applied at one end shall be transmitted to the other end. */
		}
	}
	
	requirement <'3'> enableOscillation {
		doc /* The spring-mass system shall enable periodic oscillatory motion when displaced 
		       from equilibrium and released. */
		
		subject system : springSystem;
		
		assume constraint initialConditions {
			doc /* System starts with known displacement and velocity. */
		}
		
		require constraint periodicMotion {
			doc /* The system shall exhibit periodic motion with predictable frequency. */
		}
	}
	
	requirement <'4'> operateWithinElasticLimit {
		doc /* The spring shall operate within its elastic limit to ensure reversible deformation. */
		
		subject spring : springSystem.helicalSpring;
		
		require constraint compressionLimit {
			doc /* Spring compression shall not exceed maximum compression limit. */
		}
		
		require constraint extensionLimit {
			doc /* Spring extension shall not exceed maximum extension limit. */
		}
	}
}
