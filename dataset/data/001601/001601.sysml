package TechnologyRoadmapDrivenSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    enum def TechnologyMaturityLevel {
        TRL1_BasicPrinciples;
        TRL2_ConceptFormulated;
        TRL3_ProofOfConcept;
        TRL4_LabValidation;
        TRL5_RelevantEnvironment;
        TRL6_PrototypeDemo;
        TRL7_OperationalDemo;
        TRL8_SystemComplete;
        TRL9_OperationalProven;
    }

    enum def RoadmapPhaseStatus {
        planned;
        inProgress;
        completed;
        delayed;
    }

    attribute def RoadmapPhase {
        attribute phaseName : String;
        attribute startYear : Integer;
        attribute endYear : Integer;
        attribute targetTRL : TechnologyMaturityLevel;
        attribute status : RoadmapPhaseStatus;
        attribute keyMilestones : String[1..*];
    }

    attribute def DataThroughput :> Real;

    attribute def ProcessingCapacity :> Real;

    item def SensorData {
        attribute timestamp : String;
        attribute dataQuality : Real;
        attribute dataVolume : Real;
    }

    item def ProcessedIntelligence {
        attribute analysisResult : String;
        attribute confidenceLevel : Real;
        attribute actionableInsights : String[0..*];
    }

    item def CommandSignal {
        attribute commandType : String;
        attribute priority : Integer;
    }

    port def SensorInputPort {
        in sensorDataIn : SensorData;
    }

    port def IntelligenceOutputPort {
        out intelligenceOut : ProcessedIntelligence;
    }

    port def CommandPort {
        in commandIn : CommandSignal;
        out statusOut : String;
    }

    port def PowerSupplyPort {
        in powerIn : PowerValue;
    }

    port def DataBusPort {
        inout dataFlow : SensorData;
    }

    part def AdvancedSensorModule {
        attribute currentTRL : TechnologyMaturityLevel;
        attribute sensorResolution : Real;
        attribute operatingPower : PowerValue;
        attribute dataRate : DataThroughput;

        port sensorOut : SensorInputPort;
        port power : PowerSupplyPort;

        state sensorLifecycle {
            entry; then initializing;

            state initializing {
                doc /* Sensor calibration and self-test */
            }
            then operational;

            state operational {
                entry; then idle;
                
                state idle;
                state acquiring;
                state transmitting;

                transition first idle;
                transition idleToAcquiring
                    first idle
                    accept commandReceived
                    then acquiring;
                transition acquiringToTransmitting
                    first acquiring
                    accept dataReady
                    then transmitting;
                transition transmittingToIdle
                    first transmitting
                    accept transmissionComplete
                    then idle;
            }

            state maintenance;
            transition operationalToMaintenance
                first operational
                accept maintenanceRequired
                then maintenance;
            transition maintenanceToOperational
                first maintenance
                accept maintenanceComplete
                then operational;
        }
    }

    part def AIProcessingCore {
        attribute currentTRL : TechnologyMaturityLevel;
        attribute processingCapacity : ProcessingCapacity;
        attribute algorithmVersion : String;
        attribute powerConsumption : PowerValue;

        port dataIn : DataBusPort;
        port intelligenceOut : IntelligenceOutputPort;
        port power : PowerSupplyPort;

        action def ProcessSensorData {
            in rawData : SensorData;
            out intelligence : ProcessedIntelligence;

            first start;
            then action validateData {
                in data = rawData;
                out validatedData : SensorData;
            }
            then action analyzePatterns {
                in data = validateData.validatedData;
                out patterns : String[0..*];
            }
            then action generateIntelligence {
                in patterns = analyzePatterns.patterns;
                out result : ProcessedIntelligence;
            }
            then done;
        }

        perform ProcessSensorData;
    }

    part def CommunicationSubsystem {
        attribute currentTRL : TechnologyMaturityLevel;
        attribute bandwidth : DataThroughput;
        attribute transmissionRange : LengthValue;
        attribute powerUsage : PowerValue;

        port dataIn : IntelligenceOutputPort;
        port commandPort : CommandPort;
        port power : PowerSupplyPort;

        state communicationState {
            entry; then standby;

            state standby;
            state transmitting;
            state receiving;

            transition standbyToTransmitting
                first standby
                accept dataAvailable
                then transmitting;
            transition transmittingToStandby
                first transmitting
                accept transmissionComplete
                then standby;
            transition standbyToReceiving
                first standby
                accept commandIncoming
                then receiving;
            transition receivingToStandby
                first receiving
                accept commandProcessed
                then standby;
        }
    }

    part def PowerManagementUnit {
        attribute totalPowerCapacity : PowerValue;
        attribute currentLoad : PowerValue;
        attribute efficiency : Real;

        port powerOut1 : PowerSupplyPort;
        port powerOut2 : PowerSupplyPort;
        port powerOut3 : PowerSupplyPort;
        port powerOut4 : PowerSupplyPort;
    }

    part def AutonomousIntelligenceSystem {
        doc /* An autonomous intelligence system that collects sensor data,
             * processes it using advanced AI algorithms, and disseminates
             * actionable intelligence. The system is developed following a
             * multi-phase technology roadmap to incrementally mature key
             * technologies from concept to operational deployment.
             */

        attribute systemMass : MassValue;
        attribute minOperatingTemp : TemperatureValue;
        attribute maxOperatingTemp : TemperatureValue;
        attribute missionDuration : DurationValue;

        part sensors : AdvancedSensorModule {
            attribute :>> currentTRL = TechnologyMaturityLevel::TRL7_OperationalDemo;
            attribute :>> sensorResolution = 0.01;
            attribute :>> operatingPower = 150.0 [W];
            attribute :>> dataRate = 100.0;
        }

        part aiCore : AIProcessingCore {
            attribute :>> currentTRL = TechnologyMaturityLevel::TRL6_PrototypeDemo;
            attribute :>> processingCapacity = 50.0;
            attribute :>> algorithmVersion = "v3.2.1";
            attribute :>> powerConsumption = 300.0 [W];
        }

        part comms : CommunicationSubsystem {
            attribute :>> currentTRL = TechnologyMaturityLevel::TRL8_SystemComplete;
            attribute :>> bandwidth = 10.0;
            attribute :>> transmissionRange = 50000.0 [m];
            attribute :>> powerUsage = 200.0 [W];
        }

        part powerMgmt : PowerManagementUnit {
            attribute :>> totalPowerCapacity = 1000.0 [W];
            attribute :>> currentLoad = 650.0 [W];
            attribute :>> efficiency = 0.92;
        }

        connection sensorToBus connect sensors.sensorOut to aiCore.dataIn;
        connection aiToComms connect aiCore.intelligenceOut to comms.dataIn;
        connection powerToSensors connect powerMgmt.powerOut1 to sensors.power;
        connection powerToAI connect powerMgmt.powerOut2 to aiCore.power;
        connection powerToComms connect powerMgmt.powerOut3 to comms.power;

        action def ExecutePrimaryMission {
            doc /* The primary function: continuously acquire sensor data,
                 * process it through AI algorithms to extract intelligence,
                 * and communicate actionable insights to operators.
                 */

            first start;
            then merge missionLoop;

            then action acquireSensorData {
                out sensorOutput : SensorData;
            }

            then action processData {
                in sensorInput = acquireSensorData.sensorOutput;
                out intelligence : ProcessedIntelligence;
            }

            then action communicateIntelligence {
                in intelligenceInput = processData.intelligence;
                out transmissionStatus : String;
            }

            then decide;
                if communicateIntelligence.transmissionStatus == "success" then missionLoop;
                if communicateIntelligence.transmissionStatus == "failure" then retryTransmission;

            action retryTransmission {
                in intelligenceInput = processData.intelligence;
                out retryStatus : String;
            }
            then missionLoop;

            then done;
        }

        perform ExecutePrimaryMission;
    }

    requirement <'REQ-100'> technologyRoadmapCompliance {
        doc /* The system shall be developed according to a phased technology
             * roadmap that advances component maturity levels through defined
             * development phases to achieve operational capability.
             */
        subject system : AutonomousIntelligenceSystem;
    }

    requirement <'REQ-101'> sensorMaturityRequirement {
        doc /* Advanced sensor modules shall achieve TRL 7 or higher by
             * Phase 2 completion to demonstrate operational capability.
             */
        subject sensors :>> AutonomousIntelligenceSystem::sensors;

        assert constraint {
            sensors.currentTRL == TechnologyMaturityLevel::TRL7_OperationalDemo or
            sensors.currentTRL == TechnologyMaturityLevel::TRL8_SystemComplete or
            sensors.currentTRL == TechnologyMaturityLevel::TRL9_OperationalProven
        }
    }

    requirement <'REQ-102'> aiProcessingMaturityRequirement {
        doc /* AI processing core shall achieve minimum TRL 6 to demonstrate
             * prototype capability in relevant operational environment.
             */
        subject aiCore :>> AutonomousIntelligenceSystem::aiCore;

        assert constraint {
            aiCore.currentTRL == TechnologyMaturityLevel::TRL6_PrototypeDemo or
            aiCore.currentTRL == TechnologyMaturityLevel::TRL7_OperationalDemo or
            aiCore.currentTRL == TechnologyMaturityLevel::TRL8_SystemComplete or
            aiCore.currentTRL == TechnologyMaturityLevel::TRL9_OperationalProven
        }
    }

    requirement <'REQ-103'> communicationMaturityRequirement {
        doc /* Communication subsystem shall achieve TRL 8 to ensure system
             * is complete and qualified for operational deployment.
             */
        subject comms :>> AutonomousIntelligenceSystem::comms;

        assert constraint {
            comms.currentTRL == TechnologyMaturityLevel::TRL8_SystemComplete or
            comms.currentTRL == TechnologyMaturityLevel::TRL9_OperationalProven
        }
    }

    requirement <'REQ-104'> powerBudgetRequirement {
        doc /* Total system power consumption shall not exceed available
             * power capacity with minimum 10% margin.
             */
        subject system : AutonomousIntelligenceSystem;

        assert constraint {
            system.powerMgmt.currentLoad <= system.powerMgmt.totalPowerCapacity * 0.90
        }
    }

    requirement <'REQ-105'> primaryFunctionRequirement {
        doc /* The system shall autonomously acquire, process, and communicate
             * intelligence data as its primary operational function.
             */
        subject system : AutonomousIntelligenceSystem;

        require sensorMaturityRequirement;
        require aiProcessingMaturityRequirement;
        require communicationMaturityRequirement;
    }

    package TechnologyRoadmapDefinition {
        attribute phase1 : RoadmapPhase {
            attribute :>> phaseName = "Concept Development and Validation";
            attribute :>> startYear = 2024;
            attribute :>> endYear = 2025;
            attribute :>> targetTRL = TechnologyMaturityLevel::TRL4_LabValidation;
            attribute :>> status = RoadmapPhaseStatus::completed;
            attribute :>> keyMilestones = ("Algorithm development", "Lab testing", "Concept validation");
        }

        attribute phase2 : RoadmapPhase {
            attribute :>> phaseName = "Technology Maturation and Integration";
            attribute :>> startYear = 2025;
            attribute :>> endYear = 2027;
            attribute :>> targetTRL = TechnologyMaturityLevel::TRL7_OperationalDemo;
            attribute :>> status = RoadmapPhaseStatus::inProgress;
            attribute :>> keyMilestones = ("Prototype development", "Subsystem integration", "Field demonstration");
        }

        attribute phase3 : RoadmapPhase {
            attribute :>> phaseName = "System Qualification and Deployment";
            attribute :>> startYear = 2027;
            attribute :>> endYear = 2029;
            attribute :>> targetTRL = TechnologyMaturityLevel::TRL9_OperationalProven;
            attribute :>> status = RoadmapPhaseStatus::planned;
            attribute :>> keyMilestones = ("System qualification", "Operational testing", "Full deployment");
        }
    }

    part systemImplementation : AutonomousIntelligenceSystem {
        attribute :>> systemMass = 45.0 [kg];
        attribute :>> minOperatingTemp = 233.15 [K];
        attribute :>> maxOperatingTemp = 358.15 [K];
        attribute :>> missionDuration = 259200.0 [s];
    }

    satisfy technologyRoadmapCompliance by systemImplementation;
    satisfy sensorMaturityRequirement by systemImplementation;
    satisfy aiProcessingMaturityRequirement by systemImplementation;
    satisfy communicationMaturityRequirement by systemImplementation;
    satisfy powerBudgetRequirement by systemImplementation;
    satisfy primaryFunctionRequirement by systemImplementation;
}
