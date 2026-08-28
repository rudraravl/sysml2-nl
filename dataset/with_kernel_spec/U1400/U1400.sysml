package 'Donald Hill Watershed Model' {
	private import ScalarValues::Real;
	private import ScalarValues::String;
	private import ScalarValues::Integer;
	private import ScalarValues::Boolean;
	private import ISQ::*;
	private import SI::*;
	public import Definitions::*;
	public import Usages::*;
	public import Requirements::*;

	package Definitions {
		attribute def RainfallIntensityValue :> Real;
		attribute def SlopeAngleValue :> Real;
		attribute def DensityRatioValue :> Real;
		attribute def SaturationRatioValue :> Real;
		attribute def PermeabilityRateValue :> Real;
		attribute def InterceptionRatioValue :> Real;

		item def Rainfall {
			attribute intensity : RainfallIntensityValue;
			attribute duration : TimeValue;
		}
		item def Water {
			attribute volume : VolumeValue;
		}
		item def Sediment {
			attribute mass : MassValue;
			attribute volume : VolumeValue;
		}

		port def RainfallPort {
			in item rainfall : Rainfall;
		}
		port def WaterOutPort {
			out item waterFlow : Water;
		}
		port def WaterInPort {
			in item waterFlow : Water;
		}
		port def SedimentOutPort {
			out item sedimentFlow : Sediment;
		}
		port def SedimentInPort {
			in item sedimentFlow : Sediment;
		}
		port def DrainageInflowPort {
			in item waterFlow : Water;
			in item sedimentFlow : Sediment;
		}
		port def OutletPort {
			out item waterFlow : Water;
			out item sedimentFlow : Sediment;
		}

		part def Vegetation {
			attribute density : DensityRatioValue;
			attribute canopyInterception : InterceptionRatioValue;
			port rainfallIn : RainfallPort;
			port throughfallOut : WaterOutPort;
		}

		part def Soil {
			attribute thickness : LengthValue;
			attribute permeability : PermeabilityRateValue;
			attribute fieldCapacity : VolumeValue;
			attribute saturation : SaturationRatioValue;
			port waterIn : WaterInPort;
			port excessOut : WaterOutPort;
		}

		part def SlopeSegment {
			attribute elevation : LengthValue;
			attribute steepness : SlopeAngleValue;
			attribute surfaceArea : AreaValue;
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			port sedimentOut : SedimentOutPort;
		}

		part def DrainageNetwork {
			attribute channelCount : Integer;
			port collectionPort : DrainageInflowPort;
			port outletPort : OutletPort;
		}

		part def Hill {
			attribute name : String;
			port rainfallIn : RainfallPort;
			port outflow : OutletPort;
			part upperSlope : SlopeSegment;
			part middleSlope : SlopeSegment;
			part lowerSlope : SlopeSegment;
			part vegetation : Vegetation;
			part soil : Soil;
			part drainage : DrainageNetwork;
		}

		action def InterceptRainfall {
			in rainfall : Rainfall;
			in canopyInterception : InterceptionRatioValue;
			out throughfall : Water;
		}
		action def InfiltrateWater {
			in inflow : Water;
			in permeability : PermeabilityRateValue;
			in saturation : SaturationRatioValue;
			out absorbed : Water;
			out excess : Water;
		}
		action def GenerateRunoff {
			in excessWater : Water;
			out runoff : Water;
		}
		action def ErodeSoil {
			in runoff : Water;
			in steepness : SlopeAngleValue;
			in vegetationDensity : DensityRatioValue;
			out sediment : Sediment;
		}
		action def ConveyRunoff {
			in runoff : Water;
			in sediment : Sediment;
			out outflowWater : Water;
			out outflowSediment : Sediment;
		}
		action def ProcessRainfall {
			in rainfall : Rainfall;
			out outflowWater : Water;
			out outflowSediment : Sediment;
		}

		attribute def RainfallStartSignal;
		attribute def SaturationSignal;
		attribute def HeavyFlowSignal;
		attribute def RainfallStopSignal;
		attribute def DrainageCompleteSignal;

		state def WatershedStates;
	}

	package Usages {
		private import Definitions::*;

		part donaldHill : Hill {
			attribute :>> name = "Donald Hill";

			part upperSlope : SlopeSegment {
				attribute :>> elevation = 450 [m];
				attribute :>> steepness = 35;
				attribute :>> surfaceArea = 12000 [m^2];
			}
			part middleSlope : SlopeSegment {
				attribute :>> elevation = 350 [m];
				attribute :>> steepness = 20;
				attribute :>> surfaceArea = 18000 [m^2];
			}
			part lowerSlope : SlopeSegment {
				attribute :>> elevation = 250 [m];
				attribute :>> steepness = 10;
				attribute :>> surfaceArea = 22000 [m^2];
			}

			part vegetation : Vegetation {
				attribute :>> density = 0.6;
				attribute :>> canopyInterception = 0.3;
			}
			part soil : Soil {
				attribute :>> thickness = 1.5 [m];
				attribute :>> permeability = 0.0001;
				attribute :>> fieldCapacity = 50000 [m^3];
				attribute :>> saturation = 0.0;
			}
			part drainage : DrainageNetwork {
				attribute :>> channelCount = 3;
			}

			flow of rainfall : Rainfall
				from rainfallIn.rainfall to vegetation.rainfallIn.rainfall;
			flow of throughfall : Water
				from vegetation.throughfallOut.waterFlow to soil.waterIn.waterFlow;
			flow of excessWater : Water
				from soil.excessOut.waterFlow to upperSlope.waterIn.waterFlow;
			flow of upperRunoff : Water
				from upperSlope.waterOut.waterFlow to middleSlope.waterIn.waterFlow;
			flow of middleRunoff : Water
				from middleSlope.waterOut.waterFlow to lowerSlope.waterIn.waterFlow;
			flow of lowerRunoff : Water
				from lowerSlope.waterOut.waterFlow to drainage.collectionPort.waterFlow;
			flow of lowerSediment : Sediment
				from lowerSlope.sedimentOut.sedimentFlow to drainage.collectionPort.sedimentFlow;
			flow of dischargeWater : Water
				from drainage.outletPort.waterFlow to outflow.waterFlow;
			flow of dischargeSediment : Sediment
				from drainage.outletPort.sedimentFlow to outflow.sedimentFlow;

			perform action processRainfall : ProcessRainfall {
				in rainfall = rainfallIn.rainfall;
				out outflowWater = outflow.waterFlow;
				out outflowSediment = outflow.sedimentFlow;

				action intercept : InterceptRainfall {
					in rainfall = processRainfall::rainfall;
					in canopyInterception = vegetation.canopyInterception;
					out throughfall : Water;
				}
				action infiltrate : InfiltrateWater {
					in inflow : Water;
					in permeability = soil.permeability;
					in saturation = soil.saturation;
					out excess : Water;
				}
				action generateRunoffAct : GenerateRunoff {
					in excessWater : Water;
					out runoff : Water;
				}
				action erode : ErodeSoil {
					in runoff : Water;
					in steepness = lowerSlope.steepness;
					in vegetationDensity = vegetation.density;
					out sediment : Sediment;
				}
				action convey : ConveyRunoff {
					in runoff : Water;
					in sediment : Sediment;
					out outflowWater : Water;
					out outflowSediment : Sediment;
				}
				flow intercept.throughfall to infiltrate.inflow;
				flow infiltrate.excess to generateRunoffAct.excessWater;
				flow generateRunoffAct.runoff to erode.runoff;
				flow generateRunoffAct.runoff to convey.runoff;
				flow erode.sediment to convey.sediment;
				flow convey.outflowWater to processRainfall.outflowWater;
				flow convey.outflowSediment to processRainfall.outflowSediment;
			}

			exhibit state watershedStates : WatershedStates {
				entry; then idle;
				state idle;
				accept RainfallStartSignal then absorbing;
				state absorbing;
				accept SaturationSignal then saturating;
				accept RainfallStopSignal then draining;
				state saturating;
				accept HeavyFlowSignal then eroding;
				accept RainfallStopSignal then draining;
				state eroding;
				accept RainfallStopSignal then draining;
				state draining;
				accept DrainageCompleteSignal then idle;
			}
		}
	}

	package Requirements {
		private import Definitions::*;
		private import Usages::*;

		requirement def WatershedStructureRequirement {
			subject hill : Hill;
			doc /* The hill shall be composed of upper, middle, and lower slope segments, each with elevation, steepness, and surface area. */;
		}
		requirement def RainfallInterceptionRequirement {
			subject hill : Hill;
			doc /* The vegetation layer shall intercept a portion of incident rainfall before it reaches the soil. */;
		}
		requirement def SoilAbsorptionRequirement {
			subject hill : Hill;
			doc /* The soil shall absorb water according to its permeability and field capacity, with excess water becoming runoff. */;
		}
		requirement def RunoffFlowRequirement {
			subject hill : Hill;
			doc /* Surface runoff shall flow downhill from the upper slope through the middle slope to the lower slope. */;
		}
		requirement def ErosionRequirement {
			subject hill : Hill;
			doc /* Erosion shall depend on runoff volume, slope steepness, and vegetation density. */;
		}
		requirement def DrainageCollectionRequirement {
			subject hill : Hill;
			doc /* All runoff and sediment from the lower slope shall be collected by the drainage network and routed off the hillslope. */;
		}
		requirement def WatershedStateRequirement {
			subject hill : Hill;
			doc /* The watershed shall cycle through idle, absorbing, saturating, eroding, and draining states in response to rainfall events. */;
		}

		requirement structureReq : WatershedStructureRequirement {
			subject hill = donaldHill;
		}
		requirement interceptionReq : RainfallInterceptionRequirement {
			subject hill = donaldHill;
		}
		requirement absorptionReq : SoilAbsorptionRequirement {
			subject hill = donaldHill;
		}
		requirement runoffReq : RunoffFlowRequirement {
			subject hill = donaldHill;
		}
		requirement erosionReq : ErosionRequirement {
			subject hill = donaldHill;
		}
		requirement drainageReq : DrainageCollectionRequirement {
			subject hill = donaldHill;
		}
		requirement stateReq : WatershedStateRequirement {
			subject hill = donaldHill;
		}
	}
}
