package 'Intelligent Support Surface System' {
    private import ISQ::MassValue;
    private import ISQ::LengthValue;
    private import ISQ::PressureValue;
    private import ISQ::ForceValue;
    private import ISQ::TemperatureValue;
    private import SI::kg;
    private import SI::m;
    private import SI::mm;
    private import SI::Pa;
    private import SI::MPa;
    private import ScalarValues::String;
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ScalarValues::Integer;

    requirement MaxLoadCapacityRequirement {
        subject surface : IntelligentSupportSurface;
        doc /* The platform shall support a maximum load of 1000 kg. */
        constraint { surface.maxLoad == 1000 [kg] }
    }
    requirement SafeWorkingLoadRequirement {
        subject surface : IntelligentSupportSurface;
        doc /* The recommended safe working load shall be 750 kg. */
        constraint { surface.safeWorkingLoad == 750 [kg] }
    }
    requirement DimensionRequirement {
        subject surface : IntelligentSupportSurface;
        doc /* The platform dimensions shall be 3 m by 2 m. */
        constraint { surface.platformLength == 3 [m] }
        constraint { surface.platformWidth == 2 [m] }
    }
    requirement StructuralIntegrityRequirement {
        subject surface : IntelligentSupportSurface;
        doc /* The system shall continuously monitor deflection and stress to ensure structural integrity. */
    }
    requirement EnvironmentalSensingRequirement {
        subject surface : IntelligentSupportSurface;
        doc /* The system shall sense ambient temperature and humidity. */
    }

    item def LoadApplied {
        attribute mass : MassValue;
        attribute pressureDistribution : PressureValue;
    }
    item def LoadRemoved;
    item def OverloadRejected;
    item def StructuralHealthReport {
        attribute deflection : LengthValue;
        attribute stress : PressureValue;
        attribute integrity : Boolean;
    }
    item def EnvironmentalData {
        attribute temperature : TemperatureValue;
        attribute humidity : Real;
    }

    part def StructuralCore {
        attribute maxDeflection : LengthValue := 5 [mm];
        attribute maxStress : PressureValue := 250 [MPa];
        attribute materialGrade : String;
    }
    part def LoadBearingLayer {
        attribute wearResistance : Real;
        attribute thickness : LengthValue := 10 [mm];
    }
    part def EdgeSupport {
        attribute lateralLoadCapacity : ForceValue;
        attribute reinforcementFactor : Real;
    }
    part def AnchorageSystem {
        attribute anchorCount : Integer;
        attribute anchorCapacity : ForceValue;
    }

    port def LoadBearingPort {
        in loadApplied : LoadApplied;
        in loadRemoved : LoadRemoved;
        out rejected : OverloadRejected;
    }
    port def StructuralMonitoringPort {
        out healthReport : StructuralHealthReport;
    }
    port def EnvironmentalPort {
        out environmentData : EnvironmentalData;
    }

    action monitorStructure {
        out deflection : LengthValue;
        out stress : PressureValue;
        out integrity : Boolean;
    }
    action senseEnvironment {
        out temperature : TemperatureValue;
        out humidity : Real;
    }

    part def IntelligentSupportSurface {
        attribute platformLength : LengthValue := 3 [m];
        attribute platformWidth : LengthValue := 2 [m];
        attribute maxLoad : MassValue := 1000 [kg];
        attribute safeWorkingLoad : MassValue := 750 [kg];
        attribute currentLoadMass : MassValue;

        part structuralCore : StructuralCore;
        part loadBearingLayer : LoadBearingLayer;
        part edgeSupports : EdgeSupport[*];
        part anchorageSystem : AnchorageSystem;

        port loadBearingInterface : LoadBearingPort;
        port structuralMonitoringInterface : StructuralMonitoringPort;
        port environmentalInterface : EnvironmentalPort;

        state platformStates {
            entry; then unloaded;
            do monitorStructure;
            state unloaded;
            accept loadApplied : LoadApplied via loadBearingInterface
                do assign currentLoadMass := loadApplied.mass
                then evaluating;
            state evaluating;
            accept when currentLoadMass <= safeWorkingLoad
                then loaded;
            accept when currentLoadMass > safeWorkingLoad
                do send new OverloadRejected() via loadBearingInterface
                then unloaded;
            state loaded;
            accept loadRemoved : LoadRemoved via loadBearingInterface
                then unloaded;
            accept when monitorStructure.deflection > structuralCore.maxDeflection
                do send new StructuralHealthReport(monitorStructure.deflection, monitorStructure.stress, false) via structuralMonitoringInterface
                then unloaded;
            accept when monitorStructure.stress > structuralCore.maxStress
                do send new StructuralHealthReport(monitorStructure.deflection, monitorStructure.stress, false) via structuralMonitoringInterface
                then unloaded;
        }
    }
}
