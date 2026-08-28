package ConductiveElectrodeGelSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		attribute def ElectricalConductivityValue :> Real;
		attribute def ViscosityValue :> Real;
		attribute def pHValue :> Real;
		attribute def ImpedanceValue :> Real;
		attribute def SignalAmplitudeValue :> Real;
		attribute def SNRValue :> Real;
		attribute def LayerThicknessValue :> Real;

		item def BioelectricSignal {
			attribute amplitude : SignalAmplitudeValue;
			attribute frequency : Real;
		}

		item def MeasuredSignal :> BioelectricSignal {
			attribute snr : SNRValue;
		}

		port def ElectricalInterfacePort {
			inout signal : BioelectricSignal;
		}

		action def ApplyGel;
		action def ConductSignal;
		action def CleanOff;
		action def ReplaceGel;
		action def SenseConductivity {
			out conductivity : ElectricalConductivityValue;
		}

		state def GelLifecycle;

		attribute def ApplyGelSignal;
		attribute def GelReplacedSignal;
		attribute def DegradationAlert;
		attribute def ReplacementNeeded;

		part def ElectrodeGel {
			attribute conductivity : ElectricalConductivityValue;
			attribute viscosity : ViscosityValue;
			attribute pH : pHValue;
			attribute biocompatible : Boolean;
			attribute layerThickness : LayerThicknessValue;
			attribute currentImpedance : ImpedanceValue;
			attribute minConductivityThreshold : ElectricalConductivityValue;
			attribute criticalConductivityThreshold : ElectricalConductivityValue;

			port skinContact : ElectricalInterfacePort;
			port electrodeContact : ElectricalInterfacePort;

			exhibit state gelLifecycle : GelLifecycle;
			perform action 'conduct signal' : ConductSignal;
			perform action 'sense conductivity' : SenseConductivity;

			assert constraint { conductivity >= 1.0 ['S/m'] }
			assert constraint { viscosity >= 1.0 ['Pa*s'] and viscosity <= 50.0 ['Pa*s'] }
			assert constraint { pH >= 6.5 and pH <= 7.5 }
			assert constraint { biocompatible == true }
		}

		part def HumanSkin {
			attribute outerLayerImpedance : ImpedanceValue;
			attribute surfaceCondition : String;

			port bodyInterface : ElectricalInterfacePort;
			port gelInterface : ElectricalInterfacePort;
		}

		part def MeasurementElectrode {
			attribute electrodeImpedance : ImpedanceValue;
			attribute material : String;

			port gelInterface : ElectricalInterfacePort;
			port outputPort : ElectricalInterfacePort;
		}

		part def GelContainer {
			attribute volume : VolumeValue;
			attribute sealed : Boolean;
		}

		part def BioelectricSignalSource {
			attribute signalType : String;
			port outputPort : ElectricalInterfacePort;
		}

		part def MeasurementSystem {
			part gel : ElectrodeGel;
			part skin : HumanSkin;
			part electrode : MeasurementElectrode;
			part container : GelContainer;
			part signalSource : BioelectricSignalSource;

			connection signalToSkin connect signalSource.outputPort to skin.bodyInterface;
			connection skinToGel connect skin.gelInterface to gel.skinContact;
			connection gelToElectrode connect gel.electrodeContact to electrode.gelInterface;
		}

		requirement def BiocompatibilityRequirement {
			doc /* The gel shall be biocompatible to avoid skin irritation. */
			subject gel : ElectrodeGel;
			require constraint { gel.biocompatible == true }
		}

		requirement def ConductivityRequirement {
			doc /* The gel shall have high electrical conductivity for efficient signal transmission. */
			subject gel : ElectrodeGel;
			require constraint { gel.conductivity >= 1.0 ['S/m'] }
		}

		requirement def ViscosityRequirement {
			doc /* The gel viscosity shall be balanced for easy application and stable contact. */
			subject gel : ElectrodeGel;
			require constraint { gel.viscosity >= 1.0 ['Pa*s'] and gel.viscosity <= 50.0 ['Pa*s'] }
		}

		requirement def pHRequirement {
			doc /* The gel shall have a neutral pH to avoid skin irritation. */
			subject gel : ElectrodeGel;
			require constraint { gel.pH >= 6.5 and gel.pH <= 7.5 }
		}

		requirement def SignalQualityRequirement {
			doc /* The measured signal shall have a high signal-to-noise ratio. */
			subject measuredSignal : MeasuredSignal;
			require constraint { measuredSignal.snr >= 40 }
		}

		requirement def ImpedanceReductionRequirement {
			doc /* The gel shall reduce skin impedance to enable effective signal coupling. */
			subject gel : ElectrodeGel;
			require constraint { gel.currentImpedance <= 5000 ['Ω'] }
		}
	}

	package Usages {
		private import Definitions::*;

		part measurementSystem : MeasurementSystem {
			:>> gel {
				:>> conductivity = 5.0 ['S/m'];
				:>> viscosity = 15.0 ['Pa*s'];
				:>> pH = 7.0;
				:>> biocompatible = true;
				:>> layerThickness = 0.5 ['mm'];
				:>> currentImpedance = 100000 ['Ω'];
				:>> minConductivityThreshold = 2.0 ['S/m'];
				:>> criticalConductivityThreshold = 0.5 ['S/m'];
			}
			:>> skin {
				:>> outerLayerImpedance = 100000 ['Ω'];
				:>> surfaceCondition = "dry";
			}
			:>> electrode {
				:>> electrodeImpedance = 100 ['Ω'];
				:>> material = "Ag/AgCl";
			}
			:>> container {
				:>> volume = 0.05 ['L'];
				:>> sealed = true;
			}
			:>> signalSource {
				:>> signalType = "ECG";
			}
		}

		action 'apply gel' : ApplyGel;
		action 'conduct signal' : ConductSignal;
		action 'clean off' : CleanOff;
		action 'replace gel' : ReplaceGel;
		action 'sense conductivity' : SenseConductivity {
			out conductivity;
		}

		state gelLifecycle : GelLifecycle {
			entry; then stored;
			do 'sense conductivity' { out conductivity; }

			state stored {
				doc /* Gel is stable inside its container, sealed and ready for use. */
			}
			accept 'ApplyGelSignal'
				do 'apply gel'
				then active;

			state active {
				doc /* Gel is applied to skin, effectively conducting bioelectric signals. */
				do 'conduct signal';
			}
			accept when 'sense conductivity'.conductivity < measurementSystem.gel.minConductivityThreshold
				do send new 'DegradationAlert'() to measurementSystem.electrode
				then degraded;

			state degraded {
				doc /* Gel begins to dry out and lose conductive properties. */
			}
			accept when 'sense conductivity'.conductivity < measurementSystem.gel.criticalConductivityThreshold
				do send new 'ReplacementNeeded'() to measurementSystem.electrode
				then depleted;

			state depleted {
				doc /* Gel has lost conductive properties and must be cleaned off and replaced. */
			}
			accept 'GelReplacedSignal'
				do 'clean off'
				then stored;
		}

		requirement biocompatibilityRequirement : BiocompatibilityRequirement {
			:>> subject = measurementSystem.gel;
		}
		requirement conductivityRequirement : ConductivityRequirement {
			:>> subject = measurementSystem.gel;
		}
		requirement viscosityRequirement : ViscosityRequirement {
			:>> subject = measurementSystem.gel;
		}
		requirement pHRequirement : pHRequirement {
			:>> subject = measurementSystem.gel;
		}
		requirement signalQualityRequirement : SignalQualityRequirement;
		requirement impedanceReductionRequirement : ImpedanceReductionRequirement {
			:>> subject = measurementSystem.gel;
		}

		satisfy biocompatibilityRequirement by measurementSystem.gel;
		satisfy conductivityRequirement by measurementSystem.gel;
		satisfy viscosityRequirement by measurementSystem.gel;
		satisfy pHRequirement by measurementSystem.gel;
		satisfy impedanceReductionRequirement by measurementSystem.gel;
	}
}
