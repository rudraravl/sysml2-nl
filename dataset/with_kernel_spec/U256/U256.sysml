package 'Inadine Wound Treatment System' {
	doc /* Inadine-based wound treatment system for managing acute and chronic wounds
	     * that are infected or at risk of infection. */

	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	public import Definitions::*;

	package Definitions {
		item def Exudate {
			attribute volume : VolumeValue;
		}

		item def PovidoneIodine {
			attribute concentration : Real = 10;
			attribute mass : MassValue;
		}

		part def ParaffinGauze {
			attribute isNonAdherent : Boolean = true;
		}

		port def ExudatePort {
			out item exudate : Exudate;
		}

		port def AntimicrobialPort {
			out item povidoneIodine : PovidoneIodine;
		}

		action def AbsorbExudate {
			in exudateIn : Exudate;
			out absorbedExudate : Exudate;
		}

		action def ReleasePovidoneIodine {
			in trigger : Exudate;
			out releasedAgent : PovidoneIodine;
		}

		action def MonitorSaturation {
			in absorbedVolume : VolumeValue;
			in maxCapacity : VolumeValue;
			out saturationLevel : Real;
			out changeNeeded : Boolean;
		}

		action def DetermineChangeTime {
			in saturationLevel : Real;
			in wearTime : TimeValue;
			in maxWearTime : TimeValue;
			out changeDressing : Boolean;
		}

		attribute def DressingAppliedSignal;
		attribute def DressingRemovedSignal;

		part def InadineDressingPad {
			attribute maxCapacity : VolumeValue;
			attribute absorbedVolume : VolumeValue;
			attribute maxWearTime : TimeValue = 24 [h];
			attribute wearTime : TimeValue;
			attribute isSterile : Boolean = true;
			port exudateInPort : ~ExudatePort;
			port antimicrobialOutPort : AntimicrobialPort;
			part gauze : ParaffinGauze;
			item povidoneIodine : PovidoneIodine;
			perform action absorbExudate : AbsorbExudate;
			perform action releaseAgent : ReleasePovidoneIodine;
			exhibit state dressingLifecycle {
				entry; then sterile;
				state sterile;
				accept DressingAppliedSignal
					then active;
				state active {
					entry absorbExudate;
					do releaseAgent;
				}
				accept when absorbedVolume >= maxCapacity
					then saturated;
				accept when wearTime >= maxWearTime
					then saturated;
				state saturated;
				accept DressingRemovedSignal
					then removed;
				state removed;
			}
		}

		part def WoundBed {
			attribute bacterialLoad : Real;
			attribute bacterialLoadThreshold : Real;
			port exudateOutPort : ExudatePort;
			port antimicrobialInPort : ~AntimicrobialPort;
			exhibit state woundHealth {
				entry; then infected;
				state infected;
				accept when bacterialLoad < bacterialLoadThreshold
					then healing;
				state healing;
			}
		}

		part def Patient {
			part wound : WoundBed;
		}

		part def SaturationMonitor {
			attribute saturationThreshold : Real = 0.9;
			perform action monitorSaturation : MonitorSaturation;
		}

		part def ApplicationController {
			attribute recommendedWearTime : TimeValue = 24 [h];
			perform action determineChangeTime : DetermineChangeTime;
			exhibit state controllerStates {
				entry; then monitoring;
				state monitoring {
					do determineChangeTime;
				}
				accept when determineChangeTime.changeDressing
					then changeRequired;
				state changeRequired;
				accept DressingRemovedSignal
					then monitoring;
			}
		}
	}

	package Usages {
		private import Definitions::*;

		part context {
			part patient : Patient;

			part dressing : InadineDressingPad {
				perform action absorbExudate : AbsorbExudate {
					in exudateIn = exudateInPort.exudate;
					out absorbedExudate;
				}
				perform action releaseAgent : ReleasePovidoneIodine {
					in trigger = absorbExudate.absorbedExudate;
					out releasedAgent = antimicrobialOutPort.povidoneIodine;
				}
			}

			flow of exudate : Exudate
				from patient.wound.exudateOutPort.exudate to dressing.exudateInPort.exudate;

			flow of povidoneIodine : PovidoneIodine
				from dressing.antimicrobialOutPort.povidoneIodine to patient.wound.antimicrobialInPort.povidoneIodine;

			part saturationMonitor : SaturationMonitor {
				perform action monitorSaturation : MonitorSaturation {
					in absorbedVolume = dressing.absorbedVolume;
					in maxCapacity = dressing.maxCapacity;
					out saturationLevel;
					out changeNeeded;
				}
			}

			part applicationController : ApplicationController {
				perform action determineChangeTime : DetermineChangeTime {
					in saturationLevel = saturationMonitor.monitorSaturation.saturationLevel;
					in wearTime = dressing.wearTime;
					in maxWearTime = dressing.maxWearTime;
					out changeDressing;
				}
			}
		}
	}

	package Requirements {
		private import Definitions::*;
		private import Usages::*;

		requirement def AntimicrobialProtection {
			subject dressing : InadineDressingPad;
			requirement {
				doc /* The dressing shall provide broad-spectrum antimicrobial action
				     * via 10% povidone-iodine. */
			}
		}

		requirement def ExudateManagement {
			subject dressing : InadineDressingPad;
			requirement {
				doc /* The dressing shall absorb wound exudate up to its maximum capacity. */
			}
		}

		requirement def NonAdherence {
			subject dressing : InadineDressingPad;
			requirement {
				doc /* The paraffin gauze base shall be non-adherent to the wound bed
				     * for less painful removal. */
			}
		}

		requirement def WearTimeLimit {
			subject dressing : InadineDressingPad;
			requirement {
				doc /* The dressing shall be changed within 24 hours of application
				     * or when saturated. */
			}
		}

		requirement antimicrobialReq : AntimicrobialProtection {
			subject :>> dressing = context.dressing;
		}

		requirement exudateReq : ExudateManagement {
			subject :>> dressing = context.dressing;
		}

		requirement nonAdherenceReq : NonAdherence {
			subject :>> dressing = context.dressing;
		}

		requirement wearTimeReq : WearTimeLimit {
			subject :>> dressing = context.dressing;
		}
	}
}
