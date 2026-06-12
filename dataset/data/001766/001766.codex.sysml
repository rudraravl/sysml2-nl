package DonaldHillSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Meter :> length;
    attribute def SquareMeter :> area;
    attribute def CubicMeter :> volume;
    attribute def Kilogram :> mass;
    attribute def Second :> time;
    attribute def DegreeCelsius;
    attribute def Millimeter;
    attribute def Percent;
    attribute def Lux;
    attribute def Newton;
    attribute def Watt;
    attribute def LiterPerSecond;
    attribute def MillimeterPerHour;

    item def RainWater {
        attribute flowRate : LiterPerSecond;
        attribute temperature : DegreeCelsius;
        attribute turbidity : Percent;
    }

    item def SurfaceRunoff {
        attribute flowRate : LiterPerSecond;
        attribute sedimentLoad : Kilogram;
    }

    item def TrailUser {
        attribute count : Integer;
        attribute averageMass : Kilogram;
    }

    item def MaintenanceCrew {
        attribute crewSize : Integer;
        attribute equipmentMass : Kilogram;
    }

    item def WeatherData {
        attribute airTemperature : DegreeCelsius;
        attribute rainfallIntensity : MillimeterPerHour;
        attribute windSpeed : Meter / Second;
        attribute daylight : Lux;
    }

    item def HillConditionReport {
        attribute slopeStabilityIndex : Percent;
        attribute erosionRiskIndex : Percent;
        attribute trailAvailability : Percent;
        attribute waterRetentionVolume : CubicMeter;
    }

    value def HillElevation {
        attribute value : Meter;
    }

    value def SlopeAngle {
        attribute value : Real;
        attribute unit : String = "degree";
    }

    value def SoilMoisture {
        attribute value : Percent;
    }

    value def VegetationCoverage {
        attribute value : Percent;
    }

    port def WaterInletPort {
        in rain : RainWater;
    }

    port def RunoffOutletPort {
        out runoff : SurfaceRunoff;
    }

    port def VisitorAccessPort {
        in visitors : TrailUser;
        out accessStatus : HillConditionReport;
    }

    port def WeatherObservationPort {
        in weather : WeatherData;
    }

    port def MaintenancePort {
        in crew : MaintenanceCrew;
        out conditionReport : HillConditionReport;
    }

    part def DonaldHill {
        attribute name : String = "Donald Hill";
        attribute primaryFunction : String =
            "Provide a stable elevated natural landform that supports safe recreation, controlled drainage, habitat preservation, and environmental monitoring.";

        attribute summitElevation : Meter = 284.0;
        attribute baseElevation : Meter = 132.0;
        attribute prominence : Meter = 152.0;
        attribute landArea : SquareMeter = 186000.0;
        attribute averageSlope : Real = 18.5;
        attribute maximumSlope : Real = 34.0;
        attribute vegetationCover : Percent = 78.0;
        attribute soilMoisture : Percent = 42.0;
        attribute designVisitorCapacity : Integer = 320;
        attribute maximumRunoffCapacity : LiterPerSecond = 2400.0;

        port rainInput : WaterInletPort;
        port runoffOutput : RunoffOutletPort;
        port visitorAccess : VisitorAccessPort;
        port weatherInput : WeatherObservationPort;
        port maintenanceInterface : MaintenancePort;

        part summit : Summit;
        part northSlope : ManagedSlope {
            attribute orientation : String = "north";
            attribute slopeAngle : Real = 22.0;
            attribute surfaceArea : SquareMeter = 48500.0;
        }

        part southSlope : ManagedSlope {
            attribute orientation : String = "south";
            attribute slopeAngle : Real = 27.5;
            attribute surfaceArea : SquareMeter = 52200.0;
        }

        part meadow : MeadowHabitat {
            attribute habitatArea : SquareMeter = 38700.0;
            attribute vegetationCoverage : Percent = 86.0;
        }

        part woodland : WoodlandHabitat {
            attribute habitatArea : SquareMeter = 72100.0;
            attribute canopyCoverage : Percent = 68.0;
        }

        part trailNetwork : TrailNetwork;
        part drainageSystem : DrainageSystem;
        part monitoringSystem : HillMonitoringSystem;
        part stabilizationSystem : SlopeStabilizationSystem;
        part maintenanceZone : MaintenanceZone;

        connect rainInput.rain to drainageSystem.rainReceiver.rain;
        connect drainageSystem.runoffDischarge.runoff to runoffOutput.runoff;
        connect visitorAccess.visitors to trailNetwork.entryPort.visitors;
        connect trailNetwork.trailStatus.accessStatus to visitorAccess.accessStatus;
        connect weatherInput.weather to monitoringSystem.weatherReceiver.weather;
        connect monitoringSystem.conditionOutput.conditionReport to maintenanceInterface.conditionReport;
        connect maintenanceInterface.crew to maintenanceZone.crewInput.crew;
        connect monitoringSystem.stabilityAlert.conditionReport to stabilizationSystem.conditionInput.conditionReport;
    }

    part def Summit {
        attribute elevation : Meter = 284.0;
        attribute observationArea : SquareMeter = 620.0;
        attribute guardrailLength : Meter = 148.0;
        attribute safeOccupancy : Integer = 54;

        port visitorPort : VisitorAccessPort;
    }

    part def ManagedSlope {
        attribute orientation : String;
        attribute slopeAngle : Real;
        attribute surfaceArea : SquareMeter;
        attribute soilDepth : Meter = 1.8;
        attribute vegetationCoverage : Percent = 74.0;
        attribute erosionRisk : Percent = 24.0;

        port runoffIn : WaterInletPort;
        port runoffOut : RunoffOutletPort;
    }

    part def MeadowHabitat {
        attribute habitatArea : SquareMeter;
        attribute vegetationCoverage : Percent;
        attribute pollinatorIndex : Percent = 71.0;
        attribute seasonalAccessRestricted : Boolean = false;
    }

    part def WoodlandHabitat {
        attribute habitatArea : SquareMeter;
        attribute canopyCoverage : Percent;
        attribute rootStabilizationContribution : Percent = 46.0;
        attribute protectedSpeciesPresence : Boolean = true;
    }

    part def TrailNetwork {
        attribute totalLength : Meter = 3840.0;
        attribute averageWidth : Meter = 1.6;
        attribute maximumGrade : Real = 14.0;
        attribute openTrailPercent : Percent = 100.0;
        attribute currentVisitorCount : Integer = 0;

        port entryPort : VisitorAccessPort;
        port trailStatus : VisitorAccessPort;

        part lowerLoop : TrailSegment {
            attribute segmentName : String = "Lower Loop";
            attribute length : Meter = 1420.0;
            attribute grade : Real = 6.5;
            attribute accessible : Boolean = true;
        }

        part ridgePath : TrailSegment {
            attribute segmentName : String = "Ridge Path";
            attribute length : Meter = 980.0;
            attribute grade : Real = 11.0;
            attribute accessible : Boolean = true;
        }

        part summitSpur : TrailSegment {
            attribute segmentName : String = "Summit Spur";
            attribute length : Meter = 640.0;
            attribute grade : Real = 14.0;
            attribute accessible : Boolean = true;
        }

        part serviceTrack : TrailSegment {
            attribute segmentName : String = "Service Track";
            attribute length : Meter = 800.0;
            attribute grade : Real = 9.0;
            attribute accessible : Boolean = false;
        }
    }

    part def TrailSegment {
        attribute segmentName : String;
        attribute length : Meter;
        attribute grade : Real;
        attribute accessible : Boolean;
        attribute surfaceCompaction : Percent = 58.0;
        attribute drainageCrossings : Integer = 3;
    }

    part def DrainageSystem {
        attribute storageCapacity : CubicMeter = 1260.0;
        attribute currentStoredWater : CubicMeter = 280.0;
        attribute culvertCapacity : LiterPerSecond = 2400.0;
        attribute sedimentTrapCapacity : Kilogram = 940.0;

        port rainReceiver : WaterInletPort;
        port runoffDischarge : RunoffOutletPort;

        part swales : SwaleArray;
        part culverts : CulvertNetwork;
        part retentionBasin : RetentionBasin;
        part sedimentTrap : SedimentTrap;
    }

    part def SwaleArray {
        attribute swaleCount : Integer = 18;
        attribute totalLength : Meter = 1260.0;
        attribute designFlow : LiterPerSecond = 1100.0;
    }

    part def CulvertNetwork {
        attribute culvertCount : Integer = 7;
        attribute totalCapacity : LiterPerSecond = 2400.0;
        attribute inspectionIntervalDays : Integer = 30;
    }

    part def RetentionBasin {
        attribute basinVolume : CubicMeter = 1260.0;
        attribute normalWaterVolume : CubicMeter = 280.0;
        attribute overflowThreshold : CubicMeter = 1130.0;
    }

    part def SedimentTrap {
        attribute retainedSediment : Kilogram = 210.0;
        attribute cleanoutThreshold : Kilogram = 750.0;
    }

    part def HillMonitoringSystem {
        attribute sampleInterval : Second = 300.0;
        attribute batteryPower : Watt = 95.0;
        attribute communicationAvailable : Boolean = true;

        port weatherReceiver : WeatherObservationPort;
        port conditionOutput : MaintenancePort;
        port stabilityAlert : MaintenancePort;

        part weatherStation : WeatherStation;
        part soilSensors : SoilSensorArray;
        part trailCounters : VisitorCounterArray;
        part stabilitySensors : StabilitySensorArray;
        part controller : MonitoringController;
    }

    part def WeatherStation {
        attribute measuredRainfall : MillimeterPerHour = 0.0;
        attribute measuredTemperature : DegreeCelsius = 18.0;
        attribute measuredWindSpeed : Meter / Second = 3.0;
        attribute daylightLevel : Lux = 46000.0;
    }

    part def SoilSensorArray {
        attribute sensorCount : Integer = 24;
        attribute averageSoilMoisture : Percent = 42.0;
        attribute saturationAlarmThreshold : Percent = 82.0;
    }

    part def VisitorCounterArray {
        attribute counterCount : Integer = 5;
        attribute dailyVisitorCount : Integer = 0;
        attribute warningThreshold : Integer = 280;
    }

    part def StabilitySensorArray {
        attribute inclinometerCount : Integer = 10;
        attribute groundMotion : Millimeter = 0.4;
        attribute motionAlarmThreshold : Millimeter = 6.0;
    }

    part def MonitoringController {
        attribute stabilityIndex : Percent = 92.0;
        attribute erosionRiskIndex : Percent = 18.0;
        attribute trailAvailability : Percent = 100.0;
    }

    part def SlopeStabilizationSystem {
        attribute targetStabilityIndex : Percent = 90.0;
        attribute installedRetainingLength : Meter = 410.0;
        attribute rootMatCoverage : SquareMeter = 28400.0;

        port conditionInput : MaintenancePort;

        part retainingWalls : RetainingWallSet;
        part geotextileMats : GeotextileMatSystem;
        part revegetationZones : RevegetationZoneSet;
    }

    part def RetainingWallSet {
        attribute wallCount : Integer = 9;
        attribute totalLength : Meter = 410.0;
        attribute resistingForce : Newton = 680000.0;
    }

    part def GeotextileMatSystem {
        attribute coveredArea : SquareMeter = 28400.0;
        attribute tensileStrength : Newton = 52000.0;
    }

    part def RevegetationZoneSet {
        attribute zoneCount : Integer = 16;
        attribute plantedArea : SquareMeter = 31600.0;
        attribute establishmentProgress : Percent = 83.0;
    }

    part def MaintenanceZone {
        attribute equipmentStorageArea : SquareMeter = 220.0;
        attribute scheduledInspectionIntervalDays : Integer = 14;
        attribute emergencyResponseTime : Second = 1800.0;

        port crewInput : MaintenancePort;
    }

    action def AbsorbRainfall {
        in rain : RainWater;
        in vegetationCover : Percent;
        out retainedVolume : CubicMeter;
    }

    action def RouteRunoff {
        in rain : RainWater;
        in storedWater : CubicMeter;
        out runoff : SurfaceRunoff;
    }

    action def EvaluateHillCondition {
        in weather : WeatherData;
        in soilMoisture : SoilMoisture;
        in visitorLoad : TrailUser;
        out report : HillConditionReport;
    }

    action def ManageVisitorAccess {
        in visitors : TrailUser;
        in report : HillConditionReport;
        out permitted : Boolean;
    }

    action def StabilizeSlope {
        in report : HillConditionReport;
        out updatedStabilityIndex : Percent;
    }

    action def PrimaryHillFunction {
        in weather : WeatherData;
        in visitors : TrailUser;
        out conditionReport : HillConditionReport;

        action absorb : AbsorbRainfall;
        action route : RouteRunoff;
        action evaluate : EvaluateHillCondition;
        action access : ManageVisitorAccess;
        action stabilize : StabilizeSlope;

        flow weather to evaluate.weather;
        flow visitors to evaluate.visitorLoad;
        flow evaluate.report to access.report;
        flow evaluate.report to stabilize.report;
        flow evaluate.report to conditionReport;
    }

    state def HillOperationalState {
        entry action EvaluateHillCondition;

        state NormalOperation {
            entry action ManageVisitorAccess;
        }

        state RainEvent {
            entry action AbsorbRainfall;
            do action RouteRunoff;
        }

        state RestrictedAccess {
            entry action ManageVisitorAccess;
        }

        state StabilizationRequired {
            entry action StabilizeSlope;
        }

        state MaintenanceMode;

        transition first NormalOperation;

        transition NormalOperation_to_RainEvent
            first NormalOperation
            then RainEvent
            if rainfallIntensity > 8.0;

        transition RainEvent_to_NormalOperation
            first RainEvent
            then NormalOperation
            if rainfallIntensity <= 2.0 and erosionRiskIndex < 45.0;

        transition NormalOperation_to_RestrictedAccess
            first NormalOperation
            then RestrictedAccess
            if dailyVisitorCount > 320 or trailAvailability < 75.0;

        transition RestrictedAccess_to_NormalOperation
            first RestrictedAccess
            then NormalOperation
            if dailyVisitorCount < 240 and trailAvailability >= 90.0;

        transition RainEvent_to_StabilizationRequired
            first RainEvent
            then StabilizationRequired
            if slopeStabilityIndex < 80.0 or groundMotion > 6.0;

        transition StabilizationRequired_to_MaintenanceMode
            first StabilizationRequired
            then MaintenanceMode;

        transition MaintenanceMode_to_NormalOperation
            first MaintenanceMode
            then NormalOperation
            if slopeStabilityIndex >= 90.0 and trailAvailability >= 95.0;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /*
         Donald Hill shall function as a stable managed hill system that supports safe public passage, controlled stormwater runoff, habitat preservation, and continuous condition monitoring.
        */

        subject hill : DonaldHill;

        require constraint {
            hill.prominence >= 100.0 and
            hill.vegetationCover >= 70.0 and
            hill.designVisitorCapacity >= 300
        }
    }

    requirement def DrainageRequirement {
        doc
        /*
         Donald Hill shall route rainfall and surface runoff without exceeding the drainage system discharge capacity during normal storm events.
        */

        subject hill : DonaldHill;

        require constraint {
            hill.maximumRunoffCapacity >= 2400.0
        }
    }

    requirement def RecreationSafetyRequirement {
        doc
        /*
         Donald Hill shall provide managed visitor access while restricting trail use when slope stability, rainfall, or visitor loading creates unacceptable risk.
        */

        subject trails : TrailNetwork;

        require constraint {
            trails.maximumGrade <= 15.0 and
            trails.openTrailPercent >= 75.0
        }
    }

    requirement def HabitatProtectionRequirement {
        doc
        /*
         Donald Hill shall preserve meadow and woodland habitats by maintaining vegetation coverage sufficient to reduce erosion and sustain ecological function.
        */

        subject hill : DonaldHill;

        require constraint {
            hill.meadow.vegetationCoverage >= 80.0 and
            hill.woodland.canopyCoverage >= 60.0
        }
    }

    requirement def MonitoringRequirement {
        doc
        /*
         Donald Hill shall monitor weather, soil moisture, visitor loading, and ground movement at intervals sufficient to support operational decisions.
        */

        subject monitoring : HillMonitoringSystem;

        require constraint {
            monitoring.sampleInterval <= 300.0 and
            monitoring.communicationAvailable == true
        }
    }

    requirement def StabilizationRequirement {
        doc
        /*
         Donald Hill shall maintain a slope stability index of at least 90 percent after stabilization and scheduled maintenance actions.
        */

        subject stabilization : SlopeStabilizationSystem;

        require constraint {
            stabilization.targetStabilityIndex >= 90.0
        }
    }

    satisfy PrimaryFunctionRequirement by DonaldHill;
    satisfy DrainageRequirement by DonaldHill.drainageSystem;
    satisfy RecreationSafetyRequirement by DonaldHill.trailNetwork;
    satisfy HabitatProtectionRequirement by DonaldHill;
    satisfy MonitoringRequirement by DonaldHill.monitoringSystem;
    satisfy StabilizationRequirement by DonaldHill.stabilizationSystem;

    part donaldHillSystem : DonaldHill;

}