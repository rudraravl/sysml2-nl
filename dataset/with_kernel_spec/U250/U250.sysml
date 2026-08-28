package 'Hyalobarrier Adhesion Prevention System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		attribute def ViscosityValue :> Real;
		attribute def VolumeValue :> Real;
		attribute def ThicknessValue :> Real;
		attribute def DurationValue :> Real;
		
		part def HyalobarrierGel {
			attribute isSterile: Boolean = true;
			attribute isBiocompatible: Boolean = true;
			attribute viscosity: ViscosityValue;
			attribute activeDuration: DurationValue = 7;
			exhibit state 'gel lifecycle': 'Gel Lifecycle';
		}
		
		part def Applicator {
			port gelInput: HyalobarrierGel;
			port gelOutput: HyalobarrierGel;
			attribute deliveryVolume: VolumeValue;
			attribute deliveryThickness: ThicknessValue;
		}
		
		part def Surgeon;
		part def Tissue;
		part def Patient {
			part internalTissue: Tissue[1..*];
		}
		
		connection def GelApplication {
			end applicatorPort: Applicator;
			end tissuePort: Tissue;
		}
		
		state def 'Gel Lifecycle';
		
		action def 'Apply Gel' {
			in surgeon: Surgeon;
			in applicator: Applicator;
			in tissue: Tissue[1..*];
			out gel: HyalobarrierGel;
		}
		
		action def 'Provide Barrier' {
			in tissue: Tissue[1..*];
		}
		
		action def 'Absorb Gel' {
			in tissue: Tissue[1..*];
		}
		
		attribute def 'Apply Signal';
		attribute def 'Barrier Active Signal';
		attribute def 'Absorption Complete Signal';
		attribute def 'Duration Elapsed';
	}
	
	package Usages {
		private import Definitions::*;
		
		part 'Hyalobarrier System' {
			part gel: HyalobarrierGel;
			part applicator: Applicator;
			part surgeon: Surgeon;
			part patient: Patient;
			
			connection gelApplication : GelApplication
				connect applicator to patient.internalTissue;
			
			action 'apply gel': 'Apply Gel';
			action 'provide barrier': 'Provide Barrier';
			action 'absorb gel': 'Absorb Gel';
			
			state 'gel lifecycle': 'Gel Lifecycle' {
				entry; then packaged;
				state packaged;
				accept 'Apply Signal' 
					do 'apply gel' 
					then applied;
				state applied;
				accept 'Barrier Active Signal' 
					then activeBarrier;
				state activeBarrier {
					do 'provide barrier';
				}
				accept 'Duration Elapsed' 
					then absorbing;
				state absorbing {
					do 'absorb gel';
				}
				accept 'Absorption Complete Signal' 
					then absorbed;
				state absorbed;
			}
		}
	}
	
	package Requirements {
		requirement def 'Prevent Adhesions' {
			doc /* The system shall prevent post-surgical adhesions between tissues. */
		}
		requirement def 'Biocompatibility' {
			doc /* The gel shall be biocompatible and safe for internal use. */
		}
		requirement def 'Precise Application' {
			doc /* The applicator shall deliver a precise volume and thickness of gel. */
			attribute requiredVolume: VolumeValue;
			attribute requiredThickness: ThicknessValue;
		}
		requirement def 'Effective Duration' {
			doc /* The gel shall remain effective as a barrier for approximately 7 days. */
			attribute minDuration: DurationValue = 7;
		}
		requirement def 'Bioresorbable' {
			doc /* The gel shall be fully absorbed by the body without requiring removal. */
		}
		
		requirement 'prevent adhesions req': 'Prevent Adhesions';
		requirement 'biocompatibility req': 'Biocompatibility';
		requirement 'precise application req': 'Precise Application' {
			:>> requiredVolume = 5;
			:>> requiredThickness = 2;
		}
		requirement 'effective duration req': 'Effective Duration';
		requirement 'bioresorbable req': 'Bioresorbable';
	}
}
