package RoadSurfaceSystemModel {
    import ScalarValues::*;
    import SI::*;

    attribute def Length :> Real;
    attribute def Area :> Real;
    attribute def Pressure :> Real;
    attribute def Temperature :> Real;
    attribute def Speed :> Real;
    attribute def Coefficient :> Real;
    attribute def FlowRate :> Real;
    attribute def Force :> Real;
    attribute def Mass :> Real;
    attribute def Time :> Real;

    item def VehicleLoad {
        attribute axleForce : Force;
        attribute contactPatchArea : Area;
        attribute tirePressure : Pressure;
        attribute travelSpeed : Speed;
    }

    item def SurfaceWater {
        attribute depth : Length;
        attribute flowRate : FlowRate;
        attribute temperature : Temperature;
    }

    item def TractionDemand {
        attribute requiredFriction : Coefficient;
        attribute brakingForce : Force;
        attribute lateralForce : Force;
    }

    item def DrainageFlow {
        attribute runoffRate : FlowRate;
        attribute destination : String;
    }

    item def MaintenanceCondition {
        attribute rutDepth : Length;
        attribute crackDensity : Real;
        attribute skidResistance : Coefficient;
        attribute roughnessIndex : Real;
    }

    port def LoadBearingPort {
        in item load : VehicleLoad;
    }

    port def TractionPort {
        in item demand : TractionDemand;
        out attribute availableFriction : Coefficient;
    }

    port def DrainagePort {
        in item water : SurfaceWater;
        out item runoff : DrainageFlow;
    }

    port def InspectionPort {
        out item condition : MaintenanceCondition;
    }

    part def RoadSurface {
        attribute length : Length = 1000.0;
        attribute width : Length = 12.0;
        attribute laneCount : Integer = 2;
        attribute designLife : Time = 20.0;
        attribute postedSpeed : Speed = 27.78;
        attribute nominalCrossSlope : Coefficient = 0.02;
        attribute currentFriction : Coefficient = 0.74;
        attribute currentRoughnessIndex : Real = 1.2;
        attribute maximumRutDepth : Length = 0.010;
        attribute surfaceTemperature : Temperature = 293.15;

        port loadPort : LoadBearingPort;
        port tractionPort : TractionPort;
        port drainagePort : DrainagePort;
        port inspectionPort : InspectionPort;

        part wearingCourse : WearingCourse;
        part baseLayer : BaseLayer;
        part subgradeInterface : SubgradeInterface;
        part textureSystem : SurfaceTexture;
        part crownAndSlope : DrainageGeometry;
        part shoulderInterface : ShoulderInterface;

        connection loadTransfer connect loadPort to wearingCourse.loadPort;
        connection wearingToBase connect wearingCourse.supportPort to baseLayer.loadPort;
        connection baseToSubgrade connect baseLayer.supportPort to subgradeInterface.loadPort;
        connection tractionExposure connect tractionPort to textureSystem.tractionPort;
        connection waterRouting connect drainagePort to crownAndSlope.drainagePort;
        connection edgeDischarge connect crownAndSlope.outletPort to shoulderInterface.drainagePort;
        connection inspectionAggregation connect inspectionPort to wearingCourse.inspectionPort;

        action performPrimaryFunction {
            in item vehicleLoad : VehicleLoad;
            in item tractionDemand : TractionDemand;
            in item precipitation : SurfaceWater;
            out item condition : MaintenanceCondition;

            action distributeTrafficLoad {
                in item appliedLoad : VehicleLoad;
                out attribute compressiveStress : Pressure;
            }

            action provideVehicleTraction {
                in item demand : TractionDemand;
                out attribute frictionMargin : Coefficient;
            }

            action shedSurfaceWater {
                in item water : SurfaceWater;
                out item drainage : DrainageFlow;
            }

            action reportServiceability {
                out item serviceCondition : MaintenanceCondition;
            }

            flow vehicleLoad to distributeTrafficLoad.appliedLoad;
            flow tractionDemand to provideVehicleTraction.demand;
            flow precipitation to shedSurfaceWater.water;
            flow reportServiceability.serviceCondition to condition;

            succession distributeTrafficLoad then provideVehicleTraction;
            succession provideVehicleTraction then shedSurfaceWater;
            succession shedSurfaceWater then reportServiceability;
        }

        state def SurfaceOperationalState {
            state serviceable;
            state wet;
            state degraded;
            state restricted;
            state underRepair;

            entry action initializeCondition {
                out attribute friction : Coefficient = 0.74;
                out attribute rutDepth : Length = 0.002;
            }

            transition dryToWet first serviceable then wet
                accept SurfaceWater
                if drainagePort.water.depth > 0.001;

            transition wetToServiceable first wet then serviceable
                if drainagePort.water.depth <= 0.001 and currentFriction >= 0.55;

            transition serviceableToDegraded first serviceable then degraded
                if currentRoughnessIndex > 2.7 or maximumRutDepth > 0.012;

            transition degradedToRestricted first degraded then restricted
                if currentFriction < 0.45 or maximumRutDepth > 0.020;

            transition restrictedToRepair first restricted then underRepair
                accept MaintenanceCondition;

            transition repairToServiceable first underRepair then serviceable
                if currentFriction >= 0.65 and maximumRutDepth <= 0.006 and currentRoughnessIndex <= 1.8;
        }
    }

    part def WearingCourse {
        attribute thickness : Length = 0.050;
        attribute binderContent : Real = 5.4;
        attribute aggregateNominalSize : Length = 0.0125;
        attribute permeability : Coefficient = 0.000001;
        attribute skidResistance : Coefficient = 0.74;
        attribute rutDepth : Length = 0.002;
        attribute crackDensity : Real = 0.05;

        port loadPort : LoadBearingPort;
        port supportPort : LoadBearingPort;
        port inspectionPort : InspectionPort;

        action spreadContactStress {
            in item wheelLoad : VehicleLoad;
            out item reducedLoad : VehicleLoad;
        }
    }

    part def BaseLayer {
        attribute thickness : Length = 0.200;
        attribute modulus : Pressure = 350000000.0;
        attribute compaction : Coefficient = 0.98;

        port loadPort : LoadBearingPort;
        port supportPort : LoadBearingPort;

        action attenuateLoad {
            in item surfaceLoad : VehicleLoad;
            out item foundationLoad : VehicleLoad;
        }
    }

    part def SubgradeInterface {
        attribute bearingCapacity : Pressure = 150000000.0;
        attribute moistureSensitivity : Coefficient = 0.35;

        port loadPort : LoadBearingPort;
    }

    part def SurfaceTexture {
        attribute macroTextureDepth : Length = 0.0012;
        attribute microTextureIndex : Real = 0.82;
        attribute minimumWetFriction : Coefficient = 0.55;

        port tractionPort : TractionPort;

        action computeAvailableFriction {
            in item demand : TractionDemand;
            out attribute availableFriction : Coefficient;
        }
    }

    part def DrainageGeometry {
        attribute crossSlope : Coefficient = 0.02;
        attribute longitudinalGrade : Coefficient = 0.015;
        attribute inletSpacing : Length = 45.0;
        attribute maximumAllowableWaterDepth : Length = 0.003;

        port drainagePort : DrainagePort;
        port outletPort : DrainagePort;

        action routeRunoff {
            in item rainfallFilm : SurfaceWater;
            out item shoulderRunoff : DrainageFlow;
        }
    }

    part def ShoulderInterface {
        attribute edgeDropOff : Length = 0.000;
        attribute shoulderSlope : Coefficient = 0.04;

        port drainagePort : DrainagePort;
    }

    requirement def PrimaryRoadSurfaceFunction {
        doc /* The road surface shall provide a stable, durable, and traversable interface between vehicles and the ground by bearing traffic loads, supplying tire traction, maintaining ride quality, and shedding water. */

        subject surface : RoadSurface;

        require constraint {
            surface.currentFriction >= 0.55 and
            surface.currentRoughnessIndex <= 2.7 and
            surface.maximumRutDepth <= 0.012
        }
    }

    requirement def LoadSupportRequirement {
        subject surface : RoadSurface;

        require constraint {
            surface.baseLayer.modulus >= 300000000.0 and
            surface.subgradeInterface.bearingCapacity >= 100000000.0
        }
    }

    requirement def DrainageRequirement {
        subject surface : RoadSurface;

        require constraint {
            surface.crownAndSlope.crossSlope >= 0.015 and
            surface.crownAndSlope.maximumAllowableWaterDepth <= 0.003
        }
    }

    requirement def TractionRequirement {
        subject surface : RoadSurface;

        require constraint {
            surface.textureSystem.minimumWetFriction >= 0.55 and
            surface.currentFriction >= surface.textureSystem.minimumWetFriction
        }
    }

    requirement def MaintainabilityRequirement {
        subject surface : RoadSurface;

        require constraint {
            surface.wearingCourse.rutDepth <= 0.012 and
            surface.wearingCourse.crackDensity <= 0.20
        }
    }

    part roadSurfaceSystem : RoadSurface {
        attribute length = 2500.0;
        attribute width = 14.6;
        attribute laneCount = 2;
        attribute postedSpeed = 31.29;
        attribute currentFriction = 0.72;
        attribute currentRoughnessIndex = 1.4;
        attribute maximumRutDepth = 0.004;
    }

    satisfy roadSurfaceSystem satisfies PrimaryRoadSurfaceFunction;
    satisfy roadSurfaceSystem satisfies LoadSupportRequirement;
    satisfy roadSurfaceSystem satisfies DrainageRequirement;
    satisfy roadSurfaceSystem satisfies TractionRequirement;
    satisfy roadSurfaceSystem satisfies MaintainabilityRequirement;
}