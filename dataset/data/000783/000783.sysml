package 'Sugar Pack System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SugarGrade {
		attribute gradeType : String;
		attribute purity : Real;
		attribute crystalSize : LengthValue;
	}
	
	attribute def PackagingSpec {
		attribute materialType : String;
		attribute thickness : LengthValue;
		attribute moistureBarrierRating : Real;
		attribute oxygenBarrierRating : Real;
	}
	
	item def SugarCrystals {
		attribute grade : SugarGrade;
		attribute mass : MassValue;
		attribute moistureContent : Real;
		attribute sweetness : Real;
	}
	
	item def PackagingMaterial {
		attribute spec : PackagingSpec;
		attribute sealStrength : ForceValue;
		attribute integrity : Real;
	}
	
	item def SealedSugarPacket {
		attribute contents : SugarCrystals;
		attribute envelope : PackagingMaterial;
		attribute sealedDate : String;
		attribute expiryDate : String;
	}
	
	port def SugarInterfacePort {
		out item sugar : SugarCrystals;
	}
	
	port def ProtectionInterfacePort {
		in attribute humidity : Real;
		in attribute temperature : TemperatureValue;
		out attribute protectionFactor : Real;
	}
	
	port def DispensingPort {
		out item dispensedSugar : SugarCrystals;
	}
	
	part def SugarPacket {
		attribute nominalMass : MassValue;
		attribute shelfLife : DurationValue;
		attribute batchNumber : String;
		
		part sugarContents : SugarCrystals {
			attribute :>> mass;
			attribute :>> grade = SugarGrade {
				attribute :>> gradeType = "refined white";
				attribute :>> purity = 99.8;
				attribute :>> crystalSize = 0.5 [SI::mm];
			}
			attribute :>> moistureContent = 0.02;
			attribute :>> sweetness = 1.0;
		}
		
		part protectivePackaging : PackagingMaterial {
			attribute :>> spec = PackagingSpec {
				attribute :>> materialType = "laminated paper-polymer";
				attribute :>> thickness = 0.1 [SI::mm];
				attribute :>> moistureBarrierRating = 98.0;
				attribute :>> oxygenBarrierRating = 95.0;
			}
			attribute :>> sealStrength = 15.0 [SI::N];
			attribute :>> integrity = 100.0;
		}
		
		port sugarPort : SugarInterfacePort {
			out item :>> sugar = sugarContents;
		}
		
		port environmentalPort : ProtectionInterfacePort;
		
		port dispensingPort : DispensingPort;
		
		connection protectionConnection connect protectivePackaging to environmentalPort;
		connection contentConnection connect sugarPort to dispensingPort;
	}
	
	action def MeasureSugarPortion {
		in targetMass : MassValue;
		in bulkSugar : SugarCrystals;
		out portionedSugar : SugarCrystals;
	}
	
	action def InsertIntoPackaging {
		in sugar : SugarCrystals;
		in packaging : PackagingMaterial;
		out filledPacket : SugarPacket;
	}
	
	action def SealPacket {
		in openPacket : SugarPacket;
		in sealTemperature : TemperatureValue;
		out sealedPacket : SealedSugarPacket;
	}
	
	action def PerformQualityCheck {
		in packet : SealedSugarPacket;
		out passedInspection : Boolean;
		out massDeviation : Real;
		out sealQuality : Real;
	}
	
	action def OpenAndDispense {
		doc /* Primary function: Provide a convenient, single-serving portion of sugar 
		       for sweetening beverages or food items. */
		
		in packet : SugarPacket;
		out deliveredSugar : SugarCrystals;
		
		first start;
		then action tearOpen {
			in sealedPacket = packet;
		}
		then action extractContents {
			out extractedSugar = packet.sugarContents;
		}
		then action pourSugar {
			in sugar = extractContents.extractedSugar;
			out pouredSugar;
		}
		then assign deliveredSugar := pourSugar.pouredSugar;
		then done;
	}
	
	attribute def InspectionCompleteEvent;
	attribute def ShipmentEvent;
	attribute def DeliveryEvent;
	attribute def PurchaseEvent;
	attribute def OpenEvent;
	attribute def DispenseCompleteEvent;
	
	state def PacketLifecycleStates {
		entry; then production;
		
		state production {
			entry; then measuring;
			
			state measuring;
			then packaging;
			
			state packaging;
			then sealing;
			
			state sealing;
			then qualityControl;
			
			state qualityControl;
			then decision inspectionDecision;
		}
		
		state decision inspectionDecision accept inspectionResult : InspectionCompleteEvent;
			if inspectionResult.passed then packaged;
			if not inspectionResult.passed then rejected;
		
		state packaged {
			entry; then warehousing;
			
			state warehousing;
			accept shipment : ShipmentEvent;
			then inTransit;
			
			state inTransit;
			accept delivery : DeliveryEvent;
			then retail;
			
			state retail;
			accept purchase : PurchaseEvent;
			then inUse;
			
			state inUse;
			accept opening : OpenEvent;
			then dispensing;
			
			state dispensing;
			accept dispenseComplete : DispenseCompleteEvent;
			then consumed;
		}
		
		state rejected;
		then done;
		
		state consumed;
		then done;
	}
	
	action def ManufactureSugarPacket {
		in bulkSugarSupply : SugarCrystals;
		in packagingSupply : PackagingMaterial;
		in standardMass : MassValue;
		in sealTemp : TemperatureValue;
		out finishedPacket : SealedSugarPacket;
		
		first start;
		then action measure : MeasureSugarPortion {
			in targetMass = standardMass;
			in bulkSugar = bulkSugarSupply;
			out portionedSugar;
		}
		then action insert : InsertIntoPackaging {
			in sugar = measure.portionedSugar;
			in packaging = packagingSupply;
			out filledPacket;
		}
		then action seal : SealPacket {
			in openPacket = insert.filledPacket;
			in sealTemperature = sealTemp;
			out sealedPacket;
		}
		then action inspect : PerformQualityCheck {
			in packet = seal.sealedPacket;
			out passedInspection;
			out massDeviation;
			out sealQuality;
		}
		then decide;
			if inspect.passedInspection and inspect.massDeviation <= 0.05 and inspect.sealQuality >= 95.0 then accept;
			if not inspect.passedInspection or inspect.massDeviation > 0.05 or inspect.sealQuality < 95.0 then reject;
		
		action accept {
			assign finishedPacket := seal.sealedPacket;
		}
		then done;
		
		action reject;
		then done;
	}
	
	requirement def MassAccuracyRequirement {
		doc /* The sugar packet shall contain the specified mass of sugar within 
		       acceptable tolerance limits. */
		
		subject packet : SugarPacket;
		
		require constraint massWithinTolerance {
			packet.sugarContents.mass >= packet.nominalMass * 0.95 and
			packet.sugarContents.mass <= packet.nominalMass * 1.05
		}
	}
	
	requirement def BarrierProtectionRequirement {
		doc /* The packaging shall provide effective barrier protection against 
		       moisture and oxygen to preserve sugar quality. */
		
		subject packet : SugarPacket;
		
		require constraint moistureBarrier {
			packet.protectivePackaging.spec.moistureBarrierRating >= 95.0
		}
		
		require constraint oxygenBarrier {
			packet.protectivePackaging.spec.oxygenBarrierRating >= 90.0
		}
		
		require constraint sealIntegrity {
			packet.protectivePackaging.integrity >= 99.0
		}
	}
	
	requirement def HygieneRequirement {
		doc /* The sugar packet shall meet food safety and hygiene standards for 
		       direct consumer use. */
		
		subject packet : SugarPacket;
		
		require constraint sugarPurity {
			packet.sugarContents.grade.purity >= 99.5
		}
		
		require constraint foodGradeMaterial {
			packet.protectivePackaging.spec.materialType == "food-grade certified"
		}
		
		require constraint moistureLimit {
			packet.sugarContents.moistureContent <= 0.05
		}
	}
	
	requirement def ConvenienceRequirement {
		doc /* The sugar packet shall provide convenient, single-serving dispensing 
		       for consumer use. */
		
		subject packet : SugarPacket;
		
		require constraint singleServing {
			packet.nominalMass >= 3.0 [SI::g] and
			packet.nominalMass <= 5.0 [SI::g]
		}
		
		require constraint easyOpening {
			packet.protectivePackaging.sealStrength >= 10.0 [SI::N] and
			packet.protectivePackaging.sealStrength <= 20.0 [SI::N]
		}
	}
	
	requirement <'SP-SYS-001'> sugarPacketSystemRequirement {
		doc /* The sugar packet system shall provide single-serving portions of refined 
		       sugar in a sealed, protective package that preserves quality and enables 
		       convenient dispensing for sweetening beverages and food items. */
		
		subject system : SugarPacket;
		
		require massReq : MassAccuracyRequirement {
			subject packet = system;
		}
		
		require barrierReq : BarrierProtectionRequirement {
			subject packet = system;
		}
		
		require hygieneReq : HygieneRequirement {
			subject packet = system;
		}
		
		require convenienceReq : ConvenienceRequirement {
			subject packet = system;
		}
	}
	
	part sugarPacket : SugarPacket {
		attribute :>> nominalMass = 4.0 [SI::g];
		attribute :>> shelfLife = 730.0 [SI::d];
		attribute :>> batchNumber = "SP-2024-001";
		
		binding sugarContents.mass = nominalMass;
		
		perform action manufacture : ManufactureSugarPacket {
			in standardMass = sugarPacket.nominalMass;
			in sealTemp = 180.0 [SI::'°C'];
		}
		
		perform action dispense : OpenAndDispense {
			in packet = sugarPacket;
		}
		
		exhibit state lifecycle : PacketLifecycleStates;
		
		satisfy sugarPacketSystemRequirement;
	}
}
