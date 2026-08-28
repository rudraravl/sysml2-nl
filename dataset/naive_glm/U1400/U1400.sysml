package DonaldHillWatershed {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value def Elevation :> Real { unit 'm'; }
    value def SlopeAngle :> Real { unit 'deg'; }
    value def Area :> Real { unit 'm2'; }
    value def Density :> Real { unit '1'; } // dimensionless ratio 0..1
    value def Thickness :> Real { unit 'm'; }
    value def Permeability :> Real { unit 'mm/h'; }
    value def RainfallIntensity :> Real { unit 'mm/h'; }
    value def WaterVolume :> Real { unit 'm3'; }
    value def FlowRate :> Real { unit 'm3/s'; }
    value def SedimentMass :> Real { unit 'kg'; }
    value def ErosionRate :> Real { unit 'kg/s'; }
    value def SoilMoisture :> Real { unit '1'; } // saturation ratio 0..1
    value def Duration :> Real { unit 'h'; }

    // ---- Item definitions ----
    item def Rainfall;
    item def Raindrop;
    item def SurfaceWater;
    item def InfiltratedWater;
    item def Sediment;
    item def Runoff;

    // ---- Port definitions ----
    port def RainfallPort {
        in item rainfall : Rainfall;
        in attr intensity : RainfallIntensity;
    }
    port def RunoffPort {
        out item runoff : Runoff;
        out attr flowRate : FlowRate;
        out item sediment : Sediment;
        out attr sedimentLoad : ErosionRate;
    }
    port def InflowPort {
        in item runoff : Runoff;
        in attr flowRate : FlowRate;
        in item sediment : Sediment;
        in attr sedimentLoad : ErosionRate;
    }
    port def DrainageOutPort {
        out item water : SurfaceWater;
        out attr discharge : FlowRate;
        out item sediment : Sediment;
        out attr sedimentLoad : ErosionRate;
    }

    // ---- Vegetation ----
    part def Vegetation {
        attr canopyDensity : Density = 0.65;
        attr rootCohesion : Real = 3.0;
        attr coverFraction : Density = 0.70;
        in item incomingRain : Rainfall;
        out item throughfall : Raindrop;
        out item intercepted : Rainfall;
        attr interceptedFraction : Density = 0.0;

        action def interceptRainfall {
            in rain : Rainfall;
            in density : Density;
            out through : Raindrop;
            out intercepted : Rainfall;
        }
    }

    // ---- Soil ----
    part def SoilProfile {
        attr thickness : Thickness = 1.2;
        attr permeability : Permeability = 15.0;
        attr porosity : Density = 0.35;
        attr fieldCapacity : SoilMoisture = 0.30;
        attr saturationThreshold : SoilMoisture = 0.95;
        attr currentMoisture : SoilMoisture = 0.20;
        attr availableStorage : WaterVolume = 0.0;

        in item inflow : Raindrop;
        out item infiltrated : InfiltratedWater;
        out item excess : SurfaceWater;

        action def absorbWater {
            in rain : Raindrop;
            in perm : Permeability;
            in moisture : SoilMoisture;
            out inf : InfiltratedWater;
            out excess : SurfaceWater;
            out newMoisture : SoilMoisture;
        }
    }

    // ---- Slope segment ----
    part def SlopeSegment {
        attr elevation : Elevation;
        attr steepness : SlopeAngle;
        attr surfaceArea : Area;
        attr segmentName : String;

        port rainfallIn : RainfallPort;
        port runoffOut : RunoffPort;
        port runoffIn : InflowPort;

        part vegetation : Vegetation;
        part soil : SoilProfile;

        attr storedWater : WaterVolume = 0.0;
        attr accumulatedSediment : SedimentMass = 0.0;
        attr erosionPotential : Real = 0.0;

        action def generateRunoff {
            in excessWater : SurfaceWater;
            in slope : SlopeAngle;
            in vegCover : Density;
            out runoff : Runoff;
            out sediment : Sediment;
            out erosion : ErosionRate;
        }

        action def routeFlow {
            in inflow : Runoff;
            in inflowSediment : Sediment;
            out outflow : Runoff;
            out outSediment : Sediment;
        }
    }

    // ---- Drainage network ----
    part def DrainageNetwork {
        attr channelLength : Real = 850;
        attr channelCapacity : FlowRate = 12.0;
        attr totalSediment : SedimentMass = 0.0;
        attr totalDischarge : WaterVolume = 0.0;

        port inflow : InflowPort;
        port outflow : DrainageOutPort;

        action def collectRunoff {
            in runoff : Runoff;
            in sediment : Sediment;
            out water : SurfaceWater;
            out sed : Sediment;
            out discharge : FlowRate;
        }
    }

    // ---- Donald Hill ----
    part def DonaldHill {
        attr hillName : String = "Donald Hill";
        attr peakElevation : Elevation = 420.0;
        attr baseElevation : Elevation = 180.0;
        attr totalArea : Area = 250000.0;

        port rainfallReceiver : RainfallPort;
        port drainageOutlet : DrainageOutPort;

        part upperSlope : SlopeSegment {
            attr elevation = 420.0;
            attr steepness = 28.0;
            attr surfaceArea = 80000.0;
            attr segmentName = "Upper";
        }
        part middleSlope : SlopeSegment {
            attr elevation = 320.0;
            attr steepness = 20.0;
            attr surfaceArea = 90000.0;
            attr segmentName = "Middle";
        }
        part lowerSlope : SlopeSegment {
            attr elevation = 220.0;
            attr steepness = 12.0;
            attr surfaceArea = 80000.0;
            attr segmentName = "Lower";
        }
        part drainage : DrainageNetwork;

        connection rainfallToUpper connect rainfallReceiver to upperSlope.rainfallIn;
        connection flowUpperToMiddle connect upperSlope.runoffOut to middleSlope.runoffIn;
        connection flowMiddleToLower connect middleSlope.runoffOut to lowerSlope.runoffIn;
        connection flowLowerToDrainage connect lowerSlope.runoffOut to drainage.inflow;
        connection drainageOutlet connect drainage.outflow to drainageOutlet;

        // ---- State machine ----
        state def WatershedBehavior {
            entry action initSystem {
                upperSlope.soil.currentMoisture = 0.18;
                middleSlope.soil.currentMoisture = 0.22;
                lowerSlope.soil.currentMoisture = 0.25;
            }

            state idle {
                entry action logIdle { /* dry conditions, no rainfall */ }
                transition idle_to_absorbing
                    first idle
                    when rainfallReceiver.intensity > 0.0
                    to absorbing;
            }

            state absorbing {
                entry action beginInfiltration {
                    perform upperSlope.vegetation.interceptRainfall(
                        rainfallReceiver.rainfall,
                        upperSlope.vegetation.canopyDensity,
                        upperSlope.vegetation.throughfall,
                        upperSlope.vegetation.intercepted);
                    perform upperSlope.soil.absorbWater(
                        upperSlope.vegetation.throughfall,
                        upperSlope.soil.permeability,
                        upperSlope.soil.currentMoisture,
                        upperSlope.soil.infiltrated,
                        upperSlope.soil.excess,
                        upperSlope.soil.currentMoisture);
                }
                do action continueAbsorbing {
                    // Continue infiltration across all segments
                    perform middleSlope.soil.absorbWater(
                        middleSlope.vegetation.throughfall,
                        middleSlope.soil.permeability,
                        middleSlope.soil.currentMoisture,
                        middleSlope.soil.infiltrated,
                        middleSlope.soil.excess,
                        middleSlope.soil.currentMoisture);
                    perform lowerSlope.soil.absorbWater(
                        lowerSlope.vegetation.throughfall,
                        lowerSlope.soil.permeability,
                        lowerSlope.soil.currentMoisture,
                        lowerSlope.soil.infiltrated,
                        lowerSlope.soil.excess,
                        lowerSlope.soil.currentMoisture);
                }
                transition absorbing_to_saturating
                    first absorbing
                    when upperSlope.soil.currentMoisture >= upperSlope.soil.saturationThreshold
                    to saturating;
                transition absorbing_to_idle
                    first absorbing
                    when rainfallReceiver.intensity == 0.0
                    to draining;
            }

            state saturating {
                entry action beginRunoff {
                    perform upperSlope.generateRunoff(
                        upperSlope.soil.excess,
                        upperSlope.steepness,
                        upperSlope.vegetation.coverFraction,
                        upperSlope.runoffOut.runoff,
                        upperSlope.runoffOut.sediment,
                        upperSlope.runoffOut.sedimentLoad);
                }
                do action propagateSaturation {
                    perform middleSlope.generateRunoff(
                        middleSlope.soil.excess,
                        middleSlope.steepness,
                        middleSlope.vegetation.coverFraction,
                        middleSlope.runoffOut.runoff,
                        middleSlope.runoffOut.sediment,
                        middleSlope.runoffOut.sedimentLoad);
                    perform lowerSlope.generateRunoff(
                        lowerSlope.soil.excess,
                        lowerSlope.steepness,
                        lowerSlope.vegetation.coverFraction,
                        lowerSlope.runoffOut.runoff,
                        lowerSlope.runoffOut.sediment,
                        lowerSlope.runoffOut.sedimentLoad);
                }
                transition saturating_to_eroding
                    first saturating
                    when upperSlope.runoffOut.flowRate > 2.0
                    to eroding;
                transition saturating_to_draining
                    first saturating
                    when rainfallReceiver.intensity == 0.0
                    to draining;
            }

            state eroding {
                entry action recordErosion {
                    upperSlope.erosionPotential = upperSlope.runoffOut.flowRate * upperSlope.steepness * (1.0 - upperSlope.vegetation.coverFraction);
                    middleSlope.erosionPotential = middleSlope.runoffOut.flowRate * middleSlope.steepness * (1.0 - middleSlope.vegetation.coverFraction);
                    lowerSlope.erosionPotential = lowerSlope.runoffOut.flowRate * lowerSlope.steepness * (1.0 - lowerSlope.vegetation.coverFraction);
                    upperSlope.accumulatedSediment = upperSlope.accumulatedSediment + upperSlope.erosionPotential * 100.0;
                    middleSlope.accumulatedSediment = middleSlope.accumulatedSediment + middleSlope.erosionPotential * 100.0;
                    lowerSlope.accumulatedSediment = lowerSlope.accumulatedSediment + lowerSlope.erosionPotential * 100.0;
                }
                do action continueErosion {
                    perform upperSlope.routeFlow(
                        upperSlope.runoffOut.runoff,
                        upperSlope.runoffOut.sediment,
                        middleSlope.runoffIn.runoff,
                        middleSlope.runoffIn.sediment);
                    perform middleSlope.routeFlow(
                        middleSlope.runoffOut.runoff,
                        middleSlope.runoffOut.sediment,
                        lowerSlope.runoffIn.runoff,
                        lowerSlope.runoffIn.sediment);
                    perform lowerSlope.routeFlow(
                        lowerSlope.runoffOut.runoff,
                        lowerSlope.runoffOut.sediment,
                        drainage.inflow.runoff,
                        drainage.inflow.sediment);
                    perform drainage.collectRunoff(
                        drainage.inflow.runoff,
                        drainage.inflow.sediment,
                        drainage.outflow.water,
                        drainage.outflow.sediment,
                        drainage.outflow.discharge);
                }
                transition eroding_to_draining
                    first eroding
                    when rainfallReceiver.intensity == 0.0
                    to draining;
            }

            state draining {
                entry action beginDrainage {
                    perform drainage.collectRunoff(
                        drainage.inflow.runoff,
                        drainage.inflow.sediment,
                        drainage.outflow.water,
                        drainage.outflow.sediment,
                        drainage.outflow.discharge);
                }
                do action continueDraining {
                    drainage.totalDischarge = drainage.totalDischarge + drainage.outflow.discharge * 0.5;
                    drainage.totalSediment = drainage.totalSediment + drainage.outflow.sedimentLoad * 0.5;
                    upperSlope.soil.currentMoisture = upperSlope.soil.currentMoisture * 0.90;
                    middleSlope.soil.currentMoisture = middleSlope.soil.currentMoisture * 0.90;
                    lowerSlope.soil.currentMoisture = lowerSlope.soil.currentMoisture * 0.90;
                }
                transition draining_to_idle
                    first draining
                    when drainage.outflow.discharge < 0.1
                    to idle;
            }
        }

        exhibit WatershedBehavior as watershedState;
    }

    // ---- Requirements ----
    requirement def WatershedRequirement {
        subject hill : DonaldHill;
        doc /* The Donald Hill watershed shall model rainfall interception, infiltration, runoff, erosion, and drainage. */
    }

    requirement VegetationInterceptionRequirement :> WatershedRequirement {
        doc /* Vegetation canopy shall intercept a fraction of rainfall proportional to canopy density. */
        require hill.upperSlope.vegetation.canopyDensity > 0.0;
        require hill.upperSlope.vegetation.interceptedFraction <= hill.upperSlope.vegetation.canopyDensity;
    }

    requirement SoilInfiltrationRequirement :> WatershedRequirement {
        doc /* Soil shall absorb water up to saturation threshold; excess becomes surface runoff. */
        require hill.upperSlope.soil.permeability > 0.0;
        require hill.upperSlope.soil.saturationThreshold <= 1.0;
    }

    requirement RunoffRoutingRequirement :> WatershedRequirement {
        doc /* Runoff shall flow from upper slope to middle slope to lower slope and into the drainage network. */
        require hill.upperSlope.runoffOut connects to hill.middleSlope.runoffIn;
        require hill.middleSlope.runoffOut connects to hill.lowerSlope.runoffIn;
        require hill.lowerSlope.runoffOut connects to hill.drainage.inflow;
    }

    requirement ErosionControlRequirement :> WatershedRequirement {
        doc /* Erosion rate shall depend on flow volume, slope steepness, and vegetation cover. */
        require hill.upperSlope.erosionPotential == hill.upperSlope.runoffOut.flowRate * hill.upperSlope.steepness * (1.0 - hill.upperSlope.vegetation.coverFraction);
    }

    requirement StateTransitionRequirement :> WatershedRequirement {
        doc /* The watershed shall cycle through idle, absorbing, saturating, eroding, and draining states. */
        require hill.watershedState.ownedState includes {idle, absorbing, saturating, eroding, draining};
    }

    requirement DrainageRequirement :> WatershedRequirement {
        doc /* The drainage network shall collect all surface runoff and sediment from the lower slope. */
        require hill.drainage.channelCapacity > 0.0;
        require hill.drainage.outflow.discharge <= hill.drainage.channelCapacity;
    }

    // ---- Instance ----
    part donaldHillInstance : DonaldHill {
        // Override vegetation and soil parameters for each segment
        part upperSlope {
            part vegetation {
                canopyDensity = 0.55;
                coverFraction = 0.60;
            }
            part soil {
                thickness = 0.9;
                permeability = 12.0;
                currentMoisture = 0.18;
            }
        }
        part middleSlope {
            part vegetation {
                canopyDensity = 0.70;
                coverFraction = 0.75;
            }
            part soil {
                thickness = 1.3;
                permeability = 18.0;
                currentMoisture = 0.22;
            }
        }
        part lowerSlope {
            part vegetation {
                canopyDensity = 0.80;
                coverFraction = 0.85;
            }
            part soil {
                thickness = 1.6;
                permeability = 22.0;
                currentMoisture = 0.25;
            }
        }
        part drainage {
            channelLength = 850.0;
            channelCapacity = 12.0;
        }
    }
}
