package AutonomousAllTerrainVehicle {
    public import ISQ::*;
    public import ScalarValues::*;

    package Definitions {
        public import ItemDefinitions::*;
        public import PortDefinitions::*;
        public import PartDefinitions::*;
        public import ActionDefinitions::*;
        public import RequirementDefinitions::*;

        package ItemDefinitions {
            item def TerrainData {
                attribute slope :> ISQ::planeAngle;
                attribute roughness :> ISQ::length;
                attribute soilCohesion :> ISQ::pressure;
            }

            item def TerrainabilityIndex {
                attribute value : Real;
            }

            enum def TerrainCategory {
                smooth;
                moderate;
                rough;
                extreme;
                nonTraversable;
            }

            item def DrivetrainCommand {
                attribute torque :> ISQ::torque;
                attribute speed :> ISQ::speed;
            }

            item def SuspensionCommand {
                attribute height :> ISQ::length;
                attribute stiffness :> ISQ::forcePerLength;
            }
        }

        package PortDefinitions {
            port def TerrainDataOutPort {
                out terrainData : TerrainData;
            }
            port def TerrainDataInPort {
                in terrainData : TerrainData;
            }
            port def DrivetrainCmdInPort {
                in drivetrainCmd : DrivetrainCommand;
            }
            port def DrivetrainCmdOutPort {
                out drivetrainCmd : DrivetrainCommand;
            }
            port def SuspensionCmdInPort {
                in suspensionCmd : SuspensionCommand;
            }
            port def SuspensionCmdOutPort {
                out suspensionCmd : SuspensionCommand;
            }
        }

        package ActionDefinitions {
            action def ScanTerrain {
                out data : TerrainData;
            }

            action def EvaluateTerrain {
                in data : TerrainData;
                out category : TerrainCategory;
                out index : Real;
            }

            action def DetermineConfiguration {
                in category : TerrainCategory;
                out drivetrainCmd : DrivetrainCommand;
                out suspensionCmd : SuspensionCommand;
            }

            action def AdjustDrive {
                in cmd : DrivetrainCommand;
            }

            action def AdjustSuspension {
                in cmd : SuspensionCommand;
            }

            calc def ComputeTerrainabilityIndex {
                in slope : ISQ::planeAngle;
                in roughness : ISQ::length;
                in cohesion : ISQ::pressure;
                return index : Real;
            }
        }

        package PartDefinitions {
            part def TerrainScanner {
                port terrainDataOut : TerrainDataOutPort;
                perform action scanTerrain : ActionDefinitions::ScanTerrain {
                    out data : TerrainData;
                }
            }

            part def TerrainabilityProcessor {
                port terrainDataIn : TerrainDataInPort;
                port drivetrainCmdOut : DrivetrainCmdOutPort;
                port suspensionCmdOut : SuspensionCmdOutPort;

                attribute currentCategory : TerrainCategory;
                attribute terrainabilityIndex : Real;

                perform action evaluateTerrain : ActionDefinitions::EvaluateTerrain;
                perform action determineConfiguration : ActionDefinitions::DetermineConfiguration;

                constraint { terrainabilityIndex >= 0.0 and terrainabilityIndex <= 1.0 }
            }

            part def Drivetrain {
                port drivetrainCmdIn : DrivetrainCmdInPort;
                attribute currentTorque :> ISQ::torque;
                attribute currentSpeed :> ISQ::speed;
                perform action adjustDrive : ActionDefinitions::AdjustDrive;
            }

            part def AdaptiveSuspension {
                port suspensionCmdIn : SuspensionCmdInPort;
                attribute currentHeight :> ISQ::length;
                attribute currentStiffness :> ISQ::forcePerLength;
                perform action adjustSuspension : ActionDefinitions::AdjustSuspension;
            }

            part def AllTerrainVehicle {
                attribute mass :> ISQ::mass;
                attribute velocity :> ISQ::speed;

                part scanner1 : TerrainScanner;
                part scanner2 : TerrainScanner;
                part scanner3 : TerrainScanner;
                part scanner4 : TerrainScanner;
                part processor : TerrainabilityProcessor;
                part drivetrain : Drivetrain;
                part suspension : AdaptiveSuspension[6];

                connect scanner1.terrainDataOut to processor.terrainDataIn;
                connect scanner2.terrainDataOut to processor.terrainDataIn;
                connect scanner3.terrainDataOut to processor.terrainDataIn;
                connect scanner4.terrainDataOut to processor.terrainDataIn;
                connect processor.drivetrainCmdOut to drivetrain.drivetrainCmdIn;
                connect processor.suspensionCmdOut to suspension.suspensionCmdIn;

                exhibit state vehicleStates {
                    entry action initialize;
                    then initializing;
                    state initializing;
                    state scanning {
                        do scanner1.scanTerrain;
                        do scanner2.scanTerrain;
                        do scanner3.scanTerrain;
                        do scanner4.scanTerrain;
                    }
                    state evaluating {
                        do processor.evaluateTerrain;
                    }
                    state adapting {
                        do processor.determineConfiguration;
                        do drivetrain.adjustDrive;
                        do suspension.adjustSuspension;
                    }
                    state traversing;
                    state halted;

                    transition init_to_scan
                        first initializing
                        then scanning;
                    transition scan_to_eval
                        first scanning
                        then evaluating;
                    transition eval_to_adapt
                        first evaluating
                        if processor.currentCategory != TerrainCategory::nonTraversable
                        then adapting;
                    transition eval_to_halt
                        first evaluating
                        if processor.currentCategory == TerrainCategory::nonTraversable
                        then halted;
                    transition adapt_to_traverse
                        first adapting
                        then traversing;
                    transition traverse_to_scan
                        first traversing
                        then scanning;
                    transition halt_to_scan
                        first halted
                        then scanning;
                }
            }
        }

        package RequirementDefinitions {
            requirement def TerrainAnalysisRequirement {
                subject vehicle : AllTerrainVehicle;
                doc /* The vehicle shall analyze terrain slope, roughness, and soil cohesion using four forward-facing scanners. */
            }

            requirement def TerrainabilityIndexRequirement {
                subject processor : TerrainabilityProcessor;
                doc /* The processor shall calculate a terrainability index to determine traversability. */
            }

            requirement def AdaptiveConfigurationRequirement {
                subject vehicle : AllTerrainVehicle;
                doc /* The vehicle shall automatically adjust suspension height/stiffness and drivetrain torque/speed based on terrain category. */
            }

            requirement def RoughTerrainResponseRequirement {
                subject vehicle : AllTerrainVehicle;
                doc /* On rough terrain, suspension height shall increase, torque shall increase, and speed shall decrease. */
            }

            requirement def SmoothTerrainResponseRequirement {
                subject vehicle : AllTerrainVehicle;
                doc /* On smooth terrain, suspension height shall decrease and speed shall increase for efficiency. */
            }

            requirement def HaltOnNonTraversableRequirement {
                subject vehicle : AllTerrainVehicle;
                doc /* If terrain is deemed non-traversable, the vehicle shall enter a halted state. */
            }
        }
    }

    part vehicle : Definitions::PartDefinitions::AllTerrainVehicle;

    requirement terrainAnalysisReq : Definitions::RequirementDefinitions::TerrainAnalysisRequirement;
    requirement terrainabilityIndexReq : Definitions::RequirementDefinitions::TerrainabilityIndexRequirement;
    requirement adaptiveConfigReq : Definitions::RequirementDefinitions::AdaptiveConfigurationRequirement;
    requirement roughTerrainReq : Definitions::RequirementDefinitions::RoughTerrainResponseRequirement;
    requirement smoothTerrainReq : Definitions::RequirementDefinitions::SmoothTerrainResponseRequirement;
    requirement haltReq : Definitions::RequirementDefinitions::HaltOnNonTraversableRequirement;

    satisfy terrainAnalysisReq by vehicle;
    satisfy adaptiveConfigReq by vehicle;
    satisfy roughTerrainReq by vehicle;
    satisfy smoothTerrainReq by vehicle;
    satisfy haltReq by vehicle;
}
