package 'Medical Stent System' {
	private import ISQ::*;
	private import ScalarValues::*;

	attribute def StentDiameter :> length;
	attribute def BalloonPressure :> pressure;
	attribute def RadialForce :> force;
	attribute def PercentStenosis :> ScalarValues::Real;

	item def Blood;
	item def InflationFluid;

	part def VascularStentSystem;

	part def Stent {
		attribute material : String = "Cobalt-Chromium alloy";
		attribute collapsedDiameter : StentDiameter;
		attribute expandedDiameter : StentDiameter;
		attribute radialForce : RadialForce;
		attribute deployed : Boolean = false;
	}

	part def Balloon {
		attribute nominalDiameter : StentDiameter;
		attribute burstPressure : BalloonPressure;
		attribute appliedPressure : BalloonPressure;
		attribute inflated : Boolean = false;
		port inflationPort : InflationPort;
	}

	part def DeliveryCatheter {
		attribute catheterLength : length;
		port proximalPort : InflationPort;
		part balloon : Balloon[1];
	}

	part def BloodVessel {
		attribute healthyDiameter : StentDiameter;
		attribute stenosisSeverity : PercentStenosis;
		port proximalFlowPort : VesselFlowPort;
		port distalFlowPort : VesselFlowPort;
	}

	port def InflationPort {
		in item inflationFluid : InflationFluid;
		out item pressureFeedback : BalloonPressure;
	}

	port def VesselFlowPort {
		in item bloodIn : Blood;
		out item bloodOut : Blood;
	}

	flow def BloodFlow {
		ref :>> payload : Blood;
		end port supplierPort : VesselFlowPort;
		end port consumerPort : VesselFlowPort;
	}

	flow def InflationFlow {
		ref :>> payload : InflationFluid;
		end port sourcePort : InflationPort;
		end port targetPort : InflationPort;
	}

	connection def StentCrimping {
		end [1] part stent : Stent;
		end [1] part balloon : Balloon;
	}

	connection def StentApposition {
		end [1] part stent : Stent;
		end [1] part vessel : BloodVessel;
	}

	connection def CatheterInsertion {
		end [1] part catheter : DeliveryCatheter;
		end [1] part vessel : BloodVessel;
	}

	action def DeliverStentProcedure {
		action guideCatheter;
		action positionAtLesion;
		action inflateBalloon;
		action expandStent;
		action deflateBalloon;
		action withdrawCatheter;

		succession first guideCatheter then positionAtLesion;
		succession first positionAtLesion then inflateBalloon;
		succession first inflateBalloon then expandStent;
		succession first expandStent then deflateBalloon;
		succession first deflateBalloon then withdrawCatheter;
	}

	state def StentDeploymentStates {
		state Manufactured;
		state CrimpedOnBalloon;
		state PositionedAtLesion;
		state Expanding;
		state Deployed;

		transition from Manufactured to CrimpedOnBalloon;
		transition from CrimpedOnBalloon to PositionedAtLesion;
		transition from PositionedAtLesion to Expanding;
		transition from Expanding to Deployed;
	}

	requirement def RestoreBloodFlow {
		subject stentSystem : VascularStentSystem;
		objective {
			assert stentSystem.vessel.stenosisSeverity < 10.0;
		}
	}

	requirement def StentExpansionRequirement {
		subject stentImplant : Stent;
		objective {
			assert stentImplant.expandedDiameter > stentImplant.collapsedDiameter;
		}
	}

	requirement def RadialForceRequirement {
		subject stentImplant : Stent;
		objective {
			assert stentImplant.radialForce > 0.0;
		}
	}

	requirement def BalloonInflationRequirement {
		subject balloon : Balloon;
		objective {
			assert balloon.appliedPressure < balloon.burstPressure;
		}
	}

	part stentSystem : VascularStentSystem {
		part implant : Stent[1] {
			attribute collapsedDiameter = 1.5 [mm];
			attribute expandedDiameter = 4.0 [mm];
			attribute radialForce = 0.8 [N];
			perform StentDeploymentStates;
		}

		part deliveryDevice : DeliveryCatheter[1] {
			attribute catheterLength = 140 [cm];
			part balloon : Balloon[1] {
				attribute nominalDiameter = 4.0 [mm];
				attribute burstPressure = 18 [atm];
				attribute appliedPressure = 10 [atm];
			}
		}

		part vessel : BloodVessel[1] {
			attribute healthyDiameter = 4.0 [mm];
			attribute stenosisSeverity = 75.0;
		}

		connection : StentCrimping
			connect stent references implant
			to balloon references deliveryDevice.balloon;

		connection : CatheterInsertion
			connect catheter references deliveryDevice
			to vessel references vessel;

		connection : StentApposition
			connect stent references implant
			to vessel references vessel;

		flow : BloodFlow of Blood
			from vessel.proximalFlowPort
			to vessel.distalFlowPort;

		flow : InflationFlow of InflationFluid
			from deliveryDevice.proximalPort
			to deliveryDevice.balloon.inflationPort;

		perform DeliverStentProcedure;

		requirement restoreFlow : RestoreBloodFlow {
			subject :>> stentSystem = stentSystem;
		}

		requirement stentExpansion : StentExpansionRequirement {
			subject :>> stentImplant = implant;
		}

		requirement radialForceReq : RadialForceRequirement {
			subject :>> stentImplant = implant;
		}

		requirement balloonInflation : BalloonInflationRequirement {
			subject :>> balloon = deliveryDevice.balloon;
		}
	}
}
