package 'SurgicalMaskSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FiltrationEfficiencyPercent :> Real {
		assert constraint { FiltrationEfficiencyPercent >= 0.0 and FiltrationEfficiencyPercent <= 100.0 }
	}
	
	attribute def ParticleSizeMicrons :> LengthValue;
	
	item def AirborneParticle {
		attribute diameter : ParticleSizeMicrons;
		attribute isBacterial : Boolean;
		attribute isViral : Boolean;
	}
	
	item def AirStream {
		attribute flowRate : ISQ::VolumeFlowValue;
		attribute pressure : PressureValue;
		attribute particles : AirborneParticle[*];
		attribute particleConcentration : Real;
	}
	
	item def FilteredAir :> AirStream {
		attribute filtrationLevel : FiltrationEfficiencyPercent;
	}
	
	port def AirIntakePort {
		in item ambientAir : AirStream;
	}
	
	port def AirOutputPort {
		out item processedAir : FilteredAir;
	}
	
	part def FilterLayer {
		attribute material : String;
		attribute thickness : LengthValue;
		attribute poreDiameter : ParticleSizeMicrons;
		attribute filtrationEfficiency : FiltrationEfficiencyPercent;
		
		port airIn : AirIntakePort;
		port airOut : AirOutputPort;
		
		perform action filterParticles {
			in incomingAir : AirStream = airIn.ambientAir;
			out outgoingAir : FilteredAir;
			
			action captureParticles {
				in particles : AirborneParticle[*] = incomingAir.particles;
				in efficiency : FiltrationEfficiencyPercent = filtrationEfficiency;
				out retained : AirborneParticle[*];
				out passed : AirborneParticle[*];
			}
			
			then action produceFilteredStream {
				in remainingParticles : AirborneParticle[*] = captureParticles.passed;
				in originalFlow : ISQ::VolumeFlowValue = incomingAir.flowRate;
				in originalPressure : PressureValue = incomingAir.pressure;
				out cleanAir : FilteredAir;
				
				then assign cleanAir.particles := remainingParticles;
				then assign cleanAir.flowRate := originalFlow;
				then assign cleanAir.pressure := originalPressure;
				then assign cleanAir.filtrationLevel := filtrationEfficiency;
			}
			
			then assign outgoingAir := produceFilteredStream.cleanAir;
		}
	}
	
	part def OuterLayer :> FilterLayer {
		attribute :>> material = "Spunbond Polypropylene";
		attribute :>> thickness = 0.3 [SI::mm];
		attribute :>> poreDiameter = 20.0e-6 [SI::m];
		attribute :>> filtrationEfficiency = 65.0;
	}
	
	part def MiddleLayer :> FilterLayer {
		attribute :>> material = "Meltblown Polypropylene";
		attribute :>> thickness = 0.25 [SI::mm];
		attribute :>> poreDiameter = 0.5e-6 [SI::m];
		attribute :>> filtrationEfficiency = 98.0;
		attribute electrostaticCharge : Boolean = true;
	}
	
	part def InnerLayer :> FilterLayer {
		attribute :>> material = "Soft Spunbond Polypropylene";
		attribute :>> thickness = 0.3 [SI::mm];
		attribute :>> poreDiameter = 15.0e-6 [SI::m];
		attribute :>> filtrationEfficiency = 70.0;
	}
	
	part def NosePiece {
		attribute material : String = "Aluminum Strip";
		attribute length : LengthValue = 90.0 [SI::mm];
		attribute width : LengthValue = 3.0 [SI::mm];
		attribute flexibility : Real = 0.75;
		
		perform action conformToNasalBridge;
	}
	
	part def EarLoop {
		attribute material : String = "Elastic";
		attribute length : LengthValue = 175.0 [SI::mm];
		attribute tension : ForceValue = 1.2 [SI::N];
		attribute elasticity : Real = 0.85;
		
		perform action secureToEar;
	}
	
	part def SurgicalMask {
		attribute totalThickness : LengthValue;
		attribute overallFiltrationEfficiency : FiltrationEfficiencyPercent;
		attribute breathingResistance : PressureValue;
		attribute effectiveArea : AreaValue = 150.0 [SI::cm^2];
		
		port externalEnvironment : AirIntakePort;
		port wearerInterface : AirOutputPort;
		
		part outerLayer : OuterLayer {
			port :>> airIn = externalEnvironment;
		}
		
		part middleLayer : MiddleLayer;
		
		part innerLayer : InnerLayer {
			port :>> airOut = wearerInterface;
		}
		
		part nosePiece : NosePiece[1];
		
		part earLoops : EarLoop[2];
		
		connection outerToMiddle connect outerLayer.airOut to middleLayer.airIn;
		connection middleToInner connect middleLayer.airOut to innerLayer.airIn;
		
		perform action protectWearer {
			first start;
			
			then action donMask {
				perform nosePiece.conformToNasalBridge;
				perform earLoops.secureToEar;
			}
			
			then merge continuousProtection;
			
			then action filterInhalation {
				in environmentalAir : AirStream = externalEnvironment.ambientAir;
				out protectedAir : FilteredAir;
				
				action outerFiltration : outerLayer.filterParticles {
					in incomingAir = environmentalAir;
					out outgoingAir;
				}
				
				then action middleFiltration : middleLayer.filterParticles {
					in incomingAir = outerFiltration.outgoingAir;
					out outgoingAir;
				}
				
				then action innerFiltration : innerLayer.filterParticles {
					in incomingAir = middleFiltration.outgoingAir;
					out outgoingAir;
				}
				
				then assign protectedAir := innerFiltration.outgoingAir;
			}
			
			then decide;
				if filterInhalation.protectedAir.filtrationLevel >= 95.0 
					then continuousProtection;
				if filterInhalation.protectedAir.filtrationLevel < 95.0 
					then replaceMask;
			
			action replaceMask;
			then done;
		}
	}
	
	requirement def ProtectionRequirement {
		doc /* The surgical mask shall provide effective barrier protection against airborne particles and pathogens. */
		
		subject mask : SurgicalMask;
		
		require constraint bacterialFiltrationEfficiency {
			doc /* The mask shall filter at least 95% of bacterial particles (3.0 μm diameter). */
			mask.overallFiltrationEfficiency >= 95.0
		}
		
		require constraint particleFiltrationEfficiency {
			doc /* The mask shall filter at least 98% of sub-micron particles (0.1 μm diameter). */
			mask.middleLayer.filtrationEfficiency >= 98.0
		}
		
		require constraint breathability {
			doc /* The differential pressure shall be less than 60 Pascals per cm² at 8 L/min flow. */
			mask.breathingResistance < 60.0 [SI::Pa]
		}
	}
	
	requirement def ComfortRequirement {
		doc /* The surgical mask shall be comfortable for extended wear periods. */
		
		subject mask : SurgicalMask;
		
		require constraint lightWeight {
			doc /* The total thickness shall be less than 1.0 mm for comfort. */
			mask.totalThickness < 1.0 [SI::mm]
		}
		
		require constraint secureFit {
			doc /* The mask shall maintain secure fit without excessive pressure. */
			mask.nosePiece.flexibility > 0.5 and
			mask.earLoops[1].tension > 0.8 [SI::N] and mask.earLoops[1].tension < 2.0 [SI::N] and
			mask.earLoops[2].tension > 0.8 [SI::N] and mask.earLoops[2].tension < 2.0 [SI::N]
		}
	}
	
	requirement def FluidResistanceRequirement {
		doc /* The surgical mask shall resist penetration by fluids. */
		
		subject mask : SurgicalMask;
		
		require constraint splashResistance {
			doc /* The outer layer shall resist fluid penetration at 120 mmHg pressure. */
			mask.outerLayer.material == "Spunbond Polypropylene"
		}
	}
	
	requirement maskSystemRequirements {
		doc /* The surgical mask system shall protect the wearer from airborne pathogens 
		       while maintaining comfort and breathability during extended use. */
		
		subject surgicalMask : SurgicalMask;
		
		require protectionReq : ProtectionRequirement {
			subject mask = surgicalMask;
		}
		
		require comfortReq : ComfortRequirement {
			subject mask = surgicalMask;
		}
		
		require fluidReq : FluidResistanceRequirement {
			subject mask = surgicalMask;
		}
	}
	
	part maskInstance : SurgicalMask {
		attribute :>> totalThickness = 0.85 [SI::mm];
		attribute :>> overallFiltrationEfficiency = 98.5;
		attribute :>> breathingResistance = 45.0 [SI::Pa];
		
		perform action protectWearer[*] ordered;
	}
	
	action def UseMask {
		in wearer : String;
		in environment : AirStream;
		in usageDuration : TimeValue;
		out protection : FilteredAir;
		
		action donMask {
			perform maskInstance.protectWearer.donMask;
		}
		
		then action maintainProtection {
			perform maskInstance.protectWearer.filterInhalation;
			out cleanAir : FilteredAir;
		}
		
		then assign protection := maintainProtection.cleanAir;
	}
}
