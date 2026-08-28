package 'Portable Medical Traction Splint' {
	private import ScalarValues::*;

	value def ForceValue :> Real;
	value def LengthValue :> Real;
	value def MassValue :> Real;

	attribute def DeploySignal;
	attribute def PositionSignal;
	attribute def SecureAnchorsSignal;
	attribute def ApplyTractionSignal;
	attribute def SecureStrapsSignal;
	attribute def ReleaseTractionSignal;
	attribute def StowSignal;
	attribute def TensionCheckSignal;

	part def Patient {
		part leg : Leg;
		part ankle : Ankle;
		part hip : Hip;
	}
	part def Leg;
	part def Ankle;
	part def Hip;

	part def Medic;

	port def MechanicalPort;
	port def ForcePort;

	part def TelescopicFrame {
		attribute length : LengthValue;
		port mechanical : MechanicalPort;
	}
	part def ProximalAnchorPad {
		port mechanical : MechanicalPort;
	}
	part def RatchetWindlass {
		attribute tension : ForceValue;
		port mechanical : MechanicalPort;
		port forceOut : ForcePort;
	}
	part def DistalAnkleHitch {
		port mechanical : MechanicalPort;
	}
	part def TensionIndicator {
		attribute reading : ForceValue;
		port forceIn : ForcePort;
	}
	part def SupportStrap {
		port mechanical : MechanicalPort;
	}

	connection def MechanicalConnection {
		end a : MechanicalPort;
		end b : MechanicalPort;
	}
	connection def ForceConnection {
		end source : ForcePort;
		end target : ForcePort;
	}
	connection def AnchorToHipConnection {
		end anchor : ProximalAnchorPad;
		end hip : Hip;
	}
	connection def HitchToAnkleConnection {
		end hitch : DistalAnkleHitch;
		end ankle : Ankle;
	}

	part def TractionSplint {
		attribute mass : MassValue;
		attribute currentLength : LengthValue;
		attribute appliedForce : ForceValue;

		part frame : TelescopicFrame;
		part anchorPad : ProximalAnchorPad;
		part windlass : RatchetWindlass;
		part ankleHitch : DistalAnkleHitch;
		part tensionIndicator : TensionIndicator;
		part supportStraps : SupportStrap[4];

		connection frameToAnchor : MechanicalConnection
			connect frame.mechanical to anchorPad.mechanical;
		connection frameToWindlass : MechanicalConnection
			connect frame.mechanical to windlass.mechanical;
		connection windlassToHitch : MechanicalConnection
			connect windlass.mechanical to ankleHitch.mechanical;
		connection windlassToIndicator : ForceConnection
			connect windlass.forceOut to tensionIndicator.forceIn;
		connection frameToStraps : MechanicalConnection
			connect frame.mechanical to supportStraps.mechanical;

		exhibit state splintOperation : SplintOperationStates;
	}

	action def 'Adjust Length';
	action def 'Position Splint';
	action def 'Secure Anchors';
	action def 'Apply Traction';
	action def 'Monitor Tension';
	action def 'Secure Straps';
	action def 'Release Traction';
	action def 'Stow Splint';

	state def SplintOperationStates {
		entry; then stowed;
		state stowed;
		accept DeploySignal then adjusting;
		state adjusting {
			do 'Adjust Length';
		}
		accept PositionSignal then positioning;
		state positioning {
			do 'Position Splint';
		}
		accept SecureAnchorsSignal then securingAnchors;
		state securingAnchors {
			do 'Secure Anchors';
		}
		accept ApplyTractionSignal then applyingTraction;
		state applyingTraction {
			do 'Apply Traction';
		}
		accept TensionCheckSignal if 'traction splint system'.splint.tensionIndicator.reading >= 10 and 'traction splint system'.splint.tensionIndicator.reading <= 30 then securingStraps;
		state securingStraps {
			do 'Secure Straps';
		}
		accept SecureStrapsSignal then monitoring;
		state monitoring {
			do 'Monitor Tension';
		}
		accept TensionCheckSignal if 'traction splint system'.splint.tensionIndicator.reading < 10 do 'Apply Traction' then monitoring;
		accept TensionCheckSignal if 'traction splint system'.splint.tensionIndicator.reading > 30 do 'Release Traction' then monitoring;
		accept ReleaseTractionSignal then released;
		state released {
			do 'Release Traction';
		}
		accept StowSignal then stowed;
	}

	requirement def TractionSplintRequirements {
		subject splint : TractionSplint;
		requirement 'Immobilize Leg' {
			doc /* The splint must immobilize the fractured leg. */
		}
		requirement 'Apply Controlled Traction' {
			doc /* The splint must apply a controlled, steady pulling force. */
			attribute minForce : ForceValue = 10;
			attribute maxForce : ForceValue = 30;
			assert constraint { splint.appliedForce >= minForce and splint.appliedForce <= maxForce }
		}
		requirement 'Lightweight and Portable' {
			doc /* The system must be lightweight and portable for easy deployment. */
			attribute maxWeight : MassValue = 2.0;
			assert constraint { splint.mass <= maxWeight }
		}
	}

	part 'traction splint system' {
		part splint : TractionSplint;
		part patient : Patient;
		part medic : Medic;

		connection anchorConnection : AnchorToHipConnection
			connect splint.anchorPad to patient.hip;
		connection hitchConnection : HitchToAnkleConnection
			connect splint.ankleHitch to patient.ankle;

		requirement 'Traction Splint Requirements' : TractionSplintRequirements {
			subject redefines splint = 'traction splint system'.splint;
		}

		action {
			action 'adjust length' : 'Adjust Length';
			then action 'position splint' : 'Position Splint';
			then action 'secure anchors' : 'Secure Anchors';
			then action 'apply traction' : 'Apply Traction';
			then action 'monitor tension' : 'Monitor Tension';
			then action 'secure straps' : 'Secure Straps';
			then action 'release traction' : 'Release Traction';
		}
	}
}
