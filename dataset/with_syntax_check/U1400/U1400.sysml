package 'Donald Hill System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ElevationValue :> LengthValue;
    attribute def SlopeValue :> Real;
    attribute def VegetationDensityValue :> Real;
    attribute def SoilMoistureValue :> Real;
    attribute def ErosionRateValue :> Real;
    
    item def Precipitation {
        attribute intensity :> SpeedValue;
        attribute duration :> TimeValue;
        attribute totalVolume :> VolumeValue;
    }
    
    item def SurfaceWater {
        attribute flowRate :> VolumeFlowRateValue;
        attribute velocity :> SpeedValue;
        attribute sedimentLoad :> MassValue;
    }
    
    item def GroundWater {
        attribute infiltrationRate :> SpeedValue;
        attribute storedVolume :> VolumeValue;
        attribute saturationLevel :> Real;
    }
    
    item def VegetationCover {
        attribute density : VegetationDensityValue;
        attribute rootDepth :> LengthValue;
        attribute canopyInterception :> VolumeValue;
    }
    
    item def SoilComposition {
        attribute moisture : SoilMoistureValue;
        attribute permeability :> Real;
        attribute organicContent :> Real;
        attribute depth :> LengthValue;
    }
    
    port def PrecipitationInputPort {
        in item precipitation : Precipitation;
    }
    
    port def RunoffOutputPort {
        out item runoff : SurfaceWater;
    }
    
    port def InfiltrationPort {
        in item surfaceFlow : SurfaceWater;
        out item groundwater : GroundWater;
    }
    
    port def VegetationPort {
        in item rainfall : Precipitation;
        out attribute intercepted :> VolumeValue;
    }
    
    action def InterceptRainfall {
        in precipitation : Precipitation;
        in vegetationDensity : VegetationDensityValue;
        out interceptedVolume :> VolumeValue;
        out throughfall :> VolumeValue;
    }
    
    action def InfiltrateWater {
        in surfaceWater : SurfaceWater;
        in soilPermeability : Real;
        in currentMoisture : SoilMoistureValue;
        out infiltratedVolume :> VolumeValue;
        out excessWater :> VolumeValue;
    }
    
    action def GenerateSurfaceRunoff {
        in excessWater :> VolumeValue;
        in slopeAngle : SlopeValue;
        in surfaceRoughness : Real;
        out runoffFlow : SurfaceWater;
    }
    
    action def ErodeSlope {
        in waterFlow : SurfaceWater;
        in soilErodibility : Real;
        in vegetationProtection : VegetationDensityValue;
        out sedimentYield :> MassValue;
        out erosionDepth :> LengthValue;
    }
    
    action def RouteWater {
        in upstreamFlow : SurfaceWater;
        in channelCapacity :> VolumeFlowRateValue;
        out downstreamFlow : SurfaceWater;
    }
    
    state def HydrologicalState {
        entry; then idle;
        
        state idle;
        
        accept rainfallStart : Precipitation
        transition idle_to_absorbing
            first idle
            then absorbing;
        
        state absorbing;
        
        transition absorbing_to_saturating
            first absorbing
            then saturating;
        
        state saturating;
        
        transition saturating_to_eroding
            first saturating
            then eroding;
        
        state eroding;
        
        accept rainfallEnd
        transition eroding_to_draining
            first eroding
            then draining;
        
        state draining;
        
        transition draining_to_idle
            first draining
            then idle;
    }
    
    action def ManageHillHydrology {
        in rainfallEvent : Precipitation;
        in hillTopography : SlopeValue;
        in vegetationState : VegetationCover;
        in soilState : SoilComposition;
        out totalRunoff : SurfaceWater;
        out totalErosion :> MassValue;
        out infiltratedWater : GroundWater;
        
        first start;
        then merge cycleStart;
        
        then action receiveRainfall {
            in rainfall = rainfallEvent;
            out rainfallVolume :> VolumeValue;
        }
        
        then action canopyInterception : InterceptRainfall {
            in precipitation = receiveRainfall.rainfall;
            in vegetationDensity = vegetationState.density;
            out interceptedVolume;
            out throughfall;
        }
        
        then action soilInfiltration : InfiltrateWater {
            in surfaceWater : SurfaceWater;
            in soilPermeability = soilState.permeability;
            in currentMoisture = soilState.moisture;
            out infiltratedVolume;
            out excessWater;
        }
        
        then decide;
            if soilInfiltration.excessWater.magnitude > 0.0 then generateRunoff;
            if soilInfiltration.excessWater.magnitude <= 0.0 then cycleStart;
        
        action generateRunoff : GenerateSurfaceRunoff {
            in excessWater = soilInfiltration.excessWater;
            in slopeAngle = hillTopography;
            in surfaceRoughness = vegetationState.density;
            out runoffFlow;
        }
        then slopeErosion;
        
        action slopeErosion : ErodeSlope {
            in waterFlow = generateRunoff.runoffFlow;
            in soilErodibility = 0.4;
            in vegetationProtection = vegetationState.density;
            out sedimentYield;
            out erosionDepth;
        }
        then channelRouting;
        
        action channelRouting : RouteWater {
            in upstreamFlow = generateRunoff.runoffFlow;
            in channelCapacity : VolumeFlowRateValue;
            out downstreamFlow;
        }
        then assignOutputs;
        
        action assignOutputs {
            assign totalRunoff := channelRouting.downstreamFlow;
            assign totalErosion := slopeErosion.sedimentYield;
        }
        then cycleStart;
    }
    
    part def HillSegment {
        attribute elevation : ElevationValue;
        attribute slope : SlopeValue;
        attribute area :> AreaValue;
        
        port precipitationIn : PrecipitationInputPort;
        port runoffOut : RunoffOutputPort;
        port infiltrationInterface : InfiltrationPort;
    }
    
    part def VegetationLayer {
        attribute coverage : VegetationDensityValue;
        attribute interceptionCapacity :> VolumeValue;
        
        port vegetationInterface : VegetationPort;
    }
    
    part def SoilProfile {
        attribute thickness :> LengthValue;
        attribute infiltrationCapacity :> SpeedValue;
        attribute saturation : SoilMoistureValue;
        
        port soilInterface : InfiltrationPort;
    }
    
    part def DrainageNetwork {
        attribute channelCapacity :> VolumeFlowRateValue;
        attribute channelLength :> LengthValue;
        attribute channelSlope : SlopeValue;
        
        port inflow : RunoffOutputPort;
        port outflow : RunoffOutputPort;
    }
    
    part donaldHill : HillSegment {
        attribute :>> elevation = 285.0;
        attribute :>> slope = 16.5;
        attribute :>> area = 75000.0;
        
        part upperSegment : HillSegment {
            attribute :>> elevation = 305.0;
            attribute :>> slope = 22.0;
            attribute :>> area = 25000.0;
        }
        
        part middleSegment : HillSegment {
            attribute :>> elevation = 285.0;
            attribute :>> slope = 15.0;
            attribute :>> area = 30000.0;
        }
        
        part lowerSegment : HillSegment {
            attribute :>> elevation = 265.0;
            attribute :>> slope = 10.0;
            attribute :>> area = 20000.0;
        }
        
        part vegetation : VegetationLayer {
            attribute :>> coverage = 0.72;
            attribute :>> interceptionCapacity = 3.5;
        }
        
        part soil : SoilProfile {
            attribute :>> thickness = 1.8;
            attribute :>> infiltrationCapacity = 12.0;
            attribute :>> saturation = 0.45;
        }
        
        part drainage : DrainageNetwork {
            attribute :>> channelCapacity = 6.5;
            attribute :>> channelLength = 450.0;
            attribute :>> channelSlope = 8.0;
        }
        
        perform action hydrologyManagement : ManageHillHydrology;
        
        exhibit state hydrologicBehavior : HydrologicalState;
        
        connection upperToMiddle connect upperSegment.runoffOut to middleSegment.precipitationIn;
        connection middleToLower connect middleSegment.runoffOut to lowerSegment.precipitationIn;
        connection lowerToDrainage connect lowerSegment.runoffOut to drainage.inflow;
    }
    
    requirement def HydrologicManagementRequirement {
        doc /* The Donald Hill system shall regulate hydrologic processes to maintain watershed stability. */
        
        subject donaldHill;
    }
    
    requirement <'DH-MAIN-001'> donaldHillPrimaryFunction {
        doc /* The Donald Hill system shall function as an integrated watershed that receives precipitation, 
             intercepts rainfall through vegetation cover, promotes water infiltration into soil layers, 
             generates controlled surface runoff along sloped terrain segments, routes excess water through 
             drainage networks, and minimizes soil erosion while maintaining hydrologic balance and ecological 
             stability across the hillslope landscape. */
        
        subject donaldHill;
        
        require hydrologicManagementRequirement : HydrologicManagementRequirement;
    }
}
