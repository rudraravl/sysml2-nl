package TerrainabilitySystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def TerrainabilityIndex {
        attribute value : Real;
    }
    
    enum def TerrainCategory {
        smooth;
        moderate;
        rough;
        extreme;
    }
    
    item def TerrainProfile {
        attribute slope : ISQ::AngleValue;
        attribute roughness : ISQ::LengthValue;
        attribute cohesion : ISQ::PressureValue;
        attribute category : TerrainCategory;
    }
    
    item def MobilityCommand {
        attribute targetSpeed : ISQ::SpeedValue;
        attribute targetTorque : ISQ::TorqueValue;
        attribute suspensionHeight : ISQ::LengthValue;
    }
    
    item def VehicleStatus {
        attribute currentSpeed : ISQ::SpeedValue;
        attribute position : ISQ::LengthValue[3];
        attribute pitch : ISQ::AngleValue;
        attribute roll : ISQ::AngleValue;
    }
    
    port def TerrainSensorPort {
        out terrainData : TerrainProfile;
    }
    
    port def MobilityControlPort {
        in mobilityCmd : MobilityCommand;
    }
    
    port def StatusReportPort {
        out vehicleStatus : VehicleStatus;
    }
    
    port def PowerSupplyPort {
        in powerLevel : ISQ::PowerValue;
    }
    
    part def TerrainScannerUnit {
        attribute scanRange : ISQ::LengthValue;
        attribute scanResolution : ISQ::LengthValue;
        port sensorOut : TerrainSensorPort;
    }
    
    part def AdaptiveSuspension {
        attribute maxTravel : ISQ::LengthValue;
        attribute stiffnessRange : Real[2];
        port controlIn : MobilityControlPort;
    }
    
    part def DrivetrainModule {
        attribute maxTorque : ISQ::TorqueValue;
        attribute maxPower : ISQ::PowerValue;
        port commandIn : MobilityControlPort;
        port powerIn : PowerSupplyPort;
    }
    
    part def TerrainabilityProcessor {
        port terrainIn : TerrainSensorPort;
        port statusIn : StatusReportPort;
        port commandOut : MobilityControlPort;
    }
    
    action def AnalyzeTerrain {
        in terrainInput : TerrainProfile;
        out terrainabilityScore : Real;
        out traversable : Boolean;
        
        first start;
        then action computeScore {
            private attribute slopeWeight : Real := 0.4;
            private attribute roughnessWeight : Real := 0.35;
            private attribute cohesionWeight : Real := 0.25;
            private attribute normalizedSlope : Real;
            private attribute normalizedRoughness : Real;
            private attribute normalizedCohesion : Real;
            
            then assign normalizedSlope := 1.0 - (terrainInput.slope / 45.0);
            then assign normalizedRoughness := 1.0 - (terrainInput.roughness / 0.5);
            then assign normalizedCohesion := terrainInput.cohesion / 100000.0;
            then assign terrainabilityScore := (normalizedSlope * slopeWeight) + 
                                                (normalizedRoughness * roughnessWeight) + 
                                                (normalizedCohesion * cohesionWeight);
        }
        then decide;
            if terrainabilityScore >= 0.6 then markTraversable;
            if terrainabilityScore < 0.6 then markNonTraversable;
        
        action markTraversable {
            then assign traversable := true;
        }
        then done;
        
        action markNonTraversable {
            then assign traversable := false;
        }
        then done;
    }
    
    action def GenerateMobilityCommand {
        in terrain : TerrainProfile;
        in currentStatus : VehicleStatus;
        in terrainabilityScore : Real;
        out command : MobilityCommand;
        
        first start;
        then decide;
            if terrain.category == TerrainCategory::smooth then smoothConfig;
            if terrain.category == TerrainCategory::moderate then moderateConfig;
            if terrain.category == TerrainCategory::rough then roughConfig;
            if terrain.category == TerrainCategory::extreme then extremeConfig;
        
        action smoothConfig {
            then assign command.targetSpeed := 5.0;
            then assign command.targetTorque := 200.0;
            then assign command.suspensionHeight := 0.3;
        }
        then done;
        
        action moderateConfig {
            then assign command.targetSpeed := 3.0;
            then assign command.targetTorque := 350.0;
            then assign command.suspensionHeight := 0.4;
        }
        then done;
        
        action roughConfig {
            then assign command.targetSpeed := 1.5;
            then assign command.targetTorque := 500.0;
            then assign command.suspensionHeight := 0.5;
        }
        then done;
        
        action extremeConfig {
            then assign command.targetSpeed := 0.5;
            then assign command.targetTorque := 700.0;
            then assign command.suspensionHeight := 0.6;
        }
        then done;
    }
    
    action def AdaptToTerrain {
        in terrainSequence : TerrainProfile[*] ordered;
        in vehicleState : VehicleStatus;
        out commandSequence : MobilityCommand[*] ordered;
        
        private attribute commands : MobilityCommand[0..*] := ();
        
        for terrainSegment in terrainSequence {
            perform action analyze : AnalyzeTerrain {
                in terrainInput = terrainSegment;
                out terrainabilityScore;
                out traversable;
            }
            then decide;
                if analyze.traversable then generateCommand;
                if not analyze.traversable then emergencyStop;
            
            action generateCommand {
                perform action generate : GenerateMobilityCommand {
                    in terrain = terrainSegment;
                    in currentStatus = vehicleState;
                    in terrainabilityScore = analyze.terrainabilityScore;
                    out command;
                }
                then assign commands := commands :> MobilityCommand[*];
            }
            
            action emergencyStop {
                private attribute stopCommand : MobilityCommand;
                then assign commands := commands :> MobilityCommand[*];
            }
        }
        then assign commandSequence := commands;
    }
    
    attribute def SystemReadySignal;
    attribute def ContinuousMonitorSignal;
    attribute def ResetSystemSignal;
    
    state def TerrainabilityOperationalStates {
        entry; then initializing;
        
        state initializing {
            entry assign operationalMode := "initializing";
        }
        
        transition init_to_scanning
            first initializing
            accept sysReady : SystemReadySignal
            then scanning;
        
        state scanning {
            entry assign operationalMode := "scanning";
        }
        
        transition scanning_to_evaluating
            first scanning
            then evaluating;
        
        state evaluating {
            entry assign operationalMode := "evaluating";
        }
        
        transition evaluating_to_adapting
            first evaluating
            then adapting;
        
        transition evaluating_to_halted
            first evaluating
            then halted;
        
        state adapting {
            entry assign operationalMode := "adapting";
        }
        
        transition adapting_to_traversing
            first adapting
            then traversing;
        
        state traversing {
            entry assign operationalMode := "traversing";
        }
        
        transition traversing_to_scanning
            first traversing
            accept contMonitor : ContinuousMonitorSignal
            then scanning;
        
        state halted {
            entry assign operationalMode := "halted";
        }
        
        transition halted_to_initializing
            first halted
            accept resetSys : ResetSystemSignal
            then initializing;
        
        attribute operationalMode : String;
    }
    
    part def TerrainabilityVehicle {
        doc /* An autonomous ground vehicle system designed to assess and adapt to varying terrain conditions 
                to maintain optimal mobility and mission effectiveness across diverse operational environments. */
        
        attribute maxTerrainabilityIndex : Real := 1.0;
        attribute minOperationalIndex : Real := 0.6;
        
        part scanner : TerrainScannerUnit[4] {
            attribute scanRange := 20.0;
            attribute scanResolution := 0.1;
        }
        
        part suspension : AdaptiveSuspension[6] {
            attribute maxTravel := 0.5;
            attribute stiffnessRange := (10000.0, 100000.0);
        }
        
        part drivetrain : DrivetrainModule {
            attribute maxTorque := 800.0;
            attribute maxPower := 200.0;
        }
        
        part processor : TerrainabilityProcessor;
        
        connection scannerToProcessor
            connect scanner.sensorOut to processor.terrainIn;
        
        connection processorToSuspension
            connect processor.commandOut to suspension.controlIn;
        
        connection processorToDrivetrain
            connect processor.commandOut to drivetrain.commandIn;
        
        perform action terrainAdaptation : AdaptToTerrain[*] ordered;
        
        exhibit state operationalBehavior : TerrainabilityOperationalStates;
    }
    
    requirement def PrimaryMissionRequirement {
        doc /* The terrainability system shall autonomously assess terrain characteristics and 
                dynamically adapt vehicle configuration to maintain safe and efficient mobility. */
    }
    
    requirement def TerrainabilityPerformanceRequirement {
        doc /* The system shall maintain a terrainability index above the minimum operational 
                threshold across all traversable terrain categories. */
        
        require constraint minIndexConstraint {
            minOperationalIndex >= 0.6
        }
        
        require constraint maxSlopeCapability {
            maxTraversableSlope >= 35.0
        }
        
        require constraint maxRoughnessCapability {
            maxTraversableRoughness >= 0.4
        }
        
        attribute minOperationalIndex : Real;
        attribute maxTraversableSlope : ISQ::AngleValue;
        attribute maxTraversableRoughness : ISQ::LengthValue;
    }
    
    requirement def AdaptationResponseRequirement {
        doc /* The system shall detect terrain changes and complete configuration adaptation 
                within specified time limits to ensure continuous safe operation. */
        
        require constraint detectionLatency {
            terrainDetectionTime <= 200.0
        }
        
        require constraint adaptationLatency {
            configurationAdaptationTime <= 500.0
        }
        
        attribute terrainDetectionTime : ISQ::TimeValue;
        attribute configurationAdaptationTime : ISQ::TimeValue;
    }
    
    requirement <'TERR-001'> primaryMission : PrimaryMissionRequirement {
        subject vehicle : TerrainabilityVehicle;
        
        assume constraint operationalEnvironment {
            doc /* System operates in outdoor environments with variable terrain including 
                    slopes up to 35 degrees, surface roughness up to 0.4 meters, and varying soil cohesion. */
        }
    }
    
    requirement <'TERR-002'> performanceRequirement : TerrainabilityPerformanceRequirement {
        attribute minOperationalIndex := 0.6;
        attribute maxTraversableSlope := 35.0;
        attribute maxTraversableRoughness := 0.4;
    }
    
    requirement <'TERR-003'> responseRequirement : AdaptationResponseRequirement {
        attribute terrainDetectionTime := 200.0;
        attribute configurationAdaptationTime := 500.0;
    }
    
    part terrainabilitySystem : TerrainabilityVehicle {
        satisfy primaryMission;
        satisfy performanceRequirement;
        satisfy responseRequirement;
    }
    
    action demonstrateTerrainabilityOperation {
        doc /* Demonstrates the complete terrainability system operation cycle across 
                multiple terrain types with adaptive configuration changes. */
        
        first start;
        then action initialize {
            private attribute initialVehicleState : VehicleStatus {
                attribute currentSpeed := 0.0;
                attribute position := (0.0, 0.0, 0.0);
                attribute pitch := 0.0;
                attribute roll := 0.0;
            }
        }
        then action defineTerrainSequence {
            private attribute terrainPath : TerrainProfile[3] ordered;
            private attribute terrain1 : TerrainProfile {
                attribute slope := 5.0;
                attribute roughness := 0.05;
                attribute cohesion := 80000.0;
                attribute category := TerrainCategory::smooth;
            }
            private attribute terrain2 : TerrainProfile {
                attribute slope := 15.0;
                attribute roughness := 0.15;
                attribute cohesion := 60000.0;
                attribute category := TerrainCategory::moderate;
            }
            private attribute terrain3 : TerrainProfile {
                attribute slope := 25.0;
                attribute roughness := 0.3;
                attribute cohesion := 40000.0;
                attribute category := TerrainCategory::rough;
            }
        }
        then done;
    }
}
