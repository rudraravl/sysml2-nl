package 'Compound Pulley System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	public import Definitions::*;

	package Definitions {
		value type Force :> ISQ::force;
		value type Length :> ISQ::length;
		value type Mass :> ISQ::mass;
		value type DimensionlessRatio :> ScalarValues::Real;

		part def Load {
			attribute weight : Force;
			attribute targetHeight : Length;
			attribute currentHeight : Length;
		}

		part def Rope {
			attribute tensileStrength : Force;
			attribute currentTension : Force;
			attribute length : Length;
		}

		part def Wheel {
			attribute diameter : Length;
			attribute grooveWidth : Length;
			attribute bearingFrictionCoefficient : DimensionlessRatio;
		}

		part def Axle {
			attribute diameter : Length;
			attribute bearingFriction : Force;
		}

		part def Pulley {
			part wheel : Wheel[1];
			part axle : Axle[1];
			attribute rotationalSpeed : ScalarValues::Real;
		}

		part def FixedPulley :> Pulley {
			doc
			/*
			 * Anchored to a stationary point; changes direction of pulling force.
			 */
		}

		part def MovablePulley :> Pulley {
			doc
			/*
			 * Attached to the load; moves up and down, amplifying lifting force.
			 */
		}

		part def Anchor {
			attribute mountStrength : Force;
		}

		connection def RopeContact {
			end pulleyWheel : Wheel[1];
			end ropeSegment : Rope[1];
		}

		connection def LoadAttachment {
			end pulley : MovablePulley[1];
			end load : Load[1];
		}

		connection def AnchorMount {
			end anchor : Anchor[1];
			end pulley : FixedPulley[1];
		}

		item def 'Load Attached';
		item def 'Pull Started';
		item def 'Target Height Reached';
		item def 'Lower Command';
		item def 'Load Detached';

		action def 'Lift Load' {
			in effort : Force;
			out loadDisplacement : Length;
		}

		action def 'Lower Load' {
			in controlEffort : Force;
			out loadDisplacement : Length;
		}

		action def 'Secure Load' {
			out secured : ScalarValues::Boolean;
		}

		part def CompoundPulleySystem {
			attribute mechanicalAdvantage : DimensionlessRatio;
			attribute systemEfficiency : DimensionlessRatio;
			attribute requiredEffort : Force;
			attribute ropeTension : Force;

			part fixedPulley : FixedPulley[1];
			part movablePulley : MovablePulley[1];
			part rope : Rope[1];
			part anchor : Anchor[1];
			part load : Load[0..1];

			port userPullPort;
			port loadAttachmentPort;

			connection ropeOverFixedPulley : RopeContact connect fixedPulley.wheel to rope;
			connection ropeOverMovablePulley : RopeContact connect movablePulley.wheel to rope;
			connection anchorToFixedPulley : AnchorMount connect anchor to fixedPulley;
			connection movablePulleyToLoad : LoadAttachment connect movablePulley to load;

			perform action 'lift load' : 'Lift Load';
			perform action 'lower load' : 'Lower Load';
			perform action 'secure load' : 'Secure Load';

			exhibit state 'pulley system states' {
				entry; then idle;
				state idle;
				accept 'Load Attached' via loadAttachmentPort
					then loading;
				state loading;
				accept 'Pull Started' via userPullPort
					then lifting;
				state lifting {
					do 'lift load';
				}
				accept 'Target Height Reached'
					then holding;
				state holding {
					do 'secure load';
				}
				accept 'Lower Command' via userPullPort
					then lowering;
				state lowering {
					do 'lower load';
				}
				accept 'Load Detached' via loadAttachmentPort
					then idle;
			}

			assert constraint { mechanicalAdvantage >= 2.0 }
			assert constraint { systemEfficiency > 0.85 }
			assert constraint { ropeTension < rope.tensileStrength }
		}

		requirement def 'Mechanical Advantage Requirement' {
			doc
			/*
			 * The system must provide a mechanical advantage of at least 2.
			 */
			subject pulleySystem : CompoundPulleySystem;
			assert constraint {
				pulleySystem.mechanicalAdvantage >= 2
			}
		}

		requirement def 'Efficiency Requirement' {
			doc
			/*
			 * The system must achieve an efficiency greater than 85%.
			 */
			subject pulleySystem : CompoundPulleySystem;
			assert constraint {
				pulleySystem.systemEfficiency > 0.85
			}
		}

		requirement def 'Rope Safety Requirement' {
			doc
			/*
			 * Rope tension must remain below its maximum rated tensile strength.
			 */
			subject rope : Rope;
			assert constraint {
				rope.currentTension < rope.tensileStrength
			}
		}
	}

	package Usages {
		private import Definitions::*;

		part compoundPulleySystem : CompoundPulleySystem {
			attribute mechanicalAdvantage = 2.0;
			attribute systemEfficiency = 0.88;
			attribute requiredEffort = 200 [N];
			attribute ropeTension = 200 [N];

			part fixedPulley : FixedPulley[1] {
				part wheel : Wheel[1] {
					attribute diameter = 0.10 [m];
					attribute grooveWidth = 0.012 [m];
					attribute bearingFrictionCoefficient = 0.02;
				}
				part axle : Axle[1] {
					attribute diameter = 0.015 [m];
					attribute bearingFriction = 1.5 [N];
				}
			}

			part movablePulley : MovablePulley[1] {
				part wheel : Wheel[1] {
					attribute diameter = 0.10 [m];
					attribute grooveWidth = 0.012 [m];
					attribute bearingFrictionCoefficient = 0.02;
				}
				part axle : Axle[1] {
					attribute diameter = 0.015 [m];
					attribute bearingFriction = 1.5 [N];
				}
			}

			part rope : Rope[1] {
				attribute tensileStrength = 5000 [N];
				attribute currentTension = 200 [N];
				attribute length = 10 [m];
			}

			part anchor : Anchor[1] {
				attribute mountStrength = 10000 [N];
			}

			part load : Load[0..1] {
				attribute weight = 400 [N];
				attribute targetHeight = 2.0 [m];
				attribute currentHeight = 0 [m];
			}
		}

		requirement 'mechanical advantage req' : 'Mechanical Advantage Requirement' {
			subject pulleySystem = compoundPulleySystem;
		}
		requirement 'efficiency req' : 'Efficiency Requirement' {
			subject pulleySystem = compoundPulleySystem;
		}
		requirement 'rope safety req' : 'Rope Safety Requirement' {
			subject rope = compoundPulleySystem.rope;
		}

		satisfy 'mechanical advantage req' by compoundPulleySystem;
		satisfy 'efficiency req' by compoundPulleySystem;
		satisfy 'rope safety req' by compoundPulleySystem.rope;
	}
}
