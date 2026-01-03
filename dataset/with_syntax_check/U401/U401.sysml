package StrawSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FluidType;
	attribute def MaterialType;
	
	item def Liquid {
		attribute fluidType : FluidType;
		attribute volume : VolumeValue;
		attribute viscosity : DynamicViscosityValue;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute density : MassDensityValue;
	}
	
	attribute def PressureDifferential :> PressureValue;
	attribute def FlowRate :> VolumeFlowRateValue;
	
	port def FluidPort {
		attribute pressure : PressureValue;
		attribute flowRate : FlowRate;
		in item liquidIn : Liquid;
		out item liquidOut : Liquid;
	}
	
	port def MouthPort {
		in attribute suctionPressure : PressureDifferential;
		out item deliveredLiquid : Liquid;
	}
	
	part def StrawTube {
		attribute length : LengthValue;
		attribute innerDiameter : LengthValue;
		attribute outerDiameter : LengthValue;
		attribute material : MaterialType;
		attribute flowResistance : Real;
		
		port lowerEnd : FluidPort;
		port upperEnd : FluidPort;
	}
	
	part def BeverageContainer {
		attribute capacity : VolumeValue;
		attribute currentLevel : VolumeValue;
		attribute ambientPressure : PressureValue;
		
		item contents : Liquid;
		port outlet : FluidPort;
	}
	
	part def HumanUser {
		attribute lungCapacity : VolumeValue;
		attribute maxSuctionPressure : PressureValue;
		
		port mouth : MouthPort;
		
		action def GenerateSuction {
			out suctionPressure : PressureDifferential;
		}
		
		action def Swallow {
			in receivedLiquid : Liquid;
		}
	}
	
	action def TransferLiquid {
		in appliedSuction : PressureDifferential;
		in sourceLiquid : Liquid;
		in strawLength : LengthValue;
		in strawDiameter : LengthValue;
		in fluidViscosity : DynamicViscosityValue;
		out transferredVolume : VolumeValue;
		out achievedFlowRate : FlowRate;
		
		private attribute effectivePressure : PressureValue;
		private attribute reynoldsNumber : Real;
	}
	
	signal def SuctionAppliedSignal;
	signal def SuctionReleasedSignal;
	signal def ClearBlockageSignal;
	
	state def FlowState {
		entry; then idle;
		
		state idle {
			entry assign activeFlow := false;
		}
		
		state priming {
			entry assign activeFlow := false;
			do action checkPressure;
		}
		
		state flowing {
			entry assign activeFlow := true;
			do action maintainFlow;
		}
		
		state blocked {
			entry assign activeFlow := false;
		}
		
		transition idle_to_priming
			first idle
			accept SuctionAppliedSignal
			then priming;
		
		transition priming_to_flowing
			first priming
			if pressureDifferential > threshold
			then flowing;
		
		transition flowing_to_idle
			first flowing
			accept SuctionReleasedSignal
			then idle;
		
		transition priming_to_idle
			first priming
			if pressureDifferential <= threshold
			then idle;
		
		transition flowing_to_blocked
			first flowing
			if flowRate < minimumFlow
			then blocked;
		
		transition blocked_to_idle
			first blocked
			accept ClearBlockageSignal
			then idle;
		
		attribute activeFlow : Boolean;
		attribute pressureDifferential : Real;
		attribute flowRate : Real;
		attribute threshold : Real;
		attribute minimumFlow : Real;
	}
	
	part drinkingStraw : StrawTube {
		attribute :>> length = 200.0 [mm];
		attribute :>> innerDiameter = 6.0 [mm];
		attribute :>> outerDiameter = 8.0 [mm];
		attribute :>> flowResistance = 0.15;
		
		exhibit state flowBehavior : FlowState;
		
		perform action transferAction : TransferLiquid[*] ordered;
	}
	
	attribute waterFluidType : FluidType;
	
	part strawDrinkingSystem {
		doc /* 
		This system models the primary function of a straw: to enable liquid transfer 
		from a container to a user's mouth through the application of suction pressure.
		The straw creates a low-pressure pathway that allows atmospheric pressure acting 
		on the liquid surface to push fluid upward through the tube and into the mouth.
		*/
		
		part beverage : BeverageContainer {
			attribute :>> capacity = 500.0 [mL];
			attribute :>> currentLevel = 450.0 [mL];
			attribute :>> ambientPressure = 101325.0 [Pa];
			
			item :>> contents : Liquid {
				attribute :>> fluidType = waterFluidType;
				attribute :>> volume = 450.0 [mL];
				attribute :>> viscosity = 0.001 [Pa*s];
				attribute :>> temperature = 293.15 [K];
				attribute :>> density = 1000.0 [kg/m^3];
			}
		}
		
		part straw : StrawTube :> drinkingStraw;
		
		part user : HumanUser {
			attribute :>> lungCapacity = 6.0 [L];
			attribute :>> maxSuctionPressure = -8000.0 [Pa];
			
			perform action drinkingSequence {
				first start;
				then action createSuction : GenerateSuction {
					out suctionPressure;
				}
				then action ingestLiquid : Swallow {
					in receivedLiquid;
				}
				then done;
			}
		}
		
		connection fluidPathLower : FluidConnection
			connect beverage.outlet to straw.lowerEnd;
		
		connection fluidPathUpper : FluidDelivery
			connect straw.upperEnd to user.mouth;
		
		perform action operateStraw : TransferLiquid {
			in appliedSuction = user.maxSuctionPressure;
			in sourceLiquid = beverage.contents;
			in strawLength = straw.length;
			in strawDiameter = straw.innerDiameter;
			in fluidViscosity = beverage.contents.viscosity;
			out transferredVolume;
			out achievedFlowRate;
		}
	}
	
	connection def FluidConnection {
		end source : FluidPort;
		end sink : FluidPort;
	}
	
	connection def FluidDelivery {
		end supply : FluidPort;
		end destination : MouthPort;
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* 
		The straw system shall transfer liquid from a container to a user's mouth 
		by creating a pressure differential through user-applied suction.
		*/
		
		subject strawSystem : StrawTube;
		
		require constraint enableLiquidTransfer {
			doc /* The straw must permit liquid flow when negative pressure is applied at the upper end. */
		}
		
		require constraint maintainPressureDifferential {
			doc /* The straw must maintain a sealed pathway to preserve the pressure differential. */
		}
		
		require constraint overcomeLiquidWeight {
			doc /* The applied suction must overcome the hydrostatic pressure of the liquid column. */
		}
	}
	
	requirement def StructuralIntegrityRequirement {
		doc /* The straw shall maintain its structural form during normal operation. */
		
		subject strawStructure : StrawTube;
		
		require constraint resistCollapse {
			doc /* The straw walls shall not collapse under maximum expected suction pressure. */
		}
		
		require constraint maintainDimensions {
			doc /* The inner diameter shall remain constant within 5% during use. */
		}
		
		require constraint materialCompatibility {
			doc /* The straw material shall be chemically inert with common beverages. */
		}
	}
	
	requirement def FlowPerformanceRequirement {
		doc /* The straw shall provide adequate flow rate for comfortable drinking. */
		
		subject flowSystem : StrawTube;
		
		require constraint minimumFlowRate {
			doc /* The flow rate shall be at least 8 mL/s under typical suction pressure of -5 kPa. */
		}
		
		require constraint maximumFlowResistance {
			doc /* The flow resistance shall not exceed a value requiring more than -10 kPa suction. */
		}
		
		require constraint consistentFlow {
			doc /* Flow rate variation shall not exceed 20% during continuous use. */
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The straw shall be safe for human use. */
		
		subject strawSafety : StrawTube;
		
		require constraint nonToxicMaterial {
			doc /* All materials in contact with liquid shall be food-grade and non-toxic. */
		}
		
		require constraint noSharpEdges {
			doc /* The straw ends shall have smooth, rounded edges to prevent injury. */
		}
	}
	
	requirement systemRequirements {
		doc /* Complete requirements specification for the straw drinking system. */
		
		subject strawDrinkingSystem;
		
		require requirement primaryFunctionReq : PrimaryFunctionRequirement;
		require requirement structuralIntegrityReq : StructuralIntegrityRequirement;
		require requirement flowPerformanceReq : FlowPerformanceRequirement;
		require requirement safetyReq : SafetyRequirement;
	}
	
	occurrence def DrinkingInteraction {
		doc /* 
		Models the temporal sequence of events during straw usage, 
		showing the interaction between user, straw, and beverage.
		*/
		
		ref part user :>> strawDrinkingSystem.user;
		ref part straw :>> strawDrinkingSystem.straw;
		ref part container :>> strawDrinkingSystem.beverage;
		
		event occurrence userInitiatesSuction;
		then event occurrence pressureDifferentialEstablished;
		then event occurrence liquidEntersStraw;
		then event occurrence liquidRises;
		then event occurrence liquidReachesMouth;
		then event occurrence userSwallows;
		then event occurrence suctionCeases;
		then event occurrence flowStops;
		
		message suctionApplicationMessage of PressureDifferential
			from user.mouth to straw.upperEnd;
		
		then message liquidRequestMessage of Liquid
			from straw.lowerEnd to container.outlet;
		
		then message liquidFlowMessage of Liquid
			from container.outlet to straw.lowerEnd;
		
		then message liquidDeliveryMessage of Liquid
			from straw.upperEnd to user.mouth;
	}
}
