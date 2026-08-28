package 'Electrochemical Redox System' {
	private import ScalarValues::*;
	private import SI::*;

	attribute def Voltage :> Real {
		doc
		/*
		 * Electrical potential, measured in Volts (V).
		 */
	}

	attribute def Current :> Real {
		doc
		/*
		 * Electrical current, measured in Amperes (A).
		 */
	}

	attribute def Area :> Real {
		doc
		/*
		 * Surface area, measured in square centimeters (cm^2).
		 */
	}

	item def Electron;

	item def Electrolyte {
		doc
		/*
		 * A chemical solution that conducts electric current via moving ions.
		 */
		item electrons : Electron;
		attribute concentration : Real;
		attribute volume : Real;
	}

	port def ElectrodePort {
		inout item electrons : Electron;
		attribute potential : Voltage;
		attribute current : Current;
	}

	part def WorkingElectrode {
		doc
		/*
		 * The primary electrode where the chemical reaction of interest occurs.
		 * It has an active surface with specific catalytic properties to facilitate electron transfer.
		 */
		port electrodePort : ~ElectrodePort;
		attribute activeSurfaceArea : Area;
		attribute catalyticProperty : String;
	}

	part def CounterElectrode {
		doc
		/*
		 * The counter electrode completes the electrical circuit and allows current to flow.
		 */
		port electrodePort : ~ElectrodePort;
	}

	part def ReferenceElectrode {
		doc
		/*
		 * The reference electrode provides a stable, constant electrical potential
		 * against which the working electrode potential is measured.
		 */
		port electrodePort : ~ElectrodePort;
		attribute stablePotential : Voltage;
	}

	part def Reservoir {
		doc
		/*
		 * The container holding the electrolyte in which the electrodes are immersed.
		 */
		item electrolyte : Electrolyte;
	}

	action def RedoxAction {
		doc
		/*
		 * A full redox cycle, switching between oxidizing and reducing chemical species.
		 */
		in appliedPotential : Voltage;
		out resultingCurrent : Current;
	}

	part def Potentiostat {
		doc
		/*
		 * The electronic instrument that manages the process by applying a desired voltage
		 * between the working and reference electrodes and measuring the resulting current
		 * between the working and counter electrodes.
		 */
		port workingPort : ElectrodePort;
		port counterPort : ElectrodePort;
		port referencePort : ElectrodePort;

		attribute targetPotential : Voltage;
		attribute measuredCurrent : Current;

		state machine redoxControl {
			doc
			/*
			 * The system operates in different states depending on the applied electrical potential.
			 */
			state idle;
			state oxidizing;
			state reducing;

			transition toOxidizing {
				source idle;
				target oxidizing;
				guard targetPotential > 0.0;
			}
			transition toIdleFromOx {
				source oxidizing;
				target idle;
				guard targetPotential == 0.0;
			}
			transition toReducing {
				source idle;
				target reducing;
				guard targetPotential < 0.0;
			}
			transition toIdleFromRed {
				source reducing;
				target idle;
				guard targetPotential == 0.0;
			}
			transition oxToRed {
				source oxidizing;
				target reducing;
				guard targetPotential < 0.0;
			}
			transition redToOx {
				source reducing;
				target oxidizing;
				guard targetPotential > 0.0;
			}
		}

		action redoxAction : RedoxAction;
	}

	requirement def StableReferenceRequirement {
		doc
		/*
		 * The reference electrode must provide a stable, constant electrical potential.
		 */
		subject electrode : ReferenceElectrode;
		attribute stabilityTolerance : Voltage = 0.001;
		constraint {
			stabilityTolerance > 0.0
		}
	}

	requirement def ControlPrecisionRequirement {
		doc
		/*
		 * The potentiostat must control the potential precisely and ensure stability over time.
		 */
		subject instrument : Potentiostat;
		attribute targetPrecision : Voltage = 0.001;
		constraint {
			targetPrecision > 0.0
		}
	}

	requirement def CurrentMeasurementRequirement {
		doc
		/*
		 * The resulting current must be measured with high resolution.
		 */
		subject instrument : Potentiostat;
		attribute resolution : Current = 1.0e-9;
		constraint {
			resolution > 0.0
		}
	}

	requirement def RedoxCycleCapabilityRequirement {
		doc
		/*
		 * The system shall support full redox cycles by dynamically switching
		 * between oxidation and reduction states.
		 */
		subject instrument : Potentiostat;
	}

	part redoxSystem {
		doc
		/*
		 * A laboratory-grade electrochemical system designed for precisely controlling
		 * and studying oxidation-reduction (redox) reactions.
		 */
		part reservoir : Reservoir {
			part workingElectrode : WorkingElectrode;
			part counterElectrode : CounterElectrode;
			part referenceElectrode : ReferenceElectrode;
		}
		part potentiostat : Potentiostat;

		connect potentiostat.workingPort to reservoir.workingElectrode.electrodePort;
		connect potentiostat.counterPort to reservoir.counterElectrode.electrodePort;
		connect potentiostat.referencePort to reservoir.referenceElectrode.electrodePort;

		requirement stableRefReq : StableReferenceRequirement {
			subject electrode :>> reservoir.referenceElectrode;
		}
		requirement controlPrecReq : ControlPrecisionRequirement {
			subject instrument :>> potentiostat;
		}
		requirement currentMeasReq : CurrentMeasurementRequirement {
			subject instrument :>> potentiostat;
		}
		requirement redoxCycleReq : RedoxCycleCapabilityRequirement {
			subject instrument :>> potentiostat;
		}
	}
}
