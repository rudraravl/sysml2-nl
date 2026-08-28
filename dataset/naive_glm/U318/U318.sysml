package MurphyDripIVInfusionSystem {

	import ISQ::*;
	import ScalarValues::*;

	// ---------- Value Types with Units ----------

	value type Volume :> Real {
		unit mm³;
	}

	value type FlowRate :> Real {
		unit mL/min;
	}

	value type DropRate :> Real {
		unit drop/min;
	}

	value type Length :> Real {
		unit m;
	}

	value type Pressure :> Real {
		unit kPa;
	}

	value type Mass :> Real {
		unit g;
	}

	value type Percent :> Real {
		unit '%';
	}

	// ---------- Item Types ----------

	item def InfusionFluid {
		attribute density : MassPerVolume;
		attribute medicationConcentration : MassPerVolume optional;
	}

	item def Air;

	item def Blood;

	// ---------- Port Definitions ----------

	port def FluidPort {
		out item fluid : InfusionFluid;
		in item air : Air;
	}

	port def PatientPort {
		out item fluid : InfusionFluid;
		in item blood : Blood;
	}

	// ---------- Component Part Definitions ----------

	part def IVBag {
		attribute capacity : Volume := 500 [mL];
		attribute currentVolume : Volume;
		attribute fillLevel : Percent;
		port portOut : FluidPort;
		
		exhibit state bagBehavior {
			entry; then checking;
			state checking;
			transition checking then empty
				when currentVolume == 0 [mL];
			state empty;
		}
	}

	part def SpikeAdapter {
		attribute isPierced : Boolean := false;
		port portIn : FluidPort;
		port portOut : FluidPort;
	}

	part def DripChamber {
		attribute chamberVolume : Volume := 10 [mL];
		attribute fluidLevel : Volume;
		attribute dropSize : Volume := 0.05 [mL];
		attribute isDry : Boolean;
		port portIn : FluidPort;
		port portOut : FluidPort;
		
		exhibit state chamberBehavior {
			entry; then monitoring;
			state monitoring;
			transition monitoring then dry
				when fluidLevel < 1 [mL];
			state dry;
		}
	}

	part def IVTubing {
		attribute length : Length := 1.5 [m];
		attribute innerDiameter : Length := 0.003 [m];
		attribute isPrimed : Boolean := false;
		port portIn : FluidPort;
		port portOut : FluidPort;
	}

	part def RollerClamp {
		attribute openness : Real := 0.0; // 0.0 = closed, 1.0 = fully open
		attribute isClosed : Boolean;
		port portIn : FluidPort;
		port portOut : FluidPort;
		
		action def adjust {
			in newOpenness : Real;
		}
	}

	part def IVCatheter {
		attribute gauge : Integer := 20;
		attribute isInserted : Boolean := false;
		port portIn : FluidPort;
		port portOut : PatientPort;
	}

	part def Patient {
		attribute veinPressure : Pressure := 2.0 [kPa];
		port portIn : PatientPort;
	}

	// ---------- System-Level Part ----------

	part def MurphyDripIVSystem {

		part ivBag : IVBag {
			attribute currentVolume := 500 [mL];
		}
		part spikeAdapter : SpikeAdapter;
		part dripChamber : DripChamber;
		part ivTubing : IVTubing;
		part rollerClamp : RollerClamp;
		part ivCatheter : IVCatheter;
		part patient : Patient;

		attribute bagHeight : Length := 1.0 [m];
		attribute hydrostaticPressure : Pressure;
		attribute targetFlowRate : FlowRate;
		attribute measuredDropRate : DropRate;
		attribute measuredFlowRate : FlowRate;

		calc pressureFromHeight(h : Length) : Pressure {
			// Approximate hydrostatic pressure from height
			9.8 [kPa/m] * h
		}

		calc flowFromDrops(drops : DropRate) : FlowRate {
			drops * 0.05 [mL/drop]
		}

		exhibit state systemStates {

			entry; then notReady;

			state notReady;

			transition notReady then priming
				when ivBag.currentVolume > 0 [mL]
					and rollerClamp.openness > 0.0;

			state priming {
				entry action primeAction {
					// Open clamp and allow fluid to fill chamber and tubing
					rollerClamp.openness := 1.0;
					ivTubing.isPrimed := true;
					dripChamber.fluidLevel := dripChamber.chamberVolume;
				}
			}

			transition priming then ready
				when ivTubing.isPrimed == true
					and dripChamber.fluidLevel > 5 [mL];

			state ready;

			transition ready then infusing
				when rollerClamp.openness > 0.0
					and ivCatheter.isInserted == true;

			state infusing {
				entry action startInfusion {
					// Begin monitoring drops and adjusting clamp
					measuredDropRate := 0 [drop/min];
				}
				do action monitorAndAdjust {
					// Provider counts drops and adjusts roller clamp
					measuredFlowRate := flowFromDrops(measuredDropRate);
					if measuredFlowRate < targetFlowRate {
						rollerClamp.openness := rollerClamp.openness + 0.1;
					}
					if measuredFlowRate > targetFlowRate {
						rollerClamp.openness := rollerClamp.openness - 0.1;
					}
				}
			}

			transition infusing then stopped
				when rollerClamp.openness == 0.0;

			transition stopped then infusing
				when rollerClamp.openness > 0.0;

			transition infusing then complete
				when ivBag.currentVolume == 0 [mL];

			transition infusing then notReady
				when dripChamber.isDry == true;

			state complete;
		}

		connection connectBagToSpike connect ivBag.portOut to spikeAdapter.portIn;
		connection connectSpikeToChamber connect spikeAdapter.portOut to dripChamber.portIn;
		connection connectChamberToTubing connect dripChamber.portOut to ivTubing.portIn;
		connection connectTubingToClamp connect ivTubing.portOut to rollerClamp.portIn;
		connection connectClampToCatheter connect rollerClamp.portOut to ivCatheter.portIn;
		connection connectCatheterToPatient connect ivCatheter.portOut to patient.portIn;
	}

	// ---------- Requirements ----------

	requirement def GravityFedOperation {
		subject : MurphyDripIVSystem;
		requirement {
			subject.hydrostaticPressure == subject.pressureFromHeight(subject.bagHeight);
		}
	}

	requirement def PreventAirEmbolism {
		subject : MurphyDripIVSystem;
		requirement {
			subject.dripChamber.fluidLevel > 1 [mL] during subject.systemStates.infusing;
		}
	}

	requirement def PrimingRequirement {
		subject : MurphyDripIVSystem;
		requirement {
			subject.ivTubing.isPrimed == true before subject.systemStates.infusing;
		}
	}

	requirement def FlowRateControl {
		subject : MurphyDripIVSystem;
		requirement {
			subject.measuredFlowRate == subject.targetFlowRate within tolerance 0.5 [mL/min];
		}
	}

	requirement def CompleteOnEmpty {
		subject : MurphyDripIVSystem;
		requirement {
			subject.systemStates.complete occurs when subject.ivBag.currentVolume == 0 [mL];
		}
	}

	requirement def ManualMonitoring {
		subject : MurphyDripIVSystem;
		requirement {
			subject.measuredDropRate is determined by visual observation of subject.dripChamber;
		}
	}

}
