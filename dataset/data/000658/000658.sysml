package KidneyDishSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	doc /* 
	 * This model describes a kidney dish system used in medical and surgical settings.
	 * A kidney dish is a shallow, kidney-shaped basin designed to temporarily hold
	 * medical instruments, biological specimens, fluids, and waste materials during
	 * procedures. Its primary function is to provide a sterile, accessible containment
	 * surface that facilitates safe handling and transfer of materials while maintaining
	 * aseptic conditions.
	 */
	
	attribute def MaterialType :> String;
	attribute def SterilityStatus :> String;
	
	item def BiologicalFluid {
		attribute volume : VolumeValue;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute contaminationLevel : Real;
	}
	
	item def MedicalInstrument {
		attribute mass : MassValue;
		attribute length : LengthValue;
		attribute isSterile : Boolean;
	}
	
	item def TissueSpecimen {
		attribute mass : MassValue;
		attribute preservationRequired : Boolean;
	}
	
	port def FluidIntakePort {
		in item receivedFluid : BiologicalFluid;
	}
	
	port def InstrumentHoldingPort {
		in item receivedInstrument : MedicalInstrument[*];
		out item retrievedInstrument : MedicalInstrument[*];
	}
	
	port def SpecimenPort {
		in item receivedSpecimen : TissueSpecimen;
	}
	
	part def KidneyDishContainer {
		attribute capacity : VolumeValue;
		attribute currentVolume : VolumeValue;
		attribute material : MaterialType;
		attribute sterilityStatus : SterilityStatus;
		attribute depth : LengthValue;
		attribute surfaceArea : AreaValue;
		
		port fluidIntake : FluidIntakePort;
		port instrumentHolding : InstrumentHoldingPort;
		port specimenStorage : SpecimenPort;
		
		state dishLifecycle {
			entry; then Sterile;
			
			state Sterile;
			
			transition first Sterile
				then InUse
				accept receiveContent;
			
			state InUse {
				entry; then Receiving;
				
				state Receiving;
				state Holding;
				state NearCapacity;
				
				transition first Receiving
					then Holding;
				
				transition ReceivingToHolding
					first Receiving
					then Holding;
				
				transition HoldingToNearCapacity
					first Holding
					then NearCapacity;
				
				transition NearCapacityToHolding
					first NearCapacity
					then Holding;
			}
			
			transition InUseToContaminated
				first InUse
				then Contaminated
				accept procedureComplete;
			
			state Contaminated;
			
			transition ContaminatedToAwaitingCleaning
				first Contaminated
				then AwaitingCleaning
				accept transferToWaste;
			
			state AwaitingCleaning;
			
			transition AwaitingCleaningToCleaning
				first AwaitingCleaning
				then Cleaning
				accept beginCleaning;
			
			state Cleaning;
			
			transition CleaningToSterile
				first Cleaning
				then Sterile
				accept sterilizationComplete;
		}
	}
	
	part def SterilizationUnit {
		attribute sterilizationMethod : String;
		attribute sterilizationTemperature : ThermodynamicTemperatureValue;
		attribute sterilizationDuration : TimeValue;
		
		port sterilizationInterface {
			out attribute sterileConfirmation : Boolean;
		}
	}
	
	part def MedicalProcedureStation {
		attribute procedureType : String;
		
		port instrumentSource {
			out item usedInstruments : MedicalInstrument[*];
		}
		
		port fluidSource {
			out item procedureFluid : BiologicalFluid;
		}
		
		port specimenSource {
			out item excisedTissue : TissueSpecimen;
		}
	}
	
	part def WasteDisposalUnit {
		attribute wasteVolume : VolumeValue;
		
		port wasteIntake {
			in item contaminatedFluid : BiologicalFluid;
			in item contaminatedInstruments : MedicalInstrument[*];
		}
	}
	
	action def ReceiveFluid {
		in fluid : BiologicalFluid;
		inout container : KidneyDishContainer;
		out accepted : Boolean;
	}
	
	action def HoldInstruments {
		in instruments : MedicalInstrument[*];
		inout container : KidneyDishContainer;
		out stored : Boolean;
	}
	
	action def TransferSpecimen {
		in specimen : TissueSpecimen;
		inout container : KidneyDishContainer;
		out transferred : Boolean;
	}
	
	action def EmptyContents {
		inout container : KidneyDishContainer;
		out disposalUnit : WasteDisposalUnit;
	}
	
	action def SterilizeDish {
		inout container : KidneyDishContainer;
		in sterilizer : SterilizationUnit;
		out sterilized : Boolean;
	}
	
	action def KidneyDishOperationalCycle {
		inout dish : KidneyDishContainer;
		in procedureStation : MedicalProcedureStation;
		in sterilizer : SterilizationUnit;
		in disposal : WasteDisposalUnit;
		
		first start;
		
		then accept receiveContent;
		
		then merge collectMaterials;
		
		then action receiveFluidAction : ReceiveFluid {
			in fluid;
			inout container = dish;
			out accepted;
		}
		
		then action holdInstrumentsAction : HoldInstruments {
			in instruments;
			inout container = dish;
			out stored;
		}
		
		then action transferSpecimenAction : TransferSpecimen {
			in specimen;
			inout container = dish;
			out transferred;
		}
		
		then decide;
			if receiveFluidAction.accepted then proceedToDisposal;
			else collectMaterials;
		
		merge proceedToDisposal;
		
		then accept procedureComplete;
		
		then accept transferToWaste;
		
		then action emptyDish : EmptyContents {
			inout container = dish;
			out disposalUnit = disposal;
		}
		
		then accept beginCleaning;
		
		then action sterilize : SterilizeDish {
			inout container = dish;
			in sterilizer = sterilizer;
			out sterilized;
		}
		
		then accept sterilizationComplete;
		
		then done;
	}
	
	part kidneyDishSystem {
		attribute operatingTemperature : ThermodynamicTemperatureValue;
		attribute maxOperatingCapacity : VolumeValue;
		
		part container : KidneyDishContainer {
			attribute :>> capacity = 750.0 [mL];
			attribute :>> currentVolume = 0.0 [mL];
			attribute :>> material = "medical_grade_stainless_steel";
			attribute :>> sterilityStatus = "sterile";
			attribute :>> depth = 40.0 [mm];
			attribute :>> surfaceArea = 0.025 [m^2];
		}
		
		part sterilizationUnit : SterilizationUnit {
			attribute :>> sterilizationMethod = "autoclave";
			attribute :>> sterilizationTemperature = 407.15 [K];
			attribute :>> sterilizationDuration = 1080.0 [s];
		}
		
		part procedureStation : MedicalProcedureStation {
			attribute :>> procedureType = "surgical";
		}
		
		part wasteDisposal : WasteDisposalUnit {
			attribute :>> wasteVolume = 0.0 [L];
		}
		
		connect procedureStation.fluidSource to container.fluidIntake;
		connect procedureStation.instrumentSource to container.instrumentHolding;
		connect procedureStation.specimenSource to container.specimenStorage;
		connect sterilizationUnit.sterilizationInterface to container;
		
		perform action operationalCycle[*] ordered references KidneyDishOperationalCycle {
			inout dish = container;
			in procedureStation = procedureStation;
			in sterilizer = sterilizationUnit;
			in disposal = wasteDisposal;
		}
		
		part containerPerformer : KidneyDishContainer {
			perform operationalCycle.receiveFluidAction;
			perform operationalCycle.holdInstrumentsAction;
			perform operationalCycle.transferSpecimenAction;
		}
		
		part sterilizationPerformer : SterilizationUnit {
			perform operationalCycle.sterilize;
		}
		
		part disposalPerformer : WasteDisposalUnit {
			perform operationalCycle.emptyDish;
		}
	}
	
	requirement def SterilityMaintenance {
		doc /* The kidney dish shall maintain sterile conditions from sterilization until first use. */
		subject dish : KidneyDishContainer;
		require constraint { 
			dish.sterilityStatus == "sterile" or 
			dish.sterilityStatus == "in_use" or 
			dish.sterilityStatus == "contaminated" or
			dish.sterilityStatus == "awaiting_cleaning"
		}
	}
	
	requirement def CapacityCompliance {
		doc /* The kidney dish shall not exceed its rated capacity during operation. */
		subject dish : KidneyDishContainer;
		require constraint { dish.currentVolume <= dish.capacity }
	}
	
	requirement def MaterialSafety {
		doc /* The kidney dish shall be constructed from biocompatible, non-reactive materials. */
		subject dish : KidneyDishContainer;
		require constraint { 
			dish.material == "medical_grade_stainless_steel" or 
			dish.material == "autoclavable_polymer"
		}
	}
	
	requirement def ContainmentIntegrity {
		doc /* The kidney dish shall prevent spillage and maintain fluid containment during normal handling. */
		subject dish : KidneyDishContainer;
	}
	
	requirement <'KD-SYS-001'> primaryFunctionRequirement {
		doc /* 
		 * The kidney dish system shall provide sterile, temporary containment for medical
		 * instruments, biological fluids, and tissue specimens during surgical and laboratory
		 * procedures, facilitating safe material handling and transfer while maintaining
		 * aseptic conditions throughout the procedure lifecycle.
		 */
		
		assume constraint initialSterileState {
			doc /* The system begins operation in a verified sterile state. */
		}
		
		require sterilityReq : SterilityMaintenance;
		require capacityReq : CapacityCompliance;
		require materialReq : MaterialSafety;
		require containmentReq : ContainmentIntegrity;
	}
	
	satisfy primaryFunctionRequirement by kidneyDishSystem;
}
