package ElectroscopeModel {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def ElectricCharge {
		attribute amount : Real;
	}

	port def ChargePort {
		in item charge : ElectricCharge;
	}

	interface def ChargeTransferInterface {
		end supplierPort : ChargePort;
		end consumerPort : ChargePort;
	}

	part def ConductiveCap {
		port chargeInPort : ChargePort;
		port chargeOutPort : ChargePort;
	}

	part def ConductingRod {
		port chargeInPort : ChargePort;
		port chargeOutPort : ChargePort;
	}

	part def MetalLeaf {
		port chargeInPort : ChargePort;
		attribute divergenceAngle : Real;
	}

	part def InsulatingSupport;

	part def ProtectiveEnclosure {
		attribute isProtected : Boolean default true;
	}

	calc def DivergenceCalc {
		in charge : Real;
		return angle : Real = charge * 10;
	}

	state def ElectroscopeBehavior {
		state Uncharged;
		state Charging;
		state Charged;
		state Grounding;

		transition from Uncharged to Charging;
		transition from Charging to Charged;
		transition from Charged to Grounding;
		transition from Grounding to Uncharged;
	}

	part def Electroscope {
		port externalChargePort : ChargePort;
		port groundPort : ChargePort;

		part cap : ConductiveCap;
		part rod : ConductingRod;
		part leaf1 : MetalLeaf;
		part leaf2 : MetalLeaf;
		part support : InsulatingSupport;
		part enclosure : ProtectiveEnclosure;

		attribute totalCharge : Real;
		attribute divergenceAngle : Real;
		attribute isGrounded : Boolean default false;

		interface : ChargeTransferInterface connect
			supplierPort ::> externalChargePort to
			consumerPort ::> cap.chargeInPort;

		interface : ChargeTransferInterface connect
			supplierPort ::> cap.chargeOutPort to
			consumerPort ::> rod.chargeInPort;

		interface : ChargeTransferInterface connect
			supplierPort ::> rod.chargeOutPort to
			consumerPort ::> leaf1.chargeInPort;

		interface : ChargeTransferInterface connect
			supplierPort ::> rod.chargeOutPort to
			consumerPort ::> leaf2.chargeInPort;

		calc divergence : DivergenceCalc {
			in charge = totalCharge;
			return angle;
		}

		constraint leafSymmetry {
			leaf1.divergenceAngle == leaf2.divergenceAngle
		}

		constraint angleProportionalToCharge {
			divergenceAngle == divergence.angle
		}

		state machine : ElectroscopeBehavior;
	}

	requirement def DetectChargePresence {
		doc /* The electroscope shall detect the presence of an electric charge. */
		subject electroscope : Electroscope;
		constraint {
			electroscope.totalCharge > 0 implies electroscope.divergenceAngle > 0
		}
	}

	requirement def IndicateRelativeMagnitude {
		doc /* The divergence angle shall indicate the relative magnitude of the charge. */
		subject electroscope : Electroscope;
		constraint {
			electroscope.divergenceAngle > 0 implies electroscope.totalCharge > 0
		}
	}

	requirement def EnvironmentalProtection {
		doc /* The electroscope leaves shall be protected from air currents and physical damage. */
		subject electroscope : Electroscope;
		constraint {
			electroscope.enclosure.isProtected == true
		}
	}
}
